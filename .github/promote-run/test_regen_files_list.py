#!/usr/bin/env python3
"""Self-checking test for regen_files_list — no framework, run directly.

Covers: regenerating a files: block from a nested tree (dotfiles included,
sorted), preserving an existing entry's per-file flags, defaulting new files
to user_managed: true, dropping entries whose files are gone, failing on a
config without a top-level files: key, prefixing dest with --namespace, and
matching existing entries by src (not dest) so a dest already carrying a
Mustache tag from a prior namespaced run still keeps its flags.
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import regen_files_list as regen

CONFIG = (
    "feature_name: firestartr_operation\n"
    "args: {}\n"
    "files:\n"
    "  - src: old.md\n"
    "    dest: old.md\n"
    "    user_managed: true\n"
    "\n"
    "patches: {}\n"
)


def make_tree(files):
    tmp = tempfile.TemporaryDirectory()
    for rel, content in files.items():
        path = os.path.join(tmp.name, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(content)
    return tmp


def test_regenerate_matches_tree():
    tmp = make_tree({
        "templates/README.md": "hi",
        "templates/.gitignore": "config\n",
        "templates/playbooks/lifecycle.md": "hi",
        "config.yaml": CONFIG,
    })
    try:
        cfg = os.path.join(tmp.name, "config.yaml")
        assert regen.main(["--templates", os.path.join(tmp.name, "templates"),
                           "--config", cfg]) == 0
        want = (
            "feature_name: firestartr_operation\n"
            "args: {}\n"
            "files:\n"
            "  - src: .gitignore\n"
            "    dest: .gitignore\n"
            "    user_managed: true\n"
            "  - src: README.md\n"
            "    dest: README.md\n"
            "    user_managed: true\n"
            "  - src: playbooks/lifecycle.md\n"
            "    dest: playbooks/lifecycle.md\n"
            "    user_managed: true\n"
            "\n"
            "patches: {}\n"
        )
        assert open(cfg).read() == want
    finally:
        tmp.cleanup()


def test_flags_preserved_and_new_files_default():
    tmp = make_tree({
        "templates/README.md": "hi",
        "templates/new.md": "hi",
        "config.yaml": (
            "feature_name: firestartr_operation\n"
            "files:\n"
            "  - src: README.md\n"
            "    dest: README.md\n"
            "    user_managed: false\n"
            "\n"
            "patches: {}\n"
        ),
    })
    try:
        cfg = os.path.join(tmp.name, "config.yaml")
        assert regen.main(["--templates", os.path.join(tmp.name, "templates"),
                           "--config", cfg]) == 0
        text = open(cfg).read()
        assert (
            "  - src: README.md\n"
            "    dest: README.md\n"
            "    user_managed: false\n"
            "  - src: new.md\n"
            "    dest: new.md\n"
            "    user_managed: true\n" in text
        )
    finally:
        tmp.cleanup()


def test_namespace_prefixes_dest():
    tmp = make_tree({
        "templates/SKILL.md": "hi",
        "config.yaml": (
            "feature_name: firestartr_operation\n"
            "args: {}\n"
            "files:\n"
            "\n"
            "patches: {}\n"
        ),
    })
    try:
        cfg = os.path.join(tmp.name, "config.yaml")
        assert regen.main([
            "--templates", os.path.join(tmp.name, "templates"),
            "--config", cfg,
            "--namespace", "{{| installationPath |}}/firestartr-operation",
        ]) == 0
        text = open(cfg).read()
        assert (
            "  - src: SKILL.md\n"
            '    dest: "{{| installationPath |}}/firestartr-operation/SKILL.md"\n'
            "    user_managed: true\n" in text
        )
    finally:
        tmp.cleanup()


def test_matches_existing_by_src_when_dest_is_already_namespaced():
    # Simulates config.yaml after a prior namespaced run: dest carries the
    # Mustache prefix, so a dest-keyed lookup (the old behavior) would never
    # match this src again, and would wrongly reset user_managed to true.
    tmp = make_tree({
        "templates/SKILL.md": "hi",
        "config.yaml": (
            "feature_name: firestartr_operation\n"
            "args: {}\n"
            "files:\n"
            "  - src: SKILL.md\n"
            '    dest: "{{| installationPath |}}/firestartr-operation/SKILL.md"\n'
            "    user_managed: false\n"
            "\n"
            "patches: {}\n"
        ),
    })
    try:
        cfg = os.path.join(tmp.name, "config.yaml")
        assert regen.main([
            "--templates", os.path.join(tmp.name, "templates"),
            "--config", cfg,
            "--namespace", "{{| installationPath |}}/firestartr-operation",
        ]) == 0
        text = open(cfg).read()
        assert "user_managed: false" in text
        assert "user_managed: true" not in text
    finally:
        tmp.cleanup()


def test_missing_files_key_fails():
    tmp = make_tree({
        "templates/a.md": "hi",
        "config.yaml": "feature_name: x\nargs: {}\npatches: {}\n",
    })
    try:
        assert regen.main(["--templates", os.path.join(tmp.name, "templates"),
                           "--config", os.path.join(tmp.name, "config.yaml")]) == 1
    finally:
        tmp.cleanup()


if __name__ == "__main__":
    test_regenerate_matches_tree()
    test_flags_preserved_and_new_files_default()
    test_namespace_prefixes_dest()
    test_matches_existing_by_src_when_dest_is_already_namespaced()
    test_missing_files_key_fails()
    print("ok")
