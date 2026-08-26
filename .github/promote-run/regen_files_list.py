#!/usr/bin/env python3
"""Regenerate a features package's static `files:` block from its templates tree.

The Promote run replaces the package's templates/ directory with a fresh
mirror of the skill; this keeps config.yaml's `files:` list a mechanical
image of that tree: one `{src, dest, user_managed}` entry per file, sorted by
`src`. `dest` is `src` prefixed with `--namespace` (joined with `/`) when
given, else equal to `src`. Matching an existing entry against the tree is
done by `src` — the on-disk relative path — never `dest`, since `dest` may
carry a Mustache tag (e.g. the `installationPath` arg) once namespaced and
would then never match a plain path lookup again. An entry whose src
already exists keeps its existing per-file keys (e.g. `user_managed`); new
files default to `user_managed: true`. The rest of config.yaml is
untouched. Fails if the config has no top-level `files:` key.

Usage:
    python3 regen_files_list.py --templates DIR --config config.yaml \
        [--namespace 'PREFIX']
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


def _yaml_scalar(value):
    """Render `value` as a plain YAML scalar, double-quoting it if required.

    A plain YAML scalar can't start with a flow/indicator character — a
    namespaced `dest` starts with the literal `{` of a Mustache tag
    (`{{| installationPath |}}/...`). Every value handled here is a simple
    path/prefix with nothing that needs escaping inside double quotes.
    """
    if value == "" or value[0] in "{}[]&*!|>'\"%@`,#?:-" or ": " in value:
        return f'"{value}"'
    return value


def render_block(entries):
    lines = ["files:"]
    for e in entries:
        lines.append(f"  - src: {_yaml_scalar(e['src'])}")
        lines.append(f"    dest: {_yaml_scalar(e['dest'])}")
        for key, value in e.items():
            if key not in ("src", "dest"):
                lines.append(f"    {key}: {value}")
    return lines


def rebuild(templates_dir, config_path, namespace=None):
    with open(config_path) as f:
        lines = f.read().splitlines()
    start, entries, end = split_block(lines)
    by_src = {e.get("src"): e for e in entries}
    new_entries = []
    for rel in tree_files(templates_dir):
        old = by_src.get(rel)
        extras = {k: v for k, v in (old or {}).items()
                  if k not in ("src", "dest")} if old else {"user_managed": "true"}
        dest = f"{namespace}/{rel}" if namespace else rel
        new_entries.append({"src": rel, "dest": dest, **extras})
    return "\n".join(lines[:start] + render_block(new_entries) + lines[end:]) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--templates", required=True)
    ap.add_argument("--config", required=True)
    ap.add_argument("--namespace", default=None,
                     help="Prefix joined with '/' onto every dest (e.g. a "
                          "'{{| installationPath |}}/...' Mustache tag).")
    args = ap.parse_args(argv)
    try:
        new_text = rebuild(args.templates, args.config, args.namespace)
    except ValueError as e:
        print(f"{args.config}: {e}", file=sys.stderr)
        return 1
    with open(args.config, "w") as f:
        f.write(new_text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
