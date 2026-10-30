# fs-forge Mutation Shared Reference

**Addressing:** `edit` takes one argument `<Kind>-<name>` (e.g. `ComponentClaim-my-repo`), never `edit <Kind> <name>`. `delete` takes two (`delete <Kind> <name>`). `create` takes the short ID from `kinds --json` (`component`, not `ComponentClaim`).

## Discover a kind's flags at runtime

```bash
npx @firestartr/fs-forge-cli@{version} create <kind> --help --json
```

Read `.flags[]` and `relationships` from the returned `CommandHelpJson` (schema: `npx @firestartr/fs-forge-cli@{version} schema show CommandHelpJson`). Prefer the command's own description, translated to client terms. **Never hardcode schema-field flags**: pass the discovered `path` as `--<path>=<value>`. Repeated `multiple` flags replace the whole array; read and rebuild it first.

## `{org}` passthrough: two distinct flags

Control-plane `--org={org}` selects the claims repo; it does not set the claim resource's org. For `create` or `edit`, also pass `--<orgField>={org}` when the kind's `orgField` is non-null. Discover that exact path:

```bash
npx @firestartr/fs-forge-cli@{version} kinds show <kind> --json | jq -r '.orgField'
```

## The `--commit` warning

`create`/`edit --commit` creates a branch, commits the claim and dispatches `provision-claim.yaml`, which opens the PR, waits for verify, merges, dispatches and waits for hydration when applicable, and merges the wet PR. Never use before client approval or follow with manual hydration. For status, check the dispatched run; trigger a separate manual hydrate (`gh-cookbook.md`) only if explicitly requested.

A `--commit` that fails before dispatch is a CLI error: fix the reported problem and re-run. On `Branch already exists`, an
earlier attempt left `fs-forge/{kind}-{name}` behind: check that no open PR or
dispatched run uses it, then ask the client before deleting it and re-running.
Once the provision run was dispatched (e.g. `Wet PR checks failed`), never
re-run `--commit` blindly: inspect that run and the wet PR first.

> **Check this first:** the exact error text and exit code; see
> `diagnostics.md#fs-forge-cli-error-shapes`.

## Claim defaults (`claims_defaults.yaml` in the claims repo)

`edit` fetches repo-level defaults and applies them **after** client changes, filling only unset fields, never overriding intent. It validates the final defaulted document; `--commit` publishes it schema-valid. Preview filled fields with `--show-defaults` (`fs-forge-edit.md`).

**`create` never applies defaults**, with or without `--commit`; output contains only flag-described fields. Preview additions with the read-only commands below and tell the client "the platform will also apply: …", distinct from the file.

```bash
npx @firestartr/fs-forge-cli@{version} defaults apply <Kind>-<name> --org={org}
npx @firestartr/fs-forge-cli@{version} defaults apply -f {claim-file} --org={org}
npx @firestartr/fs-forge-cli@{version} defaults show <kind> --org={org}
npx @firestartr/fs-forge-cli@{version} defaults list --org={org} [--json]
```

`apply` does not validate or write; the local file must have a `kind` field. Command flags: `--help --json`.

TFWorkspaceClaim's `providers.terraform.sync` is an **all-or-nothing block** (`reference.md` Terraform policy): set any `sync.*` and the whole block stays as set; set none and the whole default block applies. Never top up a partial block.

Ambiguous defaults location (multiple candidates, none conventional) hard-fails the three preview commands with candidates; `edit` warns on stderr and applies no defaults, never partial/best-guess. Network/auth fetch failures always hard-fail, never silently count as no defaults.
