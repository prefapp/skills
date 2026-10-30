# fs-forge config schema

`npx @firestartr/fs-forge-cli context` reads this; the skill writes it. Location precedence: `$FS_FORGE_CONFIG`, `$XDG_CONFIG_HOME/fs-forge/config.yaml`, `~/.config/fs-forge/config.yaml`. Outside this skill folder; never commit with it.

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
| `cli_version` | no | top-level pin for `@firestartr/fs-forge-cli`, shared by all orgs; `../SKILL.md` Step 1 |

Missing file, relative path, duplicate org, old `organization: { name }` shape, or any invalid entry → `NO_CONFIG`. Never migrate old values silently.

## Setup flows

Show the whole resulting file and wait for confirmation before writing. Declining writes nothing; prompt again next run. Collapse home paths to `~/`; warn but don't block on nonexistent paths.

- **`NO_CONFIG`**:
  1. Ask for the GitHub org slug (`name`).
  2. Ask once about default repo names (`claims`, `state-github`, `state-infra`, `catalog`); collect overrides.
  3. Propose the current directory as `paths`; accept a different path.
  4. Show-before-write.
- **`NO_MATCH`** (no configured path matches current directory): list configured orgs plus "new organization". Existing org → append current directory to `paths`; new → `NO_CONFIG` steps.
- **`AMBIGUOUS_MATCH`** (two orgs claim one path, only by hand-editing): show the whole file highlighting the conflict; ask which org owns the path; remove it from the other.
