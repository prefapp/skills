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
The 19 generalized skills in this repo that, together, describe the end-to-end
development workflow (plan → spec → implement → review).
_Avoid_: skill bundle, skill pack.

**Operational skill set**:
The opt-in Firestartr skills under `firestartr/` (namespace `prefapp-firestartr`)
that drive a Prefapp-managed platform. Separate audience (client developers) and
charter from the workflow set. Installed with `install.sh --fs` or `--all`.

**Playbook**:
A disclosed `.md` file loaded on demand by the single entry skill
`firestartr-operation` (e.g. `lifecycle`, `create-claim`). Not a skill — no
description, no auto-fire — so the operational group costs one description of
context load.

**Claim**:
Firestartr's declarative desired-state unit (ComponentClaim = repo, GroupClaim =
team, UserClaim = user, …). Internal vocabulary — the client never hears it; the
entry skill translates intent to the right claim kind.

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

**Upstream** (a.k.a. Matt's repo):
`github.com/mattpocock/skills`, the repository our workflow set was generalized
from. We track its changes to keep our skills sharp.
_Avoid_: source repo, origin.

**Sync run**:
A scheduled (Mon/Wed/Fri) GitHub Actions job that diffs Upstream since the
last-checked SHA, classifies the changes with `scope_changes.py`, and, if
anything relevant changed, opens/refreshes one **Sync issue** describing them.
It runs **no agent** and edits nothing — a pure notifier (`issues: write`).
Scope excludes Upstream's `in-progress/`, `deprecated/`, and `.out-of-scope/`;
`misc/` and `personal/` are suggestion-only.
_Avoid_: sync job, cron job.

**Last-checked SHA**:
The Upstream commit a fork has *actually incorporated*, stored in the fork so
each Sync run diffs exactly-once from there. Advanced **only by the human's edit
change, via the matt-sync skill** — never by the Action. A failed run or an
ignored issue changes nothing and self-heals on the next diff.

**Sync issue**:
The single GitHub issue a Sync run maintains, found by the `matt-sync` label: the
classifier's report of pending Upstream changes (edit-candidates → our skills,
import suggestions, ignored counts). At most one is open at a time — a run
refreshes it in place and auto-closes it when no actionable upstream changes are
pending. It proposes no edits and adds no files; the human acts on it by running
the matt-sync skill.
_Avoid_: sync PR.

**matt-sync skill**:
The human-run, **portable** skill at `.github/skills/matt-sync/` that carries
Upstream improvements into a fork's skills. It takes an *upstream location* and a
*target skill set* as inputs, so it can update any Matt-derived fork, mapping
upstream→target by semantic content. It edits existing skills only, never adds
new skill directories (net-new Upstream skills are suggestion-only), and
conditionally advances the fork's last-checked SHA. Not distributed by
`install.sh`.

**Governance banner**:
The one-line preamble at the top of each skill telling the agent to read the
target repo's `AGENTS.md` / `CLAUDE.md` first and obey it. Repo rules override
the skill.

## The workflow set

| Skill | Invocation | What it does |
|---|---|---|
| `setup-workflow` | explicit | One-time repo bootstrap: detect doc layout (single vs multi-context), scaffold `CONTEXT`/`docs/adr`, wire routing. Run first on a fresh repo. |
| `grilling` | auto | Round-by-round interview to stress-test a plan before building. |
| `grill-with-docs` | explicit | `grilling` that also writes CONTEXT/ADRs as it goes (runs `domain-modeling`). |
| `domain-modeling` | auto | Build/sharpen the glossary + ADRs. Single- and multi-context aware. |
| `codebase-design` | auto | Deep-module vocabulary (module / interface / depth / seam) + testability. |
| `to-spec` | explicit | Synthesize the conversation into a spec and publish it as a GitHub issue. |
| `to-tickets` | explicit | Break a spec/plan into independently-grabbable tracer-bullet tickets, each declaring its blocking edges, published as GitHub issues. |
| `triage` | explicit | Move issues through a state machine of triage roles; optionally include external PRs when the repo config enables PRs as a triage surface — categorise, verify, grill if needed, write agent-ready briefs, and record rejections in `.out-of-scope/`. |
| `implement` | explicit | Implement from spec/tickets at agreed seams. **Never commits.** |
| `tdd` | auto | Red-green-refactor, one test at a time. |
| `diagnosing-bugs` | auto | Disciplined feedback-loop debugging for hard bugs / perf regressions. |
| `review` | auto | Two-axis review (Standards + Spec) via parallel sub-agents. |
| `improve-codebase-architecture` | explicit | Periodic deep-module rescue scan + report. |
| `wayfinder` | explicit | Chart a too-big-for-one-session effort as a shared map of decision tickets on the tracker; resolve them one at a time. |
| `research` | auto | Delegate reading/investigation against primary sources to a background agent; capture findings as a Markdown file. |
| `prototype` | auto | Build throwaway code (logic TUI or UI variants) to answer a design question, then delete or absorb it. |
| `handoff` | explicit | Compact the conversation into a handoff doc for another agent. |
| `wizard` | auto | Generate an interactive bash wizard that walks a human through manual steps (credentials, third-party dashboards, migrations) only they can perform. |
| `writing-for-agents` | auto | Reference for writing any document an agent consumes — skills, `AGENTS.md`/`CLAUDE.md` — predictably. |

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
`improve-codebase-architecture`, `handoff`, `research`, `prototype`, `wizard`,
`writing-for-agents`. For an
effort too big to hold in one session, start with `wayfinder`. To move incoming
issues/PRs through a triage state machine, use `triage`.

## Install

Skills are **symlinked** (not copied) so `git pull` updates everyone instantly.
They land in a `prefapp-workflow/` namespace dir under each harness's skills
location:

- pi: `~/.agents/skills/prefapp-workflow → <repo>/skills` (recursive discovery, confirmed)
- OpenCode / Claude Code: same idea into their skills dir; recursion not yet
  confirmed — README documents the per-harness config edge cases.

The **operational skill set** is opt-in: `./install.sh --fs` adds a second
symlink `~/.agents/skills/prefapp-firestartr → <repo>/firestartr`. Use
`--workflow` for the workflow set or `--all` for both; no arguments shows help.

## Decisions

See [`docs/adr/`](docs/adr/) for the why behind: source-of-truth, GitHub-only
tracker, governance banner, single/multi-context support, the install model, the
two-category model (workflow set + opt-in operational set, ADR-0006),
schema-drift detection over auto-sync (ADR-0007), and tracking Upstream via a
notifier Action + human-run generic sync skill (ADR-0008).
