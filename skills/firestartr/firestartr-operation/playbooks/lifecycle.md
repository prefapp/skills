# Lifecycle Playbook

All mutations land here. `create-claim`/`edit-claim` supply the body; bash: `../reference/gh-cookbook.md`. Immediate landing uses **fs-forge-managed** (`create`/`edit --commit`); offline create or `gh` edit fallback uses **manual**. The client chooses the create ending.

## Governance

Apply `../SKILL.md` Common rules. **PR-only; never commit to `main`**: branch → PR → merge. Host composite tools (`create_claim_pr`, `github_create_pr_with_changes`, `github_propose_changes_dry_run`) are fallbacks when `fs-forge-cli`/`gh` cannot cover a task.

## fs-forge-managed flow (`create`/`edit --commit`)

### Step 1: Dry-run

**edit:** `edit` with `--diff` (no `--commit`); fix validation errors, show the unified YAML Claim diff, not relation tree, and get approval (`../reference/fs-forge-edit.md`).

**create:** the previously shown `create` output (no `--commit`) is the plan; `create` has no `--diff`.

### Step 2: Re-run with `--commit` and the audit-issue flags

See `../reference/fs-forge-mutation-shared.md`'s `--commit` warning. After provisioning, it watches wet (state-repo) PR checks until finished; `--no-wait-for-checks` skips that.

### Step 3: Report the outcome

Don't poll, hydrate or merge the wet PR yourself; `--commit` did it. Check the dispatched `provision-claim.yaml` run and link the audit issue. Manual hydrate only if the client explicitly asks (manual flow Step 5).

If the output says `No wet PR found for this claim; skipping check watch.`, no
checks were watched: don't report them as passed. Run
`npx @firestartr/fs-forge-cli@{version} watch-checks <Kind>-<name> --org={org} --current --json`
and report its result. For `catalogOnly: true` kinds, report the provisioning run's outcome instead; other `hydration: null` kinds are unconfirmed. Once the wet PR merges, read its merge-commit check runs before reporting (`../reference/diagnostics.md`, apply/destroy).

- Any `checks` entry or merge-commit check with `failure`, `cancelled` or `timed_out` → failed: stop, report, point to diagnostics.
- No PR (exit 3), no `checks` entries, `lastStatePr.state` not `merged` (open, closed or null after lookup error), or conclusion other than `success`, `skipped` or `neutral` (null/pending, `action_required`, `stale`) → unconfirmed: say so, point to diagnostics. Absent or pending merge-commit checks are also unconfirmed.

On either result, reopen the issue the merged claim PR closed: `gh issue reopen {N} --repo {claims_repo}`.

Failed run: `troubleshooting.md#symptom-lookup-start-here` routes PR-verify, hydrate, plan, state-PR merge or apply failures.

Failure and retry: `../reference/fs-forge-mutation-shared.md`'s `--commit` warning; unexplained CLI errors: `troubleshooting.md#fs-forge-cli-command-failures`.

## Manual flow (`create` without `--commit`, or a `gh`-based edit fallback)

### Step 0: Capture the goal as an issue

Before touching branches, open it in the claims repo, in client terms (not "claim"). Reference the issue number in the PR (`Closes #N`).

```bash
gh issue create --repo {claims_repo} --title "{goal}" --body "{what the client asked for}"
```

### Step 1: Validate the generated or updated file before opening the PR

- Schema: run `npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}` (see `../reference/fs-forge-cookbook.md`).
- References: every `user:` / `group:` / `system:` / `domain:` /
  `ref:secretsclaim:` points at an existing claim.
- Naming: matches `^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$`, ≤63 chars (see `../reference/reference.md`).
- Uniqueness: on create, if a claim of that kind/name exists, stop and tell the client it would duplicate it.

### Step 2: Branch from main

### Step 3: Write the full file on the branch (create or update)

Offline create: PUT validated `{preview-file}` to `claims/{claimsDirectory}/{name}.yaml`; for `requiresPath: true`, use the destination from `create-claim.md` Step 3 (`../reference/gh-cookbook.md`).

### Step 4: Open the PR, show it to the client, merge it (squash)

### Step 5: Hydrate

