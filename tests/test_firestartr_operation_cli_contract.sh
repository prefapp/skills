#!/usr/bin/env bash
# Exercise the check against the published CLI and a disposable copy of the skill.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/tests" "$TMP/skills/firestartr" "$TMP/bin"
cp -R "$ROOT/skills/firestartr/firestartr-operation" "$TMP/skills/firestartr/"
cp "$ROOT/tests/firestartr-operation-cli-contract.mjs" "$TMP/tests/"

# Stub only the registry's latest tag; installation and command help are real.
REAL_NPM="$(command -v npm)"
export REAL_NPM
cat > "$TMP/bin/npm" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = view ]; then echo 999.0.0; else exec "$REAL_NPM" "$@"; fi
EOF
chmod +x "$TMP/bin/npm"

cat > "$TMP/skills/firestartr/firestartr-operation/contract-test.md" <<'EOF'
```bash
npx @firestartr/fs-forge-cli@{version} validate -f {file} \
--bogus
npx @firestartr/fs-forge-cli@{version} nosuch
npx @firestartr/fs-forge-cli@{version} delete <kind> <name> --no-include-variants --no-wait --no-commit
npx @firestartr/fs-forge-cli@{version} create component --providers.github.org={org}
npx @firestartr/fs-forge-cli@{version} create <kind> --providers.github.org={org}
npx @firestartr/fs-forge-cli@{version} create domain --providers.github.org={org}
npx @firestartr/fs-forge-cli@{version} validate [-Z] [--bogus-optional]
npx @firestartr/fs-forge-cli@{version} validate -f {file} --json
npx @firestartr/fs-forge-cli@{version} validate --help --json | jq '.flags[] | "--not-a-flag"'
npx @firestartr/fs-forge-cli@{version} features add <component> --args.<field>=<value>
npx @firestartr/fs-forge-cli@{version} validate "--quoted-bogus" --source 'value --not-a-flag'
npx @firestartr/fs-forge-cli@{version} features edit <component> --args.example=value
npx @firestartr/fs-forge-cli@{version} validate -f {file} --args.bogus=true
```
Inline `npx @firestartr/fs-forge-cli@{version} validate -f {file}
--wrapped-bogus` and `npx @firestartr/fs-forge-cli@{version} validate --help --json`.
```bash
npx @firestartr/fs-forge-cli@{version} validate -f {file}&&echo --downstream-and
npx @firestartr/fs-forge-cli@{version} validate -f {file};echo --downstream-semicolon
npx @firestartr/fs-forge-cli@{version} validate -f {file}||echo --downstream-or
npx @firestartr/fs-forge-cli@{version} validate --help --json|jq -r '.flags[]'
npx @firestartr/fs-forge-cli@{version} validate -f {file}&echo --downstream-background
npx @firestartr/fs-forge-cli@{version} validate -f {file}&&npx @firestartr/fs-forge-cli@{version} validate --second-bogus
npx @firestartr/fs-forge-cli@{version} preflight [--scope claims|provider|all] --after-alternatives
npx @firestartr/fs-forge-cli@{version} validate (--refresh|--source) --after-parentheses
npx @firestartr/fs-forge-cli@{version} validate --source 'value;|&&' --after-quoted-operators
npx @firestartr/fs-forge-cli@{version} validate;echo --ignored
```
Inline `run this command:
npx @firestartr/fs-forge-cli@{version} validate -f {file}
--opening-on-previous-line`
Inline ``npx @firestartr/fs-forge-cli@{version} validate --source 'a ` b'
--double-delimiter``
```bash
npx @firestartr/fs-forge-cli@{version} preflight --org={org} \
  --kind <repo|team|user|tfworkspace> --name <name> --bogus-after-kind
npx @firestartr/fs-forge-cli@{version} preflight --kind <repo|team> --help --json|jq -r '.flags[]'
```
EOF
set +e
OUTPUT="$(PATH="$TMP/bin:$PATH" node "$TMP/tests/firestartr-operation-cli-contract.mjs" 2>&1)"
STATUS=$?
set -e
[ "$STATUS" -eq 1 ] || { printf 'FAIL: expected exit 1, got %s\n%s\n' "$STATUS" "$OUTPUT"; exit 1; }
for EXPECTED in \
  'contract-test.md:3: unknown flag --bogus for validate' \
  'contract-test.md:4: unknown command nosuch' \
  'contract-test.md:5: unknown flag --no-commit for delete' \
  'contract-test.md:8: unknown flag --providers.github.org for create domain' \
  'contract-test.md:9: unknown flag -Z for validate' \
  'contract-test.md:9: unknown flag --bogus-optional for validate' \
  'contract-test.md:10: unknown flag --json for validate' \
  'contract-test.md:13: unknown flag --quoted-bogus for validate' \
  'contract-test.md:15: unknown flag --args.bogus for validate' \
  'contract-test.md:18: unknown flag --wrapped-bogus for validate' \
  'contract-test.md:25: unknown flag --second-bogus for validate' \
  'contract-test.md:26: unknown flag --after-alternatives for preflight' \
  'contract-test.md:27: unknown flag --after-parentheses for validate' \
  'contract-test.md:28: unknown flag --after-quoted-operators for validate' \
  'contract-test.md:33: unknown flag --opening-on-previous-line for validate' \
  'contract-test.md:35: unknown flag --double-delimiter for validate' \
  'contract-test.md:38: unknown flag --bogus-after-kind for preflight' \
  '::warning::@firestartr/fs-forge-cli latest 999.0.0 is newer than skill target'; do
  [[ "$OUTPUT" == *"$EXPECTED"* ]] || { printf 'FAIL: missing %s\n%s\n' "$EXPECTED" "$OUTPUT"; exit 1; }
done
[ "$(printf '%s\n' "$OUTPUT" | grep -c 'unknown \(command\|flag\)')" -eq 17 ] || {
  printf 'FAIL: unexpected findings\n%s\n' "$OUTPUT"; exit 1;
}
echo 'PASS: unknown commands and flags, source lines, negation, and dynamic kinds'

cat > "$TMP/skills/firestartr/firestartr-operation/contract-test.md" <<'EOF'
```bash
npx @firestartr/fs-forge-cli@{version} delete <kind> <name> --no-include-variants
```
EOF
OUTPUT="$(PATH="$TMP/bin:$PATH" node "$TMP/tests/firestartr-operation-cli-contract.mjs" 2>&1)" || {
  printf 'FAIL: valid negation or warning changed the exit status\n%s\n' "$OUTPUT"; exit 1;
}
[[ "$OUTPUT" == *'::warning::@firestartr/fs-forge-cli latest 999.0.0 is newer than skill target'* ]] || {
  printf 'FAIL: missing latest warning\n%s\n' "$OUTPUT"; exit 1;
}
echo 'PASS: valid negation and latest warning do not fail the check'
