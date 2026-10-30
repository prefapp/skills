# fs-forge Preflight Reference

Read-only collision check before create/edit/delete: faster and scriptable
versus eyeballing a claims listing. Sibling of `fs-forge-cookbook.md`;
`{org}`/`{version}` come from `SKILL.md` Step 1.

## Coverage

Only kinds with a `preflight` value in `kinds show <id> --json`. Pass that
value to `--kind`, not the kind's short ID (component → `repo`); any other value
is rejected. Kinds with `preflight: null`: use the discovery-based check
(`fs-forge-discovery.md`).
`tfworkspace`'s provider check is always a no-op (claims-only, no TFC client
yet), only its claims-map check runs.

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} preflight --org={org} \
  --kind <repo|team|user|tfworkspace> --name <name> \
  (--create | --edition --old-name <old-name> | --deletion) \
  [--scope claims|provider|all] [--json]
```

`--edition` checks the *old* name's claim exists, then, unless `--scope
claims`, or `--name` equals `--old-name` (no identity change): the *new*
name's provider availability.

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

A provider conflict (2): tell the client plainly that the resource already
exists at GitHub outside Firestartr's tracking, and stop: there's no import
process to route them to yet.

## `--json`

`{"status": "<ok|conflict|not_found|error>", "kind": "<ClaimKind>", "name": "…", "conflict": "<claim|provider>"}`:
`kind` is always the full claim kind, even though `--kind` takes the
`preflight` value; `conflict` is present only when `status` is `"conflict"`. `--edition`
with an actual identity change prints **two** JSON lines (old name's claims
check, then the new name's provider check): read every stdout line, don't
assume a single JSON document.
