# Diagnostics Reference

Commands and lookup tables for `../playbooks/troubleshooting.md`. Resolve the kind's `stateRepo` (`kinds show`) to `{state_repo}` from Step 1.

## PR-verify / render-pipeline run

PR-verify (`"🔍 PR Verify"`) runs `firestartr-cli cdk8s --render` per provider; a render error fails the Actions run. `validate-claims.yaml` (schedule/`workflow_dispatch`) shares this render step and error shape; dispatch/wait below.

```bash
gh pr checks {pr} --repo {claims_repo}                     # pass/fail + link
gh run view {run_id} --repo {claims_repo} --log-failed     # the thrown error, verbatim
```

No automated Rego evaluation: PR-verify, the sweep and render CLI never load `.firestartr/validations/policies/*.rego`; only the client's manual `docker run ... conftest ...` enforces them. Render failures use the error shapes below, never the `fs-forge-cli` table (`create`/`edit`/`validate`/`defaults` only).

## Validation sweep

`validate-claims.yaml` renders every claim, kind and provider. Eligibility and comparison with PR-verify: `../playbooks/troubleshooting.md#validation-sweep`. Dispatch by ID, not display name (hidden characters):

```bash
gh workflow list --repo {claims_repo} --all               # find the 🔍 Validate Claims workflow + ID

# Reuse a recent run instead of dispatching fresh, if it's new enough:
LATEST_SHA=$(gh api repos/{claims_repo}/git/ref/heads/main --jq '.object.sha')
gh run list --repo {claims_repo} --workflow {workflow-id} --limit 1 \
  --json databaseId,headSha,conclusion,createdAt          # compare headSha to $LATEST_SHA

# Otherwise dispatch fresh: no inputs needed, defaults render everything:
gh workflow run {workflow-id} --repo {claims_repo}
sleep 30
gh run list --repo {claims_repo} --workflow {workflow-id} --limit 1 \
  --json databaseId,status,conclusion
gh run view {run_id} --repo {claims_repo} --log-failed    # the thrown error, verbatim
```

Freshness and red/green interpretation: `../playbooks/troubleshooting.md#validation-sweep`.

## Render error shapes

These are render errors (`firestartr-cli cdk8s --render`) shared by PR-verify, `validate-claims.yaml`, and `provision-claim.yaml`; schema-only `fs-forge-cli validate` never produces them.

| Condition | Message | Verdict |
|---|---|---|
| Broken reference | `Claim <Kind>-<name> not found` | Client-fixable: the referencing claim's field names a claim that doesn't exist |
| Cross-reference (secrets) | `CrossReference error: <Kind>/<name> references a non-existent secret key: '<secret>:<key>'` (or "...secret key inexistent: '<secret>/<key>'") | Client-fixable: the secret key isn't in the referenced `SecretsClaim` |
| Naming collision | `Duplicate CR found for <Kind>-<name>` | Client-fixable: two claims render to the same kind+name; rename one |
| Anything else | uncaught crash / bare stack trace | Escalate |

## `terraform_plan` check run (pre-merge)

A GitHub **Check Run**, not legacy status, on state-github and state-infra PRs. GitHub-claim kinds (`FirestartrGithubRepository`/`-Group`/`-Membership`/`-OrgWebhook`) use the same Terraform-provider plan machinery as `FirestartrTerraformWorkspace`.

```bash
gh api repos/{state_repo}/commits/{sha}/check-runs \
  --jq '.check_runs[] | select(.name == "terraform_plan") | {conclusion, output}'
gh pr view {pr} --repo {state_repo} --comments   # same plan/error text, as a sticky comment
```

`{sha}` is the PR's last commit: `gh pr view {pr} --json headRefOid --jq .headRefOid`.

## Apply / destroy: check runs + sticky PR comment (post-merge)

