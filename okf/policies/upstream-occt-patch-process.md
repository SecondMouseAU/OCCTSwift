---
type: policy
title: Upstream OCCT patch process, start to finish
description: The full lifecycle for a carried OCCT patch. Where the work happens (one persistent branch checkout of our fork, not a clone per task), GTest by default (measured 5/5 on our own open PRs), prove it fails the OCCT way, the clang-format version-skew footgun and the format.patch fix, the two shallow-clone footguns that silently close or fake-conflict a live PR, and how to respond to review.
tags: [policy, occt, upstream, contributing, testing, git, workflow, gtest]
timestamp: 2026-08-16
---

# Upstream OCCT patch process, start to finish

[Upstream OCCT PRs: style and submission workflow](upstream-occt-style.md) covers what a PR must
satisfy: OCCT's formatting and comment style, and going straight to a PR. This is the rest of it:
where the work happens (§0), what a patch needs before it's ready, the actual formatting mechanics
(§4 below, including a version-skew footgun that has nothing to do with style), the git mechanics of
actually pushing to a live PR branch without breaking it, and how to work review comments once they
arrive. Written after a single session (2026-08-11) that worked five open PRs' review comments plus
one resubmission, and hit both git footguns below for real; §4 was added after a follow-up session
(2026-08-12) fixing one of those same PRs' "Check code formatting" CI job, and §0 after #803 replaced
the clone-per-task pattern both footguns came from.

## 0. Where the work happens: one persistent checkout of the fork

**Upstream work is done in a branch checkout of `gsdali/OCCT`, not in a clone made for the task and
thrown away afterwards.** One tree, outside every OCCTSwift checkout, shared by every worktree:

```bash
# Once per machine. Skip if the directory already exists.
git clone --filter=blob:none https://github.com/gsdali/OCCT.git ~/Projects/occt-upstream
cd ~/Projects/occt-upstream
git remote add upstream https://github.com/Open-Cascade-SAS/OCCT.git
git config remote.upstream.partialclonefilter blob:none
git config remote.upstream.promisor true
git fetch upstream master
```

Measured on 2026-08-16 when this was set up: 367 MB total, 80 MB of it `.git`, and
`git rev-parse --is-shallow-repository` answers `false` with 7136 commits reachable on
`upstream/master`. Blobless rather than shallow is the whole point: full commit history, so a
merge-base always resolves, with file contents fetched on demand.

Working a PR is then ordinary git. Every open PR's branch is already there:

```bash
cd ~/Projects/occt-upstream
git fetch origin && git fetch upstream master
git checkout fix/555-gcpnts-point-count     # the branch behind OCCT#1457
git merge-base HEAD upstream/master         # resolves; §6's footgun B cannot happen
```

**Why not `Libraries/occt-src`.** It looks like the cheap answer and is the wrong tree, on four
counts, each checked rather than assumed:

- **It is itself a shallow clone.** `Scripts/build-occt.sh:97` creates it with `git clone --depth 1`,
  and `Libraries/occt-src/.git/shallow` is present. Branching there inherits exactly the boundary
  that closed OCCT#1417.
- **It is per-worktree, and usually absent.** `Libraries/` is gitignored in its entirety, so a linked
  worktree has no `Libraries/` at all until something builds one. The checkout would be re-cloned per
  worktree, which is the thing #803 asked to avoid.
- **Its working tree is permanently dirty by design.** `build-occt.sh` applies every carried patch to
  the working tree, not to HEAD, and re-runs rely on `git apply --reverse --check` to detect that.
  Branch commits interleaved with that are a second thing mutating the same files.
- **The next kernel build refuses to run, and its own remedy destroys the branch work.**
  `build-occt.sh:110-123` reuses the tree only when `git describe --tags --exact-match HEAD` equals
  the tag it builds. A branch checkout fails that test, and the error it prints tells you to
  `rm -rf occt-src`.

So `occt-src` stays what it is: a build input pinned to a tag, left clean.

**What the checkout does not hold.** The measurement, the reproducer and the writeup stay in
`Scripts/repro/<issue>/`. They are what makes a filing land, and none of it belongs in the fork. What
moves out of `Scripts/repro/<issue>/upstream/` is the *delivery* staging: a patch file regenerated
each review round, a rewritten PR description, a test file waiting to be copied somewhere. Those
become a commit on a branch.

## 1. Root-cause and patch

