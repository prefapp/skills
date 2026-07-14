# Claim schemas are owned by fscli, not vendored

**Status: accepted; supersedes the previous drift-detection decision.**

The `firestartr-operation` skill previously carried enriched copies of the
platform claim schemas. That made the skill self-contained, but the copies could
drift from the schemas used by the platform and could not be regenerated
losslessly.

## Decision

- `@prefapp/fscli` is the single source of truth for claim schemas.
- Creates discover the current kind's flags with
  `fscli create <Kind> --help --json`; the skill maps client answers and policy
  defaults onto those discovered flags.
- Validation of schema, types, and enum constraints runs through
  `fscli validate -f`. References, uniqueness, and naming normalization remain
  the skill's judgment.
- This repository does not vendor claim-schema JSON files or maintain a schema
  drift detector for them. Schema changes are consumed through the fscli release
  and version-pin process.

## Consequences

The operational skill no longer duplicates platform schemas and cannot silently
validate against an outdated local copy. The skill's reference material remains
portable policy and judgment: kind selection, naming, references, defaults, and
hydration mapping. Updating claim schemas is an fscli release concern rather than
a copy-refresh PR in `prefapp/skills`.
