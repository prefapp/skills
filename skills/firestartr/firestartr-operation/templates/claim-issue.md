# Claim issue template

Fill this in and open it as the tracking issue in `{claims_repo}` before any
branch/PR (lifecycle step 0). Write it in the **client's** terms — repos, teams,
users, buckets — never the word "claim". Drop rows that don't apply.

```markdown
## Goal
<one line: what the client wants and why>

## What to create
- **Thing:** <repo | team | user | S3 bucket | secret | …>
- **Name:** <name the client will see>
- **Owner:** <team or person responsible>
- **Where:** <system / project / AWS account, if relevant>

## Settings
<the decisions that matter — visibility, region, versioning, policy, members, …>

## Notes
<anything the operator should know: related entities, follow-ups>
```

Title format: `Create <thing> <name> for <owner>` (e.g. `Create S3 bucket
firestartr-demo-static-files for frontend-dev`).
