# fs-forge Cookbook

The repeated `fs-forge` idioms every mutating playbook builds on. `{org}` is
resolved from `organization.yaml` before any of these run.

## Invocation

```bash
npx --package=@firestartr/fs-forge-cli@0.1.0 fs-forge <args>
# or, when fs-forge is on PATH:
fs-forge <args>
```

**Hard dependency — no fallback.** If fs-forge is absent (the command fails),
stop immediately and tell the user:

> `fs-forge` is required but not installed.
> Install it with `npm install -g @firestartr/fs-forge-cli@0.1.0` or use `npx --package=@firestartr/fs-forge-cli@0.1.0 fs-forge`.
> Do not proceed without it.

Never hand-author a claim body when fs-forge is unavailable.

## Discover a kind's flags at runtime

```bash
fs-forge create <Kind> --help --json
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

The `{org}` value resolved from `organization.yaml` must be passed to the flag
whose FlagSpec `path` equals the kind's org field.

- Most kinds: `providers.github.org`
- OrgWebhookClaim: `providers.github.orgName`

To find the right flag at runtime:

```bash
fs-forge create <Kind> --help --json \
  | jq -r '.[] | select(.path == "providers.github.org" or .path == "providers.github.orgName") | "--\(.name)=\("{org}")"'
```

Pass the resulting `--<flag>=<value>` to `fs-forge create`.

## Create a claim file

```bash
fs-forge create <Kind> \
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
fs-forge validate -f {claim-file}
```

fs-forge validates schema, types, and enum constraints. It does **not** check
cross-claim references, duplicates, or naming rules — those are the skill's
responsibility (see the validation split in `reference.md`).
