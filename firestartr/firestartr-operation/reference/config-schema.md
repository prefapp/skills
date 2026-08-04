# `firestartr-config.yaml` schema

Per-install, git-ignored. Template: `../firestartr-config.example.yaml`.

| Field | Required | Meaning |
|---|---|---|
| `organizations` | yes | top-level list, one entry per GitHub org this install can target |
| `organizations[].name` | yes | literal GitHub org slug, substituted for `{org}` |
| `organizations[].paths` | yes | one or more local dirs resolving to this org (`~`-form or absolute); two dirs (e.g. a clone and a fork) may point at the same org |
| `organizations[].claims_repo` | no | default `{name}/claims` |
| `organizations[].state_github_repo` | no | default `{name}/state-github` |
| `organizations[].state_infra_repo` | no | default `{name}/state-infra` |
| `organizations[].catalog_repo` | no | default `{name}/catalog` |
| `cli_version` | no | single top-level key, shared across every organization (not per-org); unset resolves the latest stable `@firestartr/fs-forge-cli` |

The old single-`organization: { name }` shape is not supported — treat a file
in that shape as unset (`SKILL.md` Step 1).
