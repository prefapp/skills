#!/usr/bin/env python3
"""Regenerate a features package's static `files:` block from its templates tree.

The Promote run replaces the package's templates/ directory with a fresh
mirror of the skill; this keeps config.yaml's `files:` list a mechanical
image of that tree: one `{src, dest, user_managed}` entry per file, dest ==
src, sorted by path. An entry whose dest already exists keeps its existing
per-file keys (e.g. `user_managed`); new files default to `user_managed:
true`. The rest of config.yaml is untouched. Fails if the config has no
top-level `files:` key.

Usage:
    python3 regen_files_list.py --templates DIR --config config.yaml
"""
import argparse
import os
import sys


def tree_files(templates_dir):
    """Sorted posix relative paths of every file under DIR."""
    rels = []
    for dirpath, _dirnames, filenames in os.walk(templates_dir):
        for name in filenames:
            rels.append(os.path.relpath(os.path.join(dirpath, name), templates_dir))
    return sorted(r.replace(os.sep, "/") for r in rels)


def split_block(lines):
    """Return (start, entries, end) for the top-level `files:` block.

    Entries are parsed from the uniform `  - src:` / 4-space key format; the
    block ends at the first non-indented line (a blank separator or the next
    top-level key, both preserved in `lines[end:]`).
    """
    for i, line in enumerate(lines):
        if line == "files:":
            break
    else:
        raise ValueError("no top-level `files:` key")
    entries = []
    current = None
    j = i + 1
    while j < len(lines) and lines[j].startswith((" ", "\t")):
        line = lines[j]
        if line.startswith("  - "):
            key, _, value = line[4:].partition(":")
            current = {key.strip(): value.strip()}
            entries.append(current)
        elif line.startswith("    "):
            key, _, value = line[4:].partition(":")
            if current is not None:
                current[key.strip()] = value.strip()
        j += 1
    return i, entries, j


def render_block(entries):
    lines = ["files:"]
    for e in entries:
        lines.append(f"  - src: {e['src']}")
        lines.append(f"    dest: {e['dest']}")
        for key, value in e.items():
            if key not in ("src", "dest"):
                lines.append(f"    {key}: {value}")
    return lines


def rebuild(templates_dir, config_path):
    with open(config_path) as f:
        lines = f.read().splitlines()
    start, entries, end = split_block(lines)
    by_dest = {e.get("dest"): e for e in entries}
    new_entries = []
    for rel in tree_files(templates_dir):
        old = by_dest.get(rel)
        extras = {k: v for k, v in (old or {}).items()
                  if k not in ("src", "dest")} if old else {"user_managed": "true"}
        new_entries.append({"src": rel, "dest": rel, **extras})
    return "\n".join(lines[:start] + render_block(new_entries) + lines[end:]) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--templates", required=True)
    ap.add_argument("--config", required=True)
    args = ap.parse_args(argv)
    try:
        new_text = rebuild(args.templates, args.config)
    except ValueError as e:
        print(f"{args.config}: {e}", file=sys.stderr)
        return 1
    with open(args.config, "w") as f:
        f.write(new_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
