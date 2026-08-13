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
- **`validate-claims.yaml` gets dispatched, not just read.** Used both as a
  diagnostic (when a symptom isn't tied to an open PR) and as a post-fix
  verification sweep — the latter is waited on and its pass/fail reported
  alongside the fix, since unlike the main `--commit` dispatch, this sweep
  has no other mechanism to surface its result.

## Consequences

`troubleshooting.md`'s "Diagnose, don't fix — with one exception" framing is
rewritten — fixing is now the default for a named subset of surfaces, not a
rare exception. `reconciliation.md` and the existing stale-branch
git-branch-delete verdict are untouched; neither was part of this decision.
