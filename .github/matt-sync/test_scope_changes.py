#!/usr/bin/env python3
"""Self-checking test for scope_changes — no framework, run directly.

Covers the spec's Testing Decisions fixtures: an edited mapped skill, a rename,
ignored (in-progress / deprecated / .out-of-scope / README / package file), a
net-new misc skill, and an empty range. Includes one real git-fixture run to
prove the since..HEAD diff integration, not just pure classification.
"""
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import scope_changes as sc

OURS = {"tdd", "review", "setup-workflow", "implement", "grilling"}


def test_classify():
    # engineering/productivity mapped to ours -> edit-candidate
    assert sc.classify("skills/engineering/tdd/SKILL.md", OURS) == (
        "edit-candidate", ("engineering/tdd", "tdd"))
    # renames map by content, not filename
    assert sc.classify("skills/engineering/code-review/SKILL.md", OURS) == (
        "edit-candidate", ("engineering/code-review", "review"))
    assert sc.classify("skills/engineering/setup-matt-pocock-skills/SKILL.md", OURS) == (
        "edit-candidate", ("engineering/setup-matt-pocock-skills", "setup-workflow"))
    # net-new engineering skill (no analog) -> suggest-import
    assert sc.classify("skills/engineering/prototype/SKILL.md", OURS) == (
        "suggest-import", "engineering/prototype")
    # misc / personal -> suggest-import
    assert sc.classify("skills/misc/setup-pre-commit/SKILL.md", OURS) == (
        "suggest-import", "misc/setup-pre-commit")
    assert sc.classify("skills/personal/obsidian-vault/SKILL.md", OURS)[0] == "suggest-import"
    # in-progress / deprecated -> ignored
    assert sc.classify("skills/in-progress/wizard/SKILL.md", OURS)[0] == "ignored"
    assert sc.classify("skills/deprecated/qa/SKILL.md", OURS)[0] == "ignored"
    # .out-of-scope, category README, package files -> ignored
    assert sc.classify(".out-of-scope/foo.md", OURS)[0] == "ignored"
    assert sc.classify("skills/engineering/README.md", OURS)[0] == "ignored"
    assert sc.classify("package.json", OURS)[0] == "ignored"


def test_build_report():
    paths = [
        "skills/engineering/tdd/SKILL.md",
        "skills/engineering/tdd/helper.md",       # same skill, deduped
        "skills/engineering/code-review/SKILL.md",
        "skills/misc/setup-pre-commit/SKILL.md",
        "skills/in-progress/wizard/SKILL.md",
        "skills/engineering/README.md",
        "package.json",
    ]
    r = sc.build_report(paths, OURS)
    assert r["edit_candidates"] == {
        "engineering/code-review": "review",
        "engineering/tdd": "tdd",
    }
    assert r["suggest_imports"] == ["misc/setup-pre-commit"]
    assert r["ignored_count"] == 3  # in-progress, README, package.json


def test_git_fixture_diff_and_empty_range():
    with tempfile.TemporaryDirectory() as repo:
        def git(*a):
            subprocess.run(["git", "-C", repo, *a], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        git("init")
        git("config", "user.email", "t@t")
        git("config", "user.name", "t")
        # base commit (== last-checked SHA)
        os.makedirs(os.path.join(repo, "skills/engineering/tdd"))
        open(os.path.join(repo, "README.md"), "w").write("x")
        open(os.path.join(repo, "skills/engineering/tdd/SKILL.md"), "w").write("v1")
        git("add", "-A")
        git("commit", "-m", "base")
        base = subprocess.check_output(
            ["git", "-C", repo, "rev-parse", "HEAD"], text=True).strip()

        # empty range: since == HEAD
        assert sc.changed_paths(repo, base) == []

        # advance: edit a mapped skill + add an ignored README
        open(os.path.join(repo, "skills/engineering/tdd/SKILL.md"), "w").write("v2")
        os.makedirs(os.path.join(repo, "skills/misc/setup-pre-commit"))
        open(os.path.join(repo, "skills/misc/setup-pre-commit/SKILL.md"), "w").write("new")
        git("add", "-A")
        git("commit", "-m", "advance")

        paths = set(sc.changed_paths(repo, base))
        assert paths == {
            "skills/engineering/tdd/SKILL.md",
            "skills/misc/setup-pre-commit/SKILL.md",
        }
        r = sc.build_report(paths, OURS)
        assert r["edit_candidates"] == {"engineering/tdd": "tdd"}
        assert r["suggest_imports"] == ["misc/setup-pre-commit"]


if __name__ == "__main__":
    test_classify()
    test_build_report()
    test_git_fixture_diff_and_empty_range()
    print("ok")
