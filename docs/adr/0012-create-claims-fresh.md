# New claims are created fresh; claim cloning is not a path

Creating a Firestartr-managed resource used to copy an existing claim
(`clone-claim` / `fs-forge clone`) and patch what differed. That leaked source
identity, credentials, vars, Features, annotations, and other leftovers
([skills#101](https://github.com/prefapp/skills/issues/101)). Duplicate intent
is still valid; the source is read-only reference.

## Decision

Every create or "another like X" intent loads `create-claim` + `lifecycle`.
New claims are constructed from this request and documented policy. Existing
claims may be read for likeness; they are not copied. Feature-advisor stays
proactive on new repos.

Rename and import stay out of scope (ADR-0009). The unofficial
clone-then-delete rename recipe is withdrawn.

This skill releases first; CLI `clone` removal is a companion change. Older
installs update the skill or pin a clone-capable CLI. No alias, no invented
deprecation window.
