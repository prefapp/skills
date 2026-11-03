# fs-forge Features Reference

ComponentClaim-only: discover, attach, edit, and remove Feature references.

## Discovering the feature catalog

Names, READMEs, schemas, versions and changelogs: `../playbooks/feature-advisor.md`.

## Feature CRUD (ComponentClaim only)

Dedicated subcommands mutate one `features[]` entry at a time. Positional `<component>` is the **bare** name, not `ComponentClaim-<name>`. Targets:

- `<component> --org={org}`: resolved through the claims-map as
  `ComponentClaim-<component>`.
- `-f {claim-file}`: a local ComponentClaim YAML file; skips the claims-map.

All four subcommands error if the claim isn't a ComponentClaim.

### Add / edit: schema-derived `args.*` flags

```bash
npx @firestartr/fs-forge-cli@{version} features add --name <feature> --help --json
```

This discovers `args.*` from the Feature's **latest published schema**. The reference's `version`/`ref` pins the claim, not the schema used to validate args.

```bash
npx @firestartr/fs-forge-cli@{version} features add <component> --org={org} \
  --name <feature> --version <v> \
  --args.<field>=<value> ... \
  --commit
```

- `features add` requires exactly one of `--version` / `--ref`; `features edit` retains the pin when both are omitted.
- `features add` errors on existing name; `features edit` errors on missing name and preserves unpassed `args`, without reapplying schema defaults.
- Schemas cache by Feature name (`FS_FORGE_FEATURE_CACHE_DIR` overrides location); `--refresh` bypasses stale cache.
- Other flags and relationships: each subcommand's `--help --json`.

### Remove / list: no schema resolution

```bash
npx @firestartr/fs-forge-cli@{version} features remove <component> --org={org} --name <feature> --commit
npx @firestartr/fs-forge-cli@{version} features list <component> --org={org} --json
```

`remove` needs no `--source`/schema fetch.

## Inline, unvalidated alternative: `create`/`edit`

To attach on create or add/remove without a schema round-trip, use repeatable inline flags:

```bash
npx @firestartr/fs-forge-cli@{version} create component ... --feature 'name@1.2.3:{"enabled":true}'
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --add-feature 'name#main:{"enabled":true}' --remove-feature other-name --commit
```

Form: `name@version:{...}` or `name#ref:{...}`; the colon and JSON object are required, including `{}` for no args. Inline flags do **not** fetch or validate the Feature schema: run `validate` before landing (`--refresh` for the latest schema).

## Validating Feature args

`validate -f {claim-file}` (`fs-forge-cookbook.md`) validates all attached Feature args too. Offline with the default source, every attached Feature schema must already be cached; otherwise validation fails.

Pass `--source`/`--refresh` to override the defaults. Plain `validate` reuses a
cached schema by Feature name whatever `--source` says, so add `--refresh` to
check against the latest schema or when switching `--source`:

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file} --source <source> --refresh
```

Run this after any `--feature`/`--add-feature` inline mutation, since those
skip schema validation at write time.
