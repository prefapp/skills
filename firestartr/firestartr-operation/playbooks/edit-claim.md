# Edit Claim Playbook

Change an existing claim, then land it via `lifecycle`. Prefer `fs-forge edit`
over hand-editing the file — see `../reference/fs-forge-cookbook.md` for the
invocation idiom. Fall back to the manual `gh`-based edit only when a field
isn't reachable through `edit`'s flags.

## Primary flow — `fs-forge edit`

1. **Read the current claim:** `edit <Kind>-<name> --org={org}` with no
   mutating flags prints the full current YAML.
2. **Discover flags** for the target kind via
   `create <Kind> --help --json` (never `edit --help --json` — see the
   cookbook).
3. **Dry-run** the change: same command with the relevant `--<flag>=<value>`
   / `--unset <path>` and `--diff`, no `--commit`. Fix any validation errors.
4. **Show the diff to the client and get approval.**
5. **Re-run with `--commit`.** Read the cookbook's `--commit` warning first —
   it commits *and* provisions *and* hydrates the claim in one shot; there is
   nothing left to do afterward unless the client asks for status or a manual
   re-hydrate.

Array fields (e.g. `members`) are **replaced**, not appended to — always
compute the full desired array from what step 1 read before passing it.

## Team membership (GroupClaim)

`members` is a **root-level** array of `user:{username}` references — never under
`providers.github`, never under `spec`.

- **Add**: read the current `members` (step 1), append `user:{name}`, pass the
  **whole** array back. Each user must already have a UserClaim; if not, create
  it first and hydrate it before editing the group.
- **Remove**: read the current `members`, drop the entries, pass the whole
  remaining array. If it becomes empty, use `--unset members` instead.
- **List / check**: step 1's read is the answer — no PR needed for a read-only ask.

Adding the same users to several teams → one `edit` per `GroupClaim`, each
producing its own dry-run/approval/commit cycle (they're separate commits and
separate provision runs).

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
- `owner` is required — you can change it, never unset it.
- `maintainedBy`, `additionalRules[].owners`, `owner`, `platformOwner` reference
  in-org users/groups (must have claims). Only `overrides.*` and `maintainedBy`
  accept `collaborator:` — external logins that need **no** UserClaim.
- Array fields replace, so read the current value (step 1) before editing one;
  empty an array → `--unset` its path instead of passing `[]`.
- Change a collaborator's permission by moving them between the `additional*`
  arrays (read current, edit, pass whole arrays back).

Example resulting file (root-level `maintainedBy`, `providers.github`
CODEOWNERS + collaborators):

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

Same procedure for any existing claim of any kind: read (step 1), dry-run the
flag change, get approval, commit. Consult `../reference/reference.md` for the
field's kind, level, and format.

## Manual fallback

Only when the field you need to change isn't reachable through `edit`'s
flags (e.g. rewriting one element inside an array of objects without
recomputing the whole array via the `.json` escape hatch): read the file
(`gh-cookbook.md` → "Read a file"), edit it, write the **whole** file back
preserving everything else, validate
(`npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}`), then land
it via `lifecycle`'s manual flow — `edit`'s built-in commit isn't available
for a hand-edited file.
