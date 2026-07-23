# Lifecycle Playbook

The one flow every mutating operation follows. `create-claim` and `edit-claim`
produce the file body; this playbook lands it. All bash idioms live in
`../reference/gh-cookbook.md`.

## Governance — read once, applies everywhere

- **PR-only. Never commit to `main`.** Every change is a branch → PR → merge.
- Show the client the proposed change and get approval before opening the PR.
- Prefer host composite tools when present (`create_claim_pr`,
  `github_create_pr_with_changes`, `github_propose_changes_dry_run`); fall back to
  the raw `gh` idioms in the cookbook when they aren't wired.

## Create / edit flow

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
