# Prefapp Workflow Skills

A set of harness-agnostic agent skills that define the end-to-end development
workflow Prefapp developers (and clients' developers) follow on any repository.
Extracted from a proven, repo-specific skill set and generalized to work anywhere.

## The skills

| Skill | What it does |
|---|---|
| `setup-workflow` | One-time repo bootstrap: detect doc layout (single vs multi-context), scaffold `CONTEXT`/`docs/adr`, wire routing. Run first on a fresh repo. |
| `grilling` | Relentless one-question-at-a-time interview to stress-test a plan before building. |
| `grill-with-docs` | `grilling` that also writes CONTEXT/ADRs as it goes (runs `domain-modeling`). |
| `domain-modeling` | Build/sharpen the glossary + ADRs. Single- and multi-context aware. |
| `codebase-design` | Deep-module vocabulary (module / interface / depth / seam) + testability principles. |
| `to-prd` | Synthesize the conversation into a PRD and publish it as a GitHub issue. |
| `to-issues` | Break a PRD/plan into independently-grabbable vertical-slice GitHub issues. |
| `implement` | Implement from PRD/issues at agreed seams. **Never commits.** |
| `tdd` | Red-green-refactor, one test at a time. |
| `diagnosing-bugs` | Disciplined feedback-loop debugging for hard bugs / perf regressions. |
| `review` | Two-axis review (Standards + Spec) via parallel sub-agents. |
| `improve-codebase-architecture` | Periodic deep-module rescue scan + HTML report. |
| `handoff` | Compact the conversation into a handoff doc for another agent. |

## Typical flow

```
setup-workflow            (once per repo)
        │
   grilling / grill-with-docs        ← align on the plan
        │
     to-prd                          ← PRD published as a GitHub issue
        │
    to-issues                        ← PRD split into vertical slices
        │
    implement                        ← uses tdd + codebase-design at seams
        │
     review                          ← Standards + Spec
```

Cross-cutting, pull in anytime: `domain-modeling`, `diagnosing-bugs`,
`improve-codebase-architecture`, `handoff`.

## Install

Run `./install.sh` from the repo root. It symlinks the `skills/` directory into a
`prefapp-workflow/` namespace under each detected harness's skills location, so
`git pull` keeps everyone up to date automatically.

```sh
git clone https://github.com/prefapp/skills.git ~/work/prefapp/skills
cd ~/work/prefapp/skills
./install.sh
```

Skills are **symlinked, never copied** — the repo is the source of truth.

## Per-harness discovery details

### pi

- Skills location: `~/.agents/skills/`
- Install: `~/.agents/skills/prefapp-workflow → <repo>/skills`
- Recursive discovery: **confirmed** — pi walks nested directories, so a single
  namespace-dir symlink exposes every skill.

### OpenCode

- Skills location: `~/.config/opencode/skills/`
- Install: `~/.config/opencode/skills/prefapp-workflow → <repo>/skills`
- Recursive discovery: **unconfirmed** — if OpenCode does not recurse into nested
  dirs, skills won't be discovered via the namespace symlink.

  **Fallback:** create per-skill symlinks directly in the skills root:
  ```sh
  for skill in ~/work/prefapp/skills/skills/*/; do
    ln -sfn "$skill" ~/.config/opencode/skills/"$(basename "$skill")"
  done
  ```

### Claude Code

- Skills location: `~/.claude/skills/`
- Install: `~/.claude/skills/prefapp-workflow → <repo>/skills`
- Recursive discovery: **unconfirmed** — same caveat as OpenCode.

  **Fallback:** create per-skill symlinks directly in the skills root:
  ```sh
  for skill in ~/work/prefapp/skills/skills/*/; do
    ln -sfn "$skill" ~/.claude/skills/"$(basename "$skill")"
  done
  ```

## Getting the most out of these skills

- **Start every new repo with `setup-workflow`** to scaffold the domain doc layout the
  other skills expect (`CONTEXT.md` + `docs/adr/`).
- **Let `domain-modeling` fill in `CONTEXT.md` lazily** — don't pre-populate it; terms
  get added as they crystallize during grilling/implementation.
- **`implement` never commits.** It stops and reports what changed. Commits require
  explicit user approval — this is by design (see `AGENTS.md` global rules).
- **`review` needs a fixed point** (branch, tag, SHA). Run it as `review main` or
  `review HEAD~5` after finishing a feature.
- **`handoff` saves to the OS temp dir**, not the repo. Pass an argument describing
  what the next session will focus on to get a targeted doc.
