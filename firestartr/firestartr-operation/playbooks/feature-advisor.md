# Feature Advisor

Match a user's desired repo capability to an available platform feature,
without requiring them to know features exist or what they're called.

## Triggers

1. **Create/clone flows.** Before showing the plan for approval, check
   whether the user's description implies features they haven't explicitly
   requested; suggest them first.
2. **Standalone.** The user describes a capability (e.g. "I want Docker
   CI/CD") without naming a feature.

## Flow

1. **Discover:** `npx @firestartr/fs-forge-cli@{version} features discover --json`
   — full catalog with latest versions.
2. **Match** the catalog to the user's stated need using each feature's
   purpose. Fetch both READMEs to compare if uncertain between two
   candidates.
3. **Fetch details** for the best match:
   ```bash
   npx @firestartr/fs-forge-cli@{version} features discover --readme <feature-name>
   npx @firestartr/fs-forge-cli@{version} features discover --schema <feature-name>@<feature-version>
   ```
   README → what it does. Schema → configurable `args` (types, defaults).
4. **Present:** name + latest version, one sentence on why it fits (from the
   README), and the configurable args from the schema.
   > The **build_and_dispatch_docker_images** feature (v5.5.0) provides
   > Docker CI/CD — snapshot, pre-release, release builds, auto-dispatch to
   > state repos — matching your need for Docker builds.
   >
   > Configurable args: `auth_strategy` (default: azure_oidc),
   > `build_snapshots_branch` (default: repo's default branch), ...
   >
   > Want me to add this feature?
5. **Accepted** → fold into the create/clone plan (`--feature` inline flag or
   a `features add` step after landing), or hand off to `edit-claim` +
   `lifecycle` if standalone. **Declined** → move on, don't re-suggest it
   this session.
6. **Configure args** (if accepted): ask for values the schema doesn't
   default well for the user's context, one at a time with a recommended
   default. `features add --name <feature> --help --json` gives full
   `args.*` FlagSpecs under `.flags[]`. Then follow the Rules in `SKILL.md`
   (show-plan → approve → execute → show-result).

## Multiple features

Suggest one at a time, most relevant first — each its own accept/decline.

## Boundaries

- At most 3 suggestions per create/clone flow.
- Only suggest a feature whose README clearly matches the stated intent —
  never speculatively.
- Never add a feature without explicit approval.
