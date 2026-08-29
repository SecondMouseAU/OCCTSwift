# #1154: TopoDS_TShape::myState concurrent flag-mutation race

`TopoDS_TShape::myState` packs the shape type and eight boolean flags (Free, Modified, Checked,
Orientable, Closed, Infinite, Convex, Locked) into one plain `uint16_t`. Every getter/setter reads
or read-modify-writes it with ordinary bitwise operations (`myState & Bit_X`, `myState |= theBit`,
`myState &= ~theBit`), none of them atomic or otherwise synchronized.

A `TopoDS_TShape` is not private to one `TopoDS_Shape`: boolean operations (`BRepAlgoAPI_Fuse` and
siblings) routinely produce a result that shares edge/face TShapes with its inputs, so the same
instance is reachable from several `TopoDS_Shape` handles at once, on different threads, in ordinary
concurrent use. Two threads mutating two different flags on the same instance race on the same
16-bit word: both can read the same stale value before either writes back, and whichever write lands
last silently discards the other thread's update, a non-atomic read-modify-write lost update, not
merely a theoretical data race.

## Fix

`Scripts/patches/0030-TopoDS_TShape-myState-atomic-1154.patch`: `myState` becomes
`std::atomic<uint16_t>`. Every getter loads with `std::memory_order_acquire`; `setBit()` becomes a
`compare_exchange_weak` retry loop releasing on success. `std::atomic<uint16_t>` is confirmed (not
assumed) to be the same size and alignment as the `uint16_t` it replaces on this platform, and
always lock-free:

```
$ clang++ -std=c++17 -O2 sizeof_check.cpp -o /tmp/sizeof_check && /tmp/sizeof_check
sizeof(uint16_t) = 2
sizeof(std::atomic<uint16_t>) = 2
alignof(uint16_t) = 2
alignof(std::atomic<uint16_t>) = 2
is_always_lock_free = 1
```

No public signature changes: the flags are still `bool`, `setBit()` is still `protected` and still
takes the same two arguments. No other member's layout changes, since `myState` is the class's last
data member.

## GTest evidence (finding 3 of the PR #1323 review)

A new case, `TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost`, was added to the existing
`TopoDS_TShape_Test.cxx` (`Libraries/occt-src/src/ModelingData/TKBRep/GTests/`). `gtest-addition.diff`
in this directory is the exact addition; it is not carried in this repo (matching how `Scripts/patches/`
never carries GTest source), since `Libraries/occt-src` is a gitignored, ephemeral checkout.

The test launches seven threads against one shared `TShape*` (via `TopoDS_Builder::MakeCompound`),
each thread owning exactly one flag it alone ever writes (`Modified()` is excluded: it also clears
`Checked()` as a documented side effect, so it does not own its bit exclusively). Each thread loops
20000 times doing `Set(true); if (!Get()) ++lostUpdates; Set(false);`. Because only the owning thread
ever writes its own flag, a read of `false` immediately after that thread's own `Set(true)` can only
mean a *different* thread's concurrent write to a *different* flag clobbered the shared word — the
classic non-atomic bitfield lost update, reproducible on real hardware without needing TSan.

