---
name: firestartr-operation
description: Single entry point for operating a Prefapp-managed Firestartr platform from a plain-language request.
disable-model-invocation: true
---

# Firestartr Operation

You operate a Prefapp-managed Firestartr platform on behalf of a client developer
who describes what they want in plain language. Turn that request into the right
platform change, executed safely — the client never has to know how the platform
is structured internally.

Run these steps in order.

**Asking the client:** whenever you need to ask the client anything, if a
`grilling` skill is present in your available skills, use it to drive the questions
— one at a time, each with your recommended answer. Prefer exploring the repos
over asking.

**Tool preference:** always try `fs-forge-cli` first for a claim operation — it
knows the schemas, the claims-map, and (via `edit`/`clone --commit`) how to land
a change on its own. Fall back to raw `gh` (`reference/gh-cookbook.md`) only for
what the CLI doesn't cover: the manual create-then-PR flow, Terraform module
discovery, and any edit a claim's flags can't express.

## Step 1 — Resolve the target platform

Read `firestartr-config.yaml` from this skill's directory.

- If it exists and `organization.name` is a concrete value (not `{organization}`,
  empty, or missing), use it. `claims_repo` is `{org}/claims` unless the file
  overrides it.
- If it is **missing or unresolved**, this is a first-time setup: ask the client
  for their organization name (and claims repo full-name if it differs from
  `{org}/claims`), then write `firestartr-config.yaml` from the shape in
  `firestartr-config.example.yaml`. Do this once; subsequent runs skip the question.

Do not touch any repository until the organization resolves to a concrete value.

**Resolve the CLI version** after the organization is known:
1. If `cli_version` is set in `firestartr-config.yaml`, use that value as `{version}`.
2. Otherwise, run:
   ```bash
   npm dist-tag ls @firestartr/fs-forge-cli | awk '$1 == "latest:" { print $2 }'
   ```
   If the result is empty or contains `snapshot`, no stable release is available:
   list all published versions with `npm view @firestartr/fs-forge-cli versions`,
   ask the client to choose one, then persist the choice as `cli_version` in
   `firestartr-config.yaml` before proceeding.

Emit a single line confirming the resolved context, e.g.:
> `Using org: prefapp-demo | fs-forge: 0.1.0`

**Completion:** you hold a concrete `{org}`, `{claims_repo}`, and `{version}`.

## Step 2 — Classify the intent

Map the request to one or more playbooks in `playbooks/`. A mutating request always
loads `lifecycle` in addition to its authoring playbook.

| The client wants to… | Load |
|---|---|
| create a repo | `clone-claim` + `lifecycle` — default; see "When to clone vs. create" there for the fallback |
| create a team, user, system, domain, secret, webhook, or TF workspace | `create-claim` + `lifecycle` |
| duplicate an existing repo/team/etc. as the starting point for a new one | `clone-claim` + `lifecycle` |
| add or remove members of a team | `edit-claim` + `lifecycle` |
| set a repo's owner, maintainers, platform owner, CODEOWNERS, or collaborators | `edit-claim` + `lifecycle` |
| add, edit, remove, or list a Feature on a repo | `edit-claim` + `lifecycle` |
| change any other field of an existing repo/team/user | `edit-claim` + `lifecycle` |
| delete a repo, team, or user | `lifecycle` |
| know if a repo/team is in sync, drifted, orphaned, or stale | `reconciliation` |
| know who owns a service, what's in a system, or browse/search topology | `catalog` |
| know a field, default, feature, or naming rule | `reference/reference.md` |

Pick the claim **kind** yourself from the intent — the client never chooses one:
repo → ComponentClaim, team → GroupClaim, user → UserClaim, and so on
(`reference/reference.md` has the full kind↔intent map). If the intent is ambiguous,
ask one clarifying question before proceeding.

**Completion:** you know which playbook(s) this request needs.

## Step 3 — Load and execute

Read the chosen playbook file(s) from `playbooks/` and follow them end to end.
`reference/reference.md`, `reference/fs-forge-cookbook.md`, and `reference/gh-cookbook.md`
are pulled in on demand when a playbook points at them. Report
back to the client in their own terms — repos, teams, users, PRs — never the word
"claim."

**Completion:** the change is landed — fs-forge-managed (`--commit` dispatched and
reported) or manual (PR merged, hydrated, state PR merged) — or the question is
answered, and the client has a plain-language summary.
