# Install via a namespaced symlink, multi-harness documented

Skills live under a top-level `skills/<name>/SKILL.md`. An `install.sh`
symlinks the whole `skills/` dir into a single namespaced directory
`prefapp-workflow/` under a harness's skills location (default
`~/.agents/skills/prefapp-workflow`). One symlink, recursive discovery, grouped
so company skills never collide with a developer's personal skills, and
`git pull` updates everyone. Symlink, never copy.

We take the **most general** install approach for the confirmed case (pi,
recursive discovery) and **document the per-harness discovery edge cases**
(OpenCode `~/.config/opencode/skills`, Claude Code `~/.claude/skills`, whose
nested-recursion behavior isn't confirmed) in the README, so a developer can
adjust their own config or fall back to per-skill symlinks. Per-harness
slash-command wrappers (per-harness `.claude/commands` + `opencode.json` command
blocks) are **deferred** — native skill discovery already exposes the skills.

## Consequences

`install.sh` stays tiny (a symlink loop). If OpenCode/Claude turn out
non-recursive, the README's documented fallback (per-skill symlinks) covers it
without changing the repo layout.
