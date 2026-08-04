---
name: firestartr-operation
description: Single entry point for operating a Prefapp-managed Firestartr platform from a plain-language request.
disable-model-invocation: true
---

# Firestartr Operation

Turn a client's plain-language platform request into the right change, executed
safely. The client never hears "claim" or sees platform internals. Run these
steps in order.

**Asking the client:** use `grilling` if available — one question at a time,
each with a recommended answer. Prefer exploring the repos over asking.

**Tool preference:** try `fs-forge-cli` first — it knows the schemas, the
claims-map, and lands changes itself via `edit`/`clone --commit`. Read a
command's own output fully before reaching for another tool. Fall back to raw
`gh` (`reference/gh-cookbook.md`) only for what the CLI can't do: manual
create-then-PR, Terraform module discovery, edits its flags can't express.

## Step 1 — Resolve the target platform

Read `firestartr-config.yaml` from this skill's directory — schema:
`reference/config-schema.md`.

If the file is missing, empty, or doesn't match that schema (e.g. the old
single `organization: { name }` shape), tell the client (e.g. "no usable
config found — let's set one up") and treat it as unset. Never migrate or
carry forward old values silently.

**Path resolution.** Normalize the current working directory (expand `~`,
strip any trailing slash) and match it against every `paths` entry across
every organization by longest prefix. That organization is the target.

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

**Show-before-write:** before writing any change to `firestartr-config.yaml`,
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

**Completion:** you hold a concrete `{org}`, `{claims_repo}`, `{version}`, and
the matched path.

## Step 2 — Classify the intent

Map the request to one or more playbooks in `playbooks/`. A mutating request
always loads `lifecycle` in addition to its authoring playbook.

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

Pick the claim **kind** from the intent yourself — the client never chooses
one (`reference/reference.md` has the full kind↔intent map). Ask one
clarifying question if the intent is ambiguous.

**Completion:** you know which playbook(s) this request needs.

## Step 3 — Load and execute

Read the chosen playbook file(s) from `playbooks/` and follow them end to
end. `reference/reference.md`, `reference/fs-forge-cookbook.md`, and
`reference/gh-cookbook.md` are pulled in on demand when a playbook points at
them. Report back to the client in their own terms — repos, teams, users,
PRs — never the word "claim."

**Completion:** the change is landed — fs-forge-managed (`--commit`
dispatched and reported) or manual (PR merged, hydrated, state PR merged) —
or the question is answered, and the client has a plain-language summary.
