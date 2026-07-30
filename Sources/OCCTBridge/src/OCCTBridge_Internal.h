//
//  OCCTBridge_Internal.h
//  OCCTSwift
//
//  Private (src-only) header for the OCCTBridge target. Holds the foundation
//  struct definitions and helper declarations that any per-area .mm file in
//  the bridge needs.
//
//  This header is NOT public — it's never imported from Swift. It exists so
//  that splitting OCCTBridge.mm into multiple translation units (issue #99)
//  doesn't require duplicating struct definitions in every file.
//
//  Per-area .mm conventions:
//    #import "../include/OCCTBridge.h"     // public C surface
//    #import "OCCTBridge_Internal.h"        // shared structs + helpers
//    #include <... area-specific OCCT headers ...>
//

#ifndef OCCTBridge_Internal_h
#define OCCTBridge_Internal_h

#include <algorithm>
#include <mutex>
#include <vector>

// === Foundation OCCT headers ===
//
// The minimum set required for the foundation struct definitions below.
// Per-area .mm files can include additional OCCT headers as needed; this
// header is intentionally not the kitchen sink.

#include <Standard.hxx>
#include <TopoDS_Shape.hxx>
#include <TopoDS_Wire.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shell.hxx>
#include <Geom_Curve.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom_Surface.hxx>
#include <GeomAbs_Shape.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Triangulation.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_Polygon2D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <BRepTools_History.hxx>
#include <TDocStd_Application.hxx>
#include <TDocStd_Document.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_VisMaterialTool.hxx>
#include <TDF_Label.hxx>
#include <TNaming_Scope.hxx>
#include <BRepOffsetAPI_MakeFilling.hxx>

// === Foundation struct definitions ===

struct OCCTShape {
    TopoDS_Shape shape;

    OCCTShape() {}
    OCCTShape(const TopoDS_Shape& s) : shape(s) {}
};

struct OCCTWire {
    TopoDS_Wire wire;

    OCCTWire() {}
    OCCTWire(const TopoDS_Wire& w) : wire(w) {}
};

struct OCCTEdge {
    TopoDS_Edge edge;

    OCCTEdge() {}
    OCCTEdge(const TopoDS_Edge& e) : edge(e) {}
};

struct OCCTFace {
    TopoDS_Face face;

    OCCTFace() {}
    OCCTFace(const TopoDS_Face& f) : face(f) {}
};

struct OCCTMesh {
    std::vector<float> vertices;
    std::vector<float> normals;
    std::vector<uint32_t> indices;
    std::vector<int32_t> faceIndices;     // Source B-Rep face index per triangle
    std::vector<float> triangleNormals;   // Per-triangle normals (nx,ny,nz per triangle)
};

// XDE Document for assembly structure, colors, materials (v0.6.0)
struct OCCTDocument {
    // #371: a private instance, NOT XCAFApp_Application::GetApplication() -- that singleton is
    // shared process-wide and was the root cause of #344/#349/#353 (CDF_Directory/driver-cache/
    // metadata-table races), per upstream maintainer feedback on OCCT#1396: OCCT's own guidance
    // since 7.1 is a private TDocStd_Application per caller, not the shared singleton.
    Handle(TDocStd_Application) app;
    Handle(TDocStd_Document) doc;
    Handle(XCAFDoc_ShapeTool) shapeTool;
    Handle(XCAFDoc_ColorTool) colorTool;
    Handle(XCAFDoc_VisMaterialTool) materialTool;
    std::vector<TDF_Label> labels;  // Label registry (index = labelId)
    // #363: per-document, not a shared process-wide static (see docNamingScopeMutex's
    // old comment / issue #361) -- TNaming_Scope's own NCollection_Map<TDF_Label>
    // myValid has no internal synchronization, and (independent of the race) sharing
    // one instance across every document meant one document's valid-label set could
    // leak into another's. Each OCCTDocument owns its own scope instead; the WithValid
    // ctor arg matches the shared instance's prior behavior (map-defined scope).
    TNaming_Scope namingScope{true};

