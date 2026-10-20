---
name: occt-fix-pr
description: Step 2 of the upstream OCCT process. From an approved CASE.md with a failing GTest, write the smallest fix at the responsible component, prove it, and prepare one focused draft PR (branch, commit, PR body) against upstream IR. Derives our carried patch from the upstream commit, never the reverse. Local only; does not push.
---

# occt-fix-pr: build and test the fix, write the PR

Precondition: `occt-intake` produced `Scripts/repro/<issue>/CASE.md`, the user approved it, an upstream
issue exists (or the user waived it), and the failing GTest exists and fails for the original reason.
If any is missing, stop and say which.

Read first: `git -C upstream/occt show upstream/IR:.github/copilot-instructions.md`. These are the
write-time rules; the reviewer (`occt-review`) will check every one.

## 1. Set up

Create the worktree yourself from a freshly fetched `upstream/IR` (a worktree-isolated agent keys off the
cwd's repo and picks the wrong one): `git worktree add -b ir/<topic> ../<dir> upstream/IR`. Branch names
`ir/<topic>`. One defect per branch. Do not start from our carried-patch tree.

## 2. Write the fix

- The smallest complete change at the component CASE.md names. No cleanup, renaming or refactor beside it.
- Language and style (instructions sections 3, 5, 7, 8): ASCII only; none of the banned words; `NCollection_*`
  and `TCollection_*` rather than STL owned containers (a stream may force `std::string` at the interface,
  consume it there and go no further); native types, not `Standard_Integer` and friends; explicit types;
  `size_t` for sizes; direct includes.
- Comments state a lasting constraint in one line. They never tell the story of the bug or the old code.
- New function definitions: `//` plus 98 `=` and a blank line; no `function:` / `purpose:` banners; file-local
  helpers in an anonymous namespace; no inline method bodies in `.cxx` class declarations.
- New or materially changed declarations carry `//!` docs with `@param[in]` and `@return`.
- A throw you add must be an explicit `throw` or `*_Always_Raise_if`, because `Raise_if` is compiled out
  under `No_Exception`.

## 3. Prove it

1. The failing test now passes. Keep both outputs (before and after) in `Scripts/repro/<issue>/logs/`.
2. Revert each source hunk in turn and confirm a test fails for it. A hunk no test covers is removed or gets
   a test.
3. Run the neighbours: the module's suites and the callers CASE.md listed, with `--gtest_list_tests` first to
   confirm the tests ran. Zero matched tests is not a pass.
4. Format with the CI version: clang-format 18.1.8 (`uvx --from clang-format==18.1.8 clang-format ...`),
   `--dry-run -Werror` on every changed `.cxx` and `.hxx`.
5. Run `upstream/tools/occt-precheck.py` when it exists. Fix every MUST-FIX.

## 4. Size and focus gate

If the diff changes more than one subsystem, or more than about 300 non-test lines, or needs two root-cause
sentences, split it before writing the PR. A maintainer reads every line; fewer is kinder and merges faster
(our merged PRs were small and single-defect).

## 5. Commit and PR text

- Commit: `Group - Summary` subject in the form recent merges use; body states the problem and the violated
  contract in plain sentences. **No `Co-Authored-By`, no "Generated with", no OCCTSwift issue numbers or
  downstream citations.**
- PR body: `.github/pull_request_template.md` filled in, ASCII, B1 English, no asides to the reader.
  Problem / Proposed Solution (with the root-cause sentence) / Validation (only checks actually run; list
  what was not run) / CLA ID 1139 with the box ticked / `Closes #N` for the upstream issue.
- Open as a **draft**. Base is `IR`.

## 6. Our carried patch

Only after the upstream commit is final: derive `Scripts/patches/00NN-*.patch` from it
(`git format-patch`, adapted to the patched tree if earlier carried patches overlap). One source of truth,
so what ships in our kernel is what upstream is asked to take. The OCCTSwift PR for the patch is a separate
change and follows `carrying-occt-patches`.

## 7. Hand off

Write the branch, commit shas, PR body file, proof logs and the "not verified" list into CASE.md, then
stop. Do not push, open the PR or comment. Next step is `occt-review` by a different agent.
