# fs-forge watch-checks Reference

Monitor check runs on state-repo PRs produced by `create`/`edit`/`clone`/`delete --commit`. Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`. Flags, exit codes, and output shapes: `watch-checks --help --json`.

**Version guard:** requires `fs-forge-cli >= 0.10.0`. On older versions it
errors as an unrecognized command — fall back to `gh`: find the state-repo PR
(`gh pr list --repo {org}/state-github --search <name> --state all`) and read
its checks (`gh pr checks <pr> --repo {org}/state-github`).

## Modes

Two modes, mutually exclusive:

- **Watch (default)** — streams live check-run status until all checks pass, one
  fails, or `--timeout` is reached.
- **`--current`** — point-in-time snapshot: reads current check-run state and
  exits immediately. Use as the opening move in `../playbooks/reconciliation.md`
  before a manual field diff. Also shows destroy check runs from deletions,
  which land on the `last-state-pr` PR (not the deletion wet-PR).

## State-repo discovery

Resolves state repos from `--org`: `<org>/state-github` and `<org>/state-infra`.
Override with `--state-repos` when the org uses non-default names.

Exit 1 (a failed check) routes to
`../playbooks/troubleshooting.md#terraform-plan-status-check-pre-merge`.
