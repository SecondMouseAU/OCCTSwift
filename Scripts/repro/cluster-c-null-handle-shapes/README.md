# Cluster C census (#666): teaching the null-handle checker the #656 shape

This directory is the census only. It does not fix #636, #643 or #644, Cluster C's three members.

## The shared root, and why this census is a checker upgrade rather than a new probe

`Scripts/check-null-handle-guards.py` already gates this family and runs in CI's `gate-scripts`
job. It verifies that a bridge function guards its own `OCCTCurve3DRef`/`OCCTCurve2DRef`/
`OCCTSurfaceRef` *argument* - both the wrapper pointer and the `Handle` inside it - before passing
it to OCCT. #656 (`OCCTBRepToolsEvalAndUpdateTol`, already fixed on this branch) proved the checker
blind to a second, independent origin for a risky handle: one fetched locally, mid-body, from
`BRep_Tool::CurveOnSurface(edge, face, ...)`, never a wrapper argument at all, and handed straight
to `BRepTools::EvalAndUpdateTol`, which dereferences it unconditionally. Every existing check
reported that function clean while it SIGSEGV'd on ordinary topology.

The job here is to teach the checker that shape, then let it enumerate the rest of the family for
free - which is worth more than fixing the three known members by hand.

## Method

One artifact, not two independent halves like Cluster A/B: there is no dynamic Swift-level
behaviour to census here (see "Does this belong in the shared `Censuses` target?" below). The
method is:

