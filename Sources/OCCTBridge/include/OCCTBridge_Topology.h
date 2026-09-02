//
//  OCCTBridge_Topology.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Topology domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Topology_h
#define OCCTBridge_Topology_h

// MARK: - Shape Conversion

OCCTShapeRef OCCTShapeFromWire(OCCTWireRef wireRef);
OCCTShapeRef OCCTShapeFromFace(OCCTFaceRef faceRef);

/// Construct a Face reference from a Shape that wraps a TopoDS_Face.
/// Returns NULL if the shape is null or its topology type is not TopAbs_FACE.
/// Caller owns the returned reference and must release it.
OCCTFaceRef OCCTFaceFromShape(OCCTShapeRef shape);

/// Construct a Wire reference from a Shape that wraps a TopoDS_Wire.
/// Returns NULL if the shape is null or its topology type is not TopAbs_WIRE.
/// Caller owns the returned reference and must release it.
OCCTWireRef OCCTWireFromShape(OCCTShapeRef shape);

// MARK: - Memory Management

void OCCTShapeRelease(OCCTShapeRef shape);
void OCCTWireRelease(OCCTWireRef wire);
void OCCTMeshRelease(OCCTMeshRef mesh);

// MARK: - Face Analysis (for solid-based CAM)

// === #614: two face enumerations, two contracts -- the split OCCT itself draws ===
//
// A face can appear in one shape twice with opposite orientations: the ordinary result of any BOP
// leaving two bodies that share a wall. What callers want from a face list is then two lists, and
// OCCT's own kernel already separates them. This bridge follows that split rather than inventing
// one. Read against the pinned 8.0.0p1 headers/sources:
//
//   * IDENTITY / INDEXING is orientation-INSENSITIVE upstream. TopoDS_Shape::IsSame is "same
//     TShape with the same Locations. Orientations may differ" (TopoDS_Shape.hxx:265-271);
//     IsEqual additionally requires the orientation (TopoDS_Shape.hxx:273-280).
//     TopTools_ShapeMapHasher's equality operator is exactly IsSame (TopTools_ShapeMapHasher.hxx
//     :35-38), and the ONLY type-filtered mapping function OCCT publishes,
//     TopExp::MapShapes(S, T, M), accepts only that hasher's map -- there is no oriented overload
//     (TopExp.hxx:57-60). It is literally an explorer walk piped into the map (TopExp.cxx:35-45),
//     and NCollection_IndexedMap::addImpl returns the existing index and leaves the stored key
//     untouched on a repeat (NCollection_IndexedMap.hxx:684-710), so the map keeps the FIRST
//     occurrence's orientation. Upstream's own canonical stable sub-shape index -- the one BREP
//     file persistence writes -- is this same IsSame map (TopTools_ShapeSet.hxx:192).
//
//   * GEOMETRY / NORMALS is orientation-SENSITIVE upstream, and is read off the TRAVERSAL, never
//     out of an indexed map. BRepGProp::VolumeProperties, where a face's orientation decides the
//     sign of the volume integral, walks a TopExp_Explorer and takes the orientation from
//     ex.Current() (BRepGProp.cxx:322-325). Its SkipShared branch is the exact case at issue: it
//     dedupes with IsSame maps but keeps TWO of them, aFwdFMap and aRvsFMap, one per orientation,
//     so a face present both FORWARD and REVERSED is visited ONCE PER ORIENTATION rather than
//     collapsed (BRepGProp.cxx:318-338). The oriented indexed map
//     (NCollection_IndexedMap<TopoDS_Shape>, deprecated alias TopTools_IndexedMapOfOrientedShape)
//     is used upstream only for internal algorithm bookkeeping -- TopOpeBRepBuild, BOPAlgo_Builder,
//     TopOpeBRepTool, BRepCheck_Wire, ChFi3d, BRepTools_ReShape -- never as a public sub-shape
//     enumeration. (Both typedefs are Standard_HEADER_DEPRECATED since 8.0.0 and live in
//     src/Deprecated/, hence the NCollection spellings above.)
//
// So: index by IsSame, orient by explorer. Measured on the pinned kernel (BRepAlgoAPI_Splitter,
// an origin-centred 10mm box -- Shape.box spans -5..5 -- cut by the z=4 plane, two solids):
// 12 face occurrences over 11 distinct faces; the shared wall is map index 2, stored FORWARD
// because the lower solid is visited first. Its centre is (0,0,4) and its normal (0,0,1), so
// against the lower solid's interior (0,0,-0.5) the dot is +4.5 (outward) and against the upper
// solid's (0,0,4.5) it is -0.5 (INWARD). The two occurrences are IsSame and not IsEqual.
//
// The same collapse reached the CAM helpers built on the face list: horizontalFaces() answered 3
// where the geometry has 4 horizontal occurrences, because the shared wall is horizontal from both
// sides and only one survived. Those helpers read the occurrence enumeration now.
//
// OCCTShapeGetFaces is the INDEXING enumeration and stays the IsSame map. OCCTShapeGetOrientedFaces
// is the GEOMETRY enumeration and is the explorer walk, added rather than substituted so no index
// moves. Its entries carry BOTH the parent-relative orientation and the OCCTShapeGetFaces index of
// the same face, so an oriented occurrence is still addressable by every index-taking entry point.

/// Get all faces from a shape -- the INDEXING enumeration, one entry per *distinct* face.
///
/// #614: each entry carries the orientation it has at its FIRST occurrence. On a shape where a
/// face occurs with both orientations (two solids sharing a wall), that orientation is correct for
/// one owner and inverted for the other, and so is the normal OCCTFaceGetNormalAtUV derives from
/// it. Use OCCTShapeGetOrientedFaces when the normal's direction matters; use this when the index
/// matters.
///
/// @param shape The shape to extract faces from
/// @param outCount Output: number of faces returned
/// @return Array of face references, or NULL on failure. Caller must free with OCCTFreeFaceArray.
OCCTFaceRef* OCCTShapeGetFaces(OCCTShapeRef shape, int32_t* outCount);

/// The number of face OCCURRENCES in a shape -- the length OCCTShapeGetOrientedFaces returns.
///
/// #614: this is a TopExp_Explorer walk, so a face reachable from two parents is counted once per
/// parent. It is >= OCCTShapeGetFaceCount, and equal to it on any shape that shares no face. Call
/// this to size the index buffer OCCTShapeGetOrientedFaces fills.
int32_t OCCTShapeGetFaceOccurrenceCount(OCCTShapeRef shape);

/// Get all faces from a shape -- the GEOMETRY enumeration, one entry per *occurrence*, each
/// carrying the orientation it has in the parent.
///
/// #614: this is the list to walk when the normal's direction matters. A face shared by two solids
/// appears twice, once per owner, each time with the orientation that makes
/// OCCTFaceGetNormalAtUV point OUT of that owner.
///
/// Array position here is NOT a face index -- it is an occurrence number, and two positions can
/// name the same face. The face index of each entry (its position in OCCTShapeGetFaces, the token
/// every index-taking entry point in this header expects) is written into `outIndices`, so an
/// entry keeps both properties.
///
/// @param shape The shape to extract faces from
/// @param outIndices Optional buffer receiving each entry's 0-based face index; may be NULL
/// @param indexCapacity Number of int32_t slots in `outIndices`; slots past it are not written
/// @param outCount Output: number of faces returned
/// @return Array of face references, or NULL on failure. Caller must free with OCCTFreeFaceArray.
OCCTFaceRef* OCCTShapeGetOrientedFaces(OCCTShapeRef shape,
                                       int32_t*     outIndices,
                                       int32_t      indexCapacity,
                                       int32_t*     outCount);

/// The orientation this face carries: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.
///
/// #614: OCCTFaceGetNormalAtUV reverses its normal exactly when this is REVERSED, so this is what
/// decides which side of the surface the reported normal points to. Returns 0 for a null face.
int32_t OCCTFaceGetOrientation(OCCTFaceRef face);

/// Free an array of faces (frees faces AND array)
/// @param faces Array of face references
/// @param count Number of faces in the array
void OCCTFreeFaceArray(OCCTFaceRef* faces, int32_t count);

/// Free only the face array container, not the faces - use when Swift takes ownership
/// @param faces Array of face references
void OCCTFreeFaceArrayOnly(OCCTFaceRef* faces);

/// Release a single face
void OCCTFaceRelease(OCCTFaceRef face);

/// Get the normal vector at the center of a face
/// @param face The face to get normal from
/// @param outNx, outNy, outNz Output: normal vector components
/// @return true if successful, false if normal could not be computed
bool OCCTFaceGetNormal(OCCTFaceRef face, double* outNx, double* outNy, double* outNz);

/// Get the outer wire (boundary) of a face
/// @param face The face to get outer wire from
/// @return Wire reference, or NULL on failure. Caller must release with OCCTWireRelease.
OCCTWireRef OCCTFaceGetOuterWire(OCCTFaceRef face);

/// Get the bounding box of a face
/// @param face The face to get bounds from
/// @return false when the box is void (no geometry contributed to it), the face is null, or OCCT
/// raised. A face whose measured box is genuinely zero-size returns true with six zeros, which is
/// why the six doubles alone cannot carry this distinction (#943).
bool OCCTFaceGetBounds(OCCTFaceRef face,
                       double*     minX,
                       double*     minY,
                       double*     minZ,
                       double*     maxX,
                       double*     maxY,
                       double*     maxZ);

/// Get the bounding box of a face from its exact geometry, ignoring any triangulation the face
/// may carry (#733). `OCCTFaceGetBounds` calls `BRepBndLib::Add` with `useTriangulation=true`
/// (the default), which OCCT's own docs say enlarges the box by the mesh's deflection whenever a
/// triangulation is present, so its answer silently depends on whether the shape happened to be
/// meshed before this call, not just on the face's geometry. This variant always passes
/// `useTriangulation=false`, so the result is deterministic across meshed and unmeshed shapes.
/// @param face The face to get bounds from
/// @return false when the box is void, the face is null, or OCCT raised -- see
/// ``OCCTFaceGetBounds`` (#943).
bool OCCTFaceGetBoundsExact(OCCTFaceRef face,
                            double*     minX,
                            double*     minY,
                            double*     minZ,
                            double*     maxX,
                            double*     maxY,
                            double*     maxZ);

/// Check if a face is planar (flat)
/// @param face The face to check
/// @return true if the face is planar
bool OCCTFaceIsPlanar(OCCTFaceRef face);

/// Get the Z level of a horizontal planar face
/// @param face The face to get Z from
/// @param outZ Output: Z coordinate of the face plane
/// @return true if face is horizontal and Z was computed, false otherwise
bool OCCTFaceGetZLevel(OCCTFaceRef face, double* outZ);

/// Get total number of faces in a shape.
///
/// #541: this count, OCCTShapeGetFaceAtIndex, OCCTShapeGetFaces and every entry point in this
/// header that takes a face index all read ONE enumeration: TopExp::MapShapes, one entry per
/// distinct face (TopoDS_Shape::IsSame -- same TShape and location, orientation ignored),
/// addressed 0-based. A face index is meaningful only against the shape it came from.
int32_t OCCTShapeGetFaceCount(OCCTShapeRef shape);

/// Get face by index (0-based)
/// @param shape The shape containing faces
/// @param index Face index (0-based)
/// @return Face reference, or NULL if index out of bounds
OCCTFaceRef OCCTShapeGetFaceAtIndex(OCCTShapeRef shape, int32_t index);

/// Get total number of edges in a shape
int32_t OCCTShapeGetTotalEdgeCount(OCCTShapeRef shape);

/// Get edge by index (0-based)
/// @param shape The shape containing edges
/// @param index Edge index (0-based)
/// @return Edge reference, or NULL if index out of bounds. Caller must release.
OCCTEdgeRef OCCTShapeGetEdgeAtIndex(OCCTShapeRef shape, int32_t index);

