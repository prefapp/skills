#!/usr/bin/env python3
"""Guard a copied skill tree before it is promoted into a features package.

Scans every UTF-8 text file under --root and reports, as violations:
  (a) Mustache collisions — a literal `{{|` or `|}}` sequence, which the
      features renderer would treat as a template tag (its non-standard
      delimiters, per the renderer's renderContent);
  (b) escaping references — a markdown link target (inline or reference
      definition) or a path-like inline code span (one starting with `./` or
      `../`) that resolves outside the tree. Prose tokens such as
      `~/work/prefapp` or a slash-command `/firestartr-operation` are not
      flagged.

Prints one `path:line: message` per violation; exit 1 if any, else 0.
No network, no git — standalone and CI-safe.

Usage:
    python3 guard_promotion.py --root DIR
"""
import argparse
import os
import re
import sys

LINK_RE = re.compile(r"!?\[[^\]\n]*\]\(([^)\n]+)\)")
DEF_RE = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)")
CODE_RE = re.compile(r"`([^`\n]+)`")


def iter_text_files(root):
    """Yield (relpath, text) for every UTF-8-decodable file under root."""
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in sorted(filenames):
            path = os.path.join(dirpath, name)
            try:
                with open(path, "rb") as f:
                    text = f.read().decode("utf-8")
            except (UnicodeDecodeError, OSError):
                continue  # binary or unreadable — not rendered content
            yield os.path.relpath(path, root), text


def mustache_collisions(root):
    """[(relpath, lineno, line)] for lines containing {{| or |}}."""
    hits = []
    for rel, text in iter_text_files(root):
        for lineno, line in enumerate(text.splitlines(), 1):
            if "{{|" in line or "|}}" in line:
                hits.append((rel, lineno, line.strip()))
    return hits


def _link_targets(line):
    """Yield the targets of inline links and reference definitions on line."""
    for m in LINK_RE.finditer(line):
        yield m.group(1)
    m = DEF_RE.match(line)
    if m:
        yield m.group(1)


def _path_of(target):
    """Normalize a link target to a bare path: strip <>/"title"/#frag/?query."""
    t = target.strip()
    if t.startswith("<") and t.endswith(">"):
        t = t[1:-1]
    t = t.split()[0]
    return t.split("#")[0].split("?")[0]


def _skip_target(target):
    if not target:
        return True
    if target.startswith(("#", "//", "mailto:", "tel:", "data:", "javascript:")):
        return True
    return "://" in target


def _outside(root, resolved):
    return os.path.commonpath([root, resolved]) != root


def escaping_references(root):
    """[(relpath, lineno, token)] for references resolving outside root."""
    hits = []
    for rel, text in iter_text_files(root):
        file_path = os.path.join(root, rel)
        for lineno, line in enumerate(text.splitlines(), 1):
            for target in _link_targets(line):
                target = _path_of(target)
                if _skip_target(target):
                    continue
                resolved = os.path.normpath(
                    os.path.join(os.path.dirname(file_path), target))
                if _outside(root, resolved):
                    hits.append((rel, lineno, target))
            for m in CODE_RE.finditer(line):
                for token in m.group(1).split():
                    # Only ./ or ../-prefixed spans are unambiguously
                    # filesystem-relative path references.
                    if not token.startswith("."):
                        continue
                    token = _path_of(token)
                    resolved = os.path.normpath(
                        os.path.join(os.path.dirname(file_path), token))
                    if _outside(root, resolved):
                        hits.append((rel, lineno, token))
    return hits


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", required=True)
    args = ap.parse_args(argv)
    root = os.path.normpath(args.root)
    if not os.path.isdir(root):
        print(f"{root}: not a directory", file=sys.stderr)
        return 2

    mustache = mustache_collisions(root)
    escapes = escaping_references(root)
    for rel, lineno, line in mustache:
        print(f"{rel}:{lineno}: Mustache collision: {line}")
    for rel, lineno, token in escapes:
        print(f"{rel}:{lineno}: escaping reference: `{token}`")
    if mustache or escapes:
        print(f"{len(mustache) + len(escapes)} violations")
        return 1
    print("ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