1. **Baseline.** Run the checker and its `--self-test` as they stand, before any change.
2. **Design the new shape from the one proven instance (#656), then measure its true scope.**
   "Any local `Handle` initialised from any call" was tried first and matched 672 declarations
   tree-wide - almost all `new T(...)` (never null), a same-family `DownCast` (null-safe by
   construction, and this bridge's own established `Copy()`+`DownCast` cloning idiom), or a
   builder's post-success result accessor. None of those is #656's shape, and auditing 672 by hand
   would have been a bigger, less careful repeat of #618's own "blind to indirection" mistake with
   a different indirection. Narrowing the producer to `BRep_Tool::` cut it to 63 real declarations
   of the three tracked types (`Handle(Geom_Curve)`/`Handle(Geom2d_Curve)`/`Handle(Geom_Surface)`,
   `occ::handle<>` spelling included). At least two members of that family document the null
   themselves - `BRep_Tool.hxx`'s `Curve` ("May be a Null handle") and `CurveOnSurface` ("Returns
   a NULL handle if this curve does not exist") - but not all: `Surface(const TopoDS_Face&)`'s own
   doc comment says only "Returns the geometric surface of the face," no null mentioned anywhere.
   Tracking `Geom_Surface` through this walk anyway is the right conservative over-approximation -
   #656's own defect involved `Surface` too, alongside `Curve` and `CurveOnSurface` - but the
   claim should say what was verified, not what would be tidy: `BRep_Tool::` is tracked as a
   family because that is the natural boundary this bridge's own accessor usage falls into, not
   because every member of it documents a null return.
3. **Reuse, don't reinvent, the existing classification.** Once a local is tracked, it goes through
   the exact same `classify()` - the same DownCast exclusion, the same guarding-helper exclusion -
   that the wrapper-argument walk already uses and this repo's prior censuses (#618, #624/#630)
   already hardened. The only new machinery is finding the declarations and fencing their scope
   (see "Two things a wrapper argument never needed" below).
4. **Prove the design against the one instance we know is real**, not just synthetic fixtures:
   reverting `OCCTBRepToolsEvalAndUpdateTol` to its pre-#656 state (guarding `c3d`/`surf` but not
   `c2d`) and confirming the upgraded detector reports `c2d` unguarded - the actual historical bug,
   not a stand-in for it.
5. **Run the upgraded checker over the real tree and triage every new finding**, per #666's own
   instruction that a new finding is not automatically a defect: an OCCT call that copes (returns
   normally, or raises a catchable `Standard_Failure` the surrounding `catch (...)` already
   handles) is noise, not a bug, and gets an `ALLOWED` entry with a measured reason, matching
   #556/#618's own standard.
6. **Guard-removal matrix.** Every new conditional the upgrade introduces - not just the MISSED/CLEAN
   fixture pass rate - is individually neutered and the self-test and real report are re-measured,
   per this repo's `okf/policies/prove-the-test-fails.md` and Cluster A's own finding that a
   `--self-test` can pass 6/6 while several of its guards have zero real coverage.

```bash
python3 Scripts/check-null-handle-guards.py
python3 Scripts/check-null-handle-guards.py --self-test
```

## Baseline (before this census)

```
$ python3 Scripts/check-null-handle-guards.py --self-test
... 12/12 cases correct
$ python3 Scripts/check-null-handle-guards.py
All bridge functions guard the geometry handle as well as the wrapper pointer.
(23 site(s) exempt by name in ALLOWED, each with its reason.)
```

Zero unguarded sites, because the checker had no way to look for the #656 shape at all - not
because nothing like it existed. #656 itself was already fixed on this branch before this census
started, so "0 unguarded" at baseline is not evidence of anything; it is the blind spot itself.

## What was taught, and what each newly finds

### Shape 1 (mandatory): a local handle obtained from `BRep_Tool::`, not a wrapper argument

`local_handle_sites()` in the checker. Scope: `Handle(Geom_Curve)`/`Handle(Geom2d_Curve)`/
`Handle(Geom_Surface)` (or `occ::handle<>` spelling) declared as `name = BRep_Tool::Whatever(...)`.

**Measured over the real tree: 63 declarations, 62 already guarded, 1 not.**

The one: `OCCTGeomFillCoonsAlgPatchEval` (`OCCTBridge_Surface.mm:2375`), inside a local lambda,
builds `new GeomAdaptor_Curve(curve, f, l)` from a `curve` obtained via `BRep_Tool::Curve` with no
`IsNull()` check. Triaged as **measured-safe, not a defect**: `probe_cluster_c.mm` PART 1 confirms
`GeomAdaptor_Curve` raises a catchable `Standard_Failure` on a null `Handle(Geom_Curve)`, on both
the 1-arg and the 3-arg (trimmed) constructor form used here - the same verdict #618 already
recorded in `ALLOWED` for `OCCTExtremaExtCC`'s wrapper-argument call to the same constructor, now
confirmed for a curve arriving by this second route too:

```
$ /tmp/probe_cluster_c   (built from Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm)
PART 1: GeomAdaptor_Curve on a null Handle(Geom_Curve) (ALLOWED entry for OCCTGeomFillCoonsAlgPatchEval)

  GeomAdaptor_Curve(nullCurve) [1-arg, whole curve]                    Standard_Failure (catchable)
  new GeomAdaptor_Curve(nullCurve, 0.0, 1.0) [3-arg, trimmed]          Standard_Failure (catchable)
  new GeomAdaptor_Curve(nullCurve, 0.0, 1.0) then ->Value(0.5)         Standard_Failure (catchable)
```

Added to `ALLOWED`:

```python
('OCCTBridge_Surface.mm', 'OCCTGeomFillCoonsAlgPatchEval'):
    'measured #666 (Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm): '
    'GeomAdaptor_Curve raises a catchable Standard_Failure on a null Handle(Geom_Curve), on '
    'both the 1-arg and the 3-arg (trimmed) constructor - same verdict #618 already recorded '
    'for OCCTExtremaExtCC, now confirmed for a curve obtained from BRep_Tool::Curve rather '
    'than a wrapper argument',
```

The other 62 already guard their local before the first dereferencing use, including
`OCCTBRepToolsEvalAndUpdateTol` itself (`c3d`, `c2d`, `surf`, all three now correctly recognised
GUARDED).

**Two mechanisms this shape needed that the wrapper-argument walk did not**, both found by testing
the design against a REAL function rather than trusting the fixtures alone:

- **A producer allowlist, not "any call."** Covered above. The 672-vs-63 gap is itself evidence:
  most locally-obtained handles in this bridge are safe by construction or by an existing
  post-success check, and a detector that flagged all 672 would have buried one real finding in
  hundreds of false ones - the same failure shape as #618's own "blind to indirection" bug, just
  inverted (too broad instead of too narrow).
- **A scope fence.** This bridge reuses generic local names (`surf`, `curve`, `pcurve`) across
  sibling blocks in one function - most visibly a `switch` with one `Handle(Geom_Surface) surf =
  BRep_Tool::Surface(...)` per `case`. An early version of this detector, built and run against the
  real tree before any self-test fixture was written for it, mistook `OCCTFaceGetPrimaryAxis`'s
  **second** `case`'s properly-guarded `surf` for a continuation of the **first** `case`'s `surf`
  (consumed only by `DownCast`, itself null-safe) and reported the first as unguarded - a false
  positive that would not have survived review, caught here before it shipped rather than after.
  Fixed by treating a later `Handle(...) name = ...` redeclaration of the identical name, anywhere
  later in the same function body, as the end of the earlier declaration's own tracking window.

### Shape 2: `extern "C"` on the definition line no longer hides the function

One-line `FUNC` regex fix (an optional `extern\s*"C"\s*` prefix). CLAUDE.md's own blind-spot list
named this with "zero occurrences today," confirmed still true by grep - this is pure hardening,
not a live finding. Real report is unchanged (0 unguarded, same 62/63 split); a dedicated MISSED
fixture (`extern "C" int OCCTFixtureN(...)`) is what proves the parser can now see through it.

### Shape 3 (follow-up, maintainer-approved, same PR): the constructor-init connector and the `occ::handle<>` fixture gap

Two hardening fixes to `local_handle_sites()` added after the maintainer's own review measured
both against the real tree and found **zero occurrences of either**, which is why they land here
rather than as a separate PR: neither can turn the gate red, and the cost is one regex alternation
plus two fixtures.

**Finding 1: the constructor-init connector.** `LOCAL_HANDLE_DECL` required `name = BRep_Tool::
...(`. It never matched `name(BRep_Tool::...(` - #656's exact shape, written with parens:

```cpp
Handle(Geom2d_Curve) c2d(BRep_Tool::CurveOnSurface(edgeRef->shape, faceRef->shape, first, last));
return BRepTools::EvalAndUpdateTol(edgeRef->shape, c2d, first, last);
```

The module docstring already warned this exact spelling defeats the WRAPPER-ARGUMENT alias binding
(`Handle(Geom_Curve) w(wrapper->curve);`, `aliases()`'s own blind spot, unrelated to and unchanged
by this fix) - it applied equally to the new local-handle mechanism and was simply not checked
there before this pass. Fixed by widening the connector between the variable name and the producer
call from `=` to `(?:=|\()`, which handles both forms with one alternation since the text after the
connector (`BRep_Tool::Whatever(`) is identical either way.

**Finding 2: `occ::handle<>` had no fixture for a LOCAL declaration.** The regex and docstring both
claimed `occ::handle<Geom_Curve> curve = BRep_Tool::Curve(...)` is tracked identically to the
`Handle(Geom_Curve)` spelling - and it already was, correctly, with no code change needed - but no
fixture had ever exercised that spelling for a local; the existing `occ::handle<>` fixture (S, the
bridge-helper one) only uses it for a helper's *parameter* type. Per this PR's own measure-before-
you-trust standard, an untested claim of coverage is not coverage. Added a dedicated fixture.

Measured before writing either fixture, per the maintainer's own zero-site claim:

```
local, BRep_Tool producer, constructor-init paren form      : 0 occurrences
occ::handle<> local declaration with a BRep_Tool producer    : 0 occurrences
```

Confirmed. Real report stayed at 0 unguarded, same 24 `ALLOWED` entries, both before and after -
teaching either shape reported nothing new, exactly as the zero-site measurement predicted.

Self-test 19/19 -> 21/21 (two new MISSED fixtures, `T` and `U`); guard-removal proof for both is
in the extended matrix below.

### Found, deliberately not taught: a fifth alias form, with three real, live SIGSEGVs

While confirming there was nothing else obviously in scope for #644 (Cluster C's own arity
member), `OCCTBridge_Surface.mm` turned out to have nine sites shaped