/// Release an edge reference
void OCCTEdgeRelease(OCCTEdgeRef edge);

/// Convert an edge to a shape
OCCTShapeRef OCCTShapeFromEdge(OCCTEdgeRef edgeRef);

/// Construct an Edge reference from a Shape that wraps a TopoDS_Edge.
/// Returns NULL if the shape is null or its topology type is not TopAbs_EDGE.
/// Caller owns the returned reference and must release it.
OCCTEdgeRef OCCTEdgeFromShape(OCCTShapeRef shape);

/// Get edge length
double OCCTEdgeGetLength(OCCTEdgeRef edge);

/// Get edge bounding box
/// @return false when the box is void, the edge is null, or OCCT raised -- see
/// ``OCCTFaceGetBounds`` (#943).
bool OCCTEdgeGetBounds(OCCTEdgeRef edge,
                       double*     minX,
                       double*     minY,
                       double*     minZ,
                       double*     maxX,
                       double*     maxY,
                       double*     maxZ);

/// Get points along edge curve
/// @param edge The edge to sample
/// @param count Number of points to generate
/// @param outPoints Output array [x,y,z,...] (caller allocates count*3 doubles)
/// @return Actual number of points written
int32_t OCCTEdgeGetPoints(OCCTEdgeRef edge, int32_t count, double* outPoints);

/// Check if edge is a line
bool OCCTEdgeIsLine(OCCTEdgeRef edge);

/// Check if edge is a circle/arc
bool OCCTEdgeIsCircle(OCCTEdgeRef edge);

/// Get start and end vertices of edge
void OCCTEdgeGetEndpoints(OCCTEdgeRef edge,
                          double*     startX,
                          double*     startY,
                          double*     startZ,
                          double*     endX,
                          double*     endY,
                          double*     endZ);

// MARK: - Point Classification (v0.17.0)

/// Classification result: 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
typedef int32_t OCCTTopAbsState;

/// Classify a point relative to a solid
OCCTTopAbsState OCCTClassifyPointInSolid(OCCTShapeRef solid,
                                         double       px,
                                         double       py,
                                         double       pz,
                                         double       tolerance);

/// Classify a point relative to a face (using 3D point)
OCCTTopAbsState OCCTClassifyPointOnFace(OCCTFaceRef face,
                                        double      px,
                                        double      py,
                                        double      pz,
                                        double      tolerance);

/// Classify a point relative to a face (using UV parameters)
OCCTTopAbsState OCCTClassifyPointOnFaceUV(OCCTFaceRef face, double u, double v, double tolerance);

// MARK: - Wire Explorer (v0.29.0)

/// Get the number of edges in a wire by ordered traversal.
/// @param wire The wire to explore
/// @return Number of edges
int32_t OCCTWireExplorerEdgeCount(OCCTWireRef wire);

/// Get a discretized edge from a wire by ordered traversal index.
/// @param wire The wire to explore
/// @param index 0-based edge index
/// @param outPoints Output buffer for xyz triples [x,y,z,...]
/// @param maxPoints Maximum number of points to output
/// @param outPointCount Output: actual number of points written
/// @return true on success
bool OCCTWireExplorerGetEdge(OCCTWireRef wire,
                             int32_t     index,
                             double*     outPoints,
                             int32_t     maxPoints,
                             int32_t*    outPointCount);

/// Get the number of discretized points for an edge in a wire.
/// @param wire The wire to explore
/// @param index 0-based edge index
/// @return Number of points, or 0 on failure
int32_t OCCTWireExplorerGetEdgePointCount(OCCTWireRef wire, int32_t index);

// MARK: - Sub-Shape Replacement (v0.29.0)

/// Replace a sub-shape within a shape.
/// @param shape The parent shape
/// @param oldSub Sub-shape to replace
/// @param newSub Replacement sub-shape
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeReplaceSubShape(OCCTShapeRef shape, OCCTShapeRef oldSub, OCCTShapeRef newSub);

/// Remove a sub-shape from a shape.
/// @param shape The parent shape
/// @param subToRemove Sub-shape to remove
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSubShape(OCCTShapeRef shape, OCCTShapeRef subToRemove);

// MARK: - Shape Contents (v0.30.0)

/// Structure containing counts of topological entities in a shape.
typedef struct
{
  int32_t nbSolids;    ///< Number of solids
  int32_t nbShells;    ///< Number of shells
  int32_t nbFaces;     ///< Number of faces
  int32_t nbWires;     ///< Number of wires
  int32_t nbEdges;     ///< Number of edges
  int32_t nbVertices;  ///< Number of vertices
  int32_t nbFreeEdges; ///< Number of free (unattached) edges
  int32_t nbFreeWires; ///< Number of free (unattached) wires
  int32_t nbFreeFaces; ///< Number of free (unattached) faces
} OCCTShapeContents;

/// Analyze shape contents and return counts of topological entities.
/// @param shape The shape to analyze
/// @return Structure with entity counts (all zeros on failure)
OCCTShapeContents OCCTShapeGetContents(OCCTShapeRef shape);

// MARK: - Edge Analysis (v0.30.0)

/// Check if an edge has a 3D curve representation.
/// @param edge The edge shape
/// @return true if the edge has a 3D curve
bool OCCTEdgeHasCurve3D(OCCTShapeRef edge);

/// Check if an edge is closed (start == end) in 3D.
/// @param edge The edge shape
/// @return true if the edge is closed
bool OCCTEdgeIsClosed3D(OCCTShapeRef edge);

/// Check if an edge is a seam edge on a face.
/// @param edge The edge shape
/// @param face The face shape
/// @return true if the edge is a seam edge on the face
bool OCCTEdgeIsSeam(OCCTShapeRef edge, OCCTShapeRef face);

// MARK: - Find Surface (v0.30.0)

/// Find a surface that approximates a shape (wire, set of edges, etc.).
/// @param shape The shape to find a surface for
/// @param tolerance Approximation tolerance
/// @return Surface reference, or NULL if not found
OCCTSurfaceRef OCCTShapeFindSurface(OCCTShapeRef shape, double tolerance);

// MARK: - Contiguous Edges (v0.30.0)

/// Find contiguous edge pairs in a shape.
/// @param shape The shape to analyze
/// @param tolerance Contiguity tolerance
/// @return Number of contiguous edge pairs found, or 0 on failure
int32_t OCCTShapeFindContiguousEdges(OCCTShapeRef shape, double tolerance);

// MARK: - Wire Analysis (v0.37.0)

/// Result of wire topology analysis.
typedef struct
{
  bool    isClosed;
  bool    hasSmallEdges;
  bool    hasGaps3d;
  bool    hasSelfIntersection;
  bool    isOrdered;
  double  minDistance3d;
  double  maxDistance3d;
  int32_t edgeCount;
} OCCTWireAnalysisResult;

/// Analyze wire topology for potential issues.
/// @param wire The wire to analyze
/// @param tolerance Analysis tolerance
/// @param result Output analysis result
/// @return true if analysis completed
bool OCCTWireAnalyze(OCCTWireRef wire, double tolerance, OCCTWireAnalysisResult* result);

// MARK: - Oriented Bounding Box (v0.38.0)

/// Oriented bounding box result
typedef struct
{
  double centerX, centerY, centerZ; // center point
  double xDirX, xDirY, xDirZ;       // X-axis direction
  double yDirX, yDirY, yDirZ;       // Y-axis direction
  double zDirX, zDirY, zDirZ;       // Z-axis direction
  double halfX, halfY, halfZ;       // half-dimensions along each axis
} OCCTOrientedBoundingBox;

/// Compute an oriented bounding box for a shape.
/// @param shape The shape to bound
/// @param optimal If true, compute tighter (but slower) OBB
/// @param result Output OBB structure
/// @return true on success
bool OCCTShapeOrientedBoundingBox(OCCTShapeRef             shape,
                                  bool                     optimal,
                                  OCCTOrientedBoundingBox* result);

/// Get the volume of the oriented bounding box.
/// @param result Pointer to an OBB structure
/// @return Volume (8 * halfX * halfY * halfZ)
double OCCTOrientedBoundingBoxVolume(const OCCTOrientedBoundingBox* result);

/// Get the 8 corner points of the oriented bounding box.
/// @param result Pointer to an OBB structure
/// @param outCorners Output array of 24 doubles (8 corners * 3 coordinates)
void OCCTOrientedBoundingBoxCorners(const OCCTOrientedBoundingBox* result, double* outCorners);

// MARK: - Deep Shape Copy (v0.38.0)

/// Create a deep copy of a shape (independent geometry).
/// @param shape The shape to copy
/// @param copyGeom If true, copy geometry (otherwise share it)
/// @param copyMesh If true, also copy mesh data
/// @return New independent shape, or NULL on failure
OCCTShapeRef OCCTShapeCopy(OCCTShapeRef shape, bool copyGeom, bool copyMesh);

// MARK: - Outer / Inner Shells (v0.38.0)
//
// Solid, shell and wire sub-shapes are no longer extracted here: OCCTShapeGetSolidCount/GetSolids,
// GetShellCount/GetShells and GetWireCount/GetWires each walked a bare TopExp_Explorer, which
// counts occurrences rather than distinct sub-shapes and so disagreed with the generic
// OCCTShapeGetSubShapeCount/GetSubShapes/GetSubShapeByTypeIndex below on any shape whose
// sub-shape is reachable from two parents. Use the generic family with type 2/3/5. #502

/// Outer shell of a solid (BRepClass3d::OuterShell); NULL if not a solid / no shell.
/// A container (compound/compsolid) is accepted only when it holds exactly ONE solid, with two
/// or more there is no single outer shell to name, so this returns NULL rather than answering
/// for an arbitrary member. Use OCCTShapeOuterShells for a multi-solid shape. #211, #439
OCCTShapeRef OCCTShapeOuterShell(OCCTShapeRef shape);

/// Outer shell of EVERY solid in a shape, in explorer order (one per solid). Count-then-fill:
/// outShells=NULL returns a sizing UPPER BOUND (the solid count) rather than an exact count, so
/// the query stays one traversal, classifying there would make every caller pay
/// BRepClass3d::OuterShell twice per solid. The fill call returns the exact number written, which
/// may be smaller (a solid with no usable outer shell is skipped). 0 for a shape with no solids.
/// #439
int32_t OCCTShapeOuterShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount);

/// Inner (void/cavity) shells of a solid, all shells except the outer one. Count-then-fill
/// (pass outShells=NULL to query the count). Same single-solid rule as OCCTShapeOuterShell:
/// 0 for a container holding two or more solids. #212, #439
int32_t OCCTShapeInnerShells(OCCTShapeRef shape, OCCTShapeRef* outShells, int32_t maxCount);

// MARK: - Shape Axis Extraction (v0.137)

/// Axis record emitted by OCCTShapeRevolutionAxes / OCCTShapeSymmetryAxes.
/// kind: 1=cylinder, 2=cone, 3=sphere, 4=torus, 5=revolution, 6=extrusion, 7=symmetry
typedef struct
{
  double originX, originY, originZ;
  double directionX, directionY, directionZ;
  double extentMin; // along direction from origin (-inf as -DBL_MAX)
  double extentMax; // +inf as DBL_MAX
  bool   hasExtent; // false only when the axis's own shape has no boundable geometry at
                    // all (an empty/void bounding box); an unbounded-but-real shape still
                    // reports true, with extentMin/extentMax at the +-DBL_MAX sentinels
                    // above (#763)
  int32_t kind;
} OCCTShapeAxis;

/// Collect revolution axes from all cylindrical/conical/toroidal/revolved faces in a shape.
/// Axes are deduplicated by origin+direction within the given tolerance. Returns count,
/// writes up to maxAxes entries into outAxes. Returns -1 on failure.
int32_t OCCTShapeRevolutionAxes(OCCTShapeRef _Nonnull shape,
                                double tolerance,
                                OCCTShapeAxis* _Nonnull outAxes,
                                int32_t maxAxes);

