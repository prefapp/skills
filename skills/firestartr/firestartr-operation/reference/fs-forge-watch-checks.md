# fs-forge watch-checks Reference

Monitor check runs on state-repo PRs produced by `create`/`edit`/`delete --commit`. Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`SKILL.md` Step 1. Flags, exit codes, and output shapes: `watch-checks --help --json`.

## Modes

Two modes, mutually exclusive:

- **Watch (default)**: streams live check-run status until all checks pass, one
  fails, or `--timeout` is reached.
- **`--current`**: point-in-time snapshot: reads current check-run state and
  exits immediately. Use as the opening move in `../playbooks/reconciliation.md`
  before a manual field diff. Also shows destroy check runs from deletions,
  which land on the `last-state-pr` PR (not the deletion wet-PR).

## State-repo discovery

Resolves state repos from the org's config entry (`config-schema.md`; defaults
`state-github` and `state-infra`). `--state-repos` overrides both.

Exit 1 (a failed check) routes to
`../playbooks/troubleshooting.md#terraform-plan-status-check-pre-merge`.
