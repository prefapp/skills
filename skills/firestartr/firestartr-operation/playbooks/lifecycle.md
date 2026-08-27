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

## Governance

SKILL.md's Common rules (show-plan-before, step commitment, etc.) apply
here too. This playbook adds: **PR-only, never commit to `main`** — every
change is a branch → PR → merge, and the host composite tools
(`create_claim_pr`, `github_create_pr_with_changes`,
`github_propose_changes_dry_run`, when present) are fallbacks for what
`fs-forge-cli`/the `gh` cookbook idioms don't cover.

## fs-forge-managed flow (`create`/`edit`/`clone --commit`)

### Step 1 — Capture the goal as an issue

Same as the manual flow's Step 0 below, for the audit trail.

### Step 2 — Dry-run

The `edit`/`clone` command with `--diff` (no `--commit`); fix any validation
errors; show the Claim diff to the client (a unified YAML diff, not a
relation tree — `../reference/fs-forge-edit-clone.md`) and get approval.

### Step 3 — Re-run with `--commit`

See `../reference/fs-forge-mutation-shared.md`'s `--commit` warning. For CLI
`>= {tbd}`, always add `--wait-for-checks` — it overrides the CLI's own
`false` default so the claims-repo PR also waits for its checks before
merging (the state-repo PR always waits regardless).

### Step 4 — Report the outcome

Don't poll, hydrate, or merge the wet PR yourself — `--commit` already did
it. Status check: the dispatched `provision-claim.yaml` run. Manual hydrate
only if the client explicitly asks (manual flow Step 5).

> **Check this first:** if the dispatched run failed, the symptom lookup
> at `troubleshooting.md#symptom-lookup--start-here` routes to the right
> surface (PR-verify, hydrate, plan, state-PR merge, or apply).

### Step 5 — Close the audit-trail issue

