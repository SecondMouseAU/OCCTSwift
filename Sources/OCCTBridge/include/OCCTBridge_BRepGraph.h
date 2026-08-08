//
//  OCCTBridge_BRepGraph.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the BRepGraph domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_BRepGraph_h
#define OCCTBridge_BRepGraph_h



// MARK: - Attributed Adjacency Graph (AAG) Support

/// Edge convexity type for AAG
typedef enum {
    OCCTEdgeConvexityConcave = -1,  // Interior angle > 180° (pocket-like)
    OCCTEdgeConvexitySmooth = 0,    // Tangent faces (180°)
    OCCTEdgeConvexityConvex = 1     // Interior angle < 180° (fillet-like)
} OCCTEdgeConvexity;

/// Get the two faces adjacent to an edge within a shape
/// @param shape The shape containing the edge and faces
/// @param edge The edge to query
/// @param outFace1 Output: first adjacent face (caller must release)
/// @param outFace2 Output: second adjacent face (caller must release), may be NULL for boundary edges
/// @return Number of adjacent faces (0, 1, or 2)
int32_t OCCTEdgeGetAdjacentFaces(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef* outFace1, OCCTFaceRef* outFace2);

/// Determine the convexity of an edge between two faces.
///
/// Backed by OCCT's own classifier, `ChFi3d::DefineConnectType`, the same one the fillet and
/// chamfer builders use to decide which edges they can round or bevel (#723). It samples the
/// LOCAL dihedral at the edge midpoint (each face's normal there, from its pcurve's `D1`, against
/// the edge tangent), unlike the formula this replaced, which used each face's GLOBAL area
/// centroid as a stand-in for "which side is material" and drifted with face proportions: #723
/// measured a through-hole rim classifying concave depending on plate thickness, since the
/// cylindrical wall's centroid moves as the wall gets taller while the rim geometry itself never
/// changes. `ChFi3d::DefineConnectType` needs no such proxy and no per-face integration, so this
/// also removes the caching `AAG.buildGraph()` grew in #720 to make the old formula's integration
/// affordable, since there is nothing left to cache.
/// @param shape The shape containing the geometry
/// @param edge The shared edge
/// @param face1 First adjacent face
/// @param face2 Second adjacent face
/// @return Convexity type (concave, smooth/tangential, or convex)
OCCTEdgeConvexity OCCTEdgeGetConvexity(OCCTShapeRef shape, OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get all edges shared between two faces.
///
/// Shares its face-pair edge-identity comparison with OCCTFaceGetSharedEdgeCount through one
/// internal helper (`countOrCollectSharedEdges`, OCCTBridge_BRepGraph.mm) rather than two
/// independent copies of the same loop -- #761's review: two copies is the shape of bug that let
/// the original 10-cap survive unnoticed in the first place, since nothing forced them to agree.
/// @param shape The shape containing the faces
/// @param face1 First face
/// @param face2 Second face
/// @param outEdges Output array for shared edges (caller allocates)
/// @param maxEdges Maximum number of edges to return
/// @return Number of shared edges found, truncated at maxEdges if the true count is larger. Call
///   OCCTFaceGetSharedEdgeCount first to size outEdges exactly and avoid truncation (#761).
int32_t OCCTFaceGetSharedEdges(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2, OCCTEdgeRef* outEdges, int32_t maxEdges);

/// The true number of edges shared between two faces, with no cap.
///
/// `AAG.buildGraph()` (`FeatureRecognition.swift`) used to call `OCCTFaceGetSharedEdges` directly
/// with a hardcoded `maxEdges: 10`, so `AAGEdge.sharedEdgeCount` silently truncated at 10 on any
/// face pair sharing more edges -- plausible after healing splits a boundary into segments, and
/// reproduced directly: an 11-notch synthetic fixture measured 12 shared edges between two faces,
/// reported as 10 (`Scripts/repro/761-aag-brepgraph-adjacency/`). This is the same count-then-fetch
/// idiom `BRepGraph.swift`'s own `fetchIndices` helper already uses for every `...Count`/
/// `...Indices` bridge pair: call this first to size the buffer exactly, then call
/// OCCTFaceGetSharedEdges with that exact count.
///
/// Reads the identical comparison OCCTFaceGetSharedEdges does, through the shared
/// `countOrCollectSharedEdges` helper both call -- not a second, independently-written copy of the
/// loop (#761 review). Same O(e1 * e2) cost as OCCTFaceGetSharedEdges itself (each face's own edge
/// count, never the whole shape), so sizing correctly costs nothing beyond running that one
/// comparison twice (once per call), which #761's own measurement found negligible next to the
/// alternative of routing through BRepGraph.sharedEdges(between:and:) instead (a real, measured
/// performance regression at model scale -- see that repro directory's README for the numbers).
/// @param shape The shape containing the faces
/// @param face1 First face
/// @param face2 Second face
/// @return Number of shared edges, uncapped.
int32_t OCCTFaceGetSharedEdgeCount(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2);

/// True number of edges shared by two faces, optionally also handing back the first of them, from a
/// SINGLE walk of the pair.
///
/// `buildGraph()` used to ask three separate questions per adjacent pair, each rebuilding both
/// faces' edge maps: `OCCTFacesAreAdjacent` (is there one), `OCCTFaceGetSharedEdgeCount` (how many),
/// and `OCCTFaceGetSharedEdges(maxEdges: 1)` (give me one, to ask about convexity). Calls one and
/// three were literally redundant. This answers all three at once: a non-zero return IS adjacency,
/// and `outFirstEdge` is the edge convexity gets asked about (#783).
///
/// - Parameters:
///   - outFirstEdge: optional. When non-null, receives the first shared edge, or `nullptr` if the
///     faces share none. **The caller owns it and must `OCCTEdgeRelease` it** when the return is
///     greater than zero.
/// - Returns: the true shared-edge count, never truncated.
int32_t OCCTFaceGetSharedEdgeSummary(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2,
                                     OCCTEdgeRef* _Nullable outFirstEdge);

/// Check if two faces are adjacent (share at least one edge)
bool OCCTFacesAreAdjacent(OCCTShapeRef shape, OCCTFaceRef face1, OCCTFaceRef face2);

/// Get the dihedral angle between two adjacent faces at their shared edge
/// @param edge The shared edge
/// @param face1 First face
/// @param face2 Second face
/// @param parameter Parameter along edge (0.0 to 1.0) where to measure angle
/// @return Dihedral angle in radians (0 to 2*PI), or -1 on error
double OCCTEdgeGetDihedralAngle(OCCTEdgeRef edge, OCCTFaceRef face1, OCCTFaceRef face2, double parameter);

/// Create a BRepGraph from a shape.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCreate(OCCTShapeRef _Nonnull shape, bool parallel);

/// Release a BRepGraph.
void OCCTBRepGraphRelease(OCCTBRepGraphRef _Nonnull graph);

/// Check if the graph was built successfully.
bool OCCTBRepGraphIsDone(OCCTBRepGraphRef _Nonnull graph);

/// Total number of nodes in the graph.
int32_t OCCTBRepGraphNbNodes(OCCTBRepGraphRef _Nonnull graph);

// --- Topology Counts ---

/// Number of faces in the graph.
int32_t OCCTBRepGraphNbFaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of active (non-removed) faces.
int32_t OCCTBRepGraphNbActiveFaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of edges in the graph.
int32_t OCCTBRepGraphNbEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of active edges.
int32_t OCCTBRepGraphNbActiveEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of vertices in the graph.
int32_t OCCTBRepGraphNbVertices(OCCTBRepGraphRef _Nonnull graph);
/// Number of active vertices.
int32_t OCCTBRepGraphNbActiveVertices(OCCTBRepGraphRef _Nonnull graph);
/// Number of wires.
int32_t OCCTBRepGraphNbWires(OCCTBRepGraphRef _Nonnull graph);
/// Number of shells.
int32_t OCCTBRepGraphNbShells(OCCTBRepGraphRef _Nonnull graph);
/// Number of solids.
int32_t OCCTBRepGraphNbSolids(OCCTBRepGraphRef _Nonnull graph);
/// Number of coedges (half-edges).
int32_t OCCTBRepGraphNbCoEdges(OCCTBRepGraphRef _Nonnull graph);
/// Number of compounds.
int32_t OCCTBRepGraphNbCompounds(OCCTBRepGraphRef _Nonnull graph);

// --- Geometry Counts ---

/// Number of surfaces in the graph.
int32_t OCCTBRepGraphNbSurfaces(OCCTBRepGraphRef _Nonnull graph);
/// Number of 3D curves.
int32_t OCCTBRepGraphNbCurves3D(OCCTBRepGraphRef _Nonnull graph);
/// Number of 2D curves.
int32_t OCCTBRepGraphNbCurves2D(OCCTBRepGraphRef _Nonnull graph);

// --- Face Queries ---

/// Number of faces adjacent to a given face.
int32_t OCCTBRepGraphFaceAdjacentCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
/// Get adjacent face indices. Caller provides buffer of size adjacentCount.
void OCCTBRepGraphFaceAdjacentIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                       int32_t* _Nonnull outIndices);
/// Number of edges shared between two faces.
int32_t OCCTBRepGraphFaceSharedEdgeCount(OCCTBRepGraphRef _Nonnull graph,
                                          int32_t faceA, int32_t faceB);
