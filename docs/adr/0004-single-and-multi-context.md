# Support single- and multi-context repos, detected not assumed

`setup-workflow` and `domain-modeling` support both layouts: single-context
(`CONTEXT.md` + `docs/adr/`) as the default, and multi-context (`CONTEXT-MAP.md`
+ per-package `CONTEXT.md` + per-package `docs/adr/`) when the repo is a
monorepo. `setup-workflow` **detects** the repo shape (root `package.json`
`workspaces`, or a `packages/` dir) and **suggests** the best layout for the
user to confirm — rather than hardcoding either layout as the default.

## Consequences

Skills detect the repo shape at runtime; neither single- nor multi-context is
assumed as a baked-in default.
