---
name: prune-comments
description: Prune comments down to the few that carry a real external constraint, reshape the code their removal exposes, and offer encodings for claimed constraints.
disable-model-invocation: true
---

# Prune comments

Every comment is guilty until it matches the keep-list. Code that needs prose to be understood gets reshaped until it reads on its own.

## Scope

Use the files, directories, or diff the caller names. Otherwise use the current diff against the base branch (default `main`), working tree included. Every deletion, flag, and fix stays inside the scope.

## Keep-list

A comment survives only when it is one of:

- A legal or license header.
- Non-obvious behaviour forced by an external dependency, platform, vendor, or protocol we cannot reshape.
- `// prettier-ignore`, or a lint suppression whose rule is faulty, pedantic, or style-only.
- A doc comment defining a public API contract.
- An issue or RFC link explaining a constraint the code cannot express.

When unsure whether a clause applies, delete. Narration, banners, section dividers, commented-out code, TODOs without a live link, and workaround justifications all go.

## Steps

1. **Sweep.** Read every comment in scope and judge it against the keep-list. Touch comments only in this step; application code stays byte-identical. Done when every comment in scope is kept with its keep-list clause named, deleted, or deleted and flagged.
2. **Investigate claims.** `IMPORTANT`, `do not remove`, `too risky`, `fine for now`, `hack`, and long justifications are scent, not proof. For each, run both checks on the named symbol:
   - **How:** read the surrounding code, its callers, and what it calls. Is the claimed behaviour real and on a live path today?
   - **Why:** `git log -L <start>,<end>:<file>` and `git blame` on the lines, then the commit messages and, when `gh` is available, the PR body and linked issue (`gh pr view <n> --json title,body,closingIssuesReferences`).

   A comment survives only when it describes a foreign keep-list constraint proven true today. Doubt after the dig means delete. Never shorten a failed justification into a smaller one.
3. **Flag reshapes.** A deleted comment that explained a surprise in our own code becomes a **reshape** flag on the exact symbol: the rename, extraction, type, or redesign that makes the behaviour obvious without prose. Check every lint or type suppression (`eslint-disable`, `@ts-ignore`, `@ts-expect-error`, `# noqa`, `# type: ignore`, `//nolint`): look up the rule; when it guards correctness or safety, delete the suppression and flag the symbol it was hiding.
4. **Audit the sweep.** Read `git diff` for the sweep. Restore a deletion only when it names its exact keep-list clause and the proof from step 2. Confirm every flag points at code in scope and states a true reason, and that no application code changed. Done when each deletion and flag survives this check.
5. **Fix flags.** Fix trivial flags directly: delete the dead path, drop the unused parameter, call the real API, rename. When a flag needs a new shape, sketch it before coding: write the caller's usage first, then types and signatures with stub bodies; draft two structurally distinct sketches and keep the one with the smaller public surface. Then implement the smallest root-cause fix:
   - Fix at the first place the code makes a wrong decision, not where the symptom shows. A guard is a fix only when the state it handles is legitimate.
   - Remove every workaround the deleted comment was excusing.
   - Fix every instance of the same fault inside scope; report instances outside it as open.
   - When the root cause lies outside scope, land the smallest in-scope fix and report the rest as open.
6. **Encode constraints.** For each comment claiming `do not remove`, `do not change wording`, or `talk to X before changing` that is not a keep-list item, offer the cheapest in-scope encoding: a type, a runtime assertion, a test, or a CI lint rule. Wait for the user's approval. If approved, encode it and delete the comment. Otherwise delete the comment, report the constraint as unenforced, and sketch the out-of-scope work.
7. **Report:** files touched, deletion count, kept comments with their keep-list clause, restored comments, reshape flags (one line each), fixes landed, sketches drafted, encoding offers and outcomes, unenforced constraints, and other open work.
