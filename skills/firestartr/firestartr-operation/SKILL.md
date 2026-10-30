---
name: firestartr-operation
description: Operate a Prefapp-managed Firestartr platform from a plain-language request.
disable-model-invocation: true
---

# Firestartr Operation

Translate the client's request and report results in their terms; never say "claim" to them. Run Steps 1-3 in order.

**Asking the client:** use `grilling` if available: one question at a time,
each with a recommended answer. Prefer exploring the repos over asking.

**Tool preference:** try `fs-forge-cli` first and read its output fully. Use raw `gh` (`reference/gh-cookbook.md`) only for what the CLI can't do.

## Common rules

Apply to every invocation, on top of whatever the matched playbook adds:

- **Step commitment.** After classification and client approval, execute only the matched playbook's numbered steps. Re-classify and get fresh approval for any new need; never expand silently.
- **Every mutation goes through `lifecycle`**, including create, edit, and delete.
- **Read current state before editing.** Fetch the live claim before proposing changes; array fields replace entirely.
- **Pre-check before planning.** Use the kind's `preflight` value from
  `kinds show`; if null, use `reference/fs-forge-discovery.md`. See
  `reference/fs-forge-preflight.md`. If the target exists, tell the client
  and suggest the right action instead (e.g. edit, not create).
- **Plan → confirm → execute → result.** Show the CLI dry-run/print output, get explicit client approval, then show the applied state. No mutation without approval; deletes need explicit go-ahead. One coherent operation gets one cycle; unrelated requests get separate cycles.
- **Stop on first failure.** Report successes and failures; wait for instructions.
- **Flag plan-vs-result discrepancies.** Ask whether to investigate or roll back.
- **Dual-layer errors.** Lead with a client-friendly explanation, followed by technical detail.

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

**Completion:** `{org}`, `{claims_repo}`, `{version}`, and `matchedPath` (possibly null). All playbooks and references use these values.

## Step 2: Classify the intent

Map the request to one or more playbooks in `playbooks/`. A mutating request
always loads `lifecycle` in addition to its authoring playbook.

| The client wants to… | Load |
|---|---|
| create or duplicate a repo, including one like an existing repo | `create-claim` + `lifecycle` + proactive `feature-advisor` |
| create or duplicate a team, user, system, domain, secret, webhook, or TF workspace (tfwp, tfworkspace), including one like an existing entity | `create-claim` + `lifecycle` |
| team membership; repo owner, maintainers, platform owner, CODEOWNERS or collaborators; add/edit/remove/list a repo Feature; or any other existing field | `edit-claim` + `lifecycle` |
| delete a repo, team, user, or TF workspace | `lifecycle` |
| know if a repo/team is in sync, drifted, orphaned, or stale | `reconciliation` |
| watch check runs on a repo, or monitor plan-apply status | `reconciliation` |
| know who owns a service, what's in a system, or browse/search topology | `catalog` |
| want a capability in a repo without naming a specific feature | `feature-advisor` (+ `edit-claim` + `lifecycle` if accepted) |
| know a field, default, feature, or naming rule | `reference/reference.md` |
| know why something failed, or isn't behaving as expected | `troubleshooting` |
| check if a name is available before creating something | `reference/fs-forge-preflight.md` |

Pick the claim **kind** yourself from `npx @firestartr/fs-forge-cli@{version} kinds --json`;
the client never chooses one. For its capabilities, run
`npx @firestartr/fs-forge-cli@{version} kinds show <id> --json`.
Ask one clarifying question if the intent is ambiguous.

**Completion:** you know which playbook(s) this request needs.

## Step 3: Commit to steps, then execute

Read the chosen `playbooks/` or `reference/` files. If a todo-list tool is available, copy the playbooks' numbered steps before executing any. Follow them end to end; read their `reference/` pointers on demand.

**Completion:** the change is landed: fs-forge-managed (`--commit`
dispatched and reported) or manual (PR merged; hydrated and state PR merged when applicable),
or the question is answered, and the client has a plain-language summary.