/// Detect symmetry axes from principal moments of inertia, when two moments are nearly
/// equal (within fractionalTolerance of the larger), the third is a symmetry axis.
/// Returns count (0 for none, 1 for rotational symmetry, 3 for spherical symmetry).
int32_t OCCTShapeSymmetryAxes(OCCTShapeRef _Nonnull shape,
                              double fractionalTolerance,
                              OCCTShapeAxis* _Nonnull outAxes,
                              int32_t maxAxes);

/// Distance solution entry
typedef struct
{
  double point1X, point1Y, point1Z;
  double point2X, point2Y, point2Z;
  double distance;
} OCCTDistanceSolution;

/// Compute all distance solutions between two shapes
/// @param outSolutions Pre-allocated array for results
/// @param maxSolutions Maximum number of solutions to return
/// @return Number of solutions found, -1 on failure
int32_t OCCTShapeAllDistanceSolutions(OCCTShapeRef          shape1,
                                      OCCTShapeRef          shape2,
                                      OCCTDistanceSolution* outSolutions,
                                      int32_t               maxSolutions);

/// Check if one shape is fully inside another (inner solution)
/// @return 1 if inner, 0 if not inner, -1 on failure
int32_t OCCTShapeIsInnerDistance(OCCTShapeRef shape1, OCCTShapeRef shape2);

/// Distance solution detail: support type and parametric location.
/// supportType: 0=Vertex, 1=OnEdge, 2=InFace
typedef struct
{
  int32_t supportType1;
  int32_t supportType2;
  double  paramEdge1;  // parameter on edge (if supportType1 == 1)
  double  paramEdge2;  // parameter on edge (if supportType2 == 1)
  double  paramFaceU1; // U parameter on face (if supportType1 == 2)
  double  paramFaceV1; // V parameter on face (if supportType1 == 2)
  double  paramFaceU2; // U parameter on face (if supportType2 == 2)
  double  paramFaceV2; // V parameter on face (if supportType2 == 2)
} OCCTDistanceSolutionDetail;

/// Get detailed parametric info for a distance solution.
/// @param solutionIndex 0-based solution index
/// @return true on success
bool OCCTShapeDistanceSolutionDetail(OCCTShapeRef _Nonnull shape1,
                                     OCCTShapeRef _Nonnull shape2,
                                     int32_t solutionIndex,
                                     OCCTDistanceSolutionDetail* _Nonnull outDetail);

/// Decompose a BSpline surface into Bezier patches
/// @param surface BSpline surface reference
/// @param outPatches Pre-allocated array of surface refs for output patches
/// @param maxPatches Maximum patches to return
/// @param outNbUPatches Number of patches in U direction
/// @param outNbVPatches Number of patches in V direction
/// @return Total number of patches, or -1 on failure
int32_t OCCTSurfaceBSplineToBezierPatches(OCCTSurfaceRef  surface,
                                          OCCTSurfaceRef* outPatches,
                                          int32_t         maxPatches,
                                          int32_t*        outNbUPatches,
                                          int32_t*        outNbVPatches);

/// Find continuity break parameters in a BSpline curve
/// @param curve3D BSpline curve reference
/// @param continuityOrder Minimum continuity to require, as a literal derivative order: a knot
///   splits when `degree - multiplicity < continuityOrder`. Useful domain 0...degree, saturating
///   there: a cubic with simple interior knots needs 3. See the #480 note in
///   OCCTBridge_Internal.h. A negative order throws, which surfaces here as -1
/// @param outParams Pre-allocated array for break parameters
/// @param maxParams Maximum number of parameters to return
/// @return Number of break parameters found, or -1 on failure
int32_t OCCTCurve3DBSplineKnotSplits(OCCTCurve3DRef curve3D,
                                     int32_t        continuityOrder,
                                     double*        outParams,
                                     int32_t        maxParams);

/// Find the underlying geometric surface of a shape (wire, edge set) with options
/// @param shape Shape whose edges define a surface
/// @param tolerance Tolerance for surface detection
/// @param onlyPlane If true, only look for planar surfaces
/// @param outFound Set to true if a surface was found
/// @return Surface reference, or NULL if not found
OCCTSurfaceRef OCCTShapeFindSurfaceEx(OCCTShapeRef shape,
                                      double       tolerance,
                                      bool         onlyPlane,
                                      bool*        outFound);

// MARK: - v0.41.0: Shape Surgery, Plane Detection, Geometry Conversion

/// Remove sub-shapes from a shape using BRepTools_ReShape
/// @param shape Base shape
/// @param subShapes Array of sub-shape handles to remove
/// @param count Number of sub-shapes to remove
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeRemoveSubShapes(OCCTShapeRef shape, OCCTShapeRef* subShapes, int32_t count);

/// Replace sub-shapes in a shape using BRepTools_ReShape
/// @param shape Base shape
/// @param oldShapes Array of old sub-shapes
/// @param newShapes Array of new sub-shapes (must match oldShapes count)
/// @param count Number of replacements
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeReplaceSubShapes(OCCTShapeRef  shape,
                                       OCCTShapeRef* oldShapes,
                                       OCCTShapeRef* newShapes,
                                       int32_t       count);

/// Find if a shape's edges lie in a plane
/// @param shape Shape to analyze
/// @param tolerance Tolerance for planarity check
/// @param outNormalX/Y/Z Plane normal (set if found)
/// @param outOriginX/Y/Z Plane origin (set if found)
/// @return true if a plane was found
bool OCCTShapeFindPlane(OCCTShapeRef shape,
                        double       tolerance,
                        double*      outNormalX,
                        double*      outNormalY,
                        double*      outNormalZ,
                        double*      outOriginX,
                        double*      outOriginY,
                        double*      outOriginZ);

// MARK: - Sub-Shape Extraction (fixes #36)
//
// The bridge's ONE sub-shape enumeration, for every topological type. Each entry is a distinct
// sub-shape (TopoDS_Shape::IsSame: same TShape and location, orientation ignored), in
// TopExp_Explorer order; a sub-shape reachable from two parents appears once, at the position of
// its first visit. A shape is its own sub-shape when it is of the requested type. The fixed-type
// counts elsewhere in this header (OCCTShapeGetFaceCount, OCCTShapeGetTotalEdgeCount,
// OCCTShapeGetVertexCount, OCCTShapeUniqueSubShapeCount and its edge/face/vertex convenience
// forms) all read this same enumeration. #502

/// Count sub-shapes of a given topological type
/// @param shape The parent shape
/// @param type TopAbs_ShapeEnum value (0=COMPOUND..7=VERTEX); out of range counts 0
/// @return Number of distinct sub-shapes of that type
int32_t OCCTShapeGetSubShapeCount(OCCTShapeRef shape, int32_t type);

/// Get sub-shapes of a given topological type, in enumeration order
/// @param shape The parent shape
/// @param type TopAbs_ShapeEnum value (0=COMPOUND..7=VERTEX)
/// @param outSubShapes Output array, caller-allocated (size it with OCCTShapeGetSubShapeCount)
/// @param maxCount Capacity of outSubShapes
/// @return Number of sub-shapes actually written
int32_t OCCTShapeGetSubShapes(OCCTShapeRef  shape,
                              int32_t       type,
                              OCCTShapeRef* outSubShapes,
                              int32_t       maxCount);

/// Get a sub-shape by type and 0-based index
/// @param shape The parent shape
/// @param type TopAbs_ShapeEnum value
/// @param index 0-based index
/// @return Sub-shape as OCCTShapeRef, or NULL if out of range
OCCTShapeRef OCCTShapeGetSubShapeByTypeIndex(OCCTShapeRef shape, int32_t type, int32_t index);

// --- BRepExtrema_SelfIntersection ---

/// Result of self-intersection check
typedef struct
{
  int32_t overlapCount; ///< Number of overlapping triangle pairs
  bool    isDone;       ///< Whether the check completed
} OCCTSelfIntersectionResult;

/// Check a shape for self-intersection using BVH-accelerated triangle mesh overlap.
/// The shape should be meshed first (will be auto-meshed if not).
/// @param shape Shape to check
/// @param tolerance Tolerance for detecting intersections
/// @param meshDeflection Mesh deflection for auto-meshing (default 0.5)
/// @return Self-intersection result
OCCTSelfIntersectionResult OCCTShapeSelfIntersection(OCCTShapeRef shape,
                                                     double       tolerance,
                                                     double       meshDeflection);

// MARK: - v0.46.0: BRepOffset_Analyse, Approx_Curve3d, LocOpe_Prism, Volume Inertia

// --- BRepOffset_Analyse: Edge convexity classification ---

/// Edge concavity type from BRepOffset_Analyse
typedef enum
{
  OCCTConcavityConvex  = 0,
  OCCTConcavityConcave = 1,
  OCCTConcavityTangent = 2
} OCCTConcavityType;

/// Result for a single edge classification
typedef struct
{
  OCCTConcavityType type;
} OCCTEdgeConcavity;

/// Analyze edge convexity/concavity in a shape.
/// @param shape Shape to analyze
/// @param angle Threshold angle for tangent classification (radians)
/// @param outEdgeTypes Output array of edge concavity types (must hold shapeEdgeCount entries)
/// @param maxEntries Maximum entries in output array
/// @return Number of edges classified, or -1 on error
int32_t OCCTShapeAnalyzeEdgeConcavity(OCCTShapeRef       shape,
                                      double             angle,
                                      OCCTEdgeConcavity* outEdgeTypes,
                                      int32_t            maxEntries);

/// Count edges of a specific concavity type in a shape.
/// @param shape Shape to analyze
/// @param angle Threshold angle for tangent classification
/// @param type Concavity type to count (0=convex, 1=concave, 2=tangent)
/// @return Number of edges of that type, or -1 on error
int32_t OCCTShapeCountEdgeConcavity(OCCTShapeRef shape, double angle, int32_t type);

// --- BRepExtrema_ExtCC ---

/// Edge-edge extrema result
typedef struct
{
  double  distance;         // Minimum distance
  double  paramOnE1;        // Parameter on first edge
  double  paramOnE2;        // Parameter on second edge
  double  pt1x, pt1y, pt1z; // Closest point on edge 1
  double  pt2x, pt2y, pt2z; // Closest point on edge 2
  bool    isParallel;       // Whether edges are parallel
  int32_t solutionCount;    // Number of extrema
} OCCTEdgeEdgeExtremaResult;

/// Compute distance extrema between two edges.
/// @param shape1 Shape containing first edge
/// @param edgeIndex1 Index of first edge (0-based)
/// @param shape2 Shape containing second edge
/// @param edgeIndex2 Index of second edge (0-based)
/// @return Extrema result
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCC(OCCTShapeRef shape1,
                                               int32_t      edgeIndex1,
                                               OCCTShapeRef shape2,
                                               int32_t      edgeIndex2);

/// Compute distance extrema between two standalone edges (from wire shapes).
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @return Extrema result
OCCTEdgeEdgeExtremaResult OCCTBRepExtremaExtCCEdges(OCCTShapeRef edge1, OCCTShapeRef edge2);

// --- BRepExtrema_ExtPF ---

/// Point-face extrema result
typedef struct
{
  double  distance;      // Minimum distance
  double  u, v;          // Parameters on face
  double  ptx, pty, ptz; // Closest point on face
  int32_t solutionCount;
} OCCTPointFaceExtremaResult;

/// Compute distance from a point to a face.
/// @param px,py,pz Point coordinates
/// @param shape Shape containing the face
/// @param faceIndex Face index (0-based)
/// @return Extrema result
OCCTPointFaceExtremaResult OCCTBRepExtremaExtPF(double       px,
                                                double       py,
                                                double       pz,
                                                OCCTShapeRef shape,
                                                int32_t      faceIndex);

// --- BRepExtrema_ExtFF ---

