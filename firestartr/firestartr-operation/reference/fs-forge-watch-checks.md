# fs-forge watch-checks Reference

Monitor check runs on state-repo PRs produced by `create`/`edit`/`clone`/`delete
--commit`. Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

**Version guard:** requires `fs-forge-cli >= {tbd}`. Errors as an unrecognized
command on older versions — confirm availability with
`npx @firestartr/fs-forge-cli@{version} watch-checks --help` before use.

## Modes

Two modes, mutually exclusive:

- **Watch (default)** — streams live check-run status until all checks pass, one
  fails, or `--timeout` is reached. Exit code reflects the final outcome.
- **`--current`** — point-in-time snapshot: reads current check-run state and
  exits immediately. Use as the opening move in `../playbooks/reconciliation.md`
  before a manual field diff.

## State-repo discovery

Resolves state repos from `--org`: `<org>/state-github` and `<org>/state-infra`.
Override with `--state-repos` when the org uses non-default names.

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} watch-checks \
  --org={org} --cr-name=<name> \
  [--current] [--timeout=<seconds>] [--json] \
  [--state-repos=<repo1,repo2>]
```

`--cr-name` is the claim name (repo or team name). Required.

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--org` | — | GitHub org slug (required) |
| `--cr-name` | — | Claim name to watch (required) |
| `--timeout` | 300 | Seconds before exit 2; watch mode only |
| `--json` | false | Emit NDJSON instead of TTY table |
| `--state-repos` | `<org>/state-github,<org>/state-infra` | Override state-repo names |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | All checks passed |
| 1 | At least one check failed — route to `../playbooks/troubleshooting.md#terraform-plan-status-check-pre-merge` |
| 2 | Timeout reached before all checks completed (watch mode only) |
| 3 | No open PR found for `--cr-name` |

## Output formats

**TTY (default)** — one row per check run:

```
REPO                       CHECK             STATUS
<org>/state-github         terraform_plan    passed
<org>/state-infra          terraform_plan    pending
```

**`--json`** — one JSON object per line (NDJSON):

```json
{"repo": "<org>/state-github", "check": "terraform_plan", "status": "passed"}
{"repo": "<org>/state-infra", "check": "terraform_plan", "status": "pending"}
```

`status` values: `pending`, `passed`, `failed`, `timed_out`, `not_found`.
