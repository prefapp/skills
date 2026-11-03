# Reconciliation Playbook

Answer repo/team sync and drift questions. **Read-only:** route fixes to `create-claim`/`edit-claim` + `lifecycle`. Bash: `../reference/gh-cookbook.md`; claim→state map: `../reference/reference.md`.

## Opening move: watch-checks --current

Before a manual field diff, get a point-in-time check-status snapshot:

```bash
npx @firestartr/fs-forge-cli@{version} watch-checks <Kind>-<name> --org={org} --current [--cr-name=<name>]
```

Exit 0 (all checks passed) without drift suspicion → report aligned; otherwise [compare](#the-comparison). Live watch: omit `--current` to wait until checks finish or timeout. Configured state repos are the default; `--state-repos` overrides them. Flags: `watch-checks --help --json`. Exit 1: `troubleshooting.md#terraform-plan-status-check-pre-merge`.

## The comparison

Desired = claim; actual = matching state resource (`state-github` or `state-infra`, per claim→state map). State files link back via `metadata.annotations.firestartr.dev/claim-ref`. For a named entity:

### Step 1: Find the state resource

Whose `claim-ref` (or `external-name`) matches.

### Step 2: Read the source claim

### Step 3: Compare the fields that matter for its kind

- repo: visibility, description, branch strategy, features, permissions
- team: members, privacy
- membership: role

### Step 4: Report each field as aligned or drifted

Claim value vs state value.

## The un-hydrated trap: check this first

Before calling a mismatch drift, check for pending hydration:
- Open state-repo PR on `automated/CRs-update` → wait for merge.
- Claim newer than state → recommend hydrating (kind + name), not editing.

Warn the client: only a mismatch persisting **after** hydration and state-PR merge is genuine drift.

## Categories to report

| Status | Meaning | Next step |
|---|---|---|
| aligned | claim and state agree | none |
| drifted | differ after hydration | fix the claim, or re-hydrate if the claim is right |
| pending | state PR open / claim newer than state | wait / hydrate; **not** drift |
| missing state | claim exists, no state resource | hydrate (kind + name) |
| orphaned | state resource with no claim | claim was deleted; prune via delete flow |

> **Check this first:** rule out the un-hydrated trap above first. Genuine
> drift after hydration: see
> `troubleshooting.md#terraform-apply--operator-reconciliation-post-merge`.

## Full alignment sweep

For a whole-org check, resolve every state resource to its claim and tabulate:

| Scope | Total | Aligned | Drifted | Pending | Missing | Orphaned |
|---|---|---|---|---|---|---|

Flag missing state for a live claim and orphaned resources.

## Freshness

Catalog and state hydrate on a schedule (catalog every 6h). If the latest claim commit is newer, note the lag and offer hydration; don't report stale data as drift.
