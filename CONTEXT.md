# Prefapp Workflow Skills

The shared, harness-agnostic agent skills that define the development workflow
Prefapp developers (and our clients' developers) follow on any repository we
manage or collaborate on. The skills are extracted from a proven, repo-specific
workflow set and generalized so they work in any repo.

## Language

**Skill**:
A self-contained capability package — a directory with a `SKILL.md` (Agent
Skills standard) plus optional helper docs/scripts. The unit this repo ships.

**Workflow set**:
The 13 generalized skills in this repo that, together, describe the end-to-end
development workflow (plan → spec → implement → review).
_Avoid_: skill bundle, skill pack.

**Workflow skill**:
A skill that is part of the generalized workflow set and is meant to apply to
any repository.
_Avoid_: generic skill.

**Repo-specific skill**:
A skill that only makes sense inside one repository (e.g. a renderer validator
tied to that repo's build). These stay behind in their home repo and are *not*
extracted here.

**Namespace dir**:
The single nested directory (`prefapp-workflow/`) under a harness's skills
location into which this repo is symlinked, so company skills never collide
with a developer's personal skills.

**Harness**:
An agent runtime that discovers and runs skills — pi, OpenCode, or Claude Code.

**Governance banner**:
The one-line preamble at the top of each skill telling the agent to read the
target repo's `AGENTS.md` / `CLAUDE.md` first and obey it. Repo rules override
the skill.

## The workflow set

| Skill | Invocation | What it does |
|---|---|---|
| `setup-workflow` | explicit | One-time repo bootstrap: detect doc layout (single vs multi-context), scaffold `CONTEXT`/`docs/adr`, wire routing. Run first on a fresh repo. |
| `grilling` | auto | One-question-at-a-time interview to stress-test a plan before building. |
| `grill-with-docs` | explicit | `grilling` that also writes CONTEXT/ADRs as it goes (runs `domain-modeling`). |
| `domain-modeling` | auto | Build/sharpen the glossary + ADRs. Single- and multi-context aware. |
| `codebase-design` | auto | Deep-module vocabulary (module / interface / depth / seam) + testability. |
| `to-prd` | explicit | Synthesize the conversation into a PRD and publish it as a GitHub issue. |
| `to-issues` | explicit | Break a PRD/plan into independently-grabbable vertical-slice GitHub issues. |
| `implement` | explicit | Implement from PRD/issues at agreed seams. **Never commits.** |
| `tdd` | auto | Red-green-refactor, one test at a time. |
| `diagnosing-bugs` | auto | Disciplined feedback-loop debugging for hard bugs / perf regressions. |
| `review` | auto | Two-axis review (Standards + Spec) via parallel sub-agents. |
| `improve-codebase-architecture` | explicit | Periodic deep-module rescue scan + report. |
| `handoff` | explicit | Compact the conversation into a handoff doc for another agent. |

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

Skills are **symlinked** (not copied) so `git pull` updates everyone instantly.
They land in a `prefapp-workflow/` namespace dir under each harness's skills
location:

- pi: `~/.agents/skills/prefapp-workflow → <repo>/skills` (recursive discovery, confirmed)
- OpenCode / Claude Code: same idea into their skills dir; recursion not yet
  confirmed — README documents the per-harness config edge cases.

## Decisions

See [`docs/adr/`](docs/adr/) for the why behind: source-of-truth, GitHub-only
tracker, governance banner, single/multi-context support, and the install model.
