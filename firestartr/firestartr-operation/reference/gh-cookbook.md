# gh Cookbook

The repeated `gh` idioms every playbook builds on. `{claims_repo}` is
`{org}/claims` from `organization.yaml`. Prefer a host-provided composite tool
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

Always pass **both** `kind` and `name` — a hydration missing either silently does
nothing.

```bash
gh workflow run "GitHub claim: hydrate" --repo {claims_repo} \
  --field kind={ClaimKind} --field name={claim-name}
sleep 30
gh run list --repo {claims_repo} --limit 3
gh run view {run-id} --repo {claims_repo} --json status,conclusion
```

Workflow **display names carry emoji prefixes** (e.g. `💧 GitHub claim: hydrate`,
`🛑 GitHub claim: delete`), so the bare name fails to match. List them with
`gh workflow list --repo {claims_repo} --all` and trigger by **workflow ID**
(hydrate = `250797173`) or the exact emoji-prefixed name.

Proceed only when `conclusion` is `success`.

## Merge the resulting state PR

Hydration opens a PR (branch `automated/CRs-update`) on the target state repo.

```bash
gh pr list --repo {org}/state-github --limit 5
gh pr merge {pr} --repo {org}/state-github --squash
```