/// Get shared edge indices between two faces. Caller provides buffer.
void OCCTBRepGraphFaceSharedEdgeIndices(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t faceA, int32_t faceB,
                                         int32_t* _Nonnull outIndices);
/// Index of the outer wire of a face.
int32_t OCCTBRepGraphFaceOuterWire(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Edge Queries ---

/// Number of faces an edge belongs to.
int32_t OCCTBRepGraphEdgeNbFaces(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Get face indices for an edge. Caller provides buffer of size nbFaces.
void OCCTBRepGraphEdgeFaceIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                   int32_t* _Nonnull outIndices);
/// Whether an edge is a boundary edge (belongs to only one face).
bool OCCTBRepGraphEdgeIsBoundary(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Whether an edge is manifold (belongs to exactly two faces).
bool OCCTBRepGraphEdgeIsManifold(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Number of edges adjacent to a given edge (share a vertex).
int32_t OCCTBRepGraphEdgeAdjacentCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
/// Get adjacent edge indices. Caller provides buffer.
void OCCTBRepGraphEdgeAdjacentIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                       int32_t* _Nonnull outIndices);

// --- Vertex Queries ---

/// Number of edges connected to a vertex.
int32_t OCCTBRepGraphVertexEdgeCount(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex);
/// Get edge indices connected to a vertex. Caller provides buffer.
void OCCTBRepGraphVertexEdgeIndices(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex,
                                     int32_t* _Nonnull outIndices);

// --- Child Explorer ---

/// Count descendant nodes of a given kind from a root node.
/// rootKind: 0=Solid,1=Shell,2=Face,3=Wire,4=Edge,5=Vertex,6=Compound,7=CompSolid,8=CoEdge
/// targetKind: same enum.
int32_t OCCTBRepGraphChildCount(OCCTBRepGraphRef _Nonnull graph,
                                 int32_t rootKind, int32_t rootIndex,
                                 int32_t targetKind);

/// List descendant node indices of a given kind from a root node. Writes up to
/// maxCount indices into outIndices; returns the actual count (may exceed maxCount).
/// Used by TopologyRef.containedIn resolution and construction-geometry accessors.
int32_t OCCTBRepGraphChildIndices(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t rootKind, int32_t rootIndex,
                                    int32_t targetKind,
                                    int32_t* _Nonnull outIndices,
                                    int32_t maxCount);

// --- Parent Explorer ---

/// Count parent nodes of a given node.
int32_t OCCTBRepGraphParentCount(OCCTBRepGraphRef _Nonnull graph,
                                  int32_t nodeKind, int32_t nodeIndex);

// --- Validate ---

/// Validate the graph. Returns true if valid (no errors).
bool OCCTBRepGraphValidate(OCCTBRepGraphRef _Nonnull graph);
/// Count validation issues.
int32_t OCCTBRepGraphValidateIssueCount(OCCTBRepGraphRef _Nonnull graph);

/// Validate result struct.
typedef struct {
    bool isValid;
    int32_t errorCount;
    int32_t warningCount;
} OCCTBRepGraphValidateResult;

/// Validate and return detailed result.
OCCTBRepGraphValidateResult OCCTBRepGraphValidateDetailed(OCCTBRepGraphRef _Nonnull graph);

// --- Compact ---

/// Compact result struct.
typedef struct {
    int32_t removedVertices;
    int32_t removedEdges;
    int32_t removedFaces;
    int32_t nodesAfter;
} OCCTBRepGraphCompactResult;

/// Compact the graph (remove unreferenced nodes).
OCCTBRepGraphCompactResult OCCTBRepGraphCompact(OCCTBRepGraphRef _Nonnull graph);

// --- Deduplicate ---

/// Deduplicate result struct.
typedef struct {
    int32_t canonicalSurfaces;
    int32_t canonicalCurves;
    int32_t surfaceRewrites;
    int32_t curveRewrites;
} OCCTBRepGraphDeduplicateResult;

/// Deduplicate geometry in the graph.
OCCTBRepGraphDeduplicateResult OCCTBRepGraphDeduplicate(OCCTBRepGraphRef _Nonnull graph);

// --- Node Removal Check ---

/// Check if a node has been soft-removed.
bool OCCTBRepGraphIsRemoved(OCCTBRepGraphRef _Nonnull graph, int32_t nodeKind, int32_t nodeIndex);

// --- Root Nodes ---

/// Number of root nodes in the graph.
int32_t OCCTBRepGraphRootCount(OCCTBRepGraphRef _Nonnull graph);
/// Get root node kinds and indices. Caller provides buffers of size rootCount.
void OCCTBRepGraphRootNodes(OCCTBRepGraphRef _Nonnull graph,
                             int32_t* _Nonnull outKinds, int32_t* _Nonnull outIndices);

// --- Topology Statistics ---

/// Get all topology counts at once.
typedef struct {
    int32_t solids;
    int32_t shells;
    int32_t faces;
    int32_t wires;
    int32_t edges;
    int32_t vertices;
    int32_t coedges;
    int32_t compounds;
    int32_t totalNodes;
    int32_t surfaces;
    int32_t curves3d;
    int32_t curves2d;
} OCCTBRepGraphStats;

/// Get comprehensive graph statistics.
OCCTBRepGraphStats OCCTBRepGraphGetStats(OCCTBRepGraphRef _Nonnull graph);

// MARK: - BRepGraph Extended (v0.133.0)

/// Reconstruct a TopoDS_Shape from a graph node.
OCCTShapeRef _Nullable OCCTBRepGraphShapeFromNode(OCCTBRepGraphRef _Nonnull graph,
                                                   int32_t nodeKind, int32_t nodeIndex);

/// Find the node (kind+index) for a shape. Returns -1 in outKind if not found.
void OCCTBRepGraphFindNode(OCCTBRepGraphRef _Nonnull graph, OCCTShapeRef _Nonnull shape,
                           int32_t* _Nonnull outKind, int32_t* _Nonnull outIndex);

/// Check if a shape is known to the graph.
bool OCCTBRepGraphHasNode(OCCTBRepGraphRef _Nonnull graph, OCCTShapeRef _Nonnull shape);

// --- Vertex Geometry ---

/// Get vertex 3D point.
void OCCTBRepGraphVertexPoint(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex,
                              double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Get vertex tolerance.
double OCCTBRepGraphVertexTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex);

// --- Edge Geometry ---

/// Get edge tolerance.
double OCCTBRepGraphEdgeTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge is degenerated.
bool OCCTBRepGraphEdgeIsDegenerated(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge has SameParameter flag.
bool OCCTBRepGraphEdgeIsSameParameter(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge has SameRange flag.
bool OCCTBRepGraphEdgeIsSameRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get edge parameter range.
void OCCTBRepGraphEdgeRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                            double* _Nonnull outFirst, double* _Nonnull outLast);

/// Check if edge has a 3D curve.
bool OCCTBRepGraphEdgeHasCurve(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Check if edge is closed (seam) on a face.
bool OCCTBRepGraphEdgeIsClosedOnFace(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t edgeIndex, int32_t faceIndex);

/// Check if edge has a 3D polygon.
bool OCCTBRepGraphEdgeHasPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get maximum continuity order of an edge.
int32_t OCCTBRepGraphEdgeMaxContinuity(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

// --- Face Geometry ---

/// Get face tolerance.
double OCCTBRepGraphFaceTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has natural restriction.
bool OCCTBRepGraphFaceIsNaturalRestriction(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has a surface.
bool OCCTBRepGraphFaceHasSurface(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Check if face has a triangulation.
bool OCCTBRepGraphFaceHasTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Wire Queries ---

/// Check if wire is closed.
bool OCCTBRepGraphWireIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Number of coedges in a wire.
int32_t OCCTBRepGraphWireNbCoEdges(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Number of faces a wire belongs to.
int32_t OCCTBRepGraphWireFaceCount(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex);

/// Get face indices a wire belongs to.
void OCCTBRepGraphWireFaceIndices(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex,
                                  int32_t* _Nonnull outIndices);

// --- CoEdge Queries ---

/// Get edge index for a coedge.
int32_t OCCTBRepGraphCoEdgeEdge(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get face index for a coedge.
int32_t OCCTBRepGraphCoEdgeFace(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get seam pair coedge index (-1 if none).
int32_t OCCTBRepGraphCoEdgeSeamPair(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Check if coedge has a PCurve.
bool OCCTBRepGraphCoEdgeHasPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

/// Get coedge PCurve range.
void OCCTBRepGraphCoEdgeRange(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex,
                              double* _Nonnull outFirst, double* _Nonnull outLast);

// --- Shell Queries ---

/// Number of solids a shell belongs to.
int32_t OCCTBRepGraphShellSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

/// Get solid indices a shell belongs to.
void OCCTBRepGraphShellSolidIndices(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex,
                                    int32_t* _Nonnull outIndices);

// --- Solid Queries ---

/// Number of comp-solids a solid belongs to.
int32_t OCCTBRepGraphSolidCompSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex);

// --- History ---

/// Number of history records.
int32_t OCCTBRepGraphHistoryNbRecords(OCCTBRepGraphRef _Nonnull graph);

/// Check if history recording is enabled.
bool OCCTBRepGraphHistoryIsEnabled(OCCTBRepGraphRef _Nonnull graph);

/// Enable or disable history recording.
void OCCTBRepGraphHistorySetEnabled(OCCTBRepGraphRef _Nonnull graph, bool enabled);

/// Clear all history records.
void OCCTBRepGraphHistoryClear(OCCTBRepGraphRef _Nonnull graph);

// --- History Record Readback (v0.141, #72 Phase 0) ---

/// Get operation name and sequence number of history record at index.
/// outOpName is written with a NUL-terminated string up to outOpNameMax bytes.
/// Returns false on invalid index.
bool OCCTBRepGraphHistoryGetRecordInfo(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t recordIdx,
                                        char* _Nonnull outOpName,
                                        int32_t outOpNameMax,
                                        int32_t* _Nonnull outSequenceNumber);

/// Number of original (pre-mutation) nodes in record's mapping.
int32_t OCCTBRepGraphHistoryGetRecordOriginalsCount(OCCTBRepGraphRef _Nonnull graph,
                                                     int32_t recordIdx);

/// List the original nodes of a history record. Writes up to maxCount pairs;
/// returns actual count (may exceed maxCount if truncated).
int32_t OCCTBRepGraphHistoryGetRecordOriginals(OCCTBRepGraphRef _Nonnull graph,
                                                int32_t recordIdx,
                                                int32_t* _Nonnull outKinds,
                                                int32_t* _Nonnull outIndices,
                                                int32_t maxCount);

/// For a specific original node in a record, list the replacement nodes.
/// Empty result = node was deleted. Single element = modified-in-place. Multiple = split.
/// Returns -1 if the original is not in the record's mapping.
int32_t OCCTBRepGraphHistoryGetRecordMapping(OCCTBRepGraphRef _Nonnull graph,
                                              int32_t recordIdx,
                                              int32_t origKind,
                                              int32_t origIndex,
                                              int32_t* _Nonnull outKinds,
                                              int32_t* _Nonnull outIndices,
                                              int32_t maxCount);

/// Walk backwards from a derived node to its root original via the reverse map.
/// Returns true if an original is found; outputs the original's (kind, index).
/// If the node has no recorded history, returns true with the input node itself.
bool OCCTBRepGraphHistoryFindOriginal(OCCTBRepGraphRef _Nonnull graph,
                                       int32_t derivedKind,
                                       int32_t derivedIndex,
                                       int32_t* _Nonnull outKind,
                                       int32_t* _Nonnull outIndex);

/// Walk forward from an original node to all transitively derived nodes.
/// Returns the total count; writes up to maxCount pairs.
int32_t OCCTBRepGraphHistoryFindDerived(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t origKind,
                                         int32_t origIndex,
                                         int32_t* _Nonnull outKinds,
                                         int32_t* _Nonnull outIndices,
                                         int32_t maxCount);

/// Record a 1-to-N modification event on the graph's history log.
/// Useful for consumers that mutate the graph outside BRepGraph's own builder API
/// and want their changes to participate in history queries.
void OCCTBRepGraphHistoryRecord(OCCTBRepGraphRef _Nonnull graph,
                                 const char* _Nonnull opName,
                                 int32_t origKind,
                                 int32_t origIndex,
                                 const int32_t* _Nullable replKinds,
                                 const int32_t* _Nullable replIndices,
                                 int32_t replCount);

/// True if a recorded operation consumed this node, leaving no image in the result.
/// Distinct from "has no modified record" — absence of a record is not deletion.
bool OCCTBRepGraphHistoryIsDeleted(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t kind,
                                    int32_t index);

/// The graph's full deleted set. Returns the total count; writes up to maxCount pairs.
int32_t OCCTBRepGraphHistoryDeletedNodes(OCCTBRepGraphRef _Nonnull graph,
                                          int32_t* _Nullable outKinds,
                                          int32_t* _Nullable outIndices,
                                          int32_t maxCount);

/// Add an OCCT algorithm result to `graph` and absorb its BRepTools_History into
/// the graph's history log (issue #290).
///
/// This is the supported way to keep referring to an entity across an operation
/// that rebuilds the shape (booleans, fillets, ...). The input and the result live
/// in the SAME graph, so history is NodeId-keyed and the input's existing NodeRefs
/// and UIDs stay valid — there is no generation boundary and no cross-graph UID
/// lookup involved. After this call, currentForms(of:) on an input node returns
/// its successors, and the TopologyRef recipes (.splitOf / .createdBy) resolve
/// against the emitted records.
///
/// `inputRootKinds` / `inputRootIndices` name the nodes in `graph` whose subshapes
/// should be tracked; the input map is collected via
/// BRepGraph_ShapesView::CollectHistoryInputs, so those roots must already be in
/// `graph` (i.e. the graph the operation's input shape was built from).
///
/// Only VERTEX / EDGE / FACE / SOLID are carried (BRepTools_History::IsSupportedType).
///
/// @param graph       graph holding the inputs, and receiving the result
/// @param resultShape the OCCT algorithm's result shape
/// @param history     from OCCTBooleanHistoryAsBRepToolsHistory (NULL is a no-op)
/// @param opName      label written into every emitted record
/// @param outRootKind  if non-null, set to the added result's topology-root kind
/// @param outRootIndex if non-null, set to the added result's topology-root index
/// @return true if the result was added and the history absorbed.
bool OCCTBRepGraphAddWithHistory(OCCTBRepGraphRef _Nonnull graph,
                                  OCCTShapeRef _Nonnull resultShape,
                                  OCCTHistoryRef history,
                                  const int32_t* _Nonnull inputRootKinds,
                                  const int32_t* _Nonnull inputRootIndices,
                                  int32_t inputRootCount,
                                  const char* _Nonnull opName,
                                  int32_t* _Nullable outRootKind,
                                  int32_t* _Nullable outRootIndex);

// --- Poly Counts ---

/// Number of triangulations.
int32_t OCCTBRepGraphNbTriangulations(OCCTBRepGraphRef _Nonnull graph);

/// Number of 3D polygons.
int32_t OCCTBRepGraphNbPolygons3D(OCCTBRepGraphRef _Nonnull graph);

// --- MeshView additions (v0.158.0, OCCT 8.0.0 beta1 two-tier mesh storage) ---

/// Number of 2D polygons (PCurve discretizations).
int32_t OCCTBRepGraphMeshNbPolygons2D(OCCTBRepGraphRef _Nonnull graph);

/// Number of polygon-on-triangulation reps (coedge discretizations parameterized on a face triangulation).
int32_t OCCTBRepGraphMeshNbPolygonsOnTri(OCCTBRepGraphRef _Nonnull graph);

/// Number of active (non-removed) triangulations.
int32_t OCCTBRepGraphMeshNbActiveTriangulations(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 3D polygons.
int32_t OCCTBRepGraphMeshNbActivePolygons3D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 2D polygons.
int32_t OCCTBRepGraphMeshNbActivePolygons2D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active polygon-on-triangulation reps.
int32_t OCCTBRepGraphMeshNbActivePolygonsOnTri(OCCTBRepGraphRef _Nonnull graph);

/// Active triangulation rep id for a face (cache-first, persistent fallback).
/// Returns the rep id, or -1 if no mesh available.
int32_t OCCTBRepGraphMeshFaceActiveTriangulationRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Active polygon-3D rep id for an edge (cache-first, persistent fallback).
/// Returns the rep id, or -1 if no polygon3D mesh available.
int32_t OCCTBRepGraphMeshEdgePolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Whether a coedge has cached mesh data (polygon-on-tri or polygon-2D). Cache-only check.
bool OCCTBRepGraphMeshCoEdgeHasMesh(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

// --- MeshCache write API (v0.160.0): BRepGraph_Tool::Mesh statics ---

/// Create a TriangulationRep in mesh storage. Returns the rep id, or -1 on null/failure.
int32_t OCCTBRepGraphMeshCreateTriangulationRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyTriangulationRef _Nonnull triangulation);

/// Create a Polygon3DRep in mesh storage. Returns the rep id, or -1 on null/failure.
int32_t OCCTBRepGraphMeshCreatePolygon3DRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyPolygon3DRef _Nonnull polygon);

/// Create a PolygonOnTriRep linked to an existing triangulation rep. Returns the rep id, or -1 on failure.
int32_t OCCTBRepGraphMeshCreatePolygonOnTriRep(OCCTBRepGraphRef _Nonnull graph, OCCTPolyPolygonOnTriRef _Nonnull polygon, int32_t triRepId);

/// Append a triangulation rep to a face's cached mesh (multi-LOD support).
void OCCTBRepGraphMeshAppendCachedTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t triRepId);

/// Set the active triangulation index in a face's cached mesh.
void OCCTBRepGraphMeshSetCachedActiveIndex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t activeIndex);

/// Set the polygon-3D rep in an edge's cached mesh.
void OCCTBRepGraphMeshSetCachedPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t polyRepId);

/// Append a polygon-on-tri rep to a coedge's cached mesh (seam edge support).
void OCCTBRepGraphMeshAppendCachedPolygonOnTri(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polyRepId);

/// Set the polygon-2D rep in a coedge's cached mesh.
void OCCTBRepGraphMeshSetCachedPolygon2D(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t poly2DRepId);

// --- Active Geometry Counts ---

/// Number of active (non-removed) surfaces.
int32_t OCCTBRepGraphNbActiveSurfaces(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 3D curves.
int32_t OCCTBRepGraphNbActiveCurves3D(OCCTBRepGraphRef _Nonnull graph);

/// Number of active 2D curves.
int32_t OCCTBRepGraphNbActiveCurves2D(OCCTBRepGraphRef _Nonnull graph);

// --- SameDomain ---

/// Number of same-domain faces for a given face.
int32_t OCCTBRepGraphFaceSameDomainCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Get same-domain face indices.
void OCCTBRepGraphFaceSameDomainIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                        int32_t* _Nonnull outIndices);

// --- Copy and Transform ---

/// Deep copy the graph.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCopy(OCCTBRepGraphRef _Nonnull graph, bool copyGeom);

/// Copy a single face sub-graph.
OCCTBRepGraphRef _Nullable OCCTBRepGraphCopyFace(OCCTBRepGraphRef _Nonnull graph,
                                                  int32_t faceIndex, bool copyGeom);

/// Transform the graph by a translation vector.
OCCTBRepGraphRef _Nullable OCCTBRepGraphTransformTranslation(OCCTBRepGraphRef _Nonnull graph,
                                                              double dx, double dy, double dz,
                                                              bool copyGeom);

// MARK: - BRepGraph Assembly & Refs (v0.134.0)

// --- Product (Assembly) Queries ---

/// Number of products in the graph.
int32_t OCCTBRepGraphNbProducts(OCCTBRepGraphRef _Nonnull graph);

/// Number of occurrences in the graph.
int32_t OCCTBRepGraphNbOccurrences(OCCTBRepGraphRef _Nonnull graph);

/// Whether product at index is an assembly (has child occurrences, no topology root).
bool OCCTBRepGraphProductIsAssembly(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Whether product at index is a part (has a valid topology root).
bool OCCTBRepGraphProductIsPart(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Number of active child occurrences of a product.
int32_t OCCTBRepGraphProductNbComponents(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Shape root node kind for a product (-1 if invalid/assembly).
int32_t OCCTBRepGraphProductShapeRootKind(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Shape root node index for a product (-1 if invalid/assembly).
int32_t OCCTBRepGraphProductShapeRootIndex(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

/// Product index of an occurrence.
int32_t OCCTBRepGraphOccurrenceProduct(OCCTBRepGraphRef _Nonnull graph, int32_t occIndex);

/// Parent product index of an occurrence.
int32_t OCCTBRepGraphOccurrenceParentProduct(OCCTBRepGraphRef _Nonnull graph, int32_t occIndex);

/// Number of root products (not referenced by an active occurrence).
int32_t OCCTBRepGraphRootProductCount(OCCTBRepGraphRef _Nonnull graph);

/// Get root product indices.
void OCCTBRepGraphRootProductIndices(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t* _Nonnull outIndices);

// --- RefsView Per-Kind Counts ---

/// Number of shell reference entries.
int32_t OCCTBRepGraphNbShellRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of face reference entries.
int32_t OCCTBRepGraphNbFaceRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of wire reference entries.
int32_t OCCTBRepGraphNbWireRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of coedge reference entries.
int32_t OCCTBRepGraphNbCoEdgeRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of vertex reference entries.
int32_t OCCTBRepGraphNbVertexRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of solid reference entries.
int32_t OCCTBRepGraphNbSolidRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of child reference entries.
int32_t OCCTBRepGraphNbChildRefs(OCCTBRepGraphRef _Nonnull graph);

/// Number of occurrence reference entries.
int32_t OCCTBRepGraphNbOccurrenceRefs(OCCTBRepGraphRef _Nonnull graph);

// --- RefsView Global Methods ---

/// Child node kind from a reference entry. refKind uses BRepGraph_RefId::Kind values.
int32_t OCCTBRepGraphRefChildNodeKind(OCCTBRepGraphRef _Nonnull graph,
                                       int32_t refKind, int32_t refIndex);

/// Child node index from a reference entry.
int32_t OCCTBRepGraphRefChildNodeIndex(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t refKind, int32_t refIndex);

/// Whether a reference entry is removed.
bool OCCTBRepGraphRefIsRemoved(OCCTBRepGraphRef _Nonnull graph,
                                int32_t refKind, int32_t refIndex);

/// Orientation of a reference entry (TopAbs_Orientation as int).
int32_t OCCTBRepGraphRefOrientation(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t refKind, int32_t refIndex);

// --- Face Definition Details ---

/// Number of wire refs on a face.
int32_t OCCTBRepGraphFaceNbWires(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Number of isolated vertex refs on a face.
int32_t OCCTBRepGraphFaceNbVertexRefs(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Edge Definition Details ---

/// Start vertex definition index of an edge (-1 if invalid).
int32_t OCCTBRepGraphEdgeStartVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// End vertex definition index of an edge (-1 if invalid).
int32_t OCCTBRepGraphEdgeEndVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Whether an edge is topologically closed (start == end vertex).
bool OCCTBRepGraphEdgeIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

// --- Compound/CompSolid Queries ---

/// Number of parent compounds of a compound.
int32_t OCCTBRepGraphCompoundParentCount(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex);

/// Number of child refs of a compound.
int32_t OCCTBRepGraphCompoundChildCount(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex);

/// Number of solid refs in a comp-solid.
int32_t OCCTBRepGraphCompSolidSolidCount(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex);

/// Number of parent compounds of a comp-solid.
int32_t OCCTBRepGraphCompSolidCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex);

// --- Edge Additional Queries ---

/// Number of wires an edge belongs to.
int32_t OCCTBRepGraphEdgeWireCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get wire indices an edge belongs to.
void OCCTBRepGraphEdgeWireIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                   int32_t* _Nonnull outIndices);

/// Number of coedges of an edge.
int32_t OCCTBRepGraphEdgeCoEdgeCount(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

/// Get coedge indices of an edge.
void OCCTBRepGraphEdgeCoEdgeIndices(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
                                     int32_t* _Nonnull outIndices);

// --- Face Additional Queries ---

/// Number of shells a face belongs to.
int32_t OCCTBRepGraphFaceShellCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

/// Get shell indices a face belongs to.
void OCCTBRepGraphFaceShellIndices(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
                                    int32_t* _Nonnull outIndices);

/// Number of compounds a face belongs to.
int32_t OCCTBRepGraphFaceCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);

// --- Shell Additional Queries ---

/// Number of compounds a shell belongs to.
int32_t OCCTBRepGraphShellCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

/// Whether a shell is closed.
bool OCCTBRepGraphShellIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex);

// --- Solid Additional Queries ---

/// Number of compounds a solid belongs to.
int32_t OCCTBRepGraphSolidCompoundCount(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex);

// --- CompSolid Count ---

/// Number of comp-solids in the graph.
int32_t OCCTBRepGraphNbCompSolids(OCCTBRepGraphRef _Nonnull graph);

// --- Edge FindCoEdge ---

/// Find the coedge index for an (edge, face) pair (-1 if not found).
int32_t OCCTBRepGraphEdgeFindCoEdge(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t edgeIndex, int32_t faceIndex);

// MARK: - BRepGraph Builder (v0.135.0)

// --- Add Topology Nodes ---

/// Add a vertex to the graph. Returns vertex definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddVertex(OCCTBRepGraphRef _Nonnull graph,
                                       double x, double y, double z,
                                       double tolerance);

/// Add an empty shell to the graph. Returns shell definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddShell(OCCTBRepGraphRef _Nonnull graph);

/// Add an empty solid to the graph. Returns solid definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddSolid(OCCTBRepGraphRef _Nonnull graph);

/// Link a face to a shell. Returns face ref index (-1 on failure).
/// orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
int32_t OCCTBRepGraphBuilderAddFaceToShell(OCCTBRepGraphRef _Nonnull graph,
                                            int32_t shellIndex, int32_t faceIndex,
                                            int32_t orientation);

/// Link a shell to a solid. Returns shell ref index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddShellToSolid(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t solidIndex, int32_t shellIndex,
                                             int32_t orientation);

/// Add a compound with child node entries. Returns compound definition index (-1 on failure).
/// kinds and indices are parallel arrays of length count.
int32_t OCCTBRepGraphBuilderAddCompound(OCCTBRepGraphRef _Nonnull graph,
                                         const int32_t* _Nonnull kinds,
                                         const int32_t* _Nonnull indices,
                                         int32_t count);

/// Add a comp-solid with child solid indices. Returns compsolid definition index (-1 on failure).
int32_t OCCTBRepGraphBuilderAddCompSolid(OCCTBRepGraphRef _Nonnull graph,
                                          const int32_t* _Nonnull solidIndices,
                                          int32_t count);

// --- Remove/Modify Nodes ---

/// Mark a node as removed (soft deletion).
void OCCTBRepGraphBuilderRemoveNode(OCCTBRepGraphRef _Nonnull graph,
                                     int32_t nodeKind, int32_t nodeIndex);

/// Mark a node and all its descendants as removed.
void OCCTBRepGraphBuilderRemoveSubgraph(OCCTBRepGraphRef _Nonnull graph,
                                         int32_t nodeKind, int32_t nodeIndex);

// --- Append Shapes ---

/// Append a shape flattened (container nodes removed, faces as roots).
void OCCTBRepGraphBuilderAppendFlattenedShape(OCCTBRepGraphRef _Nonnull graph,
                                               OCCTShapeRef _Nonnull shape,
                                               bool parallel);

/// Append a shape preserving full topology hierarchy.
void OCCTBRepGraphBuilderAppendFullShape(OCCTBRepGraphRef _Nonnull graph,
                                          OCCTShapeRef _Nonnull shape,
                                          bool parallel);

// --- Deferred Invalidation ---

/// Begin deferred invalidation mode for batch mutations.
void OCCTBRepGraphBuilderBeginDeferred(OCCTBRepGraphRef _Nonnull graph);

/// End deferred invalidation mode and flush.
void OCCTBRepGraphBuilderEndDeferred(OCCTBRepGraphRef _Nonnull graph);

/// Check if deferred invalidation mode is active.
bool OCCTBRepGraphBuilderIsDeferredMode(OCCTBRepGraphRef _Nonnull graph);

/// Finalize batch mutations (validate reverse-index consistency).
void OCCTBRepGraphBuilderCommitMutation(OCCTBRepGraphRef _Nonnull graph);

// --- Edge Splitting ---

/// Split an edge at a vertex and parameter. Returns sub-edge indices via out params (-1 on failure).
void OCCTBRepGraphBuilderSplitEdge(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t edgeIndex, int32_t vertexIndex,
                                    double param,
                                    int32_t* _Nonnull outSubA, int32_t* _Nonnull outSubB);

// --- Replace Edge in Wire ---

/// Replace one edge with another in a wire definition.
void OCCTBRepGraphBuilderReplaceEdgeInWire(OCCTBRepGraphRef _Nonnull graph,
                                            int32_t wireIndex, int32_t oldEdgeIndex,
                                            int32_t newEdgeIndex, bool reversed);

// --- Remove Ref ---

/// Mark a reference entry as removed. Returns true if transitioned from active to removed.
bool OCCTBRepGraphBuilderRemoveRef(OCCTBRepGraphRef _Nonnull graph,
                                    int32_t refKind, int32_t refIndex);

// --- Clear Mesh ---

/// Clear all mesh representations for a face and its coedges.
void OCCTBRepGraphBuilderClearFaceMesh(OCCTBRepGraphRef _Nonnull graph,
                                        int32_t faceIndex);

/// Clear Polygon3D representation from an edge.
void OCCTBRepGraphBuilderClearEdgePolygon3D(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t edgeIndex);

// --- Validate Mutation Boundary ---

/// Validate mutation-boundary invariants. Returns true if no issues found.
bool OCCTBRepGraphBuilderValidateMutation(OCCTBRepGraphRef _Nonnull graph);

// MARK: - BRepGraph EditorView Field Setters (v0.159.0)
//
// Pure-value setters on the per-entity Ops classes of BRepGraph::EditorView.
// All take a typed entity id + scalar/bool argument and return void; on
// invalid id or out-of-range value the underlying call is a no-op.

// VertexOps
void OCCTBRepGraphSetVertexPoint(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex, double x, double y, double z);
void OCCTBRepGraphSetVertexTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t vertexIndex, double tolerance);

// EdgeOps
void OCCTBRepGraphSetEdgeTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, double tolerance);
void OCCTBRepGraphSetEdgeParamRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, double first, double last);
void OCCTBRepGraphSetEdgeSameParameter(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool sameParameter);
void OCCTBRepGraphSetEdgeSameRange(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool sameRange);
void OCCTBRepGraphSetEdgeDegenerate(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool degenerate);
void OCCTBRepGraphSetEdgeIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, bool isClosed);

// CoEdgeOps
void OCCTBRepGraphSetCoEdgeParamRange(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, double first, double last);
void OCCTBRepGraphSetCoEdgeOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t orientation);

// WireOps
void OCCTBRepGraphSetWireIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex, bool isClosed);

// FaceOps
void OCCTBRepGraphSetFaceTolerance(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, double tolerance);
void OCCTBRepGraphSetFaceNaturalRestriction(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, bool naturalRestriction);

// ShellOps
void OCCTBRepGraphSetShellIsClosed(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, bool isClosed);

// MARK: - BRepGraph EditorView Add/Remove + Ref Setters (v0.161.0)
//
// Add operations return the typed ref id (or -1 on failure). Remove operations return
// bool indicating whether the active usage was removed. Ref setters are no-ops on
// invalid ids.

// Add operations (Ref-typed return)
// NOTE: EdgeAddInternalVertex / FaceAddVertex return an int64_t supplement-attachment uid (-1 on
// failure) in OCCT 8.0.0p1 — these are runtime BRepGraph_LayerTopoSupplement attachments, not core
// ref ids. The `orientation` param is accepted for source-compat but ignored by the supplement layer.
int64_t OCCTBRepGraphEdgeAddInternalVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexIndex, int32_t orientation);
int64_t OCCTBRepGraphFaceAddVertex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t vertexIndex, int32_t orientation);
int32_t OCCTBRepGraphShellAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphSolidAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphCompoundAddChild(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex, int32_t childKind, int32_t childIndex, int32_t orientation);
int32_t OCCTBRepGraphCompSolidAddSolid(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex, int32_t solidIndex, int32_t orientation);

// Remove operations
bool OCCTBRepGraphEdgeRemoveVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
int32_t OCCTBRepGraphEdgeReplaceVertex(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t oldVertexRefIndex, int32_t newVertexIndex);
bool OCCTBRepGraphWireRemoveCoEdge(OCCTBRepGraphRef _Nonnull graph, int32_t wireIndex, int32_t coedgeRefIndex);
// NOTE: 2nd param is now the int64_t supplement-attachment uid returned by FaceAddVertex (OCCT 8.0.0p1),
// not a core ref index. faceIndex is unused (uid is layer-global).
bool OCCTBRepGraphFaceRemoveVertex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int64_t attachmentUID);
bool OCCTBRepGraphFaceRemoveWire(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t wireRefIndex);
bool OCCTBRepGraphShellRemoveFace(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t faceRefIndex);
bool OCCTBRepGraphShellRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t shellIndex, int32_t childRefIndex);
bool OCCTBRepGraphSolidRemoveShell(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t shellRefIndex);
bool OCCTBRepGraphSolidRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t solidIndex, int32_t childRefIndex);
bool OCCTBRepGraphCompoundRemoveChild(OCCTBRepGraphRef _Nonnull graph, int32_t compoundIndex, int32_t childRefIndex);
bool OCCTBRepGraphCompSolidRemoveSolid(OCCTBRepGraphRef _Nonnull graph, int32_t compSolidIndex, int32_t solidRefIndex);
void OCCTBRepGraphRemoveRep(OCCTBRepGraphRef _Nonnull graph, int32_t repKind, int32_t repIndex);

