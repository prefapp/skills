# Reference

Stable platform facts carried inside the skill (portable across deployments).
Everything org-specific comes from `firestartr-config.yaml`; everything here does not.

## fs-forge

Runnable invocation and validation idioms live in `fs-forge-cookbook.md` (sibling of
this file). Read it before calling fs-forge or writing any claim.

## Kind ↔ intent ↔ path

The client never names a kind — you pick it from the intent.

| Intent | Kind | Path | Hydration name |
|---|---|---|---|
| a repository | ComponentClaim | `claims/components/{name}.yaml` | repo name |
| a user / org member | UserClaim | `claims/users/{name}.yaml` | username |
| a team | GroupClaim | `claims/groups/{name}.yaml` | team slug |
| a system grouping | SystemClaim | `claims/systems/{name}.yaml` | claim name |
| a business domain | DomainClaim | `claims/domains/{name}.yaml` | claim name |
| secrets | SecretsClaim | `claims/secrets/{name}.yaml` | claim name |
| an org webhook | OrgWebhookClaim | `claims/orgwebhooks/{name}.yaml` | claim name |
| a terraform workspace | TFWorkspaceClaim | `claims/tfworkspaces/{name}.yaml` | claim name |

## Naming rules

- Pattern `^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$`, max 63 chars.
- Lowercase alphanumeric + `. - _`; must start and end alphanumeric.

**Normalizing a non-compliant name** (uppercase, spaces, non-ASCII): put a
transliterated slug in `name`, keep the original in `profile.displayName` and (for
GitHub-backed kinds) `providers.github.name` — GitHub teams accept Unicode.

| Desired | `name` (slug) | `displayName` / `github.name` |
|---|---|---|
| My Team! | my-team | My Team! |
| ひかり | grupo-hikari | ひかり |
| Équipe Réseau | equipe-reseau | Équipe Réseau |

## Reference formats

`user:{name}` · `group:{name}` · `system:{name}` · `domain:{name}` ·
`component:{name}` · `ref:secretsclaim:{claim}:{key}` · maintainer
`(user|group|collaborator):{name}`.

## Validation split

fs-forge validates syntax only (schema, types, enums) — via `npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}`.
`edit`/`clone` run this same validation automatically before `--commit` and
refuse to commit an invalid claim; `clone` also checks name-uniqueness itself
(errors if the target `<Kind>-<name>` already exists). The skill is still
responsible for:
- **References** — `user:`/`group:`/`system:`/… values point at claims that
  actually exist.
- **Uniqueness** — a `create` (file-based, no claims-map lookup) would not
  duplicate an existing claim.
- **Naming normalization** — the slug, displayName, and github.name rules
  described above.

## Default flag values for new claims

These are logical claim-field values, not literal CLI flag names. Map them to the
matching FlagSpec paths and use each returned `name` when calling
`npx @firestartr/fs-forge-cli@{version} create`.
All default `version: "1.0"`. The `{org}` flag value (see `fs-forge-cookbook.md`)
is resolved from `firestartr-config.yaml` and passed to the kind's org field flag.

- **ComponentClaim**: `type: service`, `lifecycle: production`,
  `system: system:default-system` (never `system:firestartr` unless the client
  names it), GitHub provider: `visibility: private`,
  `branchStrategy: {name: none, defaultBranch: main}`, `allowAutoMerge: true`,
  `deleteBranchOnMerge: true`, `features: []`,
  `sync: {enabled: true, period: 24h}`.
- **UserClaim**: GitHub provider: `role: member`,
  `sync: {enabled: true, period: 24h}`.
- **GroupClaim**: `type: business-unit`, GitHub provider: `privacy: closed`.
  Only set GitHub provider `sync` when the client explicitly asks for it.
- **SystemClaim**: `domain: domain:{org}-domain`.
- **SecretsClaim**: `lifecycle: production`, external-secrets provider:
  `refreshInterval: 24h`.
- **TFWorkspaceClaim**: Terraform provider: `source: remote`, `policy: apply`,
  `sync: {policy: observe, period: 24h, enabled: true}`,
  `backend: firestartr-terraform-state`.
- **OrgWebhookClaim**: GitHub provider:
  `webhook: {active: true, contentType: json}`.

## Terraform modules (TFWorkspaceClaim, remote source)

Remote modules live in **`prefapp/tfm`** — the canonical module repo, always the
`prefapp` org **regardless of the client's organization**. Discover, never guess
(commands in `gh-cookbook.md`): list `modules/`, read the module's `variables.tf`
for inputs, pin the latest per-module release tag (`{module}-vX.Y.Z`).

`module: git::https://github.com/prefapp/tfm.git//modules/{module}?ref={module}-vX.Y.Z`

Common intent → module / `resourceType`: S3 bucket → `aws-s3` / `aws-s3`,
RDS → `aws-rds`, EKS → `aws-eks` / `aws-eks`, AKS → `azure-aks`, VPC → `aws-vpc`.

## Features catalog (ComponentClaim)

Each entry: `name` + (`version` XOR `ref`), optional `repo`, `args`.

| Feature | Version | Purpose |
|---|---|---|
| claims_repo | 1.19.2 | hydrate / delete / import workflows |
| catalog_repo | 1.3.2 | catalog hydration |
| state_github | 1.2.0 | state-github hydration |
| state_infra | 1.2.0 | state-infra hydration |
| state_repo_apps | 3.8.3 | K8s app state repos (ArgoCD) |
| build_and_dispatch_docker_images | 5.3.2 | Docker CI/CD |
| charts_repo | 1.4.3 | Helm charts |
| tech_docs | 0.10.2 | technical docs |
| release_please | 1.4.1 | automated releases |
| issue_templates | 1.3.0 | issue templates |
| terraform-infra | 1.8.2 | terraform infra |
| state_repo | 2.2.2 | general state repo |
| state_repo_sys_services | 2.3.8 | cluster sys-services state |
| features_repo | 0.3.1 | features repo |
| cloudfront_s3_build_and_deploy | 0.2.0 | CloudFront/S3 deploy |

## Branch strategies

- **none**: default branch `main`, no protections.
- **gitflow**: adds `dev`; both `main` and `dev` get signed commits, 1 approval,
  dismiss-stale, require CODEOWNERS.

## Terraform policy hierarchy (most → least permissive)

`full-control` (create+update+delete+sync) → `apply` (create+update+sync, alias
create-update-only) → `create-only` (create+sync) → `observe` (sync/plan only).
The sync policy may never exceed the general policy.

## Claim → state mapping

| Claim | State repo | State resource |
|---|---|---|
| ComponentClaim | state-github | FirestartrGithubRepository (+Feature, +SecretsSection) |
| GroupClaim | state-github | FirestartrGithubGroup |
| UserClaim | state-github | FirestartrGithubMembership |
| OrgWebhookClaim | state-github | FirestartrGithubOrgWebhook |
| SecretsClaim | state-infra | ExternalSecret |
| TFWorkspaceClaim | state-infra | FirestartrTerraformWorkspace |
| all kinds | catalog | Domain / System / Component / Group / User / Resource |

State files carry `metadata.annotations.firestartr.dev/claim-ref` linking back to
their source claim.
