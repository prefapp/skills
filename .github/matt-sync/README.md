# matt-sync internals

Support files for the scheduled **Sync run** (`.github/workflows/matt-sync.yml`).
The Sync run is a pure **notifier**: it diffs Upstream, classifies the changes,
and opens/refreshes one labelled **Sync issue**. No agent runs in the workflow.
See `docs/adr/0008-track-upstream-matt-skills.md` and issue #1 for the design.

| File | Role |
|------|------|
| `last-checked-sha` | The Upstream commit the fork has actually incorporated. Advanced **only by a human** via the `matt-sync` skill, never by the Action. Seeded `42396a5`. |
| `scope_changes.py` | Deterministic classifier: raw Upstream diff → change report (edit-candidate / suggest-import / ignored). Its markdown is the Sync issue body. The one tested seam. |
| `test_scope_changes.py` | Self-checking test for the classifier. Run: `python3 .github/matt-sync/test_scope_changes.py`. |

The agent skill lives at `.github/skills/matt-sync/` — deliberately **outside**
`skills/` so `install.sh` never distributes it to developers' harnesses. It is
run **by hand** by a developer who acts on the Sync issue.

## No auth needed

The Action only reads Upstream (public) and writes issues with the built-in
`GITHUB_TOKEN` (`permissions: issues: write`). No model provider, no paid key,
no secret to provision.
