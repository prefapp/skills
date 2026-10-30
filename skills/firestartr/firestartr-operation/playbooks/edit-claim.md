# Edit Claim Playbook

Change an existing claim via `fs-forge edit` (`../reference/fs-forge-edit.md`), then `lifecycle`. Use manual `gh` edit only when `edit` flags cannot reach a field.

## Primary flow: `fs-forge edit`

### Step 1: Read the current claim

`edit <Kind>-<name> --org={org}` with no mutating flags prints the full
current YAML.

### Step 2: Discover flags

`create <kind> --help --json` for the target kind (never `edit --help
--json`: see the cookbook's mutation-shared reference).

### Step 3: Dry-run the change

Same command with relevant `--<flag>=<value>` / `--unset <path>`, `--diff`, and always `--show-defaults`. Fix validation errors, show the Claim diff and get approval (`../reference/fs-forge-edit.md`).

> **Check this first:** an unexpected diff, or a rejected `--commit`;
> see `troubleshooting.md#fs-forge-cli-command-failures`.

### Step 4: Re-run with `--commit`

See `../reference/fs-forge-mutation-shared.md`'s `--commit` warning.

Array fields (e.g. `members`) **replace**, not append: compute the full desired array from Step 1.

## Team membership (GroupClaim)

`members` is a **root-level** array of `user:{username}` references, never under
`providers.github`, never under `spec`.

- **Add:** append `user:{name}` to current `members` and pass the **whole** array. Each user needs a UserClaim; create and hydrate it before editing the group if absent.
- **Remove:** drop entries from current `members` and pass the whole remainder; if empty, use `--unset members`.
- **List / check:** Step 1's read suffices; no PR.

For several teams, use one `edit` per `GroupClaim`, each with its own dry-run/approval/commit cycle and provision run.

## Repository permissions (ComponentClaim)

Wrong field level triggers "must NOT have additional properties".

| Field | Level | Format | Purpose |
|---|---|---|---|
| `owner` (required) | root | `user:` or `group:` | primary owner |
| `maintainedBy` | root | `user:` / `group:` / `collaborator:` | extra maintainers |
| `platformOwner` | root | `user:` or `group:` | platform/infra team |
| `additionalRules` | `providers.github` | `{path, owners[]}` | CODEOWNERS entries |
| `overrides.additionalAdmins` | `providers.github.overrides` | `collaborator:{login}` | external admin |
| `overrides.additionalWriters` | `providers.github.overrides` | `collaborator:{login}` | external write |
| `overrides.additionalReaders` | `providers.github.overrides` | `collaborator:{login}` | external read |

Rules:
- `owner` is required: you can change it, never unset it.
- `maintainedBy`, `additionalRules[].owners`, `owner`, `platformOwner` reference
  in-org users/groups (must have claims). Only `overrides.*` and `maintainedBy`
  accept `collaborator:`: external logins that need **no** UserClaim.
- Read arrays before editing; empty array → `--unset` its path, not `[]`.
- Change collaborator permission by moving them between `additional*` arrays; pass whole arrays.

## TFWorkspaceClaim

Values, module and policy require `--commit` (no offline path); it hydrates, so no manual hydrate after (`../reference/fs-forge-mutation-shared.md`). Create vocabulary: `create-claim.md` TF workspace section.

- **values:** Step 1 is the current object. Rebuild it from the module's
  `variables.tf` plus the client's changes; pass through the discovered
  `.json` hatch.
- **module:** in-place. Discover the new module
  (`../reference/gh-cookbook.md` → "Discover Terraform modules"), rebuild
  values from the new `variables.tf`, extra confirmation because inputs
  change. `inline`: `../reference/reference.md` → "Terraform modules".
- **policy:** flag change. Hierarchy in `../reference/reference.md`.

## Any other field

Any kind: read (Step 1), dry-run, approve, commit. Field kind/level/format: `../reference/reference.md`.

## Features (ComponentClaim)

Don't recompute `features[]` by hand: use `features add`/`edit`/`remove`/`list` (`../reference/fs-forge-features.md` → "Feature CRUD"); they target one reference and derive `args.*` flags. For `add`/`edit`/`remove`: dry-run without `--commit` → client approval → `--commit`. `list` is read-only. Use inline `edit --add-feature`/`--remove-feature` only with known valid `args` and no need for schema-derived flags; run `validate` before landing.

## Manual fallback

Only if `edit` flags cannot reach the field (e.g. one array-of-objects element without dedicated CRUD, via `.json`): read (`../reference/gh-cookbook.md` → "Read a file"), edit, write the **whole** file preserving everything else, validate (`npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}`), then land via `lifecycle` manual flow. Built-in `edit` commit cannot land hand edits.
