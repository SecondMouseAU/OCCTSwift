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
#include <TopExp.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>

// === #613: one meaning for an edge or vertex index ===
//
// An edge or vertex index crossing this bridge is a 0-based position in the DEDUPLICATED
// TopExp::MapShapes enumeration -- the one Shape.edges()/edgeCount/edge(at:) and
// Shape.vertices()/vertexCount already read. It is NOT a position in a bare TopExp_Explorer walk,
// which yields one entry per topology OCCURRENCE.
//
// The two disagree on every ordinary solid, because an edge is shared by the two faces it bounds.
// Measured on this branch's kernel: a 20mm box has 12 distinct edges and 24 edge occurrences; the
// issue's L-prism has 18 and 36. From the first repeat onwards, index n names a different edge in
// each enumeration. (Faces are the exception -- explorer and map agree on ordinary solids and
// diverge only when one face has two parents, e.g. the same solid added twice to a compound --
// which is why face indexing is left alone here and belongs to #541.)
//
// Reading the map rather than the traversal is safe for these consumers: the map's equality is
// TopoDS_Shape::IsSame (TopTools_ShapeMapHasher), so orientation cannot select a different entry,
// and none of the call sites converted here depend on an occurrence's orientation.

/// The edge at 0-based `index` in `shape`'s deduplicated edge enumeration, or a null TopoDS_Edge
/// when the index is negative or past the end.
inline TopoDS_Edge occtEdgeAtIndex(const TopoDS_Shape& shape, int32_t index) {
    if (index < 0) return TopoDS_Edge();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(shape, TopAbs_EDGE, map);
    if (index >= map.Extent()) return TopoDS_Edge();
    return TopoDS::Edge(map(index + 1));  // OCCT's indexed maps are 1-based
}

/// The sub-shape at 0-based `index` in `shape`'s deduplicated enumeration of `type`, or a null
/// TopoDS_Shape when the index is out of range.
inline TopoDS_Shape occtSubShapeAtIndex(const TopoDS_Shape& shape, TopAbs_ShapeEnum type,
                                        int32_t index) {
    if (index < 0) return TopoDS_Shape();
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(shape, type, map);
    if (index >= map.Extent()) return TopoDS_Shape();
    return map(index + 1);
}

/// The 0-based position of `sub` in `shape`'s deduplicated enumeration of `type`, or -1 when `sub`
/// is not a sub-shape of that type. The inverse of occtSubShapeAtIndex, used to stamp an index a
/// caller can feed straight back into edges()/edge(at:).
inline int32_t occtIndexOfSubShape(const TopoDS_Shape& shape, TopAbs_ShapeEnum type,
                                   const TopoDS_Shape& sub) {
    if (sub.IsNull()) return -1;
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(shape, type, map);
    const int32_t found = map.FindIndex(sub);
    return found > 0 ? found - 1 : -1;  // FindIndex is 1-based, 0 means absent
}

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

// === #430/#432/#434: surface-filling helpers ===
//
// Shared by both filling entry points — OCCTShapeFill* (OCCTBridge_Healing.mm) and OCCTFilling*
// (OCCTBridge_Modeling.mm). Both now build on BRepOffsetAPI_MakeFilling (#434 converged
// OCCTFilling* off its own separate BRepFill_Filling onto the same class). Definitions live in
// OCCTBridge_Healing.mm.

// Map a plate constraint order (0=position, 1=tangency, 2=curvature) onto the GeomAbs_Shape
// value BRepOffsetAPI_MakeFilling actually accepts. It forwards the enum straight through to
// GeomPlate_CurveConstraint/BRepFill_CurveConstraint as an integer order, and both reject
// anything outside [-1, 2]. So curvature is GeomAbs_C1 (ordinal 2); GeomAbs_G2 (ordinal 3) and
// GeomAbs_C2 (ordinal 4) always throw, whatever BRepOffsetAPI_MakeFilling.hxx claims.
GeomAbs_Shape occtFillingContinuityToGeomAbs(int32_t continuity);

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

#endif /* OCCTBridge_Internal_h */
