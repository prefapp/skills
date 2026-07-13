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
| `to-spec` | Synthesize the conversation into a spec and publish it as a GitHub issue. |
| `to-tickets` | Break a spec/plan into independently-grabbable tracer-bullet tickets, each declaring its blocking edges, published as GitHub issues. |
| `triage` | Move issues through a state machine of triage roles; optionally include external PRs when the repo config enables PRs as a triage surface — categorise, verify, grill if needed, and write agent-ready briefs. |
| `implement` | Implement from spec/tickets at agreed seams. **Never commits.** |
| `tdd` | Red-green-refactor, one test at a time. |
| `diagnosing-bugs` | Disciplined feedback-loop debugging for hard bugs / perf regressions. |
| `review` | Two-axis review (Standards + Spec) via parallel sub-agents. |
| `improve-codebase-architecture` | Periodic deep-module rescue scan + HTML report. |
| `wayfinder` | Chart a too-big-for-one-session effort as a shared map of decision tickets on the tracker; resolve them one at a time. |
| `research` | Delegate reading/investigation against primary sources to a background agent; capture findings as a Markdown file. |
| `prototype` | Build throwaway code (logic TUI or UI variants) to answer a design question, then delete or absorb it. |
| `handoff` | Compact the conversation into a handoff doc for another agent. |
| `writing-great-skills` | Reference vocabulary + principles for authoring/editing skills predictably. |

## Typical flow

```
setup-workflow            (once per repo)
        │
   grilling / grill-with-docs        ← align on the plan
        │
     to-spec                         ← spec published as a GitHub issue
        │
    to-tickets                      ← spec split into tracer-bullet tickets
        │
    implement                        ← uses tdd + codebase-design at seams
        │
     review                          ← Standards + Spec
```

Cross-cutting, pull in anytime: `domain-modeling`, `diagnosing-bugs`,
`improve-codebase-architecture`, `handoff`, `research`, `prototype`,
`writing-great-skills`. For an effort too big to hold in one session, start with
`wayfinder`. To move incoming issues/PRs through a triage state machine, use
`triage`.

## Install

Run `./install.sh` from the repo root. It always symlinks the `skills/` directory
into the canonical `~/.agents/skills/prefapp-workflow/` location — which both pi and
OpenCode read — plus `~/.claude/skills/` if Claude Code is detected. `git pull`
keeps everyone up to date automatically.

```sh
git clone https://github.com/prefapp/skills.git ~/work/prefapp/skills
cd ~/work/prefapp/skills
./install.sh
```

Skills are **symlinked, never copied** — the repo is the source of truth.

### Opt-in: Firestartr operational skill set

A separate, client-facing operational set (drive a Prefapp-managed Firestartr
platform via one `/firestartr-operation` command) ships under `firestartr/` and is
**not** installed by default. Add it with:

```sh
./install.sh --with-firestartr
```

This creates a second namespace symlink `~/.agents/skills/prefapp-firestartr`
(plus `~/.claude/skills/` if Claude Code is detected). On first use the skill asks
for your organization and writes a git-ignored `organization.yaml`; nothing
client-specific is ever committed.

## Per-harness discovery details

### `~/.agents/skills` (canonical — always linked, covers pi + OpenCode)

- Skills location: `~/.agents/skills/`
- Install: `~/.agents/skills/prefapp-workflow → <repo>/skills` (always created)
- Recursive discovery: **confirmed** — nested directories are walked, so a single
  namespace-dir symlink exposes every skill.
- Both pi and OpenCode read this location, so no separate OpenCode symlink is
  needed. (OpenCode also reads `~/.config/opencode/skills`, but `~/.agents/skills`
  already covers it.)

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
