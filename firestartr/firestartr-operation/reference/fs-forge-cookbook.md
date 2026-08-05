# fs-forge Cookbook

The repeated `fs-forge` idioms every mutating playbook builds on. `{org}` and
`{version}` are resolved from `firestartr-config.yaml` before any of these run.

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} <args>
```

**Hard dependency — no fallback.** If the invocation fails, stop immediately
and tell the user:

> `fs-forge` could not be run via `npx`.
> Ensure `npx` is available (Node >= 18) and that you have network access.
> Do not proceed without it.

Never hand-author a claim body when fs-forge is unavailable.

## Discover a kind's flags at runtime

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json
```

This returns an array of FlagSpec objects. Each has:

| Field | Meaning |
|---|---|
| `name` | Long CLI flag name without the leading `--`; pass it as `--<name>` |
| `path` | Dotted path of the claim field this flag sets (e.g. `providers.github.org`) |
| `type` | Value type (`string`, `boolean`, `number`, …) |
| `required` | Whether the flag must be provided |
| `enumValues` | Allowed values (present when constrained) |
| `defaultValue` | fs-forge's own default (if any) |
| `multiple` | Whether the flag accepts multiple values |

**Never hardcode a CLI flag name.** Derive flag names from the FlagSpec returned
by `--help --json`. For field paths, use the returned `path`; the two stable org
field paths documented below are the deliberate exception used to identify the
org flag.

## `{org}` passthrough

The discovery example below uses `jq` to parse FlagSpec JSON; install `jq` or use
an equivalent JSON parser when following it.

The `{org}` value resolved from `firestartr-config.yaml` must be passed to the flag
whose FlagSpec `path` equals the kind's org field.

- Most kinds: `providers.github.org`
- OrgWebhookClaim: `providers.github.orgName`

To find the right flag at runtime:

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json \
  | jq -r '.[] | select(.path == "providers.github.org" or .path == "providers.github.orgName") | "--\(.name)=\("{org}")"'
```

Pass the resulting `--<flag>=<value>` to
`npx @firestartr/fs-forge-cli@{version} create`.

## Create a claim file

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> \
  --<org-flag>={org} \
  --<field>=<value> \
  ...
  -o {output-path}
```

Flags and their names come from the FlagSpec discovery step above — never
constructed by hand. The skill sets only the flags it knows values for;
required flags with no available value are gathered from the client first.

Add `--diff` (offline, no network) to preview the new claim's own one-hop
relation tree before writing it — same renderer as `discovery map`/`edit`'s
`--diff`, just with no "before" side. `--ascii` swaps in bracket icons.

