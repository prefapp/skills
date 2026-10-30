---
name: firestartr-operation
description: Single entry point for operating a Prefapp-managed Firestartr platform from a plain-language request.
disable-model-invocation: true
---

# Firestartr Operation

Turn a client's plain-language platform request into the right change, executed
safely. Translate platform internals (claim kinds, YAML paths, reconciliation
states) into the client's own terms (repos, teams, users, secrets, systems,
domains) and never say "claim" to them. Run Steps 1-3 in order.

**Asking the client:** use `grilling` if available: one question at a time,
each with a recommended answer. Prefer exploring the repos over asking.

**Tool preference:** try `fs-forge-cli` first: it knows the schemas, the
claims-map, and lands changes itself via `create`/`edit --commit`. Read
a command's own output fully before reaching for another tool. Fall back to raw
`gh` (`reference/gh-cookbook.md`) only for what the CLI can't do.

## Common rules

Apply to every invocation, on top of whatever the matched playbook adds:

- **Step commitment.** Once Step 2 classifies the intent and the client
  approves the resulting plan, only the matched playbook's own numbered
  steps execute. A need discovered mid-flow is a new request: re-classify
  and get fresh approval, never expand silently.
- **Every mutation goes through `lifecycle`.** No shortcutting it for any
  create, edit, or delete.
- **Read current state before editing.** Fetch the live claim before
  proposing changes: array fields replace entirely, so you need the full
  current value.
- **Pre-check before planning.** For a repo, team, user, or TF workspace use
  `preflight` (`reference/fs-forge-preflight.md`); every other kind uses
  `reference/fs-forge-discovery.md`. Target already exists → tell the
  client and suggest the right action instead (e.g. edit, not create).
- **Show plan before, show result after.** Preview with `fs-forge-cli`'s
  dry-run/print output, get explicit client approval, execute, then show
  the applied state the same way. No mutation without approval, ever.
- **Confirm destructive operations explicitly.** Deletes need the
  client's explicit go-ahead before execution.
- **One logical operation per confirmation cycle.** A coherent unit of
  work (e.g. "create three repos, a group, and a system") gets one
  plan → confirm → execute → result cycle; unrelated requests get separate
  cycles.
- **Stop on first failure.** Report what succeeded and what failed, then
  wait for the client's instructions: don't push through a multi-step
  operation after one step fails.
- **Flag plan-vs-result discrepancies.** If the applied state differs from
  what was planned (silent defaults, missing propagation, unexpected
  values), call it out and ask whether to investigate or roll back.
- **Dual-layer errors.** Lead with a client-friendly explanation, then the
  technical detail (claim kind, YAML path, CLI error) below it.

## CLI contract

Every fs-forge-cli command and flag here must exist in Step 1's target
version; CI (`.github/workflows/firestartr-operation-cli-contract.yaml`)
enforces it.

## Step 1: Resolve the target platform

**Skill-target CLI version: `2.0.1-snapshot.f24938d5`**

```bash
npx @firestartr/fs-forge-cli@{target} context --json
```

`{target}` is the version above. From the output: `org` → `{org}`;
`repos.claims` → `{claims_repo}`; `repos.stateGithub`, `repos.stateInfra`,
`repos.catalog` → the other repos; `cli.pinned` → the pin (`null` when unset).

On error (exit 1; stderr `{"error":{"code","message"}}`):
- `NO_CONFIG`, `NO_MATCH`, `AMBIGUOUS_MATCH`: run the setup flow in
  `reference/config-schema.md`.
- `NO_AUTH`: tell the client to run `gh auth login` or set `GITHUB_TOKEN`.

Touch no repository until `context` succeeds.

`{version}` = `cli.pinned` if set, else `{target}`:
- Unset or equal to `{target}`: no question.
- Pinned below `{target}` (semver): offer to bump the pin to `{target}`
  (show-before-write). Declined: use the pin and consult its `--help`.
- Pinned above `{target}`: use it and say so.
- Never ask because npm's `latest` differs.

Emit one line confirming the resolved context, e.g.:
> `Using org: prefapp-demo (~/work/prefapp) | fs-forge: 2.0.1`

**Completion:** you hold a concrete `{org}`, `{claims_repo}`, `{version}`, and
`matchedPath`.

## Step 2: Classify the intent

Map the request to one or more playbooks in `playbooks/`. A mutating request
always loads `lifecycle` in addition to its authoring playbook.

| The client wants to… | Load |
|---|---|
| create or duplicate a repo (including another like an existing one) | `create-claim` + `lifecycle` + proactive `feature-advisor` |
| create or duplicate a team, user, system, domain, secret, webhook, or TF workspace (tfwp, tfworkspace), including another like an existing one | `create-claim` + `lifecycle` |
| add or remove members of a team | `edit-claim` + `lifecycle` |
| set a repo's owner, maintainers, platform owner, CODEOWNERS, or collaborators | `edit-claim` + `lifecycle` |
| add, edit, remove, or list a Feature on a repo | `edit-claim` + `lifecycle` |
| change any other field of an existing repo/team/user/TF workspace | `edit-claim` + `lifecycle` |
| delete a repo, team, user, or TF workspace | `lifecycle` |
| know if a repo/team is in sync, drifted, orphaned, or stale | `reconciliation` |
| watch check runs on a repo, or monitor plan-apply status | `reconciliation` |
| know who owns a service, what's in a system, or browse/search topology | `catalog` |
| want a capability in a repo without naming a specific feature | `feature-advisor` (+ `edit-claim` + `lifecycle` if accepted) |
| know a field, default, feature, or naming rule | `reference/reference.md` |
| know why something failed, or isn't behaving as expected | `troubleshooting` |
| check if a name is available before creating something | `reference/fs-forge-preflight.md` |

Pick the claim **kind** from the intent yourself: the client never chooses
one (`reference/reference.md` has the full kind↔intent map). Ask one
clarifying question if the intent is ambiguous.

**Completion:** you know which playbook(s) this request needs.

## Step 3: Commit to steps, then execute

Read the chosen playbook file(s) from `playbooks/`. If the harness exposes a
todo-list tool, copy the playbook's numbered steps into it before executing
any of them: this is step commitment made visible, not a separate format.
Then follow the steps end to end. Reference material in `reference/` is
pulled in on demand when a playbook points at it. Report back to the client
in their own terms, never the word "claim."

**Completion:** the change is landed: fs-forge-managed (`--commit`
dispatched and reported) or manual (PR merged, hydrated, state PR merged),
or the question is answered, and the client has a plain-language summary.
