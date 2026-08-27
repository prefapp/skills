# Clone Claim Playbook

Create a new claim by copying an existing one and changing what differs, then
land it via `lifecycle`. Prefer `fs-forge clone` over hand-copying a file —
see `../reference/fs-forge-edit-clone.md` for the invocation idiom.

## Flow

### Step 1 — Identify the source and the new name

Source is `<Kind>-<source-name>` (an existing claim); `--from` below takes
only the `<source-name>` part, since `<Kind>` is already a separate argument
(short ID like `component` or the full `ComponentClaim` — both work here).
Confirm what should differ in the new one (the client rarely wants an exact
duplicate — at minimum the name changes, usually also
owner/visibility/members/etc.).

### Step 2 — Pre-check the new name

For ComponentClaim/GroupClaim/UserClaim/TFWorkspaceClaim, run
`preflight --create` on the new name (`../reference/fs-forge-preflight.md`)
before building a plan — it covers both a claims-map conflict and a
same-named resource already at the provider. Every other kind: confirm
`<Kind>-<new-name>` doesn't already exist via `../reference/fs-forge-discovery.md`'s
discovery commands instead (same pre-check `create-claim.md` runs for its
unsupported kinds).

### Step 3 — Read the source

Optional but recommended when you don't already know its fields: `edit
<Kind>-<source-name> --org={org}` with no mutating flags.

### Step 4 — Discover flags

For the kind via `create <Kind> --help --json` (same discovery step as
`create`/`edit` — never `clone --help --json`, which mixes every kind's
flags together).

### Step 5 — Dry-run

```bash
npx @firestartr/fs-forge-cli@{version} clone <Kind> --org={org} \
  --from <source-name> --name <new-name> \
  --<flag>=<value> ... \
  --diff --show-defaults
```

`TFWorkspaceClaim`/`SecretsClaim` also need
`--path claims/{...}/{new-name}.yaml` (the deterministic-path rule from
`create-claim.md` applies here too). Fix any validation errors, then check
the printed Claim diff yourself before showing it to the client — fix
both before moving on:
- **No source leakage.** `name` (claim + any provider `name`, e.g.
  `providers.github.name`) reflects `--name`, not `--from` — a source
  name leaking through anywhere is a defect, re-run with the missing
  override flag.
- **No leftover shape.** Every carried-over field the client didn't ask
  to change (`vars`, `secrets`, `sync`, provider settings, …) belongs on
  the new claim — strip the rest with `--unset <dotted.path>` or an
  override, re-running until the diff only has fields the new claim
  needs.

Only once both are clean, show the diff to the client and get approval
(`../reference/fs-forge-edit-clone.md` has the diff/defaults format).

> **Check this first:** a rejected `--commit` (uniqueness, schema, stale
> branch) — see `troubleshooting.md#fs-forge-cli-command-failures`.

### Step 6 — Re-run with `--commit`

See `../reference/fs-forge-mutation-shared.md`'s `--commit` warning (it
also covers the uniqueness check `clone --commit` runs on its own).

Array fields (e.g. `members`, `additionalRules`) come across **as-is** from the
source unless you override them; overriding replaces the whole array (see
`../reference/fs-forge-mutation-shared.md`), it doesn't merge with the
source's values.

## When to clone vs. create

For a **repo** (ComponentClaim), clone by default — even when the client
never said "like X". Both `clone --commit` and `create --commit` land the
change the same way (branch, PR, hydrate, state PR, in one shot), but
`clone`'s fields (system, owner, features, …) inherit from a known-good
existing component instead of risking an invalid guess at defaults. Pick any
component close enough in shape as `--from`; only fall back to `create-claim`
when nothing in the org is worth diffing against.

For every other kind, clone when the client wants "one like X but with Y
different" and an existing claim already has most of the desired shape —
otherwise `create-claim`'s manual flow is cheap enough to use directly.

## Manual fallback

Only when a needed override isn't reachable through `clone`'s flags: read the
source file, copy it, edit the differing fields, write the new file at its
deterministic path (`create-claim.md` has the per-kind path table), validate,
and land it via `lifecycle`'s manual flow.
