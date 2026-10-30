# fs-forge Discovery Reference

Read-only claim inventory and relation graphs.

## Discover an org's elements

List the claims-map without a clone or `gh api` path-walking:

```bash
npx @firestartr/fs-forge-cli@{version} discovery org-elements --org={org}
```

One API call. Options: `discovery org-elements --help --json`. Prefer over a potentially stale catalog for raw inventory.

## Discover an org's relation map (topology, ownership)

Render live claims-repo ownership/grouping relations, not the hydrated catalog:

```bash
npx @firestartr/fs-forge-cli@{version} discovery map --org={org}
```

Network-bound: downloads one claims-repo tarball and needs auth like `edit`. Recognizes only `owner`, `maintainedBy`, `platformOwner`, `subComponentOf`, `system`, `domain`, `parent`, `children`, and `members`; never API references or inline Features. Prefer it for topology when the catalog may be stale (~6h hydration lag).

Options: `discovery map --help --json`. Use `--json` when the result feeds another step; its `RelationGraph` schema is available via `schema show RelationGraph` (`fs-forge-cookbook.md`).

For ownership chains, walk `edges` from the target node until none remain; each edge carries its `relation` (`owner`, `parent`, `system`, …).

## Render an arbitrary relation graph

For non-claim graphs, including `discovery map --json` merged with untracked catalog `Resource` nodes:

```bash
npx @firestartr/fs-forge-cli@{version} diagram print --file {graph.json}
cat {graph.json} | npx @firestartr/fs-forge-cli@{version} diagram print
```

Local and offline; no `--org`. Input: same `RelationGraph` shape as `discovery map --json`. For an org's claim topology, use `discovery map`.