## Validate a claim file (syntactic only)

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}
```

fs-forge validates schema, types, and enum constraints. It does **not** check
cross-claim references, duplicates, or naming rules — those are the skill's
responsibility (see the validation split in `reference.md`).

Schema lookup is relative to the current working directory (`{cwd}/schemas/`).
Run `validate`/`create`/`edit`/`clone` from a directory that has one — e.g. a
clone of `{claims_repo}` (which ships it), or a `schemas/` symlink to the CLI's
bundled copy — not an arbitrary scratch directory like `/tmp`.

## Discover an org's elements

List every claim in an org's claims repo straight from the claims-map — no
clone, no `gh api` path-walking:

```bash
npx @firestartr/fs-forge-cli@{version} discovery org-elements --org={org}
```

Read-only, one API call. Prints an aligned KIND/NAME/FILE PATH table. Add
`--json` for a JSON object shaped like `{"org": ..., "claimsRepo": ...,
"claimsMapSha": ..., "claims": {"<Kind>": [{"name": ..., "filePath": ...}]}}`
grouped by kind, or repeatable `--kind <kind>` to filter (e.g. `--kind
component --kind group`). `--claims-repo` overrides the default `claims`
repo name. This is the fast path for "what does this org have" — prefer it
over `catalog`'s hydrated view when raw claim inventory is enough and the
catalog may be stale.

## Discover an org's relation map (topology, ownership)

Render the ownership/grouping tree derived from claim references — not a
hydrated catalog view, the live claims-repo relations:

```bash
npx @firestartr/fs-forge-cli@{version} discovery map --org={org}
```

Read-only but network-bound (downloads one claims-repo tarball; needs
`GITHUB_TOKEN` like `edit`/`clone` below). Recognizes only `owner`,
`maintainedBy`, `platformOwner`, `subComponentOf`, `system`, `domain`,
`parent`, `children`, and `members` — API references and inline Features are
never part of this graph. This is the tool for "show the org structure" /
"what's in system Y" / topology questions — prefer it over the catalog
playbook whenever the catalog might be stale, since this reads the claims
repo directly with no ~6h hydration lag.

Options: repeatable `--kind <kind>` filters to one or more kinds (short ID
like `component` or the full `ComponentClaim` — both spellings work here and
for `clone`'s kind argument below), `--ref <branch|tag|commit>` pins the
claims repo revision, `--ascii` swaps emoji icons for bracket tags (`[CMP]`,
`[GRP]`, …), `--json` returns the structured graph (`{"nodes": [...],
"edges": [...]}`) instead of the rendered tree — use `--json` when the result
feeds another step rather than the client's eyes.

Each edge carries its `relation` (`owner`, `parent`, `system`, …), so a chain
question ("who owns X, all the way up") is answered by walking `edges` from
the target node until none remain — the whole graph is in this one payload.

## Render an arbitrary relation graph

Same tree renderer as `discovery map`/`--diff`, but for a graph that has nothing
to do with claims — e.g. one assembled by hand, by another tool, or by merging
`discovery map --json` with catalog-only nodes it doesn't track (`Resource`
entities):

```bash
npx @firestartr/fs-forge-cli@{version} diagram print --file {graph.json}
cat {graph.json} | npx @firestartr/fs-forge-cli@{version} diagram print
```

Local and offline — no `--org`, no network. Input is the same `RelationGraph`
shape `discovery map --json`/`--diff --json` already produce:
`{"nodes": [{"id", "kind", "name", "dangling?", "status?"}], "edges":
[{"from", "to", "relation", "status?"}]}`. It's schema-validated; malformed
JSON or a graph that fails the schema errors with a message instead of a
crash or a silent misrender. A `kind` that isn't a real claim kind (the normal
case here) renders with the generic fallback icon (`❓` / `[???]` with
`--ascii`) — there's no per-kind custom icon for non-claim input. Reach for
this only when the graph isn't claims data; `discovery map` is still the tool
for an org's own topology.

## Claims-repo commands: read, edit, clone (network-bound)

Unlike `create` (local, deterministic, no network), `edit` and `clone` read and
write the claims repo directly over the GitHub API. Both need:

- `GITHUB_TOKEN` in the environment — `fs-forge` reads this env var directly,
  it doesn't share `gh`'s internal auth store. Populate it from `gh` once per
  session if it isn't already set: `export GITHUB_TOKEN=$(gh auth token)`.
- `--org={org}` on every invocation — the GitHub org whose `claims` repo to
  talk to. This is a different flag from the claim's own
  `providers.github.org` schema field (only relevant if you're deliberately
  changing that field); always pass `--org={org}` explicitly rather than
  relying on an env var default.

Claims are addressed as `<Kind>-<name>` (e.g. `ComponentClaim-my-repo`) — the
same key the claims-map uses. Use this notation everywhere you need to name an
existing claim.

### Read an existing claim

`edit` with no mutating flags is the preferred way to read a claim — it goes
through the claims-map instead of hand-rolling a `gh api` path lookup:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org}
```

Prints the current claim YAML to stdout. Fall back to `gh-cookbook.md`'s "Read
a file" only if the claims-map lookup itself is unavailable.

### Edit an existing claim

Mutation flags come from the same discovery step as `create` — run
`npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json` for the
target kind and reuse the returned flag `name`s. (`edit --help --json` mixes
every kind's flags together since the kind isn't known until the reference
argument is parsed — don't use it for discovery.)

Always dry-run before committing:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... \
  --unset <dotted.path> ... \
  --diff
```

`--diff` prints a one-hop **relation diff** to stderr — the same tree
renderer as `discovery map`, scoped to the edited claim and its direct
references, with `+`/`-`/`~` markers for added/removed/changed nodes and
edges (not a plain field-by-field YAML diff). Add `--json` for the
structured diff (`{"nodes": [...], "edges": [...]}` with a `status` on each
changed entry) or `--ascii` for bracket icons instead of emoji. Dangling
references (pointing at a claim that doesn't exist) are flagged using the
already-loaded claims-map. Show the printed diff to the client and get
approval. Only then re-run the same command with `--commit` appended:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... --commit
```

> **Warning — `--commit` does not just commit.** It creates the branch,
> commits the claim, and dispatches `provision-claim.yaml`, which opens the
> PR, waits for verify, merges it, **dispatches and waits for hydration**, and
> merges the resulting wet PR — all on its own, with no further input. Passing
> `--commit` provisions **and hydrates** the claim end-to-end in one shot.
> Never pass it before the client has approved the diff, and never follow it
> with a manual hydrate step — it already happened. If the client asks for
> status, check the dispatched run; only trigger a *separate* manual hydrate
> (`gh-cookbook.md`) if they explicitly ask for one.

**Array flags replace the whole array** — `--members=a --members=b` sets
`members` to exactly `[a, b]`, it does not append or remove one entry. Read
the current value first (see "Read an existing claim" above), compute the
full desired list, then pass it whole.

If the field you need isn't exposed by `--help --json` (e.g. editing one
element inside an array of objects without recomputing the whole array), fall
back to the manual `gh-cookbook.md` read → edit → write flow.

### Clone an existing claim

