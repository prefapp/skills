---
name: implement
description: "Implement a piece of work based on a PRD or set of issues."
disable-model-invocation: true
---

> **Before acting:** read any root `AGENTS.md` / `CLAUDE.md` and obey it — repo rules override this skill.

Implement the work described by the user in the PRD or issues.

Before exploring, follow the context-doc rules in [domain-modeling/domain.md](../domain-modeling/domain.md).

Use /tdd where possible, at pre-agreed seams.

Run the project's lint and test commands scoped to what you touched. Run single test
files frequently while iterating; run the full suite once at the end.

Once done, use /review to review the work.

**Do not commit.** Stop and report what you changed and how you validated it. Commits
require explicit, single-use user approval.
