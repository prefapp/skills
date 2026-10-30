# gh Cookbook

The repeated `gh` idioms every playbook builds on. `{claims_repo}` comes from
`SKILL.md` Step 1. Prefer a host-provided composite tool
when the playbook names one; otherwise use these raw commands.

## Read a file (decoded)

```bash
gh api repos/{claims_repo}/contents/{path} --jq '.content' | base64 -d
```

Get a file's blob SHA (needed to update it):

```bash
gh api repos/{claims_repo}/contents/{path} --jq '.sha'
```

## Branch from main

```bash
BASE_SHA=$(gh api repos/{claims_repo}/git/ref/heads/main --jq '.object.sha')
gh api repos/{claims_repo}/git/refs -f ref="refs/heads/{branch}" -f sha="$BASE_SHA"
```

## Create or update a file on the branch

Build the YAML, base64-encode it, PUT it. Omit `-f sha=` when creating a new file;
include it (the current blob SHA) when updating an existing one.

```bash
CONTENT=$(cat <<'EOF' | base64 -w0
{full yaml body}
EOF
)
gh api repos/{claims_repo}/contents/{path} -X PUT \
  -f message="{message}" \
  -f content="$CONTENT" \
  -f branch="{branch}" \
  -f sha="$FILE_SHA"     # updates only
```

Always write the **complete** file: a PUT replaces it wholesale. Preserve every
existing field when editing.

## Open and merge the PR

```bash
gh pr create --repo {claims_repo} --base main --head {branch} \
  --title "{title}" --body "{body}"
gh pr merge {pr} --repo {claims_repo} --squash --auto
```

If merge fails with "Base branch was modified", wait 3–5s and retry.

## Trigger hydration and wait

Each kind has its **own** hydrate workflow, and workflows take different
inputs. Read them from the registry:

```bash
npx @firestartr/fs-forge-cli@{version} kinds show <id> --json   # hydration.{workflow,key,inputs}, stateRepo
```

`hydration: null` means nothing to hydrate. Dispatch by `hydration.workflow`, a
file name: display names carry emoji prefixes, so never match on them.
`hydration.key` is the input that takes the claim name; `hydration.inputs` lists
every input the workflow accepts.

```bash
gh workflow run {hydration.workflow} --repo {claims_repo} \
  --field {hydration.key}={claim-name}      # add --field kind={Kind} when hydration.inputs has kind
sleep 30
gh run list --repo {claims_repo} --workflow {hydration.workflow} --limit 1 \
  --json databaseId,status,conclusion
```

Passing an input the workflow doesn't declare fails HTTP 422. Proceed only when
`conclusion` is `success`.

> **Check this first:** a run that didn't reach `success`; see
> `../playbooks/troubleshooting.md#hydrate-workflow-dispatchexecution`.

## Discover Terraform modules (TFWorkspaceClaim)

Commands for `reference.md`'s Terraform modules section, if sourcing
`remote` from Prefapp's own `prefapp/tfm` (public; discover, don't guess:
`inline` needs none of this):

```bash
# List available modules (dirs under modules/)
gh api repos/prefapp/tfm/contents/modules --jq '.[] | select(.type=="dir") | .name'

# Inspect a module's inputs before authoring values
gh api repos/prefapp/tfm/contents/modules/{module}/variables.tf --jq '.content' | base64 -d

# Latest release tag for a module (tags are per-module: {module}-vX.Y.Z)
gh api repos/prefapp/tfm/tags --paginate --jq '.[].name' | grep '^{module}-v' | head -1
```

Build the `module` field as:
`git::https://github.com/prefapp/tfm.git//modules/{module}?ref={module}-vX.Y.Z`

## Merge the resulting state PR

Hydration opens a PR on the kind's **state repo** (`stateRepo` in `kinds show`).
GitHub-claim hydrate auto-merges it; Secrets and TFWorkspace default to
`automerge: false`, so you **must** merge it.

```bash
gh pr list --repo {org}/{state-repo} --limit 5
gh pr merge {pr} --repo {org}/{state-repo} --squash
```
