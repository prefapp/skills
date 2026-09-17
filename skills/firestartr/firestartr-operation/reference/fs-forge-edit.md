# fs-forge Edit Reference

`edit` and a committing `create` are the network-bound fs-forge
commands — they read and write the claims repo directly over the GitHub API.
Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

All need `--org={org}` on every invocation — the control-plane flag
(`fs-forge-mutation-shared.md`'s `{org}` passthrough); always pass it
explicitly rather than relying on an env var default. Auth is the
`GITHUB_TOKEN` inline prefix from `../SKILL.md`'s Common rules — every
command below assumes it.

Claims are addressed as `<Kind>-<name>` (e.g. `ComponentClaim-my-repo`) — the
same key the claims-map uses. Use this notation everywhere you need to name an
existing claim.

## Read an existing claim

`edit <Kind>-<name> --org={org}` with no mutating flags is the preferred way
to read a claim — it goes through the claims-map instead of hand-rolling a
`gh api` path lookup, and prints the current claim YAML to stdout. Fall back
to `gh-cookbook.md`'s "Read a file" only if the claims-map lookup itself is
unavailable.

## Edit an existing claim

Mutation flags come from the same discovery step as `create` — run
`npx @firestartr/fs-forge-cli@{version} create <Kind> --help --json` for the
target kind and reuse the returned flag `path`s (`fs-forge-mutation-shared.md`).
`edit --help --json` mixes every kind's flags together since the kind isn't
known until the reference argument is parsed — don't use it for discovery.

Always dry-run before committing:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... \
  --unset <dotted.path> ... \
  --diff
```

`--diff` prints a **Claim diff** to stderr (not a relation/topology tree —
that's `discovery map`'s job, `fs-forge-discovery.md`). Add `--json` for the
structured form: a flat `ClaimDiff[]` array — `{path, before, after}` per
changed field; no separate published schema of its own.

Add `--show-defaults` **unconditionally, every time** — it implies `--diff`
and fetches the same repo-level claim defaults `edit` already applies
automatically (`fs-forge-mutation-shared.md`'s "Claim defaults"), widening
the diff's "after" side to the fully-defaulted claim: defaults show up as
ordinary `+` lines alongside the client's own field changes. Combined with
`--json`, the structured shape becomes the published **`MutationDiff`**
contract — `{"changes": [...], "defaults": {...}}`, same `{path, before,
after}` items as the flat array plus the defaulted paths (schema: `schema
show MutationDiff`, `fs-forge-cookbook.md`) — `--diff --json` alone, without
`--show-defaults`, keeps the flat `ClaimDiff[]` shape untouched. Show the
printed diff to the client and get approval. Only then re-run the same
command with `--commit` appended (`fs-forge-mutation-shared.md`'s `--commit`
warning):

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... --commit
```

If the field you need isn't exposed by `--help --json` (e.g. editing one
element inside an array of objects without recomputing the whole array), fall
back to the manual `gh-cookbook.md` read → edit → write flow.
