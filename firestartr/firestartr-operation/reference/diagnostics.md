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
the same render step and the same failure shape — dispatch/wait mechanics
for it: "Validation sweep" below.

```bash
gh pr checks {pr} --repo {claims_repo}                     # pass/fail + link
gh run view {run_id} --repo {claims_repo} --log-failed     # the thrown error, verbatim
```

No automated Rego-policy evaluation exists — `.firestartr/validations/policies/*.rego`
isn't loaded by PR-verify, the sweep, or the render CLI; the only enforcement
is a manual `docker run ... conftest ...` step the client runs by hand. A
failed run's error text is one of the render error shapes below, or an
unrecognized render failure — never one of `fs-forge-cli`'s own (that table
only applies to `create`/`edit`/`clone`/`validate`/`defaults` invocations).

## Validation sweep

`validate-claims.yaml` renders every claim in the repo, every kind, every
provider — unlike PR-verify, which only renders the claims one PR touches
(except on a delete, which forces a full render there too). Dispatch by ID,
not display name (same hidden-character caveat as every workflow here):

```bash
gh workflow list --repo {claims_repo} --all               # find the 🔍 Validate Claims workflow + ID

# Reuse a recent run instead of dispatching fresh, if it's new enough:
LATEST_SHA=$(gh api repos/{claims_repo}/git/ref/heads/main --jq '.object.sha')
gh run list --repo {claims_repo} --workflow {workflow-id} --limit 1 \
  --json databaseId,headSha,conclusion,createdAt          # compare headSha to $LATEST_SHA

# Otherwise dispatch fresh — no inputs needed, defaults render everything:
gh workflow run {workflow-id} --repo {claims_repo}
sleep 30
gh run list --repo {claims_repo} --workflow {workflow-id} --limit 1 \
  --json databaseId,status,conclusion
gh run view {run_id} --repo {claims_repo} --log-failed    # the thrown error, verbatim
```

Verifying a fix always dispatches fresh — a run from before the fix can't
reflect it. Rendering halts at the first broken claim it hits (kind-sorted:
User→Group→Component→Domain→System→Secrets→TFWorkspace→ArgoDeploy→
OrgWebhook→OrgSettings) — a green run confirms the whole repo; a red one
only guarantees that first claim. Fix it and re-dispatch to find the next.

## Render error shapes

Distinct from the `fs-forge-cli` table below — these come from the render
step (`firestartr-cli cdk8s --render`) that PR-verify, `validate-claims.yaml`,
and `provision-claim.yaml` all share. `fs-forge-cli`'s own `validate` is
schema-only and never produces them.

| Condition | Message | Verdict |
|---|---|---|
| Broken reference | `Claim <Kind>-<name> not found` | Client-fixable — the referencing claim's field names a claim that doesn't exist |
| Cross-reference (secrets) | `CrossReference error: <Kind>/<name> references a non-existent secret key: '<secret>:<key>'` (or "...secret key inexistent: '<secret>/<key>'") | Client-fixable — the secret key isn't in the referenced `SecretsClaim` |
| Naming collision | `Duplicate CR found for <Kind>-<name>` | Client-fixable — two claims render to the same kind+name; rename one |
| Anything else | uncaught crash / bare stack trace | Escalate |

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
  -r {branch} -f name={claim_name} [-f kind={ClaimKind}] 2>&1 | grep -oE 'runs/[0-9]+' | grep -oE '[0-9]+')
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
  --jq -r '.content' | base64 -d | grep -E 'firestartr.dev/(claim-ref|last-state-pr):'

gh pr view {pr_number} --repo {owner}/{repo}                          # last-state-pr is already "owner/repo#prNumber"
gh search code '"{ClaimKind}/{claim-name}"' --repo {org}/{state-repo} # unknown filename (best-effort)
```

`claim-ref` is `ClaimKind/claim_name`; `last-state-pr` is `owner/repo#prNumber`.

## fs-forge-cli error shapes

`create`/`edit`/`clone`/`validate`/`defaults` only — never a render; see
"Render error shapes" above for PR-verify/`validate-claims.yaml`/
`provision-claim.yaml` failures instead.

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
| fs-forge-cli command failures | see the fs-forge-cli error shapes table above | see the fs-forge-cli error shapes table above |
| PR-verify / render-pipeline denial | error doesn't match a render error shape | client-fixable |
| Hydrate-workflow dispatch/execution | failed step's log doesn't match a recognized fs-forge/render shape | client-fixable (see the one known error string above) |
| Terraform plan / apply / operator reconciliation | error names auth/permissions/provider-internal/state-lock/network, or is a bare crash with no claim-traceable value | client-fixable when the error names a value traceable to the claim's own fields |
| State-PR merge | `terraform_plan` green + required checks passing but merge still blocked | not a failure if only awaiting human review |
