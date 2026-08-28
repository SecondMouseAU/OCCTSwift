#!/usr/bin/env python3
"""Issue #982 (Pass 3b of #807): refman coverage census for the OCAF framework layer.

WHY A SCRIPT, NOT A LIST IN THE ISSUE: `docs/v2.0.0-plan.md`'s census rule, and this repo's history
of hand-built censuses that were confidently wrong differently each time (#558, #571, #573, #583,
#595, #507, #553, #562). #811/#812 (Pass 4a/4b) are the template this file follows.

THE LANE IS CONSUMED, NOT RE-DERIVED. Unlike #812, #982's own text says not to re-derive this lane
by grep: `Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 982` prints the
already-derived, already-committed package set (five packages, 51 headers), and
`derive_lane.py` next to this file walks the actual bridge/Swift call surface for those five
packages rather than re-deriving the package list itself. `--reverify-lane` below re-derives the
CLASS list (the 51 header basenames) from the pinned kernel and diffs it against `LANE_CLASSES`,
which is a different, narrower check than re-deriving the five-package set #982's own text forbids.

TWO SHAPES #982 SAYS TO EXPECT, both confirmed, and one of them sharper than expected:

  1. `TFunction_` is half wrapped, and the half that IS wrapped has its own gap the issue text
     didn't name. `grep -rn regenerat docs/reference/*.md docs/API_REFERENCE.md` returns nothing,
     so no doc claims completeness of the regeneration mechanism (the specific over-coverage shape
     #982 warns about is checked and absent). But `TFunction_Iterator` -- "Iterator of the graph of
     functions" per its own header, the class that actually WALKS the dependency graph in
     regeneration order (`More`/`Next`/`Current`, `GetMaxNbThreads` for parallel execution) -- is
     `#include`d at `OCCTBridge_Document.mm:10324` and never constructed: `functionScopeCount`
     reads `scope->GetFunctions().Extent()` directly, and nothing else in the bridge references the
     class at all. So the bridge wraps every PIECE of the regeneration mechanism (mark a label
     driven, register a driver by GUID, track a dependency graph node, log what changed) except the
     one class that would let a caller actually drive a regeneration in the right order. This is a
     genuine capability gap, not internal machinery, and it was found by this census's own
     `named_in_bridge` test doing its job: an earlier hand read of the bridge (recorded in this
     PR's own history) assumed the `#include` meant the class was wrapped, and the script caught
     that assumption wrong. See REAL_GAP below.
  2. `TPrsStd_AISPresentation` overlaps Pass 4d's `AIS_` surface at the boundary. Checked against
     #814's own `## Lane` text: Pass 4d's lane is `BRepMesh_`, `Poly_`, `IMeshData_`/`IMeshTools_`,
     `AIS_`, `Graphic3d_`, `Image_`, `StdPrs_`, `StdSelect_` -- `TPrsStd_` is not in it. So
     `TPrsStd_AISPresentation` is unambiguously this lane's to classify, not double-counted and not
     falling through the crack #982's own words warn about. It IS the one real, documented-with-a-
     wrong-attribution over-coverage finding this pass found (see OVER-COVERAGE below), and its
     under-coverage verdict is curated, not a bare `under` (see NOT_OUR_VIEWER).

WRAPPED COUNT. #982's own table (from #973's partition census) says "TFunction_ 7 wrapped, TObj_ 1
wrapped, TPrsStd_ 1 wrapped" -- a per-PACKAGE approximate count from #973, not #982's own
class-by-class audit. This census's own `named_in_bridge` test (identical methodology to #811/#812:
a token match against every non-comment line of `Sources/OCCTBridge/{src,include}`) agrees with it
exactly once counted the same way: `TFunction_ExecutionStatus` is `ok` alongside the 7 the issue
table names, because the bridge reads it by value (`static_cast<TFunction_ExecutionStatus>(status)`,
`OCCTBridge_Document.mm:4687`), the same way #812's own census counted
`HLRBRep_TypeOfResultingEdge` "read by value, not by name" as `ok` -- but `TFunction_Iterator`,
which an early draft of this table counted as wrapped on the strength of its `#include` alone,
is not (see point 1 above), so the two counts land on the same total, 7, by two different
adjustments that happen to cancel. Both numbers describe the same 14 classes; this census's is the
one built by the same measured rule as #811/#812, not a correction of #973's package-level
approximation.

TWO QUESTIONS, per #982:

  UNDER-COVERAGE: an OCCT class in the lane we neither wrap (named on a line of
  `Sources/OCCTBridge/{src/*.mm,include/*.h}` that does not START with `#include`, `//`, `*` or
  `/*`) nor document (named anywhere under `docs/` except `docs/CHANGELOG.md` and
  `docs/occtswift-wrapping-gaps.md`, whose whole subject is what is NOT wrapped), with no reason
  recorded in that gaps file.

  Measured before this PR: 51 lane classes, 9 wrapped, 42 neither wrapped nor documented, 0 of the
  51 named anywhere in `docs/occtswift-wrapping-gaps.md`. Base verdicts: 9 ok, 0
  deliberate/recorded, 42 under.

  Six curated reasons cover all 42, each measured against the pinned header rather than guessed
  from the name (see CLASSIFICATION RULES below): 8 deprecated collection-typedef headers, 4
  classes that require an application-specific subclass before anything in them is reachable
  (protected constructor or pure-virtual method, each confirmed directly), 17 TObj_ classes that
  are internal machinery of that same subclassing framework (iterators, persistence-attribute
  storage, checker/assistant helpers -- every one takes or returns a `TObj_Object`/`TObj_Model`
  handle, so none is independently usable without the framework the 4 above require), 10 TPrsStd_
  classes that populate an `AIS_InteractiveObject` through OCCT's own `AIS_InteractiveContext`/
  `V3d_Viewer` live-viewer pipeline (confirmed: neither type is referenced anywhere in this bridge
  or these docs -- OCCTSwift's display layer is Metal via OCCTSwiftViewport, the same fact #812's
  own `Prs3d_` finding rests on), 2 legacy `TDocStd_Application` resource-name subclasses OCCT's
  own header comment calls "Legacy", superseded in this bridge by #371's direct
  `TDocStd_Application` instantiation, and 1 real capability gap, `TFunction_Iterator`, recorded as
  one rather than folded into a curated excuse it doesn't fit (see point 1 above and REAL_GAP).

  OVER-COVERAGE: something current docs assert that the pinned kernel does not support. Two
  confirmed findings, both fixed in this same PR (see KNOWN_OVER_FINDINGS):

    1. `docs/reference/Document-XCAF-Notes.md:1945` attributed `TObjApplication.createDocument()`
       to `TObj_Application::NewDocument`. `TObj_Application` declares no such method; the bridge
       (`OCCTTObjApplicationCreateDocument`, `OCCTBridge_Document.mm`) calls `CreateNewDocument`,
       `TObj_Application`'s own override, two lines away in the same header from a real but
       DIFFERENT inherited method, `TDocStd_Application::NewDocument` (`void`-returning, no format
       argument the same way). **This shape cannot be caught by `check_method_attributions()`
       below**: `declares_member("TObj_Application", "NewDocument")` correctly answers `True`,
       because the method genuinely IS declared, on the base class, and inherited. The defect is
       not "a name that doesn't exist", it is "the right class citing the wrong one of two real
       methods with the same base-class-inherited name", a shape `census-doc-occt-attribution.py`'s
       class-level `reachable()` walker cannot see either (`TObj_Application` genuinely IS named in
       `OCCTTObjApplicationCreateDocument`'s body, so its own `--lane` run does not flag this line).
       Found by hand, reading the header directly, which is the whole reason this class of finding
       needs a human per class rather than a detector alone.
    2. `docs/reference/Document-XCAF-Notes.md:1863` attributed `DriverTable.initStandard()` to
       `TPrsStd_DriverTable::Get` + "`TPrsStd_AISPresentation` standard driver registration".
       `TPrsStd_DriverTable::InitStandardDrivers()`'s own body (read directly, not inferred) binds
       six `TPrsStd_Driver` subclasses (`TPrsStd_AxisDriver`/`ConstraintDriver`/`GeometryDriver`/
       `NamedShapeDriver`/`PlaneDriver`/`PointDriver`) to their `TDataXtd_*` attribute GUIDs and
       never touches `TPrsStd_AISPresentation` anywhere. THIS shape WAS caught by
       `census-doc-occt-attribution.py --lane` (an UNREACHED finding: the class exists, but
       `OCCTDriverTableInitStandard` never reaches it), the textbook case the tool is built for.

  Both fixed directly in this PR (docs-only, no Swift/bridge/kernel change); `KNOWN_OVER_FINDINGS`
  below pins the WRONG text so a regression back to either is caught the moment either reappears.

CLASSIFICATION RULES. Mechanical unless a class is in one of the curated tables, each entry
established during #982 by reading the pinned header directly and, for the TPrsStd_ viewer-pipeline
claim, by confirming `AIS_InteractiveContext`/`V3d_Viewer` are referenced nowhere else in this
bridge or these docs (`grep -rln AIS_InteractiveContext Sources/OCCTBridge` and the docs
equivalent, both empty).

  - DEPRECATED_COLLECTION_ALIASES: the header carries `Standard_HEADER_DEPRECATED` at file scope,
    deprecated since OCCT 8.0.0, "use NCollection_X directly". 8 of the 51: five under
    `TFunction_*Of*Driver*`/`TFunction_DoubleMapOfIntegerLabel`, `TObj_Container` and
    `TObj_SequenceOfIterator` (both declare no class of their own header-basename name either, only
    deprecated typedefs), and `TPrsStd_DataMapOfGUIDDriver`.
  - REQUIRES_SUBCLASSING: a protected constructor (`TObj_Object`, `TObj_Model`, `TObj_Partition`,
    each confirmed directly at its own `.hxx`) or a pure-virtual method with no default body
    (`TFunction_Driver::Execute`, `= 0` at `TFunction_Driver.hxx:68`) -- nothing beyond the already-
    wrapped entry point (`TObj_Application`, or `TFunction_Function`/`GraphNode`/`Iterator`/`Scope`
    driving a driver this bridge never subclasses) is constructible without an application-specific
    subclass, which the bridge architecture doesn't support (the same limitation
    `docs/occtswift-wrapping-gaps.md`'s existing "Classes Not Wrapped (require abstract subclass
    implementations)" section already names for `ChFi3d_FilBuilder`/`Approx_FitAndDivide`/
    `BRepBlend_AppSurface`).
  - TOBJ_FRAMEWORK_INTERNAL: a concrete TObj_ class that takes or returns a
    `Handle(TObj_Object)`/`Handle(TObj_Model)`/`TDF_Label` under that framework's own tree
    structure, or a `TObj_ObjectIterator` subclass walking one, with no capability independent of
    an application's own `TObj_Object`/`TObj_Model` subclass (which REQUIRES_SUBCLASSING already
    covers): the six iterator classes (`TObj_LabelIterator`, `TObj_ModelIterator`,
    `TObj_ObjectIterator`, `TObj_OcafObjectIterator`, `TObj_ReferenceIterator`,
    `TObj_SequenceIterator`), the
    label-attribute storage classes `TObj_Object`'s own persistence writes
    (`TObj_TObject`/`TObj_TReference`/`TObj_TXYZ`/`TObj_TNameContainer`/`TObj_TModel`/
    `TObj_TIntSparseArray`), the model-registry/checker/root-partition helpers
    (`TObj_Assistant`, `TObj_CheckModel`, `TObj_Persistence`, `TObj_HiddenPartition`), and the one
    enum parameter of `TObj_Object::RemoveObject`-family calls, `TObj_DeletingMode`.
  - NOT_OUR_VIEWER: reaches, or is reached only by, `AIS_InteractiveContext`/`V3d_Viewer`
    (`TPrsStd_AISPresentation`, `TPrsStd_AISViewer`, both confirmed via their own `#include`s), or
    is a `TPrsStd_Driver` subclass/the abstract `TPrsStd_Driver` interface itself/its static helper
    (`TPrsStd_AxisDriver`/`ConstraintDriver`/`GeometryDriver`/`NamedShapeDriver`/`PlaneDriver`/
    `PointDriver`/`Driver`/`ConstraintTools`) populating an `AIS_InteractiveObject` for that same
    pipeline. `AIS_InteractiveContext`/`V3d_Viewer` are referenced nowhere in this bridge or these
    docs; OCCTSwift's display layer is Metal via OCCTSwiftViewport (the same fact #812's `Prs3d_`
    finding rests on, confirmed independently rather than inherited).
  - LEGACY_RESOURCE_SUBCLASS: `AppStd_Application`/`AppStdL_Application`, whose own header doc
    comment is verbatim "Legacy class defining resources name for standard/lite OCAF documents",
    each a `TDocStd_Application` subclass overriding only `ResourcesName()` to point at a different
    resource file. Since #371 this bridge already constructs `TDocStd_Application` directly rather
    than any subclass singleton; neither legacy subclass adds a capability #371's direct
    instantiation lacks.
  - REAL_GAP: a genuine, directly-constructible capability this bridge does not offer, recorded
    honestly rather than folded into a curated excuse it doesn't fit. `TFunction_Iterator` is the
    one: a public constructor (no subclassing needed, unlike REQUIRES_SUBCLASSING), never reached
    by anything the bridge wraps. See point 1 in the module docstring for the full mechanism.

The wrapped test runs BEFORE the curated tables, following #808/#810/#811/#812: a table entry
claiming a class has no call sites must not be able to mask one that does.

ONE LIMITATION, inherited from #808/#809/#810/#811/#812 rather than rediscovered: `deliberate,
recorded` means the class NAME appears somewhere in `docs/occtswift-wrapping-gaps.md`, not that the
sentence around it is a reason. Every class this pass files as recorded is named in a bullet this
pass wrote carrying its measured reason, so the name match and the reason coincide today; the test
cannot tell the difference tomorrow.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py
    python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --verbose
    python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --reverify-lane
    python3 Scripts/repro/982-refman-coverage-ocaf-framework/refman_census.py --self-test

Exits 1 on a `KNOWN_OVER_FINDINGS` regression, on a method attribution naming a member the pinned
headers do not declare, on an `under` with no `docs/occtswift-wrapping-gaps.md` line, on a family-
count drift, or on lane drift under `--reverify-lane`. Exits 0 otherwise.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
DOCS_DIR = os.path.join(ROOT, "docs")
GAPS_FILE = os.path.join(DOCS_DIR, "occtswift-wrapping-gaps.md")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

LANE_PACKAGES = ("TFunction", "TObj", "TPrsStd", "AppStd", "AppStdL")

LANE_HEADER_RE = re.compile(r"^(TFunction|TObj|TPrsStd|AppStd|AppStdL)(_[^.]+)?\.hxx$")

# ------------------------------------------------------------------------------------------------
# The lane: 51 classes, enumerated from the pinned kernel's own headers (OCCT 8.0.1 plus the
# carried patches) on 2026-08-28, matching #973's partition census exactly (`partition_census.py
# --pass 982`). `--reverify-lane` re-derives this from the pinned headers and diffs against it:
#
#   ls Libraries/OCCT.xcframework/macos-arm64/Headers \
#     | grep -E '^(TFunction|TObj|TPrsStd|AppStd|AppStdL)(_[^.]+)?\.hxx$' | sed 's/\.hxx$//' | sort
# ------------------------------------------------------------------------------------------------

LANE_CLASSES: dict[str, list[str]] = {
    "AppStd": ["AppStd_Application"],
    "AppStdL": ["AppStdL_Application"],
    "TFunction": [
        "TFunction_Array1OfDataMapOfGUIDDriver", "TFunction_DataMapOfGUIDDriver",
        "TFunction_DataMapOfLabelListOfLabel", "TFunction_DoubleMapOfIntegerLabel",
        "TFunction_Driver", "TFunction_DriverTable", "TFunction_ExecutionStatus",
        "TFunction_Function", "TFunction_GraphNode", "TFunction_HArray1OfDataMapOfGUIDDriver",
        "TFunction_IFunction", "TFunction_Iterator", "TFunction_Logbook", "TFunction_Scope",
    ],
    "TObj": [
        "TObj_Application", "TObj_Assistant", "TObj_CheckModel", "TObj_Container",
        "TObj_DeletingMode", "TObj_HiddenPartition", "TObj_LabelIterator", "TObj_Model",
        "TObj_ModelIterator", "TObj_Object", "TObj_ObjectIterator", "TObj_OcafObjectIterator",
        "TObj_Partition", "TObj_Persistence", "TObj_ReferenceIterator", "TObj_SequenceIterator",
        "TObj_SequenceOfIterator", "TObj_TIntSparseArray", "TObj_TModel", "TObj_TNameContainer",
        "TObj_TObject", "TObj_TReference", "TObj_TXYZ",
    ],
    "TPrsStd": [
        "TPrsStd_AISPresentation", "TPrsStd_AISViewer", "TPrsStd_AxisDriver",
        "TPrsStd_ConstraintDriver", "TPrsStd_ConstraintTools", "TPrsStd_DataMapOfGUIDDriver",
        "TPrsStd_Driver", "TPrsStd_DriverTable", "TPrsStd_GeometryDriver",
        "TPrsStd_NamedShapeDriver", "TPrsStd_PlaneDriver", "TPrsStd_PointDriver",
    ],
}

FAMILY_COUNTS = {"AppStd": 1, "AppStdL": 1, "TFunction": 14, "TObj": 23, "TPrsStd": 12}
LANE_TOTAL = 51

# ------------------------------------------------------------------------------------------------
# Curated classification tables. Each reason was read off the pinned header during #982; see the
# module docstring for the two facts (protected/pure-virtual constructors, the AIS_InteractiveContext/
# V3d_Viewer absence) confirmed directly rather than inferred from a class name.
# ------------------------------------------------------------------------------------------------

DEPRECATED_COLLECTION_ALIASES = {
    c: "file-scope Standard_HEADER_DEPRECATED, deprecated since OCCT 8.0.0, use NCollection directly"
    for c in [
        "TFunction_Array1OfDataMapOfGUIDDriver", "TFunction_DataMapOfGUIDDriver",
        "TFunction_DataMapOfLabelListOfLabel", "TFunction_DoubleMapOfIntegerLabel",
        "TFunction_HArray1OfDataMapOfGUIDDriver", "TObj_Container", "TObj_SequenceOfIterator",
        "TPrsStd_DataMapOfGUIDDriver",
    ]
}

REQUIRES_SUBCLASSING = {
    "TFunction_Driver": "pure-virtual Execute() (`= 0` at TFunction_Driver.hxx:68), the "
                       "regeneration logic every driver must implement; the bridge registers "
                       "drivers by GUID (TFunction_DriverTable::HasDriver/Clear, wrapped) but "
                       "never subclasses this itself, the same 'bridge architecture doesn't "
                       "support implementing a C++ abstract class' limitation "
                       "docs/occtswift-wrapping-gaps.md already names for ChFi3d_FilBuilder/"
                       "Approx_FitAndDivide/BRepBlend_AppSurface",
    "TObj_Object": "protected constructor (TObj_Object.hxx:99, confirmed directly): 'the base "
                  "class for OCAF based TObj models', instantiable only via an application-"
                  "specific subclass",
    "TObj_Model": "protected constructor (TObj_Model.hxx, TObj_Model()), same pattern as "
                 "TObj_Object one level up the framework",
    "TObj_Partition": "protected constructor (TObj_Partition.hxx:46), same pattern",
}

_TOBJ_FRAMEWORK_REASON = ("internal machinery of the TObj object-model framework "
                          "REQUIRES_SUBCLASSING covers (TObj_Object/TObj_Model/TObj_Partition, "
                          "all protected constructors): takes or returns a "
                          "Handle(TObj_Object)/Handle(TObj_Model) or walks one, no capability "
                          "independent of an application's own subclass of the framework root, "
                          "which nothing in this bridge provides (only TObj_Application, the "
                          "already-wrapped singleton entry point, is reached)")

TOBJ_FRAMEWORK_INTERNAL = {c: _TOBJ_FRAMEWORK_REASON for c in [
    "TObj_Assistant", "TObj_CheckModel", "TObj_DeletingMode", "TObj_HiddenPartition",
    "TObj_LabelIterator", "TObj_ModelIterator", "TObj_ObjectIterator", "TObj_OcafObjectIterator",
    "TObj_Persistence", "TObj_ReferenceIterator", "TObj_SequenceIterator", "TObj_TIntSparseArray",
    "TObj_TModel", "TObj_TNameContainer", "TObj_TObject", "TObj_TReference", "TObj_TXYZ",
]}

_NOT_OUR_VIEWER_REASON = ("populates, or is reached only through, OCCT's own live-viewer "
                          "presentation pipeline (AIS_InteractiveContext/V3d_Viewer, confirmed "
                          "referenced nowhere in this bridge or these docs); OCCTSwift's display "
                          "layer is Metal via OCCTSwiftViewport, the same fact #812's Prs3d_ "
                          "finding rests on")

NOT_OUR_VIEWER = {c: _NOT_OUR_VIEWER_REASON for c in [
    "TPrsStd_AISPresentation", "TPrsStd_AISViewer", "TPrsStd_AxisDriver",
    "TPrsStd_ConstraintDriver", "TPrsStd_ConstraintTools", "TPrsStd_Driver",
    "TPrsStd_GeometryDriver", "TPrsStd_NamedShapeDriver", "TPrsStd_PlaneDriver",
    "TPrsStd_PointDriver",
]}

LEGACY_RESOURCE_SUBCLASS = {
    "AppStd_Application": "own header doc comment: \"Legacy class defining resources name for "
                         "standard OCAF documents\"; a TDocStd_Application subclass overriding "
                         "only ResourcesName(). Since #371 this bridge constructs "
                         "TDocStd_Application directly rather than any subclass singleton, which "
                         "this legacy subclass adds no capability beyond",
    "AppStdL_Application": "same shape, \"Legacy class defining resources name for lite OCAF "
                          "documents\" (the TKLCAF-only format set)",
}

REAL_GAP = {
    "TFunction_Iterator": "\"Iterator of the graph of functions\" (its own header doc comment): "
                         "walks the regeneration dependency graph in execution order "
                         "(More/Next/Current, GetMaxNbThreads for parallel batches). Publicly "
                         "constructible (TFunction_Iterator(const TDF_Label&), no subclassing "
                         "needed), #include-d at OCCTBridge_Document.mm:10324, and never "
                         "constructed: OCCTDocumentFunctionScopeCount reads "
                         "scope->GetFunctions().Extent() directly instead. This bridge wraps "
                         "every OTHER piece of the regeneration mechanism (TFunction_Function to "
                         "mark a label driven, TFunction_DriverTable to register a driver by "
                         "GUID, TFunction_GraphNode for dependency edges, TFunction_Logbook for "
                         "change tracking) but not the class that would let a caller actually "
                         "walk them in dependency order. A genuine gap, not internal machinery; "
                         "recording it here rather than wrapping it, since #982 is a coverage "
                         "audit, not a wrapping pass (see docs/v2.0.0-plan.md's own scope note).",
}

CURATED: dict[str, tuple[str, str]] = {}
for _table, _label in (
    (DEPRECATED_COLLECTION_ALIASES, "DEPRECATED_COLLECTION_ALIASES"),
    (REQUIRES_SUBCLASSING, "REQUIRES_SUBCLASSING"),
    (TOBJ_FRAMEWORK_INTERNAL, "TOBJ_FRAMEWORK_INTERNAL"),
    (NOT_OUR_VIEWER, "NOT_OUR_VIEWER"),
    (LEGACY_RESOURCE_SUBCLASS, "LEGACY_RESOURCE_SUBCLASS"),
    (REAL_GAP, "REAL_GAP"),
):
    for _cls, _why in _table.items():
        CURATED[_cls] = (_label, _why)

# ------------------------------------------------------------------------------------------------
# Over-coverage. Two confirmed findings, both fixed in this same PR (docs-only). The strings below
# are the WRONG text as it read before the fix, collapsed the same way `_collapse` normalizes the
# live file, so a regression back to either is caught the moment either reappears.
# ------------------------------------------------------------------------------------------------

KNOWN_OVER_FINDINGS: list[tuple[str, str]] = [
    ("docs/reference/Document-XCAF-Notes.md", "**OCCT:** `TObj_Application::NewDocument`"),
    ("docs/reference/Document-XCAF-Notes.md",
     "**OCCT:** `TPrsStd_DriverTable::Get` + `TPrsStd_AISPresentation` standard driver "
     "registration"),
]
PRESENCE_EXEMPT_PINS: list[tuple[str, str]] = []
KNOWN_OVER_FINDING_COUNT = 2

METHOD_ATTRIBUTION_ALLOWED: set[tuple[str, str]] = set()

_ATTRIBUTION_RE = re.compile(
    r"`([A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)?)::([A-Za-z_][A-Za-z0-9_]*)"
)

# ------------------------------------------------------------------------------------------------
# Measurement (same shape as #811/#812's refman_census.py; see those files for the rationale on
# each choice -- the comment-prefix collapse, the wrapped-before-curated ordering, the gaps.md
# exclusion). `declares_member`/`_header_bases` are DELIBERATELY SIMPLER than #812's: this lane has
# no `using X = Template<...>` alias-template class (every one of the 51 headers is either a real
# `class X : public Y` declaration, a deprecated typedef header, or a plain enum), so the
# alias-following branch and its None-propagation companion are omitted rather than shipped with no
# case to prove them, per okf/policies/prove-the-test-fails.md -- a branch no self-test case can
# break is decoration, and #812's own removal matrix found exactly that shape once already.
# `selftest_removal_matrix.py` next to this file proves the shapes THIS file does ship.
# ------------------------------------------------------------------------------------------------

def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


_COMMENT_PREFIX_RE = re.compile(r"^\s*(?:///|//!|//|\*(?!/))\s?")


def _collapse(text: str) -> str:
    lines = [_COMMENT_PREFIX_RE.sub("", ln) for ln in text.splitlines()]
    return " ".join(" ".join(lines).split())


def _lane_class_names() -> set[str]:
    return {c for classes in LANE_CLASSES.values() for c in classes}


def _bridge_files() -> list[str]:
    out = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if os.path.isfile(p) and fn.endswith((".mm", ".h")):
                out.append(p)
    return out


def _doc_files() -> list[str]:
    out = []
    for dirpath, _dirs, files in os.walk(DOCS_DIR):
        for fn in sorted(files):
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                out.append(os.path.join(dirpath, fn))
    return out


_TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def named_in_bridge(cls: str, cache) -> list[str]:
    return sorted(cache["bridge_tokens"].get(cls, set()))


def named_in_docs(cls: str, cache) -> list[str]:
    return sorted(cache["doc_tokens"].get(cls, set()))


def build_cache():
    cache: dict = {"bridge_tokens": {}, "doc_tokens": {}}
    for path in _bridge_files():
        rel = os.path.relpath(path, ROOT)
        for line in _read(path).splitlines():
            stripped = line.strip()
            if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                continue
            for tok in _TOKEN_RE.findall(stripped):
                cache["bridge_tokens"].setdefault(tok, set()).add(rel)
    for path in _doc_files():
        rel = os.path.relpath(path, ROOT)
        text = _read(path)
        if os.path.abspath(path) == os.path.abspath(GAPS_FILE):
            continue
        for tok in _TOKEN_RE.findall(text):
            cache["doc_tokens"].setdefault(tok, set()).add(rel)
    cache["gaps"] = _read(GAPS_FILE) if os.path.exists(GAPS_FILE) else ""
    return cache


def recorded_in_gaps(cls: str, cache) -> bool:
    return bool(re.search(r"\b" + re.escape(cls) + r"\b", cache["gaps"]))


def classify(cls: str, cache) -> tuple[str, str, list[str], list[str]]:
    """(verdict, note, bridge hits, docs hits). See #811/#812's classify docstrings for why the
    ordering (wrapped, then curated, then documented, then under) and the gaps.md exclusion are
    both load-bearing on their own lanes; `selftest_removal_matrix.py` re-proves both here."""
    bridge = named_in_bridge(cls, cache)
    docs = named_in_docs(cls, cache)
    if bridge:
        note = "wrapped" if docs else "wrapped (undocumented by this exact class name)"
        return ("ok", note, bridge, docs)
    if cls in CURATED:
        label, why = CURATED[cls]
        if recorded_in_gaps(cls, cache):
            return ("deliberate, recorded", f"{label}: {why}", bridge, docs)
        return ("under", f"{label}: {why}, but no line in occtswift-wrapping-gaps.md",
                bridge, docs)
    if docs:
        return ("ok", "documented", bridge, docs)
    if recorded_in_gaps(cls, cache):
        return ("deliberate, recorded", "named in occtswift-wrapping-gaps.md, no curated table "
                "entry", bridge, docs)
    return ("under", "neither wrapped nor documented, and no reason recorded", bridge, docs)


# ------------------------------------------------------------------------------------------------
# Over-coverage regression check
# ------------------------------------------------------------------------------------------------

def check_known_over_findings() -> list[str]:
    msgs = []
    for rel, wrong in KNOWN_OVER_FINDINGS + PRESENCE_EXEMPT_PINS:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            msgs.append(f"{rel}: file is gone, so its pinned finding cannot be checked")
            continue
        if _collapse(wrong) in _collapse(_read(path)):
            msgs.append(f"{rel}: {wrong}")
    return msgs


def _header_bases(cls: str) -> list[str]:
    """Direct base classes of `cls`, from `class X : public Y[, public Z]` only. No alias-template
    following: see the module docstring for why this lane doesn't need that branch."""
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return []
    text = _read(path)
    m = re.search(r"^\s*(?:class|struct)\s+" + re.escape(cls) + r"\s*:\s*([^{]+)", text, re.M)
    if not m:
        return []
    out = []
    for part in m.group(1).split(","):
        for kw in ("public", "protected", "private", "virtual"):
            part = part.replace(kw, "")
        part = part.split("<")[0].strip()
        if part:
            out.append(part)
    return out


