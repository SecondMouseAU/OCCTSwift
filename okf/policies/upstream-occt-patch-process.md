---
type: policy
title: Upstream OCCT patch process, start to finish
description: The full lifecycle for a carried OCCT patch — GTest by default, prove it fails the OCCT way, the two shallow-clone footguns that silently close or fake-conflict a live PR, and how to respond to review.
tags: [policy, occt, upstream, contributing, testing, git, workflow]
timestamp: 2026-08-11
---

# Upstream OCCT patch process, start to finish

[Upstream OCCT PRs — style and submission workflow](upstream-occt-style.md) covers formatting, comment
voice, and going straight to a PR. This is the rest of it: what a patch needs before it's ready, the
git mechanics of actually pushing to a live PR branch without breaking it, and how to work review
comments once they arrive. Written after a single session (2026-08-11) that worked five open PRs'
review comments plus one resubmission, and hit both git footguns below for real.

## 1. Root-cause and patch

Root-cause with the override-link technique (compile the changed `.cxx` standalone, link it ahead of
`libOCCT-macos.a`, no full rebuild) and [measure, don't assume](measure-dont-assume.md) — read the
actual source of the class in question, not its header comment or its name. Carry the patch in
`Scripts/patches/`, one entry in `Scripts/patches/README.md` per patch; see
[Carried OCCT source patches](../references/carried-occt-patches.md) for where that lives and the
numbering rule (numbers are never reused).

## 2. Add a GTest, in the same commit

**Not optional, even if the fix looks too small to need one.** Measured on our own PRs, not assumed:
of 11 open upstream PRs as of 2026-08-10, maintainer dpasukhi asked for a GTest on every single one
that didn't already have one (5 for 5), always the same phrasing. The one PR that already had one was
never asked. Add it before submitting, or before the first review round if the PR is already open.

- GTests are organized **per toolkit** (`TKShHealing`, `TKGeomAlgo`, `TKFillet`, ...), not per
  package. Check `src/<Toolkit>/GTests/` for an existing directory and `FILES.cmake` before creating
  one; several toolkits already have one with unrelated tests in it, and at least one (`TKFeat`, as
  of 2026-08-11) has the directory and an empty `FILES.cmake` waiting for a first entry.
- Name the file after the class the fix touches (`ChFi2d_Builder` fixed but crash reported through
  `BRepFilletAPI_MakeFillet2d`? Name it after whichever one the reproducer actually drives, matching
  the nearest existing sibling test's precedent rather than inventing a new convention).
- `TEST(<Class>Test, <CaseName>)`, no underscore before `Test`. Copy the nearest existing test in the
  same `GTests/` folder for the exact style: `ASSERT_*` for preconditions, `EXPECT_*` for the actual
  check, comments only where the mechanism isn't obvious, in OCCT's terse voice per
  [upstream-occt-style.md](upstream-occt-style.md), not ours.
- **Compile-check it before pushing.** `brew install googletest`, then compile the new test file
  against `Libraries/OCCT.xcframework/macos-arm64/Headers` directly:
  ```bash
  clang++ -std=c++17 -w -O0 -g -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
    -I"$(brew --prefix googletest)/include" -c path/to/New_Test.cxx -o /tmp/new_test.o
  ```
  If the fix added a new header-declared method (an inline `IsParallel()`, for instance), the local
  xcframework's headers won't have it yet; compile against a small override directory containing just
  the PR branch's updated `.hxx` files, placed **before** the xcframework headers on the `-I` path.

## 3. Prove the test fails, the OCCT way

[Prove the test fails](prove-the-test-fails.md) applies as written: inject the defect, confirm the
test fails, restore, confirm it passes, report both. For an OCCT kernel patch specifically, "inject
the defect" means override-linking the **unpatched** `.cxx` (from `upstream/master` before your
change, or with your guard hand-reverted) ahead of `libOCCT-macos.a`, then linking again with the
**patched** `.cxx` in its place:

```bash
clang++ -std=c++17 -w -O0 -g -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -c path/to/Fixed_Or_Unfixed.cxx -o /tmp/override.o
clang++ -std=c++17 -w -O0 -g /tmp/override.o /tmp/new_test.o \
  -L"Libraries/OCCT.xcframework/macos-arm64" -L"$(brew --prefix googletest)/lib" \
  -lOCCT-macos -lgtest -lgtest_main -framework Foundation -framework AppKit -lz -lc++ \
  -o /tmp/run && /tmp/run
```

**Check what the local archive already contains before trusting either run in isolation.** The
pinned `Libraries/OCCT.xcframework` can itself be ahead of, behind, or years off from any given
patch, independent of whether `Package.swift`'s own `url:`/`checksum:` are current: measured on
2026-08-11, the local archive already contained patches 0017 and 0020 but not 0022, 0023, or 0024,
despite all four being carried the same way in `Scripts/patches/`. A test that passes against the
unmodified archive is not proof the fix works; it may be proof the archive already has it. Compile
the pristine pre-fix source (`git show upstream/master:path/to/file.cxx`, from the PR's own base
commit) and override-link *that* to get a trustworthy "before" when the local archive's own state is
in doubt.

## 4. Format

`clang-format --dry-run --Werror -style=file` against OCCT's own root `.clang-format`, restricted to
files you touched. **`.cmake` files reliably show violations that are not real**: clang-format has no
CMake grammar and misreads the syntax, so a `FILES.cmake` you only added a line to can show dozens of
"violations" that are present, byte-identical, in the pristine unmodified file too. Confirm against
the pristine version (`git show upstream/master:path/to/FILES.cmake` through the same clang-format
invocation) before treating any `.cmake` output as something to fix.

## 5. Submit: go straight to a PR

No companion issue when the fix is in hand; see [upstream-occt-style.md](upstream-occt-style.md) for
the maintainer's own guidance on this.

## 6. Pushing to a live PR branch: two shallow-clone footguns

Both hit for real on 2026-08-11, in the same session, from the same root cause: treating a shallow
`git clone --depth 1` as harmless for a branch that's about to be amended and force-pushed.

**Footgun A: `--depth 1` clone + `git commit --amend` silently drops the parent, and GitHub
auto-closes the PR the instant you push it.** The raw commit object still has a `parent` line
(`git cat-file -p <sha>` shows it), but a shallow-boundary commit hides that from `git log`, and
`commit --amend` produces a **rootless** commit with no parent at all. Force-push that, and GitHub
sees zero shared history with the base and closes the PR silently: no comment, no bot message,
`state_reason: null`. This is not reversible — `gh pr reopen` fails outright once GitHub closes a PR
for unrelated histories. Symptoms that should read as "no merge base," not "big diff," if you see
them before pushing: `gh pr diff` erroring "exceeded the maximum number of files (300)," or the files
endpoint listing the whole repository as newly added.

**Footgun B: rebasing with too-shallow history reports thousands of fake conflicts across the entire
repo.** `git merge-base` can't find the branch's true common ancestor with `upstream/master` inside
the shallow window, so `git rebase upstream/master` treats it as merging two unrelated histories.
`git rebase --abort` immediately if you see this. None of the conflicts are real.

**Prevention, both:**

```bash
# Clone with real depth, always, for anything you'll amend and push.
git clone --depth 60 --branch <pr-branch> --filter=blob:none --sparse \
  https://github.com/<you>/OCCT.git repo
cd repo && git remote add upstream https://github.com/Open-Cascade-SAS/OCCT.git

# Check how far the PR's base actually is behind master BEFORE rebasing, not after.
gh api "repos/Open-Cascade-SAS/OCCT/compare/$(gh api repos/Open-Cascade-SAS/OCCT/pulls/<n> \
  --jq .base.sha)...master" --jq .ahead_by
git fetch --depth <that + margin> upstream master
git merge-base HEAD upstream/master   # must resolve to the PR's real base, not empty/unrelated
```

If you already have a rootless commit from Footgun A: recover the true parent from the pre-amend
commit's raw object (`git reflog` / `ORIG_HEAD` / `git fsck --unreachable` still finds it even after
the amend, then `git cat-file -p <thatSha>` shows its real `parent` line), rebuild correctly with
`git commit-tree <tree> -p <realParent> -F <message>`, and verify with `git diff --stat <realParent>
<newSha>` before pushing, not after. The PR itself stays closed regardless; open a fresh one from the
now-correct branch and link back to the closed one for review context.