    OCCTDocument() {
        app = new TDocStd_Application();
    }

    // Get or register a label, returns labelId
    int64_t registerLabel(const TDF_Label& label) {
        for (size_t i = 0; i < labels.size(); i++) {
            if (labels[i].IsEqual(label)) {
                return static_cast<int64_t>(i);
            }
        }
        labels.push_back(label);
        return static_cast<int64_t>(labels.size() - 1);
    }

    // Get label by ID
    TDF_Label getLabel(int64_t labelId) const {
        if (labelId < 0 || labelId >= static_cast<int64_t>(labels.size())) {
            return TDF_Label();
        }
        return labels[labelId];
    }
};

// 2D Drawing from HLR projection (v0.6.0)
struct OCCTDrawing {
    TopoDS_Shape visibleSharp;
    TopoDS_Shape visibleSmooth;
    TopoDS_Shape visibleOutline;
    TopoDS_Shape hiddenSharp;
    TopoDS_Shape hiddenSmooth;
    TopoDS_Shape hiddenOutline;
};

// === Geometry handle wrappers ===

struct OCCTCurve3D {
    Handle(Geom_Curve) curve;

    OCCTCurve3D() {}
    OCCTCurve3D(const Handle(Geom_Curve)& c) : curve(c) {}
};

struct OCCTCurve2D {
    Handle(Geom2d_Curve) curve;

    OCCTCurve2D() {}
    OCCTCurve2D(const Handle(Geom2d_Curve)& c) : curve(c) {}
};

struct OCCTSurface {
    Handle(Geom_Surface) surface;

    OCCTSurface() {}
    OCCTSurface(const Handle(Geom_Surface)& s) : surface(s) {}
};

// === Poly handle opaques ===

struct Poly_TriangulationOpaque {
    Handle(Poly_Triangulation) triangulation;
};

struct Poly_Polygon3DOpaque {
    Handle(Poly_Polygon3D) polygon;
};

struct Poly_Polygon2DOpaque {
    Handle(Poly_Polygon2D) polygon;
};

struct Poly_PolygonOnTriangulationOpaque {
    Handle(Poly_PolygonOnTriangulation) polygon;
};

// === History ===

// Wrapper for a BRepTools_History handle. Shared rather than area-local because
// two areas exchange it: the modeling area synthesizes one from a retained
// builder, and the BRepGraph area absorbs it into a graph's history layer.
struct OCCTHistoryStorage {
    Handle(BRepTools_History) history;
};

// === Mutex helpers ===
//
// Definitions live in OCCTBridge.mm. Marked extern so per-area TUs can call
// them without each ending up with its own static instance.

std::recursive_mutex& occtGlobalMutex();
std::mutex& igesMutex();
// #298: the fillet/chamfer serialization lock (occtFilletMutex) was removed in
// v1.12.3 — the underlying OCCT non-reentrancy (STATIC_SOLIDINDEX and the blend
// scratch) is now fixed in the pinned kernel via Scripts/patches/0003, so 3D
// fillet/chamfer builds are reentrant and no longer need serialising.
// #341: XCAFDoc_ShapeTool::theAutoNaming raced across concurrent OBJ/glTF/PLY
// bridge calls (confirmed via ThreadSanitizer against V8_0_0_p1) — fixed in the
// kernel via Scripts/patches/0011 (XCAFDoc_ShapeTool::AutoNamingScope). The
// interim meshCafMutex() bridge-side lock this comment used to describe was
// removed once the xcframework carried the patch.
// #349: CDF_Application::WriterFromFormat/ReaderFromFormat cache one storage/
// retrieval driver instance per format and reuse it for every Save/Load — the
// driver's own Write()/Read() isn't reentrant (e.g. BinLDrivers_
// DocumentStorageDriver's instance-level myRelocTable/myTypesMap scratch state),
// so two threads saving/loading the same format concurrently corrupt it
// (SIGSEGV in BinLDrivers_DocumentStorageDriver::Write/WriteSubTree, observed via
// OCCTDocumentSaveOCAF/OCCTDocumentSaveOCAFInPlace). Interim mitigation until a
// kernel fix lands — matches the #298/#341 PR1→PR2 pattern.
std::mutex& ocafStoreMutex();
// #361/#363: naming-scope state moved to a per-OCCTDocument TNaming_Scope field
// instead of one shared process-wide instance -- no lock needed, see OCCTDocument's
// namingScope member above. (docNamingScopeMutex() existed briefly in v1.15.13 and
// was removed once the shared-instance design itself was replaced.)
// #361: g_fontList/g_fontListPopulated (OCCTBridge_Visualization.mm) are plain
// globals with an unsynchronized check-then-act lazy-init, plus
// OCCTFontMgrInitDatabase() can reassign both at any time from any thread.
// Bridge-only (no OCCT source involved).
std::mutex& fontListMutex();

