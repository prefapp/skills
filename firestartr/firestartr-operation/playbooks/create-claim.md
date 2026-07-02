# Create Claim Playbook

Author a new claim body, then hand off to `lifecycle` to land it. Apply defaults
and naming rules from `../reference/reference.md` before writing. File path is
`claims/{dir}/{name}.yaml` in the claims repo (see the kind table in
`../reference/reference.md`).

Ask the client only for what you can't infer or default. Show the proposed YAML for
approval, then run the `lifecycle` create/edit flow.

## Repository → ComponentClaim  →  `claims/components/{name}.yaml`

Ask for: description, owner (a team or user), system, visibility (default private),
branch strategy (default `none`), features to install (default none).

```yaml
kind: ComponentClaim
version: "1.0"
type: service
lifecycle: production
name: {repo-name}
owner: group:{team}
system: system:{system}
providers:
  github:
    name: {repo-name}
    org: {org}
    description: "{description}"
    visibility: private
    branchStrategy:
      name: none
      defaultBranch: main
    allowAutoMerge: true
    deleteBranchOnMerge: true
    features: []
```

Verify the referenced `owner` group and `system` exist first; if not, offer to
create them in the same change. Feature entries take `name` + (`version` XOR `ref`);
see the features catalog in `../reference/reference.md`.

## User → UserClaim  →  `claims/users/{name}.yaml`

Ask for: display name, email, role (`admin`/`member`, default `member`), and which
teams to add them to. If teams are named, add the user to each `GroupClaim`'s
root-level `members` in the **same** PR (see `edit-claim`), and hydrate the user
before the groups.

```yaml
kind: UserClaim
version: "1.0"
name: {username}
profile:
  displayName: "{display name}"
  email: "{email}"
providers:
  github:
    name: {username}
    org: {org}
    role: member
    sync: { enabled: true, period: 24h }
```

## Team → GroupClaim  →  `claims/groups/{name}.yaml`

```yaml
kind: GroupClaim
version: "1.0"
name: {team-name}
type: business-unit
members:
  - user:{username}
providers:
  github:
    name: {team-name}
    org: {org}
    privacy: closed
    sync: { enabled: true, period: 24h }
```

`members` is **root-level** (never under `providers.github`). If the desired team
name isn't a valid slug (uppercase, spaces, non-ASCII), see the naming
normalization rules in `../reference/reference.md`: `name` gets the slug, `profile.displayName` and
`providers.github.name` keep the original.

## Other kinds

Same shape — `kind`, `version: "1.0"`, `name`, then a `providers` block. Pull the
required/optional fields and defaults from `../reference/reference.md` (which
discloses the full JSON schema per kind):

- **SystemClaim** `claims/systems/` — logical grouping; `domain: domain:{org}-domain`.
- **DomainClaim** `claims/domains/` — top-level business area.
- **SecretsClaim** `claims/secrets/` — ExternalSecrets + PushSecrets.
- **OrgWebhookClaim** `claims/orgwebhooks/` — org-level webhook.
- **TFWorkspaceClaim** `claims/tfworkspaces/` — remote/inline; policy hierarchy in `../reference/reference.md`.
