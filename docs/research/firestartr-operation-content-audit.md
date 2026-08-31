# Content audit: `firestartr/firestartr-operation` for public distribution

Source: issue [#83](https://github.com/prefapp/skills/issues/83), child of
wayfinder map [#80](https://github.com/prefapp/skills/issues/80). All 24
files under `firestartr/firestartr-operation/` (~2186 lines) were read in
full. Line numbers below refer to each file as it exists at the time of this
audit.

## Executive gist

One real internal-only leak candidate: a hardcoded, no-fallback pointer to
Prefapp's own private Terraform module repo (`prefapp/tfm`), presented as
mandatory for **every** client org's `TFWorkspaceClaim`s — this needs
rewriting or gating before publication. No credentials, Slack/contact info,
or other clients' names were found. Skill dependencies are clean: the one
known graceful case (`SKILL.md:13`, "use `grilling` if available") is the
only mention of any other `prefapp/skills` skill anywhere in the tree —
nothing harder exists. Escaping references: exactly the two already known
(`README.md:44` and `reference/fs-forge-preflight.md:51`) — no additional
in-repo path escapes were found; a few external (non-repo) URLs exist but
they point at legitimate third-party or product-facing destinations, not
Prefapp-internal infrastructure (with the `prefapp/tfm` exception noted
above).

## 1. Prefapp-internal-only information

- **`reference/reference.md:107` and `:112`, `reference/gh-cookbook.md:87,
  92, 95, 98, 102`** — hardcode `prefapp/tfm` (`https://github.com/prefapp/tfm`)
  as *the* canonical Terraform remote-module source, explicitly "always the
  `prefapp` org **regardless of the client's organization**"
  (`reference.md:108`). This is Prefapp's own private/internal module repo,
  asserted as a mandatory dependency for any client wanting a
  `TFWorkspaceClaim` with a remote module — with no fallback for a client
  that doesn't (and won't) have access to it. This is the audit's one clear
  **internal-only leak + hard external dependency** and should be rewritten
  (e.g., made org-configurable, or removed/gated) before this content goes
  into the public `firestartr-pro/docs` catalog. Flagging precisely for
  issue #85 to act on: 6 total line hits across 2 files, listed above.

- **`firestartr-config.yaml`** (repo root of the skill dir) — present on
  disk locally with real values (`organizations[0].name: pre-vieitesss`,
  real local filesystem paths, `cli_version: "0.7.0"`), but it is
  **git-ignored** (`.gitignore:2`) and confirmed **not tracked** by git
  (`git ls-files` does not list it). It is a per-install runtime file, never
  committed, so it carries **no publish-leak risk** through normal
  distribution — noted here only because the ticket's "read every file"
  scope includes it. No action needed for #85.

- **`SKILL.md:79`** — the example status line `Using org: prefapp-demo
  (~/work/prefapp) | fs-forge: 0.1.0` combines the placeholder org name
  `prefapp-demo` with the literal path `~/work/prefapp` (the parent of this
  very repo's checkout path in Prefapp's own dev environment, `~/work/prefapp/skills`).
  It reads as an illustrative example rather than a real leaked path (no
  real org name attached to it, no credentials), but it's a minor
  cosmetic tell that the example was written from inside Prefapp's own dev
  setup. Low severity; optional cleanup, not a hard blocker.

- **`reference/fs-forge-features.md:33`** — mentions `firestartr-pro/docs`
  as the CLI's default Feature-schema source. **Not a leak**: this is the
  name of the very (public) catalog this content is destined for
  (docs.firestartr.dev's backing repo), so referencing it is expected and
  appropriate, not an internal pointer.

- **`firestartr-config.example.yaml:5,7,8,10-13`** — uses `prefapp-demo` /
  `~/work/prefapp-demo` as the example organization. This is a generic demo
  placeholder (mirrors the shape shown in `README.md`'s "First run" section),
  not a real client or internal system name. No action needed.

- No Slack handles, email addresses, phone numbers, credentials, tokens,
  API keys, or other clients' names were found anywhere in the 24 files.
  (`GITHUB_TOKEN` appears only as an env-var *name* the CLI reads — never a
  value — in `README.md`, `reference/fs-forge-edit-clone.md`, and
  `reference/fs-forge-mutation-shared.md`.)

**Zero other internal-only leaks found** beyond the `prefapp/tfm` case above.

## 2. Hard (non-graceful) skill dependencies

Grepped the full tree for every other `prefapp/skills` skill name
(`grilling`, `domain-modeling`, `tdd`, `research`, `writing-for-agents`,
`workflow-router`, `grill-with-docs`, `handoff`, `implement`,
`improve-codebase-architecture`, `prototype`, `review`, `setup-workflow`,
`to-spec`, `to-tickets`, `triage`, `wayfinder`, `wizard`, `codebase-design`,
`diagnosing-bugs`) — the **only** hit anywhere in the 24 files is:

- **`SKILL.md:13`** — `**Asking the client:** use \`grilling\` if
  available — one question at a time, each with a recommended answer.` This
  is the already-known graceful case ("if available" + a described fallback
  behavior — "one question at a time, each with a recommended answer" — that
  the skill can perform itself either way). Confirmed: **no other mention**
  of `grilling`, or any other skill, exists anywhere else in the tree
  (`playbooks/feature-advisor.md:56`'s "one at a time with a recommended
  default" describes the same interview style directly, without naming or
  requiring the `grilling` skill).

**Zero hard dependencies on other `prefapp/skills` skills found**, beyond
the one known graceful case, which needs no further action.

## 3. References that escape the skill's own directory

Searched every file for any `../../` (2+ levels up, i.e. anything reaching
outside `firestartr/firestartr-operation/`) and cross-checked against prose.
Result: **exactly the two already-known escapes, and no others**:

1. **`README.md:44`** — `` [root README](../../README.md) `` — links to the
   repo-root `README.md` (two levels up from
   `firestartr/firestartr-operation/`).
2. **`reference/fs-forge-preflight.md:51`** — `` `../../../docs/adr/0009-preflight-no-import-or-rename-flow.md` `` —
   points at an ADR under the repo-root `docs/adr/` (three levels up from
   `firestartr/firestartr-operation/reference/`).

No other in-repo relative path of any depth escapes the skill's directory
anywhere in the 24 files (single-`../`-level references, e.g.
`../reference/fs-forge-preflight.md` from a playbook, all stay within
`firestartr/firestartr-operation/` and are not counted here).

For completeness, external (non-repo, non-filesystem) references were also
inventoried — these don't "escape the directory" in the filesystem sense
the ticket is scoped to, but are listed here since #85 may want visibility:

- `README.md:24-29` — `https://opencode.ai` (+ `/install`, `/docs/`) and
  `https://pi.dev` (+ `/install.sh`, `/docs/latest`) — third-party agent
  harness install links. Legitimate, no action needed.
- `reference/reference.md:107,112` and `reference/gh-cookbook.md:87,92,95,98,102` —
  `prefapp/tfm` / `https://github.com/prefapp/tfm` — see finding under §1
  above; this is a GitHub-repo reference (not a relative file path), but it
  is the one reference in the whole tree that both leaks internal
  infrastructure and hard-locks external clients to it.
- `reference/fs-forge-features.md:33` — `firestartr-pro/docs` — the
  publication target itself; not an escape, not a leak (see §1).

**Total escaping (in-repo, filesystem) references beyond the two known
ones: 0.**
