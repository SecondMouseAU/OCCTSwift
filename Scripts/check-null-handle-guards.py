#!/usr/bin/env python3
"""Verify that every bridge function guards the geometry Handle, not just the wrapper pointer.

`OCCTCurve3DRef`, `OCCTCurve2DRef` and `OCCTSurfaceRef` are pointers to a wrapper struct whose
only field is an OCCT `Handle`. Checking the pointer says nothing about the handle, and a null
handle reaching OCCT is often an unconditional dereference: `Scripts/repro/556-null-handle-guard-sweep`
measures 36 of the 57 distinct OCCT entry points this bridge passes such a handle into as an
uncatchable OS signal, which the enclosing `catch (...)` cannot intercept. So the opener has to
test both:

    if (!x || x->curve.IsNull()) return <the same fallback the catch below uses>;

#478 fixed the 14 functions that dereferenced the handle themselves; #556 fixed the 60 that pass
it to an OCCT API which dereferences it internally. This script is what keeps that at zero.

#618: the walk that produced both lists matched `param->field` and nothing else, so it was blind
to every site that reaches the handle through an indirection. Four such forms occur in this tree,
and the detector handles those four:

    1. a cast:            reinterpret_cast<OCCTSurface*>(surfaceRef)->surface
                          static_cast<OCCTCurve3D*>(curveRef)->curve
                          (OCCTSurface*)surface
    2. a pointer alias:   auto* s = (OCCTSurface*)surface;   ... s->surface
    3. a handle alias:    auto& surf = reinterpret_cast<OCCTSurface*>(ref)->surface;   ... f(surf)
                          Handle(Geom_Surface) work = wrapper->surface;               ... f(work)
    4. a bridge helper:   occtSurfaceToAnalytical(reinterpret_cast<OCCTSurface*>(ref)->surface, ...)

Forms 1-3 hid unguarded sites from the gate. Form 4 is the opposite: the handle is checked, just
one call frame away, so a detector that learns 1-3 without learning 4 reports correct code (the
#624/#630 failure, where a sibling gate was confidently wrong about seven entries). All four are
resolved here: casts are normalised away, aliases are followed, and a use that hands the handle to
a bridge helper whose own body `IsNull()`-checks that parameter first counts as guarded.

WHAT THIS STILL CANNOT SEE. "Four" is a fact about this tree, not about C++, and the list was
arrived at by enumerating what the bridge actually writes. Add any of these and the gate goes quiet
on a real defect, so add the shape here too rather than assuming it is covered:

  * `(*cast).field` instead of `cast->field`. Zero occurrences today.
  * an alias bound by reference to the wrapper, `OCCTSurface& w = *ref;   ... w.surface`.
  * a guard whose result is discarded or does not dominate the use: `x->curve.IsNull();` as a
    statement, or an `if` that tests it and then falls through to the use anyway. The walk treats
    the first `IsNull()` before the use as a guard and does not check for a control transfer.
    Verified once, by hand, that every clearing guard in this tree does return or throw.
  * a negated guard, `if (!x->curve.IsNull()) { } else { use(x->curve); }`.
  * a helper that guards on some paths only. `guarding_helpers()` asks whether the FIRST mention of
    the parameter is an `IsNull()` test, not whether every path through the body is protected.

`extern "C"` on the definition line is now handled (#666): FUNC used to require its return-type
span to be free of `"`, so the whole function was invisible to the parser, guarded or not. Zero
real occurrences motivated this - it was still worth one line, since the failure mode (a whole
function silently unparsed) is worse than the false positive a wrong fix would risk.

And one false-positive direction: `Handle(Geom_Curve) w(wrapper->curve);` constructor-init syntax
is not recognised as an alias binding, so it would be reported as an unguarded use. Also absent.

#666 (CLUSTER C): A SECOND, INDEPENDENT ORIGIN FOR A RISKY HANDLE, PROVEN BY #656. Every shape
above is about a handle that starts life as a bridge function's OWN `OCCTCurve3DRef`/
`OCCTCurve2DRef`/`OCCTSurfaceRef` argument. #656 (`OCCTBRepToolsEvalAndUpdateTol`) was a null
`Handle(Geom2d_Curve)` that never came from any argument: it was fetched locally, mid-body, from
`BRep_Tool::CurveOnSurface(edge, face, ...)`, and handed straight to `BRepTools::EvalAndUpdateTol`,
which dereferences it unconditionally. Every check above reported clean, because none of them looks
past a wrapper argument to a handle the function went and obtained for itself.

`local_handle_sites()` closes this specific instance: a local

    Handle(Geom_Curve)/Handle(Geom2d_Curve)/Handle(Geom_Surface) name = BRep_Tool::Whatever(...);

(`Handle(Type)` or `occ::handle<Type>` spelling, either) is tracked exactly like a wrapper-derived
handle alias once declared - the same `classify()`, the same DownCast exclusion, the same
guarding-helper exclusion - so a use before an `IsNull()` guard is reported the same way. Two things
this needed that the wrapper-argument walk did not:

  * A PRODUCER ALLOWLIST, NOT "ANY CALL". The RHS has to start with `BRep_Tool::`. At least
    `Curve` ("May be a Null handle") and `CurveOnSurface` ("Returns a NULL handle if this curve
    does not exist") say so in `BRep_Tool.hxx` itself; `Surface(const TopoDS_Face&)` documents no
    such thing ("Returns the geometric surface of the face"), and is tracked anyway as a
    conservative over-approximation, not because OCCT promises a null there. "Any local Handle
    initialised from any call" was tried first
    and matched 672 declarations tree-wide - mostly `new T(...)` (never null), a same-family
    `DownCast` (null-safe by construction, and this bridge's own established cloning idiom: `Handle
    (Geom_Curve) copy = Handle(Geom_Curve)::DownCast(c->curve->Copy());`), or a builder's
    post-success result accessor. None of those is #656's shape, and auditing 672 by hand would not
    have been a defence - it would have been a bigger, less careful repeat of #618's own "blind to
    indirection" mistake with a different indirection. `BRep_Tool::` narrowed it to 63 real
    declarations.
  * A SCOPE FENCE. This bridge reuses generic local names (`surf`, `curve`, `pcurve`) across sibling
    blocks in one function - most visibly a `switch` with one `Handle(Geom_Surface) surf =
    BRep_Tool::Surface(...)` per `case`. A flat "every later mention of this name is this variable"
    walk conflates them: an early version of this detector mistook `OCCTFaceGetPrimaryAxis`'s SECOND
    `case`'s properly-guarded `surf` for a continuation of the FIRST `case`'s `surf` (consumed only
    by `DownCast`, itself null-safe) and reported the first as unguarded - a false positive that
    would not have survived review.

    Originally fixed by treating a later `Handle(...) name = BRep_Tool::...` redeclaration of the
    identical name, anywhere later in the function body, as the end of the earlier declaration's own
    tracking window - textual, not scope-aware. An automated review round on this same PR found two
    real holes in that: a sibling redeclaration from ANY OTHER SOURCE (not `BRep_Tool::`) never
    fenced anything, since it never matched the pattern the fence looked for; and a redeclaration
    inside a NESTED block ended the OUTER variable's window right there, so a real use of the outer
    variable resuming after the nested block closes went untracked - a genuine, reproduced miss
    (self-test fixture `W`), not a theoretical one. `var_declarations()`/`binds_to()` replace the
    textual fence with real C++ block scoping - every occurrence of a name binds to the innermost
    still-in-scope declaration of it, exactly the rule the compiler itself uses - which subsumes the
    original G1/G2 fixtures (see `local_handle_sites()`'s own docstring) and additionally closes the
    nested-block miss neither of them exercised.

Measured against the tree as it stands: 63 `BRep_Tool::`-sourced locals of these three types, 62
already guarded, 1 reaching `GeomAdaptor_Curve`'s constructor unguarded
(`OCCTGeomFillCoonsAlgPatchEval`, `OCCTBridge_Surface.mm`) - measured, not assumed, against the
pinned kernel (`Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm`) to raise a
catchable `Standard_Failure` on both the 1-arg and the 3-arg (trimmed) constructor, the same
verdict #618 already recorded for `OCCTExtremaExtCC`'s wrapper-argument call to the same
constructor, now confirmed for a curve arriving by this second route too. Added to ALLOWED below.
Full method, the guard-removal matrix and the triage are in
`Scripts/repro/cluster-c-null-handle-shapes/README.md`.

NOW ALSO TAUGHT (follow-up, same PR): the constructor-init connector, `Handle(Geom_Curve) c2d(
BRep_Tool::CurveOnSurface(...));` - #656's exact shape, written with parens instead of `=`. The
false-positive direction two paragraphs below (`Handle(Geom_Curve) w(wrapper->curve);` defeating
the WRAPPER-ARGUMENT alias binding) is a different code path (`aliases()`, not `LOCAL_HANDLE_DECL`)
and is UNCHANGED by this - a local sourced from a wrapper's own field and a local sourced from
`BRep_Tool::` are tracked by two different mechanisms, and only the second gained paren support
here. Also added: a dedicated fixture for the `occ::handle<>` spelling as a LOCAL declaration
(previously only exercised as a helper's parameter type, fixture R) - the regex already covered it,
but nothing had proven that for a local until now. Zero real occurrences of either form motivated
both; see the census README for the measurement and the extended guard-removal matrix.

STILL NOT TAUGHT, DELIBERATELY, AND STILL BLIND: every item in the list above (non-dominating
guard, negated guard, partial-path helper, `(*cast).field`, reference-to-wrapper alias) applies
just as much to a `BRep_Tool::`-sourced local, and none has a known instance in this tree today.
Also still blind: a `BRep_Tool::` handle carried through one more level of copy (`Handle(Geom_Curve)
tmp = c3d;`) rather than used directly, any locally-obtained handle whose producer is not spelled
`BRep_Tool::` - a different OCCT accessor with the same null-for-valid-topology contract would not
be caught by this walk - and a SPLIT declare-then-assign (`Handle(Geom_Curve) c; ... c =
BRep_Tool::Curve(...);`), since `LOCAL_HANDLE_DECL` only matches an INITIALISING declaration: measured
at zero occurrences tree-wide before shipping this claim, per this repo's own "an untested claim of
coverage is not coverage" standard, rather than left as an assertion the way earlier passes over
this file were caught doing. Enumerating the wider producer set was explicitly out of scope for
this pass; the census README's method section says why `BRep_Tool::` specifically, not "every OCCT
call", was the line drawn.

CORRECTED, NOT BLIND: the `extern "C" { ... }` BLOCK form (as opposed to the inline `extern "C" int
foo() {` prefix `FUNC` already handles) used to be listed here as blind too - wrongly. An automated
review round confirmed live, before changing this text, that `FUNC` already parses a function
defined inside such a block correctly: the block's own `extern "C" {`/`}` are just text to
`functions()`, which finds a function by its OWN signature line, and a function nested inside the
block has no `extern "C"` text on ITS line to hide it from that match in the first place - it was
never a distinct case FUNC needed to learn. Fixture `V` locks this in.

FOUR MORE, SAME CLASS - `LOCAL_HANDLE_DECL` requires an explicit `Handle(Type)`/`occ::handle<Type>`
spelling directly followed by a bare name and one of the two known connectors, so anything else
between the type and the producer call is invisible, guarded or not:

  * a deduced type: `auto c2d = BRep_Tool::CurveOnSurface(...);` - no type name for the regex to
    anchor on at all. NOT hypothetical: `OCCTBRepToolCurveOnSurface` (`OCCTBridge_Topology.mm:3717`)
    uses exactly this, already guarded in substance (`if (c2d.IsNull()) return nullptr;` the next
    line) - safe today, invisible either way.
  * a reference binding: `const Handle(Geom_Surface)& s = BRep_Tool::Surface(...);` - the `&`
    sits exactly where the regex expects nothing but whitespace before the bare name. Zero
    occurrences.
  * global qualification: `::BRep_Tool::Curve(...)` - the leading `::` breaks the literal
    `BRep_Tool::` anchor. Zero occurrences.
  * a ternary initialiser: `Handle(Geom_Curve) c = cond ? BRep_Tool::Curve(...) : ...;` - anything
    between the connector and `BRep_Tool::` breaks the immediate-adjacency the regex requires.
    Zero occurrences.

Not taught here: this is a documentation-accuracy pass over an already-shipped mechanism, not a
new detection pass, and the one real instance found is already safe. Re-measure before assuming
that stays true.

A FIFTH ALIAS FORM, FOUND BUT NOT TAUGHT: `OCCTBridge_Surface.mm` has nine sites shaped
`const Handle(Geom_Curve)& x = *(const Handle(Geom_Curve)*)wrapperParam;` (and its `occ::handle<>`
spelling, used safely 12 more times elsewhere, always guarded) - a raw pointer reinterpretation
that exploits the wrapper struct's one-field layout, syntactically unrelated to `IDENT->field` and
invisible to `aliases()`. Three of the nine reach an unguarded, measured, uncatchable SIGSEGV:
`OCCTGeomFillProfilerAddCurve`, `OCCTGeomFillAppSurf` (the #644 function itself - its own curve
array, a DIFFERENT defect from #644's filed arity bug) and `OCCTGeomFillSectionPlacement`'s
`sectionCurve`. Measured in `Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm`, not
taught here and not fixed here: teaching the shape without fixing the three real sites it would
find would leave this gate red, which is out of bounds for a census-only pass. See the census
README's section on this fifth form, and #710, filed for it.

Two exclusions, both load-bearing:

  * A `DownCast(x->curve)` is NOT a use: down-casting a null handle returns a null handle, and
    every such site in this bridge checks the cast result. Without it the walk reports several
    hundred false positives.
  * ALLOWED below carries the sites where a guard would be noise. Most are there because the OCCT
    entry point was *measured* to tolerate a null handle - #556's own standard, since a call that
    returns normally or raises a catchable `Standard_Failure` is already handled by the function's
    `catch (...)`. Every reason cites the measurement.

    Know what an ALLOWED entry actually buys. It is keyed `(file, function)`, with no argument
    index and no re-validation: it exempts EVERY wrapper argument of that function, and it keeps
    exempting them after the body changes. A function cleared today because it called
    `GeomLib_Tool::Parameter` stays cleared if someone swaps that for a call that dereferences.
    The mechanism's only real safeguard is that it lives in a tracked file, so an entry has to
    survive review. Re-measure before trusting an entry you did not write, and delete it rather
    than widen it when a function grows a new argument.

    #666 made this coarser, not just still-coarse: the same key now ALSO exempts every
    `local_handle_sites()` finding for that function, not only `unguarded_sites()`'s wrapper
    arguments. `OCCTGeomFillCoonsAlgPatchEval` is the concrete cost, bounded but real: it passed
    the wrapper-argument walk clean *before* #666 and was never in this table, so its new entry
    (added for the local-handle finding) retroactively exempts wrapper-argument checking on that
    function too - dead weight today only because the function happens to have no
    `OCCTCurve3DRef`/`OCCTCurve2DRef`/`OCCTSurfaceRef` parameter to check, not because the table
    knows that. State which walk (or walks) an entry was actually measured against in its reason,
    going forward, so a reader can tell what a given entry does and does not cover without
    re-deriving it from the function's signature.

    An automated review round asked, again, whether the other 23 pre-existing entries - each
    reviewed only against `unguarded_sites()`, never against `local_handle_sites()` - might be
    silently exempting a real local-handle finding nobody has looked for. Re-audited by measurement,
    not by re-reading each entry: removing every `ALLOWED` exemption from `local_handle_sites()` and
    re-running against the real tree surfaces exactly one finding, `OCCTGeomFillCoonsAlgPatchEval` -
    the same one already known and already in this table. None of the other 23 has a hidden
    local-handle defect behind its entry TODAY. That is not a standing guarantee (the docstring
    warning above already covers "after the body changes"), only a measured answer to "as of this
    audit," which is exactly the standard the rest of this table is held to.

ROUND-2 REVIEW, THE REMAINING FINDINGS - all mechanical, none changing what gets reported today:

  * `self_test()` used to check only the combined `all_sites()` result, which proves some detector
    in the union catches a fixture, not specifically that the mechanism it exercises still does - a
    regression confined to `unguarded_sites()` could in principle hide behind a coincidental change
    elsewhere. Every fixture is now tagged 'wrapper' or 'local' and is also checked directly against
    its own mechanism (see `self_test()`'s own docstring for a worked example of the exact masking
    this closes).
  * `all_sites()` ran `guarding_helpers()`, `unguarded_sites()` and `local_handle_sites()` as three
    independent passes over the same source files, each re-doing the same comment/cast-stripping and
    function-boundary scan. `parse_sources()` does that work once and all three now share it.
  * The report tuple's `field` (wrapper) / `callee` (local) slot meant two different things
    depending on `kind`, tracked only by convention and a comment. It is a named `Site.detail` now,
    with the dual meaning spelled out where it is declared rather than implied at each call site.
  * `probe_cluster_c.mm`'s `fork()` return was never checked: on failure, the subsequent
    `waitpid(-1, ...)` returns immediately via `ECHILD` with `st` left at 0, which the verdict switch
    reads as "returned normally" - the opposite of what happened. Now reported as its own verdict.
  * The census README was trimmed - it had grown to carry its own review log (corrections found
    while responding to feedback, a near-miss in a throwaway verification script) well past this
    project's `docs/` length norms and its own cited `556-null-handle-guard-sweep` precedent.

Usage (from the repo root):

    python3 Scripts/check-null-handle-guards.py             # report unguarded sites
    python3 Scripts/check-null-handle-guards.py --quiet     # exit status only
    python3 Scripts/check-null-handle-guards.py --self-test # prove each failure mode is caught

Exit status is 1 when any site is unguarded, so this can gate a commit. CI runs it, and its
`--self-test`, in `ci.yml`'s `gate-scripts` job (#625).
"""
import glob
import os
import re
import sys
from collections import namedtuple

