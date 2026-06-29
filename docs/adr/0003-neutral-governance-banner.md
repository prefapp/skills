# Neutral governance banner

Each skill opens with one neutral line — *read the repo's `AGENTS.md` / `CLAUDE.md`
and obey it; repo rules override this skill* — instead of a banner that names a
specific multi-file governance layout. We assume the target repo's
`AGENTS.md`/`CLAUDE.md` already chains to whatever rules/norms files that repo
uses, so skills make no assumption about a specific governance-file layout.

## Consequences

Fresh-context subagents still get bound to repo governance via the one file
every harness already loads, without hardcoding `CONSTITUTION.md`/`RULES.md`
paths that most repos won't have.