// Simple Ref setters (no TopLoc_Location, no Bnd_Box2d)
void OCCTBRepGraphSetVertexRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, int32_t orientation);
void OCCTBRepGraphSetVertexRefVertexDefId(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, int32_t vertexIndex);
void OCCTBRepGraphSetEdgeStartVertexRefId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
void OCCTBRepGraphSetEdgeEndVertexRefId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t vertexRefIndex);
void OCCTBRepGraphSetEdgeCurve3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t curve3DRepId);
void OCCTBRepGraphSetEdgePolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t polygon3DRepId);
void OCCTBRepGraphSetCoEdgeRefCoEdgeDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeRefIndex, int32_t coedgeIndex);
void OCCTBRepGraphSetCoEdgeEdgeDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t edgeIndex);
void OCCTBRepGraphSetCoEdgeFaceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t faceIndex);
void OCCTBRepGraphSetCoEdgeCurve2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t curve2DRepId);
void OCCTBRepGraphSetCoEdgePolygon2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polygon2DRepId);
void OCCTBRepGraphSetCoEdgePolygonOnTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t polygonOnTriRepId);
void OCCTBRepGraphClearCoEdgePCurveBinding(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
void OCCTBRepGraphSetWireRefIsOuter(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, bool isOuter);
void OCCTBRepGraphSetWireRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, int32_t orientation);
void OCCTBRepGraphSetWireRefWireDefId(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, int32_t wireIndex);
void OCCTBRepGraphSetFaceSurfaceRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t surfaceRepId);
void OCCTBRepGraphSetFaceRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, int32_t orientation);
void OCCTBRepGraphSetFaceRefFaceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, int32_t faceIndex);
void OCCTBRepGraphSetShellRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, int32_t orientation);
void OCCTBRepGraphSetShellRefShellDefId(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, int32_t shellIndex);
void OCCTBRepGraphSetSolidRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, int32_t orientation);
void OCCTBRepGraphSetSolidRefSolidDefId(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, int32_t solidIndex);
void OCCTBRepGraphSetOccurrenceChildDefId(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceIndex, int32_t childKind, int32_t childIndex);
void OCCTBRepGraphSetOccurrenceRefOccurrenceDefId(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceRefIndex, int32_t occurrenceIndex);
void OCCTBRepGraphSetChildRefOrientation(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, int32_t orientation);
void OCCTBRepGraphSetChildRefChildDefId(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, int32_t childKind, int32_t childIndex);