```objc
const Handle(Geom_Curve)& curve = *(const Handle(Geom_Curve)*)curveRef;
```

- a raw pointer reinterpretation that exploits the wrapper struct's one-field layout, syntactically
unrelated to `IDENT->field` and invisible to `aliases()` regardless of whether it is guarded. Six
of the nine are safe in substance (immediately wrapped in `GeomAdaptor_Curve`, measured above to
raise a catchable exception on null). **Three are not** - measured directly, each SIGSEGVs
(uncatchable) on a null `Handle(Geom_Curve)`:

```
PART 2: GeomFill_* family on a null Handle(Geom_Curve), the fifth alias form the checker still cannot see

  GeomFill_Profiler().AddCurve(nullCurve)                  [OCCTGeomFillProfilerAddCurve]          SIGSEGV (uncatchable)
  GeomFill_SectionGenerator().AddCurve(nullCurve)          [OCCTGeomFillAppSurf, #644's own fn]     SIGSEGV (uncatchable)
  GeomFill_SectionPlacement(loc, nullCurve) ctor+Perform     [OCCTGeomFillSectionPlacement]          SIGSEGV (uncatchable)
```

`OCCTGeomFillAppSurf` is **#644's own function** - and this is a genuinely different bug from the
one #644 files: #644 is a valid single curve tripping an arity requirement inside `GeomFill_AppSurf`
itself; this is *any* null curve, at *any* count, tripping `GeomFill_SectionGenerator::AddCurve`
before `GeomFill_AppSurf` is even reached. Neither #644's issue text nor CLAUDE.md's blind-spot
list mentions this fifth form.

