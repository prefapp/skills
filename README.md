# Prefapp Skills

Harness-agnostic agent skills maintained by Prefapp. This repo ships two sets:

- **Workflow set** — [`skills/workflow/`](skills/workflow/README.md)
  The end-to-end development workflow Prefapp developers (and clients'
  developers) follow on any repository: plan → spec → implement → review.
- **Firestartr operational skill set** —
  [`skills/firestartr/firestartr-operation/`](skills/firestartr/firestartr-operation/README.md)
  A client-facing skill for operating a Prefapp-managed Firestartr platform
  in plain language.

## Install

```sh
git clone https://github.com/prefapp/skills.git ~/work/prefapp/skills
cd ~/work/prefapp/skills

./install.sh --workflow   # workflow set: symlinked; git pull updates
./install.sh --fs         # firestartr-operation: via npx skills add
./install.sh --all        # both
```

Run `./install.sh` with no arguments for all options. Install details,
per-harness layout, updating, and version pinning: see each set's README.

## Tests

```sh
./tests/test_install.sh
```

## Attribution

Parts of the workflow skill set are adapted from
[`mattpocock/skills`](https://github.com/mattpocock/skills). See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for its MIT license notice.
