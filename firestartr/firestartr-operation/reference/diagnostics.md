# Diagnostics Reference

Raw commands and lookup tables for `../playbooks/troubleshooting.md`. `{org}`
and `{version}` are resolved from `firestartr-config.yaml`; `{claims_repo}` is
`{org}/claims`, same as `gh-cookbook.md`. `{state-repo}` is `state-github` or
`state-infra` — pick per `reference.md`'s claim→state map. Bounded to what's
observable via `gh`/`gh api`/`fs-forge-cli` — never cluster/`kubectl` access
to the operator.

## PR-verify / render-pipeline run

PR-verify (`"🔍 PR Verify"`) has no check-run or PR-comment step of its own —
it's `firestartr-cli cdk8s --render` per provider, failing the Actions run
naturally if rendering throws. `validate-claims.yaml` (schedule/
`workflow_dispatch`, a whole-repo sweep rather than a per-PR check) shares
the same render step and the same failure shape.

```bash
gh pr checks {pr} --repo {claims_repo}                                       # pass/fail + link
gh run list --repo {claims_repo} --workflow validate-claims.yaml --limit 1   # the sweep, not tied to a PR
gh run view {run_id} --repo {claims_repo} --log-failed                       # the thrown error, verbatim
```

No automated Rego-policy evaluation exists — `.firestartr/validations/policies/*.rego`
isn't loaded by PR-verify, the sweep, or the render CLI; the only enforcement
is a manual `docker run ... conftest ...` step the client runs by hand. A
failed run's error text is one of the fs-forge-cli error shapes below, or an
unrecognized render failure.

## `terraform_plan` check run (pre-merge)

A GitHub **Check Run**, not a legacy status — on state-github and
state-infra PRs alike. Every GitHub-claim kind
(`FirestartrGithubRepository`/`-Group`/`-Membership`/`-OrgWebhook`) runs its
plan phase through the same Terraform-provider machinery as
`FirestartrTerraformWorkspace`.

```bash
gh api repos/{org}/{state-repo}/commits/{sha}/check-runs \
  --jq '.check_runs[] | select(.name == "terraform_plan") | {conclusion, output}'
gh pr view {pr} --repo {org}/{state-repo} --comments   # same plan/error text, as a sticky comment
```

`{sha}` is the PR's last commit: `gh pr view {pr} --json headRefOid --jq .headRefOid`.

## Apply / destroy — check runs + sticky PR comment (post-merge)

Post-merge feedback is a pair of GitHub **Check Runs** (`"<Kind> - synth"` /
`"<Kind> - apply"` or `"- destroy"`, closing `KO` on error) plus a sticky PR
comment ("Apply/Destroy Succeeded/Failed ✅/❌") with the raw error text —
identical for Terraform-claim and GitHub-claim kinds, since GitHub claims are
Terraform-provider runs under the hood.

```bash
gh api repos/{org}/{state-repo}/commits/{merge_sha}/check-runs \
  --jq '.check_runs[] | select(.name | test(" - (synth|apply|destroy)$"))'
gh pr view {hydrate_pr} --repo {org}/{state-repo} --comments
```

**The documented `Terraform Apply <cr-name>` commit status is dead code** —
defined, never called; don't rely on `gh api .../statuses` for apply
feedback. (`Terraform Destroy <cr-name>` *is* called, but only on success —
a failed destroy still only shows up in the check run + PR comment.)

The CR's own `.status.conditions` carries a generic `ERROR` message (`An
error occurred while executing the Terraform apply operation.`) — confirms
*that* it failed, never *why*; that detail lives only in the check run / PR
comment above.

## Hydrate-workflow run logs

Dispatch by **filename**, never display name (display names hide
zero-width-space characters before their emoji):

```bash
RUN_ID=$(gh workflow run {hydrate-workflow-filename} --repo {claims_repo} \
  -r {branch} -f name={claim_name} [-f kind={ClaimKind}] 2>&1 | grep -oP 'runs/\K\d+')
gh run watch "$RUN_ID" --repo {claims_repo} --exit-status
gh run view "$RUN_ID" --repo {claims_repo} --log-failed
```

`{hydrate-workflow-filename}` per claim family: `gh-cookbook.md`'s hydrate
table. One common, self-explanatory failure: `::error::No CR files found for
claim '<name>' (<kind>). The claim may not exist.` — check name/kind
spelling and that the defining claims-repo PR merged. If the claim is a
GroupClaim naming a UserClaim, confirm the user hydrated first.

## Claim ↔ state cross-referencing

```bash
# Known filename (<CrKind>.<cr-name>.yaml, at the state repo's root):
gh api repos/{org}/{state-repo}/contents/{CrKind}.{cr-name}.yaml \
  --jq -r '.content' | base64 --decode | grep -E 'firestartr.dev/(claim-ref|last-state-pr):'

gh pr view {pr_number} --repo {owner}/{repo}                          # last-state-pr is already "owner/repo#prNumber"
gh search code '"{ClaimKind}/{claim-name}"' --repo {org}/{state-repo} # unknown filename (best-effort)
```

`claim-ref` is `ClaimKind/claim_name`; `last-state-pr` is `owner/repo#prNumber`.

## fs-forge-cli error shapes

| Condition | Message | Exit code | Verdict |
|---|---|---|---|
| Schema validation | AJV message, e.g. `must have required property 'owner'` / `/providers/github must have required property 'privacy'` | `validate -f` 1 · `create --commit` 2 · `edit`/`clone` 1 | Client-fixable — correct the field |
| Uniqueness | `Claim already exists: <Kind>-<name>` | `create --commit` 1 · `clone --commit` 2 | Client-fixable — `edit` instead, or rename |
| Stale branch | `Branch already exists: fs-forge/<kind>-<name>. Delete it before publishing again.` | 1 | Client-fixable — delete the branch, retry |
| Ambiguous defaults (fatal) | `Multiple claims_defaults.yaml files found: <path1>, <path2>...` | `defaults apply/show/list` 1 | Client-fixable — consolidate to one file |
| Ambiguous defaults (tolerant) | `Warning: Skipping defaults: Multiple claims_defaults.yaml files found: ...` (stderr) | 0 — `edit`/`clone` continue without defaults | Not a failure |
| Unknown kind | `No schema found for claim kind: <kind>` | 1 or 2 | Client-fixable if `<kind>` is a typo (`reference.md`'s kind table); escalate as a CLI bug if it's a real kind |
| Anything else | uncaught crash / bare stack trace | — | Escalate |

Zero `claims_defaults.yaml` candidates is **not** an error — silently
treated as "no defaults." Only *multiple* candidates is ambiguous.

## Escalation boundary — full table

| Surface | Escalate when | Otherwise |
|---|---|---|
| Environment & tooling | never | client-fixable (Node/network) |
| Config & CLI-version resolution | `npm dist-tag ls`/`npm view` show zero published versions | client-fixable, self-service via `SKILL.md` Step 1 |
| fs-forge-cli command failures | see the table above | see the table above |
| PR-verify / render-pipeline denial | error doesn't match an fs-forge-cli error shape | client-fixable |
| Hydrate-workflow dispatch/execution | failed step's log doesn't match a recognized fs-forge/render shape | client-fixable (see the one known error string above) |
| Terraform plan / apply / operator reconciliation | error names auth/permissions/provider-internal/state-lock/network, or is a bare crash with no claim-traceable value | client-fixable when the error names a value traceable to the claim's own fields |
| State-PR merge | `terraform_plan` green + required checks passing but merge still blocked | not a failure if only awaiting human review |
