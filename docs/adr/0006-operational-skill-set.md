# Two skill categories: workflow set and opt-in operational set

The repo ships two skill categories under one `skills/` root — the generalized
**workflow set** (`skills/workflow/`, namespace `prefapp-workflow`) that applies
to any repo, and an **operational set** (`skills/firestartr/`, namespace
`prefapp-firestartr`) that drives the Firestartr platform (create/edit/delete
repos·teams·users, inspect drift/ownership) for a *client developer* who should
not learn claim internals. That audience and charter differ from the workflow
set.

## Decision

Add a second, **opt-in operational skill set** in `skills/firestartr/`
(namespace `prefapp-firestartr`), isolated from the workflow set at
`skills/workflow/` — both nested under the shared `skills/` root so the whole
repo is a single tree of independent, installable skill directories, but each
group stays isolated from the other.

- **Single client entry.** One skill, `firestartr-operation`, is the only
  described surface in the group. It resolves the org, classifies the intent,
  loads the matching **playbook(s)**, and executes. The client uses only
  `/firestartr-operation <plain request>` and never hears the word "claim."
- **Playbooks, not sub-skills.** `lifecycle`, `create-claim`, `edit-claim`,
  `reference`, `reconciliation`, `catalog` are disclosed `.md` files under the
  entry skill — no independent descriptions, so the group costs one description's
  worth of context load, not a dozen. Dispatch lives in the entry skill (no
  `routing.yaml`).
- **Portable platform data, runtime identity.** Stable facts (claim schemas,
  defaults, feature catalog, claim→state mapping) are carried inside the skill.
  The only non-portable datum — org name + claims repo — is a git-ignored runtime
  `organization.yaml` (with a committed `organization.example.yaml`), written on
  first run.
- **Governance.** Every change is PR-only, never committed to main — stated once
  in `lifecycle`.
- **Opt-in install.** `install.sh --fs` (or `--all`) shells out to
  `npx skills add prefapp/skills --skill firestartr-operation`; the default
  install is unchanged (workflow set only). Versioned independently via
  release-please (`firestartr-operation-vX.Y.Z` tags). `--skill` always
  installs `main` HEAD — to pin a release, install from that tag's tree
  directly (`.../tree/firestartr-operation-vX.Y.Z/...`) instead. The
  `release_please` Feature (attached via the `prefapp/claims` ComponentClaim,
  prefapp/claims#72) also supports a rolling `firestartr-operation-vN` major
  tag via its `release_please_generate_rolling_tag`/
  `release_please_rolling_tag_name_pattern` args — needs enabling on that
  claim to be usable as a pin target.
- **Operator/platform kit deferred.** Operator upgrades, image provenance,
  snapshot builds, CLI pinning, and OPA policy authoring target Prefapp
  *operators*, not clients. They stay out of the client entry and are ported on
  demonstrated need (YAGNI).

## Consequences

The workflow charter stays untouched. Clients get one command; Prefapp developers
maintain single-sourced playbooks. No client-specific data can be committed (it's
git-ignored). The install default is unaffected, so developers who don't opt in
never see the operational group. Conformance of the skill markdown to
`writing-for-agents` is checked via the `review` skill, not unit tests; the one
automated check covers the `install.sh` opt-in seam (`tests/test_install.sh`).
