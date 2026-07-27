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

// === #430/#432: surface-filling constraint helpers ===
//
// Shared by both filling entry points — OCCTShapeFill* (OCCTBridge_Healing.mm, on
// BRepOffsetAPI_MakeFilling) and OCCTFilling* (OCCTBridge_Modeling.mm, on BRepFill_Filling).
// Definitions live in OCCTBridge_Healing.mm. Converging the two wrappers themselves is #434.

// Map a plate constraint order (0=position, 1=tangency, 2=curvature) onto the GeomAbs_Shape
// value BRepFill_Filling actually accepts. It forwards the enum straight through to
// GeomPlate_CurveConstraint/BRepFill_CurveConstraint as an integer order, and both reject
// anything outside [-1, 2]. So curvature is GeomAbs_C1 (ordinal 2); GeomAbs_G2 (ordinal 3) and
// GeomAbs_C2 (ordinal 4) always throw, whatever BRepOffsetAPI_MakeFilling.hxx claims.
GeomAbs_Shape occtFillingContinuityToGeomAbs(int32_t continuity);

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

// Add one edge constraint, preferring the face-carrying overload whenever a support face is
// available or derivable. Templated because the two entry points hold different (but
// Add-compatible) filler types: BRepOffsetAPI_MakeFilling forwards to a private BRepFill_Filling
// that it does not expose, so there is no common base to take a reference to.
//
// Returns false only when `kind` is Nominated and that face carries no pcurve for the edge; the
// constraint is then NOT added and the caller should fail the whole fill. Every other path adds
// a constraint and returns true — including the no-pcurve-anywhere case, which reaches the
// face-less overload and surfaces as OCCT's documented Standard_Failure at Build() time.
template <class Filler>
bool occtFillingAddConstraint(Filler& filling,
                              const TopoDS_Edge& edge,
                              const TopoDS_Face& support,
                              OCCTFillingSupport kind,
                              GeomAbs_Shape order,
                              bool isBound) {
    if (order != GeomAbs_C0) {
        if (!support.IsNull()) {
            // A support face still has to carry a pcurve for this edge; BRepFill_Filling raises
            // "no 2d representation" if it does not (common on imported shapes).
            double first = 0.0, last = 0.0;
            if (!BRep_Tool::CurveOnSurface(edge, support, first, last).IsNull()) {
                filling.Add(edge, support, order, isBound);
                return true;
            }
            if (kind == OCCTFillingSupport::Nominated) return false;
        }
        TopoDS_Face derived;
        if (occtFillingSupportFaceFromPCurve(edge, derived)) {
            filling.Add(edge, derived, order, isBound);
            return true;
        }
        // No pcurve anywhere: nothing to be tangent to. The face-less overload raises
        // Standard_Failure here, which is OCCT's documented contract for this case.
    }
    filling.Add(edge, order, isBound);
    return true;
}

#endif /* OCCTBridge_Internal_h */
