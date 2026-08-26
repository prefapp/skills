# gh Cookbook

The repeated `gh` idioms every playbook builds on. `{claims_repo}` is
`{org}/claims` from `firestartr-config.yaml`. Prefer a host-provided composite tool
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

Always write the **complete** file — a PUT replaces it wholesale. Preserve every
existing field when editing.

## Open and merge the PR

```bash
gh pr create --repo {claims_repo} --base main --head {branch} \
  --title "{title}" --body "{body}"
gh pr merge {pr} --repo {claims_repo} --squash --auto
```

If merge fails with "Base branch was modified", wait 3–5s and retry.

## Trigger hydration and wait

Each claim family has its **own** hydrate workflow — not interchangeable, and they
take different inputs. Pick by the claim you landed:

| Claim family | Workflow (💧 name) | Inputs | State repo |
|---|---|---|---|
| Component / User / Group / OrgWebhook | `GitHub claim: hydrate` | `kind` + `name` | state-github |
| Secrets | `Secrets claim: hydrate` | `name` | state-infra |
| TFWorkspace | `TFWorkspace claim: hydrate` | `name` **only** (no `kind`) | state-infra |

Workflow **IDs are per-deployment** — never hardcode them; display names carry
emoji prefixes so bare-name matching fails. List, then trigger by ID:

```bash
gh workflow list --repo {claims_repo} --all      # find the matching 💧 workflow + ID
gh workflow run {workflow-id} --repo {claims_repo} \
  --field name={claim-name}                        # add --field kind={Kind} for GitHub claims ONLY
sleep 30
gh run list --repo {claims_repo} --workflow {workflow-id} --limit 1 \
  --json databaseId,status,conclusion
```

Passing an input the workflow doesn't declare (e.g. `kind` to TFWorkspace hydrate)
fails HTTP 422. Proceed only when `conclusion` is `success`.

> **Check this first:** a run that didn't reach `success` — see
> `../playbooks/troubleshooting.md#hydrate-workflow-dispatchexecution`.

## Discover Terraform modules (TFWorkspaceClaim)

Commands for `reference.md`'s Terraform modules section, if sourcing
`remote` from Prefapp's own `prefapp/tfm` (public; discover, don't guess —
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

Hydration opens a PR on the target **state repo** — `state-github` for GitHub
claims, `state-infra` for Secrets/TFWorkspace. GitHub-claim hydrate auto-merges it;
Secrets/TFWorkspace hydrate default `automerge: false`, so you **must** merge it.

```bash
gh pr list --repo {org}/{state-repo} --limit 5
gh pr merge {pr} --repo {org}/{state-repo} --squash
```
