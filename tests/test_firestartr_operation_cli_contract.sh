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
  '::warning::@firestartr/fs-forge-cli latest 999.0.0 is newer than skill target'; do
  [[ "$OUTPUT" == *"$EXPECTED"* ]] || { printf 'FAIL: missing %s\n%s\n' "$EXPECTED" "$OUTPUT"; exit 1; }
done
[ "$(printf '%s\n' "$OUTPUT" | grep -c 'unknown \(command\|flag\)')" -eq 7 ] || {
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
