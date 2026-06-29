# GitHub-only issue tracker

Skills keep GitHub + the `gh` CLI as the issue tracker, with no tracker
abstraction. All Prefapp work and all current clients use GitHub; building
GitLab/Azure DevOps branches now would be speculative. Skills carry no hardcoded
source-repo name — they act on whatever repo they run in.

## Consequences

`to-prd`, `to-issues`, and the tracker-conventions doc stay essentially intact.
If a client on a non-GitHub tracker appears later, revisit this ADR.