// === OCCT signal handling ===
//
// Installs OCCT's signal handlers (OSD::SetSignal) once, so that OS signals
// raised inside OCCT (SIGSEGV/SIGFPE on degenerate geometry) are converted into
// catchable Standard_Failure exceptions when a try block uses OCC_CATCH_SIGNALS.
// Call at the top of any modelling op that can hit degenerate input (loft,
// booleans, sweep, fillet…). Definition lives in OCCTBridge.mm. See issue #175.
void occtEnsureSignals();

// === #263: self-intersecting-wire guard ===
//
// Returns true if `s` contains a wire that BRepCheck flags as SelfIntersectingWire
// (and/or a face/shape flagged UnorientableShape). Such a profile extrudes into a
// prism that crashes OCCT's ShapeFix_Shape with uncatchable heap corruption (#263) —
// and an OS signal raised inside OCCT cannot be caught here (OCC_CATCH_SIGNALS is inert
// without OCC_CONVERT_SIGNALS in this build). So the prism/heal wrappers must DETECT and
// refuse the input (return nil) rather than build/heal the crashing solid. Cheap: a pure
// BRepCheck topology pass, no meshing. Definition lives in OCCTBridge.mm. See issue #263.
bool occtHasSelfIntersectingWire(const TopoDS_Shape& s);

// === #446: ShapeUpgrade_UnifySameDomain consumes the shape it is given ===
//
// The algorithm rewrites sub-shapes of its INPUT, and those rewrites reach the TShapes the
// caller's shape still shares — so a caller who discards the result still ends up with a
// different (measurably worse: reported self-intersecting, and here provably larger in BREP)
// shape than the one they handed in. `SetSafeInputMode` does not cover it: even in safe mode,
// TransformPCurves (ShapeUpgrade_UnifySameDomain.cxx) writes temporary pcurves onto the input's
// edges against a scratch reference face, and only ever removes them again when that face is
// later replaced. OCCT documents the class as producing a new shape and says nothing about the
// input being consumed.
//
// Every entry point in this bridge therefore unifies a private COPY: the three below, plus the
// OCCTUnifySameDomain builder (OCCTBridge_Modeling.mm), which keeps its copier alive so
// KeepShape can map the caller's sub-shapes onto their counterparts in the copy.
// Definitions live in OCCTBridge_Healing.mm. See issue #446.
class BRepBuilderAPI_Copy;

// Copy `shape` through `copier`, which the caller owns and must keep alive for as long as it
// needs to map sub-shapes (occtUnifySameDomainMapped). Returns a null shape if the copy fails.
TopoDS_Shape occtUnifySameDomainInput(const TopoDS_Shape& shape, BRepBuilderAPI_Copy& copier);

// The counterpart of `sub` inside a copy made by `copier`, or `sub` itself when it is not a
// sub-shape of what was copied (in which case it was never going to match anything either way).
TopoDS_Shape occtUnifySameDomainMapped(const TopoDS_Shape& sub, BRepBuilderAPI_Copy& copier);

