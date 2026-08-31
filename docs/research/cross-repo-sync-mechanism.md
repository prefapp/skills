# Cross-repo sync mechanism: options for keeping a `features` package aligned with `prefapp/skills`

Research for [prefapp/skills#81](https://github.com/prefapp/skills/issues/81), part of the
[wayfinder map #80](https://github.com/prefapp/skills/issues/80).

## Gist

No repo in `~/work/prefapp/` already does *this exact direction*
(`prefapp/skills` → `prefapp/features`), but two structurally close precedents
exist and can be adapted:

1. **"Promote to docs" push pattern** (`features`, `tfm`, `tfm-org-settings`,
   `tfm-specs-to-context`, `gitops-k8s` all have `promote-docs.yaml` /
   `promote_docs.yaml`) — a release/push-triggered workflow that checks out
   *both* repos, copies files, and commits+pushes into the target repo using a
   scoped GitHub App token. This is a **content-mirroring, write-into-target**
   pattern, today used org-wide for repo → `firestartr-pro/docs`.
2. **"Matt-sync" notifier pattern** (`prefapp/skills` and
   `prefapp/skills-troubleshoot`, `.github/workflows/matt-sync.yml`) — a
   scheduled workflow that diffs an *upstream* source against a tracked
   last-checked SHA, classifies the diff with a small Python script, and
   opens/refreshes one GitHub issue for a **human** to act on; it deliberately
   does **no automatic write** to content. This is the precedent for the
   *opposite* direction of the risk named in issue #4 (pulling upstream
   changes in), and is reusable as a generic "detect drift, ask a human/agent
   to reconcile" primitive regardless of direction.
3. **Generic GitHub Actions primitives** not yet used for this purpose
   anywhere in the org: `repository_dispatch` (searched, zero hits across all
   `~/work/prefapp/*/.github/workflows`), and `gh workflow run` (used, but for
   triggering *deployment* dispatches, not content sync — see below).
4. **Git submodule/subtree**: no `.gitmodules` file and no `git subtree` usage
   found anywhere under `~/work/prefapp/`. Not a precedent at Prefapp.

No decision is made here — this is fact-finding only, per the ticket scope.

---

## 1. "Promote to docs" push pattern (closest structural precedent)

**What it is.** A workflow triggered on `release: published` (or
`workflow_dispatch`) that:
- checks out the source repo (e.g. `features`) into one path,
- mints a short-lived token via `actions/create-github-app-token@v2` scoped to
  a single target repo,
- checks out the target repo (`firestartr-pro/docs`) into another path using
  that token,
- copies specific files/dirs from source path into target path (plain `cp`,
  `find … -exec cp`, plus a small script step to regenerate an `index.json`),
- commits and pushes directly to the target repo's `main` as a GitHub App bot
  identity, no-op if nothing changed (`git diff --staged --quiet`).

**Where it's used today.** Identical shape (verified via `diff`, same file
byte-for-byte except renamed variables) in:
- `prefapp/features/.github/workflows/promote-docs.yaml` — publishes
  `packages/*/templates/docs/*.md`, `CHANGELOG.md`, images, and an
  `index.json` manifest into `firestartr-pro/docs`.
- `prefapp/features/.github/workflows/promote-schemas.yaml` — same shape,
  triggered per-feature release tag, publishes `packages/<feature>/schema.json`
  into a versioned path in `firestartr-pro/docs`.
- `prefapp/tfm/.github/workflows/promote-docs.yaml`,
  `prefapp/tfm-org-settings/.github/workflows/promote-docs.yaml`,
  `prefapp/tfm-specs-to-context/.github/workflows/promote-docs.yaml` — same
  template adapted per repo.
- `prefapp/gitops-k8s/.github/workflows/promote_docs.yaml` (and the same file
  duplicated across the `gitops-fsforge-*` sibling repos) — variant triggered
  on `push` to `main` with `paths: docs/public/**`, instead of on release.

**Direction fit for #80/#81.** All existing instances push *out* of the repo
that owns the content, into a docs-only, non-source-of-truth catalog repo
(`firestartr-pro/docs`) that nothing else reads back from. The proposed
direction (`prefapp/skills` → `prefapp/features`) is the same shape (owner
repo pushes a copy into a consumer repo) but the target here is a **live
package repo with its own release-please/CI**, not a docs dump — so directly
reusing the workflow requires deciding how the mirrored content interacts with
`features`' own release-please versioning and PR review, which none of the
existing instances have had to solve (their target repo has no independent
release process for the copied content).

**Rough effort.** Low — the workflow shape, GitHub App token pattern, and
no-op-on-no-diff commit logic are already proven and copy-pasteable. The
GitHub App (`FIRESTARTER_DOCS_APP_ID` / `FIRESTARTR_DOCS_APP_PEM_FILE`) is
currently scoped to `firestartr-pro/docs` only; mirroring into
`prefapp/features` needs either a new App (or an existing one) re-scoped to
grant write access there, plus deciding whether the push commits directly to
`main` (as today) or opens a PR (since `features` has real reviewers/CI unlike
a docs-catalog repo).

## 2. "Matt-sync" notifier pattern (closest precedent for the *pull* / drift-detection half)

**What it is.** A scheduled GitHub Actions workflow (`matt-sync.yml`, cron
Mon/Wed/Fri) that:
- reads a tracked **last-checked SHA** file (`.github/matt-sync/last-checked-sha`),
- clones the upstream source repo fresh each run (`git clone`, read-only),
- diffs `last_sha..HEAD` and classifies each changed path with a deterministic
  Python script (`scope_changes.py`) into edit-candidate / suggest-import /
  ignored buckets,
