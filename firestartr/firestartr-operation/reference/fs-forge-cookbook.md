# fs-forge Cookbook

The repeated `fs-forge` idioms every mutating playbook builds on. `{org}` and
`{version}` are resolved from `firestartr-config.yaml` before any of these run.

## Invocation

```bash
npx @firestartr/fs-forge-cli@{version} <args>
```

**Hard dependency — no fallback.** If the invocation fails, stop immediately
and tell the user:

> `fs-forge` could not be run via `npx`.
> Ensure `npx` is available (Node >= 18) and that you have network access.
> Do not proceed without it.

Never hand-author a claim body when fs-forge is unavailable.

## Discover a kind's flags at runtime

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json
```

This returns an array of FlagSpec objects. Each has:

| Field | Meaning |
|---|---|
| `name` | Long CLI flag name without the leading `--`; pass it as `--<name>` |
| `path` | Dotted path of the claim field this flag sets (e.g. `providers.github.org`) |
| `type` | Value type (`string`, `boolean`, `number`, …) |
| `required` | Whether the flag must be provided |
| `enumValues` | Allowed values (present when constrained) |
| `defaultValue` | fs-forge's own default (if any) |
| `multiple` | Whether the flag accepts multiple values |

**Never hardcode a CLI flag name.** Derive flag names from the FlagSpec returned
by `--help --json`. For field paths, use the returned `path`; the two stable org
field paths documented below are the deliberate exception used to identify the
org flag.

## `{org}` passthrough

The discovery example below uses `jq` to parse FlagSpec JSON; install `jq` or use
an equivalent JSON parser when following it.

The `{org}` value resolved from `firestartr-config.yaml` must be passed to the flag
whose FlagSpec `path` equals the kind's org field.

- Most kinds: `providers.github.org`
- OrgWebhookClaim: `providers.github.orgName`

To find the right flag at runtime:

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json \
  | jq -r '.[] | select(.path == "providers.github.org" or .path == "providers.github.orgName") | "--\(.name)=\("{org}")"'
```

Pass the resulting `--<flag>=<value>` to
`npx @firestartr/fs-forge-cli@{version} create`.

## Create a claim file

```bash
npx @firestartr/fs-forge-cli@{version} create <Kind> \
  --<org-flag>={org} \
  --<field>=<value> \
  ...
  -o {output-path}
```

Flags and their names come from the FlagSpec discovery step above — never
constructed by hand. The skill sets only the flags it knows values for;
required flags with no available value are gathered from the client first.

## Validate a claim file (syntactic only)

```bash
npx @firestartr/fs-forge-cli@{version} validate -f {claim-file}
```

fs-forge validates schema, types, and enum constraints. It does **not** check
cross-claim references, duplicates, or naming rules — those are the skill's
responsibility (see the validation split in `reference.md`).

## Claims-repo commands: read, edit, clone (network-bound)

Unlike `create` (local, deterministic, no network), `edit` and `clone` read and
write the claims repo directly over the GitHub API. Both need:

- `GITHUB_TOKEN` in the environment — separate from `gh`'s own auth token;
  export it once per session if it isn't already set:
  `export GITHUB_TOKEN=$(gh auth token)`.
- `--org={org}` on every invocation — the GitHub org whose `claims` repo to
  talk to. This is a different flag from the claim's own
  `providers.github.org` schema field (only relevant if you're deliberately
  changing that field); always pass `--org={org}` explicitly rather than
  relying on `FSCRT_ORG` being set.

Claims are addressed as `<Kind>-<name>` (e.g. `ComponentClaim-my-repo`) — the
same key the claims-map uses. Use this notation everywhere you need to name an
existing claim.

### Read an existing claim

`edit` with no mutating flags is the preferred way to read a claim — it goes
through the claims-map instead of hand-rolling a `gh api` path lookup:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org}
```

Prints the current claim YAML to stdout. Fall back to `gh-cookbook.md`'s "Read
a file" only if the claims-map lookup itself is unavailable.

### Edit an existing claim

Mutation flags come from the same discovery step as `create` — run
`npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json` for the
target kind and reuse the returned flag `name`s. (`edit --help --json` mixes
every kind's flags together since the kind isn't known until the reference
argument is parsed — don't use it for discovery.)

Always dry-run before committing:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... \
  --unset <dotted.path> ... \
  --diff
```

Show the printed diff to the client and get approval. Only then re-run the
same command with `--commit` appended:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... --commit
```

> **Warning — `--commit` does not just commit.** It creates the branch,
> commits the claim, and dispatches `provision-claim.yaml`, which opens the
> PR, waits for verify, merges it, **dispatches and waits for hydration**, and
> merges the resulting wet PR — all on its own, with no further input. Passing
> `--commit` provisions **and hydrates** the claim end-to-end in one shot.
> Never pass it before the client has approved the diff, and never follow it
> with a manual hydrate step — it already happened. If the client asks for
> status, check the dispatched run; only trigger a *separate* manual hydrate
> (`gh-cookbook.md`) if they explicitly ask for one.

**Array flags replace the whole array** — `--members=a --members=b` sets
`members` to exactly `[a, b]`, it does not append or remove one entry. Read
the current value first (see "Read an existing claim" above), compute the
full desired list, then pass it whole.

If the field you need isn't exposed by `--help --json` (e.g. editing one
element inside an array of objects without recomputing the whole array), fall
back to the manual `gh-cookbook.md` read → edit → write flow.

### Clone an existing claim

```bash
npx @firestartr/fs-forge-cli@{version} clone <Kind> --org={org} \
  --from <source-name> --name <new-name> \
  --<flag>=<value> ... \
  --diff
```

`--name` must differ from `--from`. `TFWorkspaceClaim`/`SecretsClaim` also
need `--path claims/{...}/{new-name}.yaml` (same rule as `create`'s
deterministic path). Same dry-run → approve → `--commit` sequence and the same
`--commit` warning as `edit` above. `clone --commit` additionally errors if
`<Kind>-<new-name>` already exists — no separate uniqueness check needed. See
`../playbooks/clone-claim.md` for the full flow.
