# Reconciliation Playbook

Answer "is my repo/team in sync?" and related drift/alignment questions. This is
**read-only** — never mutate here; if a fix is needed, route the client to
`create-claim`/`edit-claim` + `lifecycle`. Bash idioms are in
`../reference/gh-cookbook.md`; the claim→state map is in `../reference/reference.md`.

## Opening move — watch-checks --current (CLI >= {tbd})

Before a manual field diff, get a point-in-time check-status snapshot:

```bash
npx @firestartr/fs-forge-cli@{version} watch-checks <Kind>-<name> --org={org} --current [--cr-name=<name>]
```

Exit 0 (all checks passed) with no drift suspicion → report aligned, no further
diff needed. Any other exit, or if the client suspects drift → proceed to
[The comparison](#the-comparison) below.
Full reference: `../reference/fs-forge-watch-checks.md`.

## The comparison

Desired state = the claim. Actual reconciled state = the matching resource in the
state repo (`state-github` or `state-infra`, per the claim→state map). Each state
file carries `metadata.annotations.firestartr.dev/claim-ref` back to its claim.

For a named entity:
1. Find the state resource whose `claim-ref` (or `external-name`) matches.
2. Read the source claim.
3. Compare the fields that matter for its kind:
   - repo: visibility, description, branch strategy, features, permissions
   - team: members, privacy
   - membership: role
4. Report each field as aligned or drifted (claim value vs state value).

## The un-hydrated trap — check this first

Reported "drift" is often **not** real drift, just a change that hasn't hydrated
yet. Before calling anything drifted, rule this out:

- Is there an open PR on the state repo (branch `automated/CRs-update`)? Then a
  hydration is pending — the state will catch up once it merges.
- Did the claim change more recently than the state resource? Then hydration hasn't
  run for it. Recommend hydrating (kind + name), not editing.

Only a mismatch that persists **after** hydration and state-PR merge is genuine
drift. Warn the client when the "drift" is really un-hydrated change, so they don't
chase a false positive.

## Categories to report

| Status | Meaning | Next step |
|---|---|---|
| aligned | claim and state agree | none |
| drifted | differ after hydration | fix the claim, or re-hydrate if the claim is right |
| pending | state PR open / claim newer than state | wait / hydrate — **not** drift |
| missing state | claim exists, no state resource | hydrate (kind + name) |
| orphaned | state resource with no claim | claim was deleted; prune via delete flow |

> **Check this first:** rule out the un-hydrated trap above first. Genuine
> drift after hydration — see
> `troubleshooting.md#terraform-apply--operator-reconciliation-post-merge`.

## Full alignment sweep

For a whole-org check, list every state resource, resolve each back to its claim,
and tabulate:

| Scope | Total | Aligned | Drifted | Pending | Missing | Orphaned |
|---|---|---|---|---|---|---|

Flag critical rows (missing state for a live claim, orphaned resources) for the
client.

## Freshness

Catalog and state hydrate on a schedule (catalog every 6h). If the latest claim
commit is newer, note the lag and offer to trigger hydration rather than
reporting stale data as drift.
