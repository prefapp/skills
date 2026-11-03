# Reference

Stable platform facts carried inside the skill (portable across deployments).
Everything org-specific comes from `../SKILL.md` Step 1; everything here does not.

## fs-forge

Runnable invocation and validation idioms live in `fs-forge-cookbook.md` (sibling of
this file). Read it before calling fs-forge or writing any claim.

## Naming rules

- Pattern `^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$`, max 63 chars.

**Normalizing a non-compliant name** (uppercase, spaces, non-ASCII): put a
transliterated slug in `name`, keep the original in `profile.displayName` and (for
GitHub-backed kinds) `providers.github.name`: GitHub teams accept Unicode.

## Reference formats

`user:{name}` · `group:{name}` · `system:{name}` · `domain:{name}` ·
`component:{name}` · `ref:secretsclaim:{claim}:{key}` · maintainer
`(user|group|collaborator):{name}`.

## Validation split

`validate` checks schema and Feature args, not cross-claim references, uniqueness, or naming normalization. The skill checks those before landing (`../playbooks/create-claim.md`, `../playbooks/lifecycle.md`).

## Default flag values for new claims

These are the skill's own portable, baked-in per-kind recommendations: a
fallback starting point for `create`, not a live mirror of any org's actual
configuration. For the org's real, current repo-level claim defaults
(auto-applied by `edit`, previewable for `create`; see
`fs-forge-mutation-shared.md`'s "Claim defaults" section), run
`npx @firestartr/fs-forge-cli@{version} defaults show <kind> --org={org}`.

These are logical claim-field values, not literal CLI flag names. Map them to the
matching FlagSpec paths and use each returned `path` when calling
`npx @firestartr/fs-forge-cli@{version} create`.
All default `version: "1.0"`. The `{org}` flag value (see
`fs-forge-mutation-shared.md`) comes from `../SKILL.md` Step 1 and is passed to the
kind's `orgField` flag.

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
- **TFWorkspaceClaim**: Terraform provider: `source: remote` (`inline` also
  valid; see "Terraform modules" below), `policy: apply`,
  `sync: {policy: observe, period: 24h, enabled: true}`,
  `backend: firestartr-terraform-state`.
- **OrgWebhookClaim**: GitHub provider:
  `webhook: {active: true, contentType: json}`.

## Terraform modules (TFWorkspaceClaim)

`providers.terraform.source` is `remote` or `inline`: both equally valid;
pick per claim.

- **`remote`**: pull a module from git. `prefapp/tfm` is Prefapp's own
  module repo: public (Apache-2.0), actively maintained, usable by anyone,
  not a mandatory dependency. Discover, never guess (commands in
  `gh-cookbook.md`): list `modules/`, read the module's `variables.tf` for
  inputs, pin the latest per-module release tag (`{module}-vX.Y.Z`).

  `module: git::https://github.com/prefapp/tfm.git//modules/{module}?ref={module}-vX.Y.Z`

- **`inline`**: raw Terraform HCL directly in `module`; no external repo,
  no discovery step.

Common intent → module / `resourceType`: S3 bucket → `aws-s3` / `aws-s3`,
RDS → `aws-rds`, EKS → `aws-eks` / `aws-eks`, AKS → `azure-aks`, VPC → `aws-vpc`.
Lean `remote` (`prefapp/tfm`) for these; lean `inline` for anything else or
genuinely bespoke.

## Features catalog (ComponentClaim)

Discover names and versions with `npx @firestartr/fs-forge-cli@{version} features discover --json`; read each Feature's purpose with `features discover --readme <feature-name>` (`../playbooks/feature-advisor.md`).

## Branch strategies

- **none**: default branch `main`, no protections.
- **gitflow**: adds `dev`; both `main` and `dev` get signed commits, 1 approval,
  dismiss-stale, require CODEOWNERS.

## Terraform policy hierarchy (most → least permissive)

`full-control` (create+update+delete+sync) → `apply` (create+update+sync, alias
create-update-only) → `create-only` (create+sync) → `observe` (sync/plan only).
The sync policy may never exceed the general policy.

## Claim → state mapping

Resolve the kind's `stateRepo` from `kinds show` to the corresponding repo from `../SKILL.md` Step 1. State resources: ComponentClaim → FirestartrGithubRepository (+Feature, +SecretsSection); GroupClaim → FirestartrGithubGroup; UserClaim → FirestartrGithubMembership; OrgWebhookClaim → FirestartrGithubOrgWebhook; SecretsClaim → ExternalSecret; TFWorkspaceClaim → FirestartrTerraformWorkspace. Catalog entities: Domain / System / Component / Group / User / Resource.

State files carry `metadata.annotations.firestartr.dev/claim-ref` linking back to
their source claim.
