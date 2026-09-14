# Preflight: no import or rename flow yet

`fs-forge-cli`'s `preflight` command (gitops-k8s #2546) surfaces two
collisions this skill has no automated response to yet: a **provider
conflict** (the resource already exists at GitHub with no matching claim —
the CLI's own error even says "use import process") and a **rename**
(`--edition`'s `--old-name`/`--name` gates a mutation `fs-forge edit` can't
actually perform; claims have no rename operation).

## Decision

Don't build either now. On a provider conflict, tell the client plainly and
stop — no invented import step. Rename is not a first-class flow. The former
unofficial clone-then-delete recipe is withdrawn with claim cloning;
create-then-delete is not a substitute. `preflight --edition` still surfaces
the collision; we are not wiring a rename mutation.

## Consequences

`reference/fs-forge-preflight.md` documents both gaps explicitly so a future
change doesn't "fix" them by accident without knowing this was deliberate.
Revisit either once there's demonstrated client need and, for rename, an
actual CLI mutation to gate.
