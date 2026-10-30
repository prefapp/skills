# fs-forge Preflight Reference

Read-only collision check before create/edit/delete.

## Coverage

Pass the `preflight` value from `kinds show <id> --json` to `--kind`, not the short ID (component → `repo`); other values are rejected. For `preflight: null`, use `fs-forge-discovery.md`. `tfworkspace` checks claims-map only: its provider check is a no-op (no TFC client).

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} preflight --org={org} \
  --kind <preflight-value> --name <name> \
  (--create | --edition --old-name <old-name> | --deletion) \
  [--scope claims|provider|all] [--json]
```

`--edition` checks the old claim, then the new provider name unless `--scope claims` or the name is unchanged. This check is not a rename flow; `edit` cannot rename claims.

`repo`/`team` check resource existence; `user` checks **org membership**, not
whether the GitHub login exists.

## Exit codes

| Code | Meaning | Subcommand |
|---|---|---|
| 0 | ok | any |
| 1 | claim conflict: `<Kind>-<name>` already in claims-map | `--create` |
| 2 | provider conflict: exists at GitHub, no matching claim | any |
| 3 | not found: referenced claim doesn't exist | `--edition`/`--deletion` |
| 4 | token missing scopes (`read:org`, `repo`) | any |
| 5 | provider API unreachable | any |

Provider conflict (2): tell the client the resource exists at GitHub outside Firestartr tracking; stop. There is no import process.

## `--json`

`{"status": "<ok|conflict|not_found|error>", "kind": "<ClaimKind>", "name": "…", "conflict": "<claim|provider>"}`:
`kind` is the full claim kind; `conflict` appears only for `"conflict"` status. Identity-changing `--edition` prints **two** JSON lines (old claim, then new provider check): read every line, not one JSON document.
