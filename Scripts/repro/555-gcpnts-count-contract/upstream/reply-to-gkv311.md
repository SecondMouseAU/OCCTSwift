**Status: posted, 2026-08-10.** This is the local copy of a live comment,
[OCCT#1457 (comment)](https://github.com/Open-Cascade-SAS/OCCT/pull/1457#issuecomment-5246831466).
Everything below the rule is byte-identical to what is on the PR. The two-line drafting note that
used to sit here was stripped before posting, which is the rule in
[§7 of the upstream patch process](../../../../okf/policies/upstream-occt-patch-process.md#7-responding-to-review).

**It went to #1457, not the #1417 it was drafted for**, and the two are the same PR in every other
respect: same head branch (`fix/555-gcpnts-point-count`), same fix, same review thread to answer.
#1417 was closed at 2026-08-10T20:43:18Z with `state_reason: null` and no closing comment, the
signature of footgun A in that same policy (an amend against a shallow clone drops the parent, and
GitHub closes the PR as unrelated history the moment it is pushed). #1457 was opened on the same
branch 116 minutes later, and the reply went there.

Its opening line, "Pushed an update addressing all three points", is accurate as posted: the branch
carries `0001-gcpnts-review-fixes.patch` from beside this file, whose hunks match the landed commit
`8adab6565` apart from one blank line. #803 was filed while that was still untrue and reads as
though the reply is unsent; it is not.

---

Thank you for the review. Pushed an update addressing all three points.

**1. The `No_Exception` guard.** Took option (b), replacing `Standard_ConstructionError_Raise_if`
with the plain `if` rather than adding an unconditional `throw` alongside it. Both classes now
answer a count below 2 with `IsDone() == false`, in every build, not only one that defines
`No_Exception`: the `if` replaces the precondition check entirely rather than duplicating it below
a macro that only sometimes compiles to anything.

We build with `BUILD_RELEASE_DISABLE_EXCEPTIONS=ON`, so this was not a coin flip for us: measured
before choosing, not reasoned out. Every one of our call sites into these two classes' count-based
`initialize()` (9 across the bridge, one of them a shared static helper with 2 further callers, so
11 total) already wraps the construction in `catch (...)`, so a caller-visible degenerate-count
result is identical whether the kernel throws or returns not-done: both options were safe for us.
Our own tests (`Issue558SamplingCountBoundsTests.swift`) assert the not-done/empty-result contract
for a count of 1 across every one of those entry points, which is what a silent not-done produces
directly and what a thrown exception produces once our own `catch (...)` converts it, so neither
option changes an observable answer on our side.

We also checked whether anything in the tree calls the count-based `initialize()` with a count it
does not pre-validate: grepped `src/` for both classes outside their own `GCPnts` package. Five
production call sites and one Draw test command construct either class with a count; every one
either hardcodes it (`N = 40`, `NbOfPnts = 61`, `npt = 4`/`8`) or clamps/rejects it first
(`std::max(2, aNbPoints)`, `std::max(3, aNbSamplePoints)`, the Draw command's own
`if (aSrcNbPnts < 2) { ...; return 1; }`). So no caller in the tree can reach the degenerate
branch at all today, and neither option changes observed behavior anywhere in OCCT, on top of not
changing it for us.

Given that, we preferred (b) over (a) for a reason external to our own build: an explicit
`if (...) throw ...;` makes every OCCT-internal caller of these two classes' count-based
`initialize()` newly exception-throwing for a degenerate count, in every build, including ones built
specifically to avoid that overhead. (b) keeps the existing not-done contract, and it no longer
depends on a build flag to have that shape. We did confirm directly (compiled both variants without
`No_Exception` and probed a degenerate count on each): the current PR's guard still throws
`Standard_ConstructionError` there today; after this update, neither class throws for this input in
either build configuration.

**2. `Distance()` in a loop.** Hoisted `theTol * theTol` once above the loop as `aTol2` and compare
`SquareDistance()` against it instead of calling `Distance()` (and the implicit `std::sqrt()`) on
every candidate step.

**3. `theTol3d` renamed to `theTol`.** Renamed the parameter and checked both call sites: both are
inside `GCPnts_UniformAbscissa::initialize()` overloads that already have their own `theTol`
parameter, and both already pass it straight through (`std::max(theTol, Precision::Confusion())`)
as a plain argument expression, not through an intermediate local also named `theTol`. `Perform()` is
a free function at namespace scope, not a member of the class whose `initialize()` calls it, so there
is no enclosing scope for either `theTol` to shadow; renaming introduces no shadowing anywhere in
the file.

Re-measured the full 6766-configuration equivalence sweep (17 curve types x point counts 2-200,
both classes) after all three changes: identical to the pre-review patch, 232 changed configurations,
all of them the over-request cases, nothing else moved. Re-ran the degenerate-count sweep across
5 curve types x both classes x counts {0, 1, -3}: unchanged, `IsDone() == false` throughout, no
crash. Full downstream `swift test` suite (OCCTSwift, the consumer this was filed from) unaffected.
