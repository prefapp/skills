# fs-forge Edit Reference

Use `--org={org}` explicitly on every call (`fs-forge-mutation-shared.md`); address claims as `<Kind>-<name>`.

## Read an existing claim

`edit <Kind>-<name> --org={org}` with no mutating flags is the preferred way
to read a claim: it goes through the claims-map instead of hand-rolling a
`gh api` path lookup, and prints the current claim YAML to stdout. Fall back
to `gh-cookbook.md`'s "Read a file" only if the claims-map lookup itself is
unavailable.

## Edit an existing claim

Mutation flags come from the same discovery step as `create`: run
`npx @firestartr/fs-forge-cli@{version} create <kind> --help --json` for the
target kind and reuse the returned flag `path`s (`fs-forge-mutation-shared.md`).
`edit --help --json` mixes every kind's flags together since the kind isn't
known until the reference argument is parsed: don't use it for discovery.

Always dry-run before committing:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... \
  --unset <dotted.path> ... \
  --diff --show-defaults
```

`--diff` prints a Claim diff to stderr, not a relation tree. Always add `--show-defaults`: the after side includes repo defaults (`fs-forge-mutation-shared.md`). With `--json`, see `schema show MutationDiff` (`fs-forge-cookbook.md`); without `--show-defaults`, `--diff --json` emits a flat `ClaimDiff[]` of `{path, before, after}`. Show the diff and get approval before re-running with `--commit` (`fs-forge-mutation-shared.md`):

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... --commit
```

If the field you need isn't exposed by `--help --json` (e.g. editing one
element inside an array of objects without recomputing the whole array), fall
back to the manual `gh-cookbook.md` read → edit → write flow.