// MARK: - BRepGraph EditorView v0.162.0 — geometric setters, location setters, PCurve API

// CoEdge geometric setters
void OCCTBRepGraphSetCoEdgeUVBox(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, double u1, double v1, double u2, double v2);
/// Set the geometric regularity (C^k continuity) for an edge across a pair of faces.
/// face1Index == face2Index sets the seam continuity across a closed-surface seam line.
/// Continuity uses GeomAbs_Shape: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns 1 if written, 0 if the LayerRegularity layer is not registered.
/// (OCCT 8.0.0 GA replaced per-coedge SetContinuity / SetSeamContinuity / SetSeamPairId
///  with this per-(edge, face1, face2) layer model. Seam-pair-id is structural in GA —
///  no setter exists; query via BRepGraph_Tool::CoEdge::SeamPair.)
int32_t OCCTBRepGraphSetEdgeRegularity(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t face1Index, int32_t face2Index, int32_t continuity);

// Face triangulation rep binding
void OCCTBRepGraphSetFaceTriangulationRep(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t triRepId);

// CoEdge PCurve operations (Geom2d_Curve handle from OCCTCurve2D opaque)
int32_t OCCTBRepGraphCoEdgeCreateCurve2DRep(OCCTBRepGraphRef _Nonnull graph, OCCTCurve2DRef _Nonnull curve2d);
/// Pass nullptr for curve2d to clear the PCurve binding.
void OCCTBRepGraphCoEdgeSetPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, OCCTCurve2DRef _Nullable curve2d);
void OCCTBRepGraphCoEdgeAddPCurve(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex, int32_t faceIndex,
                                   OCCTCurve2DRef _Nonnull curve2d, double first, double last,
                                   int32_t orientation);

