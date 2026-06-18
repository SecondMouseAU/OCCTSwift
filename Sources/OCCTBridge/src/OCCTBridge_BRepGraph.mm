//
//  OCCTBridge_BRepGraph.mm
//  OCCTSwift
//
//  Extracted from OCCTBridge.mm — issue #99 phase 1.
//
//  Wraps OCCT 8.0.0 BRepGraph + EditorView + MeshView + ML export surface.
//  Originally implemented across v0.129.0 → v0.164.0; lifted into its own
//  translation unit so the main bridge file isn't 58k lines and so changes
//  here don't trigger a rebuild of unrelated bridge areas.
//
//  Public C surface (OCCTBRepGraph*, OCCTPolyTriangulation*, etc.) lives in
//  ../include/OCCTBridge.h. No symbol changes — this is a pure file move.
//

#import "../include/OCCTBridge.h"
#import "OCCTBridge_Internal.h"

// Area-specific OCCT headers — the foundation set + handle wrappers come from
// OCCTBridge_Internal.h, this block is just the BRepGraph-block extras.

#include <set>
#include <vector>
#include <TopAbs_Orientation.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <gp_Pnt.hxx>
#include <gp_Pnt2d.hxx>
#include <gp_Vec.hxx>
#include <gp_Trsf.hxx>
#include <Poly_Triangle.hxx>
#include <BRepTools.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Precision.hxx>
#include <NCollection_Array1.hxx>
#include <NCollection_DataMap.hxx>
#include <NCollection_DynamicArray.hxx>
#include <TCollection_AsciiString.hxx>
#include <GeomAbs_Shape.hxx>

// === Local static helper duplicated from OCCTBridge.mm ===
//
// `static` ensures internal linkage so the symbol doesn't conflict with the
// canonical definition over there. The function bodies are identical.

static GeomAbs_Shape continuityFromInt(int val) {
    switch (val) {
        case 0: return GeomAbs_C0;
        case 1: return GeomAbs_C1;
        case 2: return GeomAbs_C2;
        case 3: return GeomAbs_C3;
        default: return GeomAbs_CN;
    }
}

// === Extracted BRepGraph block ===
//
// Verbatim copy of lines 55486–EOF from OCCTBridge.mm at the time of issue #99.

// MARK: - BRepGraph (v0.129.0)

#include <BRepGraph.hxx>
#include <BRepGraph_TopoView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ReverseIterator.hxx>
#include <BRepGraph_RefsView.hxx>
#include <BRepGraphInc_Relations.hxx>
#include <BRepGraphInc_Definition.hxx>
#include <BRepGraph_MeshView.hxx>
#include <BRepGraph_Compact.hxx>
#include <BRepGraph_Deduplicate.hxx>
#include <BRepGraph_Validate.hxx>
#include <BRepGraph_ChildExplorer.hxx>
#include <BRepGraph_ParentExplorer.hxx>
#include <BRepGraph_NodeId.hxx>
// BRepGraph_RepId moved to the BRepGraphInc subpackage in OCCT 8.0.0p1 (its Kind enum was
// also repurposed to representation kinds: EdgeCurve3D, FaceSurface, FaceTriangulation, …).
#include <BRepGraphInc_RepId.hxx>
// OCCT 8.0.0p1 removed BRepGraph_Builder; shape ingestion is now BRepGraph::ShapesView::Add().
#include <BRepGraph_ShapesView.hxx>

// OCCT 8.0.0p1 side-registry (issue: rep-id ABI preservation)
// ------------------------------------------------------------
// The pre-p1 mesh/geometry write API allocated integer "rep ids": you created a
// representation handle, got back an int id, then bound that id to an entity. p1
// removed rep ids entirely — handles are attached directly to topology defs / the
// mesh cache. To keep the int-rep-id C ABI (consumed by Swift) we keep parallel
// vectors here: Create*Rep() pushes the input handle and returns its index; the
// Set*RepId / RepSet* / append-cached entry points look the index back up and call
// the corresponding handle-based p1 setter.
#include <Poly_Triangulation.hxx>
#include <Poly_Polygon3D.hxx>
#include <Poly_Polygon2D.hxx>
#include <Poly_PolygonOnTriangulation.hxx>
#include <Geom_Surface.hxx>
#include <Geom_Curve.hxx>
#include <Geom2d_Curve.hxx>

struct OCCTBRepGraph {
    BRepGraph graph;
    // Parallel side-registries: index == the legacy "rep id".
    std::vector<occ::handle<Poly_Triangulation>>            triReps;
    std::vector<occ::handle<Poly_Polygon3D>>                poly3dReps;
    std::vector<occ::handle<Poly_Polygon2D>>                poly2dReps;
    std::vector<occ::handle<Poly_PolygonOnTriangulation>>   polyOnTriReps;
    std::vector<occ::handle<Geom_Surface>>                  surfReps;
    std::vector<occ::handle<Geom_Curve>>                    curve3dReps;
    std::vector<occ::handle<Geom2d_Curve>>                  curve2dReps;
};

static BRepGraph_NodeId::Kind kindFromInt(int32_t k) {
    switch (k) {
        case 0: return BRepGraph_NodeId::Kind::Solid;
        case 1: return BRepGraph_NodeId::Kind::Shell;
        case 2: return BRepGraph_NodeId::Kind::Face;
        case 3: return BRepGraph_NodeId::Kind::Wire;
        case 4: return BRepGraph_NodeId::Kind::Edge;
        case 5: return BRepGraph_NodeId::Kind::Vertex;
        case 6: return BRepGraph_NodeId::Kind::Compound;
        case 7: return BRepGraph_NodeId::Kind::CompSolid;
        case 8: return BRepGraph_NodeId::Kind::CoEdge;
        default: return BRepGraph_NodeId::Kind::Solid;
    }
}

OCCTBRepGraphRef OCCTBRepGraphCreate(OCCTShapeRef shape, bool parallel) {
    if (!shape) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        // OCCT 8.0.0p1 removed BRepGraph_Builder; shape ingestion is now BRepGraph::ShapesView::Add().
        BRepGraph::ShapesView::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false; // preserve pre-beta1 behaviour: no auto Product/Occurrence wrap
        auto result = ref->graph.Shapes().Add(*(const TopoDS_Shape*)shape, opts);
        // OCCT 8.0.0p1: BRepGraph::IsDone() was removed; a freshly built graph is valid if Add succeeded.
        if (!result.IsOk()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

void OCCTBRepGraphRelease(OCCTBRepGraphRef graph) { delete graph; }

bool OCCTBRepGraphIsDone(OCCTBRepGraphRef graph) {
    if (!graph) return false;
    // OCCT 8.0.0p1: BRepGraph::IsDone() removed; report "built" as having at least one node.
    return graph->graph.Topo().Gen().NbNodes() > 0;
}

int32_t OCCTBRepGraphNbNodes(OCCTBRepGraphRef graph) {
    if (!graph) return 0;
    return graph->graph.Topo().Gen().NbNodes();
}

// --- Topology Counts ---

int32_t OCCTBRepGraphNbFaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Faces().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveFaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Faces().NbActive() : 0; }
int32_t OCCTBRepGraphNbEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Edges().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Edges().NbActive() : 0; }
int32_t OCCTBRepGraphNbVertices(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Vertices().Nb() : 0; }
int32_t OCCTBRepGraphNbActiveVertices(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Vertices().NbActive() : 0; }
int32_t OCCTBRepGraphNbWires(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Wires().Nb() : 0; }
int32_t OCCTBRepGraphNbShells(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Shells().Nb() : 0; }
int32_t OCCTBRepGraphNbSolids(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Solids().Nb() : 0; }
int32_t OCCTBRepGraphNbCoEdges(OCCTBRepGraphRef g) { return g ? g->graph.Topo().CoEdges().Nb() : 0; }
int32_t OCCTBRepGraphNbCompounds(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Compounds().Nb() : 0; }

// --- Geometry Counts ---

int32_t OCCTBRepGraphNbSurfaces(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbFaceSurfaces() : 0; }
int32_t OCCTBRepGraphNbCurves3D(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbEdgeCurves3D() : 0; }
int32_t OCCTBRepGraphNbCurves2D(OCCTBRepGraphRef g) { return g ? g->graph.Topo().Geometry().NbCoEdgeCurves2D() : 0; }

// --- Face Queries ---

// OCCT 8.0.0p1: TopoView::FaceOps dropped the direct face-face Adjacent()/SharedEdges() helpers, but
// the relation is derivable from the surviving edge->faces incidence (BRepGraph_FacesOfEdge): two
// faces are adjacent iff they share an edge.
static std::set<int32_t> bgAdjacentFaces(OCCTBRepGraphRef g, int32_t faceIndex) {
    std::set<int32_t> adj;
    uint32_t ne = g->graph.Topo().Edges().Nb();
    for (uint32_t e = 0; e < ne; ++e) {
        std::vector<int32_t> faces; bool has = false;
        for (BRepGraph_FacesOfEdge it(g->graph, BRepGraph_EdgeId(e)); it.More(); it.Next()) {
            int32_t fi = (int32_t)it.CurrentId().Index;
            faces.push_back(fi);
            if (fi == faceIndex) has = true;
        }
        if (has) for (int32_t fi : faces) if (fi != faceIndex) adj.insert(fi);
    }
    return adj;
}
static std::vector<int32_t> bgSharedEdges(OCCTBRepGraphRef g, int32_t faceA, int32_t faceB) {
    std::vector<int32_t> shared;
    uint32_t ne = g->graph.Topo().Edges().Nb();
    for (uint32_t e = 0; e < ne; ++e) {
        bool a = false, b = false;
        for (BRepGraph_FacesOfEdge it(g->graph, BRepGraph_EdgeId(e)); it.More(); it.Next()) {
            int32_t fi = (int32_t)it.CurrentId().Index;
            if (fi == faceA) a = true;
            if (fi == faceB) b = true;
        }
        if (a && b) shared.push_back((int32_t)e);
    }
    return shared;
}
int32_t OCCTBRepGraphFaceAdjacentCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try { return (int32_t)bgAdjacentFaces(g, faceIndex).size(); } catch (...) { return 0; }
}
void OCCTBRepGraphFaceAdjacentIndices(OCCTBRepGraphRef g, int32_t faceIndex, int32_t* out) {
    if (!g || !out) return;
    try { int i = 0; for (int32_t f : bgAdjacentFaces(g, faceIndex)) out[i++] = f; } catch (...) {}
}
int32_t OCCTBRepGraphFaceSharedEdgeCount(OCCTBRepGraphRef g, int32_t faceA, int32_t faceB) {
    if (!g) return 0;
    try { return (int32_t)bgSharedEdges(g, faceA, faceB).size(); } catch (...) { return 0; }
}
void OCCTBRepGraphFaceSharedEdgeIndices(OCCTBRepGraphRef g, int32_t faceA, int32_t faceB, int32_t* out) {
    if (!g || !out) return;
    try { int i = 0; for (int32_t e : bgSharedEdges(g, faceA, faceB)) out[i++] = e; } catch (...) {}
}

int32_t OCCTBRepGraphFaceOuterWire(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: OuterWire moved to BRepGraph_Tool::Face.
        auto wid = BRepGraph_Tool::Face::OuterWire(g->graph, BRepGraph_FaceId(faceIndex));
        return wid.IsValid() ? (int32_t)wid.Index : -1;
    } catch (...) { return -1; }
}

// --- Edge Queries ---

int32_t OCCTBRepGraphEdgeNbFaces(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try { return g->graph.Topo().Edges().NbFaces(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return 0; }
}

void OCCTBRepGraphEdgeFaceIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        // OCCT 8.0.0p1: EdgeOps::Faces() became FacesOf() returning an iterator.
        int i = 0;
        for (BRepGraph_FacesOfEdge it(g->graph, BRepGraph_EdgeId(edgeIndex)); it.More(); it.Next())
            outIndices[i++] = (int32_t)it.CurrentId().Index;
    } catch (...) {}
}

