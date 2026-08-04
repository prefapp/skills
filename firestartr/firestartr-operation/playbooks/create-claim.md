# Create Claim Playbook

Author a new claim body via `fs-forge`, then hand off to `lifecycle` to land it.
Apply defaults from `../reference/reference.md` before calling fs-forge. File path is
`claims/{dir}/{name}.yaml` in the claims repo (see the kind table in
`../reference/reference.md`). Read `../reference/fs-forge-cookbook.md` before
invoking fs-forge.

Ask the client only for what you can't infer or default. Show the proposed command
and the generated file for approval, then run the `lifecycle` create flow.

If the client wants "one like an existing X but with Y different", use
`clone-claim` instead. For a **repo** specifically, check `clone-claim.md`'s
"When to clone vs. create" first — it's the default there, not the exception,
since `create` never lands the change on its own.

## General flow (all kinds)

1. **Discover flags** for the target kind:
   ```bash
   npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json
   ```
   Map client answers + policy defaults from `../reference/reference.md` onto the
   logical claim-field paths returned in the FlagSpec. **Never hardcode a CLI flag
   name** — derive the `name` from the FlagSpec for each value.

2. **Create the claim file:**
   ```bash
   npx @firestartr/fs-forge-cli@{version} create <Kind> \
     --<org-flag>={org} \
     --<flag>=<value> \
     ... \
     -o claims/{dir}/{name}.yaml
   ```
   For complex arrays and union values, write the value to a temporary JSON file
   and use the `name` from the relevant FlagSpec for its `.json` escape-hatch
   flag. Pass that discovered flag name verbatim; never construct or hardcode it.

3. **Validate:**
   ```bash
   npx @firestartr/fs-forge-cli@{version} validate -f claims/{dir}/{name}.yaml
   ```
   Fix any errors before proceeding.

4. Show the generated file to the client for approval, then run the `lifecycle` flow.

## Repository → ComponentClaim  →  `claims/components/{name}.yaml`

**Ask for:** description, owner, system (default `system:default-system`),
visibility (default private), branch strategy (default `none`), features
(default none).

**Verify first:** `owner` and `system` exist; offer to create them if not.
Never use `system:firestartr` unless the client names it.

Default flag values: `../reference/reference.md`.

`features`: use the repeatable `--feature 'name@version:{...}'` /
`'name#ref:{...}'` inline flag (`../reference/fs-forge-cookbook.md` →
"Feature CRUD"), not the `.json` escape hatch — one per Feature. Skips
schema validation; run `validate --source`/`--refresh` after.

## User → UserClaim  →  `claims/users/{name}.yaml`

**Ask for:** display name, email, role (`admin`/`member`, default `member`),
teams to add.

Teams named → add the user to each `GroupClaim`'s root-level `members` in the
**same** PR (`edit-claim`), hydrate the user before the groups.

Default flag values: `../reference/reference.md`.

## Team → GroupClaim  →  `claims/groups/{name}.yaml`

`members` is optional — omit the flag for an empty team, only pass it when
the client names members.

Don't set `sync` unless the client asks.

Non-slug name (uppercase, spaces, non-ASCII): naming normalization rules in
`../reference/reference.md` — `name` gets the slug, `profile.displayName`/
`providers.github.name` keep the original.

Default flag values: `../reference/reference.md`.

## Other kinds

Same flow — discover flags, fill from client answers + policy defaults,
`create`, `validate -f`. Paths, default flag values, and TFWorkspaceClaim's
remote-module discovery are all in `../reference/reference.md`. DomainClaim
has no special defaults.