# One reported site, from either walk. `detail` is deliberately dual-purpose rather than split into
# two mutually-exclusive fields: for a 'wrapper' site it is the wrapper's handle field name (e.g.
# `curve`), for a 'local' site it is the BRep_Tool:: producer call that obtained it (e.g.
# `BRep_Tool::Curve`) - #666 round-2 review's readability nit. A split (`field`/`callee`) would
# still need `kind` to know which one is meaningful, so this documents the same dual meaning the
# comment used to carry implicitly, in the name itself, rather than inventing two fields only one
# of which is ever populated for a given `kind`.
Site = namedtuple('Site', 'file line func name detail src is_array kind')

SRC_DIR = 'Sources/OCCTBridge/src'

# wrapper parameter type -> the handle field it carries
WRAPPERS = {
    'OCCTCurve3DRef': 'curve',
    'OCCTCurve2DRef': 'curve',
    'OCCTSurfaceRef': 'surface',
}

# Sites deliberately left unguarded, with the reason. An entry is a promise: either every caller
# checks both the pointer and the handle, or the OCCT entry point was measured to cope with a null
# handle on its own. The measured verdicts come from Scripts/repro/556-null-handle-guard-sweep,
# which #618 extended with the 22 entry points the pre-#618 walk never reached.
ALLOWED = {
    ('OCCTBridge_Geom2d.mm', 'makeQualifiedCurve'):
        'returns Geom2dGcc_QualifiedCurve by value, so it has no null-safe fallback to return; '
        'all of its callers reject a null pointer and a null handle before calling',

    # --- the null handle never reaches OCCT ---
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetSurface'):
        'stores into the bridge-owned side registry, not OCCT; the else branch of the same '
        'expression deliberately stores a null handle to clear the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetCurve3D'):
        'stores into the bridge-owned side registry, not OCCT; a null handle clears the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphRepSetCurve2D'):
        'stores into the bridge-owned side registry, not OCCT; a null handle clears the slot',
    ('OCCTBridge_BRepGraph.mm', 'OCCTBRepGraphCoEdgeSetPCurve'):
        'BRepGraph_EditorView::SetPCurve documents the null handle as its clear-the-binding '
        'contract ("Pass a null handle to clear the stored PCurve binding")',

    # --- measured: the OCCT call returns normally on a null handle ---
    ('OCCTBridge_Curve3D.mm', 'OCCTGeomLibToolParameter3D'):
        'measured #618: GeomLib_Tool::Parameter(Geom_Curve) returns false on a null handle',
    ('OCCTBridge_Geom2d.mm', 'OCCTGeomLibToolParameter2D'):
        'measured #618: GeomLib_Tool::Parameter(Geom2d_Curve) returns false on a null handle',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibToolParametersSurface'):
        'measured #618: GeomLib_Tool::Parameters(Geom_Surface) returns false on a null handle',
    ('OCCTBridge_Surface.mm', 'OCCTGeomConvertIsCanonical'):
        'measured #618: GeomConvert_SurfToAnaSurf::IsCanonical returns on a null handle',
    # --- measured: the OCCT call raises a catchable Standard_Failure, which each function's own
    #     catch (...) already turns into the same fallback a guard would return ---
    ('OCCTBridge_Curve3D.mm', 'OCCTApproxSameParameter'):
        'measured #618: Approx_SameParameter raises a catchable Standard_Failure. Probed per '
        'argument, not just all-three-null, since this function takes three handles and a guard '
        'would protect each one separately: all four combinations are catchable',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCC'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCCPoint'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCS'):
        'measured #618: GeomAdaptor_Curve / GeomAdaptor_Surface raise a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaExtCSPoint'):
        'measured #618: GeomAdaptor_Curve / GeomAdaptor_Surface raise a catchable Standard_Failure',
    ('OCCTBridge_Curve3D.mm', 'OCCTExtremaLocateExtCC'):
        'measured #618: GeomAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Geom2d.mm', 'OCCTExtremaLocateExtCC2d'):
        'measured #556: Geom2dAdaptor_Curve raises a catchable Standard_Failure',
    ('OCCTBridge_Geom2d.mm', 'OCCTGeom2dConvertApproxArcsSegments'):
        'measured #618: the throw is the Geom2dAdaptor_Curve built on the preceding line '
        '(OCCTBridge_Geom2d.mm:2935), not Geom2dConvert_ApproxArcsSegments itself; either way a '
        'catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibIsPlanarSurface'):
        'measured #618: GeomLib_IsPlanarSurface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTGeomLibPlanarSurfacePlane'):
        'measured #618: GeomLib_IsPlanarSurface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtPS'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtPSPoint'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtSS'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',
    ('OCCTBridge_Surface.mm', 'OCCTExtremaExtSSPoint'):
        'measured #618: GeomAdaptor_Surface raises a catchable Standard_Failure',

    # --- #666: a local handle fetched from BRep_Tool::, not a wrapper argument ---
    ('OCCTBridge_Surface.mm', 'OCCTGeomFillCoonsAlgPatchEval'):
        'measured against local_handle_sites() only (this function has no OCCTCurve3DRef/'
        'OCCTCurve2DRef/OCCTSurfaceRef parameter for unguarded_sites() to check, so this entry '
        'costs nothing on that walk today, but see the docstring rule above this table for what '
        'that would mean if it ever grew one): #666 '
        '(Scripts/repro/cluster-c-null-handle-shapes/probe_cluster_c.mm), GeomAdaptor_Curve raises '
        'a catchable Standard_Failure on a null Handle(Geom_Curve), on both the 1-arg and the '
        '3-arg (trimmed) constructor - same verdict #618 already recorded for OCCTExtremaExtCC, '
        'now confirmed for a curve obtained from BRep_Tool::Curve rather than a wrapper argument',
}