Post-merge: GitHub **Check Runs** (`"<Kind> - synth"` / `"<Kind> - apply"` or `"- destroy"`, `KO` on error) and a sticky PR comment ("Apply/Destroy Succeeded/Failed ✅/❌") with raw errors. Terraform and GitHub claims use the same provider machinery.

```bash
gh api --paginate repos/{wet_pr_owner}/{wet_pr_repo}/commits/{merge_sha}/check-runs \
  --jq '.check_runs[] | select(.name | test(" - (synth|apply|destroy)$"))'
gh pr view {hydrate_pr} --repo {state_repo} --comments
```

`Terraform Apply <cr-name>` commit status is defined but never called; don't rely on `gh api .../statuses` for apply. `Terraform Destroy <cr-name>` is called only on success; failed destroy appears in the check run + PR comment.

The CR's `.status.conditions` has generic `ERROR` (`An
error occurred while executing the Terraform apply operation.`): confirms failure, not cause; use the check run / PR comment.

## Hydrate-workflow run logs

Dispatch by **filename**, never display name (hidden zero-width spaces before emoji):

```bash
RUN_ID=$(gh workflow run {hydrate-workflow-filename} --repo {claims_repo} \
  -r {branch} -f name={claim_name} [-f kind={ClaimKind}] 2>&1 | grep -oE 'runs/[0-9]+' | grep -oE '[0-9]+')
gh run watch "$RUN_ID" --repo {claims_repo} --exit-status
gh run view "$RUN_ID" --repo {claims_repo} --log-failed
```

`{hydrate-workflow-filename}`: `kinds show <id> --json` (`gh-cookbook.md` → "Trigger hydration and wait"). `::error::No CR files found for
claim '<name>' (<kind>). The claim may not exist.`: check name/kind spelling, claims PR merge and, for GroupClaim referencing UserClaim, user-first hydration.

## Claim ↔ state cross-referencing

```bash
# Known filename (<CrKind>.<cr-name>.yaml, at the state repo's root):
gh api repos/{state_repo}/contents/{CrKind}.{cr-name}.yaml \
  --jq -r '.content' | base64 -d | grep -E 'firestartr.dev/(claim-ref|last-state-pr):'

gh pr view {pr_number} --repo {owner}/{repo}                          # last-state-pr is already "owner/repo#prNumber"
gh search code '"{ClaimKind}/{claim-name}"' --repo {state_repo} # unknown filename (best-effort)
```

`claim-ref` is `ClaimKind/claim_name`; `last-state-pr` is `owner/repo#prNumber`.

## fs-forge-cli error shapes

`create`/`edit`/`validate`/`defaults` only; render failures use "Render error shapes" above.

| Condition | Message | Exit code | Verdict |
|---|---|---|---|
| Schema validation | AJV message, e.g. `must have required property 'owner'` / `/providers/github must have required property 'privacy'` | `validate -f` 1 · `create --commit` 2 · `edit` 1 | Client-fixable: correct the field |
| Uniqueness | `Claim already exists: <Kind>-<name>` | `create --commit` 1 | Client-fixable: `edit` instead, or pick a different name |
| Stale branch | `Branch already exists: fs-forge/<kind>-<name>. Delete it before publishing again.` | 1 | Client-fixable: delete the branch, retry |
| Ambiguous defaults (fatal) | `Multiple claims_defaults.yaml files found: <path1>, <path2>...` | `defaults apply/show/list` 1 | Client-fixable: consolidate to one file |
| Ambiguous defaults (tolerant) | `Warning: Skipping defaults: Multiple claims_defaults.yaml files found: ...` (stderr) | 0; `edit` continues without defaults | Not a failure |
| Unknown kind | `No schema found for claim kind: <kind>` | 1 or 2 | Client-fixable if `<kind>` is a typo (`kinds --json`); escalate as a CLI bug if it's a real kind |
| Anything else | uncaught crash / bare stack trace | - | Escalate |

Zero `claims_defaults.yaml` candidates is not an error: silently treated as "no defaults." Only *multiple* candidates is ambiguous.
