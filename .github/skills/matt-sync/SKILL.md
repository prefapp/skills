---
name: matt-sync
description: Sync run agent. Turn a change report of Upstream (Matt Pocock) skill changes into concrete edits to our existing skills, plus import suggestions for net-new skills. Use only inside this repo's scheduled Matt-sync GitHub Action.
---

> **Before acting:** read this repo's root `AGENTS.md` / `CLAUDE.md` and `CONTEXT.md` and obey them — repo rules override this skill.

# Matt-sync agent

You are the agent half of this repo's **Sync run** (see `CONTEXT.md` → "Sync
run", "Sync PR"). A deterministic step has already classified the Upstream diff.
Your job: turn its **edit-candidates** into real edits to *our existing* skills,
and list its **suggest-imports** in the rationale.

## Inputs (already prepared for you)

- **Change report:** `/tmp/report.md` — edit-candidates (`upstream/path → our
  skill`) and suggested imports.
- **Upstream clone:** `/tmp/upstream` — Matt's repo, freshly cloned at its
  current HEAD (the Sync run `rm -rf`s any leftover before cloning, so it is
  never stale). Read only; never edit.
- **Our skills:** `skills/<name>/` in the working directory. These are what you
  edit.

## What to do

1. Read `/tmp/report.md`.
2. For each **edit-candidate** `engineering|productivity/<upstream> → our <ours>`:
   - Read the Upstream skill (`/tmp/upstream/skills/<category>/<upstream>/`) and
     our mapped skill (`skills/<ours>/`).
   - Map by **semantic content, not filename** — our set is a generalized fork,
     so wording differs (the report already resolves the upstream→ours path).
   - Identify what genuinely changed Upstream that would **improve ours**: a
     sharper instruction, a new step, a fixed mistake, a better example.
   - Apply it as concrete edits to **our** skill file(s). Preserve our
     generalizations: harness-agnostic wording, the governance banner, our
     `CONTEXT.md` vocabulary. Drop Matt-specific details (his repo names, his
     personal setup, tool-specific asides that don't apply here).
   - If nothing in the Upstream change actually improves ours, make **no edit**
     to that skill and say why in the rationale.
3. For each **suggest-import**: note it in the rationale as a candidate for a
   human to import deliberately.

## Hard rules

- **Edit existing skills only.** Never create a new `skills/<name>/` directory.
- **Never edit `/tmp/upstream`** or anything outside `skills/`.
- Do not touch `.github/matt-sync/last-checked-sha` — the workflow already
  advanced it.
- Prefer the smallest edit that lands the improvement. No rewrites for style.

## Output: the rationale

Write `/tmp/rationale.md` — this becomes the Sync PR body's rationale. Include:

- **Edits made:** per edited skill, what changed and *why* (which Upstream
  improvement it carries).
- **Considered but skipped:** edit-candidates you left unchanged, with the
  reason (Matt-specific, already covered, not an improvement).
- **Suggested imports:** the net-new Upstream skills worth a human's look, one
  line each — explicitly *not added as files*.

If you made no edits at all, say so plainly and explain why in the rationale.
