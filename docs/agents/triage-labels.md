# Triage labels

The `triage` skill speaks in seven canonical role names: two category roles and
five state roles. This file maps each to the actual label string used in this
repo's GitHub issue tracker. Defaults equal
the canonical names — edit the right-hand column if your tracker already uses
other strings (so `triage` applies existing labels instead of creating
duplicates).

| Canonical role    | Label in this repo | Meaning                                  |
| ----------------- | ------------------ | ---------------------------------------- |
| `bug`             | `bug`              | Something is broken                      |
| `enhancement`     | `enhancement`      | New feature or improvement               |
| `needs-triage`    | `needs-triage`     | Maintainer needs to evaluate this issue  |
| `needs-info`      | `needs-info`       | Waiting on reporter for more information |
| `ready-for-agent` | `ready-for-agent`  | Fully specified, ready for an AFK agent  |
| `ready-for-human` | `ready-for-human`  | Requires human implementation            |
| `wontfix`         | `wontfix`          | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the
corresponding label string from this table.