**Not taught here, and not fixed here.** Teaching the checker this shape would immediately turn it
red on these three real sites - out of bounds for a census-only PR (the verify checklist requires
the checker to still exit 0). Fixing three more bridge functions, each needing its own
fallback-semantics and regression-test pass per this repo's "prove the test fails" policy, is
equally out of bounds for "census only." **Filed as
[#710](https://github.com/SecondMouseAU/OCCTSwift/issues/710)** with the measurement, the specific
lines, and the suggested fix (teach the shape and fix the three sites together, in that follow-up,
so the gate is never red for a commit in between). See `probe_cluster_c.mm` PART 2 for the
reproducer.

## Guard-removal matrix

Per `okf/policies/prove-the-test-fails.md` and Cluster A's own corrective finding that a
`--self-test` passing 6/6 is not evidence a guard is load-bearing until it has actually been
removed and shown to change the outcome. Every new conditional this upgrade introduces, neutered
one at a time, against both the self-test suite and the real report over
`Sources/OCCTBridge/src/*.mm`:

| guard removed | self-test | FAILS | real report |
|---|---|---|---|
| (none, baseline, post-upgrade) | 19/19 | | 0 unguarded (62/63 guarded, 1 in ALLOWED) |
| G1: scope fence (`end_bound`) removed | 18/19 | `two sibling scopes reuse the same local name, each independently guarded via DownCast` | **CHANGED**: 1 unguarded - reproduces the exact `OCCTFaceGetPrimaryAxis` false positive found while building this detector |
| G2: start bound (`start_bound`) removed | 15/19 | 4 CLEAN cases, all four local-handle CLEAN fixtures | **CHANGED, badly**: 62 unguarded - an earlier unrelated guard on the same bare name anywhere in the function is misread as covering every later declaration of that name |
| `extern "C"` tolerance in `FUNC` removed | 18/19 | `extern "C" on the definition line must not hide the function` | unchanged (0 real occurrences either way; this guard is pure hardening) |
| `ALLOWED` exemption removed from `local_handle_sites` | 19/19 | none | **CHANGED**: 1 unguarded - `OCCTGeomFillCoonsAlgPatchEval` reappears, confirming the exemption is what keeps the gate green for the one measured-safe finding |
| producer allowlist widened to any call, not just `BRep_Tool::` | 19/19 | none | **CHANGED**: 18 unguarded (of 672 total candidates) - confirms the allowlist is doing real filtering, not decoration; none of the 18 was independently investigated, since widening the allowlist was never proposed as the actual design |
| `classify()`'s `DownCast` exclusion removed (shared; now also exercises the new local-handle path) | 16/19 | 3 CLEAN cases, including 2 of the 3 new local-handle DownCast/redeclaration fixtures | **CHANGED**: 237 unguarded - this exclusion was already load-bearing for the wrapper-argument walk (per #556/#618); confirms the new local-handle path depends on the identical shared logic, not a parallel copy of it |
| `classify()`'s guarding-helper exclusion removed (shared) | 17/19 | 2 CLEAN cases, one old, one new | **CHANGED**: 2 unguarded - same confirmation, for the other shared exclusion |

**Every guard this upgrade adds is load-bearing on both axes** (a self-test case catches its
removal, and the real report changes): G1 and G2 are new, and both reproduce a real failure mode
found while building the detector rather than invented for the fixture afterward. The `extern "C"`
row is the one exception - it stays at "unchanged" on the real report because there are zero real
occurrences to change, which is the expected result for hardening against a theoretical case, not
evidence the guard is decorative (its self-test row still fails without it).

The last two rows are not new logic; they re-run existing guards through the new code path to
confirm the new path actually depends on them rather than merely being adjacent to them - the same
distinction Cluster A's own audit drew between guards J/K (real, but only ever exercised by
`self_test()`'s own bypass) and guards A/D/G/L (real and load-bearing on the actual corpus).

### Extended: the Shape 3 follow-up (constructor-init connector, `occ::handle<>` local fixture)

Same method, run against the tree with fixtures `T` and `U` added (21 total cases). Both rows below
are measured against this 21-case baseline, not the 19-case one above:

| guard removed | self-test | FAILS | real report |
|---|---|---|---|
| (none, baseline, post follow-up) | 21/21 | | 0 unguarded (same 24 `ALLOWED` entries) |
| constructor-init connector narrowed back to `=` only | 20/21 | `local handle from BRep_Tool::, constructor-init paren syntax (the #656 shape, no =)` | unchanged (0 real occurrences either way - the maintainer's zero-site measurement holds) |
| `occ::handle<>` alternative removed from `LOCAL_HANDLE_DECL` | 20/21 | `local handle from BRep_Tool::, occ::handle<> spelling, unguarded` | unchanged (0 real occurrences either way) |

Both rows are single-case failures with no real-report change, exactly as the maintainer's own
zero-site measurement predicted before either fixture was written - neither shape was a live
finding, both were pure fixture-coverage gaps.

**A near-miss while building the removal test for the second row, worth recording since it is
exactly the failure mode this whole exercise exists to catch.** `LOCAL_HANDLE_DECL` has two
alternative type-spelling groups (`Handle(Type)` is group 1, `occ::handle<Type>` is group 2), so
removing the `occ::handle<>` alternative shifts every later group index down by one everywhere the
match is read. The first removal attempt patched `local_handle_sites()`'s own `m.group(3)`/
`m.group(4)` reads but missed the scope fence's `later.group(3)` comparison a few lines below -
which silently degraded into comparing a variable name against a producer name, never matching, so
the scope fence stopped firing for every redeclaration case. That produced a false "1 unguarded,
CHANGED" result and an unrelated CLEAN-case failure, which would have been read as "removing
`occ::handle<>` support somehow also breaks the scope fence" - a plausible-sounding but wrong
conclusion. Fixing the second reference (`later.group(2)`) reproduced the two-guard-removal
harness correctly, giving the clean, single-case-failure result the table reports. Not a defect in
the shipped checker - `local_handle_sites()` itself only ever reads `m.group(3)`/`m.group(4)`
against the REAL, unmodified `LOCAL_HANDLE_DECL`, where the group numbering is fixed and correct -
only in the throwaway ad hoc removal script built to test it, which is precisely why the *fixed*
version of the removal test, not the first draft, is what belongs in this table.

## Which of #636 / #643 / #644 the upgraded checker catches

**None of the three.** This is the expected, correct answer, not a shortfall: none of the three is
actually a null-handle-guard defect in the bridge.

- **#636** (`Curve3D.extrema` SIGSEGVs on parallel curves). `OCCTCurve3DExtrema` and
  `OCCTCurve3DMinDistanceToCurve` (`OCCTBridge_Curve3D.mm:1070-1106`) already guard both curve
  arguments correctly (`if (!c1 || c1->curve.IsNull() || !c2 || c2->curve.IsNull()) return ...;`).
  The crash is `GeomAPI_ExtremaCurveCurve`/`Extrema_ExtCC` being interrogated (`.Points()`,
  `.Parameters()`, `.Distance()`) after construction on two **non-null, geometrically parallel**
  curves - a numeric/degenerate-condition defect, not a null handle, in the same family as
  `BRepExtrema_ExtCC`'s existing documented fix but needing its own guard (`isParallel` or
  equivalent), which this checker has no way to express and should not be extended to express: it
  is not about `Handle` nullity at all.
- **#643** (`GeomTools_Curve2dSet`/`SurfaceSet` accept a null handle and SIGSEGV in `Write()`).
  `OCCTGeomToolsCurve2dSetWrite`/`OCCTGeomToolsSurfaceSetWrite` (`OCCTBridge_IO.mm:1570-1637`)
  already guard every array element correctly (`if (!c || c->curve.IsNull()) return nullptr;`
  inside the loop, before `cs.Add(c->curve)`), an existing, already-recognised shape (form 5,
  "array element through a cast," from #618). The checker correctly reports this function clean.
  #643's own defect is **upstream, in OCCT's own container**: `GeomTools_Curve2dSet::Add`/
  `GeomTools_SurfaceSet::Add` accept a null handle silently (unlike `GeomTools_CurveSet::Add`,
  which drops it) and only crash later, inside `Write()`, on a null this bridge's own guard already
  refuses to let through. No amount of bridge-side null-handle discipline can see inside OCCT's own
  `Add()`/`Write()` pair; #643 is correctly scoped as a kernel patch, not a bridge gap.
- **#644** (`Surface.appSurf(curves:)` SIGSEGVs on a single curve). The filed defect is an arity
  requirement inside `GeomFill_AppSurf` on a **valid** single-curve input - confirmed by #644's own
  text that substituting a guarded `0.0` for the NaN parameter still crashes. No null handle is
  involved in the filed reproduction, so no null-handle checker, upgraded or not, could catch it.
  **What this census's own investigation of the same function did find** is a different, related
  defect - see "Found, deliberately not taught" above and #710. The upgraded checker does not
  catch #644 as filed, and does not catch #710 either, by the design choice recorded there.

## Corrections and things worth a sentence

- **#666's own framing held up on measurement**: "teach the checker that shape first... it then
  enumerates the rest of the family for free" is exactly what happened - one shape, taught once,
  found the one real remaining instance (already fixed) and one genuinely new one (measured-safe),
  with no per-function hand-auditing needed beyond triaging what the walk reported.
- **CLAUDE.md's constructor-init false-positive claim was checked, not just repeated.** `Handle
  (Geom_Curve) w(wrapper->curve);` uses no `=`, so `aliases()`'s `ASSIGN`-based binding recognition
  never sees it as a copy - but the wrapper's own `wrapper->curve` occurrence, sitting right there
  as a constructor argument, textually matches the existing direct-use pattern and gets classified
  through `enclosing_call` returning `('w', 0)`, which is not a recognised helper, so it falls
  through to `'use'`. Confirmed by direct trace-through of `classify()`/`enclosing_call()`, not
  reasoned about in the abstract: the claim is accurate, and remains unaddressed, per this census's
  scope (CLAUDE.md's list was correct here; nothing to correct, worth recording that verification
  happened rather than assuming the docstring's word for it).
- **`ALLOWED`'s `(file, function)` keying is now coarser than before, not just still-coarse.**
  Before this census, a function name in `ALLOWED` exempted every wrapper-argument finding
  `unguarded_sites()` could report for it. After this census, the identical entry ALSO exempts
  anything `local_handle_sites()` finds for that same function name - a function cleared for one
  reason now silently covers a second, unrelated reason too, with no way to tell from the table
  which remit an entry was actually measured against. Not changed here: splitting the key (e.g.
  `(file, function, origin)`) would double the bookkeeping for a table whose real safeguard has
  always been "lives in a tracked file, survives review," and the same review discipline already
  required for every entry extends naturally to asking "does this also cover a local handle" when
  touching one. Worth revisiting if a function ever collects both an `ALLOWED` wrapper-argument
  entry and a genuinely different local-handle finding that shouldn't share its reasoning - not
  observed in this tree today.
- **A new, previously unreported defect (#710) was worth more than confirming the three known
  ones.** Consistent with every prior cluster census on this workstream: the checker upgrade's own
  investigation - reading every real call site the new shape's design touched, not just running the
  fixtures - found something none of #666, #644, or CLAUDE.md's blind-spot list mentioned. The three
  named members turned out to need no checker change to explain (#636, #644) or were already
  bridge-side mitigated (#643); the fifth alias form and its three live SIGSEGVs were not on
  anyone's list going in.
- **The Shape 3 follow-up's own zero-site measurement held, but the verification harness built to
  prove it needed its own fix first.** The maintainer's pre-review measurement (0 occurrences of
  both the constructor-init and `occ::handle<>`-local forms) was independently reproduced before
  either fixture was written, and both post-fixture guard-removal rows confirm it: single-case
  self-test failures, zero real-report change. The one wrinkle was in the removal *test* itself, not
  the shipped detector - see the extended guard-removal matrix's note on the `occ::handle<>` group-
  index near-miss. Recorded because it is a small, concrete instance of exactly the risk
  `okf/policies/prove-the-test-fails.md` warns about: a removal check that looks right on first
  read can still be measuring the wrong thing.

## Does this belong in the shared `Censuses` target too?

**No - the gate script is the whole artifact, and here is why**, since Cluster A/B's own censuses
both did add a `Censuses` entry and #666 explicitly asks the question.

Cluster A and B's censuses are fundamentally **dynamic**: their subject is what a real call to a
real public API returns on a real fixture (`box.edgeCount`, `filleted(edges:radius:)`'s duplicate-
index behaviour), which only exists as a runtime measurement - a static read of the source could
describe the code's *intent* but not what the built kernel actually does, so a Swift executable
that builds fixtures and calls the API was the correct primary evidence, with a source-text
classifier as secondary cross-check.

This census's subject is the opposite: **a source-level shape in `Sources/OCCTBridge/src/*.mm`
text** - does a local `Handle` declaration reach a use before an `IsNull()` check. That is exactly
what `Scripts/check-null-handle-guards.py` already exists to answer, and it is not a question a
Swift program calling the public API could answer at all: the public API never exposes "is this
specific internal C++ line guarded," only whatever behaviour results once it is or isn't. Where
this census DID need runtime evidence - is a specific unguarded call actually safe, or does it
crash - the answer came from a direct, forked, OCCT-linked C++ probe
(`probe_cluster_c.mm`), the same shape `Scripts/repro/556-null-handle-guard-sweep/repro_556.mm`
already established as this family's own dynamic-evidence idiom, not from the Swift `Censuses`
target: there is no Swift-level API to route a null `Handle(Geom_Curve)` into
`BRepTools::EvalAndUpdateTol` or `GeomFill_SectionGenerator::AddCurve` and observe the crash from
the Swift side, since the whole point is that the bridge is supposed to refuse it before OCCT ever
sees it.

So: `python3 Scripts/check-null-handle-guards.py` (the enumeration, "for free" once the shape is
taught) plus `probe_cluster_c.mm` (the crash-or-catch measurement for each finding) are the
complete artifact. Nothing here would gain evidentiary value from a `ClusterC.swift` in the shared
target, and adding one would just be a second, weaker copy of what the gate script already does
authoritatively.

## Verify

```bash
swift build                                    # 0 errors, no OCCTSWIFT_LOCAL, pinned v2.0.0-kernel.1
swift test                                     # full suite
python3 Scripts/check-bridge-index.py
python3 Scripts/check-null-handle-guards.py
python3 Scripts/check-docs-defaults.py
python3 Scripts/count-operations.py
python3 Scripts/check-bridge-index.py --self-test
python3 Scripts/check-null-handle-guards.py --self-test
python3 Scripts/check-docs-defaults.py --self-test
```
