# Does `filesTemplates` handle a ~24-file nested tree?

**Gist:** Yes, cleanly, with room to spare. The renderer has no file-count or
directory-depth limit anywhere in its schema or code — `files:` is just a flat
array of `{src, dest}` pairs copied one by one, and `filesTemplates` is only a
mechanism to *generate* more entries in that same array via Mustache-rendered
YAML snippets. The existing `claims_repo` package already ships **62** files
up to 3 directories deep (including binary images) using a plain `files:`
list with no `filesTemplates` at all, so a static 24-file, 2-level-deep tree
like `firestartr-operation/` is comfortably within precedent — it doesn't even
need `filesTemplates` for the static parts, only (optionally) for anything
conditional/looped.

## How `files:` / `filesTemplates` are actually processed

Source: `packages/features_renderer/src/render.ts` in `prefapp/gitops-k8s`

- `render()` (`render.ts:20-125`) validates `config.yaml`, builds the mustache
  context, and — only if the resolved config has a `filesTemplates` key —
  calls `expandFiles()` (`render.ts:40-42`).
- `expandFiles()` (`render.ts:181-193`) loops over every string in
  `configData.filesTemplates`, reads that template file relative to the
  feature dir, Mustache-renders it, parses the result as YAML, and
  concatenates its `files:` array onto `context.config.files`. It is a plain
  `for` loop with `Array.concat`/`.flat(Infinity)` — no recursion depth
  cap, no item-count cap.
- After expansion, `render()` iterates `context.config.files` with a single
  `forEach` (`render.ts:66-113`): for each entry it path-validates `src`/`dest`
  (`assertSafeRelativePath`, `resolveInside` — anti path-traversal, not a size
  limit), reads `templates/<src>`, Mustache-renders it, runs
  `addTraceability`, then `fs.mkdirSync(path.dirname(dest), {recursive:true})`
  + `fs.writeFileSync(dest, content)`. Because `mkdirSync` is recursive, `dest`
  (and `src`) can contain arbitrarily many path segments — nested output
  directories are created for free, one per file. There is no "copy whole
  directory" primitive; every file must have its own `{src, dest}` line,
  either written statically in `files:` or produced by a `filesTemplates`
  expansion.
- `src`/`dest` may themselves contain a Mustache tag to pick a directory
  dynamically, e.g. `feature_a`'s
  `src: .github/workflows/{{| TECH |}}/pr-verify.yaml`
  (`__tests__/fixtures/features/feature_a/config.yaml:20`).

## Schema: no maxItems on `files` or `filesTemplates`

Source: `packages/features_renderer/src/schema.ts` in `prefapp/gitops-k8s`

- `files` (`schema.ts:14-19`) is `{ type: "array", items: {$ref: "#/definitions/File"} }`
  — no `minItems`/`maxItems`.
- `filesTemplates` (`schema.ts:33-42`) is `{ type: "array", items: {type:
  "string", not: {pattern: "^/|(^|/)\\.\\.(/|$)"} } }` — again unbounded, the
  only constraint is the anti-traversal regex (no absolute paths, no `..`
  segments), enforced a second time at runtime by `resolveInside`
  (`render.ts:257-283`) which also rejects symlink escapes.
- **File-count/depth limit found: none.** The only caps in the codebase are
  unrelated to file trees: `auxiliar.ts`'s `ensureSafeTmpNames` limits a
  *test* `name` string to 128 chars (`auxiliar.ts:181-197`), irrelevant to
  rendered file trees.

## Tests: what's actually exercised

Source:
`packages/features_renderer/__tests__/renderer_files_templates.test.ts` in
`prefapp/gitops-k8s`
and its fixtures under `.../fixtures/features/feature_files_templates/`.

- The fixture feature (`config.yaml`) has one static file (`a.txt`) plus two
  `filesTemplates` entries: `files.tpl` (a conditional single file, `b.txt`,
  gated by `{{| #INCLUDE_B |}}`) and `files_loop.tpl` (a Mustache
  `{{| #ADDITIONAL_FILES |}}` loop emitting one `files:` entry per array
  element, tested with 3 elements: `a1.txt, a2.txt, a3.txt` —
  `renderer_files_templates.test.ts:180-201`). This validates the *loop*
  primitive, not raw file count — 3 is the largest N in these tests.
  Depth in this fixture is flat (`templates/a.txt`,
  `templates/additional/a1.txt`, `templates/b.txt` — only 1 level of
  subdirectory: `fixtures/features/feature_files_templates/templates/`).
- The bulk of the suite (`describe("Path traversal protection", ...)`,
  lines ~253-430) is about *security*, not scale: rejecting `..` segments,
  absolute paths, and symlink escapes in both `files:` `src`/`dest` and
  `filesTemplates` entries, for both static and template-expanded files.
  Nothing there implies a size ceiling — these are correctness/security
  checks, and one test explicitly confirms multi-level nesting works
  end-to-end ("allows files and templates nested inside the feature
  directory", `renderer_files_templates.test.ts:~395-410`, mapping
  `templates/nested/tpl.txt` → `out/nested.txt` and, via a template, →
  `out/from-tpl.txt`).
- No test anywhere renders more than a handful of files at once, so there is
  no first-party evidence of an artificial upper bound being tested — but
  combined with the schema/code reading above, and the `claims_repo`
  precedent (below), absence of such a test isn't a red flag; the mechanism
  is architecturally a loop over a list, not a size-bounded structure.

## Precedent: `claims_repo` already renders more files, deeper, with binaries

