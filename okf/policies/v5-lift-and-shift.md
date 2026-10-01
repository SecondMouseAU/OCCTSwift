---
type: policy
title: Lifting work off v5.0.0-766-execution
description: The #766 execution branch is drained onto main by lifting each PR's work as a fresh PR, never by merging the branch. The delta is taken against the PR's own base, tests and probes cross while the evidence records stay, three screens triage what is worth lifting, and the batch ends by closing what it lifted.
tags: [policy, process, v5, 766, lift, branches, agents]
timestamp: 2026-10-01
---

# Lifting work off `v5.0.0-766-execution`

`v5.0.0-766-execution` is the long-lived branch #766's 272 execution issues ran on. It is being
**drained, not merged**: each execution PR's work is read, triaged and rewritten onto `main` as a
fresh PR, in batches by domain. The branch ends when there is nothing left worth taking.

This page is the method. It existed only in issue bodies and in agent briefs regenerated per
batch, which is how batch 1 lifted five PRs and closed none of them (#2909).

## The rules

**1. Take the delta against the PR's own base, never against `main`.** An execution PR's merge-base
with `v5.0.0-766-execution` is its own branch point, usually `f01eebc8`; `main`'s merge-base with
the same head is older, and a delta taken there drags in the epic. Every lift PR body states the
merge-base it used.

**2. Never merge or cherry-pick an `exec/766-*` branch.** The work is applied by hand onto `main`.
The branch is 492 commits ahead and carries a tree `main` has decided not to take.

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

**5. Three screens triage what is left, and the first is a screen and not a verdict.**

- **Boolean-only parity density.** How many of the PR's new parity records, or added assertions,
  pin nothing but a boolean the test itself computed. Batch 1 measured 7 of 9 in the PR it
  rejected and 0 of 9 in the best one, which is where the signal comes from. **Its first false
  positive was #2487 at 18 of 29**, which survived on screen two; do not reject on density alone.
- **The injection column, which is the decisive one.** Read what each certified test was proved
  against. "The bridge function returns null, false or zero" separates a working kernel from a
  broken one and nothing else; a semantic distortion (a verdict inverted, a distance offset, a
  count off by one, a flag dropped) proves the test pins a specific answer. #2487's inversions are
  why it passed with 18 boolean-only records.
- **Laundering by deletion.** A review round that resolved a parity mismatch by deleting the
  measured side rather than explaining it (#2486, #2902). Compare the `func` name set and the
  pre-existing record set between base and head: a removal is the finding.

`Scripts/census-766-record-shape.py` and `census-766-weak-assertions.py` produce the first and
third mechanically; `Scripts/check-766-probe-reproduction.py` re-runs a cited transcript. Their
baselines are in [static-gates](static-gates.md)'s terms: none is in `gate-scripts`, because their
subject is a branch CI never checks out.

**"Evidence-fix" in a commit message is not itself a tell.** Batch 5 examined a third such pass and
found it clean: it changed `"equal": false` to `"equal": null` with a written reason, on records
whose kernel side was already N/A because a null `TopoDS_Shape` has nothing to measure. Read the
diff, not the label.

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

- [#2854](https://github.com/SecondMouseAU/OCCTSwift/issues/2854), why the records stay.
- [#2198](https://github.com/SecondMouseAU/OCCTSwift/issues/2198), the stub gate and the 72 percent.
- [prove-the-test-fails](prove-the-test-fails.md), which every lift PR satisfies on `main`'s kernel
  rather than citing the v5 branch's proof.
- [static-gates](static-gates.md), for why none of the 766 screens is in `gate-scripts`.