Root-cause with the override-link technique (compile the changed `.cxx` standalone, link it ahead of
`libOCCT-macos.a`, no full rebuild) and [measure, don't assume](measure-dont-assume.md): read the
actual source of the class in question, not its header comment or its name. Carry the patch in
`Scripts/patches/`, one entry in `Scripts/patches/README.md` per patch; see
[Carried OCCT source patches](../references/carried-occt-patches.md) for where that lives and the
numbering rule (numbers are never reused).

## 2. Add a GTest, in the same commit

**Not optional, even if the fix looks too small to need one.** Measured on our own PRs, not assumed:
of 11 open upstream PRs as of 2026-08-10, maintainer dpasukhi asked for a GTest on every single one
that didn't already have one (5 for 5: #1410, #1432, #1435, #1445, #1447), always the same phrasing
("please add GTest to cover your changes, you can follow the logic of all exited GTests"). The one PR
that already shipped a GTest (#1386, `Intf_TangentZone_Test.cxx` / `Intf_Interference_Test.cxx`) was
never asked. Five other open PRs hadn't been reached by that review pass yet at measurement time and
are likely to get the identical ask once he gets to them. This reads as a blanket expectation, not
case-by-case discretion. Add it before submitting, or before the first review round if the PR is
already open.

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
files you touched, before every push, since it catches the bulk of real violations cheaply. **Treat a
clean local pass as a first filter, not proof.** It fails open in two different, unrelated ways:

**`.cmake` files reliably show violations that are not real**: clang-format has no CMake grammar and
misreads the syntax, so a `FILES.cmake` you only added a line to can show dozens of "violations" that
are present, byte-identical, in the pristine unmodified file too. Confirm against the pristine version
(`git show upstream/master:path/to/FILES.cmake` through the same clang-format invocation) before
treating any `.cmake` output as something to fix.

**`.cxx`/`.hxx` files show the opposite problem: a clean local pass that CI's own check still rejects,
or vice versa.** clang-format's multi-line alignment (consecutive declarations, wrapped call/
constructor arguments) is version-specific, and a local install a couple of majors off from CI's can
genuinely disagree with it on the identical input. This is not a bug in either run, it's two
formatters answering the same question differently, each correctly for its own version. Measured on
PR #1445 (2026-08-12): CI's "Check code formatting" job failed on two lines it had itself aligned one
column further right in an earlier round of review; reformatting locally with `clang-format 22.1.8`
reintroduced the exact alignment CI's own `clang-format 20.1.8` had just rejected, so running local
clang-format again would have failed the same job a second time. **The workflow's own declared
expected version can't be trusted as a target to install, either**: its version-check step greps
`clang-format --version` for `18.1.8` through PowerShell's `Select-String`, a cmdlet, and cmdlets
don't set `$LASTEXITCODE`, so the script's
`if ($LASTEXITCODE -ne 0) { exit 1 }` branches on the unrelated exit code of the previous *native*
command instead, and the check is a silent no-op regardless of what's installed. The job in question
was observed actually running clang-format 20.1.8, not the 18.1.8 the script claims to require.

Don't chase this by pinning a local clang-format version to whatever you guess CI runs. **Once the
"Check code formatting" job has run at least once (pass or fail), pull its own output instead of
reformatting locally a second time**, since it always uploads a `format-patch` artifact (an empty
diff on a pass) built from the exact binary CI ran:

```bash
gh pr checks <n> --repo Open-Cascade-SAS/OCCT              # find the failing run
gh run download <run-id> --repo Open-Cascade-SAS/OCCT --name format-patch --dir <dir>
git apply <dir>/format.patch     # apply verbatim, do not re-run clang-format on top of this
git diff                         # confirm whitespace/alignment only, nothing semantic, before committing
```

Applying CI's own patch is strictly more reliable than trying to match its clang-format version
yourself: it sidesteps the version question entirely, and it's the same diff a maintainer reviewing
the PR would get if they ran the formatter themselves.

## 5. Submit: go straight to a PR

No companion issue when the fix is in hand; see [upstream-occt-style.md](upstream-occt-style.md) for
the maintainer's own guidance on this.

## 6. Pushing to a live PR branch: the two footguns §0 exists to prevent

Both hit for real on 2026-08-11, in the same session, from the same root cause: treating a shallow
`git clone --depth 1` as harmless for a branch that's about to be amended and force-pushed. Working
in the persistent checkout from §0 removes the cause of both, since it has full commit history.
They are recorded here because the cost is not recoverable and the symptoms do not read as
"shallow", so anyone who ends up in a clone made for the occasion needs to recognise them.

**Footgun A: `--depth 1` clone + `git commit --amend` silently drops the parent, and GitHub
auto-closes the PR the instant you push it.** The raw commit object still has a `parent` line
(`git cat-file -p <sha>` shows it), but a shallow-boundary commit hides that from `git log`, and
`commit --amend` produces a **rootless** commit with no parent at all. Force-push that, and GitHub
sees zero shared history with the base and closes the PR silently: no comment, no bot message,
`state_reason: null`. This is not reversible: `gh pr reopen` fails outright once GitHub closes a PR
for unrelated histories. Symptoms that should read as "no merge base," not "big diff," if you see
them before pushing: `gh pr diff` erroring "exceeded the maximum number of files (300)," or the files
endpoint listing the whole repository as newly added.

**Footgun B: rebasing with too-shallow history reports thousands of fake conflicts across the entire
repo.** `git merge-base` can't find the branch's true common ancestor with `upstream/master` inside
the shallow window, so `git rebase upstream/master` treats it as merging two unrelated histories.
`git rebase --abort` immediately if you see this. None of the conflicts are real.

**Prevention, both: work in §0's checkout, and confirm it before you push.**

```bash
cd ~/Projects/occt-upstream
git rev-parse --is-shallow-repository   # must be false
git fetch origin && git fetch upstream master
git checkout <pr-branch>
git merge-base HEAD upstream/master     # must resolve to the PR's real base, not empty/unrelated
```

The merge-base line is the check that matters, and it is worth running against the PR's own
recorded base rather than eyeballing it. Measured on 2026-08-16 against the live OCCT#1457: the
checkout's `HEAD` was `06d807ff1`, `git merge-base HEAD upstream/master` gave `7d2efad9c`, and
`gh api repos/Open-Cascade-SAS/OCCT/pulls/1457 --jq '{head_sha, base_sha: .base.sha}'` returned
exactly those two shas.

If for some reason you are in a clone made for the occasion instead, give it real depth
(`--depth 60` at minimum, plus `git fetch --depth <n>` sized from
`gh api "repos/Open-Cascade-SAS/OCCT/compare/<base.sha>...master" --jq .ahead_by`) and run the same
merge-base check before touching anything.

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

- [Upstream OCCT PRs: style and submission workflow](upstream-occt-style.md)
- [Prove the test fails](prove-the-test-fails.md)
- [Measure, do not assume, and verify with a second construction](measure-dont-assume.md)
- [Carried OCCT source patches](../references/carried-occt-patches.md)
