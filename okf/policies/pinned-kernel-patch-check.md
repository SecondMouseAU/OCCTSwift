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

**The count is necessary and not sufficient.** At the v2.0.0 release check the count agreed
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

## Current state

The current divergence, the five unpinned patches and why each matters, is recorded in
[Carried OCCT source patches](../references/carried-occt-patches.md) and in `Package.swift`'s
manifest comment, which move when the pin moves. This policy does not restate them, because a
restated number is a copy with no update path.

## Release obligations

The release commit that re-points `Package.swift`'s `url:`/`checksum:` at a kernel carrying a
patch also retires whatever bridge-side mitigation was covering for it. Those are listed in the
[Known OCCT bugs](../references/known-occt-bugs.md) rows marked "retire when repinned" and in
`CLAUDE.md`'s Known OCCT Bugs section. A guard that outlives its kernel fix turns a working call
into a refusal, and its own tests cannot signal it, because they assert the refusal.
