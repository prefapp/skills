# Keeping vendored claim schemas in sync via drift-detection, not auto-sync

The reference schemas under
`firestartr/firestartr-operation/reference/schemas/*.json` are **vendored,
LLM-enriched derivatives** of the upstream claim schemas in
`prefapp/gitops-k8s` (`packages/cdk8s_renderer/src/claims/base/schemas/`). They
add agent-facing `description`s, `default`s, `enum`s, and human-readable patterns
that the upstream machine schemas don't carry (ADR-0006's portability rule
deliberately copies them in for self-containment). Because the copies are
enriched, no automated copy can regenerate them losslessly — the enrichment
needs a human/LLM. So they drift when upstream changes and there was no signal
that they had.

## Decision

Detect drift and **notify**; never auto-sync content.

- **Event-driven detector in `gitops-k8s`.** A workflow triggers on
  `push: branches:[main]` filtered to
  `paths: ['packages/cdk8s_renderer/src/claims/base/schemas/**']`, so it fires
  exactly when a schema file actually changes — not on every release, and
  including edits that land between releases.
- **Artifact is an issue, not a PR.** A PR can't carry the real change (the
  enriched copies must be re-authored by a human/LLM); a PR that only bumped a
  pin would falsely claim "updated." The workflow opens an issue in
  `prefapp/skills` with the commit/diff link and a refresh checklist.
- **Deduped by label.** The step checks for an open issue labelled
  `schema-drift`; if one exists it comments the new commit, else it creates one.
  Consecutive upstream changes pile into a single living issue; the refresh PR
  closes it (`Closes #…`), resetting the cycle.
- **Auth via the existing GitHub App pattern.** Mint a token with
  `actions/create-github-app-token@v2` scoped to `prefapp/skills`
  (`issues: write`) — the same idiom already used by
  `promote_claims_schema.yaml` — so there is no human-owned PAT to rotate.

## Considered Options

- **Pin the published npm package version** (`@prefapp/firestartr-claims_schemas`)
  and compare. Rejected: that version tracks the whole gitops-k8s *release*, so
  it bumps when no schema changed (false positive) and misses schema edits that
  land between releases (false negative).
- **Scheduled workflow in `prefapp/skills`.** Rejected: adds weekly polling
  noise, needs read access to a private repo plus a pinned-SHA state file that
  can itself drift; the event-driven trigger needs neither.
- **Auto-sync / auto-PR the schema content.** Impossible without discarding the
  agent-facing enrichment that makes the reference valuable.

## Consequences

Adds one small workflow file to `gitops-k8s` (a repo owned by a different
concern) and requires the GitHub App to be installed on `prefapp/skills` with
`issues: write`. In exchange, schema drift surfaces automatically as a single,
actionable issue; refreshing the vendored copies stays a human step.
