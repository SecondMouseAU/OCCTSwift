---
type: policy
title: Pinned kernel patch check
description: Before trusting "the fix is in the kernel", compare Scripts/patches/ against what the release asset Package.swift pins actually holds. The count is necessary and not sufficient; match each patch's own lines against the asset, or find the CI job that proves it.
tags: [policy, occt, patches, kernel, ci, release, agents]
timestamp: 2026-09-07
---

# Pinned kernel patch check

**One OCCT version is in play.** `Scripts/build-occt.sh` builds `V8_0_1`, and `Package.swift` pins
a release asset that is that same `V8_0_1` plus whatever patches were in `Scripts/patches/` when
the asset was built. Patches land after. Any patch present in `Scripts/patches/` but absent from
the pinned asset is exercised by **no CI job at all**, because `ci.yml`'s `build-and-test` resolves
the asset rather than building from source.

## The check

Ten seconds, every time a claim rests on a kernel fix:

```bash
ls Scripts/patches/*.patch | wc -l
```

against the count in `Package.swift`'s manifest comment and in
[Carried OCCT source patches](../references/carried-occt-patches.md). If they differ, the
difference is the untested set, and any claim that a fix in it "is in the kernel" is unevidenced
until a rebuild. A divergence with a written reason is fine; a divergence without one is a finding.

**The count is necessary and not sufficient.** It is also blind in one whole direction, which is
worth stating before the ways it is imprecise in the other.

## The count compares text to text, and reads no binary

`ls | wc -l` against a number in prose, and `check-inventory-prose.py` holding that same number
consistent across `Package.swift`, `CLAUDE.md` and
[Carried OCCT source patches](../references/carried-occt-patches.md), is a closed loop over the
repo's own text. Every one of those numbers can agree with every other while the asset holds
something none of them mentions, because **nothing in that loop opens the asset**.

