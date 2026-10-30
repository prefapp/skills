# Create Claim Playbook

Author with `create`; land via `lifecycle` (`--commit` now or offline file to manual flow). Policy: `../reference/reference.md`; kind facts: `kinds show <id> --json`. Read `../reference/fs-forge-cookbook.md` before invoking fs-forge.

Ask the client only for what you can't infer or default.

## Fresh construction

Construct from the request and policy (`../reference/reference.md`): derive name, provider identity and refs from those, not another claim.

"Like X": read X (`edit <Kind>-<name> --org={org}`, no mutating flags; `../reference/fs-forge-edit.md`) for kind and requested likeness (Feature names, visibility); don't copy its YAML or hand-copy a claim file.

Plan = `create` output with requested fields, required identifiers and policy defaults. Never inherit credentials, vars, Features, annotations, provider settings (sync, org permissions, merge, technology), or `tfStateKey`; omit unless requested. Apply documented policy defaults (e.g. ComponentClaim/UserClaim `sync`), but don't bake in live claims-repo defaults; Step 4 previews the renderer's additions.

## General flow (all kinds)

### Step 1: Discover flags

`create <kind> --help --json` (`../reference/fs-forge-mutation-shared.md`).
Map client answers + policy defaults onto FlagSpec paths. Never hardcode a schema-field flag name; discover fixed flags from command help too.

### Step 2: Pre-check uniqueness

Non-null kind `preflight` → `preflight --create` (claims-map and provider; `../reference/fs-forge-preflight.md`). Otherwise check `<Kind>-<name>` via `../reference/fs-forge-discovery.md`. Claim conflict → tell client, suggest `edit`; provider conflict → stop (no import).

### Step 3: Build the claim in one invocation

```bash
npx @firestartr/fs-forge-cli@{version} create <kind> \
  --org={org} \
  [--<schema-org-flag>={org}] \
  --<flag>=<value> \
  ... \
  > {preview-file}
```

`--org` is control-plane (required for the `--commit` landing run);
`--<schema-org-flag>` is the kind's schema org field if it has one: both
in `../reference/fs-forge-mutation-shared.md` `{org}` passthrough. No
output flag; redirect stdout to `{preview-file}`, a `mktemp` path outside the
repo (one per claim, reused in Steps 4-5). For `requiresPath: true`, discover the destination convention from existing claims; if none exists, ask the client for a normalized `claims/{...}/{name}.yaml` path. Pass `--path` on `--commit` only for these kinds; others reject it. Complex arrays/unions: temp JSON file + FlagSpec
`.json` escape-hatch `path`, passed verbatim.

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {preview-file}
```

Fix errors before proceeding.

> **Check this first:** `validate -f` passing but `--commit` still
> rejecting the claim: see
> `troubleshooting.md#fs-forge-cli-command-failures`.

### Step 4: Offer to preview the org's repo-level claim defaults

Needs network and `--org`; skip if the client wants a fully offline artifact and declines. `create` never applies these (`../reference/fs-forge-mutation-shared.md` → "Claim defaults"):

```bash
npx @firestartr/fs-forge-cli@{version} defaults apply -f {preview-file} --org={org}
```

Compare to Step 3's file; tell the client what the platform will fill in,
distinct from the file.

### Step 5: Show plan, get explicit approval, land

The plan is the Step 3 file plus any Step 4 preview.

- **Landing now:** hand the approved Step 3 command to `lifecycle`'s fs-forge-managed flow for its single `--commit` run; rerun **without redirect** to show output and provisioning URL.
- **Offline artifact:** hand Step 3's validated `{preview-file}` to `lifecycle`'s manual flow.

## Repository → ComponentClaim

**Ask for:** description, owner, system (default `system:default-system`),
visibility (default private), branch strategy (default `none`), features
(default none).

**Verify first:** `owner` and `system` exist; offer to create them if not.
Never `system:firestartr` unless the client names it.

`features`: repeatable `--feature 'name@version:{...}'` or
`--feature 'name#ref:{...}'` (`../reference/fs-forge-features.md`), not
the `.json` hatch: one per Feature. Skips schema validation; run
`validate` after.

## User → UserClaim

**Ask for:** display name, email, role (`admin`/`member`, default `member`),
teams to add.

Teams named → add the user to each `GroupClaim`'s root-level `members` in
the **same** PR (`edit-claim`); hydrate the user before the groups.

## Team → GroupClaim

`members` is optional: omit the flag unless the client names members.
Set `sync` only when the client asks.

Non-slug name: `../reference/reference.md` naming rules (`name` slug;
`profile.displayName` / `providers.github.name` keep the original).

## TF workspace → TFWorkspaceClaim

**Ask for:** name; workspace name (`providers.terraform.name` may differ; propose claim name); module, values (from its `variables.tf`), policy (default `apply`).

Required beyond the shared flow: terraform `name`, `source`, `values.json`
(`{}` when the module takes no inputs), and `context.providers.json` (`[]`
when no provider context is needed).

Remote discovery is default (`../reference/gh-cookbook.md` → "Discover Terraform modules"); `inline` is equally valid (`../reference/reference.md` → "Terraform modules"). Pass values through the discovered terraform-values `.json` hatch (Step 1).

`--commit` is mandatory (no offline artifact); choose `--path` as in Step 3.
It hydrates: no manual hydrate after (`../reference/fs-forge-mutation-shared.md`).
