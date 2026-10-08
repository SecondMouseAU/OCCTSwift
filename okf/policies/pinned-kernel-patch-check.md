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
   the binary can be grepped for it; until the `v4.0.0-kernel.4` repin it was held by an
   `OCCTSWIFT_LOCAL=1`-gated test that did not run in CI, so a green `build-and-test` was not
   evidence for it, and that gate was removed when the repin made the test runnable there.
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

## There are TWO pinned kernels, and a repin owes both

Everything above is about the xcframework `Package.swift` pins for macOS and iOS. Since #2269 there
is a **second** pinned kernel: `libOCCT-wasm.a` plus its header tree, a release asset recorded in
[`Scripts/wasm-kernel-pin.txt`](../../Scripts/wasm-kernel-pin.txt). It is not a `binaryTarget`,
because SwiftPM's takes an xcframework or a zip of one and never a bare static library, so the pin
lives in that file and `Scripts/fetch-occt-wasm.sh` resolves it.

**A native repin that does not also rebuild and republish the wasm asset puts the two platforms on
different kernels.** Nothing about a macOS build, a macOS test run, `check-pinned-asset-patches.py`
or any count in this policy would notice, because every one of them reads the xcframework. The
carried patches are correctness fixes, so the failure mode is "fixed on macOS, still broken in the
browser", which is both the worst way for this to go wrong and the hardest to spot.

`Scripts/check-wasm-kernel-parity.py` is the gate. It compares the patch set the wasm pin declares
against the one `Package.swift` enumerates, and it runs in `gate-scripts` on **every** PR rather than
only when a wasm file changes. That placement is the point: **the PR that has to be caught is a
native repin, which touches `Package.swift` and no wasm path at all.**

### The acknowledgement, and why it is a count

Rebuilding the wasm kernel is a **69-minute** build, so a repin that cannot do both at once is
legitimate. The escape is two keys in the pin file:

```
OCCT_WASM_PARITY_ACKNOWLEDGED_AGAINST=<the native patch count it was decided at>
OCCT_WASM_PARITY_ACKNOWLEDGED_REASON=<why, and what closes it>
```

`AGAINST` is **the native count at the moment the divergence was accepted, not a number to bump**.
The next native repin moves the count, the acknowledgement goes stale, and the gate fires again.
That is deliberately not a boolean: an acknowledgement that never expires is a suppression, and this
repo has already been bitten by two `ACKNOWLEDGED` rows that outlived their reason (#2190). A
missing `REASON` is refused for the same reason.

The gate keeps printing both counts when it passes, so an acknowledged divergence stays visible
rather than becoming silence.

### It fired on its first real occasion, 29 seconds in

Recorded because it is the argument for the gate existing, not a hypothetical. PR #2784 published the
wasm asset for `v4.0.0-kernel.1`, twenty-nine patches. **Twenty-nine seconds later** PR #2782 repinned
native to `v4.0.0-kernel.2`, thirty patches. Neither PR was at fault: #2782 was opened before #2784
merged and could not have known a wasm asset existed, and #2784's asset matched what `Package.swift`
pinned when it was published. The browser was left without `0042`, a null-surface guard #2773
measured as a SIGSEGV on seven cases, and `main` went red within a minute. #2785 is the rebuild.

**The gate does catch a repin before it merges**, and it is worth being exact about this, because the
obvious conclusion from the story above is the wrong one. A repin PR adds a patch to
`Package.swift`'s enumeration in its own tree, so the comparison fires on that PR's own
`gate-scripts` run. Verified against the next repin rather than assumed: enumerating a hypothetical
`0043` while the wasm pin stands still produces both the divergence finding and
`An acknowledgement is present but STALE: it was written against 30 native patches and there are
now 31`.

**What let #2782 through was not the gate's placement.** `#2782`'s checks last ran on a base that did
not yet contain this gate, `#2784` then merged and added it, and `main`'s ruleset has
`strict_required_status_checks_policy` **false**, so a branch is not required to be up to date before
merging and its checks never re-ran. Every gate this repo adds has that same one-time window, and it
is not specific to wasm; see [Static gates](static-gates.md) for the mitigation.

So what remains is a process point rather than a tooling one: **nothing tells the person planning a
repin that they owe a second asset except this policy and the release step.** That is why both now
say so.

## Release obligations

The release commit that re-points `Package.swift`'s `url:`/`checksum:` runs
`python3 Scripts/check-pinned-asset-patches.py --require-asset` against the asset it is about to
pin, and records any acknowledged divergence in that script's `ACKNOWLEDGED` table and beside the
pin. That step is in `CLAUDE.md`'s Release Process, at the repin.

**It also rebuilds and republishes the wasm kernel**, attaches it to the same release as the
xcframework so one release keeps meaning one kernel on both platforms, and moves every field in
`Scripts/wasm-kernel-pin.txt`: the tag, the URL, the sha256, the byte count, the patch count and
last number, the provenance commit and the two unpacked sizes. A rebuild means attach **and** bump
both the URL and the digest, the same rule the xcframework follows. If it genuinely cannot happen in
the same PR, the acknowledgement above is the route, with an issue named in its `REASON`.

It also retires whatever bridge-side mitigation was covering for a patch the new kernel carries. Those are listed in the
[Known OCCT bugs](../references/known-occt-bugs.md) rows marked "retire when repinned" and in
`CLAUDE.md`'s Known OCCT Bugs section. A guard that outlives its kernel fix turns a working call
into a refusal, and its own tests cannot signal it, because they assert the refusal.

**It then rewrites the prose that described the kernel before it** (#3056). #3031 pinned eight
patches, and about thirty sentences across ten files went on saying "NOT built", "not pinned", "to
be deleted when this is pinned", "the pin below is now `v4.0.0-kernel.3`" or "`v4.0.0-beta.4` | not
cut" until #3054 found them by hand; a checklist written in a patch's own README entry missed two
of its four items, and review found one more after #3054. Three steps, in this order, in the repin
PR itself:

1. **Read the tense check.** `python3 Scripts/check-inventory-prose.py`: it lists every sentence
   that resolves to a patch now pinned and still calls it not-yet-pinned. It cannot see a sentence
   that names no patch.
2. **Read the kernel-tag census.** `python3 Scripts/census-stale-kernel-prose.py`: K1 is a
   `v4.0.0-kernel.N` older than the new pin written as the current one, K2 a patch count for the
   pinned asset or `Scripts/patches/` that the tree contradicts, K3 a beta called "not cut" (or
   "Cut `v4.0.0-beta.N`") whose tag exists. It is a census with a known residue of sentences that are
   stale but historical, so each finding is read, and a sentence that is deliberate history takes
   `kernel-prose-exempt: <reason>`. It cannot see a sentence that names no tag, count or beta.
3. **Grep for what neither can see**, with the old tag and the old counts as words and numerals:

   ```bash
   git grep -nE "NOT built|not (yet )?pinned|until (it|this) is pinned|when (it|this) is pinned|still in the pinned (kernel|asset)" -- . ':!docs/CHANGELOG.md' ':!Scripts/repro'
   git grep -nE "kernel\.<old K>\b|<old count in words>|<old count as a number> patches" -- . ':!docs/CHANGELOG.md' ':!Scripts/repro'
   ```

   Then read every comment that explains a bridge mitigation the repin retired (the list above), and
   `docs/v4.0.0-plan.md`'s release table, which names the next tag and the next beta.

A sentence that is history stays, and says so in its tense ("was unpinned until `v4.0.0-kernel.4`",
"measured on `kernel.2`"); the checks read that tense, so writing it correctly is also what silences
them.
