# Distribute firestartr-operation as a features-package mirror via a Promote run

External client developers can't install `firestartr-operation` from the
private `prefapp/skills` repo, and a hand-copied public location would drift.
The distribution vehicle is a versioned Firestartr Feature package,
`firestartr_operation`, in `prefapp/features` — the same public catalog every
official Feature ships through. The source of truth stays here:
`firestartr/firestartr-operation/` remains the only place the content is
edited; the package is a mechanical mirror.

## Considered Options

- **Sync mechanism.** Chose a push-triggered **Promote run** over (a) editing
  the package by hand — drift — and (b) the matt-sync notifier pattern. The
  direction is the reverse of matt-sync (we push content out of the source of
  truth into a consumer), and a full mechanical mirror has nothing per-file
  for a human to judge, so a notifier would add a manual step with no
  decision behind it.
- **Delivery shape.** Chose **one Promotion PR per run** over pushing
  directly to `prefapp/features`' `main`: that repo has real CI and
  reviewers, and an unattended write into the public catalog is exactly the
  risk to avoid. The PR is `fix:`-titled by default so release-please
  releases it as a patch; a reviewer bumps it to `feat:` when the content
  warrants a minor.
- **Gating.** The run hard-fails — no PR — when the guard finds an unrendered
  Mustache collision (`{{|`/`|}}`) or a reference resolving outside the
  package, so the mirror can never ship content the features renderer would
  misfire on or that links back into `prefapp/skills`.
- **Token.** The run mints a `prefapp/features`-scoped token from the
  existing `FS_STATE_APP_ID` GitHub App at mint time; no new App.

## Consequences

Every change to `firestartr/firestartr-operation/` on `main` produces a
reviewable Promotion PR in `prefapp/features`, gated by that repo's CI and a
human's approval. A no-diff run is a no-op. The workflow reads the
org-shared `FS_STATE_APP_ID` variable and `FS_STATE_PEM_FILE` secret (the
same credentials `prefapp/features`' release-please uses) — no per-repo
credential setup.