def declares_member(cls: str, member: str, seen: set[str] | None = None) -> bool | None:
    seen = seen if seen is not None else set()
    if cls in seen:
        return False
    seen.add(cls)
    path = os.path.join(OCCT_HEADERS, cls + ".hxx")
    if not os.path.exists(path):
        return None
    text = _read(path)
    if re.search(r"\b" + re.escape(member) + r"\s*\(", text):
        return True
    if re.search(r"\b(?:enum|class|struct|using|typedef)\s+(?:class\s+)?" + re.escape(member)
                 + r"\b", text):
        return True
    if re.search(r"\b" + re.escape(member) + r"\s*[;=]", text):
        return True
    for base in _header_bases(cls):
        sub = declares_member(base, member, seen)
        if sub is True:
            return True
        # NOT propagated further: measured (see selftest_removal_matrix.py's shape inventory)
        # that no base anywhere in this lane's chains has a missing header, so a `None` from a
        # base is unreachable here; treating it as "try the next base" rather than short-
        # circuiting the whole walk keeps this simple rather than shipping an unproven branch.
    return False


def check_method_attributions() -> tuple[bool, list[str], int]:
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, method-attribution check skipped"], 0)
    targets = _doc_files() + _bridge_files()
    msgs, checked = [], 0
    for path in targets:
        rel = os.path.relpath(path, ROOT)
        for lineno, line in enumerate(_read(path).splitlines(), 1):
            for cls, member in _ATTRIBUTION_RE.findall(line):
                if cls not in _lane_class_names():
                    continue
                if (cls, member) in METHOD_ATTRIBUTION_ALLOWED:
                    continue
                checked += 1
                if declares_member(cls, member) is False:
                    msgs.append(f"{rel}:{lineno}  {cls}::{member} is not declared by "
                                f"{cls}.hxx or any ancestor")
    return (True, msgs, checked)


