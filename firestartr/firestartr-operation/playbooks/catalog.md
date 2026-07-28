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
- **Who owns service X?** Find the `Component`, read its `owner` (a group), find that
  `Group`, list its members — return the full ownership chain.
- **What's in system Y?** Find the `System`, then every `Component` referencing it —
  present the system's topology.
- **Show the org structure.** Domain → System → Component, hierarchically.
- **Search.** Match names/fields across entities and present hits with their owners.

## Raw inventory, no relations

For a flat "what claims exist" listing (not entity ownership/topology), or when
the catalog is stale, `fs-forge discovery org-elements` reads the claims-map
directly — faster and always current. See `../reference/fs-forge-cookbook.md`.
Use the catalog entities above whenever the question involves ownership,
system membership, or hierarchy.

## Freshness

The catalog hydrates every ~6h, so it can lag recent claim changes. When the latest
claim commit is newer than the catalog's, say so and offer to trigger hydration —
don't present stale data as authoritative. (Details: `reconciliation` playbook.)