Compiled two ways (`clang++ -std=c++17 -O2 -I<override-or-not> -IHeaders -c ... `, linked against
the pinned `libOCCT-macos.a` plus `-lgtest -lgtest_main`, matching
`okf/policies/upstream-occt-patch-process.md` §2/§3's override-link technique):

**Unpatched** (stock header, 4 separate runs, 20000 iterations × 7 threads = 140000 writes each):

```
$ ./run_unpatched --gtest_filter=TopoDS_TShape_Test.*
...
[ RUN      ] TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost
TopoDS_TShape_Test.cxx:378: Failure
Expected equality of these values:
  aLostUpdates.load()
    Which is: 6
  0
non-atomic myState lost 6 of 140000 concurrent flag writes
[  FAILED  ] TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost (0 ms)
...
[  PASSED  ] 8 tests.
[  FAILED  ] 1 test, listed below:
[  FAILED  ] TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost
```

Repeated runs: 6, 1, 4, 2 lost updates (never 0). All eight pre-existing cases in the file pass
every time, unpatched and patched alike (`gtest_before.txt`/`gtest_after.txt` in this directory).

**Patched** (override header ahead of the xcframework's copy, 6 separate runs, one at higher load,
16000/48000 writes): always 0 lost updates, always `[  PASSED  ]` (`gtest_after.txt`).

```
$ ./run_patched --gtest_filter=TopoDS_TShape_Test.*
...
[       OK ] TopoDS_TShape_Test.ConcurrentFlagMutationsAreNotLost (34 ms)
...
[  PASSED  ] 9 tests.
```

`clang-format --dry-run --Werror -style=file:Libraries/occt-src/.clang-format` against both the
patched header and the modified test file reports zero violations (finding 4 of the review; local
clang-format 23.1.0, OCCT's own CI pins 18.1.8 — per
`okf/policies/upstream-occt-patch-process.md` §4 a clean local pass at a different major is a first
filter, not proof, but is what this task asked for).

## TSan evidence (finding 6 of the PR #1323 review)

`occt_1154_stress.cpp` in this directory is the reproducer from PR #1323 (restored to the version
that actually exercises the fixed methods — see "reproducer regression" below), with one addition:
a missing `#include <cstdarg>` `note()` needs. `run.sh` builds and runs it under ThreadSanitizer both
ways; `tsan.txt` is a captured transcript.

TopoDS_TShape's flag getters/setter/`setBit()` are all `inline`, defined entirely in the header, so
this translation unit is fully TSan-instrumented for the code path in question regardless of whether
the prebuilt archive itself was built with `-fsanitize=thread` — the same reasoning
`upstream-occt-patch-process.md` §1's override-link technique relies on for a `.cxx` fix, here
applying to a header-only one.

**Before** (stock header): both scenarios race, every run, at both light and heavy load.

```
$ ./run.sh before
--- scenario=tshape_myState_race threads=8 iterations=2000 ---
WARNING: ThreadSanitizer: data race (pid=...)
  Write of size 2 at 0x... by thread T3:
    #0 runTShapeMyStateRace(int, int, TopoDS_TShape*) occt_1154_stress.cpp:85 ...
  Previous write of size 2 at 0x... by thread T1:
    #0 runTShapeMyStateRace(int, int, TopoDS_TShape*) occt_1154_stress.cpp:85 ...
SUMMARY: ThreadSanitizer: data race occt_1154_stress.cpp:85 in runTShapeMyStateRace(int, int, TopoDS_TShape*)
ThreadSanitizer: reported 1 warnings
exit status 134 (128+SIGABRT, TSan's default when it finds a race)
--- scenario=boolean_shared_topology threads=8 iterations=3 ---
WARNING: ThreadSanitizer: data race (pid=...)
  ... runBooleanSharedTopology(int, int)::$_0 ...
SUMMARY: ThreadSanitizer: data race thread.h:168 in ... runBooleanSharedTopology(int, int)::$_0 ...
ThreadSanitizer: reported 1 warnings
exit status 134
```

Both scenarios reproduce independently: `tshape_myState_race` (one hand-picked shared `TShape*`,
direct flag calls) and `boolean_shared_topology` (a real `BRepAlgoAPI_Fuse` result sharing TShapes
with its `box`/`sphere` inputs, 8 worker threads mutating all eight flags on each shared TShape).

**After** (patch 0030 override-linked, higher load than the "before" run — 16 threads × 3000
iterations, and 12 threads × 5 rounds): zero races, clean exit, both scenarios.

```
$ ./run.sh after
--- scenario=tshape_myState_race threads=16 iterations=3000 ---
done: ops=48000 errors=0 elapsed=0.22s
exit status 0
--- scenario=boolean_shared_topology threads=12 iterations=5 ---
done: ops=60 errors=0 elapsed=0.60s
exit status 0
```

