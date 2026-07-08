# Track Matt Pocock's upstream: Action notifies, a human runs a generic sync skill

Our workflow set was generalized from `github.com/mattpocock/skills` (Upstream).
To keep our skills sharp as he evolves his, we split the job in two:

- A scheduled GitHub Actions **Sync run** (Mon/Wed/Fri) diffs Upstream since a
  tracked **last-checked SHA**, classifies the changes with a deterministic
  script, and **opens/refreshes a single GitHub issue** describing what changed.
  It runs **no agent** and edits nothing.
- A developer, when ready, runs the **`matt-sync` skill** by hand to turn those
  changes into concrete edits to a fork's skills, and advances the fork's
  last-checked SHA in that same change.

## Considered Options

- **Who does the work.** Chose **a human running a skill** over an unattended
  agent inside the Action (the earlier headless-`pi`-via-GitHub-Models design).
  The unattended agent carried the most operational risk and upkeep — model
  auth, a paid-key fallback, PR-bot wiring — for edits a human had to review
  anyway. Demoting the Action to a **notifier** deletes all of that; the human
  is already in the loop, so the skill runs in their own session.
- **Skill genericity.** The skill is **portable**: it takes an *upstream
  location* and a *target skill set* as inputs, so it can update **any**
  Matt-derived fork, not just ours — different forks customize differently. It
  maps upstream→target **by semantic content, per pair**, not a hardcoded rename
  table. It stays at `.github/skills/matt-sync/` (not distributed by
  `install.sh`); promote it into the installed set only if a team asks to
  install it (YAGNI).
- **Change detection & SHA lifecycle.** Chose a **tracked SHA file, advanced
  only by the human's edit change (via the skill)**, over the Action advancing
  it. The SHA means *last actually incorporated*: a failed run or an ignored
  issue changes nothing and self-heals — the next run re-diffs the same window
  and re-shows the pending backlog. The Action is therefore **write-free against
  the repo** (`issues: write` only; no `contents: write`, no `models: read`).
  The skill's SHA bump is **conditional** — it advances a fork's SHA file if the
  fork tracks one, else it's a no-op.
- **Issue lifecycle.** **One issue, refreshed in place**, found by a `matt-sync`
  label — the heir of the old "one Sync PR, refreshed in place" invariant. It is
  auto-closed when the pending diff empties (SHA caught up to Upstream HEAD).
  New-issue-per-run was rejected as tracker noise (up to 3/week of a duplicated,
  growing diff).
- **Worklist source (in this repo).** The skill reads the labelled issue via
  `gh` **primary**, and falls back to re-running the classifier / diff itself
  when no issue is found — which is also the generic path for a stranger's fork.
- **Classifier.** Kept `scope_changes.py` (deterministic upstream→ours mapping +
  in-progress/deprecated/misc scoping, with its this-repo rename table). Its
  markdown output is now the **issue body** instead of a PR body. The rename
  table stays *with the Action* and does **not** move into the generic skill.
- **Policy.** Edit-existing-only; net-new skills are suggestion-only (no files
  added). Scope excludes Upstream's `in-progress/`, `deprecated/`, and
  `.out-of-scope/`; `misc/` and `personal/` are suggestion-only.

## Consequences

The Action is a thin notifier: diff → classify → open/refresh one labelled
issue. No model auth, no `models.json`, no PR bot, no OpenCode fallback. The
`matt-sync` skill lives at `.github/skills/matt-sync/` — *outside* the installed
`skills/` set — but is written generically so anyone can point it at their own
upstream + target. Exactly one Sync issue is open at a time, refreshed in place
and auto-closed when the fork catches up. Runs fail loud and change nothing on
error. Seeded at Upstream `42396a5`, so the first run reacts to future changes
only, not the back-catalog.
