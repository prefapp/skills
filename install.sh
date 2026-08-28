#!/usr/bin/env bash
# Install prefapp-workflow skills into detected agent harnesses.
# The workflow set is symlinked flat per-skill from skills/workflow into
# ~/.agents/skills and, when Claude Code is detected, ~/.claude/skills.
# Idempotent — safe to re-run. Symlinks only, never copies.
# The Firestartr operational skill is installed via `npx skills add` — a hard
# network dependency with no fallback, same policy as fs-forge (see
# skills/firestartr/firestartr-operation/reference/fs-forge-cookbook.md).
#
# Run without arguments for usage. Install the workflow set, the Firestartr
# operational skill, or both.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills/workflow"
NAMESPACE="prefapp-workflow"

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

# Read the `name:` field from a skill's SKILL.md frontmatter (empty if absent).
skill_frontmatter_name() {
  awk '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && /^name:[ \t]*/ { sub(/^name:[ \t]*/, ""); sub(/[ \t\r]+$/, ""); print; exit }
  ' "$1" 2>/dev/null
}

# Some harnesses (Claude Code, VS Code Copilot) only discover
# <skills-root>/<skill>/SKILL.md — one level deep — and reject namespaced
# names, so a namespace-dir symlink hides every skill inside it. Link each
# skill individually into $dest instead.
link_flat() {
  local src="$1" ns="$2" dest="$3" label="$4" skill name legacy_skill existing_name
  mkdir -p "$dest"

  # Drop the namespace dir left by older versions of this script.
  if [ -L "$dest/$ns" ]; then
    rm -f "$dest/$ns"
    echo "  $label: removed stale namespace link $dest/$ns"
  fi

  # Drop per-skill links from previous runs whose source no longer exists.
  for skill in "$dest"/*; do
    [ -L "$skill" ] || continue
    case "$(readlink "$skill")" in
      "$src"/*) [ -e "$skill" ] || { rm -f "$skill"; echo "  $label: removed stale link $dest/$(basename "$skill")"; } ;;
    esac
  done

  for skill in "$src"/*/; do
    skill="${skill%/}"
    name="$(basename "$skill")"
    legacy_skill="${src%/*}/$name"
    [ -f "$skill/SKILL.md" ] || continue
    # Never clobber a real directory or a link owned by something else —
    # unless it's a real dir whose own SKILL.md unambiguously declares itself
    # as this managed skill (e.g. a stale manual-copy workaround).
    if [ -e "$dest/$name" ] || [ -L "$dest/$name" ]; then
      if [ -L "$dest/$name" ] && [ "$(readlink "$dest/$name")" = "$skill" ]; then
        : # already correctly linked
      elif [ -L "$dest/$name" ] && [ "$(readlink "$dest/$name")" = "$legacy_skill" ]; then
        rm -f "$dest/$name"
        echo "  $label: updated stale link $dest/$name"
      elif [ -d "$dest/$name" ] && ! [ -L "$dest/$name" ] && [ -f "$dest/$name/SKILL.md" ] \
        && existing_name="$(skill_frontmatter_name "$dest/$name/SKILL.md")" \
        && [ "$existing_name" = "$name" ]; then
        rm -rf "${dest:?}/${name:?}"
        echo "  $label: replaced stale copy $dest/$name with a symlink"
      else
        echo "  $label: SKIP $name — $dest/$name already exists" >&2
        continue
      fi
    fi
    ln -sfn "$skill" "$dest/$name"
    echo "  $label: $dest/$name → $skill"
  done
}

# Link one source dir into every harness skills location, flat per-skill.
link_into_harnesses() {
  local src="$1" ns="$2"
  link_flat "$src" "$ns" "$HOME/.agents/skills" "agents"
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    link_flat "$src" "$ns" "$HOME/.claude/skills" "claude"
  fi
}

if [ "$INSTALL_WORKFLOW" -eq 1 ]; then
  echo "prefapp-workflow: installing from $SKILLS_DIR"
  link_into_harnesses "$SKILLS_DIR" "$NAMESPACE"
fi

if [ "$INSTALL_FIRESTARTR" -eq 1 ]; then
  echo "prefapp-firestartr: installing via npx skills add"
  # Drop stale links left by earlier versions of this script (pre-npx): the
  # prefapp-firestartr namespace link, and any per-skill firestartr-operation
  # link from the old flat layout. The npx install never creates them, and they
  # pointed at the pre-restructure firestartr/ tree, so they are dead — and
  # would sit right where npx wants to install.
  for dest in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
    if [ -L "$dest/prefapp-firestartr" ]; then
      rm -f "$dest/prefapp-firestartr"
      echo "  prefapp-firestartr: removed stale namespace link $dest/prefapp-firestartr"
    fi
    if [ -L "$dest/firestartr-operation" ]; then
      case "$(readlink "$dest/firestartr-operation" 2>/dev/null || true)" in
        "$REPO_DIR"/firestartr/*)
          rm -f "$dest/firestartr-operation"
          echo "  prefapp-firestartr: removed stale skill link $dest/firestartr-operation"
          ;;
      esac
    fi
  done
  rc=0
  npx skills add prefapp/skills --skill firestartr-operation || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "prefapp-firestartr: 'npx skills add' failed (exit $rc) — hard dependency, no fallback." >&2
    echo "Ensure npx is available (Node >= 18) and that you have network access. Do not proceed without it." >&2
    exit "$rc"
  fi
fi

echo "Done. See README.md for per-harness discovery edge cases."