# extern "C" is tolerated ahead of the return type (#666): without it, a function defined that way
# is invisible to this regex, guarded or not, because `"` sits outside the return-type character
# class. Zero real occurrences in this tree motivated it - still worth one line.
FUNC = re.compile(r'^(?:extern\s*"C"\s*)?(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*'
                  r'\(([^;{]*?)\)\s*\{', re.M | re.S)
NOT_A_FUNCTION = {'if', 'for', 'while', 'switch', 'catch', 'return'}

# A C++ named cast and its opening paren; the matching close paren is found by scanning.
CAST_OPEN = re.compile(r'\b(?:reinterpret_cast|static_cast|const_cast|dynamic_cast)'
                       r'\s*<(?:[^<>]|<[^<>]*>)*>\s*\(')
# A C-style cast to one of the wrapper types: (OCCTSurface*), (OCCTCurve3DRef), ...
C_CAST = re.compile(r'\(\s*OCCT\w+\s*\*?\s*\)')
ASSIGN = re.compile(r'\b(\w+)\s*(=)\s*([^;]*);')
HANDLE_PARAM = re.compile(r'(?:occ::handle\s*<|\bHandle\s*\()')

# #666: a local Handle of one of the three tracked types, freshly obtained from a BRep_Tool
# accessor rather than a wrapper argument - the #656 shape. `BRep_Tool::` is a deliberate
# allowlist, not "any call": see the module docstring for why (672 candidates unrestricted, 63
# once narrowed to the `BRep_Tool::` accessor family - at least two of which document a null
# return; the walk tracks the family conservatively rather than per-documented-function).
# The connector between the name and the producer is `=` (the assignment form) or `(` (the
# constructor-init form, `Handle(Type) name(BRep_Tool::Whatever(...));`) - #656's exact shape,
# written with parens instead of `=`. Both spellings, both connectors: four surface forms, one
# regex, since only the text between `name` and `BRep_Tool::` differs.
LOCAL_HANDLE_DECL = re.compile(
    r'\b(?:Handle\s*\(\s*(Geom_Curve|Geom2d_Curve|Geom_Surface)\s*\)|'
    r'occ::handle\s*<\s*(Geom_Curve|Geom2d_Curve|Geom_Surface)\s*>)'
    r'\s+(\w+)\s*(?:=|\()\s*(BRep_Tool::\w+)\s*\(')

