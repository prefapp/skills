# Lifecycle Playbook

The one flow every mutating operation follows. `create-claim`, `edit-claim`,
and `clone-claim` produce or fetch the claim body; this playbook lands it.
All bash idioms live in `../reference/gh-cookbook.md`.

Two landing paths — pick by how the claim was produced:

- **fs-forge-managed** — `edit`/`clone --commit` (the primary path for
  `edit-claim`/`clone-claim`). Go to "fs-forge-managed flow" below.
- **Manual** — `create` (always), or a `gh`-based edit/clone fallback. Go to
  "Manual flow" below.

## Governance — read once, applies everywhere

- **PR-only. Never commit to `main`.** Every change is a branch → PR → merge.
- Show the client the proposed change and get approval **before** opening a
  PR or running `--commit`.
- Tool preference: try `fs-forge-cli` first; the raw `gh` idioms in the
  cookbook (and host composite tools like `create_claim_pr`,
  `github_create_pr_with_changes`, `github_propose_changes_dry_run`, when
  present) are the fallback for what it doesn't cover.

## fs-forge-managed flow (`edit`/`clone --commit`)

1. **Capture the goal as an issue** — same as the manual flow's step 0 below,
   for the audit trail.
2. **Dry-run** the `edit`/`clone` command with `--diff` (no `--commit`); fix
   any validation errors; show the diff to the client and get approval.
3. **Re-run with `--commit`.** Per the cookbook's `--commit` warning, this one
   command creates the branch, commits the claim, opens/merges the PR,
   dispatches and waits for hydration, and merges the resulting wet PR — all
   without further input.
4. **Report the outcome to the client.** Do **not** poll for the workflow, run
   a separate hydrate, or merge a wet PR yourself — it already happened. If
   the client asks for status, check the dispatched `provision-claim.yaml`
   run; only trigger a manual hydrate (manual flow's step 5) if they
   explicitly ask for one.

A `--commit` that fails (invalid claim, existing `fs-forge/{kind}-{name}`
branch, etc.) surfaces as a CLI error before anything is dispatched — fix the
reported problem and re-run.

## Manual flow (`create`, or a `gh`-based edit/clone fallback)

0. **Capture the goal as an issue** before touching branches. Fill in the issue
   template at `../templates/claim-issue.md` (client's terms, not "claim") and open
   it in the claims repo. Keep the issue number — reference it in the PR
   (`Closes #N`).
   ```bash
   gh issue create --repo {claims_repo} --title "{goal}" --body "{what the client asked for}"
   ```

1. **Validate the generated or updated file before opening the PR:**
   - Schema — run `npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}` (see `../reference/fs-forge-cookbook.md`).
   - References — every `user:` / `group:` / `system:` / `domain:` /
     `ref:secretsclaim:` points at an existing claim.
   - Naming — matches `^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$`, ≤63 chars (see `../reference/reference.md`).
   - Uniqueness — for a create, no claim of that kind/name already exists. If one
     does, stop and tell the client it would duplicate an existing entity.
2. **Branch** from main.
3. **Write** the full file on the branch (create or update).
4. **Open the PR**, show it to the client, **merge** it (squash).
5. **Hydrate** with the workflow for the claim's family (see the hydrate table in
   `../reference/gh-cookbook.md`) — GitHub claims take `kind`+`name`;
   Secrets/TFWorkspace take `name` only. Wait for `conclusion: success`.
   - When a create adds a new user *and* references it elsewhere (e.g. adds them to
     a team), hydrate the `UserClaim` **first**, then the dependent claim.
6. **Merge the state PR** that hydration opened — on `state-github` (GitHub claims,
   usually auto-merged) or `state-infra` (Secrets/TFWorkspace, merge it yourself).
7. Report the landed change to the client in plain terms.

A change that stops after step 4 is only half-applied — the platform won't
reconcile until hydration runs and its state PR merges. Do not stop early.

## Delete flow

Deletion is governed the same way — it does not just remove the file.

1. Confirm the target claim exists; identify its `kind` and `name`.
2. Run the platform's delete workflow (it removes the claim and its state
   resources together):
   ```bash
   gh workflow run "GitHub claim: delete" --repo {claims_repo} \
     --field kind={ClaimKind} --field name={claim-name}
   ```
   If that workflow isn't present, open a PR removing the claim file, merge it,
   then hydrate so the reconciler prunes the orphaned state.
3. Wait for the run to finish, then merge the resulting state PR.
4. Confirm removal to the client.

## Kind → hydration name

Hydration keys on the **claim name**, not the file path:

| Kind | `name` field |
|---|---|
| ComponentClaim | repo name |
| GroupClaim | team name (the normalized slug, not the display name) |
| UserClaim | github username |
| SystemClaim / DomainClaim / SecretsClaim / OrgWebhookClaim / TFWorkspaceClaim | claim name |
