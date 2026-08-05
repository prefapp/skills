# fs-forge Edit & Clone Reference

`edit`, `clone`, and a committing `create` are the network-bound fs-forge
commands — they read and write the claims repo directly over the GitHub API.
Sibling of `fs-forge-cookbook.md`; `{org}`/`{version}` come from
`firestartr-config.yaml`.

All need:

- `GITHUB_TOKEN` in the environment — `fs-forge` reads this env var directly,
  it doesn't share `gh`'s internal auth store. Populate it from `gh` once per
  session if it isn't already set: `export GITHUB_TOKEN=$(gh auth token)`.
- `--org={org}` on every invocation — the control-plane flag
  (`fs-forge-mutation-shared.md`'s `{org}` passthrough); always pass it
  explicitly rather than relying on an env var default.

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
target kind and reuse the returned flag `name`s (`fs-forge-mutation-shared.md`).
`edit --help --json` mixes every kind's flags together since the kind isn't
known until the reference argument is parsed — don't use it for discovery.

Always dry-run before committing:

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... \
  --unset <dotted.path> ... \
  --diff
```

`--diff` prints a one-hop **relation diff** to stderr — the same tree
renderer as `discovery map` (`fs-forge-discovery.md`), scoped to the edited
claim and its direct references, with `+`/`-`/`~` markers for added/removed/
changed nodes and edges (not a plain field-by-field YAML diff). Add `--json`
for the structured diff (`{"nodes": [...], "edges": [...]}` with a `status`
on each changed entry) or `--ascii` for bracket icons instead of emoji.
Dangling references (pointing at a claim that doesn't exist) are flagged
using the already-loaded claims-map.

Add `--show-defaults` **unconditionally, every time** — it implies `--diff`
and fetches the same repo-level claim defaults `edit`/`clone` already apply
automatically (`fs-forge-mutation-shared.md`'s "Claim defaults"), rendering
them as a separate "Defaults applied:" section after the client's own field
changes (or nothing, when there's nothing to add). Combined with `--json`,
the structured shape becomes `{"changes": [...], "defaults": {...}}` instead
of the plain `{"nodes"/"edges"}` graph — `--diff --json` alone, without
`--show-defaults`, keeps that flat shape untouched. Show the printed diff to
the client and get approval. Only then re-run the same command with
`--commit` appended (`fs-forge-mutation-shared.md`'s `--commit` warning):

```bash
npx @firestartr/fs-forge-cli@{version} edit <Kind>-<name> --org={org} \
  --<flag>=<value> ... --commit
```

If the field you need isn't exposed by `--help --json` (e.g. editing one
element inside an array of objects without recomputing the whole array), fall
back to the manual `gh-cookbook.md` read → edit → write flow.

## Clone an existing claim

```bash
npx @firestartr/fs-forge-cli@{version} clone <Kind> --org={org} \
  --from <source-name> --name <new-name> \
  --<flag>=<value> ... \
  --diff
```

`<Kind>` here takes either the short ID (`component`) or the full name
(`ComponentClaim`) — unlike `edit`'s `<Kind>-<name>` reference, which still
requires the full name. `--name` must differ from `--from`.
`TFWorkspaceClaim`/`SecretsClaim` also need
`--path claims/{...}/{new-name}.yaml` (same rule as `create`'s deterministic
path). Same dry-run → approve → `--commit` sequence and the same `--commit`
warning as `edit` above (`fs-forge-mutation-shared.md`); `--diff`/`--json`/
`--ascii`/`--show-defaults` behave the same as `edit`'s relation diff too
(compared against nothing, since the clone target is new). See
`../playbooks/clone-claim.md` for the full flow.
