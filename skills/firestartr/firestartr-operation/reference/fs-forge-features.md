# fs-forge Features Reference

ComponentClaim-only: discovering, attaching, editing, and removing Feature
references. Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

## Discovering the feature catalog

Browsing what's available (names, READMEs, schemas, versions, changelogs) is
part of the feature-matching flow, not a CRUD operation: see
`../playbooks/feature-advisor.md` for the commands and the full flow.

## Feature CRUD (ComponentClaim only)

Dedicated subcommands mutate one `features[]` entry at a time: no more
read-whole-array-and-recompute for this one field. Target either form (the
positional `<component>` is the **bare** component name, not
`ComponentClaim-<name>`):

- `<component> --org={org}`: resolved through the claims-map as
  `ComponentClaim-<component>`.
- `-f {claim-file}`: a local ComponentClaim YAML file; skips the claims-map.

All four subcommands error if the claim isn't a ComponentClaim.

### Add / edit: schema-derived `args.*` flags

```bash
npx @firestartr/fs-forge-cli@{version} features add --name <feature> --help --json
```

Resolves the Feature's **latest published schema** from the Feature source
(`--source`, defaults to `firestartr-pro/docs`) and returns a `CommandHelpJson`
object whose `.flags[]` includes `args.<field>` entries alongside the fixed
`name`/`version`/`ref`/`repo` flags: same discovery idiom as `create <kind>
--help --json` (`fs-forge-mutation-shared.md`). The reference's own
`version`/`ref` only pins what the claim stores; it never selects which
schema validates `args`.

```bash
npx @firestartr/fs-forge-cli@{version} features add <component> --org={org} \
  --name <feature> --version <v> \
  --args.<field>=<value> ... \
  --commit
```

- `features add` requires exactly one of `--version` / `--ref`; `features edit`
  keeps the current pin when you omit both.
- `features add` errors if the name already exists; `features edit` errors if
  it doesn't. `features edit` carries forward the existing `args` for fields
  you don't pass: it does not reapply schema defaults.
- Schemas are cached by Feature name (`FS_FORGE_FEATURE_CACHE_DIR` overrides
  the location); pass `--refresh` to bypass a stale cache.
- `--no-wait` skips waiting for the provision workflow a `--commit`
  dispatches; `--json` outputs structured JSON. Both exist on `add`/`edit`/
  `remove`.
- `--args.json='{...}'` is the raw escape hatch when you'd rather pass the
  whole `args` object as JSON than discover each field flag.

### Remove / list: no schema resolution

```bash
npx @firestartr/fs-forge-cli@{version} features remove <component> --org={org} --name <feature> --commit
npx @firestartr/fs-forge-cli@{version} features list <component> --org={org} --json
```

`remove` needs no `--source`/schema fetch.

## Inline, unvalidated alternative: `create`/`edit`

For attaching a Feature at creation time, or adding/removing one without a
schema round-trip, use the repeatable inline flag instead of the Feature
subcommands:

```bash
npx @firestartr/fs-forge-cli@{version} create component ... --feature 'name@1.2.3:{"enabled":true}'
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --add-feature 'name#main:{"enabled":true}' --remove-feature other-name --commit
```

Form is `name@version:{...}` or `name#ref:{...}`; `{...}` is a raw JSON object
(use `{}` for no args; the `:` and object are required). These do **not**
fetch or validate against the Feature's schema: run `validate` afterward (below)
to check `args` against the latest schema before landing the change.

## Validating Feature args

`validate -f {claim-file}` (`fs-forge-cookbook.md`) validates every attached
Feature's `args` against that Feature's schema, in addition to the claim's own
schema, types, and enums. Schemas come from `--source` (default: the
firestartr-pro/docs Feature catalog) and follow the cache rules above.
Offline, this succeeds only when every attached Feature's schema is already
cached; otherwise it reports `Feature <name>: ...` and exits 1.

Pass `--source`/`--refresh` to override the defaults (`--refresh` when a cached
schema may be stale):

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file} --source <source> --refresh
```

Run this after any `--feature`/`--add-feature` inline mutation, since those
skip schema validation at write time.
