#!/usr/bin/env bash
# Behavior test for the firestartr-operation skill files as static text artifacts.
# Asserts required strings are present and forbidden strings are absent.
# No framework — plain echo "FAIL" + exit 1 pattern from test_install.sh.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/../firestartr/firestartr-operation" && pwd)"

fail() { echo "FAIL: $1"; exit 1; }

# No file under the skill dir may contain the old CLI name or package.
grep -rql "fscli" "$SKILL_DIR" && fail "found 'fscli' in skill files"
grep -rql "@prefapp/fscli" "$SKILL_DIR" && fail "found '@prefapp/fscli' in skill files"

# The cookbook must use the npx invocation pattern.
grep -q "npx @firestartr/fs-forge-cli" "$SKILL_DIR/reference/fs-forge-cookbook.md" \
  || fail "cookbook missing 'npx @firestartr/fs-forge-cli'"

# The cookbook must not contain a "when on PATH" fallback.
grep -q "when.*on PATH" "$SKILL_DIR/reference/fs-forge-cookbook.md" \
  && fail "cookbook still has 'when on PATH' fallback"

# SKILL.md must reference firestartr-config.yaml, not organization.yaml, and
# parse npm's latest dist-tag independently of whitespace width.
grep -q "firestartr-config.yaml" "$SKILL_DIR/SKILL.md" \
  || fail "SKILL.md missing 'firestartr-config.yaml'"
grep -q "organization\.yaml" "$SKILL_DIR/SKILL.md" \
  && fail "SKILL.md still references 'organization.yaml'"
grep -Fq "awk '\$1 == \"latest:\" { print \$2 }'" "$SKILL_DIR/SKILL.md" \
  || fail "SKILL.md latest dist-tag parsing is whitespace-sensitive"

# Command examples must retain the npx package and version prefix.
grep -rEq '(^|[^@[:alnum:]_/-])fs-forge[[:space:]]+(create|validate)([[:space:]]|$)' "$SKILL_DIR" \
  && fail "skill files contain a bare fs-forge command"
grep -Fq 'claims_repo` is `{org}/claims' "$SKILL_DIR/SKILL.md" \
  || fail "SKILL.md default claims repo does not use the resolved org placeholder"

# firestartr-config.example.yaml must exist and contain cli_version.
[ -f "$SKILL_DIR/firestartr-config.example.yaml" ] \
  || fail "firestartr-config.example.yaml does not exist"
grep -q "cli_version" "$SKILL_DIR/firestartr-config.example.yaml" \
  || fail "firestartr-config.example.yaml missing 'cli_version' field"

echo "PASS: firestartr-operation skill files"
