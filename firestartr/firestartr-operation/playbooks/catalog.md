# Catalog Playbook

Answer ownership, topology, and discovery questions — "who owns service X", "what's
in system Y", "what services do we have". **Read-only.** The catalog
(`{org}/catalog`) is a Backstage-style view hydrated from claims; never edit it, and
if the client wants a change, route to `edit-claim`/`create-claim` + `lifecycle`
(the catalog updates on the next hydration). Bash idioms: `../reference/gh-cookbook.md`.

## Entities

Hydrated from claims: `Domain` ← DomainClaim, `System` ← SystemClaim, `Component` ←
ComponentClaim, `Group` ← GroupClaim, `User` ← UserClaim, `Resource` ← infra.

## Common questions

- **What services do we have?** List `Component` entities → name, type, lifecycle,
  owner, system as a table.
- **Who owns service X? What's in system Y? Show the org structure.** Prefer
  `fs-forge discovery map` (`../reference/fs-forge-cookbook.md`) over walking
  catalog entities by hand — it renders the ownership/grouping tree
  (`owner`, `maintainedBy`, `platformOwner`, `system`, `domain`, `members`, …)
  straight from the claims repo in one call, always current. Filter with
  `--kind` (e.g. `--kind system --kind component`) to scope to one
  system's topology or one owner's chain. Fall back to the catalog entities
  below only for relations `discovery map` doesn't track (e.g. hydrated
  `Resource` entities) or when a rendered ownership tree isn't what's asked.
- **Search.** Match names/fields across entities and present hits with their owners.

## Raw inventory, no relations

For a flat "what claims exist" listing (not entity ownership/topology), or when
the catalog is stale, `fs-forge discovery org-elements` reads the claims-map
directly — faster and always current. See `../reference/fs-forge-cookbook.md`.
Use the catalog entities above whenever the question involves relations
`discovery map` doesn't cover, such as hydrated infra `Resource`s.

## Freshness

The catalog hydrates every ~6h, so it can lag recent claim changes. When the latest
claim commit is newer than the catalog's, say so and offer to trigger hydration —
don't present stale data as authoritative. (Details: `reconciliation` playbook.)
