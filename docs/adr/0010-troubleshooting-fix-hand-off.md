# Troubleshooting hands off diagnosed fixes to the owning playbook

Real-org use of the troubleshooting playbook (PR #75) showed the deliberate
"diagnose, don't fix" policy from #72 was too conservative: for the failure
surfaces it's most confident about, clients want the fix applied, not just
named. This reverses that policy for a bounded subset of surfaces.

## Decision

Once `troubleshooting` names a fix, it continues straight into the playbook
that owns it (`edit-claim`/`clone-claim`/`create-claim`) in the same turn,
using the diagnosed field/value as the proposed change — that playbook's own
dry-run → approve → commit flow is reused untouched, never reimplemented.

- **Hand off, don't reimplement.** No new mutation logic lives in
  `troubleshooting.md`; it stops at naming the fix, the owning playbook does
  the rest, under its existing approval gate.
- **Staged, not universal.** Ships first for only the fs-forge-cli/PR-verify-
  render error-shape surface (the one deterministic table). The
  Terraform-apply/reconciliation "claim-traceable" surface is deferred to a
  follow-up once this pattern's proven live.
- **`delete` opts out.** Never chosen autonomously as a fix — only
  suggested, and only proceeds if the client explicitly asks for it.
- **A validation sweep — `validate-claims.yaml` dispatched fresh, not just
  read — is a last resort before escalating, never a first move.** Reserved
  for surfaces where a broken reference could plausibly be the cause:
  PR-verify/render-pipeline denial, hydrate dispatch/execution, Terraform
  apply/operator reconciliation post-merge (claim-traceable-but-unclear
  only), and an `fs-forge-cli` `--commit` failure, but only its
  uniqueness/stale-branch shapes — schema/unknown-kind/ambiguous-defaults
  are exactly as self-contained via `--commit` as via a dry run (`validate`
  is schema-only, never cross-references), so a sweep adds nothing there.
  Reuse a recent-enough existing run for diagnosis; verifying a fix always
  dispatches fresh, since a prior run can't reflect a fix that didn't exist
  yet. A green run confirms the whole repo; a red one only guarantees the
  first broken claim found (rendering halts there) — fix, re-dispatch, and
  report each round rather than treating one pass as exhaustive. No client
  approval needed (`contents: read`, the same tier as the re-hydrate
  exception above), but say it's running — it's a multi-repo-checkout,
  multi-minute job.

## Consequences

`troubleshooting.md`'s "Diagnose, don't fix — with one exception" framing is
rewritten — fixing is now the default for a named subset of surfaces, not a
rare exception. `reconciliation.md` and the existing stale-branch
git-branch-delete verdict are untouched; neither was part of this decision.
