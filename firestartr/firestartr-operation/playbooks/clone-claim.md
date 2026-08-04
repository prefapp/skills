# Clone Claim Playbook

Create a new claim by copying an existing one and changing what differs, then
land it via `lifecycle`. Prefer `fs-forge clone` over hand-copying a file —
see `../reference/fs-forge-cookbook.md` for the invocation idiom.

## Flow

1. **Identify the source and the new name.** Source is `<Kind>-<source-name>`
   (an existing claim); `--from` below takes only the `<source-name>` part,
   since `<Kind>` is already a separate argument (short ID like `component`
   or the full `ComponentClaim` — both work here). Confirm what should differ
   in the new one (the client rarely wants an exact duplicate — at minimum
   the name changes, usually also owner/visibility/members/etc.).
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
5. **Show the relation diff to the client and get approval.** `--diff` renders
   the new claim's one-hop relation tree (add `--ascii` for plain-text icons,
   `--json` for the structured form) — not a plain field diff
   (`../reference/fs-forge-cookbook.md` has the format).
6. **Re-run with `--commit`** — see the cookbook's `--commit` warning (it
   also covers the uniqueness check `clone --commit` runs on its own).

Array fields (e.g. `members`, `additionalRules`) come across **as-is** from the
source unless you override them; overriding replaces the whole array (see the
cookbook), it doesn't merge with the source's values.

## When to clone vs. create

For a **repo** (ComponentClaim), clone by default — even when the client
never said "like X". `create` has no `--commit`; it always falls through to
lifecycle's manual PR/hydrate/state-merge flow. `clone --commit` lands the
same change — branch, PR, hydrate, state PR — in one shot, and its fields
(system, owner, features, …) inherit from a known-good existing component
instead of risking an invalid default. Pick any component close enough in
shape as `--from`; only fall back to `create-claim` when nothing in the org
is worth diffing against.

For every other kind, clone when the client wants "one like X but with Y
different" and an existing claim already has most of the desired shape —
otherwise `create-claim`'s manual flow is cheap enough to use directly.

## Manual fallback

Only when a needed override isn't reachable through `clone`'s flags: read the
source file, copy it, edit the differing fields, write the new file at its
deterministic path (`create-claim.md` has the per-kind path table), validate,
and land it via `lifecycle`'s manual flow.
