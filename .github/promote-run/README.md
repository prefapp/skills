# promote-run internals

Support files for the push-triggered **Promote run**
(`.github/workflows/promote-firestartr-operation.yml`), which mirrors
`firestartr/firestartr-operation/` into the `firestartr_operation` Feature
package in `prefapp/features` and opens one reviewable **Promotion PR** there.
No agent runs in the workflow. See
`docs/adr/0011-promote-firestartr-operation.md` for the design.

| File | Role |
|------|------|
| `guard_promotion.py` | Guard: scans a copied file tree and reports every unrendered Mustache collision (`{{|`/`|}}`) and every reference resolving outside the tree. Exit 1 on any violation. The one tested seam. |
| `test_guard_promotion.py` | Self-checking test for the guard. Run: `python3 .github/promote-run/test_guard_promotion.py` |
| `regen_files_list.py` | Rewrites a package's `config.yaml` `files:` block from its `templates/` tree (dest == src, sorted; existing per-file flags preserved, new files default to `user_managed: true`). |
| `test_regen_files_list.py` | Self-checking test for the regeneration. Run: `python3 .github/promote-run/test_regen_files_list.py` |

## Credentials

The workflow reads `vars.FS_STATE_APP_ID` and `secrets.FS_STATE_PEM_FILE`
from the **org level** — the same values `prefapp/features`' release-please
uses, so no repo-level setup is needed here. If the mint step fails with an
unknown App ID, the org needs those two credentials set.