bool OCCTBRepGraphEdgeIsBoundary(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::IsBoundary(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsManifold(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::IsManifold(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

// OCCT 8.0.0p1: derived from vertex->edges incidence (VertexOps::Edges) — two edges are adjacent iff
// they share a vertex.
static std::set<int32_t> bgAdjacentEdges(OCCTBRepGraphRef g, int32_t edgeIndex) {
    std::set<int32_t> adj;
    uint32_t nv = g->graph.Topo().Vertices().Nb();
    for (uint32_t v = 0; v < nv; ++v) {
        const auto& edges = g->graph.Topo().Vertices().Edges(BRepGraph_VertexId(v));
        bool has = false;
        for (int i = 0; i < edges.Size(); ++i) if ((int32_t)edges(i).Index == edgeIndex) { has = true; break; }
        if (has) for (int i = 0; i < edges.Size(); ++i) {
            int32_t ei = (int32_t)edges(i).Index;
            if (ei != edgeIndex) adj.insert(ei);
        }
    }
    return adj;
}
int32_t OCCTBRepGraphEdgeAdjacentCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try { return (int32_t)bgAdjacentEdges(g, edgeIndex).size(); } catch (...) { return 0; }
}
void OCCTBRepGraphEdgeAdjacentIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* out) {
    if (!g || !out) return;
    try { int i = 0; for (int32_t e : bgAdjacentEdges(g, edgeIndex)) out[i++] = e; } catch (...) {}
}

// --- Vertex Queries ---

int32_t OCCTBRepGraphVertexEdgeCount(OCCTBRepGraphRef g, int32_t vertexIndex) {
    if (!g) return 0;
    try {
        auto& edges = g->graph.Topo().Vertices().Edges(BRepGraph_VertexId(vertexIndex));
        return (int32_t)edges.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphVertexEdgeIndices(OCCTBRepGraphRef g, int32_t vertexIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& edges = g->graph.Topo().Vertices().Edges(BRepGraph_VertexId(vertexIndex));
        for (int i = 0; i < edges.Size(); i++)
            outIndices[i] = edges(i).Index;
    } catch (...) {}
}

// --- Child Explorer ---

int32_t OCCTBRepGraphChildCount(OCCTBRepGraphRef g, int32_t rootKind, int32_t rootIndex, int32_t targetKind) {
    if (!g) return 0;
    try {
        BRepGraph_NodeId root(kindFromInt(rootKind), rootIndex);
        BRepGraph_ChildExplorer explorer(g->graph, root, kindFromInt(targetKind));
        int32_t count = 0;
        for (; explorer.More(); explorer.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphChildIndices(OCCTBRepGraphRef g,
                                    int32_t rootKind, int32_t rootIndex,
                                    int32_t targetKind,
                                    int32_t* outIndices, int32_t maxCount) {
    if (!g || !outIndices) return 0;
    try {
        BRepGraph_NodeId root(kindFromInt(rootKind), rootIndex);
        BRepGraph_ChildExplorer explorer(g->graph, root, kindFromInt(targetKind));
        int32_t total = 0;
        for (; explorer.More(); explorer.Next()) {
            if (total < maxCount) {
                BRepGraphInc::NodeInstance usage = explorer.Current();
                outIndices[total] = usage.DefId.Index;
            }
            total++;
        }
        return total;
    } catch (...) { return 0; }
}

// --- Parent Explorer ---

int32_t OCCTBRepGraphParentCount(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return 0;
    try {
        BRepGraph_NodeId node(kindFromInt(nodeKind), nodeIndex);
        BRepGraph_ParentExplorer explorer(g->graph, node);
        int32_t count = 0;
        for (; explorer.More(); explorer.Next()) count++;
        return count;
    } catch (...) { return 0; }
}

// --- Validate ---

bool OCCTBRepGraphValidate(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { return BRepGraph_Validate::Perform(g->graph).IsValid(); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphValidateIssueCount(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try { return (int32_t)BRepGraph_Validate::Perform(g->graph).Issues.Size(); }
    catch (...) { return -1; }
}

OCCTBRepGraphValidateResult OCCTBRepGraphValidateDetailed(OCCTBRepGraphRef g) {
    OCCTBRepGraphValidateResult r = {false, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Validate::Perform(g->graph);
        r.isValid = result.IsValid();
        r.errorCount = result.NbIssues(BRepGraph_Validate::Severity::Error);
        r.warningCount = result.NbIssues(BRepGraph_Validate::Severity::Warning);
    } catch (...) {}
    return r;
}

// --- Compact ---

OCCTBRepGraphCompactResult OCCTBRepGraphCompact(OCCTBRepGraphRef g) {
    OCCTBRepGraphCompactResult r = {0, 0, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Compact::Perform(g->graph);
        r.removedVertices = result.NbRemovedVertices;
        r.removedEdges = result.NbRemovedEdges;
        r.removedFaces = result.NbRemovedFaces;
        r.nodesAfter = result.NbNodesAfter;
    } catch (...) {}
    return r;
}

// --- Deduplicate ---

OCCTBRepGraphDeduplicateResult OCCTBRepGraphDeduplicate(OCCTBRepGraphRef g) {
    OCCTBRepGraphDeduplicateResult r = {0, 0, 0, 0};
    if (!g) return r;
    try {
        auto result = BRepGraph_Deduplicate::Perform(g->graph);
        r.canonicalSurfaces = result.NbCanonicalSurfaces;
        r.canonicalCurves = result.NbCanonicalCurves;
        r.surfaceRewrites = result.NbSurfaceRewrites;
        r.curveRewrites = result.NbCurveRewrites;
    } catch (...) {}
    return r;
}

// --- Node Removal ---

bool OCCTBRepGraphIsRemoved(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return false;
    try {
        BRepGraph_NodeId nid(kindFromInt(nodeKind), nodeIndex);
        return g->graph.Topo().Gen().IsRemoved(nid);
    } catch (...) { return false; }
}

// --- Root Nodes ---

int32_t OCCTBRepGraphRootCount(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return (int32_t)g->graph.RootProductIds().Size(); }
    catch (...) { return 0; }
}

void OCCTBRepGraphRootNodes(OCCTBRepGraphRef g, int32_t* outKinds, int32_t* outIndices) {
    if (!g || !outKinds || !outIndices) return;
    try {
        // OCCT 8.0.0 beta1: root iteration is now Products only (was: arbitrary node kinds).
        const auto& roots = g->graph.RootProductIds();
        for (int i = 0; i < (int)roots.Size(); i++) {
            outKinds[i] = (int32_t)BRepGraph_NodeId::Kind::Product;
            outIndices[i] = roots(i).Index;
        }
    } catch (...) {}
}

// --- Stats ---

OCCTBRepGraphStats OCCTBRepGraphGetStats(OCCTBRepGraphRef g) {
    OCCTBRepGraphStats s = {};
    if (!g) return s;
    try {
        auto& topo = g->graph.Topo();
        s.solids = topo.Solids().Nb();
        s.shells = topo.Shells().Nb();
        s.faces = topo.Faces().Nb();
        s.wires = topo.Wires().Nb();
        s.edges = topo.Edges().Nb();
        s.vertices = topo.Vertices().Nb();
        s.coedges = topo.CoEdges().Nb();
        s.compounds = topo.Compounds().Nb();
        s.totalNodes = topo.Gen().NbNodes();
        s.surfaces = topo.Geometry().NbFaceSurfaces();
        s.curves3d = topo.Geometry().NbEdgeCurves3D();
        s.curves2d = topo.Geometry().NbCoEdgeCurves2D();
    } catch (...) {}
    return s;
}

// end of v0.129.0 implementations

// MARK: - BRepGraph Extended (v0.133.0)

#include <BRepGraph_Tool.hxx>
#include <BRepGraph_ShapesView.hxx>
#include <BRepGraph_Copy.hxx>
#include <BRepGraph_Transform.hxx>

// --- Shape Reconstruction ---

OCCTShapeRef OCCTBRepGraphShapeFromNode(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return nullptr;
    try {
        BRepGraph_NodeId nid(kindFromInt(nodeKind), nodeIndex);
        TopoDS_Shape s = g->graph.Shapes().Shape(nid);
        if (s.IsNull()) return nullptr;
        return new OCCTShape{s};
    } catch (...) { return nullptr; }
}

void OCCTBRepGraphFindNode(OCCTBRepGraphRef g, OCCTShapeRef shape,
                           int32_t* outKind, int32_t* outIndex) {
    *outKind = -1;
    *outIndex = -1;
    if (!g || !shape) return;
    try {
        auto nid = g->graph.Shapes().FindNode(shape->shape);
        if (nid.IsValid()) {
            *outKind = static_cast<int32_t>(nid.NodeKind);
            *outIndex = nid.Index;
        }
    } catch (...) {}
}

bool OCCTBRepGraphHasNode(OCCTBRepGraphRef g, OCCTShapeRef shape) {
    if (!g || !shape) return false;
    try { return g->graph.Shapes().HasNode(shape->shape); }
    catch (...) { return false; }
}

// --- Vertex Geometry ---

void OCCTBRepGraphVertexPoint(OCCTBRepGraphRef g, int32_t vertexIndex,
                              double* outX, double* outY, double* outZ) {
    *outX = 0; *outY = 0; *outZ = 0;
    if (!g) return;
    try {
        auto pnt = BRepGraph_Tool::Vertex::Pnt(g->graph, BRepGraph_VertexId(vertexIndex));
        *outX = pnt.X(); *outY = pnt.Y(); *outZ = pnt.Z();
    } catch (...) {}
}

double OCCTBRepGraphVertexTolerance(OCCTBRepGraphRef g, int32_t vertexIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Vertex::Tolerance(g->graph, BRepGraph_VertexId(vertexIndex)); }
    catch (...) { return 0; }
}

// --- Edge Geometry ---

double OCCTBRepGraphEdgeTolerance(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Edge::Tolerance(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphEdgeIsDegenerated(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::Degenerated(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

// OCCT 8.0.0p1 made SameParameter / SameRange per-CoEdge derived properties (BRepGraph_Tool::CoEdge),
// no longer edge-level state. We resolve the edge to one of its coedges (via FindCoEdgeId over the
// edge's faces) and query that; a free edge with no coedge defaults to true (nothing to mismatch).
static BRepGraph_CoEdgeId bgFirstCoEdgeOfEdge(OCCTBRepGraphRef g, int32_t edgeIndex) {
    BRepGraph_EdgeId eid(edgeIndex);
    uint32_t nf = g->graph.Topo().Faces().Nb();
    for (uint32_t fi = 0; fi < nf; ++fi) {
        auto cid = BRepGraph_Tool::Edge::FindCoEdgeId(g->graph, eid, BRepGraph_FaceId(fi));
        if (cid.IsValid()) return cid;
    }
    return BRepGraph_CoEdgeId();   // invalid
}

bool OCCTBRepGraphEdgeIsSameParameter(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try {
        auto cid = bgFirstCoEdgeOfEdge(g, edgeIndex);
        return cid.IsValid() ? BRepGraph_Tool::CoEdge::SameParameter(g->graph, cid) : true;
    } catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsSameRange(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try {
        auto cid = bgFirstCoEdgeOfEdge(g, edgeIndex);
        return cid.IsValid() ? BRepGraph_Tool::CoEdge::SameRange(g->graph, cid) : true;
    } catch (...) { return false; }
}

void OCCTBRepGraphEdgeRange(OCCTBRepGraphRef g, int32_t edgeIndex,
                            double* outFirst, double* outLast) {
    *outFirst = 0; *outLast = 0;
    if (!g) return;
    try {
        auto range = BRepGraph_Tool::Edge::Range(g->graph, BRepGraph_EdgeId(edgeIndex));
        *outFirst = range.first; *outLast = range.second;
    } catch (...) {}
}

bool OCCTBRepGraphEdgeHasCurve(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Edge::HasCurve(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphEdgeIsClosedOnFace(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex) {
    if (!g) return false;
    try {
        // OCCT 8.0.0p1: IsClosedOnFace replaced by IsSeamOnFace (an edge closed on a face is its seam).
        return BRepGraph_Tool::Edge::IsSeamOnFace(g->graph,
            BRepGraph_EdgeId(edgeIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphEdgeHasPolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try {
        // OCCT 8.0.0p1: polygon presence is now a MeshView query (cache or persistent).
        return g->graph.Mesh().Effective().Edges().Has(BRepGraph_EdgeId(edgeIndex));
    } catch (...) { return false; }
}

// OCCT 8.0.0p1: per-edge max-regularity continuity is no longer exposed publicly
// (continuity is per (edge, face1, face2) and not aggregated). Stubbed.
int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef, int32_t) { return 0; }

// --- Face Geometry ---

double OCCTBRepGraphFaceTolerance(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Face::Tolerance(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return 0; }
}

// OCCT 8.0.0p1: the face "natural restriction" flag is no longer stored or exposed publicly
// (the incidence model derives restriction from wires). Stubbed.
bool OCCTBRepGraphFaceIsNaturalRestriction(OCCTBRepGraphRef, int32_t) { return false; }

bool OCCTBRepGraphFaceHasSurface(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Face::HasSurface(g->graph, BRepGraph_FaceId(faceIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphFaceHasTriangulation(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try {
        // OCCT 8.0.0p1: triangulation presence is now a MeshView query (cache or persistent).
        return g->graph.Mesh().Effective().Faces().Has(BRepGraph_FaceId(faceIndex));
    } catch (...) { return false; }
}

// --- Wire Queries ---

bool OCCTBRepGraphWireIsClosed(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::Wire::IsClosed(g->graph, BRepGraph_WireId(wireIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphWireNbCoEdges(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return 0;
    try { return BRepGraph_Tool::Wire::NbCoEdges(g->graph, BRepGraph_WireId(wireIndex)); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphWireFaceCount(OCCTBRepGraphRef g, int32_t wireIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: WireOps::Faces() removed; resolve parent faces from the wire's parent wire refs.
        const auto& rel = g->graph.Topo().Wires().Relations(BRepGraph_WireId(wireIndex));
        int32_t n = 0;
        for (BRepGraph_FacesOfWire it(g->graph, rel.ParentWireRefIds); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

void OCCTBRepGraphWireFaceIndices(OCCTBRepGraphRef g, int32_t wireIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        const auto& rel = g->graph.Topo().Wires().Relations(BRepGraph_WireId(wireIndex));
        int i = 0;
        for (BRepGraph_FacesOfWire it(g->graph, rel.ParentWireRefIds); it.More(); it.Next())
            outIndices[i++] = (int32_t)it.CurrentId().Index;
    } catch (...) {}
}

// --- CoEdge Queries ---

int32_t OCCTBRepGraphCoEdgeEdge(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        auto eid = g->graph.Topo().CoEdges().Edge(BRepGraph_CoEdgeId(coedgeIndex));
        return eid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCoEdgeFace(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        auto fid = g->graph.Topo().CoEdges().Face(BRepGraph_CoEdgeId(coedgeIndex));
        return fid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCoEdgeSeamPair(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: SeamPair moved to BRepGraph_Tool::CoEdge.
        auto pid = BRepGraph_Tool::CoEdge::SeamPair(g->graph, BRepGraph_CoEdgeId(coedgeIndex));
        return pid.IsValid() ? (int32_t)pid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphCoEdgeHasPCurve(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try { return BRepGraph_Tool::CoEdge::HasPCurve(g->graph, BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) { return false; }
}

void OCCTBRepGraphCoEdgeRange(OCCTBRepGraphRef g, int32_t coedgeIndex,
                              double* outFirst, double* outLast) {
    *outFirst = 0; *outLast = 0;
    if (!g) return;
    try {
        auto range = BRepGraph_Tool::CoEdge::Range(g->graph, BRepGraph_CoEdgeId(coedgeIndex));
        *outFirst = range.first; *outLast = range.second;
    } catch (...) {}
}

// --- Shell Queries ---

int32_t OCCTBRepGraphShellSolidCount(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: ShellOps::Solids() removed; resolve parent solids from the shell's parent shell refs.
        const auto& rel = g->graph.Topo().Shells().Relations(BRepGraph_ShellId(shellIndex));
        int32_t n = 0;
        for (BRepGraph_SolidsOfShell it(g->graph, rel.ParentShellRefIds); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

void OCCTBRepGraphShellSolidIndices(OCCTBRepGraphRef g, int32_t shellIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        const auto& rel = g->graph.Topo().Shells().Relations(BRepGraph_ShellId(shellIndex));
        int i = 0;
        for (BRepGraph_SolidsOfShell it(g->graph, rel.ParentShellRefIds); it.More(); it.Next())
            outIndices[i++] = (int32_t)it.CurrentId().Index;
    } catch (...) {}
}

// --- Solid Queries ---

int32_t OCCTBRepGraphSolidCompSolidCount(OCCTBRepGraphRef g, int32_t solidIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: SolidOps::CompSolids() removed; resolve via the solid's parent solid refs.
        const auto& rel = g->graph.Topo().Solids().Relations(BRepGraph_SolidId(solidIndex));
        int32_t n = 0;
        for (BRepGraph_CompSolidsOfSolid it(g->graph, rel.ParentSolidRefIds); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

// --- History ---
// OCCT 8.0.0p1: history moved from BRepGraph::History() to the registered BRepGraph_LayerHistory
// layer (via LayerRegistry().FindLayer<>() / Ensure<>()); records are now `Event`s whose Mapping
// value type is NCollection_LinearVector (was NCollection_DynamicArray).
#include <BRepGraph_LayerHistory.hxx>
#include <BRepGraph_LayerRegistry.hxx>

// Read the history layer if one has been registered (null otherwise). Reads do not create it.
static occ::handle<BRepGraph_LayerHistory> bgHistory(OCCTBRepGraphRef g) {
    return g->graph.LayerRegistry().FindLayer<BRepGraph_LayerHistory>();
}

int32_t OCCTBRepGraphHistoryNbRecords(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { auto h = bgHistory(g); return h.IsNull() ? 0 : (int32_t)h->NbRecords(); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphHistoryIsEnabled(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { auto h = bgHistory(g); return h.IsNull() ? false : h->IsEnabled(); }
    catch (...) { return false; }
}

void OCCTBRepGraphHistorySetEnabled(OCCTBRepGraphRef g, bool enabled) {
    if (!g) return;
    // Enabling creates the layer if absent; disabling on an absent layer is a no-op.
    try {
        if (enabled) g->graph.LayerRegistry().Ensure<BRepGraph_LayerHistory>()->SetEnabled(true);
        else { auto h = bgHistory(g); if (!h.IsNull()) h->SetEnabled(false); }
    } catch (...) {}
}

void OCCTBRepGraphHistoryClear(OCCTBRepGraphRef g) {
    if (!g) return;
    try { auto h = bgHistory(g); if (!h.IsNull()) h->Clear(); }
    catch (...) {}
}

bool OCCTBRepGraphHistoryGetRecordInfo(OCCTBRepGraphRef g,
                                        int32_t recordIdx,
                                        char* outOpName,
                                        int32_t outOpNameMax,
                                        int32_t* outSequenceNumber) {
    if (!g || !outOpName || !outSequenceNumber || outOpNameMax <= 0) return false;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull() || recordIdx < 0 || recordIdx >= (int32_t)hist->NbRecords()) return false;
        const auto& rec = hist->Record((size_t)recordIdx);
        const char* src = rec.OperationName.ToCString();
        int srcLen = rec.OperationName.Length();
        int copy = std::min(srcLen, outOpNameMax - 1);
        memcpy(outOpName, src, copy);
        outOpName[copy] = '\0';
        *outSequenceNumber = (int32_t)rec.SequenceNumber;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphHistoryGetRecordOriginalsCount(OCCTBRepGraphRef g, int32_t recordIdx) {
    if (!g) return 0;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull() || recordIdx < 0 || recordIdx >= (int32_t)hist->NbRecords()) return 0;
        const auto& rec = hist->Record((size_t)recordIdx);
        return (int32_t)rec.Mapping.Extent();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphHistoryGetRecordOriginals(OCCTBRepGraphRef g,
                                                int32_t recordIdx,
                                                int32_t* outKinds,
                                                int32_t* outIndices,
                                                int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return 0;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull() || recordIdx < 0 || recordIdx >= (int32_t)hist->NbRecords()) return 0;
        const auto& rec = hist->Record((size_t)recordIdx);
        int32_t total = 0;
        typedef NCollection_DataMap<BRepGraph_NodeId, NCollection_LinearVector<BRepGraph_NodeId>> MapT;
        for (MapT::Iterator it(rec.Mapping); it.More(); it.Next()) {
            if (total < maxCount) {
                outKinds[total] = (int32_t)it.Key().NodeKind;
                outIndices[total] = it.Key().Index;
            }
            total++;
        }
        return total;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphHistoryGetRecordMapping(OCCTBRepGraphRef g,
                                              int32_t recordIdx,
                                              int32_t origKind,
                                              int32_t origIndex,
                                              int32_t* outKinds,
                                              int32_t* outIndices,
                                              int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return -1;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull() || recordIdx < 0 || recordIdx >= (int32_t)hist->NbRecords()) return -1;
        const auto& rec = hist->Record((size_t)recordIdx);
        BRepGraph_NodeId key((BRepGraph_NodeId::Kind)origKind, origIndex);
        if (!rec.Mapping.IsBound(key)) return -1;
        const auto& repls = rec.Mapping.Find(key);
        int32_t total = (int32_t)repls.Size();
        int32_t copy = std::min(total, maxCount);
        for (int32_t i = 0; i < copy; i++) {
            outKinds[i] = (int32_t)repls.Value(i).NodeKind;
            outIndices[i] = repls.Value(i).Index;
        }
        return total;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphHistoryFindOriginal(OCCTBRepGraphRef g,
                                       int32_t derivedKind,
                                       int32_t derivedIndex,
                                       int32_t* outKind,
                                       int32_t* outIndex) {
    if (!g || !outKind || !outIndex) return false;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull()) return false;
        BRepGraph_NodeId derived((BRepGraph_NodeId::Kind)derivedKind, derivedIndex);
        BRepGraph_NodeId orig = hist->FindOriginal(derived);
        *outKind = (int32_t)orig.NodeKind;
        *outIndex = orig.Index;
        return true;
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphHistoryFindDerived(OCCTBRepGraphRef g,
                                         int32_t origKind,
                                         int32_t origIndex,
                                         int32_t* outKinds,
                                         int32_t* outIndices,
                                         int32_t maxCount) {
    if (!g || !outKinds || !outIndices) return 0;
    try {
        auto hist = bgHistory(g);
        if (hist.IsNull()) return 0;
        BRepGraph_NodeId orig((BRepGraph_NodeId::Kind)origKind, origIndex);
        auto derived = hist->FindDerived(orig);
        int32_t total = (int32_t)derived.Size();
        int32_t copy = std::min(total, maxCount);
        for (int32_t i = 0; i < copy; i++) {
            outKinds[i] = (int32_t)derived.Value(i).NodeKind;
            outIndices[i] = derived.Value(i).Index;
        }
        return total;
    } catch (...) { return 0; }
}

void OCCTBRepGraphHistoryRecord(OCCTBRepGraphRef g,
                                 const char* opName,
                                 int32_t origKind,
                                 int32_t origIndex,
                                 const int32_t* replKinds,
                                 const int32_t* replIndices,
                                 int32_t replCount) {
    if (!g || !opName) return;
    try {
        // Recording creates the history layer if absent (Ensure); the new Record() takes an Array1.
        auto hist = g->graph.LayerRegistry().Ensure<BRepGraph_LayerHistory>();
        if (hist.IsNull()) return;
        BRepGraph_NodeId orig((BRepGraph_NodeId::Kind)origKind, origIndex);
        NCollection_Array1<BRepGraph_NodeId> repls(0, std::max(0, replCount) - 1);
        for (int32_t i = 0; i < replCount; i++) {
            repls.SetValue(i, BRepGraph_NodeId((BRepGraph_NodeId::Kind)replKinds[i], replIndices[i]));
        }
        hist->Record(TCollection_AsciiString(opName), orig, repls);
    } catch (...) {}
}

// --- Poly Counts ---

int32_t OCCTBRepGraphNbTriangulations(OCCTBRepGraphRef g) {
    if (!g) return 0;
    // OCCT 8.0.0p1: PolyOps count getters were renamed (Nb*FaceTriangulations / NbEdgePolygons3D / ...).
    try { return g->graph.Mesh().Poly().NbFaceTriangulations(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbPolygons3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbEdgePolygons3D(); }
    catch (...) { return 0; }
}

// --- MeshView additions (v0.158.0, OCCT 8.0.0 beta1 two-tier mesh storage) ---

int32_t OCCTBRepGraphMeshNbPolygons2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbCoEdgePolygons2D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbPolygonsOnTri(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbCoEdgePolygonsOnTri(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActiveTriangulations(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActiveTriangulations(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygons3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygons3D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygons2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygons2D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphMeshNbActivePolygonsOnTri(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Mesh().Poly().NbActivePolygonsOnTri(); }
    catch (...) { return 0; }
}

// MeshView FaceOps: cache-first triangulation queries.
// OCCT 8.0.0p1: the mesh cache no longer exposes per-entity RepIds. These now return a presence
// sentinel (0 = a mesh entry exists, -1 = none) instead of the former rep index.

int32_t OCCTBRepGraphMeshFaceActiveTriangulationRepId(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try {
        return g->graph.Mesh().Cache().Faces().Has(BRepGraph_FaceId(faceIndex)) ? 0 : -1;
    } catch (...) { return -1; }
}

// MeshView EdgeOps: cache-first polygon3D queries.

int32_t OCCTBRepGraphMeshEdgePolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        return g->graph.Mesh().Cache().Edges().Has(BRepGraph_EdgeId(edgeIndex)) ? 0 : -1;
    } catch (...) { return -1; }
}

// MeshView CoEdgeOps: cache-only coedge mesh check.

bool OCCTBRepGraphMeshCoEdgeHasMesh(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try { return g->graph.Mesh().Cache().CoEdges().Has(BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) { return false; }
}

// MeshCache write API (v0.160.0), rewrapped for OCCT 8.0.0p1 via the side-registry.
// p1 removed integer RepIds: the cache editor (Mesh().Editor()) takes Poly_* handles directly.
// We preserve the int-rep-id ABI by stashing the input handle in the side-registry (returning its
// index as the "rep id") and resolving that index back to the handle in the Set/Append entry points.

int32_t OCCTBRepGraphMeshCreateTriangulationRep(OCCTBRepGraphRef g, OCCTPolyTriangulationRef tri) {
    if (!g || !tri) return -1;
    try {
        const Handle(Poly_Triangulation)& h = reinterpret_cast<Poly_TriangulationOpaque*>(tri)->triangulation;
        if (h.IsNull()) return -1;
        g->triReps.push_back(h);
        return (int32_t)(g->triReps.size() - 1);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphMeshCreatePolygon3DRep(OCCTBRepGraphRef g, OCCTPolyPolygon3DRef poly) {
    if (!g || !poly) return -1;
    try {
        const Handle(Poly_Polygon3D)& h = reinterpret_cast<Poly_Polygon3DOpaque*>(poly)->polygon;
        if (h.IsNull()) return -1;
        g->poly3dReps.push_back(h);
        return (int32_t)(g->poly3dReps.size() - 1);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphMeshCreatePolygonOnTriRep(OCCTBRepGraphRef g, OCCTPolyPolygonOnTriRef poly, int32_t triRepId) {
    // p1 no longer links a polygon-on-tri to a triangulation by id at creation time (the link is
    // resolved at attach time via CoEdgeDef.FaceId). triRepId is accepted for ABI compat but unused.
    (void)triRepId;
    if (!g || !poly) return -1;
    try {
        const Handle(Poly_PolygonOnTriangulation)& h = reinterpret_cast<Poly_PolygonOnTriangulationOpaque*>(poly)->polygon;
        if (h.IsNull()) return -1;
        g->polyOnTriReps.push_back(h);
        return (int32_t)(g->polyOnTriReps.size() - 1);
    } catch (...) { return -1; }
}

void OCCTBRepGraphMeshAppendCachedTriangulation(OCCTBRepGraphRef g, int32_t faceIndex, int32_t triRepId) {
    if (!g || triRepId < 0 || (size_t)triRepId >= g->triReps.size()) return;
    try {
        g->graph.Mesh().Editor().Faces().SetCachedTriangulation(
            BRepGraph_FaceId(faceIndex), g->triReps[triRepId]);
    } catch (...) {}
}

void OCCTBRepGraphMeshSetCachedActiveIndex(OCCTBRepGraphRef g, int32_t faceIndex, int32_t activeIndex) {
    // OCCT 8.0.0p1: a face's cached mesh holds exactly ONE triangulation; there is no public
    // multi-LOD active-index selection on the cache. No-op (the single cached triangulation is active).
    (void)g; (void)faceIndex; (void)activeIndex;
}

void OCCTBRepGraphMeshSetCachedPolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t polyRepId) {
    if (!g || polyRepId < 0 || (size_t)polyRepId >= g->poly3dReps.size()) return;
    try {
        g->graph.Mesh().Editor().Edges().SetCachedPolygon3D(
            BRepGraph_EdgeId(edgeIndex), g->poly3dReps[polyRepId]);
    } catch (...) {}
}

void OCCTBRepGraphMeshAppendCachedPolygonOnTri(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polyRepId) {
    if (!g || polyRepId < 0 || (size_t)polyRepId >= g->polyOnTriReps.size()) return;
    try {
        g->graph.Mesh().Editor().CoEdges().AppendCachedPolygonOnTri(
            BRepGraph_CoEdgeId(coedgeIndex), g->polyOnTriReps[polyRepId]);
    } catch (...) {}
}

void OCCTBRepGraphMeshSetCachedPolygon2D(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t poly2DRepId) {
    if (!g || poly2DRepId < 0 || (size_t)poly2DRepId >= g->poly2dReps.size()) return;
    try {
        g->graph.Mesh().Editor().CoEdges().SetCachedPolygon2D(
            BRepGraph_CoEdgeId(coedgeIndex), g->poly2dReps[poly2DRepId]);
    } catch (...) {}
}

// --- Active Geometry Counts ---

int32_t OCCTBRepGraphNbActiveSurfaces(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveFaceSurfaces(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbActiveCurves3D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveEdgeCurves3D(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbActiveCurves2D(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Geometry().NbActiveCoEdgeCurves2D(); }
    catch (...) { return 0; }
}

// --- SameDomain ---
// OCCT 8.0.0p1: TopoView::FaceOps no longer exposes a SameDomain() query (no public same-domain
// adjacency survived the incidence-table redesign). Stubbed.
int32_t OCCTBRepGraphFaceSameDomainCount(OCCTBRepGraphRef, int32_t) { return 0; }
void OCCTBRepGraphFaceSameDomainIndices(OCCTBRepGraphRef, int32_t, int32_t*) {}

// --- Copy and Transform ---

OCCTBRepGraphRef OCCTBRepGraphCopy(OCCTBRepGraphRef g, bool copyGeom) {
    if (!g) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        // OCCT 8.0.0p1: Perform now copies source INTO a target graph and returns bool.
        auto geomPolicy = copyGeom ? BRepGraph_Copy::GeomPolicy::Copy : BRepGraph_Copy::GeomPolicy::Share;
        if (!BRepGraph_Copy::Perform(g->graph, ref->graph, geomPolicy)) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

OCCTBRepGraphRef OCCTBRepGraphCopyFace(OCCTBRepGraphRef g, int32_t faceIndex, bool copyGeom) {
    if (!g) return nullptr;
    try {
        auto ref = new OCCTBRepGraph();
        // OCCT 8.0.0p1: CopyNode copies into a target graph and returns the mapped node id.
        auto geomPolicy = copyGeom ? BRepGraph_Copy::GeomPolicy::Copy : BRepGraph_Copy::GeomPolicy::Share;
        auto mapped = BRepGraph_Copy::CopyNode(
            g->graph, ref->graph,
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, faceIndex),
            geomPolicy);
        if (!mapped.IsValid()) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

OCCTBRepGraphRef OCCTBRepGraphTransformTranslation(OCCTBRepGraphRef g,
                                                    double dx, double dy, double dz,
                                                    bool copyGeom) {
    if (!g) return nullptr;
    try {
        gp_Trsf trsf;
        trsf.SetTranslation(gp_Vec(dx, dy, dz));
        auto ref = new OCCTBRepGraph();
        // OCCT 8.0.0p1: Perform now transforms source INTO a target graph and returns bool.
        auto geomPolicy = copyGeom ? BRepGraph_Copy::GeomPolicy::Copy : BRepGraph_Copy::GeomPolicy::Share;
        if (!BRepGraph_Transform::Perform(g->graph, ref->graph, trsf, geomPolicy)) { delete ref; return nullptr; }
        return ref;
    } catch (...) { return nullptr; }
}

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

#include <BRepGraph_RefsView.hxx>

static BRepGraph_RefId::Kind refKindFromInt(int32_t k) {
    // OCCT 8.0.0p1: BRepGraph_RefId::Kind::CoEdge was removed (coedges are no longer
    // reference-counted). The historic ABI code 3 (CoEdge) now maps to Shell as an inert fallback;
    // the remaining codes keep their original Swift-facing meaning.
    switch (k) {
        case 0: return BRepGraph_RefId::Kind::Shell;
        case 1: return BRepGraph_RefId::Kind::Face;
        case 2: return BRepGraph_RefId::Kind::Wire;
        case 3: return BRepGraph_RefId::Kind::Shell;   // was CoEdge (removed)
        case 4: return BRepGraph_RefId::Kind::Vertex;
        case 5: return BRepGraph_RefId::Kind::Solid;
        case 6: return BRepGraph_RefId::Kind::Child;
        case 7: return BRepGraph_RefId::Kind::Occurrence;
        default: return BRepGraph_RefId::Kind::Shell;
    }
}

static int32_t nodeKindToInt(BRepGraph_NodeId::Kind k) {
    switch (k) {
        case BRepGraph_NodeId::Kind::Solid:     return 0;
        case BRepGraph_NodeId::Kind::Shell:     return 1;
        case BRepGraph_NodeId::Kind::Face:      return 2;
        case BRepGraph_NodeId::Kind::Wire:      return 3;
        case BRepGraph_NodeId::Kind::Edge:      return 4;
        case BRepGraph_NodeId::Kind::Vertex:    return 5;
        case BRepGraph_NodeId::Kind::Compound:  return 6;
        case BRepGraph_NodeId::Kind::CompSolid: return 7;
        case BRepGraph_NodeId::Kind::CoEdge:    return 8;
        default: return -1;
    }
}

// --- Product (Assembly) Queries ---

int32_t OCCTBRepGraphNbProducts(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Products().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbOccurrences(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().Occurrences().Nb(); }
    catch (...) { return 0; }
}

bool OCCTBRepGraphProductIsAssembly(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Products().IsAssembly(BRepGraph_ProductId(productIndex)); }
    catch (...) { return false; }
}

bool OCCTBRepGraphProductIsPart(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try { return g->graph.Topo().Products().IsPart(BRepGraph_ProductId(productIndex)); }
    catch (...) { return false; }
}

int32_t OCCTBRepGraphProductNbComponents(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return 0;
    try { return g->graph.Topo().Products().NbComponents(BRepGraph_ProductId(productIndex)); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphProductShapeRootKind(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return -1;
    try {
        auto nid = g->graph.Topo().Products().ShapeRootNode(BRepGraph_ProductId(productIndex));
        if (!nid.IsValid()) return -1;
        return nodeKindToInt(nid.NodeKind);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphProductShapeRootIndex(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return -1;
    try {
        auto nid = g->graph.Topo().Products().ShapeRootNode(BRepGraph_ProductId(productIndex));
        if (!nid.IsValid()) return -1;
        return nid.Index;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphOccurrenceProduct(OCCTBRepGraphRef g, int32_t occIndex) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Topo().Occurrences().Product(BRepGraph_OccurrenceId(occIndex));
        return pid.IsValid() ? pid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphOccurrenceParentProduct(OCCTBRepGraphRef g, int32_t occIndex) {
    if (!g) return -1;
    try {
        auto pid = g->graph.Topo().Occurrences().ParentProduct(BRepGraph_OccurrenceId(occIndex));
        return pid.IsValid() ? pid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphRootProductCount(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try {
        const auto& roots = g->graph.RootProductIds();
        return (int32_t)roots.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphRootProductIndices(OCCTBRepGraphRef g, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        const auto& roots = g->graph.RootProductIds();
        for (int i = 0; i < (int)roots.Size(); ++i) {
            outIndices[i] = roots(i).Index;
        }
    } catch (...) {}
}

// --- RefsView Per-Kind Counts ---

int32_t OCCTBRepGraphNbShellRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Shells().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbFaceRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Faces().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbWireRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Wires().Nb(); }
    catch (...) { return 0; }
}

// OCCT 8.0.0p1: coedges became first-class topology entities (no longer separate refs in RefsView).
// The per-use count maps to the coedge count in the topology view (e.g. 24 for a box).
int32_t OCCTBRepGraphNbCoEdgeRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return (int32_t)g->graph.Topo().CoEdges().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbVertexRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Vertices().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbSolidRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Solids().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbChildRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Children().Nb(); }
    catch (...) { return 0; }
}

int32_t OCCTBRepGraphNbOccurrenceRefs(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Refs().Occurrences().Nb(); }
    catch (...) { return 0; }
}

// --- RefsView Global Methods ---

int32_t OCCTBRepGraphRefChildNodeKind(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: cross-kind ref queries moved to RefsView::Gen().
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        auto nid = g->graph.Refs().Gen().ChildNode(rid);
        if (!nid.IsValid()) return -1;
        return nodeKindToInt(nid.NodeKind);
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphRefChildNodeIndex(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return -1;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        auto nid = g->graph.Refs().Gen().ChildNode(rid);
        if (!nid.IsValid()) return -1;
        return nid.Index;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphRefIsRemoved(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return false;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return g->graph.Refs().Gen().IsRemoved(rid);
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphRefOrientation(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return 0;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return (int32_t)g->graph.Refs().Gen().Orientation(rid);
    } catch (...) { return 0; }
}

// --- Face Definition Details ---

int32_t OCCTBRepGraphFaceNbWires(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: wire refs moved off FaceDef into FaceRelations; NbWires exposed via Tool.
        return (int32_t)BRepGraph_Tool::Face::NbWires(g->graph, BRepGraph_FaceId(faceIndex));
    } catch (...) { return 0; }
}

// OCCT 8.0.0p1: faces no longer carry direct vertex references (FaceRelations holds only
// WireRefIds + ParentFaceRefIds). No public face-vertex-ref count. Stubbed.
int32_t OCCTBRepGraphFaceNbVertexRefs(OCCTBRepGraphRef, int32_t) { return 0; }

// --- Edge Definition Details ---

// OCCT 8.0.0p1: Edge::StartVertexId/EndVertexId return a VertexRefId (a per-edge USE reference), not
// the shared vertex definition. Resolve the ref to its vertex def id (ChildVertexId) so callers get a
// valid index into the vertex table.
static int32_t bgVertexDefOfRef(OCCTBRepGraphRef g, BRepGraph_VertexRefId ref) {
    if (!ref.IsValid()) return -1;
    auto def = g->graph.Refs().Vertices().Entry(ref).ChildVertexId;
    return def.IsValid() ? (int32_t)def.Index : -1;
}

int32_t OCCTBRepGraphEdgeStartVertex(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        return bgVertexDefOfRef(g, BRepGraph_Tool::Edge::StartVertexId(g->graph, BRepGraph_EdgeId(edgeIndex)));
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphEdgeEndVertex(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try {
        return bgVertexDefOfRef(g, BRepGraph_Tool::Edge::EndVertexId(g->graph, BRepGraph_EdgeId(edgeIndex)));
    } catch (...) { return -1; }
}

bool OCCTBRepGraphEdgeIsClosed(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    // OCCT 8.0.0p1: edge closure is derived, not a stored EdgeDef flag; query via Tool::Edge.
    try { return BRepGraph_Tool::Edge::IsClosed(g->graph, BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}

// --- Compound/CompSolid Queries ---

int32_t OCCTBRepGraphCompoundParentCount(OCCTBRepGraphRef g, int32_t compoundIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: ParentCompounds() removed; resolve via the node's compound child refs.
        const auto& refs = g->graph.Topo().Gen().CompoundRefIds(
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Compound, compoundIndex));
        int32_t n = 0;
        for (BRepGraph_CompoundsOfCompound it(g->graph, refs); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompoundChildCount(OCCTBRepGraphRef g, int32_t compoundIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: child refs moved off CompoundDef into CompoundRelations.
        auto& rel = g->graph.Topo().Compounds().Relations(BRepGraph_CompoundId(compoundIndex));
        return (int32_t)rel.ChildRefIds.Size();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompSolidSolidCount(OCCTBRepGraphRef g, int32_t compSolidIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: solid refs moved off CompSolidDef into CompSolidRelations.
        auto& rel = g->graph.Topo().CompSolids().Relations(BRepGraph_CompSolidId(compSolidIndex));
        return (int32_t)rel.SolidRefIds.Size();
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphCompSolidCompoundCount(OCCTBRepGraphRef g, int32_t compSolidIndex) {
    if (!g) return 0;
    try {
        const auto& refs = g->graph.Topo().Gen().CompoundRefIds(
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::CompSolid, compSolidIndex));
        int32_t n = 0;
        for (BRepGraph_CompoundsOfCompSolid it(g->graph, refs); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

// --- Edge Additional Queries ---

int32_t OCCTBRepGraphEdgeWireCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: EdgeOps::Wires() removed; iterate parent wires via BRepGraph_WiresOfEdge.
        int32_t n = 0;
        for (BRepGraph_WiresOfEdge it(g->graph, BRepGraph_EdgeId(edgeIndex)); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

void OCCTBRepGraphEdgeWireIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        int i = 0;
        for (BRepGraph_WiresOfEdge it(g->graph, BRepGraph_EdgeId(edgeIndex)); it.More(); it.Next())
            outIndices[i++] = (int32_t)it.CurrentId().Index;
    } catch (...) {}
}

int32_t OCCTBRepGraphEdgeCoEdgeCount(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        auto& coedges = g->graph.Topo().Edges().CoEdges(BRepGraph_EdgeId(edgeIndex));
        return (int32_t)coedges.Size();
    } catch (...) { return 0; }
}

void OCCTBRepGraphEdgeCoEdgeIndices(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        auto& coedges = g->graph.Topo().Edges().CoEdges(BRepGraph_EdgeId(edgeIndex));
        for (size_t i = 0; i < coedges.Size(); ++i) {
            outIndices[i] = (int32_t)coedges.Value(i).Index;
        }
    } catch (...) {}
}

// --- Face Additional Queries ---

int32_t OCCTBRepGraphFaceShellCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        // OCCT 8.0.0p1: FaceOps::Shells() removed; resolve parent shells from the face's parent face refs.
        const auto& rel = g->graph.Topo().Faces().Relations(BRepGraph_FaceId(faceIndex));
        int32_t n = 0;
        for (BRepGraph_ShellsOfFace it(g->graph, rel.ParentFaceRefIds); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

void OCCTBRepGraphFaceShellIndices(OCCTBRepGraphRef g, int32_t faceIndex, int32_t* outIndices) {
    if (!g || !outIndices) return;
    try {
        const auto& rel = g->graph.Topo().Faces().Relations(BRepGraph_FaceId(faceIndex));
        int i = 0;
        for (BRepGraph_ShellsOfFace it(g->graph, rel.ParentFaceRefIds); it.More(); it.Next())
            outIndices[i++] = (int32_t)it.CurrentId().Index;
    } catch (...) {}
}

int32_t OCCTBRepGraphFaceCompoundCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        const auto& refs = g->graph.Topo().Gen().CompoundRefIds(
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Face, faceIndex));
        int32_t n = 0;
        for (BRepGraph_CompoundsOfFace it(g->graph, refs); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

// --- Shell Additional Queries ---

int32_t OCCTBRepGraphShellCompoundCount(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return 0;
    try {
        const auto& refs = g->graph.Topo().Gen().CompoundRefIds(
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Shell, shellIndex));
        int32_t n = 0;
        for (BRepGraph_CompoundsOfShell it(g->graph, refs); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

bool OCCTBRepGraphShellIsClosed(OCCTBRepGraphRef g, int32_t shellIndex) {
    if (!g) return false;
    // OCCT 8.0.0p1: shell closure is derived, not a stored ShellDef flag; query via Tool::Shell.
    try { return BRepGraph_Tool::Shell::IsClosed(g->graph, BRepGraph_ShellId(shellIndex)); }
    catch (...) { return false; }
}

// --- Solid Additional Queries ---

int32_t OCCTBRepGraphSolidCompoundCount(OCCTBRepGraphRef g, int32_t solidIndex) {
    if (!g) return 0;
    try {
        const auto& refs = g->graph.Topo().Gen().CompoundRefIds(
            BRepGraph_NodeId(BRepGraph_NodeId::Kind::Solid, solidIndex));
        int32_t n = 0;
        for (BRepGraph_CompoundsOfSolid it(g->graph, refs); it.More(); it.Next()) ++n;
        return n;
    } catch (...) { return 0; }
}

// --- CompSolid Count ---

int32_t OCCTBRepGraphNbCompSolids(OCCTBRepGraphRef g) {
    if (!g) return 0;
    try { return g->graph.Topo().CompSolids().Nb(); }
    catch (...) { return 0; }
}

// --- Edge FindCoEdge ---

int32_t OCCTBRepGraphEdgeFindCoEdge(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: FindCoEdgeId moved to BRepGraph_Tool::Edge.
        auto cid = BRepGraph_Tool::Edge::FindCoEdgeId(g->graph, BRepGraph_EdgeId(edgeIndex), BRepGraph_FaceId(faceIndex));
        return cid.IsValid() ? (int32_t)cid.Index : -1;
    } catch (...) { return -1; }
}

// end of v0.133.0 implementations

// MARK: - BRepGraph Builder (v0.135.0; migrated to EditorView in v0.157.0 / OCCT 8.0.0 beta1)

#include <BRepGraph_EditorView.hxx>
#include <BRepGraph_Tool.hxx>
#include <BRepGraph_DeferredScope.hxx>

static TopAbs_Orientation oriFromInt(int32_t o) {
    switch (o) {
        case 0: return TopAbs_FORWARD;
        case 1: return TopAbs_REVERSED;
        case 2: return TopAbs_INTERNAL;
        case 3: return TopAbs_EXTERNAL;
        default: return TopAbs_FORWARD;
    }
}

// --- Add Topology Nodes ---

int32_t OCCTBRepGraphBuilderAddVertex(OCCTBRepGraphRef g, double x, double y, double z, double tolerance) {
    if (!g) return -1;
    try {
        auto vid = g->graph.Editor().Vertices().Add(gp_Pnt(x, y, z), tolerance);
        return vid.IsValid() ? vid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddShell(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        auto sid = g->graph.Editor().Shells().Add();
        return sid.IsValid() ? sid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddSolid(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        auto sid = g->graph.Editor().Solids().Add();
        return sid.IsValid() ? sid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddFaceToShell(OCCTBRepGraphRef g, int32_t shellIndex, int32_t faceIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: ShellOps::AddFace renamed to Append.
        auto rid = g->graph.Editor().Shells().Append(
            BRepGraph_ShellId(shellIndex),
            BRepGraph_FaceId(faceIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddShellToSolid(OCCTBRepGraphRef g, int32_t solidIndex, int32_t shellIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: SolidOps::AddShell renamed to Append.
        auto rid = g->graph.Editor().Solids().Append(
            BRepGraph_SolidId(solidIndex),
            BRepGraph_ShellId(shellIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddCompound(OCCTBRepGraphRef g, const int32_t* kinds, const int32_t* indices, int32_t count) {
    if (!g || !kinds || !indices || count <= 0) return -1;
    try {
        // OCCT 8.0.0p1: CompoundOps::Add takes NCollection_Array1 (was DynamicArray).
        NCollection_Array1<BRepGraph_NodeId> children(0, count - 1);
        for (int32_t i = 0; i < count; ++i) {
            children.SetValue(i, BRepGraph_NodeId(kindFromInt(kinds[i]), indices[i]));
        }
        auto cid = g->graph.Editor().Compounds().Add(children);
        return cid.IsValid() ? (int32_t)cid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphBuilderAddCompSolid(OCCTBRepGraphRef g, const int32_t* solidIndices, int32_t count) {
    if (!g || !solidIndices || count <= 0) return -1;
    try {
        // OCCT 8.0.0p1: CompSolidOps::Add takes NCollection_Array1 (was DynamicArray).
        NCollection_Array1<BRepGraph_SolidId> solids(0, count - 1);
        for (int32_t i = 0; i < count; ++i) {
            solids.SetValue(i, BRepGraph_SolidId(solidIndices[i]));
        }
        auto csid = g->graph.Editor().CompSolids().Add(solids);
        return csid.IsValid() ? (int32_t)csid.Index : -1;
    } catch (...) { return -1; }
}

// --- Remove/Modify Nodes ---

void OCCTBRepGraphBuilderRemoveNode(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().RemoveNode(BRepGraph_NodeId(kindFromInt(nodeKind), nodeIndex));
    } catch (...) {}
}

void OCCTBRepGraphBuilderRemoveSubgraph(OCCTBRepGraphRef g, int32_t nodeKind, int32_t nodeIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().RemoveSubgraph(BRepGraph_NodeId(kindFromInt(nodeKind), nodeIndex));
    } catch (...) {}
}

// --- Append Shapes ---
// NOTE: OCCT 8.0.0 beta1 routes the former Builder().AppendFlattenedShape /
// AppendFullShape through the static BRepGraph_Builder::Add(graph, shape, options).
// The Flatten option preserves the pre-beta1 distinction.

void OCCTBRepGraphBuilderAppendFlattenedShape(OCCTBRepGraphRef g, OCCTShapeRef shape, bool parallel) {
    if (!g || !shape) return;
    try {
        BRepGraph::ShapesView::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false;
        opts.Flatten = true;
        (void)g->graph.Shapes().Add(*(const TopoDS_Shape*)shape, opts);
    } catch (...) {}
}

void OCCTBRepGraphBuilderAppendFullShape(OCCTBRepGraphRef g, OCCTShapeRef shape, bool parallel) {
    if (!g || !shape) return;
    try {
        BRepGraph::ShapesView::Options opts;
        opts.Parallel = parallel;
        opts.CreateAutoProduct = false;
        (void)g->graph.Shapes().Add(*(const TopoDS_Shape*)shape, opts);
    } catch (...) {}
}

// --- Deferred Invalidation ---

void OCCTBRepGraphBuilderBeginDeferred(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().BeginDeferredInvalidation(); }
    catch (...) {}
}

void OCCTBRepGraphBuilderEndDeferred(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().EndDeferredInvalidation(); }
    catch (...) {}
}

bool OCCTBRepGraphBuilderIsDeferredMode(OCCTBRepGraphRef g) {
    if (!g) return false;
    try { return g->graph.Editor().IsDeferredMode(); }
    catch (...) { return false; }
}

void OCCTBRepGraphBuilderCommitMutation(OCCTBRepGraphRef g) {
    if (!g) return;
    try { g->graph.Editor().CommitMutation(); }
    catch (...) {}
}

// --- Edge Splitting ---

void OCCTBRepGraphBuilderSplitEdge(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexIndex,
                                    double param, int32_t* outSubA, int32_t* outSubB) {
    if (!g || !outSubA || !outSubB) {
        if (outSubA) *outSubA = -1;
        if (outSubB) *outSubB = -1;
        return;
    }
    try {
        BRepGraph_EdgeId subA, subB;
        g->graph.Editor().Edges().Split(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_VertexId(vertexIndex),
            param, subA, subB);
        *outSubA = subA.IsValid() ? subA.Index : -1;
        *outSubB = subB.IsValid() ? subB.Index : -1;
    } catch (...) {
        *outSubA = -1;
        *outSubB = -1;
    }
}

// --- Replace Edge in Wire ---

void OCCTBRepGraphBuilderReplaceEdgeInWire(OCCTBRepGraphRef g, int32_t wireIndex,
                                            int32_t oldEdgeIndex, int32_t newEdgeIndex,
                                            bool reversed) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().ReplaceEdge(
            BRepGraph_WireId(wireIndex),
            BRepGraph_EdgeId(oldEdgeIndex),
            BRepGraph_EdgeId(newEdgeIndex),
            reversed);
    } catch (...) {}
}

// --- Remove Ref ---

bool OCCTBRepGraphBuilderRemoveRef(OCCTBRepGraphRef g, int32_t refKind, int32_t refIndex) {
    if (!g) return false;
    try {
        BRepGraph_RefId rid(refKindFromInt(refKind), refIndex);
        return g->graph.Editor().Gen().RemoveRef(rid);
    } catch (...) { return false; }
}

// --- Clear Mesh ---
// NOTE: OCCT 8.0.0 beta1 split mesh storage into a cache (algorithm-derived)
// and persistent (STEP-imported) tier. The Builder-era ClearFaceMesh /
// ClearEdgePolygon3D methods now clear only the cache via BRepGraph_Tool::Mesh.

void OCCTBRepGraphBuilderClearFaceMesh(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: cache clear moved to MeshView::Editor (BRepGraph_Tool::Mesh removed).
    try { g->graph.Mesh().Editor().Faces().Clear(BRepGraph_FaceId(faceIndex)); }
    catch (...) {}
}

void OCCTBRepGraphBuilderClearEdgePolygon3D(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return;
    try { g->graph.Mesh().Editor().Edges().Clear(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) {}
}

// --- Validate Mutation Boundary ---

bool OCCTBRepGraphBuilderValidateMutation(OCCTBRepGraphRef g) {
    if (!g) return false;
    try {
        return g->graph.Editor().ValidateMutationBoundary();
    } catch (...) { return false; }
}

// MARK: - BRepGraph EditorView Field Setters (v0.159.0)
//
// Pure-value setters on the per-entity Ops classes of BRepGraph::EditorView.
// All take a typed entity id + scalar/bool argument and return void; on
// invalid id or out-of-range value the underlying call is a no-op.

// VertexOps

void OCCTBRepGraphSetVertexPoint(OCCTBRepGraphRef g, int32_t vertexIndex, double x, double y, double z) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetPoint(BRepGraph_VertexId(vertexIndex), gp_Pnt(x, y, z));
    } catch (...) {}
}

void OCCTBRepGraphSetVertexTolerance(OCCTBRepGraphRef g, int32_t vertexIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetTolerance(BRepGraph_VertexId(vertexIndex), tolerance);
    } catch (...) {}
}

// EdgeOps

void OCCTBRepGraphSetEdgeTolerance(OCCTBRepGraphRef g, int32_t edgeIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetTolerance(BRepGraph_EdgeId(edgeIndex), tolerance);
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeParamRange(OCCTBRepGraphRef g, int32_t edgeIndex, double first, double last) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetParamRange(BRepGraph_EdgeId(edgeIndex), first, last);
    } catch (...) {}
}

// OCCT 8.0.0p1: SameParameter / SameRange are now derived per-CoEdge properties (computed from the
// pcurve vs 3D curve), not settable edge flags — the Edges editor no longer exposes setters. These
// are kept as no-ops for ABI compatibility; the getters report the derived value.
void OCCTBRepGraphSetEdgeSameParameter(OCCTBRepGraphRef, int32_t, bool) {}
void OCCTBRepGraphSetEdgeSameRange(OCCTBRepGraphRef, int32_t, bool) {}

// OCCT 8.0.0p1: edge degeneracy and closure are derived from geometry/topology, no longer
// settable EdgeDef flags — the Edges editor exposes no setters. Kept as no-ops for ABI compat.
void OCCTBRepGraphSetEdgeDegenerate(OCCTBRepGraphRef, int32_t, bool) {}
void OCCTBRepGraphSetEdgeIsClosed(OCCTBRepGraphRef, int32_t, bool) {}

// CoEdgeOps

void OCCTBRepGraphSetCoEdgeParamRange(OCCTBRepGraphRef g, int32_t coedgeIndex, double first, double last) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetParamRange(BRepGraph_CoEdgeId(coedgeIndex), first, last);
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeOrientation(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().CoEdges().SetOrientation(BRepGraph_CoEdgeId(coedgeIndex), oriFromInt(orientation));
    } catch (...) {}
}

// WireOps

// OCCT 8.0.0p1: wire closure is derived from the ordered coedge chain; no settable flag. No-op.
void OCCTBRepGraphSetWireIsClosed(OCCTBRepGraphRef, int32_t, bool) {}

// FaceOps

void OCCTBRepGraphSetFaceTolerance(OCCTBRepGraphRef g, int32_t faceIndex, double tolerance) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetTolerance(BRepGraph_FaceId(faceIndex), tolerance);
    } catch (...) {}
}

// OCCT 8.0.0p1: face "natural restriction" flag is no longer stored/settable. No-op.
void OCCTBRepGraphSetFaceNaturalRestriction(OCCTBRepGraphRef, int32_t, bool) {}

// ShellOps

// OCCT 8.0.0p1: shell closure is derived from face-boundary edge incidence; no settable flag. No-op.
void OCCTBRepGraphSetShellIsClosed(OCCTBRepGraphRef, int32_t, bool) {}

// MARK: - BRepGraph EditorView Add/Remove + Ref Setters (v0.161.0)
//
// Add operations return the typed ref id (or -1 on failure). Remove operations return
// bool indicating whether the active usage was removed. Ref setters are no-ops on
// invalid ids.

// --- Add operations ---

// OCCT 8.0.0p1: edges no longer support adding internal/supplemental vertex usages through the
// public Editor (only boundary start/end vertex refs persist). No equivalent — stubbed.
int32_t OCCTBRepGraphEdgeAddInternalVertex(OCCTBRepGraphRef, int32_t, int32_t, int32_t) { return -1; }

// OCCT 8.0.0p1: faces no longer carry direct vertex usages (FaceRelations has only wires). Stubbed.
int32_t OCCTBRepGraphFaceAddVertex(OCCTBRepGraphRef, int32_t, int32_t, int32_t) { return -1; }

int32_t OCCTBRepGraphShellAddChild(OCCTBRepGraphRef g, int32_t shellIndex,
                                    int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: ShellOps::AddChild removed; shells only own faces (Append takes a FaceId).
        if (kindFromInt(childKind) != BRepGraph_NodeId::Kind::Face) return -1;
        auto rid = g->graph.Editor().Shells().Append(
            BRepGraph_ShellId(shellIndex),
            BRepGraph_FaceId(childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphSolidAddChild(OCCTBRepGraphRef g, int32_t solidIndex,
                                    int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: SolidOps::AddChild removed; solids only own shells (Append takes a ShellId).
        if (kindFromInt(childKind) != BRepGraph_NodeId::Kind::Shell) return -1;
        auto rid = g->graph.Editor().Solids().Append(
            BRepGraph_SolidId(solidIndex),
            BRepGraph_ShellId(childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCompoundAddChild(OCCTBRepGraphRef g, int32_t compoundIndex,
                                       int32_t childKind, int32_t childIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: CompoundOps::AddChild renamed to Append (still takes a NodeId).
        auto rid = g->graph.Editor().Compounds().Append(
            BRepGraph_CompoundId(compoundIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCompSolidAddSolid(OCCTBRepGraphRef g, int32_t compSolidIndex,
                                        int32_t solidIndex, int32_t orientation) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: CompSolidOps::AddSolid renamed to Append.
        auto rid = g->graph.Editor().CompSolids().Append(
            BRepGraph_CompSolidId(compSolidIndex),
            BRepGraph_SolidId(solidIndex),
            oriFromInt(orientation));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

// --- Remove operations ---

bool OCCTBRepGraphEdgeRemoveVertex(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Edges().RemoveVertex(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) { return false; }
}

int32_t OCCTBRepGraphEdgeReplaceVertex(OCCTBRepGraphRef g, int32_t edgeIndex,
                                        int32_t oldVertexRefIndex, int32_t newVertexIndex) {
    if (!g) return -1;
    try {
        auto rid = g->graph.Editor().Edges().ReplaceVertex(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_VertexRefId(oldVertexRefIndex),
            BRepGraph_VertexId(newVertexIndex));
        return rid.IsValid() ? (int32_t)rid.Index : -1;
    } catch (...) { return -1; }
}

bool OCCTBRepGraphWireRemoveCoEdge(OCCTBRepGraphRef g, int32_t wireIndex, int32_t coedgeRefIndex) {
    if (!g) return false;
    try {
        // OCCT 8.0.0p1: RemoveCoEdge now takes the exact CoEdgeId (coedges are not ref-counted).
        return g->graph.Editor().Wires().RemoveCoEdge(
            BRepGraph_WireId(wireIndex), BRepGraph_CoEdgeId(coedgeRefIndex));
    } catch (...) { return false; }
}

// OCCT 8.0.0p1: faces no longer own direct vertex refs (FaceOps::RemoveVertex removed). Stubbed.
bool OCCTBRepGraphFaceRemoveVertex(OCCTBRepGraphRef, int32_t, int32_t) { return false; }

bool OCCTBRepGraphFaceRemoveWire(OCCTBRepGraphRef g, int32_t faceIndex, int32_t wireRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Faces().RemoveWire(
            BRepGraph_FaceId(faceIndex), BRepGraph_WireRefId(wireRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphShellRemoveFace(OCCTBRepGraphRef g, int32_t shellIndex, int32_t faceRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Shells().RemoveFace(
            BRepGraph_ShellId(shellIndex), BRepGraph_FaceRefId(faceRefIndex));
    } catch (...) { return false; }
}

// OCCT 8.0.0p1: ShellOps::RemoveChild removed — shells own only faces, so the legacy "child ref"
// is a face ref. Map onto ShellOps::RemoveFace(shellId, faceRefId).
bool OCCTBRepGraphShellRemoveChild(OCCTBRepGraphRef g, int32_t shellIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Shells().RemoveFace(
            BRepGraph_ShellId(shellIndex), BRepGraph_FaceRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphSolidRemoveShell(OCCTBRepGraphRef g, int32_t solidIndex, int32_t shellRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Solids().RemoveShell(
            BRepGraph_SolidId(solidIndex), BRepGraph_ShellRefId(shellRefIndex));
    } catch (...) { return false; }
}

// OCCT 8.0.0p1: SolidOps::RemoveChild removed — solids own only shells, so the legacy "child ref"
// is a shell ref. Map onto SolidOps::RemoveShell(solidId, shellRefId).
bool OCCTBRepGraphSolidRemoveChild(OCCTBRepGraphRef g, int32_t solidIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Solids().RemoveShell(
            BRepGraph_SolidId(solidIndex), BRepGraph_ShellRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphCompoundRemoveChild(OCCTBRepGraphRef g, int32_t compoundIndex, int32_t childRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Compounds().RemoveChild(
            BRepGraph_CompoundId(compoundIndex), BRepGraph_ChildRefId(childRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphCompSolidRemoveSolid(OCCTBRepGraphRef g, int32_t compSolidIndex, int32_t solidRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().CompSolids().RemoveSolid(
            BRepGraph_CompSolidId(compSolidIndex), BRepGraph_SolidRefId(solidRefIndex));
    } catch (...) { return false; }
}

// OCCT 8.0.0p1: GenOps::RemoveRep removed — representations are owned by their topology defs and
// cleared through the per-kind editors. For the side-registry rep ids we expose, "removing" a rep
// nullifies its registry slot so a later Set*RepId() resolving the same id becomes a safe no-op.
// repKind follows BRepGraphInc_RepId::Kind ordering (0=FaceSurface, 1=FaceTriangulation,
// 2=EdgeCurve3D, 3=EdgePolygon3D, 4=CoEdgeCurve2D, 5=CoEdgePolygon2D, 6=CoEdgePolygonOnTri); any
// out-of-range kind/index is ignored.
void OCCTBRepGraphRemoveRep(OCCTBRepGraphRef g, int32_t repKind, int32_t repIndex) {
    if (!g || repIndex < 0) return;
    auto nullifyAt = [](auto& vec, int32_t idx) {
        if (idx >= 0 && (size_t)idx < vec.size()) vec[idx].Nullify();
    };
    try {
        switch (repKind) {
            case 0: nullifyAt(g->surfReps,      repIndex); break;
            case 1: nullifyAt(g->triReps,       repIndex); break;
            case 2: nullifyAt(g->curve3dReps,   repIndex); break;
            case 3: nullifyAt(g->poly3dReps,    repIndex); break;
            case 4: nullifyAt(g->curve2dReps,   repIndex); break;
            case 5: nullifyAt(g->poly2dReps,    repIndex); break;
            case 6: nullifyAt(g->polyOnTriReps, repIndex); break;
            default: break;
        }
    } catch (...) {}
}

// --- Simple Ref setters (no TopLoc_Location, no Bnd_Box2d) ---

void OCCTBRepGraphSetVertexRefOrientation(OCCTBRepGraphRef g, int32_t vertexRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Vertices().SetRefOrientation(
            BRepGraph_VertexRefId(vertexRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetVertexRefVertexDefId(OCCTBRepGraphRef g, int32_t vertexRefIndex, int32_t vertexIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefVertexDefId renamed to SetRefChildVertexId.
    try {
        g->graph.Editor().Vertices().SetRefChildVertexId(
            BRepGraph_VertexRefId(vertexRefIndex), BRepGraph_VertexId(vertexIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeStartVertexRefId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetStartVertexRefId(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetEdgeEndVertexRefId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t vertexRefIndex) {
    if (!g) return;
    try {
        g->graph.Editor().Edges().SetEndVertexRefId(
            BRepGraph_EdgeId(edgeIndex), BRepGraph_VertexRefId(vertexRefIndex));
    } catch (...) {}
}

// OCCT 8.0.0p1: edge geometry rep-ids are gone; p1 takes handles directly. We resolve the legacy
// rep id through the side-registry and call the handle-based setter (SetCurve / SetPersistentPolygon3D).
void OCCTBRepGraphSetEdgeCurve3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t curve3DRepId) {
    if (!g || curve3DRepId < 0 || (size_t)curve3DRepId >= g->curve3dReps.size()) return;
    try {
        const Handle(Geom_Curve)& c = g->curve3dReps[curve3DRepId];
        if (c.IsNull()) return;
        double f = c->FirstParameter(), l = c->LastParameter();
        g->graph.Editor().Edges().SetCurve(BRepGraph_EdgeId(edgeIndex), c, f, l);
    } catch (...) {}
}
void OCCTBRepGraphSetEdgePolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t polygon3DRepId) {
    if (!g || polygon3DRepId < 0 || (size_t)polygon3DRepId >= g->poly3dReps.size()) return;
    try {
        g->graph.Editor().Edges().SetPersistentPolygon3D(
            BRepGraph_EdgeId(edgeIndex), g->poly3dReps[polygon3DRepId]);
    } catch (...) {}
}

// OCCT 8.0.0p1: coedges are not reference-counted (no CoEdgeRefId / SetRefCoEdgeDefId). No-op.
void OCCTBRepGraphSetCoEdgeRefCoEdgeDefId(OCCTBRepGraphRef, int32_t, int32_t) {}

void OCCTBRepGraphSetCoEdgeEdgeDefId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t edgeIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetEdgeDefId renamed to SetChildEdgeId.
    try {
        g->graph.Editor().CoEdges().SetChildEdgeId(
            BRepGraph_CoEdgeId(coedgeIndex), BRepGraph_EdgeId(edgeIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetCoEdgeFaceDefId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t faceIndex) {
    if (!g) return;
    try {
        // OCCT 8.0.0p1: SetFaceDefId renamed to SetFaceId.
        g->graph.Editor().CoEdges().SetFaceId(
            BRepGraph_CoEdgeId(coedgeIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) {}
}

// OCCT 8.0.0p1: coedge geometry rep-ids are gone; p1 takes handles directly. We resolve the legacy
// rep id through the side-registry and call the handle-based setter.
void OCCTBRepGraphSetCoEdgeCurve2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t curve2DRepId) {
    if (!g || curve2DRepId < 0 || (size_t)curve2DRepId >= g->curve2dReps.size()) return;
    try {
        g->graph.Editor().CoEdges().SetPCurve(BRepGraph_CoEdgeId(coedgeIndex), g->curve2dReps[curve2DRepId]);
    } catch (...) {}
}
void OCCTBRepGraphSetCoEdgePolygon2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polygon2DRepId) {
    if (!g || polygon2DRepId < 0 || (size_t)polygon2DRepId >= g->poly2dReps.size()) return;
    try {
        g->graph.Editor().CoEdges().SetPersistentPolygon2D(
            BRepGraph_CoEdgeId(coedgeIndex), g->poly2dReps[polygon2DRepId]);
    } catch (...) {}
}
void OCCTBRepGraphSetCoEdgePolygonOnTriRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t polygonOnTriRepId) {
    if (!g || polygonOnTriRepId < 0 || (size_t)polygonOnTriRepId >= g->polyOnTriReps.size()) return;
    try {
        g->graph.Editor().CoEdges().SetPersistentPolygonOnTri(
            BRepGraph_CoEdgeId(coedgeIndex), g->polyOnTriReps[polygonOnTriRepId]);
    } catch (...) {}
}

void OCCTBRepGraphClearCoEdgePCurveBinding(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: ClearPCurveBinding renamed to ClearPCurve.
    try { g->graph.Editor().CoEdges().ClearPCurve(BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) {}
}

// OCCT 8.0.0p1: a wire reference's "is outer" flag is no longer settable (outer-wire is derived as
// the first active wire of the owning face). No-op.
void OCCTBRepGraphSetWireRefIsOuter(OCCTBRepGraphRef, int32_t, bool) {}

void OCCTBRepGraphSetWireRefOrientation(OCCTBRepGraphRef g, int32_t wireRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Wires().SetRefOrientation(
            BRepGraph_WireRefId(wireRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetWireRefWireDefId(OCCTBRepGraphRef g, int32_t wireRefIndex, int32_t wireIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefWireDefId renamed to SetRefChildWireId.
    try {
        g->graph.Editor().Wires().SetRefChildWireId(
            BRepGraph_WireRefId(wireRefIndex), BRepGraph_WireId(wireIndex));
    } catch (...) {}
}

// OCCT 8.0.0p1: face surface is gone-by-rep-id; resolve the legacy rep id through the side-registry
// and call the handle-based FaceOps::SetSurface().
void OCCTBRepGraphSetFaceSurfaceRepId(OCCTBRepGraphRef g, int32_t faceIndex, int32_t surfaceRepId) {
    if (!g || surfaceRepId < 0 || (size_t)surfaceRepId >= g->surfReps.size()) return;
    try {
        const Handle(Geom_Surface)& s = g->surfReps[surfaceRepId];
        if (s.IsNull()) return;
        g->graph.Editor().Faces().SetSurface(BRepGraph_FaceId(faceIndex), s);
    } catch (...) {}
}

void OCCTBRepGraphSetFaceRefOrientation(OCCTBRepGraphRef g, int32_t faceRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Faces().SetRefOrientation(
            BRepGraph_FaceRefId(faceRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetFaceRefFaceDefId(OCCTBRepGraphRef g, int32_t faceRefIndex, int32_t faceIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefFaceDefId renamed to SetRefFaceId.
    try {
        g->graph.Editor().Faces().SetRefFaceId(
            BRepGraph_FaceRefId(faceRefIndex), BRepGraph_FaceId(faceIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetShellRefOrientation(OCCTBRepGraphRef g, int32_t shellRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Shells().SetRefOrientation(
            BRepGraph_ShellRefId(shellRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetShellRefShellDefId(OCCTBRepGraphRef g, int32_t shellRefIndex, int32_t shellIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefShellDefId renamed to SetRefChildShellId.
    try {
        g->graph.Editor().Shells().SetRefChildShellId(
            BRepGraph_ShellRefId(shellRefIndex), BRepGraph_ShellId(shellIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetSolidRefOrientation(OCCTBRepGraphRef g, int32_t solidRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Solids().SetRefOrientation(
            BRepGraph_SolidRefId(solidRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetSolidRefSolidDefId(OCCTBRepGraphRef g, int32_t solidRefIndex, int32_t solidIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefSolidDefId renamed to SetRefChildSolidId.
    try {
        g->graph.Editor().Solids().SetRefChildSolidId(
            BRepGraph_SolidRefId(solidRefIndex), BRepGraph_SolidId(solidIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetOccurrenceChildDefId(OCCTBRepGraphRef g, int32_t occurrenceIndex,
                                            int32_t childKind, int32_t childIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetChildDefId renamed to SetChildNodeId.
    try {
        g->graph.Editor().Occurrences().SetChildNodeId(
            BRepGraph_OccurrenceId(occurrenceIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetOccurrenceRefOccurrenceDefId(OCCTBRepGraphRef g, int32_t occurrenceRefIndex,
                                                    int32_t occurrenceIndex) {
    if (!g) return;
    // OCCT 8.0.0p1: SetRefOccurrenceDefId renamed to SetRefChildOccurrenceId.
    try {
        g->graph.Editor().Occurrences().SetRefChildOccurrenceId(
            BRepGraph_OccurrenceRefId(occurrenceRefIndex),
            BRepGraph_OccurrenceId(occurrenceIndex));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefOrientation(OCCTBRepGraphRef g, int32_t childRefIndex, int32_t orientation) {
    if (!g) return;
    try {
        g->graph.Editor().Gen().SetChildRefOrientation(
            BRepGraph_ChildRefId(childRefIndex), oriFromInt(orientation));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefChildDefId(OCCTBRepGraphRef g, int32_t childRefIndex,
                                          int32_t childKind, int32_t childIndex) {
    if (!g) return;
    try {
        // OCCT 8.0.0p1: SetChildRefChildDefId renamed to SetChildRefChildNodeId.
        g->graph.Editor().Gen().SetChildRefChildNodeId(
            BRepGraph_ChildRefId(childRefIndex),
            BRepGraph_NodeId(kindFromInt(childKind), childIndex));
    } catch (...) {}
}

// MARK: - BRepGraph EditorView v0.162.0 — geometric setters, location setters, PCurve API

// CoEdge geometric setters

// OCCT 8.0.0p1: per-coedge UV bounding box is no longer a settable definition field
// (UV endpoints are derived from the PCurve via BRepGraph_Tool::CoEdge::UVPoints). No-op.
void OCCTBRepGraphSetCoEdgeUVBox(OCCTBRepGraphRef, int32_t, double, double, double, double) {}

// OCCT 8.0.0p1: EdgeOps::SetRegularity was removed — edge continuity across an (edge, face1, face2)
// is no longer a settable field (continuity is derived). No public equivalent; report failure.
int32_t OCCTBRepGraphSetEdgeRegularity(OCCTBRepGraphRef, int32_t, int32_t, int32_t, int32_t) {
    // continuityFromInt() is otherwise unused now; keep it referenced to avoid an unused-static warning.
    (void)&continuityFromInt;
    return 0;
}

// Face triangulation rep binding
// OCCT 8.0.0p1: triangulation is bound by handle. Resolve the legacy rep id via the side-registry
// and write it to the face's mesh cache (SetCachedTriangulation), which is what
// meshFaceActiveTriangulationRepId() reads back.
void OCCTBRepGraphSetFaceTriangulationRep(OCCTBRepGraphRef g, int32_t faceIndex, int32_t triRepId) {
    if (!g || triRepId < 0 || (size_t)triRepId >= g->triReps.size()) return;
    try {
        g->graph.Mesh().Editor().Faces().SetCachedTriangulation(
            BRepGraph_FaceId(faceIndex), g->triReps[triRepId]);
    } catch (...) {}
}

// CoEdge PCurve operations (Geom2d_Curve handle from OCCTCurve2D opaque)

// OCCT 8.0.0p1: standalone Curve2D rep creation (returning a RepId) was removed. We preserve the
// int-rep-id ABI by stashing the curve handle in the side-registry; SetCoEdgeCurve2DRepId() resolves
// it back and calls CoEdges().SetPCurve() (handle-based).
int32_t OCCTBRepGraphCoEdgeCreateCurve2DRep(OCCTBRepGraphRef g, OCCTCurve2DRef curve2d) {
    if (!g || !curve2d) return -1;
    try {
        const Handle(Geom2d_Curve)& h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        if (h.IsNull()) return -1;
        g->curve2dReps.push_back(h);
        return (int32_t)(g->curve2dReps.size() - 1);
    } catch (...) { return -1; }
}

void OCCTBRepGraphCoEdgeSetPCurve(OCCTBRepGraphRef g, int32_t coedgeIndex, OCCTCurve2DRef curve2d) {
    if (!g) return;
    try {
        Handle(Geom2d_Curve) h;
        if (curve2d) h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        g->graph.Editor().CoEdges().SetPCurve(BRepGraph_CoEdgeId(coedgeIndex), h);
    } catch (...) {}
}

void OCCTBRepGraphCoEdgeAddPCurve(OCCTBRepGraphRef g, int32_t edgeIndex, int32_t faceIndex,
                                    OCCTCurve2DRef curve2d, double first, double last,
                                    int32_t orientation) {
    if (!g || !curve2d) return;
    try {
        const Handle(Geom2d_Curve)& h = reinterpret_cast<OCCTCurve2D*>(curve2d)->curve;
        if (h.IsNull()) return;
        // OCCT 8.0.0p1: AddPCurve(edge, face, curve, ...) folded into CoEdges().Add(...) which
        // creates a coedge carrying the PCurve for the edge-face pair.
        (void)g->graph.Editor().CoEdges().Add(
            BRepGraph_EdgeId(edgeIndex),
            BRepGraph_FaceId(faceIndex),
            h, first, last, oriFromInt(orientation));
    } catch (...) {}
}

// Location setters (12-double 3x4 matrix, gp_Trsf::SetValues convention)

static TopLoc_Location locationFromMatrix(const double m[12]) {
    gp_Trsf trsf;
    trsf.SetValues(
        m[0], m[1], m[2],  m[3],
        m[4], m[5], m[6],  m[7],
        m[8], m[9], m[10], m[11]);
    return TopLoc_Location(trsf);
}

// OCCT 8.0.0p1: only occurrence and child references carry a local location; the per-topology
// references (vertex/coedge/wire/face/shell/solid) no longer store a location, so their editors
// expose no SetRefLocalLocation. These are no-ops for ABI compatibility. (CoEdge refs were removed
// entirely — coedges are not reference-counted.)
void OCCTBRepGraphSetVertexRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}
void OCCTBRepGraphSetCoEdgeRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}
void OCCTBRepGraphSetWireRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}
void OCCTBRepGraphSetFaceRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}
void OCCTBRepGraphSetShellRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}
void OCCTBRepGraphSetSolidRefLocalLocation(OCCTBRepGraphRef, int32_t, const double*) {}

void OCCTBRepGraphSetOccurrenceRefLocalLocation(OCCTBRepGraphRef g, int32_t occurrenceRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Occurrences().SetRefLocalLocation(
            BRepGraph_OccurrenceRefId(occurrenceRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

void OCCTBRepGraphSetChildRefLocalLocation(OCCTBRepGraphRef g, int32_t childRefIndex, const double* matrix) {
    if (!g || !matrix) return;
    try {
        g->graph.Editor().Gen().SetChildRefLocalLocation(
            BRepGraph_ChildRefId(childRefIndex), locationFromMatrix(matrix));
    } catch (...) {}
}

// MARK: - BRepGraph EditorView v0.163.0 — ProductOps assembly building

int32_t OCCTBRepGraphLinkProductToTopology(OCCTBRepGraphRef g,
                                             int32_t shapeRootKind, int32_t shapeRootIndex,
                                             const double* placementMatrix) {
    if (!g) return -1;
    try {
        TopLoc_Location loc = placementMatrix ? locationFromMatrix(placementMatrix) : TopLoc_Location();
        BRepGraph_NodeId root(kindFromInt(shapeRootKind), shapeRootIndex);
        // OCCT 8.0.0p1: LinkProductToTopology folded into ProductOps::Add(root, placement). Add() does
        // NOT register the product as a graph root, so call AppendDocumentRoot() to expose it via
        // RootProductIds() (what OCCTBRepGraphRootNodes iterates).
        auto pid = g->graph.Editor().Products().Add(root, loc);
        if (pid.IsValid()) g->graph.Editor().Products().AppendDocumentRoot(pid);
        return pid.IsValid() ? (int32_t)pid.Index : -1;
    } catch (...) { return -1; }
}

int32_t OCCTBRepGraphCreateEmptyProduct(OCCTBRepGraphRef g) {
    if (!g) return -1;
    try {
        // OCCT 8.0.0p1: CreateEmptyProduct folded into the no-arg ProductOps::Add().
        auto pid = g->graph.Editor().Products().Add();
        return pid.IsValid() ? (int32_t)pid.Index : -1;
    } catch (...) { return -1; }
}

/// Returns occurrence id, or -1 on failure. Outputs the new occurrence ref id via outOccRefId.
int32_t OCCTBRepGraphLinkProducts(OCCTBRepGraphRef g, int32_t parentProductIndex,
                                    int32_t referencedProductIndex,
                                    const double* placementMatrix,
                                    int32_t parentOccurrenceIndex,
                                    int32_t* outOccurrenceRefId) {
    if (!g || !placementMatrix) return -1;
    try {
        TopLoc_Location loc = locationFromMatrix(placementMatrix);
        BRepGraph_OccurrenceId parentOcc =
            (parentOccurrenceIndex >= 0)
                ? BRepGraph_OccurrenceId(parentOccurrenceIndex)
                : BRepGraph_OccurrenceId();
        BRepGraph_OccurrenceRefId outRefId;
        // OCCT 8.0.0p1: LinkProducts renamed to ProductOps::Append.
        auto oid = g->graph.Editor().Products().Append(
            BRepGraph_ProductId(parentProductIndex),
            BRepGraph_ProductId(referencedProductIndex),
            loc, parentOcc, &outRefId);
        if (outOccurrenceRefId) *outOccurrenceRefId = outRefId.IsValid() ? (int32_t)outRefId.Index : -1;
        return oid.IsValid() ? (int32_t)oid.Index : -1;
    } catch (...) {
        if (outOccurrenceRefId) *outOccurrenceRefId = -1;
        return -1;
    }
}

bool OCCTBRepGraphProductRemoveOccurrence(OCCTBRepGraphRef g, int32_t productIndex, int32_t occurrenceRefIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Products().RemoveOccurrence(
            BRepGraph_ProductId(productIndex), BRepGraph_OccurrenceRefId(occurrenceRefIndex));
    } catch (...) { return false; }
}

bool OCCTBRepGraphProductRemoveShapeRoot(OCCTBRepGraphRef g, int32_t productIndex) {
    if (!g) return false;
    try {
        return g->graph.Editor().Products().RemoveShapeRoot(BRepGraph_ProductId(productIndex));
    } catch (...) { return false; }
}

// MARK: - BRepGraph EditorView v0.164.0 — RepOps non-guard setters

#include <Geom_Surface.hxx>
#include <Geom_Curve.hxx>
#include <Geom2d_Curve.hxx>

// OCCT 8.0.0p1: EditorView::Reps() (the standalone representation editor addressed by RepId) was
// removed. p1 attaches representation handles directly to topology defs via the per-kind editors,
// with no public RepId slot to overwrite. We preserve the RepId-keyed ABI through the side-registry:
// RepSet* overwrites the handle stored in the registry slot identified by the legacy rep id (the slot
// the matching Create*Rep() returned). A later Set*RepId() then resolves the updated handle. Setting
// a null/invalid input ref nullifies the slot.
void OCCTBRepGraphRepSetSurface(OCCTBRepGraphRef g, int32_t surfaceRepId, OCCTSurfaceRef surface) {
    if (!g || surfaceRepId < 0 || (size_t)surfaceRepId >= g->surfReps.size()) return;
    g->surfReps[surfaceRepId] = surface ? reinterpret_cast<OCCTSurface*>(surface)->surface : Handle(Geom_Surface)();
}
void OCCTBRepGraphRepSetCurve3D(OCCTBRepGraphRef g, int32_t curve3DRepId, OCCTCurve3DRef curve) {
    if (!g || curve3DRepId < 0 || (size_t)curve3DRepId >= g->curve3dReps.size()) return;
    g->curve3dReps[curve3DRepId] = curve ? reinterpret_cast<OCCTCurve3D*>(curve)->curve : Handle(Geom_Curve)();
}
void OCCTBRepGraphRepSetCurve2D(OCCTBRepGraphRef g, int32_t curve2DRepId, OCCTCurve2DRef curve) {
    if (!g || curve2DRepId < 0 || (size_t)curve2DRepId >= g->curve2dReps.size()) return;
    g->curve2dReps[curve2DRepId] = curve ? reinterpret_cast<OCCTCurve2D*>(curve)->curve : Handle(Geom2d_Curve)();
}
void OCCTBRepGraphRepSetTriangulation(OCCTBRepGraphRef g, int32_t triRepId, OCCTPolyTriangulationRef tri) {
    if (!g || triRepId < 0 || (size_t)triRepId >= g->triReps.size()) return;
    g->triReps[triRepId] = tri ? reinterpret_cast<Poly_TriangulationOpaque*>(tri)->triangulation : Handle(Poly_Triangulation)();
}
void OCCTBRepGraphRepSetPolygon3D(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygon3DRef poly) {
    if (!g || polyRepId < 0 || (size_t)polyRepId >= g->poly3dReps.size()) return;
    g->poly3dReps[polyRepId] = poly ? reinterpret_cast<Poly_Polygon3DOpaque*>(poly)->polygon : Handle(Poly_Polygon3D)();
}
void OCCTBRepGraphRepSetPolygon2D(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygon2DRef poly) {
    if (!g || polyRepId < 0 || (size_t)polyRepId >= g->poly2dReps.size()) return;
    g->poly2dReps[polyRepId] = poly ? reinterpret_cast<Poly_Polygon2DOpaque*>(poly)->polygon : Handle(Poly_Polygon2D)();
}
void OCCTBRepGraphRepSetPolygonOnTri(OCCTBRepGraphRef g, int32_t polyRepId, OCCTPolyPolygonOnTriRef poly) {
    if (!g || polyRepId < 0 || (size_t)polyRepId >= g->polyOnTriReps.size()) return;
    g->polyOnTriReps[polyRepId] = poly ? reinterpret_cast<Poly_PolygonOnTriangulationOpaque*>(poly)->polygon : Handle(Poly_PolygonOnTriangulation)();
}
// OCCT 8.0.0p1: a polygon-on-tri's owning triangulation is resolved at attach time
// (CoEdgeDef.FaceId -> FaceDef triangulation), not stored as a rep-id link on the polygon rep.
// There is no slot to rebind by id; no-op for ABI compatibility.
void OCCTBRepGraphRepSetPolygonOnTriTriangulationId(OCCTBRepGraphRef, int32_t, int32_t) {}

// MARK: - BRepGraph MeshView v0.164.0 — cache entry inspection

// OCCT 8.0.0p1 restructured the mesh cache into Cache()/Persistent()/Effective() sub-views. Each
// cache entry now holds a SINGLE handle (no rep-id list, no per-face active index): see
// BRepGraph_CacheMesh::{Face,Edge,CoEdge}MeshEntry. These read-only introspection functions are
// rewrapped onto Cache().{Faces,Edges,CoEdges}().Has()/Entry():
//   - IsPresent       -> Has() (entry exists & is fresh).
//   - StoredOwnGen    -> the entry's generation field (FaceMeshEntry::MeshGeneration,
//                        EdgeMeshEntry::Stamp.SlotGeneration, CoEdgeMeshEntry::FaceMeshGeneration).
//   - *RepCount       -> 1 if present, else 0 (single-handle model; the rep-id LIST is gone).
//   - ActiveIndex     -> 0 if present, else -1 (single handle is always index 0).
//   - *RepId          -> 0 if present, else -1 (present-sentinel; there are no rep ids in p1).

bool OCCTBRepGraphCachedFaceMeshIsPresent(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return false;
    try { return g->graph.Mesh().Cache().Faces().Has(BRepGraph_FaceId(faceIndex)); }
    catch (...) { return false; }
}
int32_t OCCTBRepGraphCachedFaceMeshTriRepCount(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try { return g->graph.Mesh().Cache().Faces().Has(BRepGraph_FaceId(faceIndex)) ? 1 : 0; }
    catch (...) { return 0; }
}
int32_t OCCTBRepGraphCachedFaceMeshActiveIndex(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return -1;
    try { return g->graph.Mesh().Cache().Faces().Has(BRepGraph_FaceId(faceIndex)) ? 0 : -1; }
    catch (...) { return -1; }
}
uint32_t OCCTBRepGraphCachedFaceMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t faceIndex) {
    if (!g) return 0;
    try {
        const auto* e = g->graph.Mesh().Cache().Faces().Entry(BRepGraph_FaceId(faceIndex));
        return e ? e->MeshGeneration : 0;
    } catch (...) { return 0; }
}
// OCCT 8.0.0p1: a present-sentinel — the cache holds one triangulation handle, no rep ids.
int32_t OCCTBRepGraphCachedFaceMeshTriRepId(OCCTBRepGraphRef g, int32_t faceIndex, int32_t repIndex) {
    if (!g || repIndex != 0) return -1;
    try { return g->graph.Mesh().Cache().Faces().Has(BRepGraph_FaceId(faceIndex)) ? 0 : -1; }
    catch (...) { return -1; }
}

bool OCCTBRepGraphCachedEdgeMeshIsPresent(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return false;
    try { return g->graph.Mesh().Cache().Edges().Has(BRepGraph_EdgeId(edgeIndex)); }
    catch (...) { return false; }
}
// OCCT 8.0.0p1: a present-sentinel — the cache holds one Polygon3D handle, no rep id.
int32_t OCCTBRepGraphCachedEdgeMeshPolygon3DRepId(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return -1;
    try { return g->graph.Mesh().Cache().Edges().Has(BRepGraph_EdgeId(edgeIndex)) ? 0 : -1; }
    catch (...) { return -1; }
}
uint32_t OCCTBRepGraphCachedEdgeMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t edgeIndex) {
    if (!g) return 0;
    try {
        const auto* e = g->graph.Mesh().Cache().Edges().Entry(BRepGraph_EdgeId(edgeIndex));
        return e ? e->Stamp.SlotGeneration : 0;
    } catch (...) { return 0; }
}

bool OCCTBRepGraphCachedCoEdgeMeshIsPresent(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return false;
    try { return g->graph.Mesh().Cache().CoEdges().Has(BRepGraph_CoEdgeId(coedgeIndex)); }
    catch (...) { return false; }
}
// OCCT 8.0.0p1: present-sentinel keyed on whether a fresh Polygon2D is bound to the coedge.
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return -1;
    try {
        const auto* e = g->graph.Mesh().Cache().CoEdges().FindPolygon2D(BRepGraph_CoEdgeId(coedgeIndex));
        return (e && !e->Polygon2D.IsNull()) ? 0 : -1;
    } catch (...) { return -1; }
}
// OCCT 8.0.0p1: the coedge cache holds a list of polygons-on-triangulation (PolygonsOnTri); report
// its size as the rep count (this is the one place the single-handle model does NOT apply).
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return 0;
    try {
        const auto* e = g->graph.Mesh().Cache().CoEdges().FindPolygonOnTri(BRepGraph_CoEdgeId(coedgeIndex));
        return e ? (int32_t)e->PolygonsOnTri.Size() : 0;
    } catch (...) { return 0; }
}
// OCCT 8.0.0p1: present-sentinel — 0 when the requested list slot exists, -1 otherwise (no rep ids).
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId(OCCTBRepGraphRef g, int32_t coedgeIndex, int32_t repIndex) {
    if (!g || repIndex < 0) return -1;
    try {
        const auto* e = g->graph.Mesh().Cache().CoEdges().FindPolygonOnTri(BRepGraph_CoEdgeId(coedgeIndex));
        return (e && repIndex < (int32_t)e->PolygonsOnTri.Size()) ? 0 : -1;
    } catch (...) { return -1; }
}
uint32_t OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen(OCCTBRepGraphRef g, int32_t coedgeIndex) {
    if (!g) return 0;
    try {
        const auto* e = g->graph.Mesh().Cache().CoEdges().FindRaw(BRepGraph_CoEdgeId(coedgeIndex));
        return e ? e->FaceMeshGeneration : 0;
    } catch (...) { return 0; }
}

// MARK: - BRepGraph ML Export & Sampling (v0.136.0)

#include <BRepTools.hxx>
#include <GeomLProp_SLProps.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <Precision.hxx>

int32_t OCCTBRepGraphSampleFaceUVGrid(OCCTBRepGraphRef g, int32_t faceIndex,
    int32_t uSamples, int32_t vSamples,
    double* outPositions, double* outNormals,
    double* outGaussianCurvatures, double* outMeanCurvatures)
{
    if (!g || uSamples < 1 || vSamples < 1) return 0;
    try {
        // Reconstruct the face shape to get proper UV bounds (trimmed by wires)
        BRepGraph_NodeId nid(BRepGraph_NodeId::Kind::Face, faceIndex);
        TopoDS_Shape faceShape = g->graph.Shapes().Shape(nid);
        if (faceShape.IsNull()) return 0;
        const TopoDS_Face& face = TopoDS::Face(faceShape);

        double uMin, uMax, vMin, vMax;
        BRepTools::UVBounds(face, uMin, uMax, vMin, vMax);

        // Get the surface
        auto& surfHandle = BRepGraph_Tool::Face::Surface(g->graph, BRepGraph_FaceId(faceIndex));
        if (surfHandle.IsNull()) return 0;

        int32_t count = uSamples * vSamples;
        double uStep = (uSamples > 1) ? (uMax - uMin) / (uSamples - 1) : 0.0;
        double vStep = (vSamples > 1) ? (vMax - vMin) / (vSamples - 1) : 0.0;

        for (int32_t iv = 0; iv < vSamples; ++iv) {
            double v = vMin + iv * vStep;
            for (int32_t iu = 0; iu < uSamples; ++iu) {
                double u = uMin + iu * uStep;
                int32_t idx = iv * uSamples + iu;

                GeomLProp_SLProps props(surfHandle, u, v, 2, Precision::Confusion());

                // Position
                gp_Pnt pnt = props.Value();
                outPositions[idx * 3 + 0] = pnt.X();
                outPositions[idx * 3 + 1] = pnt.Y();
                outPositions[idx * 3 + 2] = pnt.Z();

                // Normal
                if (props.IsNormalDefined()) {
                    gp_Dir nrm = props.Normal();
                    outNormals[idx * 3 + 0] = nrm.X();
                    outNormals[idx * 3 + 1] = nrm.Y();
                    outNormals[idx * 3 + 2] = nrm.Z();
                } else {
                    outNormals[idx * 3 + 0] = 0.0;
                    outNormals[idx * 3 + 1] = 0.0;
                    outNormals[idx * 3 + 2] = 0.0;
                }

                // Curvatures
                if (props.IsCurvatureDefined()) {
                    outGaussianCurvatures[idx] = props.GaussianCurvature();
                    outMeanCurvatures[idx] = props.MeanCurvature();
                } else {
                    outGaussianCurvatures[idx] = 0.0;
                    outMeanCurvatures[idx] = 0.0;
                }
            }
        }
        return count;
    } catch (...) { return 0; }
}

int32_t OCCTBRepGraphSampleEdgeCurve(OCCTBRepGraphRef g, int32_t edgeIndex,
    int32_t count, double* outPoints)
{
    if (!g || count < 1) return 0;
    try {
        if (!BRepGraph_Tool::Edge::HasCurve(g->graph, BRepGraph_EdgeId(edgeIndex)))
            return 0;

        auto& curveHandle = BRepGraph_Tool::Edge::Curve(g->graph, BRepGraph_EdgeId(edgeIndex));
        if (curveHandle.IsNull()) return 0;

        auto range = BRepGraph_Tool::Edge::Range(g->graph, BRepGraph_EdgeId(edgeIndex));
        double first = range.first;
        double last = range.second;
        double step = (count > 1) ? (last - first) / (count - 1) : 0.0;

        for (int32_t i = 0; i < count; ++i) {
            double t = first + i * step;
            gp_Pnt pnt = curveHandle->Value(t);
            outPoints[i * 3 + 0] = pnt.X();
            outPoints[i * 3 + 1] = pnt.Y();
            outPoints[i * 3 + 2] = pnt.Z();
        }
        return count;
    } catch (...) { return 0; }
}
// MARK: - AAG Support Implementation

#include <TopExp_Explorer.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRep_Tool.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopExp.hxx>
#include <TopTools_ListOfShape.hxx>
// TopTools_ListIteratorOfListOfShape.hxx removed in OCCT 8.0

int32_t OCCTEdgeGetAdjacentFaces(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef* outFace1, OCCTFaceRef* outFace2) {
    if (!shape || !edge || !outFace1 || !outFace2) return 0;
    
    *outFace1 = nullptr;
    *outFace2 = nullptr;
    
    try {
        // Build edge-to-face map
        TopTools_IndexedDataMapOfShapeListOfShape edgeFaceMap;
        TopExp::MapShapesAndAncestors(shape->shape, TopAbs_EDGE, TopAbs_FACE, edgeFaceMap);
        
        // Find faces for this edge
        if (!edgeFaceMap.Contains(edge->edge)) {
            return 0;
        }
        
        const TopTools_ListOfShape& faces = edgeFaceMap.FindFromKey(edge->edge);
        int32_t count = 0;
        
        TopTools_ListOfShape::Iterator it(faces);
        for (; it.More() && count < 2; it.Next()) {
            TopoDS_Face face = TopoDS::Face(it.Value());
            if (count == 0) {
                *outFace1 = new OCCTFace(face);
            } else {
                *outFace2 = new OCCTFace(face);
            }
            count++;
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

OCCTEdgeConvexity OCCTEdgeGetConvexity(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2) {
    if (!shape || !edge || !face1 || !face2) return OCCTEdgeConvexitySmooth;
    
    try {
        // Get the edge curve and midpoint
        BRepAdaptor_Curve edgeCurve(edge->edge);
        double midParam = (edgeCurve.FirstParameter() + edgeCurve.LastParameter()) / 2.0;
        gp_Pnt midPt = edgeCurve.Value(midParam);
        
        // Get surface adapters
        BRepAdaptor_Surface surf1(face1->face);
        BRepAdaptor_Surface surf2(face2->face);
        
        // Project point onto surfaces to get UV parameters
        Standard_Real u1, v1, u2, v2;
        
        // Use edge parameters on face - find the PCurve
        Standard_Real f, l;
        Handle(Geom2d_Curve) pcurve1 = BRep_Tool::CurveOnSurface(edge->edge, face1->face, f, l);
        Handle(Geom2d_Curve) pcurve2 = BRep_Tool::CurveOnSurface(edge->edge, face2->face, f, l);
        
        if (pcurve1.IsNull() || pcurve2.IsNull()) {
            return OCCTEdgeConvexitySmooth;
        }
        
        // Get UV at midpoint
        gp_Pnt2d uv1 = pcurve1->Value(midParam);
        gp_Pnt2d uv2 = pcurve2->Value(midParam);
        
        u1 = uv1.X(); v1 = uv1.Y();
        u2 = uv2.X(); v2 = uv2.Y();
        
        // Get normals at those points
        gp_Pnt p1, p2;
        gp_Vec d1u, d1v, d2u, d2v;
        surf1.D1(u1, v1, p1, d1u, d1v);
        surf2.D1(u2, v2, p2, d2u, d2v);
        
        gp_Vec n1 = d1u.Crossed(d1v);
        gp_Vec n2 = d2u.Crossed(d2v);
        
        if (n1.Magnitude() < 1e-10 || n2.Magnitude() < 1e-10) {
            return OCCTEdgeConvexitySmooth;
        }
        
        n1.Normalize();
        n2.Normalize();
        
        // Account for face orientation
        if (face1->face.Orientation() == TopAbs_REVERSED) {
            n1.Reverse();
        }
        if (face2->face.Orientation() == TopAbs_REVERSED) {
            n2.Reverse();
        }
        
        // Get edge tangent at midpoint
        gp_Vec tangent;
        gp_Pnt unused;
        edgeCurve.D1(midParam, unused, tangent);
        
        if (tangent.Magnitude() < 1e-10) {
            return OCCTEdgeConvexitySmooth;
        }
        tangent.Normalize();
        
        // Determine convexity:
        // Cross product of tangent with n1 gives direction "into" face1
        // If n2 points in same direction as this cross product, edge is concave
        gp_Vec intoFace1 = tangent.Crossed(n1);
        
        double dot = intoFace1.Dot(n2);
        
        // Threshold for smooth (nearly tangent)
        const double smoothThreshold = 0.01;  // ~0.5 degrees
        
        if (std::abs(dot) < smoothThreshold) {
            return OCCTEdgeConvexitySmooth;
        } else if (dot > 0) {
            return OCCTEdgeConvexityConcave;
        } else {
            return OCCTEdgeConvexityConvex;
        }
    } catch (...) {
        return OCCTEdgeConvexitySmooth;
    }
}

int32_t OCCTFaceGetSharedEdges(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges) {
    if (!shape || !face1 || !face2 || !outEdges || maxEdges <= 0) return 0;
    
    try {
        // Get edges of both faces
        TopTools_IndexedMapOfShape edges1, edges2;
        TopExp::MapShapes(face1->face, TopAbs_EDGE, edges1);
        TopExp::MapShapes(face2->face, TopAbs_EDGE, edges2);
        
        int32_t count = 0;
        
        // Find common edges
        for (int i = 1; i <= edges1.Extent() && count < maxEdges; i++) {
            const TopoDS_Edge& e1 = TopoDS::Edge(edges1(i));
            
            for (int j = 1; j <= edges2.Extent(); j++) {
                const TopoDS_Edge& e2 = TopoDS::Edge(edges2(j));
                
                // Compare by IsEqual (same TShape)
                if (e1.IsSame(e2)) {
                    outEdges[count] = new OCCTEdge(e1);
                    count++;
                    break;
                }
            }
        }
        
        return count;
    } catch (...) {
        return 0;
    }
}

bool OCCTFacesAreAdjacent(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2) {
    if (!shape || !face1 || !face2) return false;
    
    OCCTEdgeRef edges[1];
    int32_t count = OCCTFaceGetSharedEdges(shape, face1, face2, edges, 1);
    
    if (count > 0) {
        OCCTEdgeRelease(edges[0]);
        return true;
    }
    return false;
}

double OCCTEdgeGetDihedralAngle(OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2, double parameter) {
    if (!edge || !face1 || !face2) return -1;
    
    try {
        // Get edge curve
        BRepAdaptor_Curve edgeCurve(edge->edge);
        double first = edgeCurve.FirstParameter();
        double last = edgeCurve.LastParameter();
        double param = first + parameter * (last - first);
        
        // Get PCurves on each face
        Standard_Real f, l;
        Handle(Geom2d_Curve) pcurve1 = BRep_Tool::CurveOnSurface(edge->edge, face1->face, f, l);
        Handle(Geom2d_Curve) pcurve2 = BRep_Tool::CurveOnSurface(edge->edge, face2->face, f, l);
        
        if (pcurve1.IsNull() || pcurve2.IsNull()) {
            return -1;
        }
        
        // Get UV at parameter
        gp_Pnt2d uv1 = pcurve1->Value(param);
        gp_Pnt2d uv2 = pcurve2->Value(param);
        
        // Get surface adapters and normals
        BRepAdaptor_Surface surf1(face1->face);
        BRepAdaptor_Surface surf2(face2->face);
        
        gp_Pnt p1, p2;
        gp_Vec d1u, d1v, d2u, d2v;
        surf1.D1(uv1.X(), uv1.Y(), p1, d1u, d1v);
        surf2.D1(uv2.X(), uv2.Y(), p2, d2u, d2v);
        
        gp_Vec n1 = d1u.Crossed(d1v);
        gp_Vec n2 = d2u.Crossed(d2v);
        
        if (n1.Magnitude() < 1e-10 || n2.Magnitude() < 1e-10) {
            return -1;
        }
        
        n1.Normalize();
        n2.Normalize();
        
        // Account for face orientation
        if (face1->face.Orientation() == TopAbs_REVERSED) {
            n1.Reverse();
        }
        if (face2->face.Orientation() == TopAbs_REVERSED) {
            n2.Reverse();
        }
        
        // Angle between normals
        double cosAngle = n1.Dot(n2);
        cosAngle = std::max(-1.0, std::min(1.0, cosAngle));  // Clamp
        
        // The dihedral angle is PI - acos(dot) for interior angle
        // Or we return the angle between normals directly
        return std::acos(cosAngle);
    } catch (...) {
        return -1;
    }
}
