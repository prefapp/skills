# Prefapp Workflow Skills

The end-to-end development workflow Prefapp developers (and clients'
developers) follow on any repository, packaged as 19 harness-agnostic agent
skills: plan → spec → implement → review. Extracted from a proven,
repo-specific skill set and generalized to work anywhere. Runs in pi,
OpenCode, Claude Code, and VS Code Copilot.

## Install

```sh
git clone https://github.com/prefapp/skills.git ~/work/prefapp/skills
cd ~/work/prefapp/skills
./install.sh --workflow
```

Skills are **symlinked, never copied** — the repo is the source of truth, and
`git pull` keeps every install up to date automatically. Run `./install.sh`
with no arguments for all options.

### Where the skills land

One symlink per skill, flat, into `~/.agents/skills/` (pi, OpenCode, VS Code
Copilot) and `~/.claude/skills/` if Claude Code is detected — e.g.
`~/.agents/skills/tdd → <repo>/skills/workflow/tdd`. Re-running `install.sh`
is safe. A name already taken by something that isn't ours is skipped with a
warning.

## Which skill when

Skills marked *(explicit)* only run when you ask for them by name; the rest
fire automatically when the situation matches.

### Plan

- **`setup-workflow`** *(explicit)* — Use when you're in a fresh repo:
  detects the doc layout (single- vs multi-context), bootstraps the
  `CONTEXT.md` + `docs/adr/` structure the other skills expect, and wires the
  routing. Run first, once per repo.
- **`grilling`** — Use when you have a plan or idea and want it stress-tested
  before building: a relentless round-by-round interview.
- **`grill-with-docs`** *(explicit)* — Use when you want the grilling session
  to also record the glossary and ADRs as it goes.
- **`triage`** *(explicit)* — Use when incoming issues need sorting: moves
  them through a state machine of triage roles — categorise, verify, grill if
  needed — into agent-ready briefs, recording rejections in `.out-of-scope/`.
  External PRs become a triage surface when the repo config enables it.
- **`wayfinder`** *(explicit)* — Use when the effort is too big to hold in one
  session: charts it as a map of decision tickets you resolve one at a time.

### Specify

- **`to-spec`** *(explicit)* — Use when the plan is aligned and needs to
  become a spec: synthesizes the conversation and publishes it as a GitHub
  issue.
- **`to-tickets`** *(explicit)* — Use when a spec needs breaking into
  independently grabbable tracer-bullet tickets with their blocking edges
  declared, published as GitHub issues.

### Implement

- **`implement`** *(explicit)* — Use when implementing from a spec or ticket,
  at the agreed seams. **Never commits** — it stops and reports what changed.
- **`tdd`** — Use when building test-first: red-green-refactor, one test at a
  time.

### Review

- **`review`** — Use when you want the changes since a fixed point (branch,
  tag, SHA) reviewed on two axes — Standards and Spec — via parallel
  sub-agents.

### Cross-cutting — pull in anytime

- **`domain-modeling`** — Use when terminology is fuzzy or the glossary and
  ADRs need sharpening.
- **`codebase-design`** — Use when designing a module's interface, deciding
  where a seam goes, or making code more testable.
- **`diagnosing-bugs`** — Use when something's broken or slow and the cause
  isn't obvious: a disciplined feedback loop, not guesswork.
- **`research`** — Use when a question needs reading legwork against primary
  sources, captured as a Markdown file in the repo.
- **`prototype`** — Use when a design question is best answered with
  throwaway code (a logic TUI or UI variants), deleted or absorbed after.
- **`improve-codebase-architecture`** *(explicit)* — Use when you want a
  periodic deep-module rescue scan with a report.
- **`handoff`** *(explicit)* — Use when you need to pass the session to
  another agent: compacts the conversation into a handoff doc.
- **`wizard`** — Use when a human must perform steps only they can
  (credentials, third-party dashboards, migrations): generates an interactive
  bash walkthrough.
- **`writing-for-agents`** — Use when writing or editing any document an
  agent consumes — skills, `AGENTS.md` — predictably.

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

## Getting the most out of these skills

- **Start every new repo with `setup-workflow`** to scaffold the domain doc
  layout the other skills expect (`CONTEXT.md` + `docs/adr/`).
- **Let `domain-modeling` fill in `CONTEXT.md` lazily** — don't pre-populate
  it; terms get added as they crystallize during grilling/implementation.
- **`implement` never commits.** It stops and reports what changed. Commits
  require explicit user approval — this is by design (see `AGENTS.md` global
  rules).
- **`review` needs a fixed point** (branch, tag, SHA). Run it as
  `review main` or `review HEAD~5` after finishing a feature.
- **`handoff` saves to the OS temp dir**, not the repo. Pass an argument
  describing what the next session will focus on to get a targeted doc.