def reverify_lane() -> tuple[bool, list[str]]:
    if not os.path.isdir(OCCT_HEADERS):
        return (False, [f"{OCCT_HEADERS} not present, lane re-derivation skipped"])
    derived = {fn[: -len(".hxx")] for fn in os.listdir(OCCT_HEADERS) if LANE_HEADER_RE.match(fn)}
    embedded = _lane_class_names()
    msgs = []
    for c in sorted(derived - embedded):
        msgs.append(f"in the pinned headers but NOT in LANE_CLASSES: {c}")
    for c in sorted(embedded - derived):
        msgs.append(f"in LANE_CLASSES but NOT in the pinned headers: {c}")
    return (True, msgs)


# ------------------------------------------------------------------------------------------------
# Self-test. `refman_census.py` is a repro artifact rather than a gate, but `declares_member` and
# `classify` are DETECTORS, and a detector that reports "all clear" because it is blind looks
# exactly like one reporting "all clear" because the tree is clean
# (okf/policies/prove-the-test-fails.md). `selftest_removal_matrix.py` next to this file switches
# off each accepting shape in turn and proves each case here actually needs it.
# ------------------------------------------------------------------------------------------------

SELF_TEST_CASES = [
    ("TFunction_Logbook", "SetTouched", True,
     "an inline method (no Standard_EXPORT), the one OCCTDocumentLogbookSetTouched calls -- "
     "proves the method-call shape isn't only ever matching Standard_EXPORT-prefixed declarations"),
    ("TFunction_Logbook", "SetUntouched", False,
     "plausible-sounding, does not exist: the real setter pair is SetTouched/SetImpacted"),
    ("TObj_Application", "CreateNewDocument", True,
     "declared locally on TObj_Application, the method OCCTTObjApplicationCreateDocument "
     "actually calls -- the CORRECT attribution this PR's fix now cites"),
    ("TObj_Application", "NewDocument", True,
     "declared on the BASE TDocStd_Application and inherited, so this correctly answers True -- "
     "and that is exactly why this shape defeats check_method_attributions(): the WRONG "
     "attribution this PR fixed cited a method that genuinely exists, just not the one the "
     "bridge calls. See KNOWN_OVER_FINDINGS and the module docstring."),
    ("TObj_Application", "NewDocumentFromTemplate", False,
     "plausible-sounding, does not exist anywhere in the two-level hierarchy"),
    ("TObj_HiddenPartition", "GetTypeFlags", True,
     "declared locally (override), no base walk needed"),
    ("TObj_HiddenPartition", "SetName", True,
     "NOT declared on TObj_HiddenPartition itself: found one level up on TObj_Partition, which "
     "overloads it -- the base-class-walk shape at depth 1"),
    ("TObj_HiddenPartition", "HasBackReferences", True,
     "NOT declared on TObj_HiddenPartition OR TObj_Partition: found two levels up on TObj_Object "
     "-- proves the walk isn't limited to one hop"),
    ("TObj_Object", "ChildTag", True,
     "a protected NESTED ENUM (TObj_Object::ChildTag), matched by neither the method-call shape "
     "(nothing follows it with `(`) nor the data-member one"),
    ("TObj_Object", "GrandChildTag", False,
     "a plausible-sounding nested type that does not exist"),
    ("TObj_Application", "myIsVerbose", True,
     "a private DATA MEMBER (bool myIsVerbose;), matched by neither the method-call shape nor "
     "the nested-type one"),
    ("TObj_Application", "myVerboseFlag", False,
     "a plausible-sounding field that does not exist: the real field is myIsVerbose above"),
    ("TPrsStd_DriverTable", "InitStandardDrivers", True,
     "the method OCCTDriverTableInitStandard actually calls -- the CORRECT attribution this "
     "PR's fix now cites"),
    ("TPrsStd_AISPresentation", "InitStandardDrivers", False,
     "the WRONG attribution docs/reference/Document-XCAF-Notes.md:1863 made before this PR: "
     "TPrsStd_AISPresentation declares no such method, InitStandardDrivers lives on "
     "TPrsStd_DriverTable"),
    ("TFunction_NoSuchClass", "Foo", None,
     "the class's own header is genuinely absent from the pinned kernel: declares_member must "
     "answer 'cannot say', not False, or a future OCCT rename would silently read as 'not "
     "declared' instead of 'unknown' -- the one None-return path this lane's simplified "
     "declares_member ships (see module docstring for why the alias-template one is omitted)"),
]

