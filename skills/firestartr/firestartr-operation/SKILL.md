---
name: firestartr-operation
description: Single entry point for operating a Prefapp-managed Firestartr platform from a plain-language request.
disable-model-invocation: true
---

# Firestartr Operation

Turn a client's plain-language platform request into the right change, executed
safely. Translate platform internals (claim kinds, YAML paths, reconciliation
states) into the client's own terms — repos, teams, users, secrets, systems,
domains — and never say "claim" to them. Run Steps 1-3 in order.

**Asking the client:** use `grilling` if available — one question at a time,
each with a recommended answer. Prefer exploring the repos over asking.

**Tool preference:** try `fs-forge-cli` first — it knows the schemas, the
claims-map, and lands changes itself via `create`/`edit`/`clone --commit`. Read
a command's own output fully before reaching for another tool. Fall back to raw
`gh` (`reference/gh-cookbook.md`) only for what the CLI can't do.

## Common rules

Apply to every invocation, on top of whatever the matched playbook adds:

- **Step commitment.** Once Step 2 classifies the intent and the client
  approves the resulting plan, only the matched playbook's own numbered
  steps execute. A need discovered mid-flow is a new request: re-classify
  and get fresh approval, never expand silently.
- **Every mutation goes through `lifecycle`.** No shortcutting it for any
  create, edit, clone, or delete.
- **Read current state before editing.** Fetch the live claim before
  proposing changes — array fields replace entirely, so you need the full
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
  wait for the client's instructions — don't push through a multi-step
  operation after one step fails.
- **Flag plan-vs-result discrepancies.** If the applied state differs from
  what was planned (silent defaults, missing propagation, unexpected
  values), call it out and ask whether to investigate or roll back.
- **Dual-layer errors.** Lead with a client-friendly explanation, then the
  technical detail (claim kind, YAML path, CLI error) below it.

## CLI contract

The fs-forge-cli commands and flags documented in this skill and its
`reference/` files must always match fs-forge-cli's actual current contract —
this skill is a living mirror, not a frozen snapshot; when the CLI changes,
update the docs, don't let them drift. The specific fs-forge-cli version a
given release's instructions were validated against is recorded only in that
release's release-please-generated CHANGELOG entry (this skill is versioned by
release-please in monorepo mode; tag `firestartr-operation-vX.Y.Z`) — there is
no duplicate, manually-maintained version note elsewhere.

## Step 1 — Resolve the target platform

Read `firestartr-config.yaml` from this skill's directory — schema:
`reference/config-schema.md`.

If the file is missing, empty, or doesn't match that schema (e.g. the old
single `organization: { name }` shape), tell the client (e.g. "no usable
config found — let's set one up") and treat it as unset. Never migrate or
carry forward old values silently.

**Path resolution.** Normalize the current working directory (expand `~`,
strip any trailing slash) and normalize every organization's `paths` entries
the same way before comparing — stored paths may be in `~`-form. Match on
path-segment boundaries: a stored path matches when it equals the directory
or is a prefix of it ending on a `/` (so `/home/me/proj` never matches
`/home/me/projectX`). The organization with the longest matching path is the
target.

- **Ambiguity** (two organizations tie — only reachable by hand-editing the
  file inconsistent): show the whole file highlighting the conflict, ask the
  client which organization should own that path, remove it from the losing
  entry, show-before-write.
- **No match** (unset, or the directory matches nothing registered): present
  a numbered list of configured organization names plus "new organization"
  (the only option when unset). Existing org → append the current directory
  to its `paths`, show-before-write. "New organization" → the flow below. The
  client may decline instead; nothing is written, the same prompt reappears
  next run.

**New-organization flow:**
1. Ask for the GitHub org slug (`name`).
2. Ask once: do the repos follow the default names (`{name}/claims`,
   `{name}/state-github`, `{name}/state-infra`, `{name}/catalog`)? Collect
   overrides for any that differ.
3. Propose the current directory as the `paths` entry; wait for confirmation
   or a different path.
4. Show-before-write.

**Show-before-write:** before writing any change to `firestartr-config.yaml`
— collapsing any path back to `~`-form when it's under the home directory —
display the whole resulting file and wait for confirmation. Declining writes
nothing; the same prompt reappears next run. Warn, don't block, if a new path
doesn't exist on disk yet.

Do not touch any repository until the organization resolves to a concrete
value.

**Resolve the CLI version** once the organization is known:
1. If `cli_version` is set, use it as `{version}`.
2. Otherwise:
   ```bash
   npm dist-tag ls @firestartr/fs-forge-cli | awk '$1 == "latest:" { print $2 }'
   ```
   Empty or `snapshot` → no stable release: list versions with
   `npm view @firestartr/fs-forge-cli versions`, ask the client to pick one,
   persist as `cli_version` (show-before-write).

Emit one line confirming the resolved context, e.g.:
> `Using org: prefapp-demo (~/work/prefapp) | fs-forge: 0.1.0`

**Skill-target CLI version: `0.10.0`**.
Compare `{version}` against it with a plain semver check (no `--help`
call needed):

- `>= {target version}` → proceed.
- `< {target version}` and pinned (`cli_version` set): tell the client the pin
  predates this skill's target and offer to bump it (show-before-write) — never
  override an explicit pin silently. Declined: fall back to `{version}`'s own
  `--help`/`--help --json` output to see what it actually supports, and use
  whatever it reports.
- `< {target version}` and unpinned: same as the "no stable release found" flow
  above — ask the client to pick a version and pin it.

**Completion:** you hold a concrete `{org}`, `{claims_repo}`, `{version}`, and
the matched path.

## Step 2 — Classify the intent

Map the request to one or more playbooks in `playbooks/`. A mutating request
always loads `lifecycle` in addition to its authoring playbook.

| The client wants to… | Load |
|---|---|
| create a repo | `clone-claim` + `lifecycle` + proactive `feature-advisor` — default; see "When to clone vs. create" there for the fallback |
| create a team, user, system, domain, secret, webhook, or TF workspace (tfwp, tfworkspace) | `create-claim` + `lifecycle` |
| duplicate an existing repo/team/etc. as the starting point for a new one | `clone-claim` + `lifecycle` + proactive `feature-advisor` |
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

Pick the claim **kind** from the intent yourself — the client never chooses
one (`reference/reference.md` has the full kind↔intent map). Ask one
clarifying question if the intent is ambiguous.

**Completion:** you know which playbook(s) this request needs.

## Step 3 — Commit to steps, then execute

Read the chosen playbook file(s) from `playbooks/`. If the harness exposes a
todo-list tool, copy the playbook's numbered steps into it before executing
any of them — this is step commitment made visible, not a separate format.
Then follow the steps end to end. Reference material in `reference/` is
pulled in on demand when a playbook points at it. Report back to the client
in their own terms — never the word "claim."

**Completion:** the change is landed — fs-forge-managed (`--commit`
dispatched and reported) or manual (PR merged, hydrated, state PR merged) —
or the question is answered, and the client has a plain-language summary.