# The producer-agnostic sibling of LOCAL_HANDLE_DECL: same three tracked types, same two
# connectors, but no `BRep_Tool::` requirement. Not a source of reportable sites - a redeclaration
# from `new T(...)` or a builder is not #656's shape - but a real C++ redeclaration of the same
# name all the same, and the scope fence below needs to know about every one of them, not just the
# `BRep_Tool::`-sourced ones, to resolve shadowing correctly (#666 round-2 review: a sibling/nested
# redeclaration "from any other source" was invisible to the old fence).
ANY_HANDLE_DECL = re.compile(
    r'\b(?:Handle\s*\(\s*(?:Geom_Curve|Geom2d_Curve|Geom_Surface)\s*\)|'
    r'occ::handle\s*<\s*(?:Geom_Curve|Geom2d_Curve|Geom_Surface)\s*>)'
    r'\s+(\w+)\s*(?:=|\()')


def block_spans(body):
    """(open, close) for every brace-delimited block in `body`, via one stack-based pass, plus a
    synthetic (-1, len(body)) span standing in for "no enclosing braces at all" - the function's
    own top level, which is a scope too even though it has no literal wrapping `{`/`}` of its own
    (the function's own `{`/`}` are already part of `body`, at index 0 and len(body)-1, and DO
    become a real span here like any other)."""
    spans, stack = [], []
    for i, ch in enumerate(body):
        if ch == '{':
            stack.append(i)
        elif ch == '}' and stack:
            spans.append((stack.pop(), i))
    spans.append((-1, len(body)))
    return spans


def innermost_span(spans, pos):
    """The smallest span that strictly contains `pos` - `pos`'s immediately enclosing scope."""
    best = None
    for o, c in spans:
        if o < pos < c and (best is None or (c - o) < (best[1] - best[0])):
            best = (o, c)
    return best


def var_declarations(body):
    """name -> [(start, block_open, block_close), ...] for every ANY_HANDLE_DECL match in body,
    each tagged with its own immediately-enclosing block span. Computed once per function and
    shared by every LOCAL_HANDLE_DECL site in it (see `local_handle_sites()`)."""
    spans = block_spans(body)
    out = {}
    for m in ANY_HANDLE_DECL.finditer(body):
        name = m.group(1)
        o, c = innermost_span(spans, m.start())
        out.setdefault(name, []).append((m.start(), o, c))
    return out


def binds_to(decls, pos):
    """Ordinary C++ block scoping: which declaration (its `start`) an occurrence of its name at
    `pos` resolves to, out of every declaration of that name in the function. A declaration is a
    candidate only while `pos` is still inside ITS OWN immediately-enclosing block (`o < pos < c`)
    - once that block closes, the declaration is out of scope again, exactly as C++ requires - and
    among the candidates still in scope, the most recently declared one (the largest `start` less
    than `pos`) wins, which is what makes a nested redeclaration shadow an outer one for uses
    inside its own block, while an outer declaration's uses AFTER that nested block closes correctly
    resume binding to the outer declaration rather than staying stuck on the inner one."""
    candidates = [d for d, o, c in decls if o < d < pos < c]
    return max(candidates) if candidates else None


