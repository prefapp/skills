# Feature Advisor

Proactively match a user's desired repo capability to an available platform
feature — without requiring them to know that features exist or what they're
called.

## When this playbook triggers

1. **During create/clone flows.** After the basic repo plan is built but before
   showing it for approval, check whether the user's description implies
   features they haven't explicitly requested. If it does, suggest them before
   finalizing the plan.
2. **Standalone.** The user describes something they want in a repo (e.g., "I
   want Docker CI/CD", "I need automated releases") without naming a specific
   feature.

## Flow

### 1. Discover available features

```bash
npx @firestartr/fs-forge-cli@{version} features discover --json
```

This returns the full catalog of available features with their latest versions.

### 2. Match intent to feature

Using the feature catalog and your knowledge of each feature's purpose, identify
the best candidate that solves the user's stated need. If uncertain between two
candidates, fetch both READMEs to compare.

### 3. Fetch feature details

For the best-match feature:

```bash
npx @firestartr/fs-forge-cli@{version} features discover --readme <feature-name>
npx @firestartr/fs-forge-cli@{version} features discover --schema <feature-name>@<version>
```

The README explains what the feature does. The schema shows its configurable
`args` fields (types, defaults, descriptions).

### 4. Present the suggestion

Show the user:
- The feature name and latest version.
- One sentence explaining why it fits their stated need (derived from the README).
- A summary of the configurable args from the schema (fields, defaults, what
  they control).

Example:

> The **build_and_dispatch_docker_images** feature (v5.5.0) provides Docker
> CI/CD pipelines including snapshot, pre-release, and release builds with
> automatic dispatch to state repos — which matches your need for Docker builds.
>
> Configurable args: `auth_strategy` (default: azure_oidc), `build_snapshots_branch` (default: repo's default branch), ...
>
> Want me to add this feature?

### 5. Handle the response

- **Accepted** → If inside a create/clone flow, fold the feature into the plan
  (using `--feature` inline flag or by adding a `features add` step after the
  repo lands). If standalone, hand off to `edit-claim` + `lifecycle` to add the
  feature to the existing repo.
- **Declined** → Acknowledge and move on. Do not suggest the same feature again
  in this session.

### 6. Configure args (if accepted)

If the feature has required args or args where the default doesn't fit the user's
context, ask for the values — one at a time, each with a recommended default
derived from the schema. Use `features add --name <feature> --help --json` for
full FlagSpec discovery of `args.*` flags.

Then proceed with the standard show-plan → approve → execute → show-result cycle
per the Rules in SKILL.md.

## Multiple features

If the user's description implies more than one feature, suggest them one at a
time in order of relevance. Each gets its own accept/decline decision.

## Proactive suggestion boundaries

- Suggest at most **3 features** per create/clone flow to avoid overwhelming the
  user.
- Only suggest features whose README clearly matches the user's stated intent or
  repo description. Do not suggest features speculatively.
- Never add a feature without explicit user approval.