// Location setters (12-double 3x4 matrix, gp_Trsf::SetValues convention; row-major).
void OCCTBRepGraphSetVertexRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t vertexRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetCoEdgeRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetWireRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t wireRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetFaceRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t faceRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetShellRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t shellRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetSolidRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t solidRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetOccurrenceRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t occurrenceRefIndex, const double* _Nonnull matrix);
void OCCTBRepGraphSetChildRefLocalLocation(OCCTBRepGraphRef _Nonnull graph, int32_t childRefIndex, const double* _Nonnull matrix);

// MARK: - BRepGraph EditorView v0.163.0 — ProductOps assembly building

/// Wrap an existing topology root in a Product. Returns the new product id or -1.
int32_t OCCTBRepGraphLinkProductToTopology(OCCTBRepGraphRef _Nonnull graph,
                                             int32_t shapeRootKind, int32_t shapeRootIndex,
                                             const double* _Nullable placementMatrix);

/// Create an empty product (assembly node with no direct topology). Returns product id or -1.
int32_t OCCTBRepGraphCreateEmptyProduct(OCCTBRepGraphRef _Nonnull graph);

/// Link two products via a fresh occurrence. Returns occurrence id, -1 on failure.
/// Outputs the new occurrence ref id via outOccurrenceRefId (-1 on failure or when null).
/// Pass parentOccurrenceIndex = -1 for an unparented occurrence.
int32_t OCCTBRepGraphLinkProducts(OCCTBRepGraphRef _Nonnull graph, int32_t parentProductIndex,
                                    int32_t referencedProductIndex,
                                    const double* _Nonnull placementMatrix,
                                    int32_t parentOccurrenceIndex,
                                    int32_t* _Nullable outOccurrenceRefId);

