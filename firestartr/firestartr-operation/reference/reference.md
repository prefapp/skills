# Reference

Stable platform facts carried inside the skill (portable across deployments).
Everything org-specific comes from `organization.yaml`; everything here does not.

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

## Defaults for new claims

All default `version: "1.0"`. `org` / `orgName` / `system` / `domain` resolve from
`{org}` in `organization.yaml`.

- **ComponentClaim**: `type: service`, `lifecycle: production`,
  `system: system:{org}-system`, github `visibility: private`,
  `branchStrategy: {name: none, defaultBranch: main}`, `allowAutoMerge: true`,
  `deleteBranchOnMerge: true`, `features: []`, `sync: {enabled: true, period: 24h}`.
- **UserClaim**: github `role: member`, `sync: {enabled: true, period: 24h}`.
- **GroupClaim**: `type: business-unit`, github `privacy: closed`,
  `sync: {enabled: true, period: 24h}`.
- **SystemClaim**: `domain: domain:{org}-domain`.
- **SecretsClaim**: `lifecycle: production`, external_secrets `refreshInterval: 24h`.
- **TFWorkspaceClaim**: terraform `source: remote`, `policy: apply`,
  `sync: {policy: observe, period: 24h, enabled: true}`, backend
  `firestartr-terraform-state`.
- **OrgWebhookClaim**: github `webhook: {active: true, contentType: json}`.

## Required fields per kind

- **ComponentClaim**: `kind, version, type, lifecycle, name, providers.github.name,
  providers.github.org`.
- **UserClaim**: `kind, version, name, providers.github.name, providers.github.org,
  providers.github.role` (`admin`|`member`).
- **GroupClaim**: `kind, version, name, providers.github.name, providers.github.org`.
  Optional: `members[]`, `type`, `parent`, `children[]`, `privacy` (closed|secret).
- **SystemClaim / DomainClaim**: `kind, version, name`.
- **SecretsClaim**: `kind, version, name`; externalSecrets need
  `refreshInterval, data[].remoteRef.key, data[].secretKey, secretStoreRef`.
- **OrgWebhookClaim**: `kind, version, name, providers.github.orgName,
  providers.github.webhook.url`.
- **TFWorkspaceClaim**: `kind, version, name, providers.terraform.name, source,
  policy`. `source: remote` needs `module`; `inline` needs `files`.

For the complete field definitions, types, and constraints, read the JSON schema
for the kind in `schemas/`:
`schemas/{component,user,group,system,domain,secrets,orgwebhook,tfworkspace,argodeploy}-claim.json`.

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
