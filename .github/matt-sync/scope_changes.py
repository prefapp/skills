#!/usr/bin/env python3
"""Turn a raw Upstream diff into a classified change report (the tested seam).

Given a checked-out Upstream repo and a last-checked SHA, classify every changed
path as edit-candidate / suggest-import / ignored, per issue #1 + ADR 0006.

Usage (workflow):
    python3 scope_changes.py --upstream DIR --since SHA --ours skills --out report.md
Prints the count of actionable items (edit-candidates + suggest-imports) to
stdout; writes the markdown report body to --out. Actionable == 0 means no PR.
"""
import argparse
import os
import subprocess
import sys

# Upstream categories under skills/.
IGNORED_CATEGORIES = {"in-progress", "deprecated"}
SUGGEST_CATEGORIES = {"misc", "personal"}
EDITABLE_CATEGORIES = {"engineering", "productivity"}

# The only two Upstream→ours renames; every other skill maps by identical name.
RENAMES = {
    "code-review": "review",
    "setup-matt-pocock-skills": "setup-workflow",
}


def skill_of(path):
    """(category, name) if path is inside a skills/<cat>/<name>/ dir, else None."""
    parts = path.split("/")
    if len(parts) >= 4 and parts[0] == "skills":
        return parts[1], parts[2]
    return None


def classify(path, our_skills):
    """Return (bucket, detail). bucket in {edit-candidate, suggest-import, ignored}."""
    s = skill_of(path)
    if s is None:
        return "ignored", None  # non-skill file, category README, or .out-of-scope/
    cat, name = s
    if cat in IGNORED_CATEGORIES:
        return "ignored", f"{cat}/{name}"
    if cat in SUGGEST_CATEGORIES:
        return "suggest-import", f"{cat}/{name}"
    if cat in EDITABLE_CATEGORIES:
        ours = RENAMES.get(name, name)
        if ours in our_skills:
            return "edit-candidate", (f"{cat}/{name}", ours)
        return "suggest-import", f"{cat}/{name}"
    return "ignored", f"{cat}/{name}"  # unknown category under skills/


def build_report(paths, our_skills):
    """Aggregate changed paths into deduped buckets."""
    edits = {}          # "engineering/tdd" -> "tdd"
    imports = set()     # "engineering/prototype"
    ignored = 0
    for p in paths:
        bucket, detail = classify(p, our_skills)
        if bucket == "edit-candidate":
            up, ours = detail
            edits[up] = ours
        elif bucket == "suggest-import":
            imports.add(detail)
        else:
            ignored += 1
    return {
        "edit_candidates": dict(sorted(edits.items())),
        "suggest_imports": sorted(imports),
        "ignored_count": ignored,
    }


def render_markdown(report):
    edits = report["edit_candidates"]
    imports = report["suggest_imports"]
    lines = ["## Change report", ""]
    lines.append(f"### Edit candidates ({len(edits)})")
    if edits:
        for up, ours in edits.items():
            lines.append(f"- `{up}` → our `{ours}`")
    else:
        lines.append("- none")
    lines.append("")
    lines.append(f"### Suggested imports ({len(imports)})")
    if imports:
        for up in imports:
            lines.append(f"- `{up}` (net-new / misc / personal — not added, review to import)")
    else:
        lines.append("- none")
    lines.append("")
    lines.append(f"### Ignored")
    lines.append(f"- {report['ignored_count']} paths (in-progress / deprecated / out-of-scope / non-skill files)")
    return "\n".join(lines) + "\n"


def changed_paths(upstream, since):
    """Paths changed in since..HEAD of the Upstream repo. Empty range -> []."""
    out = subprocess.check_output(
        ["git", "-C", upstream, "diff", "--name-only", f"{since}..HEAD"],
        text=True,
    )
    return [line for line in out.splitlines() if line.strip()]


def our_skill_names(ours_dir):
    return {
        name for name in os.listdir(ours_dir)
        if os.path.isdir(os.path.join(ours_dir, name))
    }


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--upstream", required=True)
    ap.add_argument("--since", required=True)
    ap.add_argument("--ours", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args(argv)

    paths = changed_paths(args.upstream, args.since)
    report = build_report(paths, our_skill_names(args.ours))
    with open(args.out, "w") as f:
        f.write(render_markdown(report))
    actionable = len(report["edit_candidates"]) + len(report["suggest_imports"])
    print(actionable)
    return 0


if __name__ == "__main__":
    sys.exit(main())
