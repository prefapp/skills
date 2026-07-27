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

**Ask for:** description, owner (a team or user), system (default
`system:default-system`), visibility (default private), branch strategy (default
`none`), features to install (default none).

**Verify first:** the referenced `owner` group and `system` exist; if not, offer to
create them in the same change. **Never** use `system:firestartr` unless the client
explicitly names it.

**Default flag values** (see `../reference/reference.md`; these are logical
values, not literal CLI flag names): `type=service`, `lifecycle=production`,
GitHub provider `visibility=private`, `branchStrategy.name=none`,
`branchStrategy.defaultBranch=main`, `allowAutoMerge=true`,
`deleteBranchOnMerge=true`, `sync.enabled=true`, `sync.period=24h`. Map each to
its discovered FlagSpec path and `name`.

For `features`, use the repeatable `--feature name@version:{...}` /
`name#ref:{...}` inline flag (see `../reference/fs-forge-cookbook.md` →
"Feature CRUD") instead of the general `.json` escape hatch — one flag per
Feature, `{...}` is a raw JSON `args` object and may be omitted. This skips
schema validation of `args`; run `validate` with `--source`/`--refresh`
afterward to check them against each Feature's latest schema.

## User → UserClaim  →  `claims/users/{name}.yaml`

**Ask for:** display name, email, role (`admin`/`member`, default `member`), and
which teams to add them to.

If teams are named, add the user to each `GroupClaim`'s root-level `members` in the
**same** PR (see `edit-claim`), and hydrate the user before the groups.

**Default flag values:** GitHub provider `role=member`, `sync.enabled=true`,
`sync.period=24h`; map each to its discovered FlagSpec path and `name`.

## Team → GroupClaim  →  `claims/groups/{name}.yaml`

A group may be created with **no members** — `members` is optional. Omit the
`members` flag entirely for an empty team; only pass it when the client names members.

Do **not** set `sync` unless the client explicitly asks for it.

If the desired team name isn't a valid slug (uppercase, spaces, non-ASCII), see the
naming normalization rules in `../reference/reference.md`: `name` gets the slug,
`profile.displayName` and `providers.github.name` keep the original.

**Default flag values:** `type=business-unit`, GitHub provider
`privacy=closed`; map each to its discovered FlagSpec path and `name`.

## Other kinds

Same flow — discover flags, fill from client answers + policy defaults,
`npx @firestartr/fs-forge-cli@{version} create`,
`npx @firestartr/fs-forge-cli@{version} validate -f`. Pull defaults from
`../reference/reference.md`:

- **SystemClaim** `claims/systems/` — `domain=domain:{org}-domain`.
- **DomainClaim** `claims/domains/` — top-level business area; no special defaults.
- **SecretsClaim** `claims/secrets/` — `lifecycle=production`, external-secrets
  provider `refreshInterval=24h`.
- **OrgWebhookClaim** `claims/orgwebhooks/` — GitHub-provider
  `webhook.active=true`, `webhook.contentType=json`.
- **TFWorkspaceClaim** `claims/tfworkspaces/` — Terraform-provider
  `source=remote`, `policy=apply`, `sync.policy=observe`, `sync.period=24h`,
  `sync.enabled=true`, `backend=firestartr-terraform-state`. For a **remote**
  module, discover it from `prefapp/tfm` (always the `prefapp` org, regardless of
  client's org): list
  modules, read the module's `variables.tf` for inputs, pin the latest
  `{module}-vX.Y.Z` tag. Commands in `../reference/gh-cookbook.md`.