PARSE_SELF_TEST_CASES = [
    ("- **OCCT:** `TObj_Application::CreateNewDocument`.",
     [("TObj_Application", "CreateNewDocument")],
     "the plain spelling, closing backtick straight after the member"),
    ("- **OCCT:** `TFunction_Scope::GetFunctions()` count.",
     [("TFunction_Scope", "GetFunctions")],
     "the parenthesised spelling; a pattern anchored on the closing backtick would miss this"),
    ("`TFunction_Logbook::SetTouched()` then `TFunction_Logbook::SetImpacted()`.",
     [("TFunction_Logbook", "SetTouched"), ("TFunction_Logbook", "SetImpacted")],
     "two attributions on one line, so the walk is findall rather than search"),
    ("The `TObj_Application` handle is returned.", [],
     "a class named with no member, which must not produce a pair"),
    ("    table->InitStandardDrivers();", [],
     "a real line of OCCTBridge_Document.mm using -> not ::, must not match"),
    ("Reached through TObj_Application::CreateNewDocument rather than named directly.", [],
     "an unbackticked mention in prose is not an attribution"),
]


def run_self_test() -> int:
    print(f"self-test, parser: {len(PARSE_SELF_TEST_CASES)} cases against _ATTRIBUTION_RE")
    failed = 0
    for line, expected, why in PARSE_SELF_TEST_CASES:
        got = _ATTRIBUTION_RE.findall(line)
        ok = got == expected
        print(f"  {'PASS' if ok else 'FAIL'}  {why}")
        if not ok:
            print(f"        expected {expected}, got {got}")
            failed += 1

    if not os.path.isdir(OCCT_HEADERS):
        print(f"\nself-test, headers: SKIPPED, {OCCT_HEADERS} not present "
              "(the normal case in CI and in a fresh clone)")
        return 1 if failed else 0

    print(f"\nself-test, headers: {len(SELF_TEST_CASES)} cases against declares_member")
    for cls, member, expected, why in SELF_TEST_CASES:
        got = declares_member(cls, member)
        ok = got is expected
        print(f"  {'PASS' if ok else 'FAIL'}  {cls}::{member} -> {got}: {why}")
        if not ok:
            failed += 1

    print(f"\n{len(PARSE_SELF_TEST_CASES) + len(SELF_TEST_CASES) - failed} passed, {failed} failed")
    return 1 if failed else 0


