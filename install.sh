#!/usr/bin/env bash
# Install prefapp-workflow skills into detected agent harnesses.
# Idempotent — safe to re-run. Symlinks only, never copies.
#
# Run without arguments for usage. Install the workflow set, the opt-in
# Firestartr operational skill, or both.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
NAMESPACE="prefapp-workflow"
FIRESTARTR_DIR="$REPO_DIR/firestartr"
FIRESTARTR_NAMESPACE="prefapp-firestartr"

usage() {
  cat <<'EOF'
Usage: ./install.sh OPTION

Options:
  --all       Install workflow and Firestartr skills
  --workflow  Install workflow skills
  --fs        Install the Firestartr operational skill
  -h, --help  Show this help
EOF
}

INSTALL_WORKFLOW=0
INSTALL_FIRESTARTR=0
case "${1:-}" in
  --all) INSTALL_WORKFLOW=1; INSTALL_FIRESTARTR=1 ;;
  --workflow) INSTALL_WORKFLOW=1 ;;
  --fs) INSTALL_FIRESTARTR=1 ;;
  ""|-h|--help) usage; exit 0 ;;
  *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
esac
[ "$#" -eq 1 ] || { echo "expected one option" >&2; usage >&2; exit 2; }

# Link one source dir into every harness skills location under $namespace.
link_into_harnesses() {
  local src="$1" ns="$2"
  mkdir -p "$HOME/.agents/skills"
  ln -sfn "$src" "$HOME/.agents/skills/$ns"
  echo "  agents: ~/.agents/skills/$ns → $src"
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    mkdir -p "$HOME/.claude/skills"
    ln -sfn "$src" "$HOME/.claude/skills/$ns"
    echo "  claude: ~/.claude/skills/$ns → $src"
  fi
}

if [ "$INSTALL_WORKFLOW" -eq 1 ]; then
  echo "prefapp-workflow: installing from $SKILLS_DIR"
  link_into_harnesses "$SKILLS_DIR" "$NAMESPACE"
fi

if [ "$INSTALL_FIRESTARTR" -eq 1 ]; then
  echo "prefapp-firestartr: installing from $FIRESTARTR_DIR"
  link_into_harnesses "$FIRESTARTR_DIR" "$FIRESTARTR_NAMESPACE"
fi

echo "Done. See README.md for per-harness discovery edge cases."