// One-shot unify over a private copy: the whole copy/construct/Build/result sequence the
// non-builder entry points share. Returns a null shape on failure.
TopoDS_Shape occtUnifySameDomain(const TopoDS_Shape& shape,
                                 bool unifyEdges, bool unifyFaces, bool concatBSplines);

// === #442/#443: multi-body shell selection ===
//
// Definitions live in OCCTBridge_Healing.mm, next to the ShapeFix_Solid entry points they
// were written for (#442). Shared because the same "which shells bound a body" question is
// asked by every call that turns shells into solids: the solid-from-shell entry points in
// OCCTBridge_Modeling.mm ask it too, and each having its own answer is what #443 records.

// The shells that bound a body, in exploration order: every shell an even number of the
// others in its group enclose, where a group is one solid's own shells, or all the shells
// belonging to no solid at all (free shells go through the same parity pass as a solid's own
// shells, not added unconditionally — #443). A cavity shell is left out, because a hole is not
// a body and turning one into a positive solid would give a compound whose volume
// double-counts the part. Returns empty when `shape` holds no shell, which callers take as
// "nothing to build".
std::vector<TopoDS_Shell> occtBodyBoundingShells(const TopoDS_Shape& shape);

// Assemble one result shape from bodies: the body itself when there is exactly one, a
// compound when there are several, a null shape when there are none.
TopoDS_Shape occtSolidBodiesToShape(const std::vector<TopoDS_Shape>& bodies);

// === #490: the three int -> GeomAbs_Shape continuity decoders ===
//
// Every bridge function that takes a continuity as an integer decodes it here. There used to be
// one decoder per call site instead — seven independently-named statics (fourteen copies) plus
// six more switches written inline in the function that needed them — and they disagreed, which
// is not a hypothetical: #433 shipped a broken fill because one local copy mapped order 1 to
// GeomAbs_C1 instead of GeomAbs_G1, and until #490 `bsplineRestriction` and
// `bsplineRestrictionAdvanced` drove the identical OCCT operation off two different numberings.
//
// There are exactly three vocabularies, each named after the Swift enum that feeds it
// (Sources/OCCTSwift/Continuity.swift), which is the whole point of the naming: a call site
// picks its decoder by naming the contract its caller was typed against.
//
// All three saturate rather than fall back to a fixed value: an out-of-range integer decodes to
// the nearest end of that vocabulary, so a larger number never yields a *weaker* continuity than
// a smaller one. The old copies used three different out-of-range defaults (GeomAbs_CN,
// GeomAbs_C2, GeomAbs_C1), so the same invalid input silently meant different things depending
// only on which entry point received it.

// `SurfaceContinuity` (0=G0, 1=G1, 2=G2): the geometric constraint order handed to a plate
// solver. Saturates at GeomAbs_C1.
//
// BRepOffsetAPI_MakeFilling forwards the enum straight through to
// GeomPlate_CurveConstraint/BRepFill_CurveConstraint as an integer order, and both reject
// anything outside [-1, 2]. So curvature is GeomAbs_C1 (ordinal 2); GeomAbs_G2 (ordinal 3) and
// GeomAbs_C2 (ordinal 4) always throw, whatever BRepOffsetAPI_MakeFilling.hxx claims. #430/#434.
inline GeomAbs_Shape occtGeomAbsFromSurfaceContinuity(int32_t order) {
    if (order <= 0) return GeomAbs_C0;   // order 0 — position
    if (order == 1) return GeomAbs_G1;   // order 1 — position + tangency
    return GeomAbs_C1;                   // order 2 — position + tangency + curvature
}