Source: `packages/claims_repo/config.yaml` in `prefapp/features` and its
`templates/` tree.

- `claims_repo/templates/` has **62 files**, 3 directories deep in places
  (`.github/scripts/*.js`, `docs/images/*.jpg`), including 15 binary JPGs/PNG
  under `docs/images/`. All 62 are listed as flat `files:` entries (no
  `filesTemplates` at all) — e.g. `config.yaml`'s `files:` block runs from
  `.config/auto-hydrate.yaml` through `README.md`. This is the closest
  existing package to "a large nested tree," and it works via plain `files:`,
  confirming file count and 2-3 levels of nesting are already production-used
  and not a `filesTemplates`-specific concern.
- ⚠️ **Binary-file gotcha (not applicable to `firestartr-operation`, but
  worth flagging for the new package in general):** `render.ts:87-91` reads
  every templated file with
  `fs.readFileSync(path.join(featurePath,'templates', src)).toString()`
  (implicit UTF-8 decode) and later `fs.writeFileSync(dest, content)` writes
  the *string* back (implicit UTF-8 re-encode). For a text file this
  round-trips safely. For genuinely binary content (the `claims_repo` JPGs)
  this decode/encode round-trip is lossy for any byte sequence that isn't
  valid UTF-8, and is not exercised in any renderer test — worth an
  independent check if it's ever verified those images render byte-identical
  in a real repo, but it does **not** affect this ticket since
  `firestartr-operation`'s 24 files are all confirmed plain UTF-8/ASCII text
  (`file` on every path in this repo's `firestartr/firestartr-operation/`
  returns "Unicode text, UTF-8 text" or "ASCII text", checked directly).

## Other packages, for scale context

`find <pkg>/templates -type f | wc -l` per package under `packages/` in
`prefapp/features`:

| package | file count |
|---|---|
| claims_repo | 62 |
| terraform-infra | 25 |
| state_repo_apps | 20 |
| features_repo | 18 |
| state_repo | 16 |
| build_and_dispatch_docker_images | 15 |
| tech_docs | 2 |
| issue_templates | 4 (3 templates + 1 doc) |

`tech_docs` and `issue_templates` are trivial (2-4 files, no nesting beyond
one `.github/ISSUE_TEMPLATE/` level) and don't need `filesTemplates` at all —
their `config.yaml` (`tech_docs/config.yaml`, `issue_templates/config.yaml`)
just lists each file statically, same pattern as `claims_repo` at larger
scale.

## `config.yaml` shape needed for a ~24-file, 2-level tree

Given `firestartr-operation/`'s actual layout (root files +
`playbooks/*.md` + `reference/*.md` + `templates/*.md`, no dynamic file set,
no binaries, no literal `{{`/`}}` sequences anywhere in the tree — checked
with `grep -rl '{{'`, zero matches), the simplest correct shape is a **flat
static `files:` list**, one entry per file, matching the `claims_repo` /
`tech_docs` precedent — `filesTemplates` is not required:

```yaml
feature_name: firestartr_operation
args: {}
files:
  - src: README.md
    dest: README.md
    user_managed: true
  - src: SKILL.md
    dest: SKILL.md
    user_managed: true
  - src: playbooks/catalog.md
    dest: playbooks/catalog.md
    user_managed: true
  # ... one line-pair per remaining playbooks/*.md, reference/*.md,
  # templates/claim-issue.md, firestartr-config*.yaml, .gitignore
patches: {}
```

`filesTemplates` would only earn its keep if the new package wants to (a)
conditionally include/exclude some of the 24 files per target repo, or (b)
loop over a dynamic list (à la `feature_files_templates`'s
`{{| #ADDITIONAL_FILES |}}` pattern) — neither of which is implied by the
ticket's "distribute as-is" framing, so a flat `files:` list is the
lower-risk default, with the option to lift specific entries into a
`filesTemplates`-expanded `.tpl` later without any renderer-side rework.

## Gotchas summary

1. **No file-count/depth limit found** in schema (`schema.ts`), validator
   (`validate.ts`), or renderer (`render.ts`) — confirmed by direct reading,
   not just absence of a failing test.
2. **`src`/`dest` must each be a single relative path with no `..` segment**
   (enforced twice: JSON-Schema `not: pattern` in `schema.ts:19-25,37-40`,
   and runtime `assertSafeRelativePath`/`resolveInside` in `render.ts:238-283`)
   — irrelevant for a same-repo tree copy, but means the new package's
   `config.yaml` must spell out clean relative paths (already the case for
   `firestartr-operation`).
3. **Symlinks anywhere on the resolution chain are rejected**
   (`hasSymbolicLinkComponent`, `render.ts:262-283`) — confirm
   `firestartr-operation/` has no symlinks before porting (a quick
   `find ... -type l` check is cheap to add to the follow-up work item).
4. **Mustache delimiters are the non-standard `{{| |}}`**
   (`renderContent`, `render.ts:216-218`), not the common `{{ }}` — so normal
   Markdown/YAML containing literal double braces is safe by default; only
   literal `{{|`/`|}}` text would misfire, and none exists in the current
   tree (`grep -rl '{{'` found zero matches).
5. **Binary content is read/written through implicit UTF-8 string
   round-tripping** (`render.ts:87-91`, `auxiliar.ts` writers) — a latent risk
   for image/binary assets (as seen in `claims_repo/templates/docs/images/`),
   but does not apply here since all 24 `firestartr-operation` files are
   confirmed text.
