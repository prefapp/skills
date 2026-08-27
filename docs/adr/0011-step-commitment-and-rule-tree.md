# Step commitment gates playbook execution; rules split into a tree

`firestartr-operation` had grown to ~2166 lines with rules restated three
times (SKILL.md's Rules section, inline step prose, `lifecycle.md`'s
Governance section) and no mechanism stopping the agent from executing an
action the client didn't ask for once a playbook was loaded.

## Decision

Once Step 2 classifies the intent and the client approves the resulting
plan, the agent is under **step commitment**: only the matched playbook's
own numbered steps get executed for that operation cycle. A new need
discovered mid-flow requires re-classification and fresh approval, never
silent expansion. Where the harness exposes a todo tool, the playbook's
steps are copied into it verbatim before Step 3 executes anything — the
todo list is not a separate format, it mirrors the playbook directly.

Rules split into two tiers instead of three restatements: a **Common
rules** section in SKILL.md holds what applies to every mutating
operation (PR-only, show-before-write, confirm destructive ops,
dual-layer errors, stop-on-first-failure, plus step commitment itself);
everything action-specific (e.g. array-fields-replace-not-append) lives
inline at the playbook step it governs, not in a separate per-playbook
Rules block. `lifecycle.md`'s Governance section keeps only what Common
rules doesn't already say (the fs-forge-managed vs. manual landing split).

## Consequences

Considered keeping one big Rules reference file all playbooks link to;
rejected because it re-creates the same lookup-then-cross-reference cost
step commitment is meant to remove — a rule an agent must go find is a
rule it can skip under pressure, same as the duplication problem this
replaces. Inlining at point of use costs a few repeated words across
playbooks but keeps each playbook a self-contained set of ordered
actions, which is what step commitment demands.