// `ParametricContinuity` (0=C0, 1=C1, 2=C2, 3=C3): "make every piece at least Cn". Saturates at
// GeomAbs_CN, which is the top of this same ladder (C0 < C1 < C2 < C3 < CN) rather than a
// different kind of answer, and is what `Curve3D/Curve2D.splitByContinuity` has always
// documented for criterion 4.
//
// What each consumer does with the strict end differs, and the decoder deliberately does not
// paper over it — measured against the pinned kernel (Scripts/repro is not needed for this one;
// the probe is reproduced in the #490 tests):
//   - ShapeUpgrade_Split{Curve3d,Curve2d,Surface}Continuity::SetCriterion recognises C0/C1/C2/C3
//     and CN; anything else falls to its own C1 default.
//   - The GeomConvert/Geom2dConvert Approx* family accepts C0/C1/C2 only. AdvApprox throws
//     Standard_ConstructionError for C3 and CN (and for G1/G2), which the bridge's catch(...)
//     turns into a nullptr — so asking for more than C2 there fails the call outright.
//   - ShapeCustom_BSplineRestriction likewise yields a null shape above C2.
//   - GeomAPI_PointsToBSpline/Geom2dAPI_PointsToBSpline/GeomAPI_PointsToBSplineSurface accept
//     every value without throwing.
inline GeomAbs_Shape occtGeomAbsFromParametricContinuity(int32_t level) {
    switch (level) {
        case 0:  return GeomAbs_C0;
        case 1:  return GeomAbs_C1;
        case 2:  return GeomAbs_C2;
        case 3:  return GeomAbs_C3;
        default: return level < 0 ? GeomAbs_C0 : GeomAbs_CN;
    }
}

// A GeomAbs_Shape class named by its own ordinal (0=C0, 1=G1, 2=C1, 3=G2, 4=C2), which is the
// vocabulary the LocalAnalysis_* junction analysers speak in both directions — it is what they
// are asked to check and what they report back as `ContinuityAnalysis.status`.
//
// Saturates at GeomAbs_C2 on purpose: LocalAnalysis_CurveContinuity/SurfaceContinuity implement
// no predicate above C2/G2, and asking them for C3 or CN leaves every predicate reporting true
// (measured), i.e. the analysis silently becomes meaningless. C2 is the strictest question these
// two classes can actually answer.
inline GeomAbs_Shape occtGeomAbsFromAnalysisOrder(int32_t order) {
    switch (order) {
        case 0:  return GeomAbs_C0;
        case 1:  return GeomAbs_G1;
        case 2:  return GeomAbs_C1;
        case 3:  return GeomAbs_G2;
        default: return order < 0 ? GeomAbs_C0 : GeomAbs_C2;
    }
}

// The inverse of occtGeomAbsFromAnalysisOrder, for reporting a measured class back to Swift.
// Returns -1 for GeomAbs_C3/GeomAbs_CN: those are outside the analysers' vocabulary, so a
// caller seeing -1 knows the status was not one of the five classes it can interpret.
inline int32_t occtAnalysisOrderFromGeomAbs(GeomAbs_Shape shape) {
    switch (shape) {
        case GeomAbs_C0: return 0;
        case GeomAbs_G1: return 1;
        case GeomAbs_C1: return 2;
        case GeomAbs_G2: return 3;
        case GeomAbs_C2: return 4;
        default:         return -1;
    }
}

// === #430/#432/#434: surface-filling helpers ===
//
// Shared by both filling entry points — OCCTShapeFill* (OCCTBridge_Healing.mm) and OCCTFilling*
// (OCCTBridge_Modeling.mm). Both now build on BRepOffsetAPI_MakeFilling (#434 converged
// OCCTFilling* off its own separate BRepFill_Filling onto the same class). Definitions live in
// OCCTBridge_Healing.mm.

// Construct a BRepOffsetAPI_MakeFilling, binding every argument to the parameter it names — the
// pre-#431 code passed maxDegree/maxSegments/continuity into Degree/NbPtsOnCur/TolAng, which left
// MaxDeg/MaxSegments at their defaults and made TolAng the continuity ordinal. Tol2d/Tol3d are a
// parameter-space/model-space tolerance pair; a tenth reproduces OCCT's own default ratio
// (1e-5 / 1e-4) at the default tolerance.
//
// Returned by value: C++17 guaranteed copy elision (Package.swift sets .cxx17) constructs it
// directly into the caller's variable, so no copy or move of the filler is performed.
BRepOffsetAPI_MakeFilling occtFillingMakeBuilder(int32_t degree, int32_t nbPtsOnCur,
                                                  int32_t maxDegree, int32_t maxSegments,
                                                  double tolerance3d);

