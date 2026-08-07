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

# Claude Code only discovers <skills-root>/<skill>/SKILL.md — one level deep, so a
# namespace-dir symlink hides every skill inside it. Link each skill individually.
link_into_claude() {
  local src="$1" ns="$2" dest="$HOME/.claude/skills" skill name
  mkdir -p "$dest"

  # Drop the namespace dir left by older versions of this script.
  if [ -L "$dest/$ns" ]; then
    rm -f "$dest/$ns"
    echo "  claude: removed stale namespace link ~/.claude/skills/$ns"
  fi

  # Drop per-skill links from previous runs whose source no longer exists.
  for skill in "$dest"/*; do
    [ -L "$skill" ] || continue
    case "$(readlink "$skill")" in
      "$src"/*) [ -e "$skill" ] || { rm -f "$skill"; echo "  claude: removed stale link ~/.claude/skills/$(basename "$skill")"; } ;;
    esac
  done

  for skill in "$src"/*/; do
    skill="${skill%/}"
    name="$(basename "$skill")"
    [ -f "$skill/SKILL.md" ] || continue
    # Never clobber a real directory or a link owned by something else.
    if [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
      if ! [ -L "$dest/$name" ] || [ "$(readlink "$dest/$name")" != "$skill" ]; then
        echo "  claude: SKIP $name — ~/.claude/skills/$name already exists" >&2
        continue
      fi
    fi
    ln -sfn "$skill" "$dest/$name"
    echo "  claude: ~/.claude/skills/$name → $skill"
  done
}

# Link one source dir into every harness skills location under $namespace.
link_into_harnesses() {
  local src="$1" ns="$2"
  mkdir -p "$HOME/.agents/skills"
  ln -sfn "$src" "$HOME/.agents/skills/$ns"
  echo "  agents: ~/.agents/skills/$ns → $src"
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    link_into_claude "$src" "$ns"
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
