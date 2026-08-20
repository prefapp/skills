#!/usr/bin/env python3
"""Self-checking test for guard_promotion — no framework, run directly.

Covers the spec's fixtures: a clean tree (passes), an unrendered Mustache
collision (fails), an escaping reference (fails), plus the non-flag cases
(inside-tree references, URL/anchor/mailto links, prose tokens, binary
files), and one real run against firestartr/firestartr-operation itself.
"""
import contextlib
import io
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import guard_promotion as gp


def make_tree(files):
    """Create a temp tree from {relpath: content}; return (tmpdir, root)."""
    tmp = tempfile.TemporaryDirectory()
    root = tmp.name
    for rel, content in files.items():
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        mode = "wb" if isinstance(content, bytes) else "w"
        with open(path, mode) as f:
            f.write(content)
    return tmp, root


def run(root):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = gp.main(["--root", root])
    return code, out.getvalue()


def test_clean_tree_passes():
    tmp, root = make_tree({
        "README.md": "See [the preflight reference](reference/fs-forge-preflight.md)\n",
        "playbooks/lifecycle.md": (
            "Back to [preflight](../reference/fs-forge-preflight.md), "
            "or the [Pi docs](https://pi.dev/docs/latest), or [anchor](#top).\n"),
        "SKILL.md": "Status line: `Using org: prefapp-demo (~/work/prefapp) | fs-forge: 0.1.0`\n",
    })
    try:
        code, out = run(root)
        assert code == 0, out
        assert "ok" in out
    finally:
        tmp.cleanup()


def test_mustache_collision_fails():
    tmp, root = make_tree({
        "a.md": "Render me as {{| ORG |}} please\n",
        "b.md": "A stray closing |}} delimiter\n",
    })
    try:
        code, out = run(root)
        assert code == 1, out
        assert "a.md:1: Mustache collision" in out
        assert "b.md:1: Mustache collision" in out
        assert "2 violations" in out
    finally:
        tmp.cleanup()


def test_escaping_reference_fails():
    tmp, root = make_tree({
        "README.md": "[root README](../../README.md)\n",
        "reference/fs-forge-preflight.md": "See `../../../docs/adr/0009.md`\n",
        "other.md": "[absolute](/etc/hosts)\n",
        "defs.md": "[root]: ../../README.md\n",
    })
    try:
        code, out = run(root)
        assert code == 1, out
        assert "README.md:1: escaping reference: `../../README.md`" in out
        assert "reference/fs-forge-preflight.md:1: escaping reference: `../../../docs/adr/0009.md`" in out
        assert "other.md:1: escaping reference: `/etc/hosts`" in out
        assert "defs.md:1: escaping reference: `../../README.md`" in out
        assert "4 violations" in out
    finally:
        tmp.cleanup()


def test_prose_tokens_are_not_flagged():
    tmp, root = make_tree({
        "reference/reference.md": (
            "Lean `remote` (`git::https://github.com/prefapp/tfm.git//modules/x?ref=y`) for this;\n"
            "invoke `/firestartr-operation` and mail [us](mailto:a@b) or see [top](#top).\n"),
    })
    try:
        code, out = run(root)
        assert code == 0, out
    finally:
        tmp.cleanup()


def test_binary_files_are_skipped():
    tmp, root = make_tree({
        "image.png": b"\x89PNG {{|x|}} \xff\xfe",
    })
    try:
        code, out = run(root)
        assert code == 0, out
    finally:
        tmp.cleanup()


def test_real_skill_tree_is_clean():
    repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    root = os.path.join(repo, "firestartr", "firestartr-operation")
    code, out = run(root)
    assert code == 0, out


if __name__ == "__main__":
    test_clean_tree_passes()
    test_mustache_collision_fails()
    test_escaping_reference_fails()
    test_prose_tokens_are_not_flagged()
    test_binary_files_are_skipped()
    test_real_skill_tree_is_clean()
    print("ok")
