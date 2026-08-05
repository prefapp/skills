# fs-forge-cli feedback

Notes gathered while shrinking `firestartr-operation`'s fs-forge cookbook
(2026-08). Not read by the agent — for a human to hand to the fs-forge-cli
maintainers. Verified against `@firestartr/fs-forge-cli@0.6.0`.

## The FlagSpec shape isn't self-documented

`--help --json` returns FlagSpec objects, but nothing in the CLI documents
their shape — the skill had to hand-maintain a field table, and it had
drifted (documented `enumValues`/`defaultValue`; the CLI actually returns
`options`, plus undocumented `description`/`env`/`allowNo`/
`conditionalRequired`/`dependsOn`). Consider publishing the FlagSpec shape
(a JSON Schema, or a `fs-forge help flagspec` meta-command) so downstream
tooling doesn't have to reverse-engineer and re-document it from a live call.

## Flag `description` coverage is thin and sometimes worse than nothing

On `create component --help --json`, only 28 of 66 flags carry any
`description`. Several of the generated ones actively mislead rather than
just omit: `providers.github.org` describes itself as
`"providers.github.org (required when its parent is supplied)"` — it doesn't
say this is the claim's *own* org field, distinct from the top-level
`--org` (`"[env: FSCRT_ORG] GitHub organization containing the claims repo"`).
Two org-shaped flags with no distinguishing text is a real footgun; a
one-line description on the schema-org-shaped field ("which GitHub org this
resource belongs to, as opposed to --org's claims-repo org") would let
callers get this right from `--help` alone instead of tribal knowledge.

## No flag signals "this replaces the whole array"

Every `multiple: true` flag (e.g. `--maintainedBy`, `--topics`) silently
replaces the full array on each invocation rather than appending — checked
across all of `create component`'s array flags, none mention it. Worth a
generic suffix on every such flag's description ("repeat to set the full
list; this replaces any existing value, it does not append").

## `--commit`'s full effect isn't in `--help`

`--commit`'s description is `"Commit the claim and dispatch provisioning"` —
accurate but doesn't convey that it also opens the PR, waits for verification,
merges it, dispatches and waits for hydration, and merges the resulting
second PR, unattended. Given how consequential this flag is, it may be worth
the extra lines in its `--help` text, not just in downstream docs.

## `kinds` and per-kind `create` descriptions are boilerplate

`fs-forge kinds` prints `"A Component claim"` for every kind — same template,
no distinguishing information. `create --help`'s per-kind summaries
("Create a ArgoDeployClaim") repeat the kind name with no grammar fix ("a
Argo…") and no indication of what the kind is *for*. A one-line, hand-written
purpose per kind (oclif's `summary` vs. `description` split, if not already
used this way) would remove the skill's own hardcoded kind↔intent table as a
duplicate source of truth over time.

## Response shapes for `--json` outputs aren't documented anywhere

`discovery map --json`, `--diff --json`, `--diff --show-defaults --json`, and
`diagram print`'s input all have distinct, non-obvious JSON shapes (e.g.
`--diff --json` alone is `{"nodes"/"edges"}`, but adding `--show-defaults`
changes it to `{"changes"/"defaults"}`). None of this is in `--help`; it can
only be learned by reading source or by trial and error. Worth documenting
per-command output shapes the same way input flags are documented.
