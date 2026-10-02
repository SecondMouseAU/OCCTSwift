---
type: policy
title: Lifting work off v5.0.0-766-execution
description: The #766 execution branch is drained onto main by lifting each PR's work as a fresh PR, never by merging the branch. The unit of the backlog is the path and the test inside it, never the open PR, because 84 percent of the available work is in PRs already merged into the branch. The delta is taken against the PR's own base, tests and probes cross while the evidence records stay, three screens triage what is worth lifting, and the batch ends by closing what it lifted.
tags: [policy, process, v5, 766, lift, branches, agents]
timestamp: 2026-10-02
---

# Lifting work off `v5.0.0-766-execution`

`v5.0.0-766-execution` is the long-lived branch #766's 272 execution issues ran on. It is being
**drained, not merged**: each execution PR's work is read, triaged and rewritten onto `main` as a
fresh PR, in batches by domain. The branch ends when there is nothing left worth taking.

This page is the method. It existed only in issue bodies and in agent briefs regenerated per
batch, which is how batch 1 lifted five PRs and closed none of them (#2909).

## The unit is the path, not the open PR

Six batches were steered by the count of **open** PRs targeting the branch, a number that fell
through the programme and stood at 61 when #2937 measured it. It counts the wrong population.
There are three populations and only one of them was ever being counted. #2937's own measurement,
kept here as the shape of the finding rather than as a current figure:

| Population | PRs | tests `main` has weak that it has stronger | unique to it |
|---|---|---|---|
| merged into the branch | 403 | 1,210 | 1,206 |
| open | 61 | 220 | 219 |
| closed unmerged | 134, 104 heads alive | 109 | 4 |

**Every figure in that table is stale, and only the merged row has been re-measured.** It was
taken with a census that keyed each test on its function name alone, so two same-named `@Test`
functions in different suites of one file collapsed into one entry (#2949). Re-run against `main`
at `6aa5ad2` with the corrected key, the merged row's gain count was **1,229** rather than 1,210,
over the same 417 paths; three paths moved, and `StressBuilderLifecycleTests.swift` went from 12
gains to 32 and from ninth in the ranking to fifth. The open and closed-unmerged rows have
**not** been re-measured, because each needs its own head screened. Re-run before quoting any of
them. No path the old key reported at zero gain has one under the new key, so nothing a batch
declared drained on the merged population was wrongly declared.

**The merged row stands at 876 gains over 396 paths**, measured on 2026-10-02 against
`origin/main` at `e6a3b8f` and branch head `ee42388`. Most of the fall from 1,229 is the
programme working: batches have lifted that work onto `main`. A small part of it is the detector
getting honest, and the two have been separated, because the same two runs differ in nothing but
the script: the old detector reports **889 gains over 399 paths** on exactly those refs and the
corrected one reports 876 over 396. **The correction lowers the gain count**, which is worth
understanding before the next batch reads the ranking. A gain needs the head to be strictly
better, and the branch's own versions carry the same multi-line `guard` the old detector could
not see, so some of what scored ESCAPABLE-to-clean was never a gain. The transition mix moves the
same way: SEVERE-to-ESCAPABLE rises 263 to 314 while ESCAPABLE-to-clean falls 330 to 282.

So **the backlog the programme worked is 15 percent of the work**, and the merged population,
which nothing in the programme can see, is 84 percent of it. The two are near-disjoint by
construction: an open PR's commits live on its own `exec/766-*` head and are not on the branch,
while a merged PR's commits **are** the branch and appear in no open-PR list. #2271 was squash
merged, so `git log --merges` does not list it either, and `check-766-already-landed.py` takes a
PR number, so nothing would ever have pointed it at one. Its `HatchTests.swift` pins sat on the
branch for as long as the programme ran.

Measured the same day: of the 61 open PRs, **one** reaches any of the merged gains, and the
104 surviving closed-unmerged heads carry **four** gains that are nowhere else. Closed-unmerged is
therefore almost empty, which shrinks the programme rather than growing it: most of those PRs are
evidence-record corrections, and the records never cross (#2854).

**The measurement, and the ranking it produces:**

    python3 Scripts/census-766-unlifted-tests.py --prs-from <gh pr list dump> --top 40

It takes every `Tests/**` and `Scripts/repro/766-*` path that differs between `main` and the
branch, gives each the same blob verdict `check-766-already-landed.py` gives (imported, not
restated), attributes it to the PR that put it there, and then tiers every `@Test` on both sides
with `census-766-weak-assertions.py`'s detector. A **gain** is a test `main` has SEVERE or
ESCAPABLE and the branch has better. That is the quantity to carve batches out of, because it is
the quantity the programme exists to move.

Attribution over the whole ranked list is unanimous: the 417 gainful paths trace to **218 distinct
PRs and every one of them is merged**, with six paths unattributed because the difference is
`main`'s own later work rather than a commit on the branch. Not one open or closed-unmerged PR
appears.

**Rank by gain, never by PR count.** Of 1,681 differing paths, 698 are probes `main` lacks, 254
are `main`'s own later work, and 727 are test files present on both sides. Of those 727, **417
have a gain and 310 have none**: `main` is already level or ahead there, and a path differing is
not a path worth taking. Batch 6 met the reverse case too, where `main`'s `HatchTests.swift` was
weaker than the v5 base by 25 lines belonging to a third PR. Read the file.

**346 is not the remaining work, in either direction.** That is the commit count #2937 quotes,
`git log --no-merges origin/v5.0.0-766-execution ^origin/main -- Tests/ Scripts/repro/`, and it
counts commits by identity, including every one whose content `main` has already taken through a
lift rewritten rather than copied. Measuring by content gives the path and test counts above, and
both of those are the number to carve batches out of. The commit count answers nothing.

Every count the census prints is a **lower** bound. Two tests that both tier clean can still
differ, and #2937's own `islandsCutHoles` is one: the branch pins two exact half-spans `main` does
not, and the detector scores both sides the same. It has been a lower bound for four further
reasons, and three of them are now closed: the name-keyed tier map (#2949), the invisible
multi-line `guard` (#2982), the ordering tautology counted as a pin (#2985), and the same-named
helper borrowed across suites (#2964). **Three separate defects were found in one instrument in
one day**, which is why the figures on this page carry a date and a commit: re-measure, never
quote.

What is still open, and what no fix is going to reach, is in
`census-766-weak-assertions.py`'s "WHAT IT CANNOT SEE": a threshold a correct answer clears by a
whole unit (`bb.max.x - bb.min.x > 9.0` for a true span of 10, which carries a literal and so
scores as a pin), a helper one file away from its callers, and a sibling `@Test` inlined into its
neighbour. The first is a deliberate non-target, because every mechanical shape that reaches it
also reaches the tolerance comparisons the detector exists to respect; the injection
counterfactual under rule 5a is what catches it instead.

## What the first two content batches measured

#2937's prediction was that the merged population holds the work and nothing in the programme
could reach it. Batch 8 ran two lifts picked by path rather than by PR and both came back the same
way:

| batch | paths | source PRs | merged | open | SEVERE in those paths |
|---|---|---|---|---|---|
| Stress | 3 | 9 | **9** | 0 | 191 to 100 |
| Foundation | 1 | 6 | **6** | 0 | 31 to 7 |

**Fifteen source PRs, every one of them merged into the branch and invisible to an open-PR
screen.** Repo-wide the two together moved SEVERE from 1,496 to about 1,381, a frozen measurement
of the day batch 8 ran and taken with the detector as it then was. Take this as settled:
pick paths from `census-766-unlifted-tests.py`, and expect the sources to be merged PRs you cannot
close.

### The census picks candidates, and three of its shapes are not gains

A gain is a candidate, not a verdict, and batch 8 measured three ways it misleads:

* **`main` ahead but scoring worse.** `main`'s stronger version of a test carried an extra
  `guard let ... else { Issue.record; continue }`, which the detector reads as a nil-skip. Lifting
  the branch's version would have removed pins, not added them.
* **A sibling test inlined into its neighbour.** The detector inlines any same-file `func` whose
  name a test calls, so a test calling `Color.fromName(` picked up the body of the sibling
  `@Test func fromName` and inherited its `if let`. Five gains cleared themselves once the
  neighbour was fixed. Any file where a test's name is a prefix of another test's call shows this.
* **Same-named tests in different suites of one file collapsed**, because the tier map was keyed
  on the function name (#2949). `StressExhaustiveAPITests.swift` holds 112 tests and the census
  said 100. Fixed, and the same shape was then found in the detector's helper map and fixed
  there too (#2964): a test was expanded with whichever same-named helper came last in the file,
  so the four tests of `StressFormatRoundTripTests.swift`'s OBJ suite scored against the IGES
  suite's `roundTrip` and read as clean while their own helper asserts nothing. Both were
  under-reporting, and under-reporting is the one direction a census must not fail in.

The complement also holds: both batches strengthened tests the census could not count, because a
test can tier clean and still be loose. `#expect(distance > 1.0)` where the answer is 2, and
`#expect(msg != nil || msg == nil)`, both tier clean. Read around what the census points at.

## The rules

**1. Take the delta against the PR's own base, never against `main`.** An execution PR's merge-base
with `v5.0.0-766-execution` is its own branch point; `main`'s merge-base with the same head is
older, and a delta taken there drags in the epic. Measure it, do not copy the hash out of a
previous batch, and state it in the lift PR body.

This page used to add that every batch had measured that base as the same commit. **That was an
artefact of batching by domain**, and batch 8 disproved it: the six source PRs behind the
Foundation lift have **six distinct merge-bases**, and their `main drops N lines` figures climb
161, 203, 285, 370, 420, 505 because the six deltas overlap in one file. A shared base is a
property of a batch somebody assembled, never of the branch, so there is nothing to carry
forward.

**2. Never merge or cherry-pick an `exec/766-*` branch.** The work is applied by hand onto `main`.
The branch is several hundred commits ahead (492 when #2854 measured it) and carries a tree `main`
has decided not to take.

**3. What crosses and what stays.** Tests cross. `Scripts/repro/766-*` probes and transcripts
cross, with the probe compiled and its transcript committed. The
`okf/references/766-execution/` and `okf/references/766-test-validity/` records **do not**, per
[#2854](https://github.com/SecondMouseAU/OCCTSwift/issues/2854): `main` has no such tree,
`Scripts/check-test-validity.py`'s `run_sample_red_green` and `run_sample_kernel_parity` are each a
bare `return True`, no CI job runs that script on either branch, and #2198 measured that 72 percent
of the existing evidence names a bridge function that does not exist. The per-test verdicts go in
the lift PR body instead, where a closed PR keeps them at its URL. Grep every lifted file for
`okf/references/766-` and for paths `main` lacks before pushing.

**4. Step 0 is the already-landed screen, and it is a step, not diligence.**

    python3 Scripts/check-766-already-landed.py <pr> [<pr> ...]

It takes each candidate's delta against its own base and reports, per touched path, whether `main`
already holds the branch's post-image. LANDED means stop and close the source. NOT-LANDED means
read the per-file lines it prints, not lift unseen: containment is strict, so two comments `main`
dropped are enough for DIFFERENT. Run it over the whole batch before any reading. It is a blob
comparison and the script's docstring says what it cannot answer.

**DIFFERENT does not say which side moved, and that is the question.** Resolve it before reading
the branch's version at all:

    git diff <the PR's own base> origin/main -- <path>

Empty means `main` has not touched the path since the branch point, so the difference is the
branch's and the branch is the candidate. Non-empty means `main` moved, and `main` is then as
likely to be ahead as behind: batch 3 met a test whose contract `main` had legitimately changed
under it (#2769), batch 7 met a return type that became an optional (#2857), and batch 8 met a
file where `main`'s version pins strictly more while scoring worse on the detector. Taking the
branch's side without this check is how a lift becomes a regression.

It is **per candidate**, so it answers only about work somebody has already decided to look at.
It cannot find work, and pointed at a PR number it cannot reach a merged one at all. Finding what
a batch should contain is the census above, and the two are not alternatives: the census picks the
paths, this screen clears the candidate.

**5. Three screens triage what is left, and the first is a screen and not a verdict.**

- **Boolean-only parity density.** How many of the PR's new parity records, or added assertions,
  pin nothing but a boolean the test itself computed. Batch 1 measured 7 of 9 in the PR it
  rejected and 0 of 9 in the best one, which is where the signal comes from. **Its first false
  positive was #2487 at 18 of 29**, which survived on screen two; do not reject on density alone.
- **The injection column, which is the decisive one.** Read what each certified test was proved
  against. "The bridge function returns null, false or zero" separates a working kernel from a
  broken one and nothing else; a semantic distortion (a verdict inverted, a distance offset, a
  count off by one, a flag dropped) proves the test pins a specific answer. #2487's inversions are
  why it passed with 18 boolean-only records. **A Red row is not a pass either**, and on this
  population it usually meant the test was never rewritten: of the 339 merged PRs recording one,
  300 left at least one red-rowed test unchanged, and 266 of those tests are still weak on `main`
  at `9fcf0d08`, in 69 paths (#2970, ranked for a re-sweep in #2983). Those are **not** gains and
  no lift reaches them: the branch holds the same weak copy, so they have to be written rather
  than taken. Treat a certified-Red test exactly as you treat an uncertified one, per
  [prove-the-test-fails](prove-the-test-fails.md)'s "a red row is a reason to keep going".
- **Laundering by deletion.** A review round that resolved a parity mismatch by deleting the
  measured side rather than explaining it (#2486, #2902). Compare the `func` name set and the
  pre-existing record set between base and head: a removal is the finding.

`Scripts/census-766-record-shape.py` and `census-766-weak-assertions.py` produce the first and
third mechanically; `Scripts/check-766-probe-reproduction.py` re-runs a cited transcript. Their
baselines are in [static-gates](static-gates.md)'s terms: none is in `gate-scripts`, because their
subject is a branch CI never checks out.

**A corrected probe added beside the first is named so that its pair derives.** An evidence-fix
pass that re-measures something adds `probe-evidence-fix.mm` and `transcript-evidence-fix.txt` to
the directory and points the record's `source` at the second transcript.
`check-766-probe-reproduction.py` pairs a probe with its transcript, its `reproduce.json` and its
argv file by substituting the whole `probe` token, so `probe-evidence-fix.mm` is diffed against
`transcript-evidence-fix.txt` and declares in `reproduce-evidence-fix.json`; the older word order
`evidence-fix-probe.mm` / `evidence-fix-transcript.txt` resolves the same way. Any other spelling
pairs with nothing and is reported `MISSING`, which is deliberate: while the script opened
`probe.mm` and `transcript.txt` by name, thirty-nine such pairs were re-run by nothing while the
records citing them read as verified (#2934).

**"Evidence-fix" in a commit message is not itself a tell.** Batch 5 examined a third such pass and
found it clean: it changed `"equal": false` to `"equal": null` with a written reason, on records
whose kernel side was already N/A because a null `TopoDS_Shape` has nothing to measure. Read the
diff, not the label.

**5a. Report the injection counterfactual, not only the census delta.** Run the batch's own
switches against the versions you replaced. Batch 10's BndLib lift measured 14 of 19 switches
reddening nothing and 17 of 21 tests catching nothing on `main`, against zero and zero after, while
the census delta for the same batch was three SEVERE. The census still undercounts, now for the
reasons under "WHAT IT CANNOT SEE" rather than for the four defects since fixed, and the sharpest
of them is exactly a batch-10 shape: `bb.max.x - bb.min.x > 9.0` for a true span of 10 scores as
a pin and cannot fail on anything a working kernel returns. So where a batch's value is in
question the counterfactual is the honest number and it costs one more run of a harness already
built.
[Injection sweep mechanics](../references/injection-sweep-mechanics.md) has the how.

**6. A lifted test that fails on `main` is evidence, and is never weakened to make it pass.** The
v5 base and `main` pin different kernels, so a pinned value that moved is a finding about the
repin and a refusal the kernel no longer makes is a finding about the kernel. Pin what `main`
actually does and keep the original expectation as a `withKnownIssue`, which goes red when the
behaviour returns (#2908's `holeOffSurfaceReturnsNil`). Where `main` already has a stronger version
of the same test, nothing crosses and the body says so (#2918's `drillAfterFailedShell` against
#2830). Re-measuring a value to match is the thing this programme exists to remove.

**7. A batch ends by closing what it lifted.** Each source PR is closed with a comment naming the
commit on `main` that carries its work, so the record survives at the PR URL. "Do not close,
recommend" produced a queue of recommendations nobody actioned and a backlog count the programme
was steered by (#2909). Closing is the batch's last step, not the next batch's first.

**The close follows the merge, not the push.** A source PR closed while the lift is still open
points at work that may never land, and if the lift is then reworked the comment is wrong with no
one watching it. So the lifting agent names the source PRs in its PR body and comments on each,
and **whoever merges the lift closes them**, with the merge commit in hand. Batches 6 and 7 both
left this step to a later sweep and both needed one.

A merged source PR cannot be closed at all, so for the merged population the record is the comment
alone: name the source PR in the lift PR body, and comment on it with the commit on `main` that
carries its work. The branch is drained when the census reports no gain worth taking, not when the open-PR
list empties: emptying that list would leave 84 percent of the work on a branch about to be
dropped, which is the condition #2937 was filed to prevent.

## What the records' fate means for a finding about them

A defect in an evidence record on `v5.0.0-766-execution` is **not** repaired there by default. The
tree is not coming to `main`, nothing reads it, and a repair is work spent on a file with no
reader. Record the finding, check whether what it is about survives somewhere that does, and close
it when it does.

[#2902](https://github.com/SecondMouseAU/OCCTSwift/issues/2902) is the worked example. Two
measured tables were deleted from Foundation parity records to make both sides match: the
`OSD_PerfMeter` CPU table and the per-view sharp-edge counts behind `emitted_edges: 36`. Both are
verbatim on `main` today, in `Scripts/repro/766-foundation-osd-io/transcript.txt` and
`Scripts/repro/766-foundation-sheet-bom-serial/transcript.txt`, which crossed with their probes and
which `check-766-probe-reproduction.py` recompiles and diffs line by line. The measurement is
therefore in the only artefact of this family that a script verifies, and putting it back in the
record would put it in the one that nothing reads. A later salvage of the record tree finds the
damaged rows mechanically, since boolean-only-on-both-sides is `census-766-record-shape.py`'s first
channel.

## Related

- [#2937](https://github.com/SecondMouseAU/OCCTSwift/issues/2937), the three populations and the
  measurement, and `Scripts/census-766-unlifted-tests.py`, which is that measurement.
- [#2854](https://github.com/SecondMouseAU/OCCTSwift/issues/2854), why the records stay.
- [#2198](https://github.com/SecondMouseAU/OCCTSwift/issues/2198), the stub gate and the 72 percent.
- [prove-the-test-fails](prove-the-test-fails.md), which every lift PR satisfies on `main`'s kernel
  rather than citing the v5 branch's proof.
- [static-gates](static-gates.md), for why none of the 766 screens is in `gate-scripts`.
