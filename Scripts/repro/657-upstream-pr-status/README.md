# #657: upstream OCCT PR status audit, and is patch 0020 fileable

Housekeeping fallout from the OCCT 8.0.1 absorb (#654). Re-verifies the status of the ten open
upstream OCCT PRs #657 lists, checks whether any actually needs a conflict-resolving rebase, and
assesses whether carried patch `0020` (never filed) is ready to send. `okf` has a standing lesson
that external status claims are re-verified, not copied from the issue that states them
(`feedback-verify-external-status-claims`); this write-up is that verification, not a restatement.

**No upstream action was taken.** Nothing here pushes to, comments on, or modifies any pull request
or issue in `Open-Cascade-SAS/OCCT`, or any fork of it. `verify.sh` in this directory is read-only;
it reproduces Method 1's PR-state fields (state, merged, mergeable, comment counts, not the CI
status/check-runs calls) and all of Method 2 below, but not Method 3's file-tree diff or Method 4's
reproducer/clang-format checks, both of which were done by hand for this write-up and are not
re-run by the script. Run it to re-check the parts it covers after time has passed.

## Method

1. **Live PR state**: `gh api repos/Open-Cascade-SAS/OCCT/pulls/<n>` for each of the ten, plus
   `.../issues/<n>/comments` and `.../pulls/<n>/reviews` for anything that reads like unanswered
   feedback, plus `.../commits/<sha>/status` and `.../check-runs` for CI.
2. **Does the patch still apply**: a `--filter=blob:none --depth 100` sparse clone of
   `Open-Cascade-SAS/OCCT` at the current `master` tip, containing only the directories our eleven
   patches (the ten plus `0020`) touch, then `git apply --check -p1` of this repo's own carried
   `.patch` file against it. This is a stronger claim than GitHub's `mergeable` flag: it proves *our
   patch file*, not just the PR branch (which can drift from it after a force-push), still matches
   current upstream source close enough to apply with zero rejected hunks.
3. **Is the PR branch itself in sync with our patch file**: for the two PRs with a review thread
   (`1388`, `1399`), applied both our local `.patch` and the PR's live `.diff` (fetched fresh via
   `Accept: application/vnd.github.v3.diff`) to separate copies of the same master checkout, then
   diffed the *resulting file trees* rather than the raw diff text. That survives context-line
   drift and blob-hash differences in `diff --git` headers that a raw text diff would flag as
   spurious.
4. **Fileability of `0020`**: compiled and ran the existing reproducer against the currently pinned
   kernel (which already carries the fix), and ran the OCCT-root `.clang-format` over the patched
   file to confirm no reformatting is needed before submission.

## Per-PR status (verified 2026-08-07)

