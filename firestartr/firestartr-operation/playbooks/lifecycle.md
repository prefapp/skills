# Lifecycle Playbook

The one flow every mutating operation follows. `create-claim`, `edit-claim`,
and `clone-claim` produce or fetch the claim body; this playbook lands it.
All bash idioms live in `../reference/gh-cookbook.md`.

Two landing paths — pick by how the claim was produced:

- **fs-forge-managed** — `create`/`edit`/`clone --commit`. The primary path
  for `edit-claim`/`clone-claim`. Go to "fs-forge-managed flow" below.
- **Manual** — `create` without `--commit`, or a `gh`-based edit/clone
  fallback. Go to "Manual flow" below.

For `create-claim`, the client's own choice of ending decides the path: landing
immediately routes here to fs-forge-managed; an offline artifact routes to
manual.

## Governance — read once, applies everywhere

- **PR-only. Never commit to `main`.** Every change is a branch → PR → merge.
- Show the client the proposed change and get approval **before** opening a
  PR or running `--commit`.
- Tool preference: try `fs-forge-cli` first; the raw `gh` idioms in the
  cookbook (and host composite tools like `create_claim_pr`,
  `github_create_pr_with_changes`, `github_propose_changes_dry_run`, when
  present) are the fallback for what it doesn't cover.

## fs-forge-managed flow (`create`/`edit`/`clone --commit`)

1. **Capture the goal as an issue** — same as the manual flow's step 0 below,
   for the audit trail.
2. **Dry-run** the `create`/`edit`/`clone` command with `--diff` (no
   `--commit`); fix any validation errors; show the relation diff to the
   client (a one-hop tree, not a field diff — `../reference/fs-forge-discovery.md`)
   and get approval.
3. **Re-run with `--commit`** — see the cookbook's `--commit` warning.
4. **Report the outcome.** Don't poll, hydrate, or merge the wet PR yourself
   — `--commit` already did it. Status check: the dispatched
   `provision-claim.yaml` run. Manual hydrate only if the client explicitly
   asks (manual flow step 5).
5. **Close the audit-trail issue**, linking the merged claim PR in the closing
   comment. `--commit`'s auto-generated PR has no `Closes #N` footer (there's
   no flag for it), so the issue is only linked back to the change if you do
   it here.

A `--commit` that fails (invalid claim, an already-existing target claim for
`create`/`clone`, existing `fs-forge/{kind}-{name}` branch, etc.) surfaces as
a CLI error before anything is dispatched — fix the reported problem and
re-run.

## Manual flow (`create` without `--commit`, or a `gh`-based edit/clone fallback)

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