/// Detach an occurrence ref from a product.
bool OCCTBRepGraphProductRemoveOccurrence(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex, int32_t occurrenceRefIndex);

/// Detach the scalar shape-root from a product.
bool OCCTBRepGraphProductRemoveShapeRoot(OCCTBRepGraphRef _Nonnull graph, int32_t productIndex);

// MARK: - BRepGraph EditorView RepOps non-guard setters (v0.164.0)
//
// Swap the geometry / mesh content bound to an existing rep id without recreating
// the rep. Pass a valid handle to bind, or skip — the bridge no-ops on null.

void OCCTBRepGraphRepSetSurface(OCCTBRepGraphRef _Nonnull graph, int32_t surfaceRepId, OCCTSurfaceRef _Nonnull surface);
void OCCTBRepGraphRepSetCurve3D(OCCTBRepGraphRef _Nonnull graph, int32_t curve3DRepId, OCCTCurve3DRef _Nonnull curve);
void OCCTBRepGraphRepSetCurve2D(OCCTBRepGraphRef _Nonnull graph, int32_t curve2DRepId, OCCTCurve2DRef _Nonnull curve);
void OCCTBRepGraphRepSetTriangulation(OCCTBRepGraphRef _Nonnull graph, int32_t triRepId, OCCTPolyTriangulationRef _Nonnull tri);
void OCCTBRepGraphRepSetPolygon3D(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygon3DRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygon2D(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygon2DRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygonOnTri(OCCTBRepGraphRef _Nonnull graph, int32_t polyRepId, OCCTPolyPolygonOnTriRef _Nonnull poly);
void OCCTBRepGraphRepSetPolygonOnTriTriangulationId(OCCTBRepGraphRef _Nonnull graph, int32_t polyOnTriRepId, int32_t triRepId);

// MARK: - BRepGraph MeshView cache entry inspection (v0.164.0)
//
// Detailed access to the algorithm-derived cache entries for diagnostics and
// non-destructive mesh tooling. All return 0/false/-1 for absent entries.

bool OCCTBRepGraphCachedFaceMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshTriRepCount(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshActiveIndex(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
uint32_t OCCTBRepGraphCachedFaceMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex);
int32_t OCCTBRepGraphCachedFaceMeshTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex, int32_t repIndex);

bool OCCTBRepGraphCachedEdgeMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
int32_t OCCTBRepGraphCachedEdgeMeshPolygon3DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);
uint32_t OCCTBRepGraphCachedEdgeMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex);

