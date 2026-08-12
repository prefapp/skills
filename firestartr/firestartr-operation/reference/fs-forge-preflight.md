# fs-forge Preflight Reference

Read-only collision check before create/edit/delete — faster and scriptable
versus eyeballing a claims listing. Sibling of `fs-forge-cookbook.md`;
`{org}`/`{version}` come from `firestartr-config.yaml`.

## Coverage

Four kinds only, and under a **different short ID** than the rest of the
CLI: `repo` (not `component`), `team`, `user`, `tfworkspace` — any other
value is rejected. No preflight for system, domain, secrets, or org
webhooks; use the discovery-based check (`fs-forge-discovery.md`) for those.
`tfworkspace`'s provider check is always a no-op (claims-only, no TFC client
yet) — only its claims-map check runs.

**Predates this CLI?** `npx @firestartr/fs-forge-cli@{version} preflight --help`
errors as an unrecognized command when it does — fall back to the
discovery-based check.

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} preflight --org={org} \
  --kind <repo|team|user|tfworkspace> --name <name> \
  (--create | --edition --old-name <old-name> | --deletion) \
  [--scope claims|provider|all] [--json]
```

One of `--create`/`--edition`/`--deletion` is required, mutually exclusive.
`--edition` checks the *old* name's claim exists, then — unless `--scope
claims`, or `--name` equals `--old-name` (no identity change) — the *new*
name's provider availability. `--scope` defaults to `all`.

`repo`/`team` check resource existence; `user` checks **org membership**, not
whether the GitHub login exists.

## Exit codes

| Code | Meaning | Subcommand |
|---|---|---|
| 0 | ok | any |
| 1 | claim conflict — `<Kind>-<name>` already in claims-map | `--create` |
| 2 | provider conflict — exists at GitHub, no matching claim | any |
| 3 | not found — referenced claim doesn't exist | `--edition`/`--deletion` |
| 4 | `GITHUB_TOKEN` missing scopes (`read:org`, `repo`) | any |
| 5 | provider API unreachable | any |

A provider conflict (2): tell the client plainly that the resource already
exists at GitHub outside Firestartr's tracking, and stop — there's no import
process to route them to yet (see
`../docs/adr/0009-preflight-no-import-or-rename-flow.md`).

## `--json`

`{"status": "ok"|"conflict"|"not_found"|"error", "kind": "<ClaimKind>", "name": "…", "conflict"?: "claim"|"provider"}`
— `kind` is always the full claim kind, even though `--kind` takes the short
ID. `--edition` with an actual identity change prints **two** JSON lines
(old name's claims check, then the new name's provider check) — read every
stdout line, don't assume a single JSON document.