/// Face-face extrema result
typedef struct
{
  double  distance;
  double  u1, v1; // Parameters on face 1
  double  u2, v2; // Parameters on face 2
  double  pt1x, pt1y, pt1z;
  double  pt2x, pt2y, pt2z;
  int32_t solutionCount;
} OCCTFaceFaceExtremaResult;

/// Compute distance extrema between two faces.
/// @param shape1 Shape containing first face
/// @param faceIndex1 First face index (0-based)
/// @param shape2 Shape containing second face
/// @param faceIndex2 Second face index (0-based)
/// @return Extrema result
OCCTFaceFaceExtremaResult OCCTBRepExtremaExtFF(OCCTShapeRef shape1,
                                               int32_t      faceIndex1,
                                               OCCTShapeRef shape2,
                                               int32_t      faceIndex2);

// MARK: - v0.49.0: BRepExtrema_ExtPC, ExtCF, FreeBounds, ShapeCustom, ShapeFix, Surface/Curve
// expansion

// --- BRepExtrema_ExtPC ---

/// Point-edge extrema result
typedef struct
{
  double  distance;      // Minimum distance over the edge, ends included (#580)
  double  parameter;     // Parameter on edge at the nearest point
  double  ptx, pty, ptz; // Nearest point on edge
  int32_t solutionCount; // Number of perpendicular feet BRepExtrema_ExtPC found; 0 is a
                         // reportable state, not a failure -- see below
  bool isValid;          // false only when there is no such edge, or it has no 3D curve
} OCCTPointEdgeExtremaResult;

/// Compute the minimum distance from a point to an edge of a shape, over the whole edge.
///
/// The distance/parameter/point are the minimum over the edge's own range including its two ends,
/// via occtNearestPointOnCurveRange -- the same helper behind OCCTEdgeProjectPoint, so the two
/// cannot disagree about the same point and the same edge. This used to report the minimum over
/// BRepExtrema_ExtPC's extrema instead, which excludes the ends and can consist of a single
/// MAXIMUM: a point below a half circle of radius 5 read as 11 away when it is 7.81 away, and a
/// point past the end of a trimmed segment had no answer at all (#580).
///
/// `solutionCount` keeps both its meaning and its source: how many extrema BRepExtrema_ExtPC found,
/// which is how many perpendicular feet the point has on the edge. It is no longer a success flag.
/// Zero means the nearest point is one of the ends, which is worth reporting rather than refusing.
///
/// @param px,py,pz Point coordinates
/// @param shape Shape containing the edge
/// @param edgeIndex Edge index (0-based, in the enumeration Shape.edges() reads)
/// @return Nearest-point result; check isValid, not solutionCount
OCCTPointEdgeExtremaResult OCCTBRepExtremaExtPC(double       px,
                                                double       py,
                                                double       pz,
                                                OCCTShapeRef shape,
                                                int32_t      edgeIndex);

// --- BRepExtrema_ExtCF ---

/// Edge-face (curve-face) extrema result
typedef struct
{
  double  distance;
  double  paramOnEdge;
  double  uOnFace, vOnFace;
  double  edgePtx, edgePty, edgePtz;
  double  facePtx, facePty, facePtz;
  int32_t solutionCount;
  bool    isParallel;
} OCCTEdgeFaceExtremaResult;

/// Compute distance extrema between an edge and a face.
/// @param shape1 Shape containing the edge
/// @param edgeIndex Edge index (0-based)
/// @param shape2 Shape containing the face
/// @param faceIndex Face index (0-based)
/// @return Extrema result (minimum distance solution)
OCCTEdgeFaceExtremaResult OCCTBRepExtremaExtCF(OCCTShapeRef shape1,
                                               int32_t      edgeIndex,
                                               OCCTShapeRef shape2,
                                               int32_t      faceIndex);

/// Result of polyhedral distance computation.
typedef struct
{
  double distance;      // Polyhedral distance between shapes
  double p1x, p1y, p1z; // Closest point on shape 1
  double p2x, p2y, p2z; // Closest point on shape 2
  bool   success;       // True if computation succeeded
} OCCTPolyDistanceResult;

/// Compute fast polyhedral (approximate) distance between two shapes.
/// Shapes must be meshed beforehand (BRepMesh_IncrementalMesh).
OCCTPolyDistanceResult OCCTShapePolyhedralDistance(OCCTShapeRef shape1, OCCTShapeRef shape2);

// MARK: - IntCurvesFace. Curve-Face Intersection (v0.61.0)

/// Intersect a line with a face. Returns number of intersection points.
/// outPoints must have space for maxPts * 3 doubles (x,y,z triples).
/// outParams must have space for maxPts doubles (w parameter on line).
int32_t OCCTIntersectLineFace(OCCTShapeRef face,
                              double       origX,
                              double       origY,
                              double       origZ,
                              double       dirX,
                              double       dirY,
                              double       dirZ,
                              double       pInf,
                              double       pSup,
                              double*      outPoints,
                              double*      outParams,
                              int32_t      maxPts);

// --- IntCurvesFace_ShapeIntersector ---

/// Intersect a ray with all faces of a shape.
/// @param shape The shape to intersect
/// @param ox,oy,oz Ray origin
/// @param dx,dy,dz Ray direction
/// @param outPoints Output array of (x,y,z) triples, caller must free with free()
/// @param outParams Output array of parameter values along ray, caller must free with free()
/// @param outCount Number of intersection points
/// @return true if intersections found
bool OCCTIntCurvesFaceShapeIntersect(OCCTShapeRef shape,
                                     double       ox,
                                     double       oy,
                                     double       oz,
                                     double       dx,
                                     double       dy,
                                     double       dz,
                                     double* _Nullable* _Nonnull outPoints,
                                     double* _Nullable* _Nonnull outParams,
                                     int32_t* outCount);

/// Find the nearest intersection of a ray with a shape.
/// @return true if an intersection was found, with the point in outX/Y/Z and parameter in outParam
bool OCCTIntCurvesFaceShapeIntersectNearest(OCCTShapeRef shape,
                                            double       ox,
                                            double       oy,
                                            double       oz,
                                            double       dx,
                                            double       dy,
                                            double       dz,
                                            double*      outX,
                                            double*      outY,
                                            double*      outZ,
                                            double*      outParam);

// --- TopTrans_SurfaceTransition ---

/// Compute surface transition states for a boundary crossing.
/// @param tgtX/Y/Z Tangent direction of the boundary
/// @param normX/Y/Z Normal of the reference surface
/// @param surfNormX/Y/Z Normal of the crossing surface
/// @param tolerance Tolerance for angle comparison
/// @param surfOrientation Orientation of the crossing surface (0=FORWARD, 1=REVERSED)
/// @param boundOrientation Orientation of the boundary (0=FORWARD, 1=REVERSED)
/// @param outStateBefore Output: state before crossing (0=IN, 1=OUT, 2=ON, 3=UNKNOWN)
/// @param outStateAfter Output: state after crossing (0=IN, 1=OUT, 2=ON, 3=UNKNOWN)
void OCCTTopTransSurfaceTransition(double  tgtX,
                                   double  tgtY,
                                   double  tgtZ,
                                   double  normX,
                                   double  normY,
                                   double  normZ,
                                   double  surfNormX,
                                   double  surfNormY,
                                   double  surfNormZ,
                                   double  tolerance,
                                   int32_t surfOrientation,
                                   int32_t boundOrientation,
                                   int32_t* _Nonnull outStateBefore,
                                   int32_t* _Nonnull outStateAfter);

/// Compute surface transition with curvature information.
void OCCTTopTransSurfaceTransitionCurvature(double  tgtX,
                                            double  tgtY,
                                            double  tgtZ,
                                            double  normX,
                                            double  normY,
                                            double  normZ,
                                            double  maxDX,
                                            double  maxDY,
                                            double  maxDZ,
                                            double  minDX,
                                            double  minDY,
                                            double  minDZ,
                                            double  maxCurv,
                                            double  minCurv,
                                            double  surfNormX,
                                            double  surfNormY,
                                            double  surfNormZ,
                                            double  surfMaxDX,
                                            double  surfMaxDY,
                                            double  surfMaxDZ,
                                            double  surfMinDX,
                                            double  surfMinDY,
                                            double  surfMinDZ,
                                            double  surfMaxCurv,
                                            double  surfMinCurv,
                                            double  tolerance,
                                            int32_t surfOrientation,
                                            int32_t boundOrientation,
                                            int32_t* _Nonnull outStateBefore,
                                            int32_t* _Nonnull outStateAfter);

// MARK: - v0.68.0: TKGeomAlgo Part 2. CurveTransition, Trihedrons, NSections, Law, GccAna, Intf

// --- TopTrans_CurveTransition ---
/// Compute curve transition states at a boundary crossing (simple, no curvature).
void OCCTTopTransCurveTransition(double  tgtX,
                                 double  tgtY,
                                 double  tgtZ,
                                 double  tangX,
                                 double  tangY,
                                 double  tangZ,
                                 double  normX,
                                 double  normY,
                                 double  normZ,
                                 double  curvature,
                                 double  tolerance,
                                 int32_t surfOrientation,
                                 int32_t boundOrientation,
                                 int32_t* _Nonnull outStateBefore,
                                 int32_t* _Nonnull outStateAfter);

/// Compute curve transition states with curvature on the boundary curve.
void OCCTTopTransCurveTransitionWithCurvature(double  tgtX,
                                              double  tgtY,
                                              double  tgtZ,
                                              double  curveNormX,
                                              double  curveNormY,
                                              double  curveNormZ,
                                              double  curveCurv,
                                              double  tangX,
                                              double  tangY,
                                              double  tangZ,
                                              double  normX,
                                              double  normY,
                                              double  normZ,
                                              double  surfCurv,
                                              double  tolerance,
                                              int32_t surfOrientation,
                                              int32_t boundOrientation,
                                              int32_t* _Nonnull outStateBefore,
                                              int32_t* _Nonnull outStateAfter);

// --- TopCnx_EdgeFaceTransition ---

/// Result of edge-face transition computation.
typedef struct
{
  int32_t transition;         ///< TopAbs_Orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL
  int32_t boundaryTransition; ///< TopAbs_Orientation for boundary
} OCCTEdgeFaceTransitionResult;

/// Compute cumulated edge-face transition for multiple face interferences on an edge.
/// @param edgeTangentX,Y,Z Edge tangent direction
/// @param edgeNormalX,Y,Z Edge normal direction (0,0,0 for linear edge)
/// @param edgeCurvature Edge curvature (0 for linear edge)
/// @param faceTangentX,Y,Z Array of face tangent directions (3 doubles per face)
/// @param faceNormalX,Y,Z Array of face normal directions (3 doubles per face)
/// @param faceCurvatures Array of face curvatures at edge
/// @param faceOrientations Array of face orientations (TopAbs_Orientation values)
/// @param faceTransitions Array of face transitions (TopAbs_Orientation values)
/// @param faceBoundaryTr Array of face boundary transitions (TopAbs_Orientation values)
/// @param tolerances Array of tolerances per face
/// @param faceCount Number of faces
/// @return Transition result
OCCTEdgeFaceTransitionResult OCCTTopCnxEdgeFaceTransition(
  double edgeTangentX,
  double edgeTangentY,
  double edgeTangentZ,
  double edgeNormalX,
  double edgeNormalY,
  double edgeNormalZ,
  double edgeCurvature,
  const double* _Nonnull faceTangents,
  const double* _Nonnull faceNormals,
  const double* _Nonnull faceCurvatures,
  const int32_t* _Nonnull faceOrientations,
  const int32_t* _Nonnull faceTransitions,
  const int32_t* _Nonnull faceBoundaryTransitions,
  const double* _Nonnull tolerances,
  int32_t faceCount);

/// Result for each intersection hit.
typedef struct
{
  double x, y, z; // Intersection point
  double u, v;    // Surface parameters
  double w;       // Curve parameter
} OCCTCurveSurfaceHit;

