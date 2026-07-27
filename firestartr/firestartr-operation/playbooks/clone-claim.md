# Clone Claim Playbook

Create a new claim by copying an existing one and changing what differs, then
land it via `lifecycle`. Prefer `fs-forge clone` over hand-copying a file —
see `../reference/fs-forge-cookbook.md` for the invocation idiom.

## Flow

1. **Identify the source and the new name.** Source is `<Kind>-<source-name>`
   (an existing claim); confirm what should differ in the new one (the client
   rarely wants an exact duplicate — at minimum the name changes, usually
   also owner/visibility/members/etc.).
2. **Read the source** (optional but recommended when you don't already know
   its fields): `edit <Kind>-<source-name> --org={org}` with no mutating flags.
3. **Discover flags** for the kind via `create <Kind> --help --json` (same
   discovery step as `create`/`edit` — never `clone --help --json`, which
   mixes every kind's flags together).
4. **Dry-run:**
   ```bash
   npx @firestartr/fs-forge-cli@{version} clone <Kind> --org={org} \
     --from <source-name> --name <new-name> \
     --<flag>=<value> ... \
     --diff
   ```
   `TFWorkspaceClaim`/`SecretsClaim` also need
   `--path claims/{...}/{new-name}.yaml` (the deterministic-path rule from
   `create-claim.md` applies here too). Fix any validation errors.
5. **Show the diff to the client and get approval.**
6. **Re-run with `--commit`.** Read the cookbook's `--commit` warning first —
   it commits *and* provisions *and* hydrates the new claim in one shot;
   nothing else to do afterward unless the client asks for status or a manual
   re-hydrate. `clone --commit` also errors on its own if `<Kind>-<new-name>`
   already exists — no separate uniqueness check needed.

Array fields (e.g. `members`, `additionalRules`) come across **as-is** from the
source unless you override them; overriding replaces the whole array (see the
cookbook), it doesn't merge with the source's values.

## When to clone vs. create

Clone when the client wants "one like X but with Y different" and an existing
claim of that kind already has most of the desired shape. Otherwise use
`create-claim` — building from schema defaults is simpler than cloning and
overriding most of the fields anyway.

## Manual fallback

Only when a needed override isn't reachable through `clone`'s flags: read the
source file, copy it, edit the differing fields, write the new file at its
deterministic path (`create-claim.md` has the per-kind path table), validate,
and land it via `lifecycle`'s manual flow.
