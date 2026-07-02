# Track Matt Pocock's upstream and auto-PR proposed skill edits

Our workflow set was generalized from `github.com/mattpocock/skills` (Upstream).
To keep our skills sharp as he evolves his, a scheduled GitHub Actions **Sync
run** (Mon/Wed/Fri) diffs Upstream since a tracked **last-checked SHA**, runs
`pi` headless driven by a repo-specific `matt-sync` skill, and opens/refreshes a
single **Sync PR** proposing concrete edits to *our existing* skills (net-new
Upstream skills are only *suggested* for import in the PR body, never added).

## Considered Options

- **Who does the work.** Chose `pi` headless + a committed skill over GitHub's
  Copilot coding agent (Route A): Copilot doesn't save the hard part (staging
  Upstream's diff), gives weaker control over our mapping/scoping rules, and
  carries a subscription-for-unattended-use ToS smell. `gh copilot` can't edit
  files, so it was never viable.
- **Auth.** Chose **GitHub Models via the built-in `GITHUB_TOKEN`**
  (`permissions: models: read`) over a paid API key, to avoid provisioning a
  secret; OpenCode Zen/Go (`OPENCODE_API_KEY`) is the documented fallback if
  GitHub Models' rate limits bite.
- **Change detection.** Chose a **tracked SHA file, advanced only inside the
  Sync PR**, over a time-window ("commits in last 48h"): the SHA approach is
  exactly-once and survives missed/failed runs; the time-window silently drops
  or double-counts changes.
- **Skill mapping.** Chose **agent semantic judgment** over a hand-maintained
  mapping table: our set is a near-1:1 generalized fork of Upstream's
  `engineering/` + `productivity/`, so names mostly match and the agent resolves
  the two renames (`review`↔`code-review`, `setup-workflow`↔
  `setup-matt-pocock-skills`) by content. A table would be pure upkeep.
- **Policy.** Edit-existing-only; net-new skills are suggestion-only (no files
  added); irrelevant changes ignored. Scope excludes Upstream's `in-progress/`,
  `deprecated/`, and `.out-of-scope/`; `misc/` and `personal/` are
  suggestion-only.

## Consequences

The `matt-sync` skill lives at `.github/skills/matt-sync/`, *outside* the
installed `skills/` set, so `install.sh` never distributes this repo-specific
automation to developers' harnesses. Exactly one Sync PR is open at a time on a
fixed `matt-sync` branch, refreshed in place; the agent reads the open PR and
extends prior suggestions rather than clobbering. Runs fail loud and change
nothing on error (built-in scheduled-workflow email; no auto-fallback wired
yet). Seeded at Upstream `42396a5`, so the first run reacts to future changes
only, not the back-catalog.
