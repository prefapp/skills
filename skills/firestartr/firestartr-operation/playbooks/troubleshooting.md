# Troubleshooting Playbook

Diagnose local tooling through Terraform apply using GitHub (Actions, PR comments, checks, issues) and `fs-forge-cli`/`gh`, never cluster/`kubectl` access. Commands and lookup tables: `../reference/diagnostics.md`.

## Symptom lookup: start here

Read only the matched failure surface.

| Symptom | Failure surface |
|---|---|
| `npx`/`fs-forge` won't run, no network, wrong Node | [Environment & tooling](#environment--tooling) |
| No usable config, no GitHub auth, or no published CLI release | [Config & CLI-version resolution](#config--cli-version-resolution) |
| A `create`/`edit`/`defaults` command errored | [fs-forge-cli command failures](#fs-forge-cli-command-failures) |
| A claims-repo PR's checks are failing (PR Verify / render) | [PR-verify / render-pipeline denial](#pr-verify--render-pipeline-denial) |
| A hydrate workflow run failed, or no state PR ever appeared | [Hydrate-workflow dispatch/execution](#hydrate-workflow-dispatchexecution) |
| A state PR's `terraform_plan` check is red | [Terraform plan status check (pre-merge)](#terraform-plan-status-check-pre-merge) |
| A state PR won't merge, or merges but nothing happens next | [State-PR merge](#state-pr-merge) |
| A repo/team/webhook/TF resource wasn't created, or drift has no obvious cause | [Terraform apply / operator reconciliation (post-merge)](#terraform-apply--operator-reconciliation-post-merge) |
| The catalog looks stale, or reconciliation drift might be a false positive | [Read-only playbooks' own failure modes](#read-only-playbooks-own-failure-modes) |

## Diagnose, don't fix: with one exception

Report findings and route fixes to `create-claim`/`edit-claim`/`lifecycle`; never edit here. Exception: offer to trigger re-hydration (`../reference/gh-cookbook.md` → "Trigger hydration and wait"), as in `catalog.md` and `reconciliation.md` Freshness.

## Escalation boundary

Check signal legibility (does the GitHub signal name a cause? Stop digging after the surface's finite check) and fix ownership (client action or Prefapp-owned credentials, quota, platform bug, state corruption, repo administration). Exit as **client-fixable** with the specific fix, or **escalate: needs Prefapp** with why.

## Validation sweep

`validate-claims.yaml` renders the whole repo; PR-verify renders only touched claims except on deletes. Use this last resort before escalating, never first, only when the surface's own check doesn't explain PR-verify/render denial, hydrate dispatch/execution, claim-traceable-but-unclear Terraform apply/operator reconciliation, or `--commit` uniqueness/stale-branch failures.

Read the latest run; reuse it if newer than the latest claims-repo commit, otherwise dispatch fresh. Always dispatch fresh to verify a fix. No client approval needed, but say it is running: it checks out multiple repos and takes minutes.

Green confirms the whole repo; red identifies only the first broken claim. Fix it, re-dispatch and report each round; one pass is not exhaustive.

Dispatch/wait/read commands and the render error-shape table:
`../reference/diagnostics.md#validation-sweep`.

## Environment & tooling

Never escalate. Node/network/`npx`: fix and retry, or tell the client and stop (`../reference/fs-forge-cookbook.md` hard-dependency check).

## Config & CLI-version resolution

Self-service via `../SKILL.md` Step 1 (`NO_CONFIG`, `NO_MATCH`, `AMBIGUOUS_MATCH`, `NO_AUTH`, pin below target); never escalate except when `npm view @firestartr/fs-forge-cli@{target} version` returns 404: unpublished target is a Prefapp publishing failure.

## fs-forge-cli command failures

Four known conditions, all client-fixable except an uncaught crash. Exact
messages, exit codes, and the verdict table: `../reference/diagnostics.md`.

## PR-verify / render-pipeline denial

PR-verify is an Actions run, not a check-run/PR-comment step; read its log (`../reference/diagnostics.md`). No automated Rego-policy evaluation or separate policy denial exists. Render errors (broken reference or naming collision) differ from fs-forge-cli errors: `validate` is schema-only and never runs during render. Recognized shape → client-fixable; otherwise escalate.

## Hydrate-workflow dispatch/execution

`::error::No CR files found for claim '<name>' (<kind>). The claim may not
exist.` → client-fixable: check name/kind spelling and that the defining PR
merged. A GroupClaim referencing an un-hydrated UserClaim fails the same way:
hydrate the user first, then retry. Any other failed step: read it once
(`../reference/diagnostics.md`); a recognized fs-forge/render shape is
client-fixable, anything else escalates.

## Terraform plan status check (pre-merge)

Read `terraform_plan` check-run `output.summary` for the verbatim plan/error on Terraform-claim and GitHub-claim state PRs (`../reference/diagnostics.md`). Use the apply/reconciliation verdict below.

> **`watch-checks` exit code 1** means at least one check on a state-repo PR has failed: start here.

## State-PR merge

`terraform_plan` green, required checks passing, PR still blocked → escalate (Prefapp-owned branch protection/repo administration). Awaiting human review isn't a failure: get it reviewed.

## Terraform apply / operator reconciliation (post-merge)

- Value **traceable to claim fields** (invalid enum, name collision, quota tied to requested size, described resource) → client-fixable; identify the field.
- **auth/permissions/provider-internal/state-lock/network** or bare provider/Terraform crash without claim-traceable value → escalate.

Read sticky PR comment / check-run `output.summary` first (`../reference/diagnostics.md`). CR `.status.conditions` confirms failure, not cause. GitHub-claim kinds use the same check-run pair and sticky comment, not a cluster-only failure class.

> **Deleted claims:** destroy check runs land on the `last-state-pr` PR (from
> the CR's `firestartr.dev/last-state-pr` annotation), not the deletion
> wet-PR. Inspect destroy status with `npx @firestartr/fs-forge-cli@{version} watch-checks <Kind>-<name> --org={org} --current` (it follows `last-state-pr`).

## Read-only playbooks' own failure modes

Before calling a failure real, check `catalog.md` Freshness (catalog hydrates ~6h) or `reconciliation.md`'s un-hydrated trap (open state PR or claim newer than state). Only mismatch after hydration and state-PR merge is genuine drift; use the apply/reconciliation section above.
