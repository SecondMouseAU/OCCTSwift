//
//  OCCTBridge_Mesh.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Mesh domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Mesh_h
#define OCCTBridge_Mesh_h

// MARK: - Meshing

OCCTMeshRef OCCTShapeCreateMesh(OCCTShapeRef shape,
                                double       linearDeflection,
                                double       angularDeflection);

/// Enhanced mesh parameters for fine control over tessellation
typedef struct
{
  double deflection;               // Linear deflection for boundary edges
  double angle;                    // Angular deflection for boundary edges (radians)
  double deflectionInterior;       // Linear deflection for face interior (0 = same as deflection)
  double angleInterior;            // Angular deflection for face interior (0 = same as angle)
  double minSize;                  // Minimum element size (0 = no minimum)
  bool   relative;                 // Use relative deflection (proportion of edge size)
  bool   inParallel;               // Enable multi-threaded meshing
  bool   internalVertices;         // Generate vertices inside faces
  bool   controlSurfaceDeflection; // Validate surface approximation quality
  bool   adjustMinSize;            // Auto-adjust minSize based on edge size
  bool   allowQualityDecrease; // Allow replacing an existing finer triangulation with a coarser one
                               // (#211)
} OCCTMeshParameters;

/// Create mesh with enhanced parameters
OCCTMeshRef OCCTShapeCreateMeshWithParams(OCCTShapeRef shape, OCCTMeshParameters params);

/// Get default mesh parameters
OCCTMeshParameters OCCTMeshParametersDefault(void);

/// Construct a Mesh directly from raw triangulation arrays.
///
/// `vertices` is `vertexCount` packed (x, y, z) triplets (so `vertexCount * 3` floats).
/// `normals`, if non-NULL, is the same shape and must match `vertexCount`. Pass NULL
/// to have per-vertex normals computed from triangle face-normals (smooth shading).
/// `indices` is `indexCount` UInt32 indices forming `indexCount / 3` triangles; each
/// index must be < `vertexCount`.
///
/// Returns NULL if any input is invalid (empty, mismatched normal count,
/// `indexCount` not divisible by 3, or any index out of range), or on
/// allocation failure. Caller releases the result via `OCCTMeshRelease`.
OCCTMeshRef OCCTMeshCreateFromArrays(const float*    vertices,
                                     uint32_t        vertexCount,
                                     const float*    normals,
                                     const uint32_t* indices,
                                     uint32_t        indexCount);

// MARK: - Edge Discretization

// Ensuring a shape's edges have explicit 3D curves — needed before discretising a lofted/swept
// shape whose edges may carry only pcurves — is OCCTBRepLibBuildCurves3dForShape. There used to be
// a void OCCTShapeBuildCurves3d here wrapping BRepLib::BuildCurves3d's no-tolerance overload, but
// that overload is `return BuildCurves3d(S, 1.0e-5);` and nothing else, so it was the same call
// with the success flag discarded. #498.

/// Get discretized edge as polyline points
///
/// Rebuilds the shape's edge map on every call, so looping this over every edge is O(edges²) —
/// use OCCTShapeComputeAllEdgePolylines for iterate-all-edges consumers (issue #275).
///
/// @param shape The shape containing edges
/// @param edgeIndex Index of the edge (0-based)
/// @param deflection Linear deflection for discretization
/// @param outPoints Output array for points [x,y,z,...] (caller allocates)
/// @param maxPoints Maximum points to return
/// @return Number of points written, or -1 on error
int32_t OCCTShapeGetEdgePolyline(OCCTShapeRef shape,
                                 int32_t      edgeIndex,
                                 double       deflection,
                                 double*      outPoints,
                                 int32_t      maxPoints);

