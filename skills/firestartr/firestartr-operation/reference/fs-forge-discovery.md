# fs-forge Discovery Reference

Read-only ways to inspect an org's claims and render relation graphs. Sibling
of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

## Discover an org's elements

List every claim in an org's claims repo straight from the claims-map — no
clone, no `gh api` path-walking:

```bash
npx @firestartr/fs-forge-cli@{version} discovery org-elements --org={org}
```

Read-only, one API call. Add `--json` for structured output grouped by kind,
or repeatable `--kind <kind>` to filter (e.g. `--kind component --kind
group`). `--claims-repo` overrides the default `claims` repo name. This is
the fast path for "what does this org have" — prefer it over `catalog`'s
hydrated view when raw claim inventory is enough and the catalog may be
stale.

## Discover an org's relation map (topology, ownership)

Render the ownership/grouping tree derived from claim references — not a
hydrated catalog view, the live claims-repo relations:

```bash
npx @firestartr/fs-forge-cli@{version} discovery map --org={org}
```

Read-only but network-bound (downloads one claims-repo tarball; needs
`GITHUB_TOKEN` like `edit`/`clone`). Recognizes only `owner`, `maintainedBy`,
`platformOwner`, `subComponentOf`, `system`, `domain`, `parent`, `children`,
and `members` — API references and inline Features are never part of this
graph. This is the tool for "show the org structure" / "what's in system Y" /
topology questions — prefer it over the catalog playbook whenever the catalog
might be stale, since this reads the claims repo directly with no ~6h
hydration lag.

Options: repeatable `--kind <kind>` filters to one or more kinds (short ID
like `component` or the full `ComponentClaim` — both spellings work here and
for `clone`'s kind argument), `--ref <branch|tag|commit>` pins the claims repo
revision, `--ascii` swaps emoji icons for bracket tags, `--json` returns the
structured **`RelationGraph`** (`{"nodes": [...], "edges": [...]}` — schema:
`schema show RelationGraph`, `fs-forge-cookbook.md`) instead of the rendered
tree — use `--json` when the result feeds another step rather than the
client's eyes.

Each edge carries its `relation` (`owner`, `parent`, `system`, …), so a chain
question ("who owns X, all the way up") is answered by walking `edges` from
the target node until none remain — the whole graph is in this one payload.

## Render an arbitrary relation graph

Same tree renderer as above, but for a graph that has nothing to do with
claims — e.g. one assembled by hand, by another tool, or by merging
`discovery map --json` with catalog-only nodes it doesn't track (`Resource`
entities):

```bash
npx @firestartr/fs-forge-cli@{version} diagram print --file {graph.json}
cat {graph.json} | npx @firestartr/fs-forge-cli@{version} diagram print
```

Local and offline — no `--org`, no network. Input is the same `RelationGraph`
shape `discovery map --json` produces (above). Reach for this only when the
graph isn't claims data; `discovery map` is still the tool for an org's own
topology.
