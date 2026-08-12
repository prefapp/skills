# Troubleshooting Playbook

Diagnose why a platform request failed or is behaving unexpectedly —
anywhere from local tooling to Terraform apply — using only what's visible
via GitHub (Actions runs, PR comments, check runs, issues) and
`fs-forge-cli`/`gh`. Never assumes cluster/`kubectl` access to the operator.
Raw commands and full lookup tables: `../reference/diagnostics.md`.

## Symptom lookup — start here

Each row jumps straight to one failure surface — read that section only, not
top to bottom.

| Symptom | Failure surface |
|---|---|
| `npx`/`fs-forge` won't run, no network, wrong Node | [Environment & tooling](#environment--tooling) |
| No usable org/CLI-version config, no published CLI release | [Config & CLI-version resolution](#config--cli-version-resolution) |
| A `create`/`edit`/`clone`/`defaults` command errored | [fs-forge-cli command failures](#fs-forge-cli-command-failures) |
| A claims-repo PR's checks are failing (PR Verify / render) | [PR-verify / render-pipeline denial](#pr-verify--render-pipeline-denial) |
| A hydrate workflow run failed, or no state PR ever appeared | [Hydrate-workflow dispatch/execution](#hydrate-workflow-dispatchexecution) |
| A state PR's `terraform_plan` check is red | [Terraform plan status check (pre-merge)](#terraform-plan-status-check-pre-merge) |
| A state PR won't merge, or merges but nothing happens next | [State-PR merge](#state-pr-merge) |
| A repo/team/webhook/TF resource wasn't created, or drift has no obvious cause | [Terraform apply / operator reconciliation (post-merge)](#terraform-apply--operator-reconciliation-post-merge) |
| The catalog looks stale, or reconciliation drift might be a false positive | [Read-only playbooks' own failure modes](#read-only-playbooks-own-failure-modes) |

## Diagnose, don't fix — with one exception

Report what this finds and route back to the playbook that owns the fix
(`create-claim`/`edit-claim`/`clone-claim`/`lifecycle`) — never edit a claim
from here. The one exception: offering to trigger a re-hydrate directly,
already sanctioned as non-mutating by `catalog.md`'s and `reconciliation.md`'s
Freshness sections (`../reference/gh-cookbook.md` → "Trigger hydration and
wait").

## Escalation boundary

Two axes decide "keep digging" versus "tell the client this needs Prefapp":

1. **Signal legibility** — does the GitHub-visible signal name a cause? Each
   surface below has a finite check; exhausting it *is* "stop digging."
2. **Ownership of the fix** — once named, can the client act on it
   themselves (edit a claim field, approve a PR, fix local env), or is it
   Prefapp-owned (credentials, quota, platform bug, state corruption, repo
   administration)?

Two exits only: **client-fixable** (name the specific fix) or **escalate —
needs Prefapp** (name why). Full per-surface table: `../reference/diagnostics.md`.

## Environment & tooling

Never escalate. Node/network/`npx` problems are
`../reference/fs-forge-cookbook.md`'s hard-dependency check — fix and retry,
or tell the client and stop.

## Config & CLI-version resolution

Never escalate — both are self-service via `SKILL.md` Step 1 (missing/invalid
`firestartr-config.yaml`, unpinned/stale `cli_version`). One exception:
`npm dist-tag ls`/`npm view @firestartr/fs-forge-cli versions` showing **zero
published versions at all** — that's a Prefapp-owned publishing failure,
escalate.

## fs-forge-cli command failures

Four known conditions, all client-fixable except an uncaught crash. Exact
messages, exit codes, and the verdict table: `../reference/diagnostics.md`.

## PR-verify / render-pipeline denial

PR-verify is a plain Actions run — no dedicated check-run/PR-comment step;
read its log (`../reference/diagnostics.md`). There is **no automated
Rego-policy evaluation** today, so there's no separate "policy denial" mode:
a failed render reuses the same shapes as fs-forge-cli's own validation
above — client-fixable if it matches one of those, escalate otherwise.

## Hydrate-workflow dispatch/execution

`::error::No CR files found for claim '<name>' (<kind>). The claim may not
exist.` → client-fixable: check name/kind spelling and that the defining PR
merged. A GroupClaim referencing an un-hydrated UserClaim fails the same way
— hydrate the user first, then retry. Any other failed step: read it once
(`../reference/diagnostics.md`); a recognized fs-forge/render shape is
client-fixable, anything else escalates.

## Terraform plan status check (pre-merge)

Read the `terraform_plan` check run's `output.summary` — the plan or error
text verbatim, for Terraform-claim and GitHub-claim state PRs alike
(`../reference/diagnostics.md`). Same client-fixable/escalate call as
Terraform apply / operator reconciliation below.

## State-PR merge

`terraform_plan` green and required checks passing but the PR still won't
merge → escalate (branch-protection/repo-administration, Prefapp-owned).
Unmerged only for lack of human review isn't a failure — get it reviewed.

## Terraform apply / operator reconciliation (post-merge)

No enumerated table — errors are unbounded, so use this heuristic:

- Names a value **traceable to the claim's own fields** (invalid enum, name
  collision, a quota tied to a requested size, a resource the claim itself
  describes) → client-fixable, point at the field to edit.
- Names **auth/permissions/provider-internal/state-lock/network** concerns,
  or is a bare provider/Terraform crash with no claim-traceable value →
  escalate.

Read the sticky PR comment / check-run `output.summary` first
(`../reference/diagnostics.md`) — the CR's `.status.conditions` is a generic
templated message, good only to confirm *that* it failed, never *why*. This
covers GitHub-claim kinds too: they surface through the identical check-run
pair plus sticky PR comment, not a cluster-only failure class.

## Read-only playbooks' own failure modes

Rule these out before treating either as a real failure:

- **Catalog looks wrong or stale** — `catalog.md`'s Freshness section: it
  hydrates every ~6h.
- **Reconciliation reports drift** — `reconciliation.md`'s un-hydrated trap:
  an open state-repo PR, or a claim newer than its state resource, isn't
  drift yet.

Only a mismatch that survives hydration and state-PR merge is genuine drift
— then it's this playbook's Terraform apply / operator reconciliation
surface above.

## Reference

Runnable commands and the full lookup tables: `../reference/diagnostics.md`.
