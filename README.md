# Prefapp Workflow Skills

A set of harness-agnostic agent skills that define the end-to-end development
workflow Prefapp developers (and clients' developers) follow on any repository.
Extracted from a proven, repo-specific skill set and generalized to work anywhere.

## The skills

| Skill | What it does |
|---|---|
| `setup-workflow` | One-time repo bootstrap: detect doc layout (single vs multi-context), scaffold `CONTEXT`/`docs/adr`, wire routing. Run first on a fresh repo. |
| `grilling` | Relentless round-by-round interview to stress-test a plan before building. |
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
| `wizard` | Generate an interactive bash wizard that walks a human through steps only they can perform (credentials, third-party dashboards, migrations). |
| `writing-for-agents` | Reference for writing any document an agent consumes — skills, `AGENTS.md`/`CLAUDE.md` — predictably. |

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
`writing-for-agents`. For an effort too big to hold in one session, start with
`wayfinder`. To move incoming issues/PRs through a triage state machine, use
`triage`.

## Install

Run `./install.sh` from the repo root to see the available options. Use
`--workflow` for the workflow set, `--fs` for the Firestartr operational skill,
or `--all` for both. The selected skills are linked into the canonical
`~/.agents/skills/` location — which both pi and OpenCode read — plus
`~/.claude/skills/` if Claude Code is detected. `git pull` keeps everyone up to
date automatically.

```sh
git clone https://github.com/prefapp/skills.git ~/work/prefapp/skills
cd ~/work/prefapp/skills
./install.sh --workflow
```

Skills are **symlinked, never copied** — the repo is the source of truth.

## Tests

Run the local test entrypoints from the repository root:

```sh
./tests/test_install.sh
```

### Opt-in: Firestartr operational skill set

A separate, client-facing operational set (drive a Prefapp-managed Firestartr
platform via one `/firestartr-operation` command) ships under `firestartr/` and is
installed separately or together with the workflow set:

```sh
./install.sh --fs  # or: ./install.sh --all
```

This creates a second namespace symlink `~/.agents/skills/prefapp-firestartr`
(plus flat per-skill links in `~/.claude/skills/` if Claude Code is detected). On first use the skill asks
for your organization and writes a git-ignored `firestartr-config.yaml`; nothing
client-specific is ever committed.

## Per-harness discovery details

### `~/.agents/skills` (canonical — always linked, covers pi + OpenCode)

- Skills location: `~/.agents/skills/`
- Workflow install: `~/.agents/skills/prefapp-workflow → <repo>/skills`
- Recursive discovery: **confirmed** — nested directories are walked, so a single
  namespace-dir symlink exposes every skill.
- Both pi and OpenCode read this location, so no separate OpenCode symlink is
  needed. (OpenCode also reads `~/.config/opencode/skills`, but `~/.agents/skills`
  already covers it.)

### Claude Code

- Skills location: `~/.claude/skills/`
- Install: one symlink **per skill**, flat — `~/.claude/skills/tdd → <repo>/skills/tdd`
- Recursive discovery: **no** — Claude Code only reads `<skills-root>/<skill>/SKILL.md`,
  one level deep. A namespace-dir symlink hides everything inside it, so `install.sh`
  links each skill individually here. Skill names therefore share one flat namespace
  with your personal skills.
- Re-running `install.sh` removes the old `prefapp-workflow` / `prefapp-firestartr`
  namespace links and prunes per-skill links whose source is gone.
- If a name is already taken by something that isn't ours, that skill is skipped with a
  warning rather than overwritten. Rename or remove the existing one, then re-run.

### VSCode Agent (GitHub Copilot)

- Skills location: `~/.agents/skills/`
- Install: one symlink **per skill**, flat — `~/.agents/skills/tdd → <repo>/skills/tdd`
- Recursive discovery: **no** — VSCode Agent only reads `<skills-root>/<skill>/SKILL.md`,
  one level deep. A namespace-dir symlink such as `prefapp-workflow/` hides every skill
  inside it, so `install.sh` adds flat per-skill links alongside the namespace dir
  whenever `code` is installed or `~/.vscode` exists. Skill names therefore share one
  flat namespace with your personal skills.
- The namespace dir is kept for pi/OpenCode compatibility; VSCode Agent ignores it.
- Re-running `install.sh` prunes per-skill links whose source is gone.
- If a name is already taken by something that isn't ours, that skill is skipped with a
  warning rather than overwritten. Rename or remove the existing one, then re-run.

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

## Attribution

Parts of this workflow skill set are adapted from
[`mattpocock/skills`](https://github.com/mattpocock/skills). See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for its MIT license notice.