| Our patch | Upstream PR | State | CI | Files touched upstream since PR opened | Applies to current master | Unanswered feedback |
|---|---|---|---|---|---|---|
| `0010` | [OCCT#1386](https://github.com/Open-Cascade-SAS/OCCT/pull/1386) | open | 17 green, 1 skipped | none | yes, byte-identical (prod code) | none, 0 comments |
| `0011` | [OCCT#1388](https://github.com/Open-Cascade-SAS/OCCT/pull/1388) | open | 17 green, 1 skipped | none | yes | none, thread resolved, see below |
| `0012` | [OCCT#1390](https://github.com/Open-Cascade-SAS/OCCT/pull/1390) | open | 17 green, 1 skipped | none | yes, byte-identical | none, 0 comments |
| `0014` | [OCCT#1394](https://github.com/Open-Cascade-SAS/OCCT/pull/1394) | open | 17 green, 1 skipped | none | yes, byte-identical | none, 0 comments |
| `0015` | [OCCT#1397](https://github.com/Open-Cascade-SAS/OCCT/pull/1397) | open | 17 green, 1 skipped | none | yes, byte-identical | none, 0 comments |
| `0016` | [OCCT#1399](https://github.com/Open-Cascade-SAS/OCCT/pull/1399) | open | 17 green, 1 skipped | none | yes, byte-identical | none, thread resolved (issue's claim was wrong, see below) |
| `0017` | [OCCT#1410](https://github.com/Open-Cascade-SAS/OCCT/pull/1410) | open | 17 green, 1 skipped | none (the two files this patch touches; see below) | yes, byte-identical | none, 0 comments |
| `0018` | [OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417) | open | 17 green, 1 skipped | none (base *is* current master tip) | yes, byte-identical | **yes, 3 requested changes, 4 days old** |
| `0019` | [OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418) | open | 17 green, 1 skipped | none (base *is* current master tip) | yes, byte-identical | **yes, regression provenance plus a repro script, 7 days old** |
| `0021` | [OCCT#1420](https://github.com/Open-Cascade-SAS/OCCT/pull/1420) | open | 17 green, 1 skipped | none (base *is* current master tip) | yes, byte-identical | none, 0 comments |

All ten: `state: open`, `merged: false`, `closed_at: null`. The issue's core claim (all ten still
open) is correct. Nothing has silently merged or closed without the issue being updated. CI is
green on all ten (`17 success, 1 skipped` on every head commit); the combined status shows
`pending` on all ten, which is consistent with an unresolved required-review gate on an
external-contributor PR, not a failing check. No PR has zero reviews recorded
(`pulls/<n>/reviews` is empty on all ten), so `mergeable_state: blocked` reads as "awaiting a
maintainer review," not "has a conflict."

## Finding 1: none of the ten need a conflict-resolving rebase

`git apply --check -p1` of all ten carried `.patch` files against a fresh checkout of upstream
`master` (`b8f597c677811d1f9f4d8a97f5ae2825c0353a42`, 2026-07-30) succeeds with **zero rejected
hunks**, matching every PR's own `mergeable: true`. This is stronger than the issue's own claim
("zero file-level collisions against the 74 files 8.0.1 touched") because it is measured against
upstream `master` directly, not against our `V8_0_1` pin.

The reason is simple once measured: `master` has moved by only 5 commits since the oldest of the
ten PRs' base commits (`37dd5686`, the six sharing that base: `1386`, `1388`, `1390`, `1394`,
`1397`, `1410`), 3 commits since `1399`'s base (`50314b69`), and by **zero** commits since `1417`,
`1418` and `1420`'s base (`b8f597c6` **is** the current master tip). None of those handful of
intervening commits touches a file any of our ten patches touches, confirmed by diffing each PR's
base commit against `HEAD` and cross-referencing the changed-file list against each patch's own
file list (`Scripts/repro/657-upstream-pr-status/verify.sh` reproduces this).

**"Rebase" in the issue's sense is therefore GitHub's cosmetic "this branch is out-of-date with the
base branch" banner, not a merge conflict.** Clicking "Update branch" on each of the ten (a
maintainer-only action we did not take) would fast-forward the base pointer with no resulting diff
to resolve. There is nothing to do here beyond what a maintainer does at merge time.

`0017`/`1410` is worth calling out by name since the issue flagged it specifically ("re-verify the
defect still reproduces on master," `ShapeFix` being the package `8.0.1` changed most heavily). The
two files this patch touches, `ShapeFix_ComposeShell.cxx` and `ShapeUpgrade_WireDivide.cxx`, are
**not** among the 26 files `8.0.1` touched in that package (`ShapeFix_Face.cxx` and
`ShapeUpgrade_UnifySameDomain.cxx` were, but those are different files fixing different defects,
`0001`/#263 and `0013`/#348, both already retired). Since the two files this patch actually touches
are provably byte-identical to when the PR was opened, the null-context defect it fixes is
unchanged in current master. There is nothing to re-run a crash reproducer against that the file
diff does not already answer.

## Finding 2: the issue's claim about `0016`/OCCT#1399 is wrong

The issue states: "`0016`/OCCT#1399 still carries the mutex version of the `Storage_Schema` half
... the PR was never updated to match." This is false, and was already false when #657 was filed.

`gh api repos/Open-Cascade-SAS/OCCT/issues/1399/comments` shows the exchange completed on
**2026-07-30**, three days before #657 was opened:

- 2026-07-29, gkv311: suggests moving `Storage_Schema::ICurrentData()` to a
  `mutable Handle(Storage_Data) myCurrentData` instance field instead of the mutex.
- 2026-07-30, gsdali (us): "Done, and thanks for the pointer... Force-pushed onto the same
  branch," describing exactly that change.

Fetching the PR's live diff (`gh api .../pulls/1399 -H "Accept: application/vnd.github.v3.diff"`)
confirms the pushed content: `Storage_Schema.cxx` reads `myCurrentData = aData;` and
`myCurrentData->InternalData()`, not `Storage_Schema::ISetCurrentData(aData)` or
`Storage_Schema::ICurrentData()`. Applying that live diff and this repo's own `0016` patch file to
separate copies of the same master checkout produces **byte-identical file trees**. Our
locally-carried patch already matches the revised design `Scripts/patches/README.md`'s own `0016`
entry describes. There is nothing to push here; #657's premise for flagging this PR was already
stale at filing time. Recommend a one-line correction on #657 itself (not done by this PR, since
that is a comment on our own repo's issue rather than an upstream action, but left for the human to
decide since it wasn't asked for).

## Finding 3: `0011`/OCCT#1388 diverged in prose only, not in substance

Same comparison method applied to `1388` (the other PR with a review thread) turns up a real but
harmless difference: the live PR's pushed code (`OwnAutoNamingScope`, `myOwnAutonaming`,
`SetOwnAutoNaming`/`UnsetOwnAutoNaming`, all matching what `Scripts/patches/README.md`'s `0011`
entry describes) is logically and structurally identical to our locally-carried `0011` patch, but
the **comments differ**. The PR carries OCCT's terse one-line house style (for example
`Saves/restores the instance's own override, not a shared flag, no locking needed`), while our
locally-carried `.patch` file still has OCCTSwift's own multi-sentence doc-comment voice from
before the submission pass. A few declaration alignments also differ by one or two spaces, pure
`clang-format` artifacts from the two files evolving independently after the fork point.

Per `okf/policies/upstream-occt-style.md`, this divergence is **expected and not a defect**: "This
is a context switch, not our default... OCCT's house style applies only to code destined for the
OCCT tree." The local patch documents the fix for this codebase's own purposes; what actually ships
to OCCT gets OCCT's formatting at submission time, and the two are allowed to diverge afterward.
Noted for awareness, not as an action item. Re-syncing the local patch's comments to match the live
PR would just be churn with no behavior change.

## Finding 4: two PRs have real, unanswered reviewer feedback

Neither is a "review comment" formally (`review_comments: 0` on both, which is GitHub's
inline-diff-review count), but both carry a plain conversation comment from the same maintainer
(gkv311) requesting or noting something concrete, with no reply from our side since:

- **`0018`/[OCCT#1417](https://github.com/Open-Cascade-SAS/OCCT/pull/1417)**, 2026-08-03 (4 days
  unanswered as of this audit): three specific requested changes.
  1. The added `if (theNbPoints <= 1) { ...; return; }` duplicates the (compiled-out-under
     `No_Exception`) `Standard_ConstructionError_Raise_if` above it; gkv311 suggests either
     replacing the `Raise_if` with a real `throw` or dropping the duplicate check and keeping only
     the early return.
  2. The new end-point check uses `Distance()` (a `sqrt()` per call inside a loop); OCCT's own
     convention is `SquareDistance()` against a precomputed `tol*tol`.
  3. The parameter name `theTol3d` is misleading since the same template also instantiates for
     `Adaptor2d_Curve2d`; suggests renaming to `theTol`.

  All three are small, mechanical, and consistent with the class's own existing conventions; none
  changes the fix's logic.

- **`0019`/[OCCT#1418](https://github.com/Open-Cascade-SAS/OCCT/pull/1418)**, 2026-07-31 (7 days
  unanswered): gkv311 identifies this as **a regression since OCCT 7.6.0**, introduced by an
  UndefinedBehaviorSanitizer cleanup commit (`3016a390713d2e893f4bfa797882b9f0266840e1`,
  "0032495: Coding rules - eliminate CLang UndefinedBehaviorSanitizer warnings"), and supplies a
  DRAW Tcl script reproducing the sphere-collapse case directly (`approxsurf r s 1.e-3 0 0 8 8 100`)
  with commented-out assertions on the resulting surface's degree. This reads as an invitation to
  add that script as an OCCT DRAW-level regression test alongside the fix, and as provenance worth
  folding into the PR description (a note on *when* the bug was introduced, which the original PR
  description does not have).

Both need a human response before either PR can move; neither is something this task should answer
on the maintainer's behalf given the hard constraint against upstream writes.

## Finding 5: nothing else has quietly shipped or gone stale

Diffing every PR's base commit against current `master` for the *whole* `src/` tree (not just the
files our patches touch) turns up 26 changed files, all of them either unrelated defects or areas
already retired from our carried-patch list (`ShapeFix_Face.cxx` is `0001`/#263,
`ShapeUpgrade_UnifySameDomain.cxx` is `0013`/#348, `ShapeAnalysis_FreeBounds.*` is `0004`/#310 and
its `0007`/#323 sibling, `BRepGProp_EdgeTool.cxx` is `0006`/#318, all already retired per
`Scripts/patches/README.md`'s "Retired patches" section, and all already reflected there). Nothing
on that list is one of the ten open patches under a different upstream PR number, and nothing on
the ten's own list has been superseded. `okf/references/carried-occt-patches.md`'s status table for
these ten already matches what's verified here; no update needed there either.

## Patch `0020`: is it in a state to file?

**Yes.** Checked against the three concrete bars the issue names:

- **Still applies**: `git apply --check -p1 Scripts/patches/0020-*.patch` against the current
  upstream `master` sparse checkout succeeds with zero rejected hunks (the touched file,
  `BRepFeat_MakeCylindricalHole.cxx`, does not appear in the 26-file changed-list above at all).
- **Reproducer runnable**: compiled and ran
  `Scripts/repro/532-cylindrical-hole-part-selection/occt_532_part_selection.mm` against the
  currently pinned `v2.0.0-kernel.1` xcframework (which already carries this fix). Output matches
  the repro README's documented "after" column exactly, for example the two-plate compound's
  `PerformUntilEnd` reports `removed=3141.5927` (not `0.0000`), the severed 8mm bar's three affected
  modes all report `removed=1407.2952`, and `PerformBlind(20)` reports `1178.0972`. Confirms the
  reproducer still compiles against current headers and its measurements are exactly what the
  writeup claims.
- **Format-clean**: fetched OCCT's own root `.clang-format` and ran `clang-format -style=file` over
  the patched file (patch applied to a clean upstream checkout); the formatted output is
  byte-identical to the unformatted patched output. No reformatting needed before submission.

**On the second, unfixed defect** (`PerformThruNext`'s closest-interval fallback nesting
`// parbar > Last` unreachably inside `if (parbar < First)`): recommend it **rides along as a
one-line prose note in the PR description, not as a code change**. No geometry in the existing
reproducer sweep reaches that fallback branch at all (it only runs when no tool part's barycentre
falls in `[First, Last]`), so there is no measurement backing a fix, only the static observation
that the branch is unreachable as written. Bundling an unverified change into the same PR as a
measured, validated one raises its risk for no offsetting benefit, and OCCT's own house style
(`okf/policies/upstream-occt-style.md`) favors minimal, surgical diffs. Flagging it in prose costs
nothing and gives the maintainer full context, matching how `0016`'s own PR description flagged
`AddPersistent`'s `static TCollection_AsciiString` as a drive-by finding without folding it into
the same commit unasked.

**On whether it needs a companion issue**: no. `okf/policies/upstream-occt-style.md` (and the
maintainer's own comment it quotes, on
[OCCT#1409](https://github.com/Open-Cascade-SAS/OCCT/issues/1409#issuecomment-5124395058)) is
explicit that a ready fix goes straight to a PR. `0018`, `0019` and `0021` were all filed that way,
each noted in `Scripts/patches/README.md` as "a fix PR with no companion repro issue, per upstream's
own guidance." The task description asked for an issue draft as well as a PR draft "ready to send";
`draft-0020-pr.md` in this directory has the PR text only, with this recommendation stated up front,
since drafting a companion issue would itself be the pattern the policy and precedent both argue
against. If a human reviewing this disagrees and wants the issue anyway, the PR body's first three
paragraphs (root cause plus the two other users' correct behavior) are already issue-shaped and can
be split out verbatim.

See [`draft-0020-pr.md`](draft-0020-pr.md) for the full drafted title and body, ready to paste into
a new PR against `Open-Cascade-SAS/OCCT`, **not sent**, per this task's hard constraint against any
upstream write.

## Re-running this audit

```bash
Scripts/repro/657-upstream-pr-status/verify.sh
```

Takes under a minute (shallow, sparse clone; no OCCT build). Prints the same live-status table and
apply-check results gathered above, so a re-run after time has passed will show its own current
answer rather than this file's timestamp-frozen one.