```bash
npx @firestartr/fs-forge-cli@{version} clone <Kind> --org={org} \
  --from <source-name> --name <new-name> \
  --<flag>=<value> ... \
  --diff
```

`<Kind>` here takes either the short ID (`component`) or the full name
(`ComponentClaim`) — unlike `edit`'s `<Kind>-<name>` reference, which still
requires the full name. `--name` must differ from `--from`.
`TFWorkspaceClaim`/`SecretsClaim` also need
`--path claims/{...}/{new-name}.yaml` (same rule as `create`'s deterministic
path). Same dry-run → approve → `--commit` sequence and the same `--commit`
warning as `edit` above; `--diff`/`--json`/`--ascii` behave the same as
`edit`'s relation diff too (compared against nothing, since the clone target
is new). `clone --commit` additionally errors if `<Kind>-<new-name>` already
exists — no separate uniqueness check needed. See `../playbooks/clone-claim.md`
for the full flow.

## Discover the feature catalog

```bash
npx @firestartr/fs-forge-cli@{version} features discover --json
npx @firestartr/fs-forge-cli@{version} features discover --readme <feature-name>
npx @firestartr/fs-forge-cli@{version} features discover --schema <feature-name>@<feature-version>
```

Reads the Feature source (`--source`, defaults to `firestartr-pro/docs`), not
a claim or component — no `--org`/`--commit`. `--json` lists every published
feature with its latest version; `--readme` prints what a feature does;
`--schema` prints its `args.*` FlagSpecs for `<feature-name>@<feature-version>`.
`--versions <feature-name>`/`--changelog <feature-name>` are also available.
Feeds `../playbooks/feature-advisor.md`.

## Feature CRUD (ComponentClaim only)

Dedicated subcommands mutate one `features[]` entry at a time — no more
read-whole-array-and-recompute for this one field. Target either form (the
positional `<component>` is the **bare** component name, not
`ComponentClaim-<name>`):

- `<component> --org={org}` — resolved through the claims-map as
  `ComponentClaim-<component>`.
- `-f {claim-file}` — a local ComponentClaim YAML file; skips the claims-map.

All four subcommands error if the claim isn't a ComponentClaim.

### Add / edit — schema-derived `args.*` flags

```bash
npx @firestartr/fs-forge-cli@{version} features add --name <feature> --help --json
```

Resolves the Feature's **latest published schema** from the Feature source
(`--source`, defaults to `firestartr-pro/docs`) and returns FlagSpecs for
`args.<field>` alongside the fixed `name`/`version`/`ref`/`repo` flags — same
FlagSpec discovery idiom as `create <Kind> --help --json`. The reference's own
`version`/`ref` only pins what the claim stores; it never selects which schema
validates `args`.

```bash
npx @firestartr/fs-forge-cli@{version} features add <component> --org={org} \
  --name <feature> --version <v> \
  --args.<field>=<value> ... \
  --commit
```

- Exactly one of `--version` / `--ref` is required.
- `features add` errors if the name already exists; `features edit` errors if
  it doesn't. `features edit` carries forward the existing `args` for fields
  you don't pass — it does not reapply schema defaults.
- Schemas are cached by Feature name (`FS_FORGE_FEATURE_CACHE_DIR` overrides
  the location); pass `--refresh` to bypass a stale cache.
- `--args.json='{...}'` is the raw escape hatch when you'd rather pass the
  whole `args` object as JSON than discover each field flag.

### Remove / list — no schema resolution

```bash
npx @firestartr/fs-forge-cli@{version} features remove <component> --org={org} --name <feature> --commit
npx @firestartr/fs-forge-cli@{version} features list <component> --org={org} --json
```

`remove` needs no `--source`/schema fetch. `list` is read-only and needs no
`--commit`.

### Inline, unvalidated alternative — `create`/`edit`

For attaching a Feature at creation time, or adding/removing one without a
schema round-trip, use the repeatable inline flag instead of the Feature
subcommands:

```bash
npx @firestartr/fs-forge-cli@{version} create component ... --feature 'name@1.2.3:{"enabled":true}'
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --add-feature 'name#main:{"enabled":true}' --remove-feature other-name --commit
```

Form is `name@version:{...}` or `name#ref:{...}`; `{...}` is a raw JSON object
and may be omitted for no args. These do **not** fetch or validate against the
Feature's schema — run `validate` afterward (deep mode, below) to check `args`
against the latest schema before landing the change.

### Deep validation

Plain `validate -f {claim-file}` ("Validate a claim file (syntactic only)"
above) checks the claim's own schema, types, and enums, but not Feature
`args` against their schemas. Add `--source`/`--refresh` to also validate
every attached Feature's `args` against its latest schema (`--refresh`
bypasses the schema cache):

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file} --source <source> --refresh
```

Run this after any `--feature`/`--add-feature` inline mutation, since those
skip schema validation at write time.
