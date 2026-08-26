# Namespace the firestartr-operation Feature's render under `installationPath`

The `firestartr_operation` Feature (ADR-0011) rendered its files flat at the
target repo's root. That's fine for a repo dedicated to hosting just this
one skill, but risky for any other repo: a Feature-owned `README.md`,
`SKILL.md`, etc. would silently overwrite whatever the repo already had
there. We added an `installationPath` Feature `$arg` (default `"skills"`, no
trailing slash) so every rendered file lands under
`{installationPath}/firestartr-operation/…` instead — matching the
`skills/{name}/SKILL.md` layout agent harnesses already expect, and letting
the Feature attach to an arbitrary, already-populated repo without
collision. The skill's own README (its **Skill README**, mirrored by the
Promote run, deleted from the render by `prefapp/features#1266`) is restored
under this same prefix rather than left un-namespaced or dropped — it's just
another mirrored file now, no special-casing needed.

## Considered Options

- **Leave the Skill README un-namespaced at the repo root.** Rejected: once
  "attach to a dedicated repo" is retired as primary advice (an arbitrary
  existing repo becomes the expected target), this is exactly the collision
  namespacing was introduced to avoid — it would clobber that repo's real
  README.
- **Drop the Skill README from the render entirely**, keeping only the
  features-owned `templates/docs/README.md`. Rejected: that page is
  pre-install catalog content, never rendered into the target repo —
  post-install content (full Prerequisites detail, the Troubleshooting
  pointer) would have no home for someone who already installed the Feature.

## Consequences

`packages/firestartr_operation/config.yaml` gains an `installationPath` arg
and every `files:` entry's `dest` is now a Mustache template (`{{|
installationPath |}}/firestartr-operation/…`) instead of a literal path.
`.github/promote-run/regen_files_list.py`'s existing-entry lookup had to
switch from keying on `dest` to keying on `src`, since `dest` is no longer a
plain path once namespaced.
