# fs-forge Cookbook

The repeated `fs-forge` idioms every mutating playbook builds on. `{org}` and
`{version}` are resolved from `firestartr-config.yaml` before any of these run.
Beyond invocation and validation, idioms are split by topic — read the sibling
that matches the task instead of assuming everything lives here:

| Need to… | Read |
|---|---|
| discover a kind's flags, pass `{org}`, use `--commit`, or preview claim defaults | `fs-forge-mutation-shared.md` |
| read, edit, or clone an existing claim | `fs-forge-edit-clone.md` |
| list an org's claims, render its topology, or print an arbitrary relation graph | `fs-forge-discovery.md` |
| check whether a name is free before create/edit/delete | `fs-forge-preflight.md` |
| discover, attach, edit, or remove a Feature on a ComponentClaim | `fs-forge-features.md` |
| author a brand-new claim with `create` | `../playbooks/create-claim.md` — the invocation lives there, not here |

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} <args>
```

**Hard dependency — no fallback.** If the invocation fails, stop immediately
and tell the user:

> `fs-forge` could not be run via `npx`.
> Ensure `npx` is available (Node >= 18) and that you have network access.
> Do not proceed without it.

Never hand-author a claim body when fs-forge is unavailable.

## Discover the CLI's own machine-readable contracts

Local and offline — no `--org`, no network, no claims-repo checkout:

```bash
npx @firestartr/fs-forge-cli@{version} schema list --json
npx @firestartr/fs-forge-cli@{version} schema show CommandHelpJson
npx @firestartr/fs-forge-cli@{version} schema show RelationGraph
npx @firestartr/fs-forge-cli@{version} schema show MutationDiff
```

`schema list --json` prints the three published contract names; `schema show
<Name>` prints that JSON Schema verbatim. Read one whenever a command's JSON
output needs more certainty than this cookbook's prose gives:
`CommandHelpJson` for `--help --json` (`fs-forge-mutation-shared.md`),
`RelationGraph` for `discovery map --json`/`diagram print`
(`fs-forge-discovery.md`), `MutationDiff` for `edit`/`clone --diff --json
--show-defaults` (`fs-forge-edit-clone.md`).

## List supported claim kinds

```bash
npx @firestartr/fs-forge-cli@{version} kinds --json
```

Local and offline. Each entry's `description` is the schema's own one-line
summary — prefer it, translated to client terms (never "claim" — Rule 1,
`../SKILL.md`), over composing your own when explaining what's available.

## Validate a claim file (syntactic only)

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}
```

fs-forge validates schema, types, and enum constraints. It does **not** check
cross-claim references, duplicates, or naming rules — those are the skill's
responsibility (see the validation split in `reference.md`).

Schema lookup is relative to the current working directory (`{cwd}/schemas/`).
Run `validate`/`create`/`edit`/`clone` from a directory that has one — e.g. a
clone of `{claims_repo}` (which ships it), or a `schemas/` symlink to the CLI's
bundled copy — not an arbitrary scratch directory like `/tmp`.
