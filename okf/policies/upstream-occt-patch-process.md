---
type: policy
title: Upstream OCCT patch process, start to finish
description: The full lifecycle for a carried OCCT patch. Where the work happens (one persistent tree at `upstream/occt`, PRs against `IR`, not a clone per task), GTest by default (measured 5/5 on our own open PRs), prove it fails the OCCT way, the clang-format version-skew footgun and the format.patch fix, the two shallow-clone footguns that silently close or fake-conflict a live PR, the scoped token's missing `workflow` scope, upstream CI facts, and how to respond to review.
tags: [policy, occt, upstream, contributing, testing, git, workflow, gtest]
timestamp: 2026-10-08
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

## 0. Where the work happens: `<repo>/upstream/occt`

**Upstream work is done in one persistent tree, not in a clone made for the task and thrown away
afterwards.** It is `upstream/occt` inside the OCCTSwift checkout (the `upstream/` directory is its
own working area, with its own `README.md` and `.envrc`), and it has three remotes:

| Remote | Repo | Use |
|---|---|---|
| `upstream` | `Open-Cascade-SAS/OCCT` | what PRs target; fetch `master` and `IR` from it |
| `smau` | `SecondMouseAU/OCCT` | the org fork, where PR branches are pushed |
| `origin` | `gsdali/OCCT` | the old personal fork, kept for branches pushed before 2026-09-07 |

**The scoped token is in `<repo>/upstream/.envrc`** (Keychain item `gh-token-occt-upstream`). Load it
with `eval "$(direnv export bash)"` from inside `upstream/`, or export it into your own shell; never
print it. With it, **`gh pr create` works against `Open-Cascade-SAS/OCCT`**, so there is no
browser compare-URL fallback to fall back on. The ecosystem credential in `~/Projects` is
deliberately not loaded in this tree and cannot create a cross-repo PR (it returns 403).

**The base is `IR`, not `master`.** OCCT's maintainer (dpasukhi, 2026-10-07) said `IR` is always the
integration branch and `master` is never merged into directly. A PR filed against `master` is
tolerated for older PRs, since he changes the base himself, but a new PR targets `IR`. Several PRs in
flight at once get **one `git worktree` per patch**, not one branch checked out in turn.

```bash
cd <repo>/upstream/occt
eval "$(direnv export bash)"                 # the scoped token, never echoed
git fetch upstream IR master && git fetch smau
git worktree add ../wt-<patch> -b fix/<issue>-<slug> upstream/IR
```

**The fork moved from `gsdali/OCCT` to `SecondMouseAU/OCCT` on 2026-09-07**, for the same reason
every other repo moved: the work belongs to the org, not to a personal account. Two finished patches
had sat unpushable that day because `git push` to the personal fork answered
`403 Permission to gsdali/OCCT.git denied to gsdali`, an org-scoped credential meeting a personal
remote. Branches already pushed to the old fork keep their open upstream PRs, since a PR tracks the
head repo it was opened from; move them only when a PR needs a new push.

Measured on 2026-08-16 when this was set up: 367 MB total, 80 MB of it `.git`, and
`git rev-parse --is-shallow-repository` answers `false` with 7136 commits reachable on
`upstream/master`. Blobless rather than shallow is the whole point: full commit history, so a
merge-base always resolves, with file contents fetched on demand.

Working a PR is then ordinary git. Every open PR's branch is already there:

```bash
cd <repo>/upstream/occt
git fetch smau && git fetch upstream IR master
git checkout fix/555-gcpnts-point-count     # the branch behind OCCT#1457
git merge-base HEAD upstream/IR             # resolves; §6's footgun B cannot happen
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
  the working tree, not to HEAD, and re-runs rely on `git apply --reverse --check` to detect that, and on the rule that a patch
  failing both that check and the forward one is carried when a later patch on one of its files
  reverse-checks clean (a stacked pair such as 0051 then 0055).
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

**Override-link does not apply to a PR against `IR`.** The test has to compile against `IR`'s own
headers, which have drifted from the pinned `V8_0_1`, so build `IR` itself: a full cmake build,
about 50 minutes, then run the GTest binary it produces before and after the fix. A patch that is
also carried on 8.0.1 must be **re-derived on `IR`**, not copied: test files drift (patch `0053`'s
test hunk did not apply to `IR`). The override-link recipe below remains the quick route for a patch
that is only being checked against the pinned kernel.

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

**Re-check on 2026-10-07/08, a different observation.** A local clang-format 18.1.8 matched CI's
format check on all five PRs filed that day. That is one more data point, not a retraction: it does
not show the version check works, only that 18.1.8 agreed with whatever binary CI ran on those five
files. Whether the check is still a no-op is not settled here; if a format job disagrees with a local
18.1.8 run, the `format-patch` artifact below is still the authority.

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
cd <repo>/upstream/occt
git rev-parse --is-shallow-repository   # must be false
git fetch smau && git fetch upstream IR master
git checkout <pr-branch>
git merge-base HEAD upstream/IR         # must resolve to the PR's real base, not empty/unrelated
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

## The hold on filing until OCCT 8.0.2 was cancelled (2026-10-07)

Record, not a rule. On 2026-09-21 the policy was to hold every upstream PR, and any rebase of the
open branches, until OCCT 8.0.2 shipped and `master` absorbed `IR`. The user **cancelled that hold on
2026-10-07** and directed filing against `IR`. The reason is the one the hold missed: filing and
rebasing are against `IR`, whose churn is daily, and `master` only absorbs it in batches, so there
was never a settled tree to wait for and the milestone had already slipped (due 2026-10-02, no
release branch on 2026-10-03). A repin onto 8.0.2 is a separate matter, covered in
`docs/v4.0.0-plan.md`.

The one lesson from that period that still holds: OCCT#1548 and #1549 both failed CI on 2026-09-21
and neither failure was staleness. Both patches were authored against the pinned `V8_0_1` and
forward-ported, and `V8_0_1` had diverged. #1549's `IFSelect_WorkSession.cxx:2656` had been
refactored so a textual replacement missed it; #1548's `TopoDS_TShape_Test.cxx` exists on the target
but not in `V8_0_1`, so the branch **replaced** it, deleting 295 lines of upstream tests. So: **when
forward-porting a patch authored on a pinned tree, diff every file you touch against the target
branch (`IR`) first.** A rebase does not perform that check.

## 9. Footgun: the scoped token cannot push a commit that touches workflows

**The scoped PAT lacks the `workflow` scope.** Any push whose new commits touch `.github/workflows`
is refused, and the `merge-upstream` API returns 422 for the same reason. This bit on 2026-10-07/08
because the fork's `smau/IR` had fallen five commits behind `upstream/IR`, two of them touching
workflows, so the fork's `IR` could not be brought up to date and a branch cut from it carried the
gap.

The workaround four filing agents used, which leaves the fork's `IR` alone:

1. Author and test on current `upstream/IR`.
2. Cherry-pick the commits onto the fork's (stale) `IR` for the push, so the push contains none of
   the workflow commits.
3. Open the PR against upstream `IR`.
4. Prove the merge result equals the tested tree: `git merge-tree --write-tree upstream/IR HEAD`
   must print a tree identical to the one you tested.
5. Put new tests **mid-file, not at the end**, so the cherry-pick onto the older base does not
   conflict with whatever upstream appended at the tail.

**The clean fix is a token with the `workflow` scope**, so the fork's `IR` can be synced and none of
the above is needed. That is the user's to issue.

**One agent took a different route and it is not the sanctioned one.** It pushed the fork's `IR`
using the ecosystem credential from `~/Projects`, which the `upstream/` tree deliberately does not
load. Whether that route is acceptable needs the user's decision; this page does not bless it, and an
agent should not use it unprompted.

## 10. Upstream CI facts

Observed on the five PRs filed 2026-10-07/08:

- **Two more checks than the format job.** CI also runs the license check
  (`.github/actions/scripts/validate-license.py`) and include cleanup (`cleanup-includes.py`). Both run
  locally with plain `python3`, so run them before pushing.
- **Missing includes are caught by one job.** The GCC Debug no-PCH `-Werror` job is what finds an
  include a PCH build hides. Run a no-PCH `-fsyntax-only` pass over the touched files locally.
- **`cmake .` after any `FILES.cmake` change**, or ninja does not register the new test files and the
  new test silently does not build.
- **A PR template exists**: `.github/pull_request_template.md` has Pre-Submission, Problem, Solution,
  Validation and CLA sections. The CLA claim is the user's to make; an agent leaves it for them.
- **Release builds disable exceptions.** Upstream Release builds set
  `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`, so a crash test against unpatched code dies with SIGSEGV
  rather than throwing. Run such a case in a death-test child or a fresh process, never in the main
  test process.
- **A reusable pattern for a lazy-global race** (patch `0056`): clear the global, then make the first
  use, inside a death-test child, so each iteration starts from the uninitialised state.

## Related

- [Upstream OCCT PRs: style and submission workflow](upstream-occt-style.md)
- [Prove the test fails](prove-the-test-fails.md)
- [Measure, do not assume, and verify with a second construction](measure-dont-assume.md)
- [Carried OCCT source patches](../references/carried-occt-patches.md)