If `kinds show <id> --json` reports `hydration: null`, skip Steps 5-6: for `catalogOnly: true`, claims-index regenerates `claims-map.json` on merge; otherwise no workflow hydrates the claim, so report the change as unconfirmed (`../reference/diagnostics.md`). If `hydration` is set, dispatch its workflow (`../reference/gh-cookbook.md`) and wait for `conclusion: success`.
- When a create adds a user and references it elsewhere (e.g. a team), hydrate the `UserClaim` **first**, then the dependent claim.

Failed/timed-out run: `troubleshooting.md#hydrate-workflow-dispatchexecution`.

### Step 6: Merge the state PR

That hydration opened a PR on the kind's `stateRepo` (`kinds show`, resolved via Step 1's repos): GitHub-claim hydrate usually auto-merges it; Secrets and TFWorkspace need you to merge it.

PR won't merge: `troubleshooting.md#state-pr-merge`.

### Step 7: Report the landed change to the client in plain terms

When hydration is required, the platform won't reconcile until it succeeds and its state PR merges. Do not stop early.

## Delete flow

Before planning, check `kinds show <id> --json` → `delete`. If `delete.supported` is false, tell the client and go to "No delete workflow exists".

### `fs-forge-cli delete`

#### Step 1: Decide flags before dry-running

Choose flags before the dry-run; use the same command with `--commit` later:
- Unprovision waits for claims PR Verify before merge by default; `--no-wait-for-checks` skips that.
- If `kinds show` has `variants: true` (TFWorkspaceClaim), ask whether to keep variant CRs and pass `--include-variants`/`--no-include-variants` accordingly; otherwise omit.
- Add `--no-wait` only if the client asks not to wait for unprovision.
- Optional fast existence check for non-null `preflight`: `preflight --deletion` (`../reference/fs-forge-preflight.md`); it doesn't replace Step 2's dry-run.

#### Step 2: Dry-run

No `--commit`, to confirm the claim exists and preview the dispatch:

```bash
npx @firestartr/fs-forge-cli@{version} delete <Kind> <name> --org={org} \
  [--include-variants|--no-include-variants]
```

Show the printed plan (kind, name, `includeVariants`, `waitForClaimChecks`); it must match Step 1's flags.

#### Step 3: Get approval, then re-run with `--commit` and the audit-issue flags

Audit-issue flags: `../reference/fs-forge-mutation-shared.md`'s `--commit` warning. `unprovision-claim.yaml` merges both state and claims PRs. Don't poll or merge yourself; report the dispatched run.

#### Step 4: Check run placement

Destroy results land on each deleted CR's `last-state-pr` PR, not the deletion wet PR (which merges when CI passes); without the annotation, on the deletion wet PR. `watch-checks` doesn't report destroy results: once the state PR merges, the CR is off the default branch and `--current` exits 3 (`No CRs found`). Per state repo, find this claim's deletion PR: the newest merged one whose removed files carry its exact `claim-ref` (variant CRs ride along):

```bash
DEL=""
for N in $(gh pr list --repo {state_repo} --state merged --search 'in:title "Automated deletion"' --limit 200 \
  --json number,body --jq '.[] | select(.body | contains("[{name}](")) | .number'); do
  BASE=$(gh pr view $N --repo {state_repo} --json baseRefOid --jq .baseRefOid)
  for f in $(gh pr view $N --repo {state_repo} --json files --jq '.files[].path'); do
    if gh api "repos/{state_repo}/contents/$f?ref=$BASE" --jq .content | base64 -d | grep -qx "    firestartr.dev/claim-ref: {ClaimKind}/{name}"; then DEL=$N; break 2; fi
  done
done
```

For each removed file, read its `last-state-pr` at `$BASE` (`../reference/diagnostics.md`, claim ↔ state), then check that PR's merge commit (no annotation: `$DEL`). A CR is confirmed by (a) a success `Terraform Destroy <cr-name>` status when no other removed file has that name, or (b) a success `<Kind> - destroy` check run when it is the only CR of that kind removed with that `last-state-pr`. A failed `<Kind> - destroy` is failed; otherwise unconfirmed. No `$DEL`, or any CR failed or unconfirmed (fs-forge-managed Step 3 rules): reopen the issue the unprovision run closed, `gh issue reopen {N} --repo {claims_repo}`. All confirmed: leave it closed.

### No delete workflow exists

If `delete.supported: false`, don't remove the file yourself. Tell the client no automated path exists; they must remove it by hand.

Otherwise, confirm removal to the client once the change has landed.

## Hydration name

The hydrate name is the claim's name, not its file path; for a group use its normalized slug, not its display name.