// Build a support face carrying the edge's own pcurve, for edges with no nominated support face.
//
// This exists to keep BRepFill_Filling's face-less Add(edge, order) overload out of the call
// path for continuity above C0. That overload builds its constraint from the UNTRIMMED pcurve
// (it fetches the edge's [f, l] range and then discards it), which for the usual Geom2d_Line
// pcurve means a +/-2e100 parameter range instead of the edge's own. What happens next depends
// on the support surface: a bounded one throws a catchable Standard_Failure ("U parameters out
// of range"), but an unbounded or periodic one accepts the garbage, the constraint cannot be
// projected, and GeomPlate_BuildPlateSurface::Perform's recovery path then dereferences its own
// still-null myGeomPlateSurface — an uncatchable SIGSEGV, not an exception. That planar/curved
// split is why the defect stayed hidden. Routing through Add(edge, face, order) instead uses
// BRepAdaptor_Curve2d, which trims correctly, and yields results identical to a real support
// face. Upstream defect; see issue #430 and Scripts/repro/430-fill-untrimmed-pcurve/.
//
// Returns false when the edge has no pcurve at all, or when the synthesized face does not
// resolve one — callers must then either skip the constraint or accept position-only continuity.
bool occtFillingSupportFaceFromPCurve(const TopoDS_Edge& edge, TopoDS_Face& outFace);

// Where a support face came from, which decides what happens when it turns out to be unusable.
enum class OCCTFillingSupport {
    // The caller named this exact face. If it cannot serve as the continuity reference, that is
    // a failure, not something to paper over — substituting a different surface would answer a
    // question the caller did not ask.
    Nominated,
    // The bridge picked or derived this face on the caller's behalf (an ancestor lookup, or none
    // at all). Falling back to another reference is the documented behaviour.
    Inferred,
};

// Add one edge constraint to `filling`, preferring the face-carrying overload whenever a
// support face is available or derivable.
//
// No longer templated: before #434, the two callers held different (but Add-compatible) filler
// types — BRepOffsetAPI_MakeFilling here, BRepFill_Filling directly in OCCTBridge_Modeling.mm —
// with no common base to take a reference to. #434 moved OCCTFilling* onto
// BRepOffsetAPI_MakeFilling too, so both callers now share the same concrete type.
//
// Returns false only when `kind` is Nominated and that face carries no pcurve for the edge; the
// constraint is then NOT added and the caller should fail the whole fill. Every other path adds
// a constraint and returns true — including the no-pcurve-anywhere case, which reaches the
// face-less overload and surfaces as OCCT's documented Standard_Failure at Build() time.
bool occtFillingAddConstraint(BRepOffsetAPI_MakeFilling& filling,
                              const TopoDS_Edge& edge,
                              const TopoDS_Face& support,
                              OCCTFillingSupport kind,
                              GeomAbs_Shape order,
                              bool isBound);

// === #403: shared BSpline knot-split-to-parameter conversion ===
//
// Curve3D.continuityBreaks, LawFunction.knotSplitParameters, and Surface.knotSplitting
// each wrap a different OCCT *KnotSplitting analyzer (GeomConvert_BSplineCurveKnotSplitting,
// Law_BSplineKnotSplitting, GeomConvert_BSplineSurfaceKnotSplitting -- the last one calling
// this twice, once per parametric direction) but all three reduce to the identical loop:
// walk the N computed split points, convert each one's knot-table index to a real
// parameter value, write up to maxParams of them, and report the true split count even
// when writing was truncated (so a caller can always retry with a bigger buffer).
//
// splitIndexAt(i) returns the underlying knot-table index for split i (1-based, matching
// every *KnotSplitting class's own SplitValue/USplitValue/VSplitValue numbering);
// knotAt(index) converts that knot-table index to an actual parameter value.
template <class SplitIndexAt, class KnotAt>
int32_t occtWriteKnotSplitParams(int32_t nbSplits, SplitIndexAt splitIndexAt, KnotAt knotAt,
                                  double* outParams, int32_t maxParams) {
    int32_t count = std::min(nbSplits, maxParams);
    for (int32_t i = 0; i < count; i++) {
        outParams[i] = knotAt(splitIndexAt(i + 1));
    }
    return nbSplits;
}

