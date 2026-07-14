# fscli Cookbook

The repeated `fscli` idioms every mutating playbook builds on. `{org}` is
resolved from `organization.yaml` before any of these run.

## Invocation

```bash
npx @prefapp/fscli@<pin> <args>
# or, when fscli is on PATH:
fscli <args>
```

`<pin>` is a fixed version tag set when fscli first ships. Until then the
placeholder is intentional — do not substitute a concrete version.

**Hard dependency — no fallback.** If fscli is absent (the command fails),
stop immediately and tell the user:

> `fscli` is required but not installed.
> Install it with `npm install -g @prefapp/fscli@<pin>` or use `npx @prefapp/fscli@<pin>`.
> Do not proceed without it.

Never hand-author a claim body when fscli is unavailable.

## Discover a kind's flags at runtime

```bash
fscli create <Kind> --help --json
```

This returns an array of FlagSpec objects. Each has:

| Field | Meaning |
|---|---|
| `name` | CLI flag name used to pass the value |
| `path` | Dotted path of the claim field this flag sets (e.g. `providers.github.org`) |
| `type` | Value type (`string`, `boolean`, `number`, …) |
| `required` | Whether the flag must be provided |
| `enumValues` | Allowed values (present when constrained) |
| `defaultValue` | fscli's own default (if any) |
| `multiple` | Whether the flag accepts multiple values |

**Never hardcode a CLI flag name.** Derive flag names from the FlagSpec returned
by `--help --json`. For field paths, use the returned `path`; the two stable org
field paths documented below are the deliberate exception used to identify the
org flag.

## `{org}` passthrough

The `{org}` value resolved from `organization.yaml` must be passed to the flag
whose FlagSpec `path` equals the kind's org field.

- Most kinds: `providers.github.org`
- OrgWebhookClaim: `providers.github.orgName`

To find the right flag at runtime:

```bash
fscli create <Kind> --help --json \
  | jq -r '.[] | select(.path == "providers.github.org" or .path == "providers.github.orgName") | "--\(.name)=\("{org}")"'
```

Pass the resulting `--<flag>=<value>` to `fscli create`.

## Create a claim file

```bash
fscli create <Kind> \
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
fscli validate -f {claim-file}
```

fscli validates schema, types, and enum constraints. It does **not** check
cross-claim references, duplicates, or naming rules — those are the skill's
responsibility (see the validation split in `reference.md`).
