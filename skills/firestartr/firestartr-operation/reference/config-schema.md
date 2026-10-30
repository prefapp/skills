# fs-forge config schema

Read by `npx @firestartr/fs-forge-cli context` (`SKILL.md` Step 1); the skill
writes it through the setup flows below. Location, first set wins: `$FS_FORGE_CONFIG`, then
`$XDG_CONFIG_HOME/fs-forge/config.yaml`, then `~/.config/fs-forge/config.yaml`.
It lives outside this skill folder, so it is never committed with it.

```yaml
organizations:
  - name: prefapp-demo
    paths:
      - ~/work/prefapp-demo
      - ~/work/prefapp-demo-fork
    claims_repo: claims
cli_version: 2.0.1
```

| Field | Required | Meaning |
|---|---|---|
| `organizations[].name` | yes | GitHub org slug, substituted for `{org}` |
| `organizations[].paths` | yes | absolute or `~/` dirs; a clone and a fork may both name one org |
| `organizations[].claims_repo` | no | default `claims`; bare name is in `{org}`, or `owner/repo` |
| `organizations[].state_github_repo` | no | default `state-github` |
| `organizations[].state_infra_repo` | no | default `state-infra` |
| `organizations[].catalog_repo` | no | default `catalog` |
| `cli_version` | no | top-level pin for `@firestartr/fs-forge-cli`, shared by all orgs; `SKILL.md` Step 1 |

Any invalid entry makes the whole file unusable: a missing file, a relative
path, a duplicate org name, or the old `organization: { name }` shape. The CLI
then returns `NO_CONFIG`. Never migrate old values silently.

## Setup flows

Show-before-write: display the whole resulting file and wait for confirmation
before writing. Declining writes nothing; the prompt reappears next run.
Collapse paths under the home directory to `~/`. Warn, don't block, if a path
doesn't exist yet.

- **`NO_CONFIG`**:
  1. Ask for the GitHub org slug (`name`).
  2. Ask once whether the repos use the default names (`claims`, `state-github`,
     `state-infra`, `catalog`); collect overrides for any that differ.
  3. Propose the current directory as the `paths` entry; take a different
     path if the client gives one.
  4. Show-before-write.
- **`NO_MATCH`** (the current directory matches no configured path): list the
  configured org names plus "new organization". Existing org → append the
  current directory to its `paths`. "New organization" → the `NO_CONFIG` steps.
- **`AMBIGUOUS_MATCH`** (two orgs claim one path; only by hand-editing): show
  the whole file with the conflict highlighted; ask which org should own the
  path; remove it from the other entry.