bool OCCTBRepGraphCachedCoEdgeMeshIsPresent(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygon2DRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepCount(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);
int32_t OCCTBRepGraphCachedCoEdgeMeshPolygonOnTriRepId(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex, int32_t repIndex);
uint32_t OCCTBRepGraphCachedCoEdgeMeshStoredOwnGen(OCCTBRepGraphRef _Nonnull graph, int32_t coedgeIndex);

// MARK: - BRepGraph ML Export & Sampling (v0.136.0)

/// Sample a regular UV grid on a face surface. Returns point count (uSamples * vSamples),
/// or 0 on failure. Caller provides output buffers: positions (count*3 doubles),
/// normals (count*3 doubles), gaussianCurvatures (count doubles), meanCurvatures (count doubles).
///
/// All four buffers share one layout: **U-major**, u varying slowest and v fastest, i.e. sample
/// (iu, iv) sits at `occtSurfaceGridIndex(iu, iv, vSamples)` == `iu * vSamples + iv` — the same
/// index every other surface grid in this bridge uses (#404/#486). Scalar buffers are indexed by
/// that value directly; the xyz buffers by `idx * 3 + {0,1,2}`.
///
/// This wrote the transposed `iv * uSamples + iu` until #617. Note what that defect did and did
/// not do: a transpose is a bijection onto the same `0..<uSamples * vSamples` range, so it is in
/// bounds at every aspect ratio and every reader of it got a silent wrong answer, never a trap.
/// (The out-of-range failure in this family needs a different slip, a caller striding by the
/// wrong count.) Do not re-spell the formula here — use the shared helper.
int32_t OCCTBRepGraphSampleFaceUVGrid(
    OCCTBRepGraphRef _Nonnull graph, int32_t faceIndex,
    int32_t uSamples, int32_t vSamples,
    double* _Nonnull outPositions, double* _Nonnull outNormals,
    double* _Nonnull outGaussianCurvatures, double* _Nonnull outMeanCurvatures);

/// Sample N evenly-spaced points along an edge curve.
/// Caller provides outPoints buffer of size count*3.
/// Returns actual number of points sampled (0 if edge has no curve).
int32_t OCCTBRepGraphSampleEdgeCurve(
    OCCTBRepGraphRef _Nonnull graph, int32_t edgeIndex,
    int32_t count, double* _Nonnull outPoints);

// MARK: - Durable identity (BRepGraph::UIDsView) — OCCT 8.0.0p1

/// Return the durable node UID for the node identified by (nodeKind, nodeIndex).
/// On success, writes the UID kind to *outUIDKind and the monotonic counter to
/// *outCounter, and returns true. Returns false (and leaves outputs untouched)
/// if the node is invalid/removed/out of bounds. counter == 0 is the invalid sentinel.
bool OCCTBRepGraphNodeUID(OCCTBRepGraphRef _Nonnull graph,
                          int32_t nodeKind, int32_t nodeIndex,
                          int32_t* _Nonnull outUIDKind, uint32_t* _Nonnull outCounter);

/// Resolve a node UID (uidKind, counter) back to a NodeId.
/// On success, writes the node kind to *outNodeKind and the per-kind index to
/// *outNodeIndex, and returns true. Returns false if the UID does not resolve.
bool OCCTBRepGraphNodeFromUID(OCCTBRepGraphRef _Nonnull graph,
                              int32_t uidKind, uint32_t counter,
                              int32_t* _Nonnull outNodeKind, int32_t* _Nonnull outNodeIndex);

/// True if a node UID (uidKind, counter) exists in this graph generation.
bool OCCTBRepGraphHasNodeUID(OCCTBRepGraphRef _Nonnull graph,
                             int32_t uidKind, uint32_t counter);

/// Return the durable reference UID for the reference (refKind, refIndex).
/// Writes the UID kind to *outUIDKind and the counter to *outCounter; returns
/// true on success, false if the reference is invalid/removed/out of bounds.
bool OCCTBRepGraphRefUID(OCCTBRepGraphRef _Nonnull graph,
                         int32_t refKind, int32_t refIndex,
                         int32_t* _Nonnull outUIDKind, uint32_t* _Nonnull outCounter);

/// Resolve a reference UID (uidKind, counter) back to a RefId.
/// Writes the ref kind to *outRefKind and the per-kind index to *outRefIndex;
/// returns true on success, false if the UID does not resolve.
bool OCCTBRepGraphRefFromUID(OCCTBRepGraphRef _Nonnull graph,
                             int32_t uidKind, uint32_t counter,
                             int32_t* _Nonnull outRefKind, int32_t* _Nonnull outRefIndex);

/// True if a reference UID (uidKind, counter) exists in this graph generation.
bool OCCTBRepGraphHasRefUID(OCCTBRepGraphRef _Nonnull graph,
                            int32_t uidKind, uint32_t counter);

/// Return the durable item UID for the node (nodeKind, nodeIndex).
/// Writes the item domain (1 = Node, 2 = Reference) to *outDomain, the kind to
/// *outKind, and the counter to *outCounter; returns true on success.
bool OCCTBRepGraphItemUIDOfNode(OCCTBRepGraphRef _Nonnull graph,
                                int32_t nodeKind, int32_t nodeIndex,
                                int32_t* _Nonnull outDomain, int32_t* _Nonnull outKind,
                                uint32_t* _Nonnull outCounter);

/// Resolve an item UID (domain, kind, counter) back to an item id.
/// Writes the item domain to *outDomain, the kind to *outKind and per-kind index
/// to *outIndex; returns true on success, false if the UID does not resolve.
bool OCCTBRepGraphItemFromUID(OCCTBRepGraphRef _Nonnull graph,
                              int32_t domain, int32_t kind, uint32_t counter,
                              int32_t* _Nonnull outDomain, int32_t* _Nonnull outKind,
                              int32_t* _Nonnull outIndex);

/// True if an item UID (domain, kind, counter) exists in this graph generation.
bool OCCTBRepGraphHasItemUID(OCCTBRepGraphRef _Nonnull graph,
                              int32_t domain, int32_t kind, uint32_t counter);

/// Return the current graph generation counter.
///
/// NOTE: always 1 in practice. OCCT advances it only from BRepGraph::Clear(); this bridge
/// calls Clear() exactly once, when it builds a graph (#303), and never rebuilds one, so the
/// counter lands at 1 and is identical for every graph. It cannot distinguish two graphs — use
/// OCCTBRepGraphInstanceID for that. See issues #295 and #303.
uint32_t OCCTBRepGraphGeneration(OCCTBRepGraphRef _Nonnull graph);

/// Return this graph's instance id — unique among every graph this process creates, and
/// distinct (with overwhelming probability) from ids minted by any other process.
///
/// A BRepGraph_UID is only meaningful inside the graph that minted it: counters restart
/// at 1 per graph, so a UID from one graph lands in another's valid range and resolves to
/// an unrelated node. Pairing a UID with this id is what lets the Swift layer reject a
/// foreign UID instead of silently returning a wrong node (#295). Never returns 0.
uint64_t OCCTBRepGraphInstanceID(OCCTBRepGraphRef _Nonnull graph);

#endif /* OCCTBridge_BRepGraph_h */
