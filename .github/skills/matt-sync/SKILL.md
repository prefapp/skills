---
name: matt-sync
description: Carry upstream (Matt Pocock) skill improvements into a fork's skills. A human runs this to turn a diff of Matt's skills into concrete edits to an existing, differently-customized fork — this repo's, or anyone's. Portable across forks; edits existing skills only.
---

> **Before acting:** read the target repo's root `AGENTS.md` / `CLAUDE.md` and
> `CONTEXT.md` and obey them — repo rules override this skill.

# Matt-sync

You carry improvements from **Upstream** (Matt Pocock's skills,
`github.com/mattpocock/skills`) into a **fork** whose skills were generalized
from his but customized differently. You run **by hand**, not inside any
workflow. You edit *existing* skills only.

## Step 1 — Confirm your two locations (ask if not given)

1. **Upstream location.** Where is Matt's skills clone? If none exists, offer to
   `git clone https://github.com/mattpocock/skills.git` into a temp dir. Read
   only — never edit it.
2. **Target skill set.** Which skills am I updating? Default: this repo's
   `skills/`. Accept any other fork's skills directory.

## Step 2 — Get the worklist

- **If a Sync issue exists (this repo):** read it — `gh issue list --state open
  --label matt-sync` then `gh issue view <n>`. Its classified report already maps
  upstream changes to our skills (edit-candidates) and lists suggested imports.
  That is your worklist.
- **Otherwise (another fork, or no issue):** diff Upstream yourself since the
  fork's last-checked point (`git -C <upstream> diff --name-only <sha>..HEAD`,
  scoped to `skills/`), and scope it. In *this* repo you may reuse
  `.github/matt-sync/scope_changes.py` to classify. For an arbitrary fork, scan
  the changed upstream skills and match them to target skills yourself.

## Step 3 — For each edit-candidate `<upstream skill> → <target skill>`

- Read the Upstream skill and the mapped target skill.
- **Map by semantic content, not filename** — a fork renames and rewords things,
  so match by what each skill *does*, per pair. A target skill with no upstream
  counterpart is left alone; upstream with no target match becomes a
  suggest-import note.
- Identify what genuinely changed Upstream that would **improve the target**: a
  sharper instruction, a new step, a fixed mistake, a better example.
- Apply it as concrete edits to the **target** skill file(s). Preserve the fork's
  customizations: its wording, its governance banner, its `CONTEXT.md`
  vocabulary. Drop Matt-specific details (his repo names, personal setup,
  tool-specific asides that don't apply).
- If nothing in the Upstream change improves the target, make **no edit** and say
  why in the rationale.

## Step 4 — Advance the fork's last-checked SHA (conditional)

If the fork tracks a last-checked SHA, advance it to Upstream HEAD **in this same
change**. In this repo that's `.github/matt-sync/last-checked-sha`. If the fork
tracks upstream some other way, or not at all, this is a no-op.

## Hard rules

- **Edit existing skills only.** Never create a new skill directory. Net-new
  Upstream skills are suggestion-only.
- **Never edit the Upstream clone** or anything outside the target skill set
  (except the fork's last-checked SHA in Step 4).
- Prefer the smallest edit that lands the improvement. No rewrites for style.

## Output: the rationale

Summarize for the human reviewing/committing your change:

- **Edits made:** per edited skill, what changed and *why* (which Upstream
  improvement it carries).
- **Considered but skipped:** edit-candidates left unchanged, with the reason
  (Matt-specific, already covered, not an improvement).
- **Suggested imports:** net-new Upstream skills worth a human's look, one line
  each — explicitly *not added as files*.

If you made no edits at all, say so plainly and explain why.
