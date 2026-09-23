# Create Claim Playbook

Author a new claim with `create`, then land it via `lifecycle` — `--commit`
now, or an offline file to the manual flow. Policy defaults and kind paths:
`../reference/reference.md`. Read `../reference/fs-forge-cookbook.md` before
invoking fs-forge.

Ask the client only for what you can't infer or default.

## Fresh construction

Construct with `create` from this request and documented policy
(`../reference/reference.md`). Claim name, provider identity, and needed
refs come from the requested name and that policy — not from another claim.

"Like X": read X (`edit <Kind>-<name> --org={org}`, no mutating flags —
`../reference/fs-forge-edit.md`) for kind and the likeness they asked for
(Feature names, visibility). Fold that into this request. Do not copy X's
YAML, run `fs-forge clone`, or hand-copy a claim file.

The plan is the `create` output — requested fields plus required
identifiers and `../reference/reference.md`'s policy defaults. Never
inherited from a source claim: credentials, vars, Features, annotations,
provider settings (sync, org permissions, merge, technology),
`tfStateKey` — absent unless this request named them. Documented policy
defaults (e.g. the ComponentClaim/UserClaim `sync` block) are defaults,
not inheritance — apply them. Do not bake live claims-repo defaults
into the file; Step 4 previews what the renderer will add later.

## General flow (all kinds)

### Step 1 — Discover flags

`create <Kind> --help --json` (`../reference/fs-forge-mutation-shared.md`).
Map client answers + policy defaults onto FlagSpec paths. Never hardcode a
schema-field flag name; that reference lists the fixed flags safe to
hardcode.

### Step 2 — Pre-check uniqueness

Repo, team, user, or TF workspace: `preflight --create`
(`../reference/fs-forge-preflight.md`) — claims-map and provider. Every
other kind: confirm `<Kind>-<name>` does not already exist via
`../reference/fs-forge-discovery.md`. Claim conflict → tell the client,
suggest `edit`. Provider conflict → stop (no import; same preflight
reference).

### Step 3 — Build the claim in one invocation

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> \
  --org={org} \
  [--<schema-org-flag>={org}] \
  --<flag>=<value> \
  ... \
  > claims/{dir}/{name}.yaml
```

`--org` is control-plane (required for the `--commit` landing run);
`--<schema-org-flag>` is the kind's schema org field if it has one — both
in `../reference/fs-forge-mutation-shared.md` `{org}` passthrough. No
output flag; redirect stdout to save. TFWorkspaceClaim/SecretsClaim need
`--path claims/{...}/{name}.yaml` only with `--commit` (rejected for every
other kind). Complex arrays/unions: temp JSON file + FlagSpec `.json`
escape-hatch `path`, passed verbatim.

```bash
npx @firestartr/fs-forge-cli@{version} validate -f claims/{dir}/{name}.yaml
```

Fix errors before proceeding.

> **Check this first:** `validate -f` passing but `--commit` still
> rejecting the claim — see
> `troubleshooting.md#fs-forge-cli-command-failures`.

### Step 4 — Offer to preview the org's repo-level claim defaults

Needs network and `--org`; skip if the client wants a fully offline
artifact and declines. `create` never applies these itself, committed or
not (`../reference/fs-forge-mutation-shared.md` → "Claim defaults"):

```bash
npx @firestartr/fs-forge-cli@{version} defaults apply -f claims/{dir}/{name}.yaml --org={org}
```

Compare to Step 3's file; tell the client what the platform will fill in,
distinct from the file.

### Step 5 — Show plan, get explicit approval, land

The plan is the Step 3 file plus any Step 4 preview.

- **Landing now** — hand the approved Step 3 command to `lifecycle`'s
  fs-forge-managed flow, which owns the single `--commit` run (with
  `--wait-for-checks`). Re-run it there **without the redirect** so its
  output — including the dispatched provisioning URL — stays visible.
- **Offline artifact** — hand Step 3's validated file to `lifecycle`'s
  manual flow.

## Repository → ComponentClaim

**Ask for:** description, owner, system (default `system:default-system`),
visibility (default private), branch strategy (default `none`), features
(default none).

**Verify first:** `owner` and `system` exist; offer to create them if not.
Never `system:firestartr` unless the client names it.

`features`: repeatable `--feature 'name@version:{...}'` or
`--feature 'name#ref:{...}'` (`../reference/fs-forge-features.md`), not
the `.json` hatch — one per Feature. Skips schema validation; run
`validate --source`/`--refresh` after.

## User → UserClaim

**Ask for:** display name, email, role (`admin`/`member`, default `member`),
teams to add.

Teams named → add the user to each `GroupClaim`'s root-level `members` in
the **same** PR (`edit-claim`); hydrate the user before the groups.

## Team → GroupClaim

`members` is optional — omit the flag unless the client names members.
Set `sync` only when the client asks.

Non-slug name: `../reference/reference.md` naming rules (`name` slug;
`profile.displayName` / `providers.github.name` keep the original).

## TF workspace → TFWorkspaceClaim

**Ask for:** name; workspace name (`providers.terraform.name` — can differ
from the claim name; propose the claim name as default). Module, values
(from the module's `variables.tf`), policy (default `apply`).

Required beyond the shared flow: terraform `name`, `source`, `values.json`
(`{}` when the module takes no inputs), and `context.providers.json` (`[]`
when no provider context is needed).

Remote module discovery is the default (`../reference/gh-cookbook.md` →
"Discover Terraform modules"). `inline` is equally valid —
`../reference/reference.md` → "Terraform modules".

Pass values through the FlagSpec `.json` hatch for the terraform values
field (Step 1).

`--commit` is mandatory (no offline artifact) and requires
`--path claims/tfworkspaces/{name}.yaml`
(`../reference/fs-forge-mutation-shared.md` `--commit` warning — it
hydrates; no manual hydrate after).

## Other kinds

Same flow. Paths and policy defaults: `../reference/reference.md`.
DomainClaim has no special defaults.
