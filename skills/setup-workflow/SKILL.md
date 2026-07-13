---
name: setup-workflow
description: Bootstrap a repo for the workflow skills — detect its domain-doc layout (no-docs / single-context / multi-context), scaffold CONTEXT/CONTEXT-MAP + docs/adr, and wire AGENTS.md routing. Run once before first use of the other workflow skills.
disable-model-invocation: true
---

> **Before acting:** read any root `AGENTS.md` / `CLAUDE.md` and obey it — repo rules override this skill.

# Setup Workflow

Scaffold the per-repo domain-doc layout the workflow skills assume, and wire the
routing that points agents at it.

The issue tracker used by these skills is **GitHub** (`gh` CLI). See
[issue-tracker-github.md](./issue-tracker-github.md) for the conventions.

This is a prompt-driven skill, not a deterministic script. Explore, present what
you found, confirm with the user, then write.

## Process

### 1. Explore

Read whatever exists; don't assume:

- `git remote -v` — confirm this is a GitHub repo.
- `AGENTS.md` (and `CLAUDE.md`) at the repo root — does an `## Agent skills` (or workflow routing) section already exist?
- `CONTEXT.md` and `CONTEXT-MAP.md` at the repo root.
- `docs/adr/` and any per-package `docs/adr/` directories.
- `docs/agents/triage-labels.md` — the triage label vocabulary (for the `triage` skill).
- `pnpm-workspace.yaml`, root `package.json` `workspaces`, or populated `packages/*` directories with their own `src/` — signals a monorepo.

### 2. Decide the layout

Detect the repo's current state and pick the layout:

- **`CONTEXT-MAP.md` exists at root** → already multi-context. Extend it; never clobber.
- **Root `CONTEXT.md` exists, no `CONTEXT-MAP.md`** → single-context.
- **Neither exists** → no-docs. Pick by repo shape:
  - **Monorepo-like** — `pnpm-workspace.yaml` exists, root `package.json` has a `workspaces` field, **or** populated `packages/*` directories have their own `src/` → suggest **multi-context**.
  - **Otherwise** → suggest **single-context**.

Present what you found and the proposed layout, and confirm with the user before writing.

### 3. Scaffold the layout

> Only scaffold when the user has asked you to set the repo up. Do **not** author
> glossary terms or ADR content here — `CONTEXT.md`/ADR bodies are filled in lazily
> by `/domain-modeling` (via `/grill-with-docs` and `/improve-codebase-architecture`)
> as packages are touched. This skill only creates the structure.

**Triage labels.** The `triage` skill maps seven canonical roles (two category
roles and five state roles) to real label strings. Write
`docs/agents/triage-labels.md` with the defaults (each label
equal to its canonical name) unless the user's tracker already uses other
strings — then collect the overrides so `triage` applies existing labels instead
of creating duplicates.

**Single-context:**

```
/
├── CONTEXT.md          ← empty glossary stub
└── docs/adr/           ← empty (system-wide ADRs)
```

**Multi-context:**

```
/
├── CONTEXT-MAP.md                  ← lists packages/contexts, links to their CONTEXT.md
├── docs/adr/                       ← system-wide ADRs
└── packages/<pkg>/
    ├── CONTEXT.md                  ← per-package glossary stub
    └── docs/adr/                   ← package-specific ADRs
```

Use the format in [../domain-modeling/CONTEXT-FORMAT.md](../domain-modeling/CONTEXT-FORMAT.md)
for `CONTEXT.md`/`CONTEXT-MAP.md` and [../domain-modeling/ADR-FORMAT.md](../domain-modeling/ADR-FORMAT.md)
for ADRs. The consumer rules every skill follows live in
[../domain-modeling/domain.md](../domain-modeling/domain.md).

### 4. Wire routing into AGENTS.md

Routing lives in **`AGENTS.md`** (or `CLAUDE.md`). Add or update an `## Agent skills`
block — update it in place if it already exists, don't append a duplicate, and don't
overwrite surrounding sections:

```markdown
## Agent skills

### Domain docs

[one-line summary of layout — "single-context" or "multi-context"]. See `.agents/skills/domain-modeling/domain.md` for the consumer rules.
```

Also confirm a `### Triage labels` note points at `docs/agents/triage-labels.md`.

### 5. Done

Tell the user the layout is scaffolded and that `CONTEXT.md`/ADR bodies get filled
in lazily by `/domain-modeling` as packages are touched.