**Before every push, whichever path got you there:**

```bash
git cat-file -p HEAD | head -3          # must show a real "parent" line
git diff --stat <trueBase> HEAD         # must show only your intended files
git push origin HEAD:<branch> --force-with-lease
```

**After pushing, poll rather than trust the first read.** GitHub's PR object (`head.sha`,
`changed_files`, `mergeable`) lags a force-push by several seconds to ~30s. Confirm the ref landed
with `git ls-remote` first, then poll `gh api repos/Open-Cascade-SAS/OCCT/pulls/<n> --jq '{state,
head_sha, changed_files, mergeable}'` until `state: open` and `mergeable: true` both show, rather than
reading a stale response as a failed push.

## 7. Responding to review

Reply addressed to the reviewer by name, in one comment per round, covering every point raised.
**Measure before agreeing to apply a suggestion, and before declining one.** A reviewer's suggestion
to "make X consistent with Y" is a hypothesis about the code, not a fact about it: on 2026-08-11,
asked to synchronize `Extrema_ExtCC2d::Points()`'s bounds check with a sibling fix, reading the actual
`Results()` implementation showed the two classes aren't built the same way (one class's counter is
an invariant with its point container, the other's isn't), so the suggested change was safe but
provably a no-op, not the fix it looked like from the outside. Applied it anyway since it cost
nothing and matched what was asked, but said what was actually measured rather than agreeing on the
premise. See [measure-dont-assume.md](measure-dont-assume.md).

Never post a file's own internal tracking notes (a "not yet posted, draft for review" header meant
for us) as part of a public comment. If a drafted reply lives in `Scripts/repro/<issue>/` from an
earlier session, strip anything above the actual reply text before using it as a `gh pr comment`
body, and check what was actually posted afterward, not just what you meant to post.

## 8. After merge

Retire the patch: delete `Scripts/patches/000N-*.patch`, move its `Scripts/patches/README.md` entry
under "Retired patches" with a note on whether the merged form matched what we carried (check the
hunks; review can change a patch between submission and merge). The kernel pin catches up at the next
`Scripts/build-occt.sh` rebuild, see `docs/guides/building-occt.md`.

## Related

- [Upstream OCCT PRs — style and submission workflow](upstream-occt-style.md)
- [Prove the test fails](prove-the-test-fails.md)
- [Measure, do not assume, and verify with a second construction](measure-dont-assume.md)
- [Carried OCCT source patches](../references/carried-occt-patches.md)
