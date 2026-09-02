# fs-forge Features Reference

ComponentClaim-only: discovering, attaching, editing, and removing Feature
references. Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

## Discovering the feature catalog

Browsing what's available (names, READMEs, schemas, versions, changelogs) is
part of the feature-matching flow, not a CRUD operation — see
`../playbooks/feature-advisor.md` for the commands and the full flow.

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
(`--source`, defaults to `firestartr-pro/docs`) and returns a `CommandHelpJson`
object whose `.flags[]` includes `args.<field>` entries alongside the fixed
`name`/`version`/`ref`/`repo` flags — same discovery idiom as `create <Kind>
--help --json` (`fs-forge-mutation-shared.md`). The reference's own
`version`/`ref` only pins what the claim stores; it never selects which
schema validates `args`.

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
- `--no-wait` skips waiting for the provision workflow a `--commit`
  dispatches; `--json` outputs structured JSON. Both exist on `add`/`edit`/
  `remove`.
- `--args.json='{...}'` is the raw escape hatch when you'd rather pass the
  whole `args` object as JSON than discover each field flag.

### Remove / list — no schema resolution

```bash
npx @firestartr/fs-forge-cli@{version} features remove <component> --org={org} --name <feature> --commit
npx @firestartr/fs-forge-cli@{version} features list <component> --org={org} --json
```

`remove` needs no `--source`/schema fetch.

## Inline, unvalidated alternative — `create`/`edit`

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

## Deep validation

Plain `validate -f {claim-file}` (`fs-forge-cookbook.md`) checks the claim's
own schema, types, and enums, but not Feature `args` against their schemas.
Add `--source`/`--refresh` to also validate every attached Feature's `args`
against its latest schema (`--refresh` bypasses the schema cache):

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file} --source <source> --refresh
```

Run this after any `--feature`/`--add-feature` inline mutation, since those
skip schema validation at write time.