/// Create a line–shape intersection iterator.
OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateLine(OCCTShapeRef _Nonnull shape,
                                                                   double originX,
                                                                   double originY,
                                                                   double originZ,
                                                                   double dirX,
                                                                   double dirY,
                                                                   double dirZ,
                                                                   double tolerance);

/// Create a curve–shape intersection iterator (uses existing Curve3D).
OCCTCurveSurfaceInterRef _Nullable OCCTCurveSurfaceInterCreateCurve(OCCTShapeRef _Nonnull shape,
                                                                    OCCTCurve3DRef _Nonnull curve,
                                                                    double tolerance);

/// Release the iterator.
void OCCTCurveSurfaceInterRelease(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Check if more results are available.
bool OCCTCurveSurfaceInterMore(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Advance to next result.
void OCCTCurveSurfaceInterNext(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Get current hit data.
OCCTCurveSurfaceHit OCCTCurveSurfaceInterHit(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Get the face hit at current position.
OCCTFaceRef _Nullable OCCTCurveSurfaceInterFace(OCCTCurveSurfaceInterRef _Nonnull inter);

/// Collect all hits into an array. Returns count, fills hits array (caller provides buffer).
int32_t OCCTCurveSurfaceInterAllHits(OCCTCurveSurfaceInterRef _Nonnull inter,
                                     OCCTCurveSurfaceHit* _Nonnull hits,
                                     int32_t maxHits);

// --- BRepExtrema_DistanceSS ---
typedef struct
{
  double distance;
  double point1X, point1Y, point1Z;
  double point2X, point2Y, point2Z;
  int    solutionCount;
  bool   isDone;
} OCCTDistanceSSResult;

OCCTDistanceSSResult OCCTBRepExtremaDistanceSS(OCCTShapeRef _Nonnull shape1Ref,
                                               OCCTShapeRef _Nonnull shape2Ref,
                                               double deflection);

/// Create an OBB from center, axes, and half-sizes.
OCCTOBBRef _Nonnull OCCTOBBCreate(double cx,
                                  double cy,
                                  double cz,
                                  double xDirX,
                                  double xDirY,
                                  double xDirZ,
                                  double yDirX,
                                  double yDirY,
                                  double yDirZ,
                                  double zDirX,
                                  double zDirY,
                                  double zDirZ,
                                  double hx,
                                  double hy,
                                  double hz);

/// Create an OBB from a shape's bounding box.
OCCTOBBRef _Nullable OCCTOBBCreateFromShape(OCCTShapeRef _Nonnull shape);

/// Release an OBB.
void OCCTOBBRelease(OCCTOBBRef _Nonnull obb);

/// Check if OBB is void (empty).
bool OCCTOBBIsVoid(OCCTOBBRef _Nonnull obb);

/// Get center of OBB.
void OCCTOBBGetCenter(OCCTOBBRef _Nonnull obb,
                      double* _Nonnull x,
                      double* _Nonnull y,
                      double* _Nonnull z);

/// Get half-sizes of OBB.
void OCCTOBBGetHalfSizes(OCCTOBBRef _Nonnull obb,
                         double* _Nonnull hx,
                         double* _Nonnull hy,
                         double* _Nonnull hz);

/// Check if a point is outside the OBB.
bool OCCTOBBIsOutPoint(OCCTOBBRef _Nonnull obb, double px, double py, double pz);

/// Check if another OBB is outside this OBB.
bool OCCTOBBIsOutOBB(OCCTOBBRef _Nonnull obb1, OCCTOBBRef _Nonnull obb2);

/// Enlarge the OBB by a gap value.
void OCCTOBBEnlarge(OCCTOBBRef _Nonnull obb, double gap);

/// Get square extent (diagonal squared).
double OCCTOBBSquareExtent(OCCTOBBRef _Nonnull obb);

// MARK: - BRepClass3d. Point Classification (v0.92.0)

/// Classify a 3D point relative to a solid shape.
/// @return 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
int32_t OCCTShapeClassifyPoint(OCCTShapeRef _Nonnull shape,
                               double px,
                               double py,
                               double pz,
                               double tolerance);

// MARK: - BRepClass_FClassifier (v0.96.0)

/// Classify a 2D point on a face (in UV space).
/// @return 0=IN, 1=OUT, 2=ON, 3=UNKNOWN
int32_t OCCTShapeClassifyPoint2D(OCCTShapeRef _Nonnull shape,
                                 int32_t faceIndex,
                                 double  u,
                                 double  v,
                                 double  tolerance);

/// Create a bound sort box with boxes.
/// @param boxes Array of bounding boxes (6 doubles each: xmin,ymin,zmin,xmax,ymax,zmax)
/// @param count Number of boxes
OCCTBoundSortBoxRef _Nonnull OCCTBoundSortBoxCreate(const double* _Nonnull boxes, int32_t count);

/// Release a bound sort box.
void OCCTBoundSortBoxRelease(OCCTBoundSortBoxRef _Nonnull bsb);

/// Find indices of boxes that intersect a query box. Indices are 0-based, matching this
/// bridge's own convention (translated from Bnd_BoundSortBox's native 1-based indices, whose
/// own header documents "the index is 1-based"; OCCTBoundSortBoxCreate stores caller box i at
/// OCCT array position i+1). Count-then-fill: outIndices=NULL returns the total number of
/// intersecting boxes without writing any. The fill call also returns the TOTAL count, not the
/// number written, so a return value greater than maxIndices signals truncation. #1462
/// @return Total number of intersecting boxes (not the number written to outIndices).
int32_t OCCTBoundSortBoxCompare(OCCTBoundSortBoxRef _Nonnull bsb,
                                double xmin,
                                double ymin,
                                double zmin,
                                double xmax,
                                double ymax,
                                double zmax,
                                int32_t* _Nullable outIndices,
                                int32_t maxIndices);

// --- BRepExtrema_SelfIntersection face pair reporting ---

/// Detect self-intersections and report overlapping face index pairs.
/// @param shape The shape to check (will be meshed automatically)
/// @param tolerance Overlap tolerance
/// @param outFaceIdx1 Output array of first face indices for each overlapping pair
/// @param outFaceIdx2 Output array of second face indices for each overlapping pair
/// @param maxPairs Maximum number of pairs to return
/// @return Number of overlapping pairs found, or -1 on error
int32_t OCCTShapeSelfIntersectionPairs(OCCTShapeRef _Nonnull shape,
                                       double tolerance,
                                       int32_t* _Nonnull outFaceIdx1,
                                       int32_t* _Nonnull outFaceIdx2,
                                       int32_t maxPairs,
                                       double  deflection);

// --- BRepLib_FindSurface ---

/// Find a surface (typically plane) through the edges of a shape.
/// @param onlyPlane If true, only planes are considered
/// @return Found surface, or NULL if not found
OCCTSurfaceRef _Nullable OCCTFindSurface(OCCTShapeRef _Nonnull shape,
                                         double tolerance,
                                         bool   onlyPlane);

/// Find surface and return the tolerance reached.
double OCCTFindSurfaceTolerance(OCCTShapeRef _Nonnull shape, double tolerance, bool onlyPlane);

/// Check if the surface already existed on the shape.
bool OCCTFindSurfaceExisted(OCCTShapeRef _Nonnull shape, double tolerance, bool onlyPlane);

// MARK: - TopExp Adjacency (v0.102.0)

/// Get the first (FORWARD) vertex of an edge. Returns vertex coordinates. Returns false if no
/// vertex.
bool OCCTEdgeFirstVertex(OCCTShapeRef _Nonnull edge,
                         double* _Nonnull x,
                         double* _Nonnull y,
                         double* _Nonnull z);

/// Get the last (REVERSED) vertex of an edge. Returns vertex coordinates. Returns false if no
/// vertex.
bool OCCTEdgeLastVertex(OCCTShapeRef _Nonnull edge,
                        double* _Nonnull x,
                        double* _Nonnull y,
                        double* _Nonnull z);

/// Get both vertices of an edge. Returns false if null vertices.
bool OCCTEdgeVertices(OCCTShapeRef _Nonnull edge,
                      double* _Nonnull x1,
                      double* _Nonnull y1,
                      double* _Nonnull z1,
                      double* _Nonnull x2,
                      double* _Nonnull y2,
                      double* _Nonnull z2);

/// Get first and last vertices of a wire. For closed wires, both are the same vertex. Returns false
/// if null.
bool OCCTWireVertices(OCCTShapeRef _Nonnull wire,
                      double* _Nonnull x1,
                      double* _Nonnull y1,
                      double* _Nonnull z1,
                      double* _Nonnull x2,
                      double* _Nonnull y2,
                      double* _Nonnull z2);

/// Find common vertex between two edges. Returns false if no shared vertex.
bool OCCTEdgeCommonVertex(OCCTShapeRef _Nonnull edge1,
                          OCCTShapeRef _Nonnull edge2,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Build edge→face adjacency map. Returns number of edges, and for each edge the count of adjacent
/// faces. adjacentFaceCounts must be pre-allocated with edgeCount entries (call with NULL first to
/// get count).
int32_t OCCTEdgeFaceAdjacency(OCCTShapeRef _Nonnull shape, int32_t* _Nullable adjacentFaceCounts);

/// Build vertex→edge adjacency map. Returns number of vertices, and for each vertex the count of
/// adjacent edges.
int32_t OCCTVertexEdgeAdjacency(OCCTShapeRef _Nonnull shape, int32_t* _Nullable adjacentEdgeCounts);

/// Get adjacent faces for a specific edge within a shape. Returns count of faces found.
/// faceIndices is an output array of 0-based face indices, addressable with
/// OCCTShapeGetFaceAtIndex. Caller allocates (max 64).
int32_t OCCTEdgeAdjacentFaces(OCCTShapeRef _Nonnull shape,
                              OCCTShapeRef _Nonnull edge,
                              int32_t* _Nonnull faceIndices,
                              int32_t maxFaces);

/// Get adjacent edges for a specific vertex within a shape. Returns count of edges found.
/// edgeIndices is an output array of 0-based edge indices, addressable with
/// OCCTShapeGetEdgeAtIndex. Caller allocates (max 64).
int32_t OCCTVertexAdjacentEdges(OCCTShapeRef _Nonnull shape,
                                OCCTShapeRef _Nonnull vertex,
                                int32_t* _Nonnull edgeIndices,
                                int32_t maxEdges);

// MARK: - BRepOffset_Analyse Edge Classification (v0.102.0)

/// Analyze edge concavity for all edges in a shape. Returns number of edges analyzed.
/// edgeTypes must be pre-allocated with returned count entries (call with NULL first to get count).
/// Uses existing OCCTConcavityType: 0=Convex, 1=Concave, 2=Tangent.
int32_t OCCTAnalyseEdgeConcavity(OCCTShapeRef _Nonnull shape,
                                 double angle,
                                 int32_t* _Nullable edgeTypes);

/// Get faces grouped by edge concavity type. Returns compound of connected face groups.
/// concavityType: 0=Convex, 1=Concave, 2=Tangent (matches OCCTConcavityType)
OCCTShapeRef _Nullable OCCTAnalyseExplode(OCCTShapeRef _Nonnull shape,
                                          double  angle,
                                          int32_t concavityType);

/// Count edges of a given concavity type on a specific face. 0=Convex, 1=Concave, 2=Tangent
int32_t OCCTAnalyseEdgesOnFace(OCCTShapeRef _Nonnull shape,
                               double angle,
                               OCCTShapeRef _Nonnull face,
                               int32_t concavityType);

/// Get ancestor faces for an edge in the offset analysis.
int32_t OCCTAnalyseAncestorCount(OCCTShapeRef _Nonnull shape,
                                 double angle,
                                 OCCTShapeRef _Nonnull edge);

/// Count tangent edges at a vertex along a given edge.
int32_t OCCTAnalyseTangentEdgeCount(OCCTShapeRef _Nonnull shape,
                                    double angle,
                                    OCCTShapeRef _Nonnull edge,
                                    OCCTShapeRef _Nonnull vertex);

// MARK: - BRepTools_WireExplorer Extensions (v0.102.0)

/// Explore wire edges with face context. Returns edge orientations (0=FORWARD, 1=REVERSED,
/// 2=INTERNAL, 3=EXTERNAL). orientations must be pre-allocated. Returns edge count.
int32_t OCCTWireExplorerOrientations(OCCTShapeRef _Nonnull wire,
                                     OCCTShapeRef _Nullable face,
                                     int32_t* _Nullable orientations);

/// Get connecting vertices from wire explorer (vertex between consecutive edges).
/// xs/ys/zs must be pre-allocated with edge count entries. Returns vertex count.
int32_t OCCTWireExplorerVertices(OCCTShapeRef _Nonnull wire,
                                 OCCTShapeRef _Nullable face,
                                 double* _Nullable xs,
                                 double* _Nullable ys,
                                 double* _Nullable zs);

/// Create a new ReShape context.
OCCTReShapeRef _Nonnull OCCTReShapeCreate(void);

/// Release a ReShape context.
void OCCTReShapeRelease(OCCTReShapeRef _Nonnull rs);

/// Clear all recorded modifications.
void OCCTReShapeClear(OCCTReShapeRef _Nonnull rs);

/// Record a shape removal.
void OCCTReShapeRemove(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Record a shape replacement.
void OCCTReShapeReplace(OCCTReShapeRef _Nonnull rs,
                        OCCTShapeRef _Nonnull oldShape,
                        OCCTShapeRef _Nonnull newShape);

/// Check if a shape has been recorded for modification.
bool OCCTReShapeIsRecorded(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Apply all recorded modifications to a shape.
OCCTShapeRef _Nullable OCCTReShapeApply(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

/// Get the replacement value for a specific shape.
OCCTShapeRef _Nullable OCCTReShapeValue(OCCTReShapeRef _Nonnull rs, OCCTShapeRef _Nonnull shape);

// MARK: - BRepTools_Substitution (v0.105.0)

/// Substitute a subshape with a list of new shapes. newSubs can be NULL (count=0) to remove.
OCCTShapeRef _Nullable OCCTShapeSubstitute(OCCTShapeRef _Nonnull shape,
                                           OCCTShapeRef _Nonnull oldSub,
                                           OCCTShapeRef _Nullable* _Nullable newSubs,
                                           int32_t newCount);

/// Check if a shape was copied during substitution build.
bool OCCTSubstitutionIsCopied(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull subshape);

// MARK: - BRepLib_MakeVertex (v0.105.0)

/// Create a vertex shape at the given point.
OCCTShapeRef _Nullable OCCTMakeVertex(double x, double y, double z);

// MARK: - Shape topology extensions (v0.106.0)

/// Get shape orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.
int32_t OCCTShapeGetOrientation(OCCTShapeRef _Nonnull shape);

/// Set shape orientation: 0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL.
void OCCTShapeSetOrientation(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Get a reversed copy of the shape.
OCCTShapeRef _Nullable OCCTShapeReversed(OCCTShapeRef _Nonnull shape);

/// Get a complemented copy of the shape (reversed orientation).
OCCTShapeRef _Nullable OCCTShapeComplemented(OCCTShapeRef _Nonnull shape);

/// Compose two shape orientations. Returns new shape with composed orientation.
OCCTShapeRef _Nullable OCCTShapeComposed(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Check if the shape's Free flag is set.
bool OCCTShapeIsFree(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Modified flag is set.
bool OCCTShapeIsModified(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Checked flag is set.
bool OCCTShapeIsChecked(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Orientable flag is set.
bool OCCTShapeIsOrientable(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Infinite flag is set.
bool OCCTShapeIsInfinite(OCCTShapeRef _Nonnull shape);

/// Check if the shape's Convex flag is set.
bool OCCTShapeIsConvex(OCCTShapeRef _Nonnull shape);

/// Check if the shape is empty (null).
bool OCCTShapeIsEmpty(OCCTShapeRef _Nonnull shape);

/// Check if two shapes are partners (same TShape).
bool OCCTShapeIsPartner(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

/// Check if two shapes are equal (same TShape + same location + same orientation).
bool OCCTShapeIsEqual(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

/// Get the number of direct children sub-shapes.
int32_t OCCTShapeNbChildren(OCCTShapeRef _Nonnull shape);

/// Get the hash code of a shape.
int32_t OCCTShapeHashCode(OCCTShapeRef _Nonnull shape);

// MARK: - BRepTools/BRepLib Utilities (v0.107.0)

/// Clean all tessellation data from a shape.
/// Alias kept for the v0.107 name; forwards to OCCTBRepToolsCleanTriangulation.
void OCCTShapeClean(OCCTShapeRef _Nonnull shape);

/// Clean geometry (PCurves etc.) from a shape.
void OCCTShapeCleanGeometry(OCCTShapeRef _Nonnull shape);

/// Remove unused PCurves from edges of a shape.
void OCCTShapeRemoveUnusedPCurves(OCCTShapeRef _Nonnull shape);

/// Update BRep data structures.
/// Alias kept for the v0.107 name; forwards to OCCTBRepToolsUpdate.
void OCCTShapeUpdate(OCCTShapeRef _Nonnull shape);

/// Check if an edge has same-range parametrisation.
bool OCCTBRepLibCheckSameRange(OCCTShapeRef _Nonnull edge);

/// Ensure edge has same-range parametrisation.
bool OCCTBRepLibSameRange(OCCTShapeRef _Nonnull edge, double tol);

/// Build 3D curve for an edge from PCurves.
bool OCCTBRepLibBuildCurve3d(OCCTShapeRef _Nonnull edge, double tol);

/// Update tolerances of all sub-shapes.
void OCCTBRepLibUpdateTolerances(OCCTShapeRef _Nonnull shape);

/// Update inner tolerances of all sub-shapes.
void OCCTBRepLibUpdateInnerTolerances(OCCTShapeRef _Nonnull shape);

/// Update tolerance of a specific edge.
bool OCCTBRepLibUpdateEdgeTolerance(OCCTShapeRef _Nonnull edge, double tol);

// MARK: - Edge/Face Extraction (v0.107.0)

/// Extract the 3D curve from an edge. Returns null if no curve. Writes first/last parameters.
OCCTCurve3DRef _Nullable OCCTEdgeExtractCurve3D(OCCTShapeRef _Nonnull edge,
                                                double* _Nonnull first,
                                                double* _Nonnull last);

/// Extract the PCurve of an edge on a face. Returns null if no PCurve.
OCCTCurve2DRef _Nullable OCCTEdgeExtractPCurve(OCCTShapeRef _Nonnull edge,
                                               OCCTShapeRef _Nonnull face,
                                               double* _Nonnull first,
                                               double* _Nonnull last);

/// Get the tolerance of an edge.
double OCCTEdgeGetTolerance(OCCTShapeRef _Nonnull edge);

/// Check if an edge is degenerated.
bool OCCTEdgeIsDegenerated(OCCTShapeRef _Nonnull edge);

/// Extract the surface from a face.
OCCTSurfaceRef _Nullable OCCTFaceExtractSurface(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a face.
double OCCTFaceGetTolerance(OCCTShapeRef _Nonnull face);

/// Get the number of wires on a face.
int32_t OCCTFaceWireCount(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a vertex.
double OCCTVertexGetTolerance(OCCTShapeRef _Nonnull vertex);

/// Get the point of a vertex.
void OCCTVertexGetPoint(OCCTShapeRef _Nonnull vertex,
                        double* _Nonnull x,
                        double* _Nonnull y,
                        double* _Nonnull z);

// MARK: - Shape Topology Counting (v0.109.0)

/// Count the number of faces in a shape.
int32_t OCCTShapeCountFaces(OCCTShapeRef _Nonnull shape);

/// Count the number of edges in a shape.
int32_t OCCTShapeCountEdges(OCCTShapeRef _Nonnull shape);

/// Get the shape type as a string. Caller must free() the result.
char* _Nullable OCCTShapeTypeString(OCCTShapeRef _Nonnull shape);

// --- Additional Shape operations ---

/// Get child shape at 0-based index.
OCCTShapeRef _Nullable OCCTShapeChild(OCCTShapeRef _Nonnull shape, int32_t index);

/// Check if shape is locked.
bool OCCTShapeIsLocked(OCCTShapeRef _Nonnull shape);

/// Set locked state on a shape.
void OCCTShapeSetLocked(OCCTShapeRef _Nonnull shape, bool locked);

/// Create a shape with an applied location transform (4x3 row-major matrix).
OCCTShapeRef _Nullable OCCTShapeLocated(OCCTShapeRef _Nonnull shape,
                                        const double* _Nonnull matrix12);

/// Get the current location transform as a 4x3 row-major matrix.
void OCCTShapeGetLocation(OCCTShapeRef _Nonnull shape, double* _Nonnull matrix12);

/// Set location transform in-place (4x3 row-major matrix).
void OCCTShapeSetLocation(OCCTShapeRef _Nonnull shape, const double* _Nonnull matrix12);

/// Create a shape with a specific orientation (0=FWD, 1=REV, 2=INT, 3=EXT).
OCCTShapeRef _Nullable OCCTShapeOriented(OCCTShapeRef _Nonnull shape, int32_t orientation);

/// Create a compound from an array of shapes.
OCCTShapeRef _Nullable OCCTShapeCompounded(const OCCTShapeRef _Nonnull* _Nonnull shapes,
                                           int32_t count);

/// Create an empty shape of a given type (0=COMPOUND..7=VERTEX).
OCCTShapeRef _Nullable OCCTShapeEmpty(int32_t type);

// --- Wire/Face construction ---

/// Create a wire from an array of edge shapes.
OCCTShapeRef _Nullable OCCTMakeWireFromEdges(const OCCTShapeRef _Nonnull* _Nonnull edges,
                                             int32_t count);

/// Create a compound from an array of shapes.
OCCTShapeRef _Nullable OCCTMakeCompound(const OCCTShapeRef _Nonnull* _Nonnull shapes,
                                        int32_t count);

/// Create a shell from an array of face shapes.
OCCTShapeRef _Nullable OCCTMakeShell(const OCCTShapeRef _Nonnull* _Nonnull faces, int32_t count);

/// Check if shape is a compound.
bool OCCTShapeIsCompound(OCCTShapeRef _Nonnull shape);

/// Check if shape is a solid.
bool OCCTShapeIsSolid(OCCTShapeRef _Nonnull shape);

/// Check if shape is a shell.
bool OCCTShapeIsShell(OCCTShapeRef _Nonnull shape);

/// Check if shape is a face.
bool OCCTShapeIsFace(OCCTShapeRef _Nonnull shape);

/// Check if shape is an edge.
bool OCCTShapeIsEdge(OCCTShapeRef _Nonnull shape);

/// Create a distance computation between two shapes.
OCCTDistSSRef _Nullable OCCTDistSSCreate(OCCTShapeRef _Nonnull s1, OCCTShapeRef _Nonnull s2);

/// Release a DistShapeShape object.
void OCCTDistSSRelease(OCCTDistSSRef _Nonnull dist);

/// Check if distance computation succeeded.
bool OCCTDistSSIsDone(OCCTDistSSRef _Nonnull dist);

/// Get the minimum distance value.
double OCCTDistSSValue(OCCTDistSSRef _Nonnull dist);

/// Get the number of solutions.
int32_t OCCTDistSSNbSolution(OCCTDistSSRef _Nonnull dist);

/// Get the i-th point on shape 1 (1-based).
void OCCTDistSSPointOnShape1(OCCTDistSSRef _Nonnull dist,
                             int32_t index,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);

/// Get the i-th point on shape 2 (1-based).
void OCCTDistSSPointOnShape2(OCCTDistSSRef _Nonnull dist,
                             int32_t index,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);

/// Get the support type on shape 1 (0=vertex, 1=edge, 2=face).
int32_t OCCTDistSSSupportType1(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support type on shape 2 (0=vertex, 1=edge, 2=face).
int32_t OCCTDistSSSupportType2(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support sub-shape on shape 1 (1-based).
OCCTShapeRef _Nullable OCCTDistSSSupportShape1(OCCTDistSSRef _Nonnull dist, int32_t index);

/// Get the support sub-shape on shape 2 (1-based).
OCCTShapeRef _Nullable OCCTDistSSSupportShape2(OCCTDistSSRef _Nonnull dist, int32_t index);

// MARK: - v0.114.0: TopoDS_Builder, ShapeContents expanded, FreeBoundsProperties, WireBuilder,
//                    Boolean tolerances, Offset wire/face, ThickSolid tolerance, BRepLib utilities,
//                    Mass properties expansion, Curve isBounded

// --- TopoDS_Builder ---

/// Create an empty wire via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeWire(void);

/// Create an empty shell via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeShell(void);

/// Create an empty solid via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeSolid(void);

/// Create an empty compound via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeCompound(void);

/// Create an empty comp-solid via TopoDS_Builder.
OCCTShapeRef _Nullable OCCTBuilderMakeCompSolid(void);

/// Add child shape into parent shape using TopoDS_Builder.
bool OCCTBuilderAdd(OCCTShapeRef _Nonnull parent, OCCTShapeRef _Nonnull child);

/// Remove child shape from parent shape using TopoDS_Builder.
bool OCCTBuilderRemove(OCCTShapeRef _Nonnull parent, OCCTShapeRef _Nonnull child);

// --- BRepLib utilities ---

/// Orient a closed solid so that its faces' normals point outward.
bool OCCTBRepLibOrientClosedSolid(OCCTShapeRef _Nonnull solid);

/// Build a 3D curve for every edge of a shape that has only pcurves. The one entry point for
/// BRepLib:BuildCurves3d, both of its overloads, since the no-tolerance one is just
/// `BuildCurves3d(S, 1.0e-5)`, and OCCT's own default for the parameter is that same 1e-5.
///
/// Returns false if any single edge could not be given a 3D curve (a degenerate edge with no
/// planar pcurve, or an edge stripped of every representation); the edges that did succeed are
/// still modified, so false means "partially built", not "nothing happened".
///
/// `tolerance` is not only the approximation tolerance: BRepLib::BuildCurve3d also makes it the
/// rebuilt edge's tolerance floor, so it is readable off the result afterwards. It has no effect
/// at all when the pcurve lies on a plane, that branch is analytic (GeomLib:To3d) and hard-codes
/// the new edge tolerance to 0. See Scripts/repro/498-buildcurves3d-triplication/. #498.
bool OCCTBRepLibBuildCurves3dForShape(OCCTShapeRef _Nonnull shape, double tolerance);

/// Sort faces of a shape by decreasing area (returns sorted face list as a compound).
OCCTShapeRef _Nullable OCCTBRepLibSortFaces(OCCTShapeRef _Nonnull shape);

/// Reverse sort faces (increasing area).
OCCTShapeRef _Nullable OCCTBRepLibReverseSortFaces(OCCTShapeRef _Nonnull shape);

// --- BRep_Tool queries on Shape ---

/// Get the tolerance of an edge shape.
double OCCTShapeEdgeTolerance(OCCTShapeRef _Nonnull edge);

/// Get the tolerance of a face shape.
double OCCTShapeFaceTolerance(OCCTShapeRef _Nonnull face);

/// Get the tolerance of a vertex shape.
double OCCTShapeVertexTolerance(OCCTShapeRef _Nonnull vertex);

/// Get the 3D point of a vertex shape.
void OCCTShapeVertexPoint(OCCTShapeRef _Nonnull vertex,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Get the curve from an edge shape. Returns NULL if edge has no 3D curve.
OCCTCurve3DRef _Nullable OCCTShapeEdgeCurve(OCCTShapeRef _Nonnull edge,
                                            double* _Nonnull first,
                                            double* _Nonnull last);

/// Get the surface from a face shape. Returns NULL if face has no surface.
OCCTSurfaceRef _Nullable OCCTShapeFaceSurface(OCCTShapeRef _Nonnull face);

/// Check if a shape is closed (for wire or shell).
bool OCCTShapeIsClosed(OCCTShapeRef _Nonnull shape);

// --- Unique sub-shape counts (TopExp::MapShapes) ---

/// Count unique sub-shapes of a given type.
/// type: 0=compound, 1=compsolid, 2=solid, 3=shell, 4=face, 5=wire, 6=edge, 7=vertex
int32_t OCCTShapeUniqueSubShapeCount(OCCTShapeRef _Nonnull shape, int32_t type);

// --- Shape topology queries ---

/// Get the number of unique edges in a shape.
int32_t OCCTShapeUniqueEdgeCount(OCCTShapeRef _Nonnull shape);

/// Get the number of unique faces in a shape.
int32_t OCCTShapeUniqueFaceCount(OCCTShapeRef _Nonnull shape);

/// Get the number of unique vertices in a shape.
int32_t OCCTShapeUniqueVertexCount(OCCTShapeRef _Nonnull shape);

// --- Shape empty copy ---

/// Create an empty copy of a shape (same TShape, no sub-shapes).
OCCTShapeRef _Nullable OCCTShapeEmptyCopied(OCCTShapeRef _Nonnull shape);

// --- GCPnts_AbscissaPoint expansion ---

/// Find parameter on an edge at a given arc length from startParam.
double OCCTEdgeParameterAtArcLength(OCCTShapeRef _Nonnull edge,
                                    double arcLength,
                                    double startParam);

/// Compute total arc length of an edge.
double OCCTEdgeArcLength(OCCTShapeRef _Nonnull edge);

/// OCCTCurve3DArcLength and OCCTCurve3DArcLengthBetween were declared here: second spellings
/// of OCCTCurve3DGetLength / OCCTCurve3DGetLengthBetween that returned 0 rather than -1.0 on
/// failure. Removed by #506.

/// Compute arc length between two parameters on an edge.
double OCCTEdgeArcLengthBetween(OCCTShapeRef _Nonnull edge, double u1, double u2);

/// A cheap, unsubdivided arc-length estimate between two parameters on an edge: one quadrature
/// pass, not the accurate measurement `OCCTEdgeArcLengthBetween` subdivides until it converges.
/// Meant only to bound an implied sample count before running a sampler that needs the same
/// single pass internally anyway -- see its doc comment for why (#862).
double OCCTEdgeArcLengthQuickEstimate(OCCTShapeRef _Nonnull edge, double u1, double u2);

/// Find parameter at a fraction (0..1) of total edge length.
double OCCTEdgeParameterAtFraction(OCCTShapeRef _Nonnull edge, double fraction);

// --- BRepAdaptor exposure ---

/// Get the parameter domain of an edge curve.
void OCCTEdgeAdaptorDomain(OCCTShapeRef _Nonnull edge,
                           double* _Nonnull first,
                           double* _Nonnull last);

/// Evaluate the edge curve at a parameter.
void OCCTEdgeAdaptorValue(OCCTShapeRef _Nonnull edge,
                          double param,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Get the curve type of an edge (GeomAbs_CurveType: 0=Line, 1=Circle, etc.).
int32_t OCCTEdgeAdaptorCurveType(OCCTShapeRef _Nonnull edge);

/// Get the UV bounds of a face surface.
void OCCTFaceAdaptorBounds(OCCTShapeRef _Nonnull face,
                           double* _Nonnull uMin,
                           double* _Nonnull uMax,
                           double* _Nonnull vMin,
                           double* _Nonnull vMax);

/// Evaluate the face surface at (u,v).
void OCCTFaceAdaptorValue(OCCTShapeRef _Nonnull face,
                          double u,
                          double v,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Get the surface type of a face (GeomAbs_SurfaceType: 0=Plane, 1=Cylinder, etc.).
int32_t OCCTFaceAdaptorSurfaceType(OCCTShapeRef _Nonnull face);

// --- Additional shape queries ---

/// Compute the volume of the oriented bounding box (OBB) of a shape.
double OCCTShapeOBBVolume(OCCTShapeRef _Nonnull shape);

/// Get the maximum edge tolerance in a shape.
double OCCTShapeMaxEdgeTolerance(OCCTShapeRef _Nonnull shape);

/// Get the maximum face tolerance in a shape.
double OCCTShapeMaxFaceTolerance(OCCTShapeRef _Nonnull shape);

/// Get the maximum vertex tolerance in a shape.
double OCCTShapeMaxVertexTolerance(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) edges.
bool OCCTShapeHasFreeEdges(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) wires.
bool OCCTShapeHasFreeWires(OCCTShapeRef _Nonnull shape);

/// Check if a shape has any free (non-shared) faces.
bool OCCTShapeHasFreeFaces(OCCTShapeRef _Nonnull shape);

/// Compute the bounding box diagonal length.
double OCCTShapeBoundingDiagonal(OCCTShapeRef _Nonnull shape);

/// Compute the volumetric centroid of a shape.
/// @return false when the shape has no closed volume. The value this used to write in that case
///         was the shape's location origin, which follows the part around and is not a
///         recognisable sentinel (#609).
bool OCCTShapeCentroid(OCCTShapeRef _Nonnull shape,
                       double* _Nonnull x,
                       double* _Nonnull y,
                       double* _Nonnull z);

/// Compute the total edge length of all edges in a shape.
double OCCTShapeTotalEdgeLength(OCCTShapeRef _Nonnull shape);

// MARK: - BRepBndLib (v0.118.0)

/// Compute axis-aligned bounding box for a shape.
/// @return false when the box is void (e.g. an empty shape), distinguishes that case from a
///         genuinely degenerate/point shape at the world origin, which legitimately computes to
///         all-zero coordinates (#900).
bool OCCTShapeBoundingBox(OCCTShapeRef _Nonnull shape,
                          double* _Nonnull xmin,
                          double* _Nonnull ymin,
                          double* _Nonnull zmin,
                          double* _Nonnull xmax,
                          double* _Nonnull ymax,
                          double* _Nonnull zmax);

/// Compute optimal (tight) axis-aligned bounding box for a shape.
/// @return false when the box is void (e.g. an empty shape), see ``OCCTShapeBoundingBox`` (#900).
bool OCCTShapeBoundingBoxOptimal(OCCTShapeRef _Nonnull shape,
                                 bool useShapeTolerance,
                                 double* _Nonnull xmin,
                                 double* _Nonnull ymin,
                                 double* _Nonnull zmin,
                                 double* _Nonnull xmax,
                                 double* _Nonnull ymax,
                                 double* _Nonnull zmax);

/// Compute oriented bounding box (OBB) for a shape with detailed axes output.
///
/// Delegates to ``OCCTShapeOrientedBoundingBox`` for the actual `Bnd_OBB` computation (#847),
/// this is the same box, unpacked into separate scalar out-parameters instead of one packed
/// struct, with failure reported through `isVoid` instead of a `bool` return.
void OCCTShapeOrientedBoundingBoxDetailed(OCCTShapeRef _Nonnull shape,
                                          bool isOptimal,
                                          double* _Nonnull cx,
                                          double* _Nonnull cy,
                                          double* _Nonnull cz,
                                          double* _Nonnull xDirX,
                                          double* _Nonnull xDirY,
                                          double* _Nonnull xDirZ,
                                          double* _Nonnull yDirX,
                                          double* _Nonnull yDirY,
                                          double* _Nonnull yDirZ,
                                          double* _Nonnull zDirX,
                                          double* _Nonnull zDirY,
                                          double* _Nonnull zDirZ,
                                          double* _Nonnull xHSize,
                                          double* _Nonnull yHSize,
                                          double* _Nonnull zHSize,
                                          bool* _Nonnull isVoid);

// MARK: - gp_Trsf extras (v0.118.0)

/// Create a transform from 3x4 matrix values.
void OCCTShapeTransformFromMatrix(OCCTShapeRef _Nonnull shape,
                                  double a11,
                                  double a12,
                                  double a13,
                                  double a14,
                                  double a21,
                                  double a22,
                                  double a23,
                                  double a24,
                                  double a31,
                                  double a32,
                                  double a33,
                                  double a34,
                                  OCCTShapeRef _Nullable* _Nonnull result);

/// Check if a transform is negative (IsNegative).
bool OCCTShapeTransformIsNegative(OCCTShapeRef _Nonnull shape);

// MARK: - TopExp extras (v0.118.0)

/// Find common vertex between two edges. Returns false if none.
bool OCCTEdgesCommonVertex(OCCTShapeRef _Nonnull edge1,
                           OCCTShapeRef _Nonnull edge2,
                           double* _Nonnull x,
                           double* _Nonnull y,
                           double* _Nonnull z);

// MARK: - BRep_Tool extras (v0.118.0)

/// Check if edge has SameParameter flag set.
bool OCCTEdgeSameParameter(OCCTShapeRef _Nonnull edge);

/// Check if edge has SameRange flag set.
bool OCCTEdgeSameRange(OCCTShapeRef _Nonnull edge);

/// Check if face has NaturalRestriction flag.
bool OCCTFaceNaturalRestriction(OCCTShapeRef _Nonnull face);

/// Check if edge is geometric (has 3D curve or curve on surface).
bool OCCTEdgeIsGeometric(OCCTShapeRef _Nonnull edge);

/// Check if face is geometric (has underlying surface).
bool OCCTFaceIsGeometric(OCCTShapeRef _Nonnull face);

// --- BRepTools statics ---

/// Remove triangulation from a shape (BRepTools::Clean).
/// Canonical implementation; OCCTShapeClean forwards here.
void OCCTBRepToolsCleanTriangulation(OCCTShapeRef _Nonnull shape);

/// Remove internal edges/vertices from a shape (BRepTools::RemoveInternals).
void OCCTBRepToolsRemoveInternals(OCCTShapeRef _Nonnull shape);

/// Detect if a face is closed in U and/or V (BRepTools::DetectClosedness).
/// Sets isClosedU and isClosedV.
void OCCTBRepToolsDetectClosedness(OCCTShapeRef _Nonnull face,
                                   bool* _Nonnull isClosedU,
                                   bool* _Nonnull isClosedV);

/// Evaluate and update tolerance of an edge on a face. Returns the new tolerance.
/// Uses BRep_Tool to extract curves, then BRepTools::EvalAndUpdateTol.
double OCCTBRepToolsEvalAndUpdateTol(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Count 3D edges in a shape (via BRepTools::Map3DEdges).
int32_t OCCTBRepToolsMap3DEdgeCount(OCCTShapeRef _Nonnull shape);

/// Update face UV points (BRepTools::UpdateFaceUVPoints).
void OCCTBRepToolsUpdateFaceUVPoints(OCCTShapeRef _Nonnull face);

/// Compare two vertices for geometric equality.
bool OCCTBRepToolsCompareVertices(OCCTShapeRef _Nonnull v1, OCCTShapeRef _Nonnull v2);

/// Compare two edges for geometric equality.
bool OCCTBRepToolsCompareEdges(OCCTShapeRef _Nonnull e1, OCCTShapeRef _Nonnull e2);

/// Check if an edge is really closed on a face.
bool OCCTBRepToolsIsReallyClosed(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Update a shape (all sub-shape types, BRepTools::Update).
/// Canonical implementation; OCCTShapeUpdate forwards here.
void OCCTBRepToolsUpdate(OCCTShapeRef _Nonnull shape);

// --- BRepLib extended statics ---

/// Ensure normal consistency of triangulated shape. Returns true if normals were fixed.
bool OCCTBRepLibEnsureNormalConsistency(OCCTShapeRef _Nonnull shape, double maxAngleRad);

/// Update deflection information of a shape.
void OCCTBRepLibUpdateDeflection(OCCTShapeRef _Nonnull shape);

/// Get the continuity of the surface across an edge between two faces.
/// Returns a raw GeomAbs_Shape ordinal, the measured-class vocabulary, so 0=C0, 1=G1, 2=C1,
/// 3=G2, 4=C2, 6=CN, and -1 for a null argument or a throw. Six of the seven ordinals are
/// reachable: `BRepLib::ContinuityOfFaces` never returns C3 (5), and CN is 6, not 5, a seam
/// edge on an elementary surface takes an early `return GeomAbs_CN`, and so does any elementary
/// pair that measures C2. (This comment used to say "5=CN", which is neither the ordinal of CN
/// nor a value this function can return; the implementation casts the enum straight through, so
/// there was never a lookup table for it to be describing. #495.)
int32_t OCCTBRepLibContinuityOfFaces(OCCTShapeRef _Nonnull edge,
                                     OCCTShapeRef _Nonnull face1,
                                     OCCTShapeRef _Nonnull face2,
                                     double tolerance);

// OCCTBRepLibBuildCurves3dAll used to be declared here (v0.122.0), with a body byte-identical to
// OCCTBRepLibBuildCurves3dForShape (v0.114.0) ~1700 header lines above: same overload, same two
// arguments. Use that one. #498.

/// Same-parameter all edges in a shape.
void OCCTBRepLibSameParameterAll(OCCTShapeRef _Nonnull shape, double tolerance, bool forced);

// --- Additional Shape queries ---

/// Get a nullified copy of the shape (cleared TShape).
OCCTShapeRef _Nullable OCCTShapeNullified(OCCTShapeRef _Nonnull shape);

/// Get the shape type as a string name.
const char* _Nullable OCCTShapeTypeName(OCCTShapeRef _Nonnull shape);

/// Check if this shape is NOT equal to other.
bool OCCTShapeIsNotEqual(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2);

// --- Shape emptied/moved ---

/// Get an emptied copy of the shape (no sub-shapes).
OCCTShapeRef _Nullable OCCTShapeEmptied(OCCTShapeRef _Nonnull shape);

/// Move a shape by an XYZ translation. Returns a new copy.
OCCTShapeRef _Nullable OCCTShapeMoved(OCCTShapeRef _Nonnull shape, double dx, double dy, double dz);

/// Get the shape orientation as integer (0=FORWARD, 1=REVERSED, 2=INTERNAL, 3=EXTERNAL).
int32_t OCCTShapeOrientationValue(OCCTShapeRef _Nonnull shape);

// OCCTShapeNbEdges / OCCTShapeNbFaces / OCCTShapeNbVertices are gone: each was a
// TopExp_Explorer occurrence count (24 edges / 6 faces / 48 vertices on a 12-edge, 6-face,
// 8-vertex box -- nbFaces only diverges from faceCount on a shape with a shared face), while
// this project's own reference docs always documented the distinct count. Shape.nbEdges /
// .nbFaces / .nbVertices are deprecated and forward to edgeCount / faceCount / vertexCount,
// which already called OCCTShapeGetTotalEdgeCount / OCCTShapeGetFaceCount /
// OCCTShapeGetVertexCount. #651

// MARK: - v0.126.0: Final completeness release

// --- BRep_Tool completions ---

/// Get the 2D curve (pcurve) of an edge on a face. Returns the Curve2D ref and parameter range.
OCCTCurve2DRef _Nullable OCCTBRepToolCurveOnSurface(OCCTShapeRef _Nonnull edge,
                                                    OCCTShapeRef _Nonnull face,
                                                    double* _Nonnull outFirst,
                                                    double* _Nonnull outLast);

/// Check if edge has continuity regularity between two faces.
bool OCCTBRepToolHasContinuity(OCCTShapeRef _Nonnull edge,
                               OCCTShapeRef _Nonnull face1,
                               OCCTShapeRef _Nonnull face2);

/// Get the continuity of edge between two faces. Returns GeomAbs_Shape as int.
int32_t OCCTBRepToolContinuity(OCCTShapeRef _Nonnull edge,
                               OCCTShapeRef _Nonnull face1,
                               OCCTShapeRef _Nonnull face2);

/// Check if edge has any regularity on some two surfaces.
bool OCCTBRepToolHasAnyContinuity(OCCTShapeRef _Nonnull edge);

/// Get the maximum continuity of edge between all its surfaces. Returns GeomAbs_Shape as int.
int32_t OCCTBRepToolMaxContinuity(OCCTShapeRef _Nonnull edge);

/// Check if edge is degenerated.
bool OCCTBRepToolDegenerated(OCCTShapeRef _Nonnull edge);

/// Check if face has the NaturalRestriction flag set.
bool OCCTBRepToolNaturalRestriction(OCCTShapeRef _Nonnull face);

/// Get the parameter range of edge on a face (pcurve range).
bool OCCTBRepToolRangeOnFace(OCCTShapeRef _Nonnull edge,
                             OCCTShapeRef _Nonnull face,
                             double* _Nonnull outFirst,
                             double* _Nonnull outLast);

/// Get the parameter of vertex on pcurve of edge on face.
bool OCCTBRepToolParameterOnFace(OCCTShapeRef _Nonnull vertex,
                                 OCCTShapeRef _Nonnull edge,
                                 OCCTShapeRef _Nonnull face,
                                 double* _Nonnull outParam);

/// Get the UV parameters of vertex on face.
bool OCCTBRepToolParametersOnFace(OCCTShapeRef _Nonnull vertex,
                                  OCCTShapeRef _Nonnull face,
                                  double* _Nonnull outU,
                                  double* _Nonnull outV);

/// Get UV points at extremities of edge on face.
bool OCCTBRepToolUVPoints(OCCTShapeRef _Nonnull edge,
                          OCCTShapeRef _Nonnull face,
                          double* _Nonnull firstU,
                          double* _Nonnull firstV,
                          double* _Nonnull lastU,
                          double* _Nonnull lastV);

/// Get maximum tolerance of sub-shapes of given type. type: 6=EDGE, 4=FACE, 7=VERTEX.
double OCCTBRepToolMaxTolerance(OCCTShapeRef _Nonnull shape, int32_t subShapeType);

// --- BRep_Tool completions ---

/// Get the 2D curve of an edge computed on a plane surface.
/// Returns the Curve2D and parameter range. May return NULL for non-planar surfaces.
OCCTCurve2DRef _Nullable OCCTBRepToolCurveOnPlane(OCCTShapeRef _Nonnull edge,
                                                  OCCTSurfaceRef _Nonnull surface,
                                                  double* _Nonnull outFirst,
                                                  double* _Nonnull outLast);

/// Get the 3D polygon of a meshed edge. Returns node count (0 if not available).
/// Points are returned as flat array [x1,y1,z1,...]. Caller must free with free().
int32_t OCCTBRepToolPolygon3D(OCCTShapeRef _Nonnull edge, double* _Nullable* _Nonnull outPoints);

/// Get the polygon-on-triangulation of a meshed edge.
/// Returns node indices (1-based) into the triangulation. Count returned. Caller must free with
/// free().
int32_t OCCTBRepToolPolygonOnTriangulation(OCCTShapeRef _Nonnull edge,
                                           int32_t* _Nullable* _Nonnull outIndices);

// --- BRep_Tool completions ---

/// Check if an edge is closed on a face (has same PCurve with different orientations).
bool OCCTBRepToolIsClosedOnFace(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Get the 2D polygon of an edge on a face. Returns 2D point count (0 if not available).
/// Points are returned as flat array [x1,y1,x2,y2,...]. Caller must free with free().
int32_t OCCTBRepToolPolygonOnSurface(OCCTShapeRef _Nonnull edge,
                                     OCCTShapeRef _Nonnull face,
                                     double* _Nullable* _Nonnull outPoints);

/// Set UV points of an edge on a face.
bool OCCTBRepToolSetUVPoints(OCCTShapeRef _Nonnull edge,
                             OCCTShapeRef _Nonnull face,
                             double fU,
                             double fV,
                             double lU,
                             double lV);

#endif /* OCCTBridge_Topology_h */
