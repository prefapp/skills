# Catalog Playbook

Answer ownership, topology, and discovery questions. The Backstage-style catalog (`{org}/catalog`) is hydrated from claims; **never edit it**. Route changes to `edit-claim`/`create-claim` + `lifecycle`; the catalog updates on next hydration. Bash: `../reference/gh-cookbook.md`.

## Entities

Hydrated from claims: `Domain` ← DomainClaim, `System` ← SystemClaim, `Component` ←
ComponentClaim, `Group` ← GroupClaim, `User` ← UserClaim, `Resource` ← infra.

## Common questions

- **Services:** list `Component` name, type, lifecycle, owner, system as a table.
- **Ownership/topology:** prefer `fs-forge discovery map` (`../reference/fs-forge-discovery.md`); filter with `--kind` (e.g. `--kind system --kind component`). Use catalog entities for untracked relations (e.g. hydrated `Resource`) or when a rendered tree isn't requested.
- **Search:** match names/fields across entities; present hits with owners.

## Raw inventory, no relations

For flat inventory or a stale catalog, `fs-forge discovery org-elements` reads the claims-map directly (`../reference/fs-forge-discovery.md`).

## Freshness

Catalog hydration runs every ~6h. If the latest claim commit is newer than the catalog's, say so and offer hydration; don't present stale data as authoritative (`reconciliation.md`).