Link the merged claim PR in the closing comment. `--commit`'s
auto-generated PR has no `Closes #N` footer (there's no flag for it), so
the issue is only linked back to the change if you do it here.

A `--commit` that fails (invalid claim, an already-existing target claim for
`create`/`clone`, existing `fs-forge/{kind}-{name}` branch, etc.) surfaces as
a CLI error before anything is dispatched — fix the reported problem and
re-run.

> **Check this first:** the exact CLI error message — see
> `troubleshooting.md#fs-forge-cli-command-failures` if it doesn't explain
> the failure.

## Manual flow (`create` without `--commit`, or a `gh`-based edit/clone fallback)

### Step 0 — Capture the goal as an issue

Before touching branches. Fill in the issue template at
`../templates/claim-issue.md` (client's terms, not "claim") and open it in
the claims repo. Keep the issue number — reference it in the PR
(`Closes #N`).

```bash
gh issue create --repo {claims_repo} --title "{goal}" --body "{what the client asked for}"
```

### Step 1 — Validate the generated or updated file before opening the PR

- Schema — run `npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}` (see `../reference/fs-forge-cookbook.md`).
- References — every `user:` / `group:` / `system:` / `domain:` /
  `ref:secretsclaim:` points at an existing claim.
- Naming — matches `^[a-z0-9]([a-z0-9._-]*[a-z0-9])?$`, ≤63 chars (see `../reference/reference.md`).
- Uniqueness — for a create, no claim of that kind/name already exists. If one
  does, stop and tell the client it would duplicate an existing entity.

### Step 2 — Branch from main

### Step 3 — Write the full file on the branch (create or update)

### Step 4 — Open the PR, show it to the client, merge it (squash)

### Step 5 — Hydrate

With the workflow for the claim's family (see the hydrate table in
`../reference/gh-cookbook.md`) — GitHub claims take `kind`+`name`;
Secrets/TFWorkspace take `name` only. Wait for `conclusion: success`.
- When a create adds a new user *and* references it elsewhere (e.g. adds them to
  a team), hydrate the `UserClaim` **first**, then the dependent claim.

> **Check this first:** a failed or timed-out run — see
> `troubleshooting.md#hydrate-workflow-dispatchexecution` if it doesn't
> explain the failure.

### Step 6 — Merge the state PR

That hydration opened — on `state-github` (GitHub claims, usually
auto-merged) or `state-infra` (Secrets/TFWorkspace, merge it yourself).

> **Check this first:** a PR that won't merge — see
> `troubleshooting.md#state-pr-merge` if it doesn't explain the failure.

### Step 7 — Report the landed change to the client in plain terms

A change that stops after Step 4 is only half-applied — the platform won't
reconcile until hydration runs and its state PR merges. Do not stop early.

## Delete flow

Deletion is governed the same way — it does not just remove the file. Kind
support differs from every other operation, so check it before planning:

- **Supported** — ComponentClaim, GroupClaim, UserClaim, OrgWebhookClaim,
  TFWorkspaceClaim, SecretsClaim.
- **Not supported** — SystemClaim, DomainClaim have no delete workflow, old
  or new. Tell the client, then go straight to "No delete workflow exists"
  below.

### Primary path — `fs-forge-cli delete` (current CLI version)

#### Step 1 — Capture the goal as an issue

Same as the fs-forge-managed flow's Step 1 above, for the audit trail.

#### Step 2 — Decide flags before dry-running

So the dry-run previews the exact command you'll later add `--commit` to:
- Always include `--wait-for-checks` — it overrides the CLI's own
  `false` default so the claims-repo PR also waits for its checks before
  merging (the state-repo PR always waits regardless).
- For TFWorkspaceClaim, ask the client whether to keep variant CRs and
  pass `--include-variants`/`--no-include-variants` accordingly; every
  other kind has no variants, so leave this flag off.
- Optional fast check first, for ComponentClaim/GroupClaim/UserClaim/
  TFWorkspaceClaim: `preflight --deletion`
  (`../reference/fs-forge-preflight.md`) confirms the claim exists in one
  sub-second call — Step 3's dry-run confirms it either way, so this is a
  scriptable shortcut, not a replacement.

#### Step 3 — Dry-run

No `--commit`, to confirm the claim exists and preview the dispatch:

```bash
npx @firestartr/fs-forge-cli@{version} delete <Kind> <name> --org={org} \
  --wait-for-checks [--include-variants|--no-include-variants]
```

Show the client the printed plan — kind, name, `includeVariants`,
`waitForClaimChecks` — it should match the flags chosen in Step 2.

#### Step 4 — Get approval, then re-run with `--commit`

```bash
npx @firestartr/fs-forge-cli@{version} delete <Kind> <name> --org={org} \
  --wait-for-checks [--include-variants|--no-include-variants] --commit
```

`--commit` dispatches `unprovision-claim.yaml`, which fully self-services
— it merges both the state-repo PR and the claims-repo PR itself. Don't
poll or merge anything yourself; report the dispatched run.

#### Step 5 — Check run placement

Destroy check runs and commit statuses land on the wet-PR referenced by
the deleted CR's `firestartr.dev/last-state-pr` annotation — not the
deletion wet-PR. The deletion wet-PR is merged once its CI passes; destroy
feedback lives on the `last-state-pr` PR. Fallback: if `last-state-pr` is
missing, check runs go to the deletion wet-PR. Inspect destroy status
with:
`npx @firestartr/fs-forge-cli@{version} watch-checks <Kind>-<name> --org={org} --current`

#### Step 6 — Close the audit-trail issue

Link the merged claim PR in the closing comment (`--commit` has no
`Closes #N` footer to do this automatically).

### Manual fallback (older CLI, supported kind)

When `{version}` predates the `delete` command (Step 1's version-check
paragraph), dispatch the platform's per-kind delete workflow directly —
it removes the claim and its state resources but does **not** merge the
resulting state PR itself:

```bash
gh workflow run "GitHub claim: delete" --repo {claims_repo} \
  --field kind={ClaimKind} --field name={claim-name}
```

This covers ComponentClaim/GroupClaim/UserClaim/OrgWebhookClaim only —
TFWorkspaceClaim/SecretsClaim each have their own per-kind delete workflow
instead; `gh workflow list --repo {claims_repo} --all` finds it
(`../reference/gh-cookbook.md` has the general workflow-dispatch idiom). Wait
for the run to finish, then merge the resulting state PR yourself.

### No delete workflow exists

For SystemClaim/DomainClaim, or any kind if no delete workflow is reachable:
do not remove the claim file yourself. Tell the client there is no automated
delete path for this claim kind and they'll need to remove it by hand.

Otherwise, confirm removal to the client once the change has landed.

## Kind → hydration name

Hydration keys on the **claim name**, not the file path:

| Kind | `name` field |
|---|---|
| ComponentClaim | repo name |
| GroupClaim | team name (the normalized slug, not the display name) |
| UserClaim | github username |
| SystemClaim / DomainClaim / SecretsClaim / OrgWebhookClaim / TFWorkspaceClaim | claim name |