// === #399/#411/#487: conic dimension preconditions ===
//
// The dimensions a circle, ellipse, hyperbola or parabola needs in order to be that curve rather
// than a degenerate stand-in for a point or a line. Not dimension-specific: whether the conic is
// built in a plane or in space changes nothing about which radii describe one, so these four
// predicates serve both the Curve3D and the Curve2D factories.
//
// Two families build each curve type from caller-supplied dimensions, and every one of them needs
// the same answer: the direct family (OCCTCurve3DCreate*, OCCTCurve2DCreate*, including the ArcOf*
// variants) constructing a Geom_* / Geom2d_* object outright, and the gce family (OCCTGceMake*,
// OCCTGceMake*2d) going through a gce_Make* algorithm first.
//
// They must be checked here, in the bridge, and not left to OCCT. Every OCCT precondition is
// written as a *_Raise_if macro, and the pinned OCCT.xcframework is a Release build, where OCCT's
// own BUILD_RELEASE_DISABLE_EXCEPTIONS (default ON) defines No_Exception and expands all of those
// macros to nothing inside OCCT's translation units. So the checks OCCT documents in its headers do
// not run in this build; measured consequences (#487):
//
//   - gce_MakeElips2d(ax, 5, -3) reports gce_Done and yields a live Geom2d_Ellipse whose
//     MinorRadius() is -3. Its own two checks (MajorRadius < 0, MajorRadius < MinorRadius) do not
//     cover that input, and gp_Elips2d's check, which would, is compiled out.
//   - gce_MakeHypr2d(ax, 0, 0, true) and gce_MakeParab2d(ax, 0) both succeed, as do the
//     corresponding direct Geom2d_Hyperbola / Geom2d_Parabola constructors. OCCT accepts these
//     through every route; rejecting them is entirely this bridge's contract.
//
// A degenerate conic is not a harmless curve either: a zero-radius ellipse evaluates to its own
// centre at every parameter while still reporting a [0, 2pi] range, so it reads as a curve
// everywhere downstream and behaves as a point.
//
// One definition each, because the alternative is what the audit found: #399 added these four to
// OCCTBridge_Curve3D.mm, #411 added a byte-equivalent occtValidCircle2dRadius to
// OCCTBridge_Geom2d.mm, and the 2D direct factories spelled the same conditions inline in six more
// places, which is how the 2D gce factories came to be skipped by both passes.

// A circle needs a positive radius. Zero collapses it to its own centre.
inline bool occtValidCircleRadius(double radius) {
    return radius > 0;
}

// An ellipse needs both radii positive, and the minor no larger than the major, which is the
// orientation OCCT's own gp_Elips2d/gp_Elips invariant requires.
inline bool occtValidEllipseRadii(double majorR, double minorR) {
    return majorR > 0 && minorR > 0 && minorR <= majorR;
}

// A hyperbola needs both radii positive. Unlike an ellipse it puts no ordering on them: a minor
// radius larger than the major is an ordinary hyperbola, not an inverted one.
inline bool occtValidHyperbolaRadii(double majorR, double minorR) {
    return majorR > 0 && minorR > 0;
}

// A parabola needs a positive focal length. At zero it degenerates to a line parallel to its own
// axis of symmetry, which is gp_Parab2d's documented behaviour, not an error it reports.
inline bool occtValidParabolaFocal(double focal) {
    return focal > 0;
}

#endif /* OCCTBridge_Internal_h */