/// Discretise every edge of `shape` in a single pass, building the edge map once — O(edges),
/// versus O(edges²) for an OCCTShapeGetEdgePolyline loop over the same shape.
///
/// Edge ordering matches OCCTShapeGetTotalEdgeCount / OCCTShapeGetEdgePolyline (the same
/// TopExp::MapShapes ordering). Degenerate edges and edges that fail discretisation are kept as
/// entries with a point count of 0, so indices stay aligned with the shape's edge indices.
///
/// @param shape The shape containing edges
/// @param deflection Linear deflection for discretization
/// @param maxPointsPerEdge Maximum points per edge (must be >= 2)
/// @return A handle the caller must release with OCCTEdgePolylinesRelease, or NULL on error
OCCTEdgePolylinesRef _Nullable OCCTShapeComputeAllEdgePolylines(OCCTShapeRef shape,
                                                                double       deflection,
                                                                int32_t      maxPointsPerEdge);

/// Release a polyline set.
void OCCTEdgePolylinesRelease(OCCTEdgePolylinesRef _Nullable polys);

/// Number of edges in the set (matches the source shape's edge count).
int32_t OCCTEdgePolylinesGetEdgeCount(OCCTEdgePolylinesRef _Nullable polys);

/// Number of points for the edge at `edgeIndex` (0-based); 0 if degenerate or failed.
int32_t OCCTEdgePolylinesGetPointCount(OCCTEdgePolylinesRef _Nullable polys, int32_t edgeIndex);

/// Copy the edge's points as [x,y,z,...] into `outPoints` (caller allocates).
/// @return Number of points written (never more than maxPoints), or 0.
int32_t OCCTEdgePolylinesCopyPoints(OCCTEdgePolylinesRef _Nullable polys,
                                    int32_t edgeIndex,
                                    double* outPoints,
                                    int32_t maxPoints);

// MARK: - Triangle Access

/// Triangle data with face reference
typedef struct
{
  uint32_t v1, v2, v3; // Vertex indices
  int32_t  faceIndex;  // Source B-Rep face index (-1 if unknown)
  float    nx, ny, nz; // Triangle normal
} OCCTTriangle;

/// Get triangles with face association and normals
/// @param mesh The mesh to query
/// @param outTriangles Output array (caller allocates with triangleCount elements)
/// @return Number of triangles written
int32_t OCCTMeshGetTrianglesWithFaces(OCCTMeshRef mesh, OCCTTriangle* outTriangles);

// MARK: - Mesh to Shape Conversion

/// Convert a mesh (triangulation) to a B-Rep shape (compound of faces)
/// @param mesh The mesh to convert
/// @return Shape containing triangulated faces, or NULL on failure
OCCTShapeRef OCCTMeshToShape(OCCTMeshRef mesh);

/// Convert a mesh to a B-Rep shape with a caller-supplied sewing (vertex-weld) tolerance.
/// The weld tolerance must scale with the mesh's coordinate magnitude — too small for a
/// large-coordinate mesh leaves the shell open. @param weldTolerance edge-merge tolerance
/// (model units); pass 1e-6 to reproduce the default behaviour of OCCTMeshToShape.
/// @return Shape containing triangulated faces, or NULL on failure
OCCTShapeRef OCCTMeshToShapeWithTolerance(OCCTMeshRef mesh, double weldTolerance);

// MARK: - Mesh Booleans (via B-Rep roundtrip)

