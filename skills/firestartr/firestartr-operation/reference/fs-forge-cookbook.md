# fs-forge Cookbook

Read the reference for the task:

| Need to… | Read |
|---|---|
| discover a kind's flags, pass `{org}`, use `--commit`, or preview claim defaults | `fs-forge-mutation-shared.md` |
| read or edit an existing claim | `fs-forge-edit.md` |
| list an org's claims, render its topology, or print an arbitrary relation graph | `fs-forge-discovery.md` |
| check whether a name is free before create/edit/delete | `fs-forge-preflight.md` |
| watch check runs on a state-repo PR, or get point-in-time check status | `../playbooks/reconciliation.md` |
| discover, attach, edit, or remove a Feature on a ComponentClaim | `fs-forge-features.md` |
| author a brand-new claim with `create` | `../playbooks/create-claim.md`; the invocation lives there, not here |

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} <args>
```

**Hard dependency: no fallback.** If the invocation fails, stop immediately
and tell the user:

> `fs-forge` could not be run via `npx`.
> Ensure `npx` is available (Node >= 22) and that you have network access.
> Do not proceed without it.

Never hand-author a claim body when fs-forge is unavailable.

## Discover the CLI's own machine-readable contracts

Local and offline: discover the published contracts and inspect one as JSON Schema:

```bash
npx @firestartr/fs-forge-cli@{version} schema list --json
npx @firestartr/fs-forge-cli@{version} schema show <Name>
```

## List and inspect claim kinds

```bash
npx @firestartr/fs-forge-cli@{version} kinds --json
npx @firestartr/fs-forge-cli@{version} kinds show <id> --json
```

Local and offline. Prefer each entry's `description`, translated to client terms, when explaining what's available.

## Validate a claim file

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}
```

fs-forge validates schema, types, enum constraints, and attached Feature
`args` (`fs-forge-features.md`). It does **not** check
cross-claim references, duplicates, or naming rules: those are the skill's
responsibility (see the validation split in `reference.md`).
