# #982: refman coverage audit, OCAF framework layer (Pass 3b of #807)

Three files:

| file | what it is |
|---|---|
| `derive_lane.py` | the lane's real bridge/Swift call surface, by call. The five-package list itself is CONSUMED from `Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 982`, per #982's own instruction not to re-derive it by grep; what this file derives instead is which files and functions actually reach it, and two nearby same-named-family attribute classes that are NOT this lane. |
| `refman_census.py` | the census. 51 classes, four verdicts, an over-coverage sweep, a family-count assertion, a lane re-derivation, and its own self-test. |
| `selftest_removal_matrix.py` | the proof that the self-test's guards are load-bearing, adapted from #811/#812's own matrix. Found one design inconsistency on its first run: `declares_member` shipped a `return None` propagation branch the shape inventory could not account for, because this lane (unlike #812's) has no alias-template class to make it reachable; removed rather than left unproven. |

```bash
python3 Scripts/repro/982-refman-coverage-ocaf-framework/derive_lane.py
python3 Scripts/repro/982-refman-coverage-ocaf-framework/derive_lane.py --calls
python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py
python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --verbose
python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --reverify-lane
python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --self-test
python3 Scripts/repro/982-refman-coverage-ocaf-framework/selftest_removal_matrix.py
```

All run from any cwd, in about a second. The checks that read the pinned headers report SKIPPED
rather than passing silently without `Libraries/OCCT.xcframework` (this worktree symlinks
`Libraries/` to the sibling checkout at `/Users/elb/Projects/OCCTSwift/Libraries`, pinned to the
same `V8_0_1` + patches asset as this branch's own `Package.swift`; a fresh clone or CI has
neither).

## Result

| verdict | count |
|---|---|
| `ok` | 9 |
| `deliberate, recorded` | 42 |
| `under` | 0 |
| `over` | 0 (the script derives it: 2 confirmed, both fixed in this PR, 0 remaining) |

**Before this PR the same table read `ok` 9, `deliberate, recorded` 0, `under` 42.** All 42 have a
real, measured reason now recorded in `docs/occtswift-wrapping-gaps.md`'s new "OCAF framework
layer" section.

## What the lane actually is

#982's own `## Lane` text already names the five packages and their per-package header/wrapped
counts, sourced from #973's partition census: `TFunction_` (14 headers), `TPrsStd_` (12), `TObj_`
(23), `AppStd_` (1), `AppStdL_` (1) -- 51 headers. `partition_census.py --pass 982` prints that
table verbatim; `refman_census.py --reverify-lane` re-derives the 51 class names directly from the
pinned kernel and diffs them against `LANE_CLASSES`, confirming an exact match.

**Consuming the package list did not mean skipping the file-level derivation #812's own
`derive_lane.py` did for its lane.** `derive_lane.py` here walks which Swift files and bridge
functions actually reach these five packages: all 37 lane bridge calls live in ONE file,
`Sources/OCCTBridge/src/OCCTBridge_Document.mm` (no second, independently-evolved call path to
reconcile, unlike #812's HLR lane), and the real Swift surface is `DriverTable.swift` and
`TObjApplication.swift` (both wholly in-lane) plus the TFunction-prefixed sections of
`Document.swift` and `AssemblyNode.swift` (both files carry much larger OCAF-attribute surfaces
outside this lane).

**Two nearby, easily-confused attribute families sit in those same two multi-lane files and are
explicitly NOT this lane**, confirmed by reading the `#include` two lines above each bridge
function rather than assumed from a similar name:

- `Document.swift`'s `TDataXtd_Presentation` section (`OCCTDocumentSetPresentation`/
  `OCCTDocumentHasPresentation`/`OCCTDocumentPresentation*`) builds `TDataXtd_Presentation`.
  `TPrsStd_AISPresentation`, this lane's actual class with a name one word different, is never
  constructed anywhere in this bridge at all (see NOT_OUR_VIEWER below).
- `AssemblyNode.swift`'s `XCAFDoc_GraphNode` section (`OCCTDocumentSetGraphNodeAttr`/
  `OCCTDocumentGraphNodeSetChild`/...) builds `XCAFDoc_GraphNode`, XCAF's own assembly-DAG
  attribute (Pass 3's territory, #810), not `TFunction_GraphNode` (this lane's regeneration-
  dependency graph, reached by the sibling, differently-suffixed `OCCTDocumentSetGraphNode`/
  `OCCTDocumentGraphNode*` functions two hundred lines earlier in the same file). The bridge
  function name's `Attr` infix is the only textual difference and is load-bearing, not accidental.

