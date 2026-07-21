# Two skill categories: workflow set and opt-in operational set

The repo shipped one category — the generalized **workflow set** (`skills/`,
namespace `prefapp-workflow`) that applies to any repo. Prefapp also needs
**operational** skills that drive the Firestartr platform (create/edit/delete
repos·teams·users, inspect drift/ownership) for a *client developer* who should
not learn claim internals. That audience and charter differ from the workflow
set.

## Decision

Add a second, **opt-in operational skill set** in its own top-level directory
`firestartr/` (namespace `prefapp-firestartr`), separate from the untouched
workflow set.

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
- **Opt-in install.** `install.sh --fs` (or `--all`) creates the
  `prefapp-firestartr` symlink; the default install is unchanged (workflow set
  only). Symlink-only, idempotent.
- **Operator/platform kit deferred.** Operator upgrades, image provenance,
  snapshot builds, CLI pinning, and OPA policy authoring target Prefapp
  *operators*, not clients. They stay out of the client entry and are ported on
  demonstrated need (YAGNI).

## Consequences

The workflow charter stays untouched. Clients get one command; Prefapp developers
maintain single-sourced playbooks. No client-specific data can be committed (it's
git-ignored). The install default is unaffected, so developers who don't opt in
never see the operational group. Conformance of the skill markdown to
`writing-great-skills` is checked via the `review` skill, not unit tests; the one
automated check covers the `install.sh` opt-in seam (`tests/test_install.sh`).