/// Perform boolean union on two meshes
/// @param mesh1 First mesh
/// @param mesh2 Second mesh
/// @param deflection Deflection for re-meshing result
/// @return Result mesh, or NULL on failure
OCCTMeshRef OCCTMeshUnion(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean subtraction on two meshes (mesh1 - mesh2)
OCCTMeshRef OCCTMeshSubtract(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

/// Perform boolean intersection on two meshes
OCCTMeshRef OCCTMeshIntersect(OCCTMeshRef mesh1, OCCTMeshRef mesh2, double deflection);

// MARK: - Mesh Access

int32_t OCCTMeshGetVertexCount(OCCTMeshRef mesh);
int32_t OCCTMeshGetTriangleCount(OCCTMeshRef mesh);
void    OCCTMeshGetVertices(OCCTMeshRef mesh, float* outVertices);
void    OCCTMeshGetNormals(OCCTMeshRef mesh, float* outNormals);
void    OCCTMeshGetIndices(OCCTMeshRef mesh, uint32_t* outIndices);

// MARK: - BRepMesh_Deflection (v0.61.0)

/// Compute absolute deflection from relative deflection and max shape size.
double OCCTComputeAbsoluteDeflection(OCCTShapeRef shape,
                                     double       relativeDeflection,
                                     double       maxShapeSize);

/// Check if a current deflection is consistent with a required deflection.
bool OCCTDeflectionIsConsistent(double current, double required, bool allowDecrease, double ratio);

// --- BRepLib_ToolTriangulatedShape ---

/// Compute normals on the triangulation of a shape's faces.
/// The shape must be meshed first.
/// @return true if normals were computed on at least one face
bool OCCTBRepLibComputeNormals(OCCTShapeRef shape);

// --- BRepLib_PointCloudShape ---

/// Generate a point cloud from a meshed shape by triangulation.
/// @param shape The meshed shape
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outNormals Output array of (nx,ny,nz) triples — caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTBRepLibPointCloudByTriangulation(OCCTShapeRef shape,
                                          double* _Nullable* _Nonnull outPoints,
                                          double* _Nullable* _Nonnull outNormals,
                                          int32_t* outCount);

/// Generate a point cloud from a meshed shape by density.
/// @param shape The meshed shape
/// @param density Points per unit area
/// @param outPoints Output array of (x,y,z) triples — caller must free with free()
/// @param outNormals Output array of (nx,ny,nz) triples — caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTBRepLibPointCloudByDensity(OCCTShapeRef shape,
                                    double       density,
                                    double* _Nullable* _Nonnull outPoints,
                                    double* _Nullable* _Nonnull outNormals,
                                    int32_t* outCount);

// MARK: - ShapeConstruct_MakeTriangulation

/// Build a triangulated face from an array of 3D points.
OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromPoints(const double* _Nonnull coords,
                                                                 int32_t pointCount);

/// Build a triangulated face from a wire.
OCCTShapeRef _Nullable OCCTShapeConstructTriangulationFromWire(OCCTWireRef _Nonnull wire);

// MARK: - BRepMesh_ShapeTool (Static Mesh Utilities)

/// Get maximum tolerance of edges/vertices on a face.
double OCCTMeshShapeToolMaxFaceTolerance(OCCTFaceRef _Nonnull face);

/// Get maximum dimension of a shape's bounding box.
double OCCTMeshShapeToolBoxMaxDimension(OCCTShapeRef _Nonnull shape);

/// Get UV parameter points of an edge on a face.
typedef struct
{
  double u1, v1, u2, v2;
  bool   success;
} OCCTUVPointsResult;

OCCTUVPointsResult OCCTMeshShapeToolUVPoints(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face);

/// Create a 2D polygon from points (x,y pairs).
OCCTPolyPolygon2DRef _Nullable OCCTPolyPolygon2DCreate(const double* _Nonnull points, int count);

/// Get number of nodes.
int OCCTPolyPolygon2DNbNodes(OCCTPolyPolygon2DRef _Nonnull ref);

/// Get a node's coordinates (0-based index). Returns false if out of range.
bool OCCTPolyPolygon2DNode(OCCTPolyPolygon2DRef _Nonnull ref,
                           int index,
                           double* _Nonnull x,
                           double* _Nonnull y);

/// Get/set deflection.
double OCCTPolyPolygon2DDeflection(OCCTPolyPolygon2DRef _Nonnull ref);
void   OCCTPolyPolygon2DSetDeflection(OCCTPolyPolygon2DRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygon2DRelease(OCCTPolyPolygon2DRef _Nonnull ref);

/// Create a Poly_Triangulation from flat node and triangle arrays.
/// - Parameter nodes: flat array of node coordinates (count*3 doubles).
/// - Parameter nbNodes: number of nodes.
/// - Parameter triangles: flat array of triangle vertex indices, 0-based (count*3 ints).
/// - Parameter nbTriangles: number of triangles.
OCCTPolyTriangulationRef _Nullable OCCTPolyTriangulationCreate(const double* _Nonnull nodes,
                                                               int nbNodes,
                                                               const int* _Nonnull triangles,
                                                               int nbTriangles);

/// Number of nodes.
int OCCTPolyTriangulationNbNodes(OCCTPolyTriangulationRef _Nonnull ref);

/// Number of triangles.
int OCCTPolyTriangulationNbTriangles(OCCTPolyTriangulationRef _Nonnull ref);

/// Get a node's coordinates (0-based index in Swift, 1-based internally).
bool OCCTPolyTriangulationNode(OCCTPolyTriangulationRef _Nonnull ref,
                               int index,
                               double* _Nonnull x,
                               double* _Nonnull y,
                               double* _Nonnull z);

/// Get a triangle's three node indices (0-based externally, returns 0-based indices).
bool OCCTPolyTriangulationTriangle(OCCTPolyTriangulationRef _Nonnull ref,
                                   int index,
                                   int* _Nonnull n1,
                                   int* _Nonnull n2,
                                   int* _Nonnull n3);

/// Get / set deflection.
double OCCTPolyTriangulationDeflection(OCCTPolyTriangulationRef _Nonnull ref);
void   OCCTPolyTriangulationSetDeflection(OCCTPolyTriangulationRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyTriangulationRelease(OCCTPolyTriangulationRef _Nonnull ref);

/// Create a 3D polygon from points (x,y,z triples).
OCCTPolyPolygon3DRef _Nullable OCCTPolyPolygon3DCreate(const double* _Nonnull points, int count);

/// Create a 3D polygon from points with parameters.
OCCTPolyPolygon3DRef _Nullable OCCTPolyPolygon3DCreateWithParams(const double* _Nonnull points,
                                                                 int count,
                                                                 const double* _Nonnull params);

/// Get number of nodes.
int OCCTPolyPolygon3DNbNodes(OCCTPolyPolygon3DRef _Nonnull ref);

/// Get a node's coordinates (0-based index).
bool OCCTPolyPolygon3DNode(OCCTPolyPolygon3DRef _Nonnull ref,
                           int index,
                           double* _Nonnull x,
                           double* _Nonnull y,
                           double* _Nonnull z);

/// Check if polygon has parameters.
bool OCCTPolyPolygon3DHasParameters(OCCTPolyPolygon3DRef _Nonnull ref);

/// Get parameter at index (0-based).
double OCCTPolyPolygon3DParameter(OCCTPolyPolygon3DRef _Nonnull ref, int index);

/// Get/set deflection.
double OCCTPolyPolygon3DDeflection(OCCTPolyPolygon3DRef _Nonnull ref);
void   OCCTPolyPolygon3DSetDeflection(OCCTPolyPolygon3DRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygon3DRelease(OCCTPolyPolygon3DRef _Nonnull ref);

/// Create a polygon on triangulation from node indices (0-based in Swift, 1-based internally).
OCCTPolyPolygonOnTriRef _Nullable OCCTPolyPolygonOnTriCreate(const int* _Nonnull nodeIndices,
                                                             int count);

/// Create with parameters.
OCCTPolyPolygonOnTriRef _Nullable OCCTPolyPolygonOnTriCreateWithParams(
  const int* _Nonnull nodeIndices,
  int count,
  const double* _Nonnull params);

/// Get number of nodes.
int OCCTPolyPolygonOnTriNbNodes(OCCTPolyPolygonOnTriRef _Nonnull ref);

/// Get node index at position (0-based).
int OCCTPolyPolygonOnTriNode(OCCTPolyPolygonOnTriRef _Nonnull ref, int index);

/// Check if has parameters.
bool OCCTPolyPolygonOnTriHasParameters(OCCTPolyPolygonOnTriRef _Nonnull ref);

/// Get parameter at index (0-based).
double OCCTPolyPolygonOnTriParameter(OCCTPolyPolygonOnTriRef _Nonnull ref, int index);

/// Get/set deflection.
double OCCTPolyPolygonOnTriDeflection(OCCTPolyPolygonOnTriRef _Nonnull ref);
void   OCCTPolyPolygonOnTriSetDeflection(OCCTPolyPolygonOnTriRef _Nonnull ref, double deflection);

/// Release.
void OCCTPolyPolygonOnTriRelease(OCCTPolyPolygonOnTriRef _Nonnull ref);

// MARK: - Poly_MergeNodesTool

/// Merge nodes of a shape's face triangulations. Returns merged vertex count, 0 on failure.
/// smoothAngle: angle threshold for normal smoothing (radians).
/// mergeTolerance: distance threshold for merging nodes.
/// outVertices/outNormals: interleaved x,y,z float arrays; outIndices: triangle indices.
/// maxVertices/maxIndices are hard capacities, not hints: if the merged mesh needs more room
/// than a requested (non-null) buffer provides, the whole call fails (returns 0, *outTriangleCount
/// left untouched) rather than silently writing a truncated prefix (#1566).
int OCCTPolyMergeNodes(OCCTShapeRef _Nonnull shapeRef,
                       double smoothAngle,
                       double mergeTolerance,
                       float* _Nullable outVertices,
                       float* _Nullable outNormals,
                       uint32_t* _Nullable outIndices,
                       int maxVertices,
                       int maxIndices,
                       int* _Nullable outTriangleCount);

OCCTCoherentTriangulationRef OCCTCoherentTriangulationCreate(void);
OCCTCoherentTriangulationRef OCCTCoherentTriangulationCreateFromMesh(OCCTShapeRef _Nonnull shapeRef,
                                                                     double deflection);
int    OCCTCoherentTriangulationSetNode(OCCTCoherentTriangulationRef _Nonnull ref,
                                        double x,
                                        double y,
                                        double z);
bool   OCCTCoherentTriangulationAddTriangle(OCCTCoherentTriangulationRef _Nonnull ref,
                                            int n0,
                                            int n1,
                                            int n2);
bool   OCCTCoherentTriangulationRemoveTriangle(OCCTCoherentTriangulationRef _Nonnull ref,
                                               int triIndex);
int    OCCTCoherentTriangulationNTriangles(OCCTCoherentTriangulationRef _Nonnull ref);
int    OCCTCoherentTriangulationComputeLinks(OCCTCoherentTriangulationRef _Nonnull ref);
int    OCCTCoherentTriangulationNLinks(OCCTCoherentTriangulationRef _Nonnull ref);
void   OCCTCoherentTriangulationSetDeflection(OCCTCoherentTriangulationRef _Nonnull ref,
                                              double deflection);
double OCCTCoherentTriangulationDeflection(OCCTCoherentTriangulationRef _Nonnull ref);
bool   OCCTCoherentTriangulationRemoveDegenerated(OCCTCoherentTriangulationRef _Nonnull ref,
                                                  double tolerance);
/// Converts back to standard Poly_Triangulation; returns vertex/triangle counts
bool OCCTCoherentTriangulationGetResult(OCCTCoherentTriangulationRef _Nonnull ref,
                                        int* _Nonnull outNbNodes,
                                        int* _Nonnull outNbTriangles);
/// Gets node coordinates (1-based index into result triangulation)
bool OCCTCoherentTriangulationNodeCoords(OCCTCoherentTriangulationRef _Nonnull ref,
                                         int nodeIndex,
                                         double* _Nonnull x,
                                         double* _Nonnull y,
                                         double* _Nonnull z);
void OCCTCoherentTriangulationRelease(OCCTCoherentTriangulationRef _Nonnull ref);

// --- RWMesh_CoordinateSystemConverter ---

/// Coordinate system enum (Z-up=0, Y-up=1)
typedef enum
{
  OCCTCoordinateSystemZup = 0,
  OCCTCoordinateSystemYup = 1
} OCCTCoordinateSystem;

/// Coordinate system converter result
typedef struct
{
  double x, y, z;
} OCCTPoint3D;

/// Convert a 3D point between coordinate systems with unit scaling
OCCTPoint3D OCCTCoordSystemConvert(double x,
                                   double y,
                                   double z,
                                   int    inputSystem,
                                   double inputLengthUnit,
                                   int    outputSystem,
                                   double outputLengthUnit);

/// Get standard axis direction for a coordinate system
OCCTPoint3D OCCTCoordSystemUpDirection(int system);

// MARK: - v0.100.0: RWStl, ShapeAnalysis_Curve statics, BRepExtrema_SelfIntersection pairs,
//                    Geom_OffsetCurve basis, APIHeaderSection_MakeHeader, ShapeAnalysis_FreeBounds
//                    simplified

// --- RWStl direct binary/ASCII STL I/O ---

/// Write a shape's triangulation to binary STL file. Shape is meshed automatically.
/// @param shape The shape to write
/// @param filePath Output file path
/// @param deflection Linear mesh deflection (mm) for the auto-triangulation
/// @return true on success
bool OCCTShapeWriteSTLBinary(OCCTShapeRef _Nonnull shape,
                             const char* _Nonnull filePath,
                             double deflection);

/// Write a shape's triangulation to ASCII STL file. Shape is meshed automatically.
/// @param shape The shape to write
/// @param filePath Output file path
/// @param deflection Linear mesh deflection (mm) for the auto-triangulation
/// @return true on success
bool OCCTShapeWriteSTLAscii(OCCTShapeRef _Nonnull shape,
                            const char* _Nonnull filePath,
                            double deflection);

/// Read an STL file and return as a triangulated shape (face with triangulation).
/// @param filePath Input STL file path
/// @return Shape with triangulation, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeReadSTL(const char* _Nonnull filePath);

// MARK: - Poly_Connect Mesh Adjacency (v0.102.0)

/// Get adjacent triangles for a triangle in a mesh. adj1/adj2/adj3 are 0 if no neighbor.
/// Returns false if invalid triangle index or no triangulation on shape.
bool OCCTMeshTriangleAdjacency(OCCTShapeRef _Nonnull shape,
                               int32_t faceIndex,
                               int32_t triangleIndex,
                               int32_t* _Nonnull adj1,
                               int32_t* _Nonnull adj2,
                               int32_t* _Nonnull adj3);

/// Get a triangle index containing the given node. Returns 0 if invalid.
int32_t OCCTMeshNodeTriangle(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t nodeIndex);

/// Count triangles sharing a given node (fan count). Returns 0 if invalid.
int32_t OCCTMeshNodeTriangleCount(OCCTShapeRef _Nonnull shape,
                                  int32_t faceIndex,
                                  int32_t nodeIndex);

/// Create a face iterator over a meshed shape.
OCCTMeshFaceIterRef _Nullable OCCTMeshFaceIterCreate(OCCTShapeRef _Nonnull shape);

/// Release a face iterator.
void OCCTMeshFaceIterRelease(OCCTMeshFaceIterRef _Nonnull iter);

/// Check if the iterator has more faces.
bool OCCTMeshFaceIterMore(OCCTMeshFaceIterRef _Nonnull iter);

/// Advance to the next face.
void OCCTMeshFaceIterNext(OCCTMeshFaceIterRef _Nonnull iter);

/// Number of nodes in the current face triangulation.
int32_t OCCTMeshFaceIterNbNodes(OCCTMeshFaceIterRef _Nonnull iter);

/// Number of triangles in the current face triangulation.
int32_t OCCTMeshFaceIterNbTriangles(OCCTMeshFaceIterRef _Nonnull iter);

/// Get node position at 1-based index (transformed).
void OCCTMeshFaceIterNode(OCCTMeshFaceIterRef _Nonnull iter,
                          int32_t index,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Check if current face has normals.
bool OCCTMeshFaceIterHasNormals(OCCTMeshFaceIterRef _Nonnull iter);

/// Get normal at 1-based node index (transformed).
void OCCTMeshFaceIterNormal(OCCTMeshFaceIterRef _Nonnull iter,
                            int32_t index,
                            double* _Nonnull nx,
                            double* _Nonnull ny,
                            double* _Nonnull nz);

/// Get triangle node indices at 1-based triangle index (oriented).
void OCCTMeshFaceIterTriangle(OCCTMeshFaceIterRef _Nonnull iter,
                              int32_t index,
                              int32_t* _Nonnull n1,
                              int32_t* _Nonnull n2,
                              int32_t* _Nonnull n3);

/// Create a vertex iterator over a shape.
OCCTMeshVertexIterRef _Nullable OCCTMeshVertexIterCreate(OCCTShapeRef _Nonnull shape);

/// Release a vertex iterator.
void OCCTMeshVertexIterRelease(OCCTMeshVertexIterRef _Nonnull iter);

/// Check if the iterator has more vertices.
bool OCCTMeshVertexIterMore(OCCTMeshVertexIterRef _Nonnull iter);

/// Advance to the next vertex.
void OCCTMeshVertexIterNext(OCCTMeshVertexIterRef _Nonnull iter);

/// Get the current vertex point.
void OCCTMeshVertexIterPoint(OCCTMeshVertexIterRef _Nonnull iter,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);

// --- Poly_Triangulation queries on faces ---

/// Get the number of nodes in the triangulation of a face.
int32_t OCCTFaceTriangulationNodeCount(OCCTShapeRef _Nonnull face);

/// Get the number of triangles in the triangulation of a face.
int32_t OCCTFaceTriangulationTriangleCount(OCCTShapeRef _Nonnull face);

/// Get the deflection of the triangulation.
double OCCTFaceTriangulationDeflection(OCCTShapeRef _Nonnull face);

/// Get the coordinates of a node (1-based index).
void OCCTFaceTriangulationNode(OCCTShapeRef _Nonnull face,
                               int32_t index,
                               double* _Nonnull x,
                               double* _Nonnull y,
                               double* _Nonnull z);

/// Get the node indices of a triangle (1-based index). Returns 1-based node indices.
void OCCTFaceTriangulationTriangle(OCCTShapeRef _Nonnull face,
                                   int32_t index,
                                   int32_t* _Nonnull n1,
                                   int32_t* _Nonnull n2,
                                   int32_t* _Nonnull n3);

/// Check if the face triangulation has normals.
bool OCCTFaceTriangulationHasNormals(OCCTShapeRef _Nonnull face);

/// Get the normal at a node (1-based index).
void OCCTFaceTriangulationNormal(OCCTShapeRef _Nonnull face,
                                 int32_t index,
                                 double* _Nonnull nx,
                                 double* _Nonnull ny,
                                 double* _Nonnull nz);

/// Check if the face triangulation has UV nodes.
bool OCCTFaceTriangulationHasUVNodes(OCCTShapeRef _Nonnull face);

/// Get the UV coordinates of a node (1-based index).
void OCCTFaceTriangulationUVNode(OCCTShapeRef _Nonnull face,
                                 int32_t index,
                                 double* _Nonnull u,
                                 double* _Nonnull v);

// MARK: - Poly copy / mutators — OCCT 8.0.0p1

/// Deep-copy a Poly_Polygon2D (Poly_Polygon2D::Copy()). Returns NULL on failure.
OCCTPolyPolygon2DRef _Nullable OCCTPolyPolygon2DCopy(OCCTPolyPolygon2DRef _Nonnull ref);

/// Deep-copy a Poly_PolygonOnTriangulation. Returns NULL on failure.
OCCTPolyPolygonOnTriRef _Nullable OCCTPolyPolygonOnTriCopy(OCCTPolyPolygonOnTriRef _Nonnull ref);

/// Overwrite the node-index array via ChangeNodeArray(). count must equal NbNodes().
/// Returns true on success, false on size mismatch / error.
bool OCCTPolyPolygonOnTriSetNodes(OCCTPolyPolygonOnTriRef _Nonnull ref,
                                  const int* _Nonnull nodeIndices,
                                  int count);

/// Overwrite the parameter array via ChangeParameterArray(). Requires HasParameters()
/// and count == NbNodes(). Returns true on success, false otherwise.
bool OCCTPolyPolygonOnTriSetParameters(OCCTPolyPolygonOnTriRef _Nonnull ref,
                                       const double* _Nonnull params,
                                       int count);

#endif /* OCCTBridge_Mesh_h */
