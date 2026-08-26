# fs-forge Mutation Shared Reference

Cross-cutting rules `create`, `edit`, and `clone` all lean on. Sibling of
`fs-forge-cookbook.md`; `{org}`/`{version}` come from `firestartr-config.yaml`.

## Discover a kind's flags at runtime

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json
```

This (and dynamic Feature help, `fs-forge-features.md`) returns a
**`CommandHelpJson`** object, never a root-level array — full contract:
`npx @firestartr/fs-forge-cli@{version} schema show CommandHelpJson`
(`fs-forge-cookbook.md`'s contract-discovery commands). Besides `flags`
(below), read: `id`/`aliases` to confirm which command actually matched;
`description`/`summary` — the command's own explanation; prefer these,
translated to client terms (Rule 1, `../SKILL.md`), over composing your own
when telling the client what an operation does; `usage`/`examples` for the
canonical invocation; `args` for positional-argument specs (same
`required`/`multiple` idea as flags); and `relationships` for declarative
arg/flag constraints — e.g. `features add`'s "a component name or `--file`,
never both" is `{"type": "exactlyOne", "args": ["component"], "flags":
["file"]}` — read this instead of inferring the rule from prose.

Read the flags themselves from **`.flags[]`**: `path` (dotted claim-field
path, e.g. `providers.github.org` — also the flag's literal name; pass a
value as `--<path>=<value>`), `type`, `required`, `conditionalRequired`
(required only once its parent object/union branch is actually supplied),
`options` (allowed values, when constrained), `default`, `multiple` (passing
it several times **replaces** the whole array, it never appends — read the
current value first, compute the full desired list, then pass it whole; a
repeatable flag's own `description` states this rule itself), and
`description` (when the CLI provides one — check it before asking the
client).

**Never hardcode a CLI flag name for a schema field.** Derive schema-field flag
paths from the FlagSpec entries in `--help --json`'s `.flags[]`. Every other
flag this cookbook uses is already a fixed, hardcoded name, safe to keep
hardcoding: `org`, `commit`, and `path` on every kind; `diff` and `json` on
`edit`/`clone` only (`create` has neither); ComponentClaim's own
`feature`/`add-feature`/`remove-feature` (`fs-forge-features.md`'s "Feature
CRUD"); and the two schema org-field paths documented next, identified by exact
`path` match, never fuzzy "contains org" matching.

## `{org}` passthrough — two distinct flags

A kind's discovered flags can include **two** org-shaped entries at once —
tell them apart by FlagSpec `path`, never by name alone:

- **Control-plane `--org`** (`path: "org"`, env `FSCRT_ORG`) — which GitHub
  org's claims repo to talk to. Same name on every kind and every command
  (`create`/`edit`/`clone`/`defaults`/`discovery`). Only enforced when a
  network call actually happens — `--commit`, `edit`/`clone`, a `defaults`
  command — a plain, uncommitted `create` needs neither it nor network access.
- **Schema org field** — which GitHub org the claim's own resource (repo,
  team, …) belongs to. Path varies by kind, and several kinds have none at
  all:
  - Most kinds: `providers.github.org`
  - OrgWebhookClaim: `providers.github.orgName`

The `{org}` value from `firestartr-config.yaml` is usually the same GitHub
org for both, but pass it to each flag under its own discovered name — never
assume one flag also sets the other. This distinction doesn't go away for
`edit`/`clone` — they still need the control-plane flag on top of it for
every network call (`fs-forge-edit-clone.md`).

The example below uses `jq` to parse FlagSpec JSON; install `jq` or use an
equivalent JSON parser when following it. To find the schema org field at
runtime:

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json \
  | jq -r '.flags[] | select(.path == "providers.github.org" or .path == "providers.github.orgName") | "--\(.path)=\("{org}")"'
```

Pass the resulting `--<flag>=<value>` to `create`, `edit`, or `clone`.

## The `--commit` warning

`--commit` does not just write the claim. Appended to `create`, `edit`, or
`clone`, it creates the branch, commits the claim file, and dispatches
`provision-claim.yaml`, which opens the PR, waits for verify, merges it,
**dispatches and waits for hydration**, and merges the resulting wet PR — all
on its own, with no further input. One flag provisions **and hydrates** the
claim end-to-end. Never pass it before the client has approved the diff, and
never follow it with a manual hydrate step — it already happened. If the
client asks for status, check the dispatched run; only trigger a *separate*
manual hydrate (`gh-cookbook.md`) if they explicitly ask for one.

`create --commit` and `clone --commit` additionally error up front if the
target `<Kind>-<name>` already exists — no separate uniqueness check needed
from the CLI's side (the skill still pre-checks its own side —
`reference.md`'s validation split). `create --commit`/`clone --commit` on
TFWorkspaceClaim/SecretsClaim also require `--path claims/{...}/{name}.yaml`
(rejected outright for every other kind, which resolve their own path). A
`--commit` that fails for any of these reasons surfaces as a CLI error before
anything is dispatched — fix the reported problem and re-run.

> **Check this first:** the exact error text and exit code — see
> `diagnostics.md#fs-forge-cli-error-shapes`.

## Claim defaults (`claims_defaults.yaml` in the claims repo)

`edit`/`clone` automatically fetch the org's repo-level claim defaults and
apply them **after** the client's own requested changes, additively — a
field is only filled when the claim doesn't already set it, never
overwriting client intent. Validation runs against this final, defaulted
document, so `--commit` always publishes a fully-defaulted, schema-valid
claim. Reveal what got filled in a dry-run with `--show-defaults`
(`fs-forge-edit-clone.md`).

**`create` never applies them** — with or without `--commit`, its output is
always the minimal document its flags describe. Preview what the platform
would add with the read-only commands below and surface it to the client as
"the platform will also apply: …", distinct from the file itself.

```bash
npx @firestartr/fs-forge-cli@{version} defaults apply <Kind>-<name> --org={org}
npx @firestartr/fs-forge-cli@{version} defaults apply -f {claim-file} --org={org}
npx @firestartr/fs-forge-cli@{version} defaults show <kind> --org={org}
npx @firestartr/fs-forge-cli@{version} defaults list --org={org} [--json]
```

`apply` prints a claim (by `<Kind>-<name>` reference, or a local `-f` file —
which must have a `kind` field, or it errors) filled with its kind's
defaults; no validation, no write. `show` prints one kind's defaults on
their own (an empty result for a kind with none defined, an error for an
unrecognized kind id). `list` prints which kinds have any defaults defined
for the org — table by default, `--json` for structured output. All three
need the same `GITHUB_TOKEN`/`--org` prerequisites as `edit`/`clone`.

Some fields default as an **all-or-nothing block** rather than field-by-field
— currently TFWorkspaceClaim's `providers.terraform.sync` block (see
`reference.md`'s Terraform policy section): set any one `sync.*` field
yourself and the whole block stays exactly as set; set none and the whole
default block applies. A partially-set block is never "topped up" field by
field.

**Failure handling differs by context.** An ambiguous defaults-file location
(more than one candidate found, none at the conventional path) hard-fails
the three preview commands above with the candidate list, but only warns on
stderr for `edit`/`clone`, which continue **without** applying defaults at
all — never a partial/best-guess application. A genuine network or auth
failure fetching the file is always a hard failure, everywhere — never
treated the same as "no defaults file" and silently skipped.
