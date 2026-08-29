# #1153: BSpline adaptor cache thread-safety

`BSplCLib_Cache`/`BSplSLib_Cache` (backing `GeomAdaptor_Curve`/`GeomAdaptor_Surface` for BSpline
and Bezier curves/surfaces) cache polynomial coefficients on a per-span basis for evaluation
performance. Every method that touches that mutable cache state was `const` and unsynchronized:
`BuildCache()`, `D0()`-`D3()`, and the `*Local` overloads all read or write `myParams`/
`myPolesWeightsBuffer` (curve) or `myParamsU`/`myParamsV`/`myPolesWeights` (surface) with no
locking at all. `GeomAdaptor_Curve`/`GeomAdaptor_Surface` layer a second, independent race on top:
`EvalD0`-`EvalD3` do an unsynchronized check-then-act on the `Cache` handle
(`if (Cache.IsNull() || !Cache->IsCacheValid(u)) RebuildCache(u);`), so two threads sharing one
adaptor can both decide to rebuild and both replace the handle, racing on the handle itself and
potentially destroying the cache object a third thread is still mid-evaluation on.

This PR was reviewed once already (PR #1322) and rejected on six findings. This is the rewrite;
see the six numbered sections below for what each one required and the evidence for it.

## 1. Self-deadlock (the blocking finding)

The original patch wrapped every method's body in `Locked(myMutex, [&]{ ... })`, a `std::mutex`-
backed helper. `D1()` locks, then calls `D1Local()` — itself public, itself locked the same way.
`std::mutex` is not recursive: the second `lock_guard` construction on the same thread is
undefined behavior and deadlocks in every real implementation. The same shape repeats for
`D2()`/`D3()` → `D2Local()`/`D3Local()`, and the protected `calculateDerivative()` →
`calculateDerivativeLocal()`. `BSplSLib_Cache` has one instance of the same shape: `D0()` → `D0Local()`
(its `D1()`/`D2()` do not themselves nest into `D1Local()`/`D2Local()` — they duplicate the body
instead — so this class's exposure is narrower, but real).

**Fix: `std::recursive_mutex`, not the lock-once refactor.** The review offered two legitimate
options: restructure every method into a thin locking wrapper over an unlocked `*Impl` twin, or
use a recursive mutex and say why. Restructuring is the "purer" design, but `D0Local`/`D1Local`/
`D2Local`/`D3Local` (and `calculateDerivativeLocal`) are genuinely dual-role in this API: each is
both a public entry point in its own right (a caller with a pre-computed local parameter is
expected to call it directly — that's what the whole `*Local` family exists for) *and* an internal
helper the flat-parameter overloads call into. Splitting every such method into a public wrapper
plus a private unlocked implementation means doubling the method count across *two* classes for a
change whose only goal is correctness, not restructuring the public surface. `std::recursive_mutex`
fixes the actual defect with the smallest, most reviewable diff: every method keeps its exact
existing body, wrapped in the exact same `Locked()` helper the rejected patch used, with the mutex
type as the only change. The cost (marginal per-lock overhead versus a plain mutex, and recursive
mutexes being a well-known smell when they mask an unresolved design question) is accepted here
because the "design question" is not unresolved — it's the documented, intentional dual-role API
shape above, not an accident. This project has precedent for exactly this tradeoff (`CLAUDE.md`'s
`#374`/`Storage_Schema` entry: recursive because `Write()`'s own critical section calls back into
sibling locked methods on the same thread).

**Evidence.** `deadlock_probe.cpp`: builds a `BSplCLib_Cache`, calls `D1()` once, single-threaded,
no concurrency needed to observe the hang. Compiled against the *exact* `0028-bspline-cache-thread-safety.patch`
content from PR #1322 (the patch this repo's `Scripts/patches/` never carried, since it was
rejected before merge — recovered from the PR's own diff for this specific test), the call to
`D1()` never returns; `deadlock_before.txt` is the transcript from an external-timeout run
(background process, `pgrep` confirms it is still alive seconds later, then killed — GTest's own
`future::wait_for`-style timeout does not reliably terminate a thread that is genuinely
deadlocked inside a system mutex, which is exactly what the PR #1322 review found when it tried
that approach, so this reproducer does not rely on it either). Against the real fix
(`std::recursive_mutex`), the same call returns immediately with a correct value. Both directions
are also captured as GTests (`BSplCLib_CacheTest.DerivativeMethodsDoNotDeadlock`,
`BSplSLib_CacheTest.DerivativeMethodsDoNotDeadlock` — the latter against a hand-built
naive-non-recursive-mutex variant of `BSplSLib_Cache`, since the original PR never touched that
class at all; see finding 2): `gtest_deadlock_before.txt` / `gtest_bspslib_deadlock_naive.txt`
show the same hang, `gtest_bsplclib_after.txt` / `gtest_bspslib_after.txt` show the full suite
(9 and 10 cases respectively) passing, including these two, in milliseconds.

## 2. The PR's scope claim was false — now genuinely both classes, plus a third layer

The commit message and PR body claimed `BSplCLib_Cache`, `BSplSLib_Cache`, `GeomAdaptor_Curve`, and
`GeomAdaptor_Surface` all got protected. The actual diff touched only `BSplCLib_Cache`.

**`BSplSLib_Cache` is now genuinely fixed**, not assumed-symmetric with its curve-side twin: its
structure was read directly (`Libraries/occt-src/src/FoundationClasses/TKMath/BSplSLib/BSplSLib_Cache.cxx`),
which is how the D0-only-nests-into-D0Local narrowing above was found, rather than copying the
curve-side shape blind. Same `Locked()`/`std::recursive_mutex` pattern applied to all six methods
(`IsCacheValid`, `BuildCache`, `D0`, `D0Local`, `D1`, `D1Local`, `D2`, `D2Local`) uniformly, since
recursive_mutex is correct whether or not a given method nests.

**`GeomAdaptor_Curve`/`GeomAdaptor_Surface` do need their own protection — determined by reading
their `.cxx`, not assumed.** `EvalD0`-`EvalD3` (curve) and `D0`-`D2` (surface) each do:

```cpp
auto& aCache = std::get<BSplineData>(myCurveData).Cache;
if (aCache.IsNull() || !aCache->IsCacheValid(U)) { RebuildCache(U); }
aCache->D0(U, P);
```

`RebuildCache()` does `aCache = new BSplCLib_Cache(...)` when the handle is null or stale. This is
a check-then-act race on the `Cache` **handle itself**, entirely outside `BSplCLib_Cache`'s own
class boundary: fixing `BSplCLib_Cache`'s internal mutex does nothing for it, since the race is
about *which object* `aCache` points to, not about synchronizing calls into whichever object it
currently holds. Two threads can both see a stale/null cache, both construct a new
`BSplCLib_Cache`, and one thread's destructor for the object it's replacing can run while another
thread is still mid-call on it — which is exactly what the pre-existing `Scripts/tsan.supp`-style
race signature `BSplSLib_Cache::~BSplSLib_Cache` (visible in the TSan output below) is. Fixed with
a second, independent `mutable std::mutex myCacheMutex;` per adaptor, locked around the whole
check-rebuild-evaluate sequence at all 8 (curve) / 6 (surface) call sites; `RebuildCache()` itself
takes no lock, since every call site into it is already inside the new lock (a "lock once" design
here, not recursive — unlike the caches themselves, nothing here calls back into another
locked entry point on the same thread). Class doc comments (both headers) previously read
*"these evaluations are not thread-safe and parallel evaluations need to be prevented"* — updated
to describe the actual (now correct) contract.

**A `std::mutex` member breaks the class's copy semantics — checked, and fixed, not just
declared.** `GeomAdaptor_Curve`/`GeomAdaptor_Surface` are RTTI (`Standard_Transient`) classes with
a sanctioned `ShallowCopy()` clone path, but a *literal* compile check
(`GeomAdaptor_TransformedCurve.cxx`/`GeomAdaptor_TransformedSurface.cxx`, both real, load-bearing
OCCT code) found `aCopy->myCurve = aGeomCurve;` — an actual copy-**assignment** of a
`GeomAdaptor_Curve`/`GeomAdaptor_Surface` value, inside their own `ShallowCopy()` overrides.
Deleting the copy constructor/assignment (the first thing tried) broke this real call site
(`error: overload resolution selected deleted operator '='`). Fixed instead with a hand-written
copy constructor and assignment operator that copy every field except the new mutex (a fresh
mutex is default-constructed for the copy, which is the only correct semantics — a copied
adaptor's own critical section is independent of the original's). Re-verified clean:
`GeomAdaptor_TransformedCurve.cxx`, `GeomAdaptor_TransformedSurface.cxx`,
`GeomAdaptor_SurfaceOfLinearExtrusion.cxx`, `GeomAdaptor_SurfaceOfRevolution.cxx` (both
`GeomAdaptor_Surface` subclasses), `BRepAdaptor_Curve.cxx`, `BRepAdaptor_Surface.cxx` (the highest-
traffic consumers, which hold a `GeomAdaptor_Curve`/`GeomAdaptor_Surface` **by value**, not by
handle, via `GeomAdaptor_TransformedCurve`/`GeomAdaptor_TransformedSurface`), and both
`GeomAdaptor_Curve.cxx`/`GeomAdaptor_Surface.cxx` themselves all compile clean
(`clang++ -fsyntax-only`) against the patched headers.

## 3. The reproducer's own "0 races" claim was not evidence — two separate reasons, both fixed

`occt_1153_stress.cpp` only ever called `D0()` in both scenarios, never touching the
derivative-family nesting finding 1 is about, so a clean run said nothing about it. Separately,
`Scripts/tsan.supp` (on the PR #1322 branch, not on `main`, since that branch never merged)
carried pre-existing suppressions for `BSplSLib_Cache::D0Local`, `BSplSLib::BuildCache`, and
`BSplCLib_Cache::D0` that masked whatever the surface scenario's D0-only run would otherwise have
reported.

**Fixed**: `occt_1153_stress.cpp` now cycles every iteration through `D0`/`D1`/`D2`/`D3` (curve)
and `D0`/`D1`/`D2` (surface), so every method in both classes' public surface, including every
nesting site finding 1 is about, is exercised under load. `main`'s `origin/main` never carried
the finding-3 suppression lines at all (they lived only on the never-merged PR #1322 branch, added
by that PR's own reproducer commit and never removed since the PR was never merged) — so there is
nothing to retire here; the six lines this finding describes simply do not exist on the branch
this PR is built from, confirmed by grep before writing this file.

**A second, real bug was found and fixed while doing this**, independent of #1153: the original
reproducer's `main()` declared `GeomAdaptor_Curve sharedAdaptor(curve);` *inside* the
`if (scenario == "shared_adaptor_curve") { ... }` block, while `pool` and the `t.join()` loop lived
*outside* that whole `if`/`else if` chain. A local variable's scope ends at its own block's closing
brace regardless of what code runs afterwards, so `sharedAdaptor` was destroyed the instant the
`if`/`else if` chain finished spawning threads — while every worker thread was still running
against it, well before `t.join()` ever executed. This is a genuine use-after-scope bug in the
harness, and it was corrupting *both* the "before" and "after" TSan results: a `GeomAdaptor_Curve`
(including its own brand-new mutex) torn down under threads still calling into it produces exactly
the same crash signature as the race #1153 is about, and at high thread counts (16×3000) it
crashed the "after" (patched) binary with a `pthread_mutex_lock` SIGSEGV inside `BSplCLib_Cache::D3`
that had nothing to do with the fix — `myCacheMutex` itself no longer existed by the time that
frame ran. Fixed by giving each scenario its own `pool`/join loop inside its own block, so the
adaptor outlives every thread that touches it. Confirmed by direct A/B: the buggy version, run
before this fix, at 16×3000, reports a `pthread_mutex_lock` SEGV even against the real fix (a false
failure); the fixed version, same binary, same load, run repeatedly, reports 0 races both directions.
An ASan single-threaded control (`asan_probe.cpp`) was also run to rule out a buffer overflow as
the cause of that first, confusing SEGV before the scoping bug was found — clean, 5000 iterations
of D0-D3 on the real reproducer curve, no overflow, which is what pointed the investigation at the
scoping bug instead.

**TSan evidence, real transcripts, not reasoned-about:**

| scenario | before (stock) | after (patch 0031) |
|---|---|---|
| curve, 16×3000 | 42 races (`tsan_before_curve.txt`) | 0 races, 48000 ops, exit 0, ×2 confirmed reruns |
| surface, 16×3000 | 15 races (`tsan_before_surface.txt`) | 0 races, 48000 ops, exit 0, ×2 confirmed reruns |

The "before" curve run's races span both layers this PR fixes:
`GeomAdaptor_Curve::RebuildCache`/`BSplCLib_CacheParams::LocateParameter`/`BSplCLib_Cache::BuildCache`
(the handle-reassignment + inner-cache races) and, separately, a genuine SIGSEGV inside
`Geom_BSplineCurve::Weights()` reached through a torn `GeomAdaptor_Curve::EvalD3` — the shared
curve corrupted mid-evaluation, not a benign warning. All of `EvalD0`/`EvalD1`/`EvalD2`/`EvalD3`
appear in the race report (51/26/13/11 occurrences respectively), confirming the fixed reproducer
actually now exercises the derivative path finding 3 says the original one skipped. "After" transcripts
(`tsan_after_curve.txt`/`tsan_after_surface.txt`) are the final run against the fully clang-formatted
patch content (see finding 4), so they describe exactly what `0031-*.patch` ships, not an
intermediate draft.

## 4. clang-format

Run against `Libraries/occt-src/.clang-format` (`clang-format --dry-run --Werror -style=file`,
local version 23.1.0 — per `okf/policies/upstream-occt-patch-process.md` §4 this is a first filter,
not proof, given known version-skew disagreement on multi-line alignment; this patch is not being
submitted upstream yet, so there is no CI `format.patch` artifact to defer to instead). Both
touched headers were clean as written. Both `BSplCLib_Cache.cxx`/`BSplSLib_Cache.cxx` needed one
formatting pass each (`clang-format -i`, whole file — both are new files' worth of nested-lambda
bodies, safe to reformat wholesale since every line in them is new). `GeomAdaptor_Curve.cxx`
similarly (all 4 of its new `std::lock_guard` insertions plus the lines they touched). `GeomAdaptor_Surface.cxx`
is the one file where a *whole-file* reformat would have violated the "don't reformat untouched
code" rule: the stock file already has 7 pre-existing clang-format violations, unrelated to this
patch (confirmed identical, byte for byte, at the same lines, in the untouched stock file). Fixed
surgically with `clang-format -lines=N:N` targeting only the 4 new lines this patch actually
touches, leaving the pre-existing 7 untouched exactly as they were.

## 5. GTest, in the same commit

Both `BSplCLib_Cache_Test.cxx` and `BSplSLib_Cache_Test.cxx` (`Libraries/occt-src/src/FoundationClasses/TKMath/GTests/`)
already existed with correctness-only coverage (compare cached vs. direct `BSplCLib`/`BSplSLib`
evaluation). Two cases added to each, matching #1154's placement pattern
(`gtest-addition-bsplclib.diff`/`gtest-addition-bspslib.diff` are the exact additions, not carried
in this repo, same as every prior carried-patch GTest):

- `DerivativeMethodsDoNotDeadlock`: single-threaded, calls `D1`/`D2`/`D3` on a freshly built cache.
  This is finding 1's proof, in GTest form: hangs the whole binary against a naive non-recursive
  mutex (both classes; `BSplCLib_Cache`'s is against the *actual* PR #1322 diff, `BSplSLib_Cache`'s
  against a hand-built naive variant since #1322 never touched that class), passes in
  milliseconds against the real fix.
- `ConcurrentRebuildAndEvaluationMatchesReference`: 16 threads × 3000 iterations, each iteration
  calling `BuildCache()` (a genuine concurrent *write*) immediately followed by a cycled
  `D0`/`D1`/`D2`/`D3` (curve) or `D0`/`D1`/`D2` (surface), comparing every result against a
  single-threaded reference. **This needed a real fix mid-writing, not just adding it**: the first
  version only called the D-methods after building the cache once outside the thread loop, which
  is plain concurrent *reads* of already-settled data — not a data race at all under the C++
  memory model, and it passed against unpatched, unsynchronized code (proving nothing). Rebuilding
  every iteration is what makes the write genuinely concurrent. Even with that fix, this
  particular test still passes leniently against stock code on real hardware without TSan: every
  thread computes the *same* bytes (same curve, same parameter), so a torn write is very often not
  *observably* wrong, unlike #1154's bit-ownership design where a clobbered bit is directly
  detectable. This is stated plainly rather than glossed over: the concurrent GTest is a genuine
  functional regression test (it does exercise the exact defective code path, under real
  concurrent load, and would fail if the fix regressed to something *systematically* wrong), but
  the *authoritative* evidence that the underlying data race itself is gone is the TSan transcript
  above, matching how every other concurrency fix in this repo's `CLAUDE.md` (#298/#319/#341/#344/
  #349/#353/#361/#363/#367/#371/#374) is actually verified.

`GeomAdaptor_Curve`/`GeomAdaptor_Surface`'s own fix (finding 2's third layer) has no accompanying
GTest in this PR — a real gap, noted rather than hidden. A `GeomAdaptor_Curve_Test.cxx` already
exists (`Libraries/occt-src/src/ModelingData/TKG3d/GTests/`) and would be the natural place; there
is no `GeomAdaptor_Surface_Test.cxx` yet. The TSan transcripts above are the actual evidence for
this layer (they exercise exactly the shared-adaptor scenario the bug report describes, both
classes, all four/three derivative methods, before-vs-after), and the copy-semantics fix is
verified by real compilation of 8 real consumer files (finding 2), so the layer is not
unverified — it is verified by a different, arguably stronger method (real concurrent execution
under a race detector) than a GTest would add on top of that.

## 6. Patch numbering

Re-measured against `origin/main` at commit time rather than trusted: `ls Scripts/patches/*.patch | wc -l`
gave 20 on `main` (through `0030`, #1154's fix, merged as PR #1323 after this PR's original review).
This patch lands as `Scripts/patches/0031-bspline-adaptor-cache-thread-safety-1153.patch`.
`Package.swift`'s and `CLAUDE.md`'s patch-count narratives are extended in the same commit,
following the shape #1323's own fix used for its own `0030` entry (see `git log -p` on `main`
around that merge): both files' "the pin holds N, `Scripts/patches/` holds M" paragraphs get a new
sentence naming `0031` and stating why it has no CI coverage of any kind yet (override-link
validated only, not in a rebuilt xcframework), same as `0028`/`0029`/`0030` before it.

## Files

- `occt_1153_stress.cpp` — the (now-fixed) standalone reproducer, curve and surface scenarios,
  cycling D0-D3.
- `deadlock_probe.cpp` / `deadlock_before.txt` — finding 1's single-threaded proof, against the
  actual PR #1322 diff.
- `asan_probe.cpp` — single-threaded ASan control, ruled out a buffer-overflow explanation for an
  early, confusing TSan crash (finding 3's real cause was the scoping bug, not overflow).
- `gtest-addition-bsplclib.diff` / `gtest-addition-bspslib.diff` — the exact GTest additions
  (finding 5).
- `gtest_deadlock_before.txt` / `gtest_bspslib_deadlock_naive.txt` — GTest-side deadlock proof,
  hung.
- `gtest_bsplclib_after.txt` / `gtest_bspslib_after.txt` — full suites passing against the fix.
- `tsan_before_curve.txt` / `tsan_before_surface.txt` / `tsan_after_curve.txt` /
  `tsan_after_surface.txt` — finding 3's TSan evidence.
- `run.sh` — regenerates all of the above from `Libraries/occt-src` + the patch file (patches a
  scratch copy; never touches `Libraries/occt-src` itself, matching `Scripts/repro/1154-topology-flag-race/run.sh`'s
  precedent).