- if anything is actionable, opens or refreshes **one** GitHub issue (found by
  a fixed label, `matt-sync`) with a markdown change report; auto-closes that
  issue when nothing is pending,
- makes **no code edits and no automatic sync** — a human (or agent) is
  expected to run a companion skill (`.github/skills/matt-sync/`) by hand,
  which does the actual content reconciliation and advances the SHA file in
  the same change.
- rationale is written up in `docs/adr/0008-track-upstream-matt-skills.md`:
  an earlier design ran an unattended agent inside the Action and was
  rejected as too much operational risk/upkeep for edits a human had to review
  anyway; demoting the Action to a notifier needed only `issues: write`
  permission, no `contents: write`.

**Where it's used today.** `prefapp/skills/.github/workflows/matt-sync.yml`
and `prefapp/skills-troubleshoot/.github/workflows/matt-sync.yml` — both
tracking upstream `github.com/mattpocock/skills` into their own local
`skills/` directory, i.e. **pulling** an external upstream in, not pushing a
local copy out.

**Direction fit for #80/#81.** This is the mirror-image direction of what
issue #4 flagged (content flowing *into* `prefapp/skills` from
`firestartr-ia`) rather than the current problem (content flowing *out of*
`prefapp/skills` into `prefapp/features`) — but the mechanism (scheduled diff
+ classify + single refreshed issue + human/agent-driven reconciliation, no
autonomous write) is direction-agnostic. It could be pointed the other way:
`prefapp/features` (or a bot with read access to both) diffs
`firestartr/firestartr-operation/` in `prefapp/skills` since a tracked SHA and
opens an issue in `features` (or `skills`) when it drifts, leaving a human/
agent to actually copy the change over — same "notify, don't auto-write"
posture as pattern 1 rejects but pattern 2 embraces.

**Rough effort.** Medium — the scheduled-diff + classify + single-issue
plumbing is proven and reusable almost as-is (workflow, SHA-file convention,
classifier script shape). The Prefapp-specific part is the classifier
(`scope_changes.py`'s category/rename mapping) and the companion skill, both
of which would need a new mapping for `firestartr-operation` → `features`
package layout rather than upstream-skills → fork-skills.

## 3. Generic GitHub Actions primitives (available, unused for this purpose)

- **`repository_dispatch` / `workflow_dispatch` cross-repo trigger.** Searched
  every `.github/workflows/*.yaml` under `~/work/prefapp/*` for
  `repository_dispatch`: zero matches anywhere in the org. Not a precedent,
  but a standard GitHub Actions primitive (a source repo fires an event/token
  call that triggers a workflow in the target repo) that nothing here already
  wires up for content sync.
- **`gh workflow run` cross-repo dispatch** *is* used, but for a different
  purpose: `prefapp/gitops-k8s/.github/workflows/trigger_dispatch_on_releases.yaml`
  fires `gh workflow run make_dispatches.yaml -R <repo>` after a successful
  Docker release build, which in turn calls the `prefapp/action-make-state-repos-dispatches`
  action to open dispatch PRs against **state repos** (GitOps claim
  reconciliation), not to mirror file content between source repos. Same
  "one repo tells another repo's Actions to do something" primitive, applied
  to deployment orchestration rather than content mirroring — relevant as a
  proof the primitive works reliably at Prefapp, not as a direct precedent
  for this ticket.
- **Scheduled workflow diffing a remote git clone** — this is exactly what
  `matt-sync.yml` already does (see pattern 2); it is the only concrete
  instance of this primitive in the org, and it targets an external
  (non-Prefapp) upstream, not another Prefapp repo.

## 4. Git submodule / subtree

Checked every repo under `~/work/prefapp/` for `.gitmodules` (none exist) and
grepped `.github` and `scripts` directories for `git subtree` invocations
(none found). Git submodules/subtree are not used anywhere in the org today
for repo-to-repo content sharing — this would be a net-new mechanism with no
internal precedent to draw on, unlike patterns 1 and 2.

---

## Sources consulted

- `~/work/prefapp/features/.github/workflows/promote-docs.yaml`,
  `promote-schemas.yaml`
- `~/work/prefapp/tfm/.github/workflows/promote-docs.yaml` (diffed against
  `features`' version)
- `~/work/prefapp/tfm-org-settings/`, `~/work/prefapp/tfm-specs-to-context/`
  — same `promote-docs.yaml` workflow present
- `~/work/prefapp/gitops-k8s/.github/workflows/promote_docs.yaml`,
  `trigger_dispatch_on_releases.yaml`, `make_dispatches.yaml`
- `~/work/prefapp/skills/.github/workflows/matt-sync.yml`,
  `~/work/prefapp/skills/.github/matt-sync/scope_changes.py`,
  `~/work/prefapp/skills/.github/matt-sync/README.md`,
  `~/work/prefapp/skills/.github/skills/matt-sync/SKILL.md`,
  `~/work/prefapp/skills/docs/adr/0008-track-upstream-matt-skills.md`
  (same file duplicated in `~/work/prefapp/skills-troubleshoot/`)
- Full listing of `.github/workflows/` across every repo under
  `~/work/prefapp/*/` (18 repos checked)
- `grep -r repository_dispatch`, `grep -r "git subtree"`, and a
  `.gitmodules` search across all of `~/work/prefapp/*`: no matches
- `gh issue view 4` and `gh issue view 81` in `prefapp/skills`, for the
  originating risk framing and the exact ticket wording