## Two shapes #982 said to expect, and what each turned out to be

**"`TFunction_` is half wrapped ... a doc claim about the regeneration contract being complete is
exactly the kind of over-coverage to look for."** No such doc claim exists (`grep -rn regenerat
docs/reference/*.md docs/API_REFERENCE.md` returns nothing) -- checked, not found. But the census's
own `named_in_bridge` test found something sharper than the issue text predicted:
`TFunction_Iterator`, "Iterator of the graph of functions" per its own header, the class that
actually WALKS the regeneration dependency graph in execution order, is `#include`d at
`OCCTBridge_Document.mm:10324` and never constructed. An early hand read of this bridge during this
audit assumed the `#include` meant it was wrapped (the same assumption the issue table's own
approximate "7 wrapped" count would produce if you counted the include); the script's own measured
test caught that wrong. This bridge wraps every OTHER piece of the regeneration mechanism (mark a
label driven, register a driver by GUID, track dependency edges, log what changed) but not the one
class that would let a caller actually drive a regeneration in the right order. Recorded as a real
capability gap in `docs/occtswift-wrapping-gaps.md`, not folded into a curated excuse it doesn't
fit, and not fixed here: #982 is a coverage audit, not a wrapping pass.

**"`TPrsStd_AISPresentation` overlaps Pass 4d's `AIS_` surface at the boundary ... check it isn't
documented by neither pass nor double-counted by both."** Checked against #814's own `## Lane`
text directly: Pass 4d's lane is `BRepMesh_`/`Poly_`/`IMeshData_`/`IMeshTools_`/`AIS_`/
`Graphic3d_`/`Image_`/`StdPrs_`/`StdSelect_` -- `TPrsStd_` is not in it, so `TPrsStd_AISPresentation`
belongs to this lane alone, with no double-count risk. It is also the one class this pass's own
over-coverage sweep found genuinely wrong-attributed (see below), which is a coincidence of which
class the issue happened to flag, not a causal connection.

## What found the over-coverage, and what happened to each finding

`Scripts/census-doc-occt-attribution.py --lane TFunction_,TPrsStd_,TObj_,AppStd_,AppStdL_` (#928)
surfaced **1 candidate**, confirmed TRUE (unlike #811/#812's lanes, where every candidate the
detector surfaced turned out to be a false positive):

```
docs/reference/Document-XCAF-Notes.md:1863  TPrsStd_AISPresentation  [heading]  subject=initStandard  via=OCCTDriverTableInitStandard
```

Read against the real code: `TPrsStd_DriverTable::InitStandardDrivers()`'s own body (read directly
in `Libraries/occt-src/src/ApplicationFramework/TKVCAF/TPrsStd/TPrsStd_DriverTable.cxx`, not
inferred) binds six `TPrsStd_Driver` subclasses to their `TDataXtd_*` attribute GUIDs
(`TPrsStd_AxisDriver`, `ConstraintDriver`, `GeometryDriver`, `NamedShapeDriver`, `PlaneDriver`,
`PointDriver`) and never touches `TPrsStd_AISPresentation` anywhere. The doc's own prose was simply
wrong about which class gets registered. **Fixed in this PR** (`docs/reference/Document-XCAF-Notes.md`,
docs-only): the bullet now names the six real driver classes.

**A second finding, found by hand rather than by this detector, and a demonstration of exactly why
a detector alone isn't enough.** `docs/reference/Document-XCAF-Notes.md:1945` attributed
`TObjApplication.createDocument()` to `TObj_Application::NewDocument`. Reading `TObj_Application.hxx`
directly: it declares no `NewDocument` method at all. `TDocStd_Application::NewDocument` (the base
class) IS a real, declared method -- `void`-returning, no format argument the way
`CreateNewDocument` takes one -- and `TObj_Application` inherits it but never overrides it, and the
bridge (`OCCTTObjApplicationCreateDocument`, `OCCTBridge_Document.mm`) never calls it; it calls
`CreateNewDocument`, `TObj_Application`'s own override, two lines below in the same header. **Two
detectors, checked directly, both miss this shape**, for different reasons stated in
`refman_census.py`'s own docstring rather than merely asserted:

- `census-doc-occt-attribution.py`'s class-level `reachable()` walker: `TObj_Application` genuinely
  IS named inside `OCCTTObjApplicationCreateDocument`'s body (the `static_cast<TObj_Application*>`
  and `Handle(TObj_Application) hApp(a)` lines), so its reachability test passes and the tool's own
  `--lane` run above does not flag this line at all.
- This pass's own `check_method_attributions()`/`declares_member`: `declares_member("TObj_Application",
  "NewDocument")` correctly answers `True`, because the method genuinely is declared, on the base
  class, and inherited (confirmed as `SELF_TEST_CASES`' own third case, which is a positive `True`
  case rather than a negative one -- the self-test proves the checker is RIGHT to say True here,
  which is exactly what makes the doc's citation impossible to catch this way). The defect is not
  "a name that doesn't exist"; it is "the right class citing the wrong one of two real methods with
  the same base-class-inherited name."

**Fixed in this PR** (docs-only): the bullet now cites `CreateNewDocument` and explains the
divergence from the inherited-but-unused `NewDocument`.

Beyond the automated pass and this one hand-found case, every remaining `- **OCCT:**` bullet
touching this lane was read against the pinned headers: `TFunction_Scope`'s six wrapped methods
(`AddFunction`/`RemoveFunction`/`HasFunction`/`RemoveAllFunctions`/`GetFunctions`/`GetFreeID`, all
confirmed), `TFunction_GraphNode`'s eight (`AddPrevious`/`AddNext`/`RemovePrevious` two overloads
each/`GetStatus`/`SetStatus`/`RemoveAllPrevious`/`RemoveAllNext`, all confirmed),
`TFunction_Logbook`'s `SetTouched`/`SetImpacted`/`IsModified`/`Clear`/`IsEmpty` (all confirmed,
`SetTouched` specifically because it is an inline, non-`Standard_EXPORT` declaration -- a shape
`declares_member`'s method-call regex has to match without relying on the `Standard_EXPORT` prefix,
which every other lane class happens to use), `TFunction_Function`'s `Failed`/`SetFailure`/
`GetFailure`, `TFunction_DriverTable`'s `HasDriver`/`Clear`, and `TObj_Application`'s
`GetInstance`/`IsVerbose`/`SetVerbose`. No further finding.

## The findings (under-coverage)

41 of the 42 unwrapped-and-undocumented classes are recorded reasons rather than genuine capability
gaps, following six curated categories (full reasons, with header line citations, are in
`docs/occtswift-wrapping-gaps.md`'s new "OCAF framework layer" section, not repeated here so this
README going stale cannot make the gate pass on the wrong evidence): 8 deprecated collection-typedef
headers, 4 classes requiring an application-specific subclass (protected constructor or
pure-virtual method, each confirmed directly at the header), 17 `TObj_` classes that are internal
machinery of that same subclassing framework, 10 `TPrsStd_` classes that populate an
`AIS_InteractiveObject` through OCCT's own live-viewer pipeline this bridge does not use (Metal
instead, the same fact #812's `Prs3d_` finding rests on), and 2 legacy `TDocStd_Application`
resource-name subclasses superseded by #371's direct instantiation.

**The 42nd, `TFunction_Iterator`, is the one genuine capability gap** (see above): recorded
honestly as `REAL_GAP` rather than squeezed into REQUIRES_SUBCLASSING (it needs no subclass, its
constructor is public) or TOBJ_FRAMEWORK_INTERNAL (it is not a `TObj_` class, and its own package's
regeneration mechanism has no other internal-machinery bucket). Not wrapped in this PR: #982 is a
coverage audit, and `docs/v2.0.0-plan.md`'s own scope note is explicit that a correctness/coverage
release adds no new operations. A future wrapping-focused release is the right place for a
`functionIterator()`-shaped entry point.

## Proving the detectors fail

`selftest_removal_matrix.py` switches off each accepting shape in turn:

```
declares_member baseline: 15/15 cases pass unmodified

  method-call          disabled -> 7/15 cases fail  [load-bearing]
  nested-type          disabled -> 1/15 cases fail  [load-bearing]
  data-member          disabled -> 1/15 cases fail  [load-bearing]
  base-class-walk      disabled -> 3/15 cases fail  [load-bearing]
  own-header-absent    disabled -> 1/15 cases fail  [load-bearing]

_ATTRIBUTION_RE baseline: 6/6 cases pass with the shipped pattern

  closing-backtick-anchor    imposed -> 2/6 cases fail  [load-bearing]
  no-leading-backtick        imposed -> 1/6 cases fail  [load-bearing]

classify baseline (real tree): {'ok': 9, 'deliberate, recorded': 42, 'under': 0}
  docs-first AND gaps.md-as-docs -> {'ok': 51, ...}   [load-bearing]
    ordering alone                -> {'ok': 13, 'deliberate, recorded': 38, ...}  [load-bearing]
    gaps.md-as-docs alone         -> {'ok': 9, 'deliberate, recorded': 42, ...}   [redundant on this lane]
```

**One design inconsistency was found on the first run, before any self-test case existed to hide
it.** `declares_member` was first written by adapting #812's own version, which follows a
`using X = Template<...>` alias when a class's own header declares no `class`/`struct` of its name.
This lane has no such class (every one of the 51 headers is either a real `class X : public Y`
declaration, a deprecated typedef header, or a plain enum -- verified directly, not assumed), so
that branch was dropped. But the base-walk loop's `if sub is None: return None` propagation line
was left in place, and `selftest_removal_matrix.py`'s own shape-inventory check (`declares_member
has 2 return None paths, this file covers 1`) caught the mismatch on its first run: a walk of every
lane class's full base-class chain (`AppStd_Application -> TDocStd_Application -> CDF_Application ->
CDM_Application -> Standard_Transient`, and five others) confirmed every base's own header is
shipped, so that propagation branch could never actually fire and had no self-test case exercising
it, matching the shape #812's own removal matrix found once for `data-member`. Removed rather than
left as untested defensive code; `declares_member`'s base-walk loop now simply tries the next base
on an unreachable class instead of short-circuiting the whole search, which is unreachable here for
the same reason.

**Both directions of the main check were proved by injection, not merely reasoned about**:

- `docs/occtswift-wrapping-gaps.md`'s `TFunction_Iterator` mention was replaced tree-wide with a
  placeholder; `refman_census.py` re-run reported it `under` ("no line in
  occtswift-wrapping-gaps.md") and exited 1. Restoring the file returned it to `deliberate, recorded`
  and exit 0. (The first attempt at this replaced only the FIRST of two mentions in the paragraph --
  the constructor citation a few lines below the heading also names the class -- and produced a
  false "still clean" result, itself a small demonstration of why a single `grep -c` count matters
  before trusting an injection.)
- Each of `KNOWN_OVER_FINDINGS`' two entries was reverted to its pre-fix wording in
  `docs/reference/Document-XCAF-Notes.md` in turn; `refman_census.py` re-run reported the matching
  `REGRESSION:` line and exited 1 for each. Restoring the file returned both to a clean, exit-0 run,
  byte-identical to the run before either injection.

`wrapped-before-curated` reports 0 lane classes on this lane (none of the 9 wrapped classes appear
in any curated table) -- kept anyway, since the property under test is the RULE ("wrapped beats
curated"), not that this particular lane has a live instance of it; #811/#812 keep the same check
for the identical reason on their own lanes.

## What this pass did not do

- **No general-purpose gate promotion.** Same status as #811/#812 left
  `census-doc-occt-attribution.py` in: still a report, not a gate, per CLAUDE.md's own accounting of
  its measured false-positive rate (41% over a 40-row sample). Measured on this lane: 1 candidate,
  1 true (100%), the smallest sample of the three lanes it has now run on and not enough on its own
  to move the aggregate rate.
- **`TObj_Application::CreateNewDocument`/`GetInstance`/`IsVerbose`/`SetVerbose`,
  `TPrsStd_DriverTable::InitStandardDrivers`/`Get`/`Clear`, and the ten `TFunction_` members listed
  above were the only members of this lane's classes checked by `check_method_attributions()`** (41
  attributions found tree-wide naming a lane class with `::`, all resolving cleanly against the
  pinned headers after this PR's two fixes); the other 41 classes have zero `Class::Member` doc or
  bridge-comment attributions naming them at all, consistent with most of them being internal
  machinery or a live-viewer subsystem nobody writes prose about.
- **`TFunction_Iterator` was recorded, not wrapped.** See "The findings" above.
