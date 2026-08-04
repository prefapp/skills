# 🔥 Firestartr Operation

Firestartr is Prefapp's platform layer that manages your GitHub org's repos,
teams, and users as declarative claims. This skill is the single entry point
for operating a Prefapp-managed Firestartr platform: describe what you want in
plain language, and it turns that into the right platform change, executed
safely. You never need to know how the platform is structured internally — you
talk repos, teams, and users; the skill never talks claims.

## ✅ Prerequisites

- 🏗️ A **bootstrapped Firestartr organization** — Prefapp sets this up for you.
- 🟢 **Node ≥ 18** — the CLI (`@firestartr/fs-forge-cli`) runs via `npx`;
  nothing to install globally.
- 🐙 **`gh` CLI**, authenticated (`gh auth login`) — used for the flows the
  CLI doesn't cover, and as the token source below.
- 🔑 **`GITHUB_TOKEN`** in the environment — the CLI reads it directly.
  Populate it once per session: `export GITHUB_TOKEN=$(gh auth token)`

## 🤖 Install a harness

The skill runs inside an agent harness. If you don't have one yet, pick either:

- **[OpenCode](https://opencode.ai)** — install with
  `curl -fsSL https://opencode.ai/install | bash`
  ([docs](https://opencode.ai/docs/))
- **[Pi](https://pi.dev)** — install with
  `curl -fsSL https://pi.dev/install.sh | sh`
  ([docs](https://pi.dev/docs/latest))

Both discover skills from `~/.agents/skills/`, which is where the installer
links this skill. Claude Code is also supported via `~/.claude/skills/`.

## 📦 Install

From the root of the `skills` repo:

```sh
./install.sh --fs
```

This symlinks the skill into your agent harness(es) under the
`prefapp-firestartr` namespace. See the
[root README](../../README.md) for per-harness discovery details. `git pull`
keeps it up to date automatically.

## 🚀 First run

Invoke `/firestartr-operation` (or explicitly ask your agent to use the
`firestartr-operation` skill), then just describe what you want.

On first run the skill asks for your organization's GitHub org slug and
proposes your current directory as its `paths` entry, then writes a
git-ignored `firestartr-config.yaml` beside `SKILL.md` — nothing
client-specific is ever committed. The whole file is shown to you before it's
written. Subsequent runs from that folder skip the question; running the
skill from a folder it doesn't recognize offers to attach it to an existing
organization or create a new one, so you can work across several
Firestartr-managed platforms from one install. A missing, empty, or
unrecognized-shape config — including the old single-organization format —
is never migrated or carried forward; the skill treats it as unset and walks
you through setup fresh. To set or fix the config yourself, copy
`firestartr-config.example.yaml` to `firestartr-config.yaml` and fill it in
per the schema in `reference/config-schema.md`.

If details are missing from your request, the skill interviews you one
question at a time, each with a recommended answer — it prefers exploring the
repos over asking.

## ⚙️ How it works

1. 🔍 **Resolve** — the skill reads `firestartr-config.yaml`, matches your
   current directory against each organization's registered `paths` (longest
   prefix wins), and pins down your org, claims repo, and CLI version.
2. 🧭 **Classify** — your request is mapped to one of its playbooks (create,
   clone, edit, delete, reconcile, browse).
3. 🛠️ **Execute** — changes land through `fs-forge-cli` when possible, falling
   back to raw `gh` (manual create-then-PR flows, Terraform discovery) only
   where the CLI can't express them.
4. 📣 **Report** — you get a plain-language summary in your own terms: repos,
   teams, users, PRs.

## 💬 Example prompts

| You say | What happens |
|---|---|
| "Create a repo called payments-api" | 🆕 new repo, landed via PR |
| "Duplicate the web-frontend repo as web-frontend-v2" | 🐑 clone flow using the existing repo as the starting point |
| "Add ana to the platform team" | 👥 team membership edit |
| "Who owns the billing service?" | 📖 catalog lookup, read-only |
| "Is the claims repo in sync?" | 🩺 reconciliation status (synced, drifted, orphaned, stale) |

## 🧯 Troubleshooting

| Symptom | Fix |
|---|---|
| 📦 No stable CLI release found (`latest` empty or `snapshot`) | pick a published version (`npm view @firestartr/fs-forge-cli versions`) and pin it as `cli_version` in `firestartr-config.yaml` |
| 🚫 `fs-forge` could not be run via `npx` | check Node ≥ 18 and network access |
| 🔒 Claims-repo operations fail with auth errors | ensure `GITHUB_TOKEN` is exported — the CLI doesn't share `gh`'s auth store |