Confirmed clean across multiple separate invocations, not just one lucky run: `tshape_myState_race`
0/2 (at 8×2000 and 16×3000), `boolean_shared_topology` 0/2 (at 8×3 and 12×5), all exit 0. This is a
freshly measured re-run, not a reuse of the PR body's own unverified claim.

### Reproducer regression, found and fixed while re-verifying

The PR branch's HEAD version of `occt_1154_stress.cpp` (commit `cd5053a6`, "test: add TSan
reproducer...") had silently regressed from the working version two commits earlier (`dd50d146`):
the later commit replaced both scenarios' actual flag-mutation calls (`ts->Free(!ts->Free())` etc.)
with code that only reads `TShape()` handles and `Orientation()` (a *different* field, on
`TopoDS_Shape`, not `TopoDS_TShape::myState`), so it no longer exercised the methods the patch fixes
at all — it would report 0 races before **and** after, which is not evidence of anything. This
directory carries the working `dd50d146` version (plus the `<cstdarg>` fix), not the regressed HEAD
one, since the task is to prove the fix works, and a reproducer that cannot fail is not proof.

## Copy-constructibility (finding 5 of the PR #1323 review)

`std::atomic<uint16_t>` has no copy constructor, so `TopoDS_TShape`'s own implicitly-generated copy
constructor and copy-assignment operator become implicitly deleted. That is only a problem if
something actually copy-constructs or copy-assigns a `TopoDS_TShape` (or a concrete subclass:
`TopoDS_TVertex`/`TEdge`/`TWire`/`TFace`/`TShell`/`TSolid`/`TCompSolid`/`TCompound`) **by value**,
rather than through `occ::handle<TopoDS_TShape>` (a reference-counted smart pointer: copying the
handle copies a pointer and bumps a refcount, never the pointee).

Note that `Standard_Transient` (the base class) *does* define a working public copy constructor
("does nothing", resets the refcount to 0) and copy-assignment operator, so the design does not rule
out by-value copies elsewhere in the hierarchy in general — this had to be checked, not assumed from
"Transient types are normally handled via Handle".

**Checked two ways, both clean:**

1. **Exhaustive grep**, entire `Libraries/occt-src/src` tree (not just `TKBRep`), for
   `TopoDS_TShape` and each of the eight concrete subclass names, filtered to exclude
   `occ::handle<...>`/`Handle(...)`/pointer/reference/class-declaration/RTTI-macro/typedef-target
   occurrences. Zero by-value uses anywhere: every hit is a template type parameter (the
   `ShapePersistent`/`StdPersistent` OCAF persistence machinery, which stores type tags, not
   instances), a default constructor definition, an `IMPLEMENT_STANDARD_RTTIEXT`/`DEFINE_STANDARD_RTTIEXT`
   macro invocation, `STANDARD_TYPE(TopoDS_TShape)`, or an `OCCT_DUMP_BASE_CLASS` macro argument.

2. **Real compile check**, not just the grep: 22 `.cxx` files compiled (`-c`, no link) against the
   patched header placed ahead of the xcframework's `Headers/` on the include path — all 9 files in
   `TKBRep/TopoDS/` (the class hierarchy itself: `TopoDS_TShape.cxx` through every `TopoDS_T*.cxx`),
   plus `TopExp.cxx`, `TopExp_Explorer.cxx`, `BRepTools.cxx`, `BRep_Builder.cxx` (heavy `TopoDS_Shape`
   consumers in the same toolkit), and `BRepAlgoAPI_BooleanOperation.cxx`,
   `BRepBuilderAPI_MakeShape.cxx`, `ShapeFix_Shape.cxx` (heavy shape-producing/consuming code in
   other toolkits). All 22 compile cleanly, zero errors.

**Verdict: no copy-constructibility problem.** Nothing in the OCCT source tree copies a
`TopoDS_TShape` (or a concrete subclass) by value; every access goes through `occ::handle<...>` or a
raw pointer/reference. The patch does not need a user-provided copy constructor.