That is not hypothetical. The v4.0.0-kernel.1 asset holds **thirty-one** patches against a tree of
twenty-nine ([#2190](https://github.com/SecondMouseAU/OCCTSwift/issues/2190)): `0032` and the
retired `0034-LocOpe_SplitDrafts` were deleted from `Scripts/patches/` and never reverted out of
the shared `Libraries/occt-src` tree, because `build-occt.sh` applies patches idempotently and
never reverts, so a retired patch's edits survive in a working tree until somebody removes them by
hand. The build picked them up. Every count agreed. It stood for a month and was found by hand,
while looking at something else.

**The asymmetry is the lesson.** The count asks "does the asset LACK a patch we carry", which is
the question the release check was built around, because a missing fix is the failure that bites.
It cannot ask "does the asset HOLD something we do not carry", and that question has its own
failure mode: code nobody reviewed for this release, in a binary every consumer downloads, with
nothing recording that it is there.

## What catches it

`python3 Scripts/check-pinned-asset-patches.py --require-asset`, at the repin step, before the
release commit lands. It derives from each patch's own diff a shipped header line, a string
literal, a `thread_local` wrapper symbol or a name the patch introduces, and looks for each in all
three slices. It also recovers every **retired** patch from git history and looks for that, which
is the half nothing performed.

What it reports, and why it reports it that way:

- **Confirmed present.** Evidence found in every slice. Sixteen of the twenty-nine today, fifteen
  through the header rule, which is exact: the xcframework ships the patched header verbatim.
- **Not derivable.** Thirteen today. A patch that changes a comparison or reorders an argument
  contributes no name, no literal and no new reference, and `0033` contributes a function name that
  libc++ optimises out of existence at `-O2`. **Absence of a symbol is not absence of a patch**, and
  a checker reporting those thirteen as missing would be worse than no checker. The bucket is the
  point: a verdict the tool cannot reach is printed as one it cannot reach.
- **Unexpectedly present.** A retired patch found in the asset. This is what #2190 is.
- **Acknowledged.** A divergence with a written reason, in the script's `ACKNOWLEDGED` table, keyed
  on the tag `Package.swift` pins so it expires at the next repin. This policy already says a
  divergence with a written reason is fine; the table is where that reason lives for the tool as
  well as for the reader, and an acknowledgement whose patch is no longer in the asset is itself
  reported, so it cannot outlive what it described.

It reads a 157 MB archive per slice, so it is **not** a `gate-scripts` script and will not become
one: that job is pure Python over the repo's own text, with no checkout of the asset. Per #2098 it
takes `--require-asset`, so a run with no asset to read fails rather than passing on a population it
never examined.

**What it still cannot do.** It cannot sweep for arbitrary unknown content. "What else is in this
binary that no patch explains" has no answer short of rebuilding and diffing, which is the work the
check exists to avoid. It names the known stale candidates and looks for those, which converts "we
hope nothing stale is in there" into "the known stale candidates are not in there": a smaller
claim, and a true one.

**Revert the source tree when you retire a patch.** Edits left in `Libraries/occt-src` reproduce
silently at the next rebuild. Retiring a patch means deleting the file **and** reverting its edits.
The visible consequence of having cleaned the tree late is that the tree and the pinned asset no
longer agree, so a local rebuild yields a different checksum. Say so beside the pin, or the next
person spends an afternoon hunting a build difference that is not there.

## And within the count itself

At the v2.0.0 release check the count agreed
(fifteen on disk, "fifteen" in the prose) while the enumeration beside it in `Package.swift`
listed eleven, never extended past `0021`. A total and a list disagree silently, and the total is
the one everybody reads. What settles it is matching each patch's own added lines against the
pinned asset, by whichever of these applies:

1. **A patch that touches a shipped `.hxx`** can be checked directly against
   `OCCT.xcframework/*/Headers/`.
2. **A `.cxx`-only patch that adds a distinctive string literal** can be checked with `strings`
   against all three slice archives (`0026`'s throw message was confirmed this way).
3. **Anything else** needs either a green `build-and-test` (which resolves the asset) or a
   reproducer run against it. `0027` signals through `myStatus` and adds no literal, so nothing in
   the binary can be grepped for it; it is held by an `OCCTSWIFT_LOCAL=1`-gated test that does not
   run in CI, so a green `build-and-test` is not evidence for it and never was.
4. **Some patches are reachable by none of these**, because the bridge stops the defect before OCCT
   sees it. `0018` and `0023` are the two today, and `Package.swift` says so beside them.

## What `kernel-integration.yml` does and does not prove

It triggers on `Scripts/patches/**`, builds `V8_0_1` plus every carried patch from source, and runs
the full suite against that binary. So the PR that **adds** a patch gets it built, and that proves
the patch applies, compiles and regresses nothing. It cannot prove the fix works unless a
Swift-reachable assertion exists for it (a data-race fix has none without TSan instrumentation the
asset doesn't carry), and it does not run on any later PR that leaves `Scripts/patches/` alone,
which is nearly all of them. **"Read `kernel-integration.yml` instead of `ci.yml`" is not the
lesson**; that advice is what #585 discredited.

## History, so the rule reads as earned

- **#585**: the pin was an older kernel than the branch's tests were written against, so every
  test asserting a newer patch's fix failed in CI indistinguishably from a regression. Seven suites
  were red for that reason alone, and `build-and-test` went 0-for-21 on the integration branch.
- **#512**: `v2.0.0-kernel.1` held eleven patches against a tree of fourteen, and `kernel.2`
  fourteen against fifteen, within minutes of being published.
- **2026-08-17**: the v2.0.0 asset held fifteen while `0026` (#905) and `0027` (#913) sat
  untested, and `0027` landed on `main` partway through the check that found `0026`.
  `v3.0.0-kernel.1` closed it.
- **2026-09-02**: the paragraph in `CLAUDE.md` that carried this rule said "twenty-one" through
  `0031`, went stale when `0032` landed, and was caught only while writing `0033`'s entry. The
  rule is not the sentence; the rule is running the command.
- **#2190, 2026-09-23**: the first one the count could never have caught. `v4.0.0-kernel.1` held
  thirty-one patches against a tree of twenty-nine, every count in the repo agreed with every
  other, and the two extras were retired patches left in the source tree. Also in the same block:
  `Package.swift` claimed the asset was byte-identical to its predecessor "which is why `checksum:`
  below did NOT change when `url:` did", and the checksum had changed, in the same commit that
  moved the URL. Both corrected in place; `Scripts/check-pinned-asset-patches.py` is what makes
  the first one findable next time.

## Current state

The current divergence, in both directions, is recorded in
[Carried OCCT source patches](../references/carried-occt-patches.md) and in `Package.swift`'s
manifest comment, which move when the pin moves. This policy does not restate them, because a
restated number is a copy with no update path.

## Release obligations

The release commit that re-points `Package.swift`'s `url:`/`checksum:` runs
`python3 Scripts/check-pinned-asset-patches.py --require-asset` against the asset it is about to
pin, and records any acknowledged divergence in that script's `ACKNOWLEDGED` table and beside the
pin. That step is in `CLAUDE.md`'s Release Process, at the repin.

It also retires whatever bridge-side mitigation was covering for a patch the new kernel carries. Those are listed in the
[Known OCCT bugs](../references/known-occt-bugs.md) rows marked "retire when repinned" and in
`CLAUDE.md`'s Known OCCT Bugs section. A guard that outlives its kernel fix turns a working call
into a refusal, and its own tests cannot signal it, because they assert the refusal.
