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
#include <NCollection_Array1.hxx>
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
// The rest serve the shared algorithm helpers at the bottom of this header
// (occtFillingAddConstraint, occtShapeFilletEdgeList, occtDefeaturePerform,
// occtBRepFeatCylindricalHole) rather than the
// structs above.
#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepFeat_MakeCylindricalHole.hxx>
#include <BRepFeat_Status.hxx>
#include <Precision.hxx>
#include <gp_Ax1.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTools_ListOfShape.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <gp_Pnt2d.hxx>
// These four serve the local-properties helpers (occtSurfaceLocalProps and friends).
#include <GeomLProp_SLProps.hxx>
#include <GeomLProp_CLProps.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepLProp_CLProps.hxx>
#include <Precision.hxx>
#include <cmath>

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
        case 4:  return GeomAbs_C2;
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

// Which of the five analysis predicates an analysis order actually computes. Bit layout matches
// the OCCTLocalAnalysis*ContinuityFlags bitmask: bit0=C0, bit1=G1, bit2=C1, bit3=G2, bit4=C2.
//
// LocalAnalysis_CurveContinuity and LocalAnalysis_SurfaceContinuity run exactly one branch of a
// switch on the order they were constructed with, and only that branch's quantities are ever
// computed. Every other predicate then reads a member still at its 0.0 initialiser and compares
// it against a tolerance, so its Is*() returns true whatever the geometry does: a sharp
// 90-degree corner analysed at order C0 reports IsC2() == true, and C2Angle() answers 0.0 (a
// perfect match) to go with it. The five branches are cumulative only along their own ladder,
// and no order computes all five — not even the C2 default, which never touches G1 or G2.
//
// Callers mask against this so an unmeasured class is reported as "not asked" rather than as a
// false positive. #495; OCCT's own header says as much ("the constructor computes the quantities
// which are necessary to check the continuity in the following cases"), just not in a form any
// caller can act on.
inline int32_t occtAnalysisMeasuredMask(GeomAbs_Shape order) {
    switch (order) {
        case GeomAbs_C0: return 0x01;                      // C0
        case GeomAbs_G1: return 0x01 | 0x02;               // C0, G1
        case GeomAbs_C1: return 0x01 | 0x04;               // C0, C1
        case GeomAbs_G2: return 0x01 | 0x02 | 0x08;        // C0, G1, G2
        case GeomAbs_C2: return 0x01 | 0x04 | 0x10;        // C0, C1, C2
        default:         return 0x01;                      // unreachable: the order saturates
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

// === #571: one GeomPlate_MakeApprox contract behind all six plate entry points ===

class GeomPlate_Surface;
class Geom_BSplineSurface;

//
// GeomPlate_MakeApprox is the one consumer of AdvApp2Var_ApproxAFunc2Var that does not go through
// GeomConvert_ApproxSurface — it drives the approximator directly — so it sat outside every census
// built by grepping for GeomConvert_ApproxSurface, including the PrecisCode census in
// OCCTBridge_Surface.mm. Six bridge functions construct it: OCCTShapePlatePoints and
// OCCTShapePlateCurves (OCCTBridge_Healing.mm), OCCTShapePlatePointsAdvanced, OCCTShapePlateMixed,
// OCCTSurfacePlateThrough and OCCTGeomPlateSurface (OCCTBridge_ProjLib_NLPlate.mm). Five of them
// hard-coded `Nbmax = 1, dmax = tolerance * 10`; the sixth passed the caller's maxSegments and
// `dmax = tolerance * 0.1`. Definition lives in OCCTBridge_ProjLib_NLPlate.mm.
//
// The two arguments that differed are the two that decide whether `tolerance` means anything:
//
//   Nbmax caps the number of Bezier patches, and 1 is the one value that breaks the algorithm.
//   AdvApp2Var_ApproxAFunc2Var::ComputePatches derives its cut decision NumDec from myMaxPatches,
//   and at 1 every branch leaves NumDec = 0; AdvApp2Var_Patch::CutSense then returns 0 whether or
//   not the criterion is satisfied, so "the fit missed" and "the fit is fine" issue the same
//   instruction — keep this patch. The criterion is still evaluated and still reported through
//   CriterionError(), it just cannot act. Measured on a 25-point wavy plate at tolerance 1e-2:
//   Nbmax = 1 returns a 9x9 surface deviating 9.8e-2, i.e. 9.8x the tolerance it was given, with
//   the criterion violated (critErr 9.8e-2 against a 1e-2 threshold) and ignored; Nbmax = 2 or
//   more returns 16x16 deviating 4.4e-3, inside tolerance. Sweeping dmax across nine orders of
//   magnitude at Nbmax = 1 yields bit-identical control nets — a dead argument in the sense of
//   #497's inert SetFuzzyValue.
//
//   dmax sets the criterion threshold, as seuil = max(Tol3d, 10 * dmax) (GeomPlate_MakeApprox.cxx).
//   So `dmax = tolerance * 10` asks the G0 criterion to accept 100x the tolerance the caller
//   requested — and it is not merely dead weight once Nbmax allows subdivision: at Nbmax = 20 that
//   value reproduces the bad 9x9 answer exactly, while tolerance * 0.1 gives the good 16x16 one.
//   tolerance * 0.1 makes 10 * dmax == Tol3d, so seuil is the caller's own tolerance. It is the
//   value the sixth site already used, and measurement picks it over the other five.
//
// CritOrder stays 0. The G0 criterion measures the distance between the fitted patch and the plate
// at the plate's own order-0 constraint UVs, which is exactly what `tolerance` promises for a
// surface built to pass through points. CritOrder = -1 disables the criterion outright (and flips
// the Jacobi precision, myPrec 0 -> 1); CritOrder = 1 measures normals instead of positions.
//
// `continuity` is the continuity of the joins BETWEEN patches, a different axis from the
// constraint order handed to GeomPlate_PointConstraint/GeomPlate_CurveConstraint — which is why
// OCCTShapePlateCurves' caller-supplied order is NOT forwarded here. It was implicit at all six
// sites (GeomPlate_MakeApprox.hxx defaults it to GeomAbs_C1); passing it explicitly keeps that
// value while making it reviewable, and it is not cosmetic — C0/C1/C2 give 17x17, 16x16 and 21x21
// control nets on the fixture above. Only those three are accepted: G1, G2, C3 and CN all throw
// Standard_Failure ("AdvApp2Var_ApproxAFunc2Var : UContinuity Error"), measured, so callers must
// clamp into the parametric ladder rather than reach for occtGeomAbsFromSurfaceContinuity, whose
// order-1 answer is GeomAbs_G1.
//
// Returns a null handle when the approximation cannot be built; callers treat that as failure.
occ::handle<Geom_BSplineSurface> occtPlateApproxSurface(const occ::handle<GeomPlate_Surface>& plate,
                                                        double tolerance,
                                                        int32_t maxDegree,
                                                        int32_t maxSegments,
                                                        GeomAbs_Shape continuity);

// The patch-join continuity every plate entry point asks for unless told otherwise. C1 is what all
// six sites got from GeomPlate_MakeApprox's own default before #571 made it explicit.
inline GeomAbs_Shape occtPlateApproxDefaultContinuity() { return GeomAbs_C1; }

// The largest number of Bezier patches a plate approximation may use unless the caller names one.
// A cap, not a target: the approximator stops as soon as the criterion is met, and on the #571
// fixture everything from 2 upwards produces the identical surface. Matches the `maxSegments: 20`
// default that Shape.plateSurface(points:) already exposed.
inline int32_t occtPlateApproxDefaultMaxSegments() { return 20; }

// The largest Bezier degree a plate approximation may use unless the caller names one. All six
// sites already used 8.
inline int32_t occtPlateApproxDefaultMaxDegree() { return 8; }

// === #497: one BRepAlgoAPI_Defeaturing skeleton ===
//
// Four entry points remove faces with BRepAlgoAPI_Defeaturing: OCCTShapeRemoveFeatures and
// OCCTShapeDefeature (the plain index- and shape-addressed forms), OCCTShapeHistoryFromDefeature
// (same operation, keeping the builder alive for its history), and OCCTShapeRemoveSmallFaces
// (OCCTBridge_Healing.mm, which picks the faces itself by area). They had four independent copies
// of the same SetShape/AddFaceToRemove/Build/IsDone sequence, and the copies had drifted apart on
// every precondition: one silently skipped an out-of-range face index while another failed the
// call, one dereferenced its faces array without a null check, and only two of them checked the
// result shape for null. Definitions live in OCCTBridge_Modeling.mm.
//
// A fifth wrapper, OCCTDefeatureWithTolerance, was deleted rather than folded in. It differed from
// OCCTShapeDefeature only by calling SetFuzzyValue, and that call does nothing:
// BRepAlgoAPI_Defeaturing::Build forwards exactly myInputShape, myFacesToRemove, myFillHistory and
// myRunParallel to the BOPAlgo_RemoveFeatures that does the work, so the fuzzy value inherited from
// BOPAlgo_Options is stored and never read — as BRepAlgoAPI_Defeaturing.hxx says outright ("the
// other options of the base class are not supported here and will have no effect"). Measured, not
// assumed: identical BREP output for fuzzy values from 1e-7 to 100 on a 10mm box, against a
// BRepAlgoAPI_Cut control that those same magnitudes visibly wreck. See
// Scripts/repro/497-defeaturing-fuzzy-inert/.
class BRepAlgoAPI_Defeaturing;

// Resolve caller-supplied face indices — 0-based, into the shape's own TopExp face map — to the
// faces themselves. Returns false, adding nothing, when the request is empty or names an index the
// shape does not have. Failing an out-of-range index is the contract the majority of the callers
// already had: quietly dropping it (the pre-#497 OCCTShapeRemoveFeatures behaviour) hands back a
// shape that still carries the feature the caller asked to remove, with nothing to distinguish it
// from a successful removal.
bool occtDefeaturingFacesByIndex(const TopoDS_Shape& shape, const int32_t* faceIndices,
                                 int32_t faceCount, TopTools_ListOfShape& outFaces);

// The same resolution for faces addressed as shape handles. Returns false when the request is
// empty, the array itself is null, or any element is null — a null element used to be dereferenced
// unchecked by OCCTShapeDefeature, which no try/catch could have saved.
//
// #578: each element is a face *carrier*, not necessarily a face. AddFaceToRemove takes a
// TopoDS_Shape and its own documentation calls it "the shape to extract the faces for removal", so
// a compound, a shell or the whole input solid is a legal way to name faces — measured, and passing
// the faces a carrier explores to is the same request BREP for BREP. Every element is therefore
// exploded for TopAbs_FACE and each face checked against the input's own face map. The rule, chosen
// to match the index-addressed occtDefeaturingFacesByIndex above rather than the kernel's own:
//
//   every element must contribute at least one face, and every face it contributes must belong to
//   `shape` — otherwise the whole request fails and nothing is removed.
//
// Membership is TopTools_ShapeMapHasher, i.e. IsSame, so a reversed face still belongs (measured)
// while a face off an identically-built shape does not. The kernel's own rule is to ignore what does
// not belong ("those that do not belong will be ignored", BRepAlgoAPI_Defeaturing.hxx), which
// succeeds while silently leaving the named feature in place — the failure mode #497 removed from
// the index-addressed spelling, on the entry point #536 made canonical. This changes only requests
// that were being partly discarded: nothing whose carriers all belong behaves differently. See
// Scripts/repro/578-defeature-face-membership/ for the whole matrix.
bool occtDefeaturingFacesFromShapes(const TopoDS_Shape& shape, const OCCTShape* const* faces,
                                    int32_t faceCount, TopTools_ListOfShape& outFaces);

// Run `defeaturing` over `shape`, removing `facesToRemove`. The builder is the caller's, because
// OCCTShapeHistoryFromDefeature has to outlive this call to read its history. Returns false unless
// the operation is done AND produced a non-null shape.
bool occtDefeaturePerform(BRepAlgoAPI_Defeaturing& defeaturing, const TopoDS_Shape& shape,
                          const TopTools_ListOfShape& facesToRemove, TopoDS_Shape& outResult);

// === #480: what a knot-splitting `continuity` argument actually means ===
//
// Four OCCT analyzers split a BSpline at knots: GeomConvert_BSplineCurveKnotSplitting,
// Geom2dConvert_BSplineCurveKnotSplitting, GeomConvert_BSplineSurfaceKnotSplitting (once per
// parametric direction) and Law_BSplineKnotSplitting. All four run a byte-for-byte identical
// algorithm, so every bridge function below shares one contract, measured against the pinned
// kernel on 3D curves, 2D curves, laws and surfaces (identical counts in all four):
//
//   - The argument is a `ContinuityRange`: a literal derivative order, not a GeomAbs_Shape.
//     It must reach OCCT as the raw integer the caller asked for. Decoding it to a GeomAbs_Shape
//     first would be silently wrong, since GeomAbs_C3 is ordinal 5 and would split at knots the
//     caller never asked about.
//   - A knot splits when `degree - multiplicity(knot) < ContinuityRange`. Range 0 short-circuits
//     to the two bracketing knots, and so does any range the whole curve already satisfies.
//   - So the useful domain is 0...degree and it saturates there: on a cubic with simple interior
//     knots, ranges 0, 1 and 2 all return just the two bracketing knots and range 3 returns every
//     knot; on a degree-5 curve nothing below 5 reaches a simple interior knot. That cap is the
//     defect #398 found on curves and #480 fixed across the rest of the family: the Swift range
//     was documented as 0...2, which on ordinary cubic geometry is every value that does nothing.
//   - A negative range throws Standard_RangeError. That one is an explicit `throw`, not a
//     *_Raise_if macro, so unlike most OCCT preconditions it survives this kernel's No_Exception
//     build (verified) and reaches the catch(...) in each bridge function below.
//
// === #403/#481: shared BSpline knot-splitting buffer contract ===
//
// Curve3D.continuityBreaks, LawFunction.knotSplitting, LawFunction.knotSplitParameters and
// Surface.knotSplitting each wrap a different OCCT *KnotSplitting analyzer
// (GeomConvert_BSplineCurveKnotSplitting, Law_BSplineKnotSplitting, and
// GeomConvert_BSplineSurfaceKnotSplitting, the last one calling this twice, once per
// parametric direction) but all reduce to the identical loop: walk the N computed split
// points, write up to maxOut of them into the caller's buffer, and report the TRUE split
// count even when writing was truncated, so a caller that came up short can retry at the
// size it was just told. #481: LawFunction.knotSplitting was the one that returned the
// written count instead, silently capping itself at its Swift caller's first-pass buffer.
//
// valueAt(i) produces split i's value (1-based, matching every *KnotSplitting class's own
// SplitValue/USplitValue/VSplitValue numbering).
template <class T, class ValueAt>
int32_t occtWriteKnotSplits(int32_t nbSplits, ValueAt valueAt, T* outValues, int32_t maxOut) {
    int32_t count = std::min(nbSplits, maxOut);
    for (int32_t i = 0; i < count; i++) {
        outValues[i] = valueAt(i + 1);
    }
    return nbSplits;
}

// The parameter-valued form of the above: splitIndexAt(i) returns the underlying knot-table
// index for split i, and knotAt(index) converts that index to an actual parameter value.
template <class SplitIndexAt, class KnotAt>
int32_t occtWriteKnotSplitParams(int32_t nbSplits, SplitIndexAt splitIndexAt, KnotAt knotAt,
                                  double* outParams, int32_t maxParams) {
    return occtWriteKnotSplits<double>(nbSplits,
        [&](int32_t i) { return knotAt(splitIndexAt(i)); }, outParams, maxParams);
}

// === #399/#411/#487/#514/#554: conic dimension preconditions ===
//
// The dimensions a circle, ellipse, hyperbola or parabola needs in order to be that curve rather
// than a degenerate stand-in for a point or a line. Not dimension-specific: whether the conic is
// built in a plane or in space changes nothing about which radii describe one, so these four
// predicates serve both the Curve3D and the Curve2D factories.
//
// Four routes reach a conic from caller-supplied dimensions, and every one of them needs the same
// answer: the direct family (OCCTCurve3DCreate*, OCCTCurve2DCreate*, including the ArcOf* variants)
// constructing a gp_* / Geom_* / Geom2d_* object outright, the gce family (OCCTGceMake*) and the GC
// family (OCCTGCMake*, OCCTCurve3DMake*) going through an algorithm class first, and the setters
// (OCCTCurve3D{Ellipse,Hyperbola,Parabola,Circle}Set*) rewriting one dimension of a live curve.
//
// They must be checked here, in the bridge, and not left to OCCT. Most OCCT preconditions are
// written as a *_Raise_if macro, and the pinned OCCT.xcframework is a Release build, where OCCT's
// own BUILD_RELEASE_DISABLE_EXCEPTIONS (default ON) defines No_Exception and expands all of those
// macros to nothing inside OCCT's translation units. Which checks survive therefore depends on
// *where the check is written*, and the three cases behave differently (measured, #487/#514/#554):
//
//   - A macro inside OCCT's own .cxx is gone. gce_MakeElips2d(ax, 5, -3) reports gce_Done and
//     yields a live Geom2d_Ellipse whose MinorRadius() is -3; gce_MakeHypr2d(ax, 0, 0, true) and
//     gce_MakeParab2d(ax, 0) both succeed. OCCT accepts these through every route.
//   - A macro in a header the bridge includes still runs, because it is compiled in *our* TU.
//     gp_Elips/gp_Hypr/gp_Parab (and their 2d counterparts) are constexpr in the header, so
//     gp_Elips(ax, 5, -3), gp_Elips(ax, 3, 5), gp_Hypr(ax, -5, 3) and gp_Parab(ax, -2) all raise
//     and the surrounding catch already turns them into a failure.
//   - A hand-written `if (...) throw` is not a macro and survives everywhere. Geom_Ellipse's
//     setters are spelled that way, so SetMinorRadius(-3) and SetMajorRadius below the current
//     minor both raise from inside OCCT's TU.
//
// The residue those three leave is the same in every family: ZERO. It satisfies every check
// written (`minor < 0 || major < minor` is false for (0, 0)), so it is the one degenerate input
// that arrives intact by every route, and it is what these predicates exist to reject.
//
// A degenerate conic is not a harmless curve either: a zero-radius ellipse evaluates to its own
// centre at every parameter while still reporting a [0, 2pi] range, so it reads as a curve
// everywhere downstream and behaves as a point. The sharpest measured case is
// GC_MakeArcOfEllipse's two-point form, where a zero minor radius makes the ElCLib::Parameter
// inversion return NaN for both bounds: IsDone() still reports true, so the `if (!IsDone())` guard
// a bridge function would normally rely on passes, and the caller receives a live curve whose
// every evaluation is NaN.
//
// One definition each, because the alternative is what the audit found: #399 added these four to
// OCCTBridge_Curve3D.mm, #411 added a byte-equivalent occtValidCircle2dRadius to
// OCCTBridge_Geom2d.mm, and the 2D direct factories spelled the same conditions inline in six more
// places, which is how the 2D gce factories came to be skipped by both passes.
//
// Whether a *query* taking these dimensions needs the same guard is decided per site by the test
// #553 settled on: probe whether OCCT actually returns the degenerate answer. Being a read-only
// query is not the criterion, since that is exactly where a wrong answer hides quietly.
//
// Guarded, because OCCT does not answer the degenerate question (#554):
//
//   - OCCTExtremaExtPElCElips / OCCTExtremaExtPElCParab: Extrema_ExtPElC reports NbExt() == 0
//     against a (0, 0) ellipse rather than the one extremum at its centre.
//   - OCCTExtremaElCLinElips: Extrema_ExtElC reports IsParallel() whatever the line does.
//
// Not guarded, because OCCT does answer it, and neither has a channel to report a rejection
// through without widening its signature:
//
//   - OCCTElCLibValueOnEllipse evaluates the degenerate conic exactly as it is defined
//     (ElCLib::Value(1.0, gp_Elips(ax, 5, 0)) is (2.70151, 0, 0), a point on the collapsed
//     segment), and returns void.
//   - The OCCTBndLib* conic entry points return the true bounding box of the degenerate curve
//     (a tolerance-sized box at the centre for (0, 0)), and return void.

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

// === #486: shared batch grid-evaluation packing/unpacking ===
//
// Curve3D, Curve2D and Surface each grew three generations of "evaluate at N parameters"
// bridge functions (v0.28/v0.29, v0.110, v0.111) that each hand-rolled their own parameter
// pack loop and their own result unpack loop. With nothing shared, the two Surface entry
// points drifted onto opposite grid layouts: OCCTSurfaceEvaluateGrid wrote v-major while
// OCCTGridEvalSurfaceD0 wrote u-major, and both header comments called their own layout
// "row-major". The duplicate spellings are gone; these helpers are what stops a future
// second spelling from re-deriving (and re-diverging on) the same two loops.

/// Copy a caller's parameter array into the 1-based NCollection_Array1 that every
/// GeomGridEval_* / Geom2dGridEval_* evaluator takes.
inline NCollection_Array1<double> occtGridEvalParams(const double* params, int32_t count) {
    NCollection_Array1<double> arr(1, count);
    for (int32_t i = 0; i < count; i++) {
        arr.SetValue(i + 1, params[i]);
    }
    return arr;
}

/// THE definition of OCCTSwift's surface-grid buffer layout: **U-major**, u varying slowest and
/// v fastest. Shared by OCCTSurfaceEvaluateGrid, OCCTSurfaceEvaluateGridD1, OCCTSurfaceDrawMesh
/// and the Swift SurfaceGrid/SurfaceGridD1 types (#404). "Row-major" is ambiguous for a UV grid,
/// since either parameter can be the row, so the index lives here in code instead of being
/// re-spelled in prose at each call site.
inline int32_t occtSurfaceGridIndex(int32_t iu, int32_t iv, int32_t vCount) {
    return iu * vCount + iv;
}

// === #501: GCPnts arc-length samplers can return more points than were asked for ===
//
// GCPnts_UniformAbscissa::initialize sizes its own parameter array at `nbPoints + 5` and lets the
// arc-length walk fill it as far as it runs, so NbPoints() is not bounded by the requested count.
// GCPnts_QuasiUniformAbscissa inherits that for every curve which is neither Bezier nor BSpline,
// because it forwards to GCPnts_UniformAbscissa for those.
//
// Measured on an ellipse with major radius 1e6 and minor radius 1e-3: the walk lands ~1.6e-8 in
// parameter short of the end, which is far outside the sampler's own epsilon (Resolution(1e-7),
// about 1e-13 there), so it takes one more step and snaps that step to the end parameter. 22 of 59
// point counts overshoot by exactly one. Every bridge function here is handed a buffer sized from
// the count the caller asked for, so writing NbPoints() values was a heap write past the end.
// Scripts/repro/501-quasiuniform-buffer-overflow reproduces it against the shipped functions.
//
// Clamping alone is not enough: the surplus point *is* the curve's end parameter, so dropping the
// tail drops the end of the curve. Keep the first `capacity - 1` samples and the sampler's own last
// one, which is what OCCTGCPntsQuasiUniform (the only member of the family that already clamped)
// was silently getting wrong.

/// How many of a GCPnts sampler's `nbPoints` samples fit in a buffer of `capacity` slots.
inline int32_t occtSamplerKept(int32_t nbPoints, int32_t capacity) {
    return std::min(nbPoints, std::max(capacity, 0));
}

/// The 1-based sampler index feeding output slot `slot`, given `kept` of `nbPoints` samples fit.
/// Identity while everything fits; otherwise the final slot takes the sampler's last point so a
/// clamped distribution still spans the whole curve.
inline int32_t occtSamplerIndex(int32_t slot, int32_t kept, int32_t nbPoints) {
    return (slot == kept - 1) ? nbPoints : slot + 1;
}

/// The point-count precondition every GCPnts_UniformAbscissa / GCPnts_QuasiUniformAbscissa entry
/// point has to apply itself. Both classes document (and `Raise_if`) `nbPoints >= 2`, but the
/// pinned kernel is a Release build, where OCCT defines No_Exception and every `*_Raise_if`
/// compiles to nothing (see #487). Below 2 the algorithms do not fail cleanly:
/// GCPnts_QuasiUniformAbscissa(bezier_or_bspline, 0) builds an NCollection_HArray1 with the empty
/// range (1, 0) and then writes element 1 of it, an out-of-bounds store that SIGSEGVs (measured on
/// a 4-pole Bezier, an all-coincident-pole Bezier and an 8-point BSpline fit); on an ellipse the
/// same call reports IsDone() with five points for a request of zero.
inline bool occtValidSampleCount(int32_t nbPoints) {
    return nbPoints >= 2;
}

// === #489: shared BRepFilletAPI_MakeFillet edge-list skeleton ===
//
// Three bridge functions fillet a caller-supplied list of edge indices and differ only in what
// radius each of those edges gets: OCCTShapeFilletEdges (one radius for the whole list) and
// OCCTShapeFilletEdgesLinear (a start and an end radius, applied per edge) in
// OCCTBridge_Modeling.mm, and OCCTShapeBlendEdges (one radius per edge) in OCCTBridge_Healing.mm.
// Everything either side of the per-edge Add (the null/count guard, the TopExp::MapShapes edge
// map, the 0-based-to-1-based index translation and its bounds check, Build/IsDone/Shape, and the
// catch(...) that turns any OCCT failure into nullptr) was written out three times.
//
// That is how the radius precondition came to be missing from one of them. Both fillet* functions
// reject a non-positive radius before OCCT is touched; the blend function checked only that the
// radii pointer was non-null, and never looked at a single element. Copies do not propagate a
// guard added to one of them, which is the whole argument for one skeleton: the next piece of
// hardening this family needs lands in one place, on all three call sites at once.
//
// The precondition belongs here in the bridge, for the same reason the conic predicates above do:
// the pinned OCCT.xcframework is a Release build, so OCCT's own *_Raise_if preconditions are
// compiled out by No_Exception and nothing inside the library will reject the value for us.
// Measured against that kernel (Scripts/repro/489-fillet-radius-validation/):
// BRepFilletAPI_MakeFillet::Add(r, edge) with r of 0, a negative r, or NaN neither throws nor
// yields a wrong shape. It fails IsDone(), so wherever the bad radius did reach OCCT the result
// was already nullptr. The case that escaped was a bad radius paired with an out-of-range edge
// index: the bounds check dropped the pair, and the batch then built from the remaining edges and
// reported success for a request that was never fully honoured.

// A fillet radius has to be positive. Zero and negative both fail BRepFilletAPI_MakeFillet's own
// Build(), so this rejects them before that work is done rather than after; NaN fails the same
// comparison, since NaN > 0 is false.
inline bool occtValidFilletRadius(double radius) {
    return radius > 0;
}

// Every radius in a per-edge radius array, checked up front. One bad element rejects the whole
// batch, matching the uniform-radius entry point: it rejects its single radius before looking at
// any index, so a per-edge list cannot make its own validity depend on which indices resolve.
inline bool occtValidFilletRadii(const double* radii, int32_t count) {
    if (!radii || count < 1) return false;
    for (int32_t i = 0; i < count; i++) {
        if (!occtValidFilletRadius(radii[i])) return false;
    }
    return true;
}

// Add the edges named by `edgeIndices` (0-based, indexing `shape`'s own TopExp edge map) to
// `fillet`, through whichever Add overload the caller's radius law needs. Returns false, having
// added nothing further, when an index does not name an edge of `shape`.
//
// `addEdge(fillet, edge, entry)` is the only part that varies between the callers: `entry` is the
// index into the caller's own arrays, so a per-edge radius list can read its own element. It is
// called only for indices that resolve to a real edge.
//
// #520 made an out-of-range index reject the call. It used to be skipped here, so a batch with one
// bad index filleted the rest and reported success: a request honoured in part, presented as
// honoured in full, the same defect class as #439/#442/#443. The two radius-law entry points
// (OCCTShapeFilletVariable, OCCTShapeFilletEvolving) already rejected, so this is what makes all
// five agree. A caller who wants best-effort can filter its own indices; a caller who cannot tell
// a partial result from a complete one had no way back.
//
// Not folded into occtShapeFilletEdgeList below because OCCTShapeHistoryFromFilletEdges has to
// keep its builder alive past the call, to hand back a BRepTools_History over it.
//
// Radius validation is the caller's, since the shapes it takes (one scalar, two scalars, an array,
// a (parameter, radius) point list) have nothing in common but occtValidFilletRadius above.
template <class AddEdge>
bool occtFilletAddEdges(BRepFilletAPI_MakeFillet& fillet, const TopoDS_Shape& shape,
                        const int32_t* edgeIndices, int32_t edgeCount, AddEdge addEdge) {
    TopTools_IndexedMapOfShape edgeMap;
    TopExp::MapShapes(shape, TopAbs_EDGE, edgeMap);

    for (int32_t i = 0; i < edgeCount; i++) {
        int32_t idx = edgeIndices[i];
        if (idx < 0 || idx >= edgeMap.Extent()) return false;
        addEdge(fillet, TopoDS::Edge(edgeMap(idx + 1)), i);  // OCCT's map is 1-based
    }
    return true;
}

// === #520: the radius law, for the two entry points that take one ===
//
// A contour added by the law-taking Add(edge) overload carries no radius of its own, and
// BRepFilletAPI_MakeFillet::Build() **SIGSEGVs** on a contour that never receives one — an OS
// signal, so no catch(...) on this side of the bridge can turn it into nullptr. Every path that
// calls Add(edge) therefore has to reach a successful SetRadius, or return before Build().
// Measured in Scripts/repro/520-fillet-edge-index-contracts/ (`no-radius`, `radius-dropped`).
//
// Applying the law is one SetRadius(UandR, contour, 1) call, which is what makes the validation
// below worth sharing. OCCT's own contract for that array (BRepFilletAPI_MakeFillet.hxx):
//
//   - X is a *relative* parameter on the contour, between 0 and 1; Y is the radius there.
//   - With 1 point the X is ignored and the radius is constant; with 2 the X values are ignored
//     too and only the endpoint radii are used; with 3 or more OCCT renormalises via
//     (U - Uf) / (Ul - Uf), so the profile always spans the whole contour whatever the caller
//     wrote, and only the *relative* placement of the interior points survives.
//
// So the [0,1] range is not load-bearing inside OCCT, and that is exactly why it is checked here:
// a profile written outside it is silently reinterpreted rather than rejected, e.g.
// [(-5, 1), (0, 4), (7, 1)] puts its peak at 41.7% of the contour rather than at the start. The
// two degenerate orderings are worse than reinterpreted: equal parameters divide by zero, and
// descending ones reverse the law the caller wrote (measured: 7960.426609 against 7963.730821 for
// the ascending equivalent).
//
// Unlike the Add(radius, edge) path #489 measured, a non-positive radius here is not caught by
// OCCT at all: a profile containing -3.0 reports IsDone() == 1 and hands back a shape
// BRepCheck_Analyzer rejects. This predicate is the only thing standing between that and a caller.
//
// `pointAt(i)` returns the i-th point as a gp_Pnt2d(relative parameter, radius); the two callers
// hold their profiles in different layouts (parallel arrays, and an array of OCCTFilletRadiusPoint)
// and neither is worth copying to share this.
template <class PointAt>
bool occtFilletSetRadiusProfile(BRepFilletAPI_MakeFillet& fillet, int32_t contourIndex,
                                int32_t pointCount, PointAt pointAt) {
    if (pointCount < 1) return false;

    TColgp_Array1OfPnt2d UandR(1, pointCount);
    double previous = 0;
    for (int32_t i = 0; i < pointCount; i++) {
        gp_Pnt2d point = pointAt(i);
        if (!occtValidFilletRadius(point.Y())) return false;
        // Written as a positive test so NaN, which compares false against everything, is rejected
        // by the same expression rather than needing its own.
        if (!(point.X() >= 0.0 && point.X() <= 1.0)) return false;
        if (i > 0 && !(point.X() > previous)) return false;
        previous = point.X();
        UandR.SetValue(i + 1, point);
    }

    fillet.SetRadius(UandR, contourIndex, 1);
    return true;
}

// occtFilletAddEdges plus the build-and-wrap half: the guard, the perform/check/result triad, and
// the catch(...) that turns any OCCT failure into nullptr. This is the whole body of the three
// edge-list fillet entry points bar their radius law.
template <class AddEdge>
OCCTShapeRef occtShapeFilletEdgeList(OCCTShapeRef shape,
                                     const int32_t* edgeIndices, int32_t edgeCount,
                                     AddEdge addEdge) {
    if (!shape || !edgeIndices || edgeCount < 1) return nullptr;

    try {
        BRepFilletAPI_MakeFillet fillet(shape->shape);
        if (!occtFilletAddEdges(fillet, shape->shape, edgeIndices, edgeCount, addEdge)) {
            return nullptr;
        }

        fillet.Build();
        if (!fillet.IsDone()) return nullptr;

        TopoDS_Shape result = fillet.Shape();
        if (result.IsNull()) return nullptr;

        return new OCCTShape(result);
    } catch (...) {
        return nullptr;
    }
}

// === #505: the precondition BRepFilletAPI_MakeFillet's edge-keyed radius laws never check ===
//
// GetBounds, GetLaw and SetLaw each take a (contour index, TopoDS_Edge) pair and each resolve it
// through ChFiDS_FilSpine::ChangeLaw(E), which asks ChFiDS_Spine::Index(E) where the edge sits in
// that contour's spine. Index returns 0 for an edge the spine does not hold, and ChangeLaw then uses
// it anyway: ElSpine(0) -> FirstParameter(0) -> abscissa->Value(-1). Neither that access nor
// ChFi3d_FilBuilder's own Value(IC) has a live bounds check, because OCCT's *_Raise_if macros are
// compiled out of the pinned Release build. So nothing anywhere rejects the request; it just answers
// about whatever the out-of-range index lands on. Measured on a 10x10x10 box
// (Scripts/repro/505-filletbuilder-edge-type/):
//
//   - Two contours, GetBounds(1, edgeOfContour2): returns true, with contour 1's bounds and contour
//     1's law. The edge argument stops mattering the moment Index() answers 0.
//   - GetBounds(1, edgeInNoContour): same, true with contour 1's law.
//   - SetLaw(1, edgeInNoContour, law): overwrites contour 1's law and reports nothing.
//   - GetBounds(0, e) and GetBounds(-1, e): true, again with contour 1's answer. The upper bound is
//     checked upstream (IC <= NbElements()), so 2 and 99 do return false; only the low side leaks.
//
// Contour(E) is the same TopoDS_Shape::IsSame walk over the same spines that Index(E) is about to
// do, so it decides exactly this question, and it is populated by Add() rather than by Build(),
// which means it is equally valid before and after the fillet is built.
inline bool occtFilletContourHoldsEdge(const BRepFilletAPI_MakeFillet& fillet,
                                       int32_t contourIndex, const TopoDS_Edge& edge) {
    if (contourIndex < 1 || contourIndex > fillet.NbContours()) return false;
    return fillet.Contour(edge) == contourIndex;
}

// === #492: one analytical-conversion path per GeomConvert converter class ===
//
// GeomConvert_CurveToAnaCurve and GeomConvert_SurfToAnaSurf each had two independently-grown
// wrapper families (v0.30.0 and v0.78) that made the identical OCCT call and then disagreed about
// what to do with the answer: the older curve wrapper hardcoded the curve's own parameter range and
// discarded newFirst/newLast/Gap(), and the older surface wrapper carried an "already analytical"
// guard its younger sibling never grew. These two helpers are the single path all of them now take.
//
// The contract both entry points guarantee, and neither guaranteed before:
//
//   1. Success yields a NEW object that shares no state with the input. This is not decoration.
//      GeomConvert_CurveToAnaCurve::ConvertToAnalytical hands back the *input handle itself* when
//      the curve is already analytical -- ComputeLine and ComputeCircle both down-cast the input and
//      return it (GeomConvert_CurveToAnaCurve.cxx:186, :296) -- and for a Geom_TrimmedCurve it
//      returns the basis curve the trim still holds. Both wrappers then handed that shared curve to
//      Swift as a separate Curve3D, so an in-place transform on the "converted" curve moved the
//      original too. Measured, not theorised: translating the result of
//      Curve3D.circle(...).toAnalytical() by 100 moved the source circle by exactly 100.
//
//      GeomConvert_SurfToAnaSurf never does this -- every branch allocates
//      (GeomConvert_SurfToAnaSurf.cxx:791-807 for already-analytical input, and every newSurf[]
//      assignment elsewhere), so the old same-handle guard was dead code against this kernel. It is
//      still copied here, because "the current kernel happens to allocate" is exactly the assumption
//      that let the two families drift apart in the first place. Both results are tiny analytic
//      objects (line/circle/ellipse; plane/cylinder/cone/sphere/torus), so the copy is free.
//
//   2. Failure is one outcome, not three. A null input, an unrecognisable input and a thrown
//      Standard_Failure (the bounded surface overload throws Geom_BSplineSurface::Segment on
//      inverted UV bounds) all return false, leaving the out-parameters untouched.
//
// "Already analytical" is a success, not a rejection, on both sides -- a circle IS its analytical
// form. Gap() reports 0 exactly for those, which is how a caller tells them apart.

#include <GeomConvert_CurveToAnaCurve.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>

// Recognise `curve` over [first, last] as a line, circle or ellipse.
//
// outFirst/outLast come back in the RECOGNISED curve's own parameterisation, which is not the
// input's: a BSpline circle asked about [pi/2, 3pi/2] reports [0, 3.06] on the Geom_Circle it
// returns. Trimmed curves are unwrapped to their basis curve before recognition.
inline bool occtCurveToAnalytical(const occ::handle<Geom_Curve>& curve, double tolerance,
                                  double first, double last,
                                  occ::handle<Geom_Curve>& outCurve,
                                  double& outFirst, double& outLast, double& outGap) {
    if (curve.IsNull()) return false;
    try {
        GeomConvert_CurveToAnaCurve converter(curve);
        occ::handle<Geom_Curve> result;
        double newFirst = first, newLast = last;
        if (!converter.ConvertToAnalytical(tolerance, result, first, last, newFirst, newLast)) {
            return false;
        }
        if (result.IsNull()) return false;
        occ::handle<Geom_Curve> detached = occ::handle<Geom_Curve>::DownCast(result->Copy());
        if (detached.IsNull()) return false;
        outCurve = detached;
        outFirst = newFirst;
        outLast = newLast;
        outGap = converter.Gap();
        return true;
    } catch (...) {
        return false;
    }
}

// Recognise `surface` as a plane, cylinder, cone, sphere or torus.
//
// uvBounds is either null, for the whole surface, or four doubles {uMin, uMax, vMin, vMax}
// selecting the sub-patch to fit. Those are the two ConvertToAnalytical overloads; nothing else
// differs between them.
inline bool occtSurfaceToAnalytical(const occ::handle<Geom_Surface>& surface, double tolerance,
                                    const double* uvBounds,
                                    occ::handle<Geom_Surface>& outSurface, double& outGap) {
    if (surface.IsNull()) return false;
    try {
        GeomConvert_SurfToAnaSurf converter(surface);
        occ::handle<Geom_Surface> result =
            uvBounds ? converter.ConvertToAnalytical(tolerance, uvBounds[0], uvBounds[1],
                                                     uvBounds[2], uvBounds[3])
                     : converter.ConvertToAnalytical(tolerance);
        if (result.IsNull()) return false;
        occ::handle<Geom_Surface> detached = occ::handle<Geom_Surface>::DownCast(result->Copy());
        if (detached.IsNull()) return false;
        outSurface = detached;
        outGap = converter.Gap();
        return true;
    } catch (...) {
        return false;
    }
}

// === #502: one sub-shape enumeration ===
//
// "Give me this shape's sub-shapes of type T" was implemented twice, on two different OCCT
// primitives that answer differently:
//
//   * OCCTShapeGetSolidCount/GetSolids, GetShellCount/GetShells, GetWireCount/GetWires drove a
//     bare TopExp_Explorer, which yields one entry per *occurrence* in the topology tree.
//   * OCCTShapeGetSubShapeCount/GetSubShapeByTypeIndex (and OCCTShapeUniqueSubShapeCount, and the
//     fixed-type counts for faces, edges and vertices) built a TopTools_IndexedMapOfShape through
//     TopExp::MapShapes, which keeps one entry per *distinct* sub-shape.
//
// The gap is not cosmetic and not rare. TopTools_ShapeMapHasher's equality is
// TopoDS_Shape::IsSame (same TShape and same location, orientation ignored), so the map drops
// every repeat visit. Measured on the pinned kernel (Scripts/repro/502-subshape-traversal-dedup/):
// a plain 10mm box has 24 edge occurrences over 12 edges and 48 vertex occurrences over 8
// vertices, because each edge is reached once per adjacent face. For SOLID/SHELL/WIRE the two
// agreed on every ordinary shape tried (primitives, a hollow solid's two shells, two distinct
// bodies, two placements of one body, a sewn stack, a compsolid) and diverged exactly when one
// sub-shape is reachable from two parents: one Shape compounded with itself (2 solids vs 1), one
// shell handed to two solidFromShells calls (2 shells vs 1, #502's own example), one wire used to
// build two faces (2 wires vs 1), a face and its own reverse in one shell (2 faces vs 1).
//
// Deduplicated is the answer this API gives everywhere else (a box has 12 edges, not 24), so that
// is the answer all of it gives now. What made the choice cheap is that the two primitives
// are not independent: TopExp::MapShapes(S, T, M) is literally a TopExp_Explorer walk piped into
// the map (TopExp.cxx:34-45), so the deduplicated sequence is the explorer's sequence with later
// repeats removed. Order is preserved, no index moves, and one traversal serves both spellings.

/// THE sub-shape enumeration. Fills `outMap` with `shape`'s sub-shapes of TopAbs type `type`,
/// in TopExp_Explorer order, one entry per distinct sub-shape (`TopoDS_Shape::IsSame`: same
/// TShape and location, orientation ignored). Returns the number of entries.
///
/// `type` is the raw TopAbs_ShapeEnum ordinal as it arrives from Swift (0=COMPOUND..7=VERTEX);
/// anything outside that range yields 0 rather than being cast to an enum it has no value in.
/// Note that a shape IS its own sub-shape when it is of the requested type: a solid asked for
/// SOLID answers 1.
inline int32_t occtMapSubShapes(const TopoDS_Shape& shape, int32_t type,
                                TopTools_IndexedMapOfShape& outMap) {
    if (type < TopAbs_COMPOUND || type > TopAbs_VERTEX) return 0;
    TopExp::MapShapes(shape, static_cast<TopAbs_ShapeEnum>(type), outMap);
    return outMap.Extent();
}

/// The single sub-shape at 0-based `index` in the enumeration above, or a null TopoDS_Shape when
/// the index is negative or past the end. Callers that want the whole set should map once and
/// read the map, rather than calling this in a loop.
inline TopoDS_Shape occtSubShapeAt(const TopoDS_Shape& shape, int32_t type, int32_t index) {
    if (index < 0) return TopoDS_Shape();
    TopTools_IndexedMapOfShape map;
    if (index >= occtMapSubShapes(shape, type, map)) return TopoDS_Shape();
    return map(index + 1);  // OCCT's indexed maps are 1-based
}

// === #541: one meaning for a face index ===
//
// A face index crossing this bridge is a 0-based position in the enumeration above -- the one
// Shape.faces(), Shape.faceCount and Shape.face(at:) all read. Before #541 it was three things:
// OCCTShapeGetFaces walked a bare TopExp_Explorer (one entry per *occurrence*, so the index it
// wrote into Face.index could name a face no other entry point had), fourteen consumers walked
// their own explorer to match it, and a handful read the deduplicated map 1-based, so a Face.index
// addressed the face before the one it named and could never name the last face at all.
//
// Measured on the pinned kernel (Scripts/repro/541-face-index-contract/): the explorer/map
// divergence is not a hand-built curiosity. One BRepAlgoAPI_Splitter run cutting a box with a
// plane leaves two solids sharing the single cut face -- 12 occurrences over 11 distinct faces --
// and the duplicate is not last, so from index 10 onwards the two schemes named *different* faces.
// A caller holding Face.index from faces() drafted, deleted or opened a face it had not selected.
// On the ten fixtures that share no face the two orders are identical face-by-face, so converging
// them moved no index on any shape without a shared sub-shape.
//
// Use these two rather than open-coding an explorer walk or a map lookup: a null return means
// "no such index", which is the only failure they have.

/// The face at 0-based `index` in `shape`'s face enumeration, or a null face when the index is
/// negative, past the end, or names a sub-shape that is not a face.
inline TopoDS_Face occtFaceAt(const TopoDS_Shape& shape, int32_t index) {
    TopoDS_Shape sub = occtSubShapeAt(shape, TopAbs_FACE, index);
    if (sub.IsNull() || sub.ShapeType() != TopAbs_FACE) return TopoDS_Face();
    return TopoDS::Face(sub);
}

/// The edge at 0-based `index` in `shape`'s edge enumeration, or a null edge when the index is
/// negative, past the end, or names a sub-shape that is not an edge. `shape` is often a single
/// face, whose edges are enumerated the same way.
inline TopoDS_Edge occtEdgeAt(const TopoDS_Shape& shape, int32_t index) {
    TopoDS_Shape sub = occtSubShapeAt(shape, TopAbs_EDGE, index);
    if (sub.IsNull() || sub.ShapeType() != TopAbs_EDGE) return TopoDS_Edge();
    return TopoDS::Edge(sub);
}

// === #405/#494: one resolution behind every GeomLProp_* local-property construction ===
//
// GeomLProp_SLProps / GeomLProp_CLProps / GeomLProp_CLProps2d each take a `Resolution` their own
// headers document as "the linear tolerance (it is used to test if a vector is null)". It is not a
// comparison or display tolerance: it decides whether a derivative at one (u, v) counts as null,
// and so whether the tangent, normal and curvature are reported as existing at all. Two entry
// points that pass different values disagree about the *existence* of curvature at the same point
// on the same geometry, which is the defect #405 fixed for three Surface entry points and #494
// finished for the rest.
//
// A *smaller* resolution is the more permissive one. The null test is
// `derivative.SquareMagnitude() > resolution * resolution`, so the 1e-10 the Local* family used to
// pass called a derivative significant that Precision::Confusion() calls null -- the opposite of
// how a tolerance usually reads, which is why the drift survived #405's own audit.
//
// Measured before converging them (Scripts/repro/494-lprop-resolution/): on a cone approaching its
// apex, 1e-10 reports curvature defined with mean curvature -8.66e7 at v = 1e-8 where
// Precision::Confusion() reports it undefined; on a cubic Bezier whose first two poles sit 1e-8
// apart, 1e-10 returns curvature 6.67e15 where Precision::Confusion() returns RealLast(). The
// third value in play, the 1e-6 of OCCTGeomLPropCLProps/OCCTGeomLPropSLProps, was the same value
// #405 removed from OCCTSurfaceCurvatures.
//
// #529 finished the job on the adaptor side. BRepLProp_SLProps and BRepLProp_CLProps are not a
// different class family at all: in OCCT 8.0 they are `using` aliases for the very templates
// GeomLProp_SLProps/GeomLProp_CLProps alias, instantiated over BRepAdaptor_Surface/BRepAdaptor_Curve
// instead of a Geom_ handle (BRepLProp_SLProps.hxx is nine lines long). Same Resolution, same
// meaning, so the same value -- see occtFaceLocalProps/occtEdgeLocalProps below.
inline double occtLocalPropsResolution() { return Precision::Confusion(); }

// Construct the local-properties object for a surface at (u, v), computing derivatives up to
// `order` (1 for tangents and the normal, 2 for curvature). C++17 guarantees the returned prvalue
// is constructed directly into the caller's variable, so nothing is copied or moved.
inline GeomLProp_SLProps occtSurfaceLocalProps(const occ::handle<Geom_Surface>& surface,
                                                double u, double v, int order) {
    return GeomLProp_SLProps(surface, u, v, order, occtLocalPropsResolution());
}

// Curve counterpart. The parameter is bound here rather than through a later SetParameter() call,
// which the two-step callers (construct, then SetParameter) get for free.
inline GeomLProp_CLProps occtCurveLocalProps(const occ::handle<Geom_Curve>& curve,
                                              double u, int order) {
    return GeomLProp_CLProps(curve, u, order, occtLocalPropsResolution());
}

// 2D curve counterpart, over Geom2d_Curve.
inline GeomLProp_CLProps2d occtCurve2dLocalProps(const occ::handle<Geom2d_Curve>& curve,
                                                  double u, int order) {
    return GeomLProp_CLProps2d(curve, u, order, occtLocalPropsResolution());
}

// The topological counterparts (#529). A face and the surface under it are the same geometry asked
// the same question, so OCCTFaceLPropMeanCurvature and OCCTFaceGetMeanCurvature have to agree about
// whether the curvature exists at a given (u, v); the adaptor these read through changes how the
// derivatives are fetched, not what counts as a null one.
//
// Measured on the pinned kernel (Scripts/repro/529-breplprop-resolution/), the two values disagree
// exactly where the derivative magnitude falls between them: on a cone face approaching its apex,
// 1e-6 reports the curvature undefined at v = 1e-6 where every Geom_-side entry point reports mean
// curvature -8.66e5, and the disagreement runs down to v = 3e-7.
//
// The adaptor is the caller's, not built here: every one of these call sites needs it for something
// else too -- its parameter bounds, or a second props object at a different order.
inline BRepLProp_SLProps occtFaceLocalProps(const BRepAdaptor_Surface& surface,
                                             double u, double v, int order) {
    return BRepLProp_SLProps(surface, u, v, order, occtLocalPropsResolution());
}

// Edge counterpart, over BRepAdaptor_Curve. As with occtCurveLocalProps the parameter is bound in
// the constructor rather than through a later SetParameter() call.
inline BRepLProp_CLProps occtEdgeLocalProps(const BRepAdaptor_Curve& curve,
                                             double u, int order) {
    return BRepLProp_CLProps(curve, u, order, occtLocalPropsResolution());
}

// Whether a curvature reported by GeomLProp_CLProps/CLProps2d can be turned into a radius, and so
// into a normal direction or a centre of curvature.
//
// Two ways it cannot, and every bridge entry point that inverts a curvature has to reject both:
//
//   - Curvature at or below the resolution. A straight stretch of curve has no centre of
//     curvature; OCCT's own CentreOfCurvature() throws LProp_NotDefined here.
//
//   - Curvature exactly RealLast(). OCCT returns that sentinel, meaning infinite curvature, when
//     the first significant derivative has order > 1 -- a cusp, e.g. a Bezier whose first two
//     poles coincide. IsTangentDefined() is still true there (the search falls through to D2), and
//     RealLast() passes any "is the curvature big enough" test, so the sentinel used to flow
//     straight into CentreOfCurvature(). That is worse than an exception: LProp_CurveUtils::
//     Curvature() returns the sentinel *without* assigning the myCurvature field it normally sets,
//     leaving it 0.0, so ComputeCentreOfCurvature divides the normal by zero and the caller gets
//     (nan, inf, nan) reported as a successfully computed point. Measured on the same cusped
//     Bezier. Normal() rejects the sentinel explicitly and throws, so it was never exposed there.
//
// Non-finite values cannot arise from OCCT's own arithmetic here, but are rejected too so that a
// caller of this predicate never has to ask a second question about the value it approved.
inline bool occtCurveCurvatureIsInvertible(double curvature) {
    return std::isfinite(curvature)
        && curvature != RealLast()
        && std::abs(curvature) > occtLocalPropsResolution();
}

// === #539: the nearest point on a curve, over the range the caller actually has ===
//
// For every bridge entry point that promises the CLOSEST point on a bounded curve, rather than the
// closest of whatever an OCCT search happened to find. No single OCCT call answers this correctly,
// which is why the two entry points that asked it had picked one each and were wrong in different
// ways:
//
//   ShapeAnalysis_Curve::Project answers on any curve, but on an analytic basis (line, circle,
//     ellipse) it solves on the basis curve and reports a parameter outside [first, last] as though
//     it were on the curve. A segment trimmed to [3, 8] calls (100, 0, 0) distance 0; a point on
//     the full circle but off the arc reads as distance 0 too. Passing the range does not help --
//     the 7-argument overload documents itself as EXTENDING the range, and measured identically.
//     Its AdjustToEnds flag, which reads like it might already cover this, changed no measured
//     answer either way.
//
//   GeomAPI_ProjectPointOnCurve honours the range, but returns extrema, not minima: on a half
//     circle the only extremum in range can be the FAR side, reported as LowerDistance (11 where
//     the truth is 7.81), and it finds nothing at all whenever the nearest point is an end.
//
//   The ends themselves are the answer whenever the nearest point is not a perpendicular foot --
//     the ordinary case for a point beyond a trimmed curve, and the one neither call covers.
//
// Taking the minimum over all three is correct on all 51 curve/point combinations measured for
// #539 (line, circle, ellipse, parabola, hyperbola, Bezier, BSpline and offset curves, trimmed and
// not), where ShapeAnalysis_Curve alone was right on 37 and GeomAPI alone on 25. The two it fixes
// beyond the trimmed-range defect the issue named: a parabola or hyperbola whose only in-range
// extremum is a MAXIMUM (both calls answered 20 and 27 where the truth was 19.6 and 25.5), and any
// arc queried from outside its own span.
//
// Periodic bases need no special handling here, and deliberately get none. Geom_TrimmedCurve
// normalises its own domain (trimming a circle to [-1, 1] reports [5.28, 7.28]) and Project returns
// the periodic representative nearest that domain, so a parameter landing outside it is genuinely
// outside the curve -- verified over ten seam-crossing and beyond-one-period cases, every one of
// which the plain clamp below answered exactly.
//
// `first`/`last` are passed in rather than read off the curve because the two callers disagree
// about where the range lives: a Curve3D carries its own, while an edge's range comes from
// BRep_Tool::Curve and usually bounds an unbounded basis curve.
//
// Returns false only when there is nothing to answer with -- a null curve, or a curve on which
// every candidate failed to evaluate. An unbounded curve with no extremum keeps the
// ShapeAnalysis_Curve answer, so callers that always answered still always answer.

#include <ShapeAnalysis_Curve.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>

inline bool occtNearestPointOnCurveRange(const occ::handle<Geom_Curve>& curve, const gp_Pnt& point,
                                         double first, double last, double precision,
                                         gp_Pnt* outPoint, double* outParameter,
                                         double* outDistance) {
    if (curve.IsNull()) return false;

    const bool firstFinite = !Precision::IsInfinite(first);
    const bool lastFinite = !Precision::IsInfinite(last);

    double bestParam = 0.0, bestDistance = RealLast();
    gp_Pnt bestPoint;
    bool found = false;

    // A candidate parameter counts only if it lies in the range AND the curve can be evaluated
    // there; everything else about it is decided by the distance it produces.
    auto consider = [&](double param) {
        if (firstFinite && param < first) return;
        if (lastFinite && param > last) return;
        gp_Pnt candidate;
        try {
            candidate = curve->Value(param);
        } catch (...) {
            return;
        }
        double distance = point.Distance(candidate);
        if (distance < bestDistance) {
            bestDistance = distance;
            bestParam = param;
            bestPoint = candidate;
            found = true;
        }
    };

    // 1. ShapeAnalysis_Curve's answer, kept when it landed inside the range.
    gp_Pnt analysisPoint;
    double analysisParam = 0.0, analysisDistance = RealLast();
    bool haveAnalysis = false;
    try {
        ShapeAnalysis_Curve analyzer;
        analysisDistance = analyzer.Project(curve, point, precision, analysisPoint, analysisParam);
        haveAnalysis = true;
        consider(analysisParam);
    } catch (...) {
        // Leave it to the other two sources.
    }

    // 2. Every extremum inside the range, since the nearest one is not always the first.
    try {
        GeomAPI_ProjectPointOnCurve projector(point, curve, first, last);
        for (int i = 1; i <= projector.NbPoints(); i++) consider(projector.Parameter(i));
    } catch (...) {
        // Same.
    }

    // 3. The ends, where they are real parameters rather than OCCT's infinity sentinel.
    if (firstFinite) consider(first);
    if (lastFinite) consider(last);

    if (!found) {
        if (!haveAnalysis) return false;
        bestParam = analysisParam;
        bestDistance = analysisDistance;
        bestPoint = analysisPoint;
    }

    if (outPoint) *outPoint = bestPoint;
    if (outParameter) *outParameter = bestParam;
    if (outDistance) *outDistance = bestDistance;
    return true;
}

// === #496: the drilling preconditions, and one BRepFeat_MakeCylindricalHole skeleton ===
//
// OCCTSwift drills round holes two ways, and the audit read the older one as a crude
// reimplementation of the newer one, to be folded into it. Measuring both against the pinned kernel
// (Scripts/repro/496-drill-hole-contracts/) says otherwise: they answer different questions, and
// six of thirteen probed requests change answer under a delegation. The two that stay:
//
//   OCCTShapeDrillHole      cuts a FINITE cylinder that starts at `position` and runs `depth` along
//                           `direction` (or a bounding-box-derived length when depth <= 0), with
//                           BRepAlgoAPI_Cut. Works on any shape, overshoots harmlessly, and cannot
//                           say why it failed.
//   BRepFeat_MakeCylindricalHole  is OCCT's local-operation feature drill. Needs a solid, reports a
//                           real BRepFeat_Status, and each of its five modes bounds the hole its own
//                           way — none of which is "start at the origin and run for a length" except
//                           PerformBlind, which then rejects a length that leaves the stock.
//
// So this section does not merge the two algorithms. It gives them the one thing they genuinely
// should share — the preconditions on a drilling request — and collapses the feature family's five
// modes and its status query onto one skeleton, since those really were five copies of one body.

// Both families need a real axis. OCCTShapeDrillHole always checked this; the feature family
// reached gp_Dir, threw Standard_ConstructionError ("input vector has zero norm") and swallowed it
// in its own catch (...). Same answer today, by an accident that any narrowing of that catch would
// have taken away. NaN fails this too, since every NaN comparison is false.
inline bool occtValidDrillDirection(double dirX, double dirY, double dirZ) {
    double sq = dirX * dirX + dirY * dirY + dirZ * dirZ;
    return sq >= 1e-20;   // matches OCCTShapeDrillHole's historical 1e-10 on the magnitude
}

// Both families need a radius OCCT can actually build a cylinder from. Not just positive: the
// pinned xcframework is a Release build, so OCCT's own Raise_if preconditions are compiled out by
// No_Exception (#487) and nothing below the bridge rejects a degenerate one.
//
// Measured on that kernel: a radius of 0 — or any radius below Precision::Confusion, e.g. 1e-14 —
// makes every BRepFeat_MakeCylindricalHole mode return BRepFeat_NoError and a shape identical to
// the input: same volume, same six faces, no material removed. A drill that reports success and
// removes nothing is the worst of the three possible answers. A negative radius throws, and both
// families already turned that into a failure.
inline bool occtValidDrillRadius(double radius) {
    return radius > Precision::Confusion();
}

// The five ways BRepFeat_MakeCylindricalHole can bound a hole. Kept in one place because the Swift
// CylindricalHoleExtent enum, the two bridge entry points and this skeleton all have to agree.
enum OCCTCylindricalHoleExtent : int32_t {
    OCCTCylindricalHoleThroughAll = 0,   // Perform(R)                — an INFINITE cylinder, both
                                         //   ways along the axis; the origin anchors it, and is not
                                         //   a starting point
    OCCTCylindricalHoleUntilEnd   = 1,   // PerformUntilEnd(R)        — bounded by the stock's own
                                         //   entry and exit faces
    OCCTCylindricalHoleThruNext   = 2,   // PerformThruNext(R)        — stops at the next face
    OCCTCylindricalHoleBlind      = 3,   // PerformBlind(R, length)   — `p0` is the length, measured
                                         //   from the origin; HoleTooLong if it leaves the stock
    OCCTCylindricalHoleRange      = 4,   // Perform(R, PFrom, PTo)    — `p0`/`p1` are parameters on
                                         //   the axis
};

// The status vocabulary shared with Swift's Shape.CylindricalHoleStatus. Values are the wire
// contract; do not renumber.
enum OCCTCylindricalHoleStatus : int32_t {
    OCCTCylindricalHoleNoError          = 0,
    OCCTCylindricalHoleInvalidPlacement = 1,
    OCCTCylindricalHoleHoleTooLong      = 2,
    OCCTCylindricalHoleUnknown          = 3,
};

inline int32_t occtCylindricalHoleStatusCode(BRepFeat_Status status) {
    switch (status) {
        case BRepFeat_NoError:          return OCCTCylindricalHoleNoError;
        case BRepFeat_InvalidPlacement: return OCCTCylindricalHoleInvalidPlacement;
        case BRepFeat_HoleTooLong:      return OCCTCylindricalHoleHoleTooLong;
        default:                        return OCCTCylindricalHoleUnknown;
    }
}

// Init, run the requested mode, read Status(), and — only when `outShape` is given and the status
// is clean — Build() and wrap the result. The whole body of what used to be four functions, three
// of which differed by a single Perform* line and the fourth of which was the third with the Build
// deleted.
//
// The status is always returned, which is the point: reporting it was the feature family's one real
// advantage over the boolean drill, and only the ThroughAll mode had an entry point that surfaced
// it. BRepFeat_HoleTooLong is written in exactly two places in the kernel
// (BRepFeat_MakeCylindricalHole.cxx:526 and :667), both inside PerformBlind — so the Swift enum
// carried a case that no public spelling could produce.
//
// A malformed request (no axis direction, a radius OCCT cannot build) is InvalidPlacement rather
// than Unknown: the caller named a placement that cannot define a hole, which is actionable, where
// Unknown means "OCCT raised something we do not recognise".
inline int32_t occtBRepFeatCylindricalHole(OCCTShapeRef shape,
                                           double originX, double originY, double originZ,
                                           double dirX, double dirY, double dirZ,
                                           double radius, int32_t extent,
                                           double p0, double p1,
                                           OCCTShapeRef* outShape) {
    if (outShape) *outShape = nullptr;
    if (!shape) return OCCTCylindricalHoleInvalidPlacement;
    if (!occtValidDrillDirection(dirX, dirY, dirZ)) return OCCTCylindricalHoleInvalidPlacement;
    if (!occtValidDrillRadius(radius)) return OCCTCylindricalHoleInvalidPlacement;

    try {
        gp_Ax1 axis(gp_Pnt(originX, originY, originZ), gp_Dir(dirX, dirY, dirZ));
        BRepFeat_MakeCylindricalHole hole;
        hole.Init(shape->shape, axis);

        switch (extent) {
            case OCCTCylindricalHoleUntilEnd: hole.PerformUntilEnd(radius);  break;
            case OCCTCylindricalHoleThruNext: hole.PerformThruNext(radius);  break;
            case OCCTCylindricalHoleBlind:    hole.PerformBlind(radius, p0); break;
            case OCCTCylindricalHoleRange:    hole.Perform(radius, p0, p1);  break;
            case OCCTCylindricalHoleThroughAll: hole.Perform(radius);        break;
            default: return OCCTCylindricalHoleInvalidPlacement;
        }

        int32_t status = occtCylindricalHoleStatusCode(hole.Status());
        if (!outShape || status != OCCTCylindricalHoleNoError) return status;

        hole.Build();
        TopoDS_Shape result = hole.Shape();
        if (result.IsNull()) return OCCTCylindricalHoleUnknown;

        *outShape = new OCCTShape(result);
        return OCCTCylindricalHoleNoError;
    } catch (...) {
        return OCCTCylindricalHoleUnknown;
    }
}

#endif /* OCCTBridge_Internal_h */
