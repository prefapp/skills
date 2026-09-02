# Create Claim Playbook

Author a new claim body via `fs-forge`, then land it — immediately via
`--commit`, or as an offline file handed to `lifecycle`'s manual flow. Apply
defaults from `../reference/reference.md` before calling fs-forge. File path is
`claims/{dir}/{name}.yaml` in the claims repo (see the kind table in
`../reference/reference.md`). Read `../reference/fs-forge-cookbook.md` before
invoking fs-forge.

Ask the client only for what you can't infer or default.

If the client wants "one like an existing X but with Y different", use
`clone-claim` instead. For a **repo** specifically, check `clone-claim.md`'s
"When to clone vs. create" first — it's the default there, not the exception.

## General flow (all kinds)

### Step 1 — Discover flags

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json
```

Map client answers + policy defaults from `../reference/reference.md` onto the
logical claim-field paths returned in the FlagSpec. **Never hardcode a CLI flag
name** for a schema field — derive the `path` from the FlagSpec for each value
(`../reference/fs-forge-mutation-shared.md` lists the fixed flags that are safe to
hardcode).

### Step 2 — Pre-check uniqueness

For a repo, team, user, or TF workspace, run `preflight --create`
(`../reference/fs-forge-preflight.md`) before building a plan — it covers
both a claims-map conflict and a same-named resource already at the
provider. Every other kind: confirm `<Kind>-<name>` doesn't already exist
via `../reference/fs-forge-discovery.md`'s discovery commands instead. Tell
the client and suggest `edit` on a claim conflict; on a provider conflict,
stop and explain — there's no import path yet
(`../reference/fs-forge-preflight.md`).

### Step 3 — Build the claim in one invocation

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> \
  --org={org} \
  [--<schema-org-flag>={org}] \
  --<flag>=<value> \
  ... \
  > claims/{dir}/{name}.yaml
```

`--org` is the control-plane flag (harmless here, required once Step 5 adds
`--commit`); `--<schema-org-flag>` is the kind's own schema org field, if it
has one — both are explained in `../reference/fs-forge-mutation-shared.md`'s
"{org} passthrough". There's no output flag — the redirect above is the
only way to save it; `create` prints the full new claim, so redirecting
stdout is the whole step. TFWorkspaceClaim/SecretsClaim also need
`--path claims/{...}/{name}.yaml` (rejected for every other kind; only
required once `--commit` is added). For complex arrays and union values,
write the value to a temporary JSON file and use the `path` from the
relevant FlagSpec for its `.json` escape-hatch flag — pass that discovered
path verbatim, never construct or hardcode it. Then validate:

```bash
npx @firestartr/fs-forge-cli@{version} validate -f claims/{dir}/{name}.yaml
```

Fix any errors before proceeding.

> **Check this first:** `validate -f` passing but `--commit` still
> rejecting the claim — see
> `troubleshooting.md#fs-forge-cli-command-failures`.

### Step 4 — Offer to preview the org's repo-level claim defaults

Needs network and `--org`, so skip it if the client wants a fully offline
artifact and declines. `create` never applies these itself, committed or
not:

```bash
npx @firestartr/fs-forge-cli@{version} defaults apply -f claims/{dir}/{name}.yaml --org={org}
```

Compare its output against Step 3's file and tell the client what the
platform will additionally fill in (`../reference/fs-forge-mutation-shared.md` →
"Claim defaults"), distinct from the file itself.

### Step 5 — Show the client the file and any defaults preview, then land it

- **Landing now** — re-run Step 3's command **without the redirect** (so
  its output — including the dispatched provisioning URL — stays visible)
  with `--commit` appended (see
  `../reference/fs-forge-mutation-shared.md`'s `--commit` warning); the
  `lifecycle` playbook's fs-forge-managed flow takes it from there.
- **Offline artifact instead** — hand off Step 3's validated file to
  `lifecycle`'s manual flow.

## Repository → ComponentClaim  →  `claims/components/{name}.yaml`

**Ask for:** description, owner, system (default `system:default-system`),
visibility (default private), branch strategy (default `none`), features
(default none).

**Verify first:** `owner` and `system` exist; offer to create them if not.
Never use `system:firestartr` unless the client names it.

Default flag values: `../reference/reference.md`.

`features`: use the repeatable `--feature 'name@version:{...}'` or
`--feature 'name#ref:{...}'` inline flag (`../reference/fs-forge-features.md` →
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

## TF workspace → TFWorkspaceClaim  →  `claims/tfworkspaces/{name}.yaml`

**Ask for:** name; workspace name (`providers.terraform.name` — can
differ from the claim name; propose the claim name as default). Module,
values (from the module's `variables.tf`), policy (default `apply`).

Required beyond the shared flow: terraform `name`, `source`, `values.json`
(`{}` when the module takes no inputs), and `context.providers.json` (`[]`
when no provider context is needed).

Remote module discovery is the default path (`../reference/gh-cookbook.md`
→ "Discover Terraform modules"). `inline` is equally valid —
`../reference/reference.md` → "Terraform modules".

Pass values through the FlagSpec `.json` hatch for the terraform values
field (Step 1).

`--commit` is mandatory (no offline artifact path) and requires
`--path claims/tfworkspaces/{name}.yaml`. See
`../reference/fs-forge-mutation-shared.md`'s `--commit` warning — it
hydrates; no manual hydrate after.

Default flag values: `../reference/reference.md`.

## Other kinds

Same flow — discover flags, fill from client answers + policy defaults,
`create`, `validate -f`. Paths and default flag values are in
`../reference/reference.md`. DomainClaim has no special defaults.