# ------------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description="#982 refman coverage census, OCAF framework lane")
    ap.add_argument("--verbose", action="store_true", help="print the matching files per class")
    ap.add_argument("--reverify-lane", action="store_true",
                    help="re-derive the lane from the pinned headers and diff against LANE_CLASSES")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return run_self_test()

    exit_code = 0
    cache = build_cache()

    table_counts = {pkg: len(cs) for pkg, cs in LANE_CLASSES.items()}
    if table_counts != FAMILY_COUNTS:
        for pkg in sorted(set(table_counts) | set(FAMILY_COUNTS)):
            if table_counts.get(pkg) != FAMILY_COUNTS.get(pkg):
                print(f"FAMILY COUNT DRIFT: {pkg}: table has {table_counts.get(pkg)}, "
                      f"FAMILY_COUNTS says {FAMILY_COUNTS.get(pkg)}")
        exit_code = 1
    total = sum(table_counts.values())
    if total != LANE_TOTAL:
        print(f"LANE TOTAL DRIFT: table has {total}, LANE_TOTAL says {LANE_TOTAL}")
        exit_code = 1

    print(f"#982 OCAF framework lane: {total} classes across {len(LANE_CLASSES)} packages")
    print(f"{'class':<40} {'verdict':<22} note")
    print("-" * 130)

    tally = {"ok": 0, "deliberate, recorded": 0, "under": 0, "over": 0}
    unders = []
    for pkg in sorted(LANE_CLASSES):
        for cls in LANE_CLASSES[pkg]:
            verdict, note, bridge, docs = classify(cls, cache)
            tally[verdict] += 1
            if verdict == "under":
                unders.append((cls, note))
            print(f"{cls:<40} {verdict:<22} {note}")
            if args.verbose:
                if bridge:
                    print(f"{'':<40} {'':<22} bridge: {', '.join(bridge)}")
                if docs:
                    print(f"{'':<40} {'':<22} docs:   {', '.join(docs)}")

    print()
    print("verdicts:")
    for k in ("ok", "deliberate, recorded", "under"):
        print(f"  {k:<22} {tally[k]}")

    print()
    print(f"over-coverage findings tracked: {KNOWN_OVER_FINDING_COUNT} (both fixed in this PR, "
          f"see module docstring)")
    regressions = check_known_over_findings()
    if regressions:
        print("REGRESSION: the following fixed over-coverage findings have reappeared:")
        for m in regressions:
            print(f"  {m}")
        exit_code = 1
    else:
        print("  neither has regressed")

    checked, msgs, n = check_method_attributions()
    print()
    if not checked:
        print(f"method attributions: SKIPPED ({msgs[0]})")
    else:
        print(f"method attributions checked (this lane's classes only): {n}")
        if msgs:
            print("FINDINGS: a doc or bridge comment names a member the pinned headers do not "
                  "declare:")
            for m in msgs:
                print(f"  {m}")
            exit_code = 1
        else:
            print("  every one resolves against the pinned headers")

    if unders:
        print()
        print("UNDER-COVERAGE with no reason in docs/occtswift-wrapping-gaps.md:")
        for cls, note in unders:
            print(f"  {cls}: {note}")
        exit_code = 1

    if args.reverify_lane:
        print()
        ok, msgs = reverify_lane()
        if not ok:
            print(f"lane re-derivation: SKIPPED ({msgs[0]})")
        elif msgs:
            print("LANE DRIFT:")
            for m in msgs:
                print(f"  {m}")
            exit_code = 1
        else:
            print("lane re-derivation: the pinned headers still give exactly these 51 classes")

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
