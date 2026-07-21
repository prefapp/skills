# Edit Claim Playbook

Change an existing claim in place, then land it via `lifecycle`. Both concerns
below mutate one claim file: read it, change the targeted field(s), write the
**whole** file back preserving everything else, then **validate before proceeding**:
```bash
fs-forge validate -f {claim-file}
```
Fix any errors before running the `lifecycle` flow. See `../reference/fs-forge-cookbook.md`
for the fs-forge invocation idiom.

Read the current file first (`gh-cookbook.md` → "Read a file"), edit, and keep
every unrelated field intact.

## Team membership (GroupClaim)

`members` is a **root-level** array of `user:{username}` references — never under
`providers.github`, never under `spec`.

- **Add**: append `user:{name}` entries. Each user must already have a UserClaim;
  if not, create it in the same PR and hydrate the user before the group.
- **Remove**: drop the entries. If `members` becomes empty, remove the key.
- **List / check**: read the file and inspect `members` (a read-only ask needs no PR).

Adding the same users to several teams → one branch, one PR touching each group
file, then hydrate each `GroupClaim` (kind + name).

## Repository permissions (ComponentClaim)

Seven fields, at three levels. Placing a field at the wrong level triggers a
"must NOT have additional properties" schema error — level matters.

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
- `owner` is required — you can change it, never remove it.
- `maintainedBy`, `additionalRules[].owners`, `owner`, `platformOwner` reference
  in-org users/groups (must have claims). Only `overrides.*` and `maintainedBy`
  accept `collaborator:` — external logins that need **no** UserClaim.
- Empty an array → remove the key; empty `overrides` → remove `overrides`.
- Change a collaborator's permission by moving them between the `additional*` arrays.

Example (root-level `maintainedBy`, `providers.github` CODEOWNERS + collaborators):

```yaml
owner: group:my-team
maintainedBy:
  - group:another-team
  - collaborator:external-user
platformOwner: group:platform-team
providers:
  github:
    additionalRules:
      - path: /docs
        owners: [group:docs-team]
    overrides:
      additionalWriters:
        - collaborator:external-dev
```

## Any other field

Same procedure for any existing claim of any kind: read, change the field, write
the whole file back, land via `lifecycle`. Consult `../reference/reference.md` for
the field's kind, level, and format.
