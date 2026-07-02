# matt-sync internals

Support files for the scheduled **Sync run** (`.github/workflows/matt-sync.yml`).
See `docs/adr/0006-track-upstream-matt-skills.md` and issue #1 for the design.

| File | Role |
|------|------|
| `last-checked-sha` | The Upstream commit the last Sync PR processed. Advanced only inside the Sync PR. Seeded `42396a5`. |
| `scope_changes.py` | Deterministic classifier: raw Upstream diff → change report (edit-candidate / suggest-import / ignored). The one tested seam. |
| `test_scope_changes.py` | Self-checking test for the classifier. Run: `python3 .github/matt-sync/test_scope_changes.py`. |
| `models.json` | Registers **GitHub Models** as a pi provider (OpenAI-compatible). |

The agent skill lives at `.github/skills/matt-sync/` — deliberately **outside**
`skills/` so `install.sh` never distributes it to developers' harnesses.

## Auth

The agent runs `pi` headless against **GitHub Models** using the workflow's
built-in `GITHUB_TOKEN` — no paid key, no secret to provision. The workflow
grants `permissions: models: read`; `models.json` resolves the key from
`$GITHUB_TOKEN` and sends it as a Bearer token.

## Manual fallback: OpenCode Zen/Go

If GitHub Models' rate limits block the run, fall back **manually** (there is no
auto-fallback wired, by design — issue #1 "Out of Scope"):

1. Add an `OPENCODE_API_KEY` repo secret (OpenCode Zen or Go key).
2. In `models.json`, add an OpenCode provider (OpenAI-compatible), e.g.
   `baseUrl: https://opencode.ai/zen/v1`, `apiKey: "$OPENCODE_API_KEY"`,
   `api: openai-completions`.
3. Point the workflow's `--provider`/`--model` at it and pass the secret as env.

Revert once GitHub Models is usable again.