def strip_comments(text):
    """Blank out comments and preserve every newline, so line numbers still line up."""
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            out.append(' ' * (j - i))
            i = j
        elif text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            out.append(''.join(c if c == '\n' else ' ' for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == '\\':
                    j += 1
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def strip_casts(text):
    """Blank every cast wrapper, preserving length, so all four spellings of

        reinterpret_cast<OCCTSurface*>(ref)->surface
        static_cast<OCCTSurface*>(ref)->surface
        (OCCTSurface*)ref ... ref->surface
        ref->surface

    reduce to the last one. Positions (and therefore line numbers) are unchanged.
    """
    out, n = list(text), len(text)
    for m in CAST_OPEN.finditer(text):
        depth, j = 0, m.end() - 1
        while j < n:
            if text[j] == '(':
                depth += 1
            elif text[j] == ')':
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if j < n:
            for k in range(m.start(), m.end()):
                out[k] = ' '
            out[j] = ' '
    return C_CAST.sub(lambda mm: ' ' * (mm.end() - mm.start()), ''.join(out))


def functions(text):
    """(name, params, body start, body end) for every function definition in the file."""
    for m in FUNC.finditer(text):
        name, params = m.group(1), m.group(2)
        if name in NOT_A_FUNCTION:
            continue
        start = i = m.end() - 1
        depth = 0
        while i < len(text):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        yield name, params, start, i


def split_params(params):
    """Top-level comma split, so Handle(Geom_Curve) and handle<X, Y> stay in one piece."""
    out, depth, cur = [], 0, ''
    for ch in params:
        if ch in '(<[':
            depth += 1
        elif ch in ')>]':
            depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        out.append(cur)
    return out


def wrapper_params(params):
    """(name, handle field, is_array) for each wrapper-typed parameter.

    is_array marks `OCCTCurve3DRef*` / `OCCTCurve3DRef[]`, where the parameter is a pointer to
    wrappers rather than a wrapper. It only affects the suggested fix that gets printed: writing
    `curveRefs->curve` on one of those is a type error, so the hint has to name an element."""
    out = []
    for p in split_params(params):
        p = p.strip()
        for wrapper, field in WRAPPERS.items():
            if not re.search(r'\b' + wrapper + r'\b', p):
                continue
            m = re.search(r'(\w+)\s*(\[\s*\])?\s*$', p)
            if m and m.group(1) not in WRAPPERS:
                tail = p[p.index(wrapper) + len(wrapper):]
                out.append((m.group(1), field, '*' in tail or bool(m.group(2))))
            break
    return out


def parse_sources(sources):
    """(path, raw, text, ctext, lines, funcs) once per file - the shared, expensive parse work
    that guarding_helpers()/unguarded_sites()/local_handle_sites() each used to redo independently.

    #666 round-2 review (item 8): all_sites() ran all three walks over the same `sources` from
    scratch - comment-stripping, cast-stripping and re-finding every function's boundaries three
    times per file per invocation, for no new information the first pass didn't already have.
    `text` (comments blanked, casts intact) and `ctext` (both blanked) are kept as two separate
    strings, not one: guarding_helpers() deliberately wants casts LEFT IN (a helper parameter typed
    straight as a `Handle`, never itself behind a cast, is what it looks for), while the other two
    walks want them stripped. `funcs` (the `functions()` boundary list) is identical either way,
    since `functions()` only reads return-type/name/param text, none of which a cast can appear
    inside, so it is computed once against `text` and reused for both."""
    parsed = []
    for path, raw in sources:
        text = strip_comments(raw)
        ctext = strip_casts(text)
        lines = raw.splitlines()
        parsed.append((path, raw, text, ctext, lines, list(functions(text))))
    return parsed


def guarding_helpers(parsed):
    """(function, argument index) for every bridge function that IsNull-checks that Handle
    parameter before touching it. Passing a handle to one of these IS a guard: the check just
    lives one call frame away.

    Seven (function, argument) pairs across six functions qualify in this tree:
    `occtCurveToAnalytical`, `occtSurfaceToAnalytical`, `bgSurfacesSameDomain` (both arguments),
    `occtNearestPointOnCurveRange`, `occtNearestPointOnCurve2dRange` and `occtPlateApproxSurface`.
    Only the first two are load-bearing: drop this rule and exactly `OCCTGeomConvertCurveToAnalytical`
    and `occtSurfToAnaSurfResult` are wrongly reported, nothing else. The other four are recognised
    because they guard unconditionally, not because any caller currently relies on it."""
    guards = set()
    for path, raw, text, ctext, lines, funcs in parsed:
        for name, params, bs, be in funcs:
            body = text[bs:be + 1]
            for i, p in enumerate(split_params(params)):
                if not HANDLE_PARAM.search(p):
                    continue
                m = re.search(r'(\w+)\s*$', p.strip())
                if not m:
                    continue
                first = re.search(r'\b' + re.escape(m.group(1)) + r'\b', body)
                if first and re.match(r'\s*\.\s*IsNull\s*\(', body[first.end():first.end() + 20]):
                    guards.add((name, i))
    return guards


def enclosing_call(body, pos):
    """(callee, argument index) for the call whose argument list encloses `pos`, else None."""
    depth, i, commas = 0, pos - 1, 0
    while i >= 0:
        ch = body[i]
        if ch == ')':
            depth += 1
        elif ch == '(':
            if depth == 0:
                m = re.search(r'(\w+)\s*$', body[:i])
                return (m.group(1), commas) if m else None
            depth -= 1
        elif ch == ',' and depth == 0:
            commas += 1
        i -= 1
    return None


def aliases(body, param, field):
    """Local names standing in for the wrapper pointer, and for the handle it carries."""
    ptr, handle, spans = {param: -1}, {}, []
    for _ in range(4):                        # fixpoint; alias chains are 1-2 deep in practice
        grew = False
        for m in ASSIGN.finditer(body):
            if body[m.start(2) + 1:m.start(2) + 2] == '=':
                continue                      # ==, not an assignment
            name, rhs = m.group(1), m.group(3).strip().strip('() \t\n')
            hit = re.fullmatch(r'(\w+)\s*(?:\[[^\]]*\])?', rhs)
            if hit and hit.group(1) in ptr and name not in ptr:
                ptr[name] = m.end()
                grew = True
                continue
            hit = re.fullmatch(r'(\w+)\s*(?:\[[^\]]*\])?\s*->\s*' + field, rhs)
            if hit and hit.group(1) in ptr and name not in handle:
                handle[name] = m.end()
                spans.append((m.start(), m.end()))
                grew = True
        if not grew:
            break
    return ptr, handle, spans


def classify(body, start, end, helpers):
    """'guard', 'use', or None (not a use at all) for one occurrence of the handle."""
    after, before = body[end:end + 40], body[max(0, start - 80):start]
    if re.match(r'\s*\.\s*IsNull\s*\(', after):
        return 'guard'                        # this occurrence IS the guard
    if re.search(r'DownCast\s*\(\s*$', before):
        return None                           # null-safe: DownCast(null) returns null
    call = enclosing_call(body, start)
    if call in helpers:
        return 'guard'                        # the callee IsNull-checks it before using it
    return 'use'


def unguarded_sites(parsed, helpers):
    """Every (file, line, function, parameter) whose handle reaches OCCT without an IsNull test."""
    found = []
    for path, raw, text, ctext, lines, funcs in parsed:
        for name, params, bs, be in funcs:
            body = ctext[bs:be + 1]
            for param, field, is_array in wrapper_params(params):
                if (os.path.basename(path), name) in ALLOWED:
                    continue
                ptr, handle, spans = aliases(body, param, field)
                ev = []
                for a, bound in ptr.items():
                    pat = re.compile(r'\b' + re.escape(a) + r'\s*(?:\[[^\]]*\])?\s*->\s*'
                                     + field + r'\b')
                    for u in pat.finditer(body):
                        if u.start() < bound or any(s <= u.start() < e for s, e in spans):
                            continue          # before the alias exists, or merely binding one
                        kind = classify(body, u.start(), u.end(), helpers)
                        if kind:
                            ev.append((u.start(), kind))
                for h, bound in handle.items():
                    pat = re.compile(r'(?<![\w>.])' + re.escape(h) + r'\b')
                    for u in pat.finditer(body):
                        if u.start() < bound or re.match(r'\s*=(?!=)', body[u.end():u.end() + 4]):
                            continue
                        kind = classify(body, u.start(), u.end(), helpers)
                        if kind:
                            ev.append((u.start(), kind))
                ev.sort()
                first = next((p for p, k in ev if k == 'use'), None)
                if first is None or any(k == 'guard' and p < first for p, k in ev):
                    continue
                line = text.count('\n', 0, bs + first) + 1
                found.append(Site(os.path.basename(path), line, name, param, field,
                                   lines[line - 1].strip() if line <= len(lines) else '', is_array,
                                   'wrapper'))
    return found


def local_handle_sites(parsed, helpers):
    """#666: every local Handle(Geom_Curve)/Handle(Geom2d_Curve)/Handle(Geom_Surface), obtained
    from a BRep_Tool:: call rather than a wrapper argument, that reaches a use before an IsNull
    test - the #656 shape. Same (file, line, function, name) shape as unguarded_sites(), tagged
    'local' in the last field so main()'s report can tell the two origins apart.

    Two things a wrapper argument never needed:

    * A SCOPE FENCE, now genuinely block-scope-aware (round-2 review of #666: the original fence
      was textual, not scoped - it ended a name's tracking window at the next `Handle(...) name =
      BRep_Tool::...` redeclaration and nothing else, so (a) a sibling redeclaration from ANY OTHER
      SOURCE (`name = SomeOtherFactory(...)`, no `BRep_Tool::`) didn't fence at all, since it never
      matched `LOCAL_HANDLE_DECL`, and (b) a redeclaration inside a NESTED block ended the outer
      variable's window right there, so a real use of the OUTER variable resuming after the nested
      block closed was silently dropped - proven, not just suspected: reverting this fix to the old
      end-bound reproduces a live miss on exactly that shape (self-test fixture `W`).

      `var_declarations()`/`binds_to()` replace the linear "next same-name redeclaration" fence with
      real C++ block scoping: every ANY_HANDLE_DECL-typed declaration of the name in the function -
      any producer, not just `BRep_Tool::` - is tagged with its own immediately-enclosing block, and
      each occurrence of the name binds to the innermost still-in-scope declaration at that point
      (`binds_to`), the same rule the C++ compiler itself uses. This subsumes both guard-removal
      fixtures the old fence needed (G1: two sibling `switch`-case declarations of `surf` correctly
      resolve to their own case, since each case's occurrences fall outside the other case's block;
      G2: an unrelated earlier guard on the same bare name - a parameter, never a candidate
      declaration at all - cannot protect a later local, since it was never in `decls_by_var` to
      begin with) and additionally fixes the nested-block miss neither fixture exercised.

    * THE SAME `spans`-STYLE EXCLUSION `unguarded_sites()` ALREADY HAD, extended here (round-2
      review: without it, a mid-window reassignment of the tracked name - `c = BRep_Tool::Curve(...)`
      with no `Handle(...)` retype, so it doesn't touch the scope fence above at all - was itself
      picked up by the use-scan and misclassified as an unguarded use, even when the reassigned
      value goes on to be properly guarded before its real read: self-test fixture `X` reproduces
      this as a live false positive against the pre-fix code). The exclusion does not make a
      reassignment's OWN un-rechecked null risk visible - if the reassigned value is used
      unguarded and nothing rechecks it, the ORIGINAL declaration's earlier guard still (wrongly)
      reads as covering it, the identical false-negative trade-off `unguarded_sites()`'s own
      `spans` exclusion already accepts for a wrapper-derived handle alias. Not new here, just
      inherited: re-verify a reassigned handle by eye same as a reassigned alias.

    A shadow from a declaration of a DIFFERENT, untracked shape (`auto name = ...;` with no type
    name to anchor on, or an unrelated type like `TopoDS_Face name;`) still doesn't fence - neither
    is matched by `ANY_HANDLE_DECL`, which only knows the three tracked `Handle`/`occ::handle<>`
    types - and remains exactly the residual the module docstring's "FOUR MORE, SAME CLASS" section
    already describes for the deduced-type case. No known instance of either in this tree today.
    """
    found = []
    for path, raw, text, ctext, lines, funcs in parsed:
        for name, params, bs, be in funcs:
            if (os.path.basename(path), name) in ALLOWED:
                continue
            body = ctext[bs:be + 1]
            decls_by_var = var_declarations(body)
            for m in LOCAL_HANDLE_DECL.finditer(body):
                var, callee = m.group(3), m.group(4)
                mine = m.start()
                pat = re.compile(r'(?<![\w>.])' + re.escape(var) + r'\b')
                ev = []
                for u in pat.finditer(body, m.end()):
                    if binds_to(decls_by_var.get(var, ()), u.start()) != mine:
                        continue                      # a later/sibling redeclaration owns this one
                    if re.match(r'\s*=(?!=)', body[u.end():u.end() + 4]):
                        continue                      # binds/rebinds the name, not a read
                    kind = classify(body, u.start(), u.end(), helpers)
                    if kind:
                        ev.append((u.start(), kind))
                ev.sort()
                first = next((p for p, k in ev if k == 'use'), None)
                if first is None or any(k == 'guard' and p < first for p, k in ev):
                    continue
                line = text.count('\n', 0, bs + first) + 1
                found.append(Site(os.path.basename(path), line, name, var, callee,
                                   lines[line - 1].strip() if line <= len(lines) else '', False,
                                   'local'))
    return found


def all_sites(sources):
    """The full report: both handle origins, one combined list. Parses every file once
    (`parse_sources`) and shares that parse across `guarding_helpers()` and both site walks,
    rather than each redoing it (#666 round-2 review, item 8)."""
    parsed = parse_sources(sources)
    helpers = guarding_helpers(parsed)
    return unguarded_sites(parsed, helpers) + local_handle_sites(parsed, helpers)


def bridge_sources():
    paths = sorted(glob.glob(os.path.join(SRC_DIR, '*.mm'))) + \
        sorted(glob.glob(os.path.join(SRC_DIR, '*.h')))
    return [(p, open(p).read()) for p in paths]


# Each fixture is one bridge function in one of the shapes this tree actually uses. The MISSED
# half must be reported; the CLEAN half must not. Before #618 the detector matched `param->field`
# only, so it scored 1/6 on MISSED - it caught the plain form and nothing else.
MISSED = [
    ('reinterpret_cast straight into OCCT', '''
int OCCTFixtureA(OCCTSurfaceRef s) {
    try { Splitter sp; sp.Init(reinterpret_cast<OCCTSurface*>(s)->surface); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    ('handle alias bound through a cast', '''
int OCCTFixtureB(OCCTSurfaceRef surfaceRef) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        Splitter sp; sp.Init(surface); return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    ('pointer alias through a C-style cast', '''
int OCCTFixtureC(OCCTSurfaceRef surface) {
    try { auto* s = (OCCTSurface*)surface; GeomAdaptor_Surface a(s->surface); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    ('static_cast spelling', '''
int OCCTFixtureD(OCCTCurve3DRef c) {
    try { Splitter sp; sp.Init(static_cast<OCCTCurve3D*>(c)->curve); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    ('array element through a cast', '''
int OCCTFixtureE(const OCCTCurve3DRef* refs, int n) {
    try {
        for (int i = 0; i < n; i++) {
            auto* w = reinterpret_cast<OCCTCurve3D*>(refs[i]);
            seq.Append(w->curve);
        }
        return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    # The pre-#618 form. It must keep being caught: the fix is additive, not a replacement.
    ('plain param->field, no indirection', '''
int OCCTFixtureF(OCCTCurve3DRef curve) {
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    # #666: the #656 shape itself - a local handle from BRep_Tool::, not a wrapper argument.
    ('local handle from BRep_Tool::, passed onward unguarded (the #656 shape)', '''
double OCCTFixtureM(OCCTShapeRef edgeRef, OCCTShapeRef faceRef) {
    try {
        double first, last;
        Handle(Geom2d_Curve) c2d = BRep_Tool::CurveOnSurface(edgeRef->shape, faceRef->shape, first, last);
        return BRepTools::EvalAndUpdateTol(edgeRef->shape, c2d, first, last);
    } catch (...) { return 0.0; }
}''', 'local'),
    # #666: FUNC must see through `extern "C"` on the definition line, or this whole function -
    # an otherwise-plain, otherwise-caught unguarded site - is invisible to every check below.
    ('extern "C" on the definition line must not hide the function', '''
extern "C" int OCCTFixtureN(OCCTCurve3DRef curve) {
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    # #666 (G2): the scope fence's LOWER bound. An unrelated, earlier guard on the same bare name
    # (here, a same-named parameter) must not be read as covering a later local that shadows it.
    ('an earlier guard on an unrelated same-named parameter must not shadow a later local', '''
bool OCCTFixtureO(OCCTSurfaceRef surf, OCCTShapeRef faceRef) {
    try {
        if (!surf || surf->surface.IsNull()) return false;
        {
            Handle(Geom_Surface) surf = BRep_Tool::Surface(faceRef->shape);
            return surf->IsUPeriodic();
        }
    } catch (...) { return false; }
}''', 'local'),
    # #666 follow-up: the constructor-init connector. LOCAL_HANDLE_DECL required `name =
    # BRep_Tool::...(`; this is #656's exact shape written with parens instead - `name(BRep_Tool::
    # ...(`. The module docstring already warned this spelling defeats the wrapper-argument walk's
    # alias binding; it applied equally here and was unaddressed until now.
    ('local handle from BRep_Tool::, constructor-init paren syntax (the #656 shape, no `=`)', '''
double OCCTFixtureT(OCCTShapeRef edgeRef, OCCTShapeRef faceRef) {
    try {
        double first, last;
        Handle(Geom2d_Curve) c2d(BRep_Tool::CurveOnSurface(edgeRef->shape, faceRef->shape, first, last));
        return BRepTools::EvalAndUpdateTol(edgeRef->shape, c2d, first, last);
    } catch (...) { return 0.0; }
}''', 'local'),
    # #666 follow-up: the `occ::handle<>` spelling had never been exercised for a LOCAL
    # declaration (only for a helper's parameter type, fixture R) - the regex already covered it,
    # but nothing proved that until this fixture.
    ('local handle from BRep_Tool::, occ::handle<> spelling, unguarded', '''
double OCCTFixtureU(OCCTShapeRef edgeRef) {
    try {
        double first, last;
        occ::handle<Geom_Curve> curve = BRep_Tool::Curve(edgeRef->shape, first, last);
        return curve->FirstParameter();
    } catch (...) { return 0.0; }
}''', 'local'),
    # #666 round-2 review: FUNC already parses a function defined inside an `extern "C" { ... }`
    # block - the block's own braces are just ordinary text to `functions()`, and the function
    # signature inside has no `extern "C"` text of its own to hide it - so this was NEVER blind,
    # contrary to what the module docstring used to claim. Not a new guard (nothing in FUNC changes
    # for this fixture to pass); it freezes the corrected claim against a future regression, the
    # same reasoning fixture N used for the inline form.
    ('extern "C" block form (as opposed to the inline prefix) must not hide a function either', '''
extern "C" {

int OCCTFixtureV(OCCTCurve3DRef curve) {
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}

}''', 'wrapper'),
    # #666 round-2 review (item 1): the scope fence used to be purely textual - it ended a name's
    # tracking window only at the next *BRep_Tool::-sourced* redeclaration of that name, so it never
    # noticed a redeclaration inside a NESTED block, and a real use of the OUTER variable resuming
    # after that block closes was silently dropped. Confirmed empirically against the pre-fix code
    # before this fixture was written: `all_sites()` returned `[]` for this exact shape.
    ('outer local resumes after a nested same-named redeclaration closes; the outer use is real', '''
double OCCTFixtureW(OCCTShapeRef edgeRef, OCCTShapeRef otherEdgeRef) {
    try {
        double first, last;
        Handle(Geom2d_Curve) c2d = BRep_Tool::CurveOnSurface(edgeRef->shape, edgeRef->shape, first, last);
        {
            double f2, l2;
            Handle(Geom2d_Curve) c2d = BRep_Tool::CurveOnSurface(otherEdgeRef->shape, otherEdgeRef->shape, f2, l2);
            if (c2d.IsNull()) return 0.0;
            DoSomething(c2d);
        }
        return BRepTools::EvalAndUpdateTol(edgeRef->shape, c2d, first, last);
    } catch (...) { return 0.0; }
}''', 'local'),
]

# The other failure mode, and the one #624/#630 was: a detector taught indirection can start
# reporting correct code. Each of these guards its handle in a way the tree really uses.
CLEAN = [
    ('plain two-condition opener', '''
int OCCTFixtureG(OCCTCurve3DRef curve) {
    if (!curve || curve->curve.IsNull()) return 0;
    try { Splitter sp; sp.Init(curve->curve); return 1; }
    catch (...) { return 0; }
}''', 'wrapper'),
    ('guarded through the handle alias', '''
int OCCTFixtureH(OCCTSurfaceRef surfaceRef) {
    try {
        auto& surface = reinterpret_cast<OCCTSurface*>(surfaceRef)->surface;
        if (surface.IsNull()) return 0;
        Splitter sp; sp.Init(surface); return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    ('guarded through a by-value Handle copy', '''
int OCCTFixtureI(OCCTSurfaceRef initialSurface) {
    try {
        auto wrapper = (OCCTSurface*)initialSurface;
        Handle(Geom_Surface) workSurface = wrapper->surface;
        if (workSurface.IsNull()) return 0;
        NLPlate_NLPlate solver(workSurface); return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    ('guarded through the pointer alias', '''
int OCCTFixtureJ(OCCTSurfaceRef surface, OCCTCurve2DRef curve2d) {
    try {
        auto* sw = (OCCTSurface*)surface;
        auto* cw = (OCCTCurve2D*)curve2d;
        if (!sw || sw->surface.IsNull() || !cw || cw->curve.IsNull()) return 0;
        GeomAdaptor_Surface a(sw->surface); return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    ('DownCast is not a use', '''
int OCCTFixtureK(OCCTCurve2DRef curveRef) {
    try {
        auto& curve = reinterpret_cast<OCCTCurve2D*>(curveRef)->curve;
        Handle(Geom2d_BSplineCurve) bsp = Handle(Geom2d_BSplineCurve)::DownCast(curve);
        if (bsp.IsNull()) return 0;
        return 1;
    } catch (...) { return 0; }
}''', 'wrapper'),
    # Form 4. The handle is checked one frame away, inside the shared helper - the shape that
    # makes a naive indirection-aware detector wrong about OCCTGeomConvertCurveToAnalytical.
    ('guarded by the bridge helper it is passed to', '''
inline bool occtFixtureToAnalytical(const occ::handle<Geom_Curve>& curve, double tol) {
    if (curve.IsNull()) return false;
    GeomConvert_CurveToAnaCurve converter(curve);
    return converter.ConvertToAnalytical(tol);
}
int OCCTFixtureL(OCCTCurve3DRef curveRef) {
    if (!curveRef) return 0;
    return occtFixtureToAnalytical(reinterpret_cast<OCCTCurve3D*>(curveRef)->curve, 1e-7) ? 1 : 0;
}''', 'wrapper'),
    # #666: local handle from BRep_Tool::, guarded before use - the actual #656 fix, reduced.
    ('local handle from BRep_Tool::, guarded before use', '''
double OCCTFixtureP(OCCTShapeRef edgeRef, OCCTShapeRef faceRef) {
    try {
        double first, last;
        Handle(Geom2d_Curve) c2d = BRep_Tool::CurveOnSurface(edgeRef->shape, faceRef->shape, first, last);
        if (c2d.IsNull()) return 0.0;
        return BRepTools::EvalAndUpdateTol(edgeRef->shape, c2d, first, last);
    } catch (...) { return 0.0; }
}''', 'local'),
    # #666: a local handle from BRep_Tool:: consumed only by DownCast is the same null-safe
    # exclusion as a wrapper-derived one - this is the bridge's real Copy()+DownCast clone idiom.
    ('local handle from BRep_Tool:: consumed only by DownCast', '''
bool OCCTFixtureQ(OCCTShapeRef faceRef) {
    try {
        Handle(Geom_Surface) surf = BRep_Tool::Surface(faceRef->shape);
        Handle(Geom_Plane) plane = Handle(Geom_Plane)::DownCast(surf);
        if (plane.IsNull()) return false;
        return true;
    } catch (...) { return false; }
}''', 'local'),
    # #666: local handle from BRep_Tool::, guarded one call frame away by the bridge helper.
    ('local handle from BRep_Tool::, guarded by the bridge helper it is passed to', '''
inline bool occtFixtureCurveGuard(const occ::handle<Geom_Curve>& curve, double tol) {
    if (curve.IsNull()) return false;
    return true;
}
bool OCCTFixtureR(OCCTShapeRef edgeRef) {
    double first, last;
    Handle(Geom_Curve) curve = BRep_Tool::Curve(edgeRef->shape, first, last);
    return occtFixtureCurveGuard(curve, 1e-7);
}''', 'local'),
    # #666 (G1): two sibling scopes reuse the same local name, each independently guarded via
    # DownCast. Reduced from the real false positive an early version of this detector reported
    # on OCCTFaceGetPrimaryAxis, where the SECOND case's properly-guarded `surf` was misread as
    # covering the FIRST case's (also-guarded, but via DownCast) `surf`.
    ('two sibling scopes reuse the same local name, each independently guarded via DownCast', '''
bool OCCTFixtureS(OCCTShapeRef faceRef, int mode) {
    try {
        if (mode == 0) {
            Handle(Geom_Surface) surf = BRep_Tool::Surface(faceRef->shape);
            Handle(Geom_Plane) p = Handle(Geom_Plane)::DownCast(surf);
            if (p.IsNull()) return false;
            return true;
        }
        Handle(Geom_Surface) surf = BRep_Tool::Surface(faceRef->shape);
        Handle(Geom_CylindricalSurface) c = Handle(Geom_CylindricalSurface)::DownCast(surf);
        if (c.IsNull()) return false;
        return true;
    } catch (...) { return false; }
}''', 'local'),
    # #666 round-2 review (item 7): a mid-window reassignment of the tracked name (`c = BRep_Tool::
    # Curve(...)`, no `Handle(...)` retype, so it never touches the scope fence at all) used to be
    # picked up by the use-scan itself and misclassified as an unguarded use, even though `c` really
    # is guarded before its one dereferencing read. Confirmed empirically against the pre-fix code
    # before this fixture was written: the reassignment line itself was reported as unguarded.
    ('a plain reassignment of the tracked name is a rebind, not a read, even mid-window', '''
double OCCTFixtureX(OCCTShapeRef edgeRef, OCCTShapeRef otherEdgeRef) {
    try {
        double first, last;
        Handle(Geom_Curve) c = BRep_Tool::Curve(edgeRef->shape, first, last);
        c = BRep_Tool::Curve(otherEdgeRef->shape, first, last);
        if (c.IsNull()) return 0.0;
        return c->FirstParameter();
    } catch (...) { return 0.0; }
}''', 'local'),
]


def self_test():
    """Prove both failure modes: an unguarded site is reported, a guarded one is not.

    Every fixture is tagged 'wrapper' or 'local' for the mechanism it exercises, and is checked
    TWICE: once through that mechanism directly (unguarded_sites()/local_handle_sites(), with a
    shared `helpers`, matching how all_sites() itself combines them), and once through the
    combined all_sites() - the same round-trip #666's own report used, since a fixture that only
    exercises one origin still has to survive the OTHER walk running over it unharmed (e.g. a
    local-handle fixture must not trip the wrapper-argument walk, and vice versa).

    #666 round-2 review (item 5): checking only the combined all_sites() result, as this used to,
    proves some detector in the union catches each fixture - not specifically that the mechanism a
    fixture is FOR still does. A regression confined to unguarded_sites()/classify()/aliases() that
    happened to leave the union's answer unchanged for every 'wrapper' fixture would have passed
    silently. Checking the direct mechanism per fixture closes that.
    """
    failed = 0
    for name, src, walk in MISSED:
        sources = [('fixture.mm', src)]
        parsed = parse_sources(sources)
        helpers = guarding_helpers(parsed)
        direct = unguarded_sites(parsed, helpers) if walk == 'wrapper' \
            else local_handle_sites(parsed, helpers)
        hit = all_sites(sources)
        ok = bool(direct) and bool(hit)
        failed += not ok
        print(f'  {"ok  " if ok else "MISS"} unguarded, {name}: '
              f'{hit[0].func + "(" + hit[0].name + ")" if hit else "NOT REPORTED"}')
    for name, src, walk in CLEAN:
        sources = [('fixture.mm', src)]
        parsed = parse_sources(sources)
        helpers = guarding_helpers(parsed)
        direct = unguarded_sites(parsed, helpers) if walk == 'wrapper' \
            else local_handle_sites(parsed, helpers)
        hit = all_sites(sources)
        ok = not direct and not hit
        failed += not ok
        print(f'  {"ok  " if ok else "FALSE"} guarded, {name}: '
              f'{hit[0].func + " wrongly reported" if hit else "not reported"}')
    total = len(MISSED) + len(CLEAN)
    print(f'{total - failed}/{total} cases correct')
    return 1 if failed else 0


def main():
    quiet = '--quiet' in sys.argv
    if '--self-test' in sys.argv:
        return self_test()
    if not os.path.isdir(SRC_DIR):
        print(f'{SRC_DIR} not found - run from the repo root', file=sys.stderr)
        return 2
    sources = bridge_sources()
    sites = all_sites(sources)
    if not sites:
        if not quiet:
            print('All bridge functions guard the geometry handle as well as the wrapper pointer.')
            print(f'({len(ALLOWED)} site(s) exempt by name in ALLOWED, each with its reason.)')
        return 0
    if not quiet:
        print(f'{len(sites)} site(s) reach OCCT with an unchecked handle:\n')
        for s in sites:
            print(f'  {s.file}:{s.line}  {s.func}({s.name})')
            print(f'      {s.src}')
            if s.kind == 'local':
                # `s.name` is a local, not a wrapper argument: there is no pointer to null-check
                # alongside it, just the handle itself, obtained from `s.detail` (the BRep_Tool::
                # call that produced it).
                print(f'      obtained from {s.detail}(); want: if ({s.name}.IsNull()) return <fallback>;')
            elif s.is_array:
                # `s.name` is a pointer to wrappers, so `s.name->s.detail` would not compile. The
                # guard belongs on the element, inside the loop that reads it.
                print(f'      want, per element of {s.name}:  '
                      f'if (!e || e->{s.detail}.IsNull()) return <fallback>;')
            else:
                print(f'      want: if (!{s.name} || {s.name}->{s.detail}.IsNull()) return <fallback>;')
    return 1


if __name__ == '__main__':
    sys.exit(main())
