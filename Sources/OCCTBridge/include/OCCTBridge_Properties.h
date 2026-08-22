//
//  OCCTBridge_Properties.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Properties domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Properties_h
#define OCCTBridge_Properties_h

// MARK: - Measurement & Analysis (v0.7.0)

/// Mass properties result structure
typedef struct
{
  double volume;                    // Cubic units
  double surfaceArea;               // Square units
  double mass;                      // With density applied
  double centerX, centerY, centerZ; // Center of mass
  double ixx, ixy, ixz;             // Inertia tensor row 1
  double iyx, iyy, iyz;             // Inertia tensor row 2
  double izx, izy, izz;             // Inertia tensor row 3
  bool   isValid;
} OCCTShapeProperties;

/// Get full mass properties of a shape
/// @param shape The shape to analyze
/// @param density Density for mass calculation (use 1.0 for volume-only calculations)
/// @return Properties structure with isValid indicating success
OCCTShapeProperties OCCTShapeGetProperties(OCCTShapeRef shape, double density);

/// Measure the volume a shape encloses (convenience function)
///
/// Computed with `OnlyClosed = true`, so a shape with no closed shell has no volume and this
/// reports failure rather than the number the divergence integral returns over a surface that
/// encloses nothing (#609). Use `OCCTShapeSignedVolumeFlux` when the question is which way the
/// faces point rather than how much volume there is.
///
/// The value written keeps `BRepGProp`'s sign, so a reversed solid writes a negative volume and
/// this still returns true. `Shape.volume` treats that as no answer; `Shape.signedVolume` is the
/// accessor for it, and it goes through `OCCTShapeSignedVolumeFlux` rather than this.
///
/// @param shape The shape to measure
/// @param outVolume Output: volume in cubic units, signed, untouched when this returns false
/// @return true when the shape has a closed volume, false otherwise or on error
bool OCCTShapeGetVolume(OCCTShapeRef shape, double* outVolume);

/// Get the signed divergence integral over a shape's faces.
///
/// This is `VolumeProperties` with `OnlyClosed` left at its default, so unlike
/// `OCCTShapeGetVolume` it answers for an open surface. The *magnitude* is a volume only when the
/// surface is closed; the *sign* is a sound orientation signal either way, because reversing a
/// surface negates the flux. Callers wanting to measure a volume must use `OCCTShapeGetVolume`.
///
/// @param shape The shape to integrate over
/// @param outFlux Output: signed flux, untouched when this returns false
/// @return false only on an internal error
bool OCCTShapeSignedVolumeFlux(OCCTShapeRef shape, double* outFlux);

/// Get surface area of a shape (convenience function)
/// @param shape The shape to measure
/// @return Surface area in square units, or -1.0 on error
double OCCTShapeGetSurfaceArea(OCCTShapeRef shape);

/// Get center of mass of a shape (convenience function)
/// @param shape The shape to analyze
/// @param outX, outY, outZ Output: center of mass coordinates
/// @return true on success, false on error
bool OCCTShapeGetCenterOfMass(OCCTShapeRef shape, double* outX, double* outY, double* outZ);

/// Distance measurement result structure
typedef struct
{
  double  distance;      // Minimum distance between shapes
  double  p1x, p1y, p1z; // Closest point on shape1
  double  p2x, p2y, p2z; // Closest point on shape2
  int32_t solutionCount; // Number of solutions found
  bool    isValid;
} OCCTDistanceResult;

/// Compute minimum distance between two shapes
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param deflection Deflection tolerance for curved geometry (use 1e-6 for default)
/// @return Distance result with isValid indicating success
OCCTDistanceResult OCCTShapeDistance(OCCTShapeRef shape1, OCCTShapeRef shape2, double deflection);

/// Check if two shapes intersect (overlap in space)
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Tolerance for intersection test
/// @return true if shapes intersect or touch, false otherwise
bool OCCTShapeIntersects(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Get total number of vertices in a shape
int32_t OCCTShapeGetVertexCount(OCCTShapeRef shape);

/// Get vertex coordinates at index
/// @param shape The shape containing vertices
/// @param index Vertex index (0-based)
/// @param outX, outY, outZ Output: vertex coordinates
/// @return true on success, false if index out of bounds
bool OCCTShapeGetVertexAt(OCCTShapeRef shape,
                          int32_t      index,
                          double*      outX,
                          double*      outY,
                          double*      outZ);

/// Get all vertices as an array
/// @param shape The shape containing vertices
/// @param outVertices Output array for vertices [x,y,z,...] (caller allocates vertexCount*3
/// doubles)
/// @return Number of vertices written
int32_t OCCTShapeGetVertices(OCCTShapeRef shape, double* outVertices);

// MARK: - Bounds

/// Get the axis-aligned bounding box of a shape (BRepBndLib::Add, the same box
/// `OCCTShapeBoundingBox` computes).
/// @return false when the box is void (no geometry contributed to it), the shape is null, or OCCT
/// raised. A shape whose measured box is genuinely zero-size returns true with six zeros, which is
/// why the six doubles alone cannot carry this distinction (#943).
bool OCCTShapeGetBounds(OCCTShapeRef shape,
                        double*      minX,
                        double*      minY,
                        double*      minZ,
                        double*      maxX,
                        double*      maxY,
                        double*      maxZ);

// MARK: - Surfaces & Curves (v0.9.0)

/// Curve analysis result structure
typedef struct
{
  double length;
  bool   isClosed;
  bool   isPeriodic;
  double startX, startY, startZ;
  double endX, endY, endZ;
  bool   isValid;
} OCCTCurveInfo;

/// Curve point with derivatives
typedef struct
{
  double posX, posY, posZ;    // Position
  double tanX, tanY, tanZ;    // Tangent vector
  double curvature;           // Curvature magnitude
  double normX, normY, normZ; // Principal normal (if curvature > 0)
  bool   hasNormal;
  bool   isValid;
} OCCTCurvePoint;

/// Get comprehensive curve information for a wire
/// @param wire The wire to analyze
/// @return Curve information structure with isValid indicating success
OCCTCurveInfo OCCTWireGetCurveInfo(OCCTWireRef wire);

/// Get the length of a wire
/// @param wire The wire to measure
/// @return Length in linear units, or -1.0 on error
double OCCTWireGetLength(OCCTWireRef wire);

/// Get point on wire at normalized parameter (0.0 to 1.0)
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 (start) to 1.0 (end)
/// @param x, y, z Output: point coordinates
/// @return true on success, false on error
bool OCCTWireGetPointAt(OCCTWireRef wire, double param, double* x, double* y, double* z);

/// Get tangent vector at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @param tx, ty, tz Output: tangent vector components (normalized)
/// @return true on success, false on error
bool OCCTWireGetTangentAt(OCCTWireRef wire, double param, double* tx, double* ty, double* tz);

/// Get curvature at normalized parameter
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @param curvature Output: curvature value (1/radius)
/// @return true if the curvature exists there. False for a null wire, a parameter the wire cannot
///   be evaluated at, and a point whose first derivative is null (a cusp), where the hand-rolled
///   formula has no answer. That last case used to return 0, a straight wire's answer (#595).
bool OCCTWireGetCurvatureAt(OCCTWireRef wire, double param, double* _Nonnull curvature);

/// Get full curve point with position, tangent, and curvature
/// @param wire The wire to sample
/// @param param Parameter value from 0.0 to 1.0
/// @return Curve point structure with isValid indicating success
OCCTCurvePoint OCCTWireGetCurvePointAt(OCCTWireRef wire, double param);

// MARK: - Face Surface Properties (v0.18.0)

/// Get UV parameter bounds of a face
bool OCCTFaceGetUVBounds(OCCTFaceRef face, double* uMin, double* uMax, double* vMin, double* vMax);

/// Evaluate surface point at UV parameters
bool OCCTFaceEvaluateAtUV(OCCTFaceRef face, double u, double v, double* px, double* py, double* pz);

/// Get surface normal at UV parameters
bool OCCTFaceGetNormalAtUV(OCCTFaceRef face,
                           double      u,
                           double      v,
                           double*     nx,
                           double*     ny,
                           double*     nz);

/// Get Gaussian curvature at UV parameters
bool OCCTFaceGetGaussianCurvature(OCCTFaceRef face, double u, double v, double* curvature);

/// Get mean curvature at UV parameters
bool OCCTFaceGetMeanCurvature(OCCTFaceRef face, double u, double v, double* curvature);

/// Get principal curvatures and directions at UV parameters
bool OCCTFaceGetPrincipalCurvatures(OCCTFaceRef face,
                                    double      u,
                                    double      v,
                                    double*     k1,
                                    double*     k2,
                                    double*     d1x,
                                    double*     d1y,
                                    double*     d1z,
                                    double*     d2x,
                                    double*     d2y,
                                    double*     d2z);

/// Get surface type: 0=Plane, 1=Cylinder, 2=Cone, 3=Sphere, 4=Torus,
///   5=BezierSurface, 6=BSplineSurface, 7=SurfaceOfRevolution,
///   8=SurfaceOfExtrusion, 9=OffsetSurface, 10=Other
int32_t OCCTFaceGetSurfaceType(OCCTFaceRef face);

/// Get surface area of a single face
double OCCTFaceGetArea(OCCTFaceRef face, double tolerance);

/// Get the primary axis of a face's underlying surface if cylindrical/conical/spherical/
/// toroidal/surface-of-revolution/surface-of-extrusion. Returns false for non-axial surfaces.
/// v0.137. outKind: 0=none, 1=cylinder, 2=cone, 3=sphere, 4=torus, 5=revolution, 6=extrusion.
bool OCCTFaceGetPrimaryAxis(OCCTFaceRef _Nonnull face,
                            double* _Nonnull ox,
                            double* _Nonnull oy,
                            double* _Nonnull oz,
                            double* _Nonnull dx,
                            double* _Nonnull dy,
                            double* _Nonnull dz,
                            int32_t* _Nonnull outKind);

// MARK: - Edge 3D Curve Properties (v0.18.0)

/// Get parameter bounds of an edge's curve
bool OCCTEdgeGetParameterBounds(OCCTEdgeRef edge, double* first, double* last);

/// Get 3D curvature at parameter on edge curve
bool OCCTEdgeGetCurvature3D(OCCTEdgeRef edge, double param, double* curvature);

/// Get tangent direction at parameter on edge curve
bool OCCTEdgeGetTangent3D(OCCTEdgeRef edge, double param, double* tx, double* ty, double* tz);

/// Get principal normal at parameter on edge curve
bool OCCTEdgeGetNormal3D(OCCTEdgeRef edge, double param, double* nx, double* ny, double* nz);

/// Get center of curvature at parameter on edge curve
bool OCCTEdgeGetCenterOfCurvature3D(OCCTEdgeRef edge,
                                    double      param,
                                    double*     cx,
                                    double*     cy,
                                    double*     cz);

/// Get torsion at parameter on edge curve
bool OCCTEdgeGetTorsion(OCCTEdgeRef edge, double param, double* torsion);

/// Get point at parameter (uses actual curve parameterization)
bool OCCTEdgeGetPointAtParam(OCCTEdgeRef edge, double param, double* px, double* py, double* pz);

/// Get curve type: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola,
///   5=BezierCurve, 6=BSplineCurve, 7=OffsetCurve, 8=Other
int32_t OCCTEdgeGetCurveType(OCCTEdgeRef edge);

// MARK: - Point Projection (v0.18.0)

/// Projection result for point-on-surface
typedef struct
{
  double px, py, pz; // closest 3D point
  double u, v;       // UV parameters
  double distance;   // distance from original point
  bool   isValid;
} OCCTSurfaceProjectionResult;

/// Project point onto face (closest point)
OCCTSurfaceProjectionResult OCCTFaceProjectPoint(OCCTFaceRef face, double px, double py, double pz);

/// Get all projection results (multiple solutions)
int32_t OCCTFaceProjectPointAll(OCCTFaceRef                  face,
                                double                       px,
                                double                       py,
                                double                       pz,
                                OCCTSurfaceProjectionResult* results,
                                int32_t                      maxResults);

/// Projection result for point-on-curve
typedef struct
{
  double px, py, pz; // closest 3D point on curve
  double parameter;  // curve parameter, always within the edge's own range
  double distance;   // distance from original point
  bool   isValid;    // false only for an edge with no 3D curve
} OCCTCurveProjectionResult;

/// Project point onto edge curve, giving the closest point over the edge's own parameter range.
/// Where the point has no perpendicular foot on the edge, the closest point is one of its ends
/// (#539). Shares OCCTCurve3DProjectPoint's implementation.
OCCTCurveProjectionResult OCCTEdgeProjectPoint(OCCTEdgeRef edge, double px, double py, double pz);

// MARK: - Shape Proximity (v0.18.0)

/// Face proximity pair result
typedef struct
{
  int32_t face1Index;
  int32_t face2Index;
} OCCTFaceProximityPair;

/// Detect face pairs between two shapes that are within tolerance
int32_t OCCTShapeProximity(OCCTShapeRef           shape1,
                           OCCTShapeRef           shape2,
                           double                 tolerance,
                           OCCTFaceProximityPair* outPairs,
                           int32_t                maxPairs,
                           double                 deflection);

/// Whether `shape` self-intersects, from BOPAlgo_CheckerSI's interference map.
///
/// Unbounded: there is no timeout, and the check has been measured at minutes on an ordinary
/// solid. Returns false both for a clean shape and for a check that could not run, which is why
/// the Swift property over it is deprecated in favour of the bounded, tri-state
/// OCCTShapeSelfIntersectsBounded (#1088).
bool OCCTShapeSelfIntersects(OCCTShapeRef shape);

// MARK: - v0.40.0: Mass Properties, Geometry Conversion, Distance Analysis

/// Inertia properties result structure
typedef struct
{
  double volume;
  double centerX, centerY, centerZ;
  /// Row-major 3x3 inertia matrix (Ixx, Ixy, Ixz, Iyx, Iyy, Iyz, Izx, Izy, Izz)
  double inertia[9];
  /// Principal moments of inertia
  double principalIx, principalIy, principalIz;
  /// Principal axes (3x3, row-major: axisX, axisY, axisZ)
  double principalAxes[9];
  bool   hasSymmetryAxis;
  bool   hasSymmetryPoint;
} OCCTInertiaProperties;

/// Compute volume-based inertia properties (volume, center of mass, inertia matrix)
bool OCCTShapeInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps);

/// Compute surface-area-based inertia properties
bool OCCTShapeSurfaceInertiaProperties(OCCTShapeRef shape, OCCTInertiaProperties* outProps);

// --- BRepGProp_Face ---

/// Get the natural bounds of a face using BRepGProp_Face.
/// Unlike OCCTFaceGetUVBounds (BRepTools::UVBounds), this uses BRepGProp_Face::Bounds
/// which accounts for face orientation and provides parametric integration bounds.
/// @param face Face to query
/// @param uMin, uMax, vMin, vMax Output UV bounds
/// @return true on success
bool OCCTFaceGetNaturalBounds(OCCTFaceRef face,
                              double*     uMin,
                              double*     uMax,
                              double*     vMin,
                              double*     vMax);

/// Evaluate a face at UV using BRepGProp_Face::Normal, returning point and unnormalized normal.
/// Unlike OCCTFaceGetNormalAtUV which normalizes, this returns the raw cross product of
/// partial derivatives (dS/du x dS/dv), whose magnitude equals the local area element.
/// @param face Face to evaluate
/// @param u, v UV parameters
/// @param px, py, pz Output 3D point coordinates
/// @param nx, ny, nz Output surface normal (unnormalized, magnitude = area element)
/// @return true on success
bool OCCTFaceEvaluateNormalAtUV(OCCTFaceRef face,
                                double      u,
                                double      v,
                                double*     px,
                                double*     py,
                                double*     pz,
                                double*     nx,
                                double*     ny,
                                double*     nz);

// --- Volume Inertia Properties ---

/// Result of volume inertia analysis
typedef struct
{
  double volume;                    ///< Volume (mass)
  double centerX, centerY, centerZ; ///< Center of mass

  /// Matrix of inertia (3x3, row-major, about center of mass)
  double inertia[9];

  /// Principal moments of inertia
  double principalMoment1, principalMoment2, principalMoment3;

  /// Principal axes of inertia (3 unit vectors)
  double axis1X, axis1Y, axis1Z;
  double axis2X, axis2Y, axis2Z;
  double axis3X, axis3Y, axis3Z;

  /// Gyration radii
  double gyrationRadius1, gyrationRadius2, gyrationRadius3;

  /// Whether the shape has a symmetry axis (#848: same `GProp_PrincipalProps` the gyration
  /// radii above come from also has these; the older `OCCTInertiaProperties` sibling exposes
  /// them but this struct didn't, for no reason other than the two never being unified).
  bool hasSymmetryAxis;
  /// Whether the shape has a symmetry point
  bool hasSymmetryPoint;
} OCCTVolumeInertiaResult;

/// Compute volume inertia properties of a shape.
/// Returns volume, center of mass, inertia tensor, principal moments/axes.
/// @param shape Shape to analyze
/// @param result Output inertia result
/// @return true on success
bool OCCTShapeVolumeInertia(OCCTShapeRef shape, OCCTVolumeInertiaResult* result);

/// Surface inertia result (for area properties)
typedef struct
{
  double area;
  double centerX, centerY, centerZ;
  double inertia[9];
  double principalMoment1, principalMoment2, principalMoment3;

  /// Whether the shape has a symmetry axis (#848, see `OCCTVolumeInertiaResult`'s equivalent
  /// fields for why these were added)
  bool hasSymmetryAxis;
  /// Whether the shape has a symmetry point
  bool hasSymmetryPoint;
} OCCTSurfaceInertiaResult;

/// Compute surface (area) inertia properties of a shape.
/// @param shape Shape to analyze
/// @param result Output inertia result
/// @return true on success
bool OCCTShapeSurfaceInertia(OCCTShapeRef shape, OCCTSurfaceInertiaResult* result);

// MARK: - v0.63.0: GeomLProp, BRepOffset_SimpleOffset, Approx_CurvilinearParameter,
// GeomInt_IntSS, Contap_Contour, BRepFeat_Builder, GeomFill trihedrons/filling/sweep

// --- GeomLProp_CLProps ---
// Curve local properties at a parameter
typedef struct
{
  double px, py, pz; // point
  double tx, ty, tz; // tangent direction (0 if undefined)
  double nx, ny, nz; // normal direction (0 if undefined)
  double cx, cy, cz; // center of curvature (0 if undefined)
  double curvature;  // curvature value
  bool   tangentDefined;
  // Whether nx/ny/nz and cx/cy/cz hold anything: the curvature has to be invertible into a
  // radius, which rules out both zero (a straight stretch, or an inflection) and OCCT's
  // RealLast() infinite-curvature sentinel at a cusp. Added in #494 so callers stop re-deriving
  // it from `curvature` against a magic number of their own, the Swift wrapper used to test
  // `curvature > 1e-10`, which was a copy of a bridge-side literal that no longer exists.
  bool curvatureInvertible;
} OCCTCurveLocalProps;

OCCTCurveLocalProps OCCTGeomLPropCLProps(OCCTShapeRef edgeShape, double param);

// --- GeomLProp_SLProps ---
// Surface local properties at (U,V) on a face
typedef struct
{
  double px, py, pz;    // point
  double nx, ny, nz;    // normal (0 if undefined)
  double tuX, tuY, tuZ; // tangent U direction (0 if undefined)
  double tvX, tvY, tvZ; // tangent V direction (0 if undefined)
  double maxCurvature;
  double minCurvature;
  double meanCurvature;
  double gaussianCurvature;
  bool   normalDefined;
  bool   curvatureDefined;
  bool   isUmbilic;
} OCCTSurfaceLocalProps;

OCCTSurfaceLocalProps OCCTGeomLPropSLProps(OCCTShapeRef faceShape, double u, double v);

// MARK: - BRepGProp_MeshCinert (Mesh Linear Properties)

/// Prepare polygon points from a meshed edge. Returns point count, fills coords (x,y,z triples).
int32_t OCCTMeshCinertPreparePolygon(OCCTEdgeRef _Nonnull edge,
                                     double* _Nonnull coords,
                                     int32_t maxPoints);

/// Compute linear mass properties of a polygon (length, center of mass).
typedef struct
{
  double mass; // Length
  double centerX, centerY, centerZ;
} OCCTMeshCinertResult;

OCCTMeshCinertResult OCCTMeshCinertCompute(const double* _Nonnull coords, int32_t pointCount);

// MARK: - BRepGProp_MeshProps (Mesh Surface/Volume Properties)

/// Mesh property type.
typedef enum
{
  OCCTMeshPropsVolume  = 0, // Vinert
  OCCTMeshPropsSurface = 1  // Sinert
} OCCTMeshPropsType;

/// Compute mesh properties for a triangulated face.
typedef struct
{
  double mass; // Area (Sinert) or volume contribution (Vinert)
  double centerX, centerY, centerZ;
} OCCTMeshPropsResult;

OCCTMeshPropsResult OCCTMeshPropsCompute(OCCTFaceRef _Nonnull face, OCCTMeshPropsType type);

// MARK: - BRepGProp_Cinert (Curve Inertia)

/// Compute curve linear inertia properties for an edge.
typedef struct
{
  double mass; // Length
  double centerX, centerY, centerZ;
} OCCTCurveInertiaResult;

OCCTCurveInertiaResult OCCTBRepGPropCinert(OCCTEdgeRef _Nonnull edge);

// MARK: - BRepGProp_Sinert (Surface Inertia per Face)

/// Compute surface inertia properties for a single face.
typedef struct
{
  double mass; // Area
  double centerX, centerY, centerZ;
  double epsilon; // Adaptive integration error (0 for non-adaptive)
} OCCTFaceSurfaceInertia;

OCCTFaceSurfaceInertia OCCTBRepGPropSinert(OCCTFaceRef _Nonnull face);
OCCTFaceSurfaceInertia OCCTBRepGPropSinertAdaptive(OCCTFaceRef _Nonnull face, double epsilon);

// MARK: - BRepGProp_Vinert (Volume Inertia per Face)

/// Compute volume inertia properties from a single face.
typedef struct
{
  double mass; // Volume contribution
  double centerX, centerY, centerZ;
} OCCTFaceVolumeInertia;

OCCTFaceVolumeInertia OCCTBRepGPropVinert(OCCTFaceRef _Nonnull face);
OCCTFaceVolumeInertia OCCTBRepGPropVinertPlane(OCCTFaceRef _Nonnull face,
                                               double planeNX,
                                               double planeNY,
                                               double planeNZ,
                                               double planeDist);

// --- BRepGProp_VinertGK ---
typedef struct
{
  double mass;
  double errorReached; // BRepGProp_VinertGK::GetErrorReached() (#732)
  double centerX, centerY, centerZ;
} OCCTVinertGKResult;

OCCTVinertGKResult OCCTBRepGPropVinertGK(OCCTShapeRef _Nonnull faceRef,
                                         double locX,
                                         double locY,
                                         double locZ,
                                         double tolerance,
                                         bool   computeCG);

// MARK: - BRepGProp_Domain (v0.97.0)

/// Count boundary edges of a face.
int32_t OCCTShapeFaceDomainEdgeCount(OCCTShapeRef _Nonnull shape, int32_t faceIndex);

// MARK: - GProp Cylinder/Cone (v0.104.0)

/// Cylinder lateral surface area.
double OCCTGPropCylinderSurface(double radius, double height);

/// Cylinder volume.
double OCCTGPropCylinderVolume(double radius, double height);

/// Cone lateral surface area (from V=0 to V=height).
double OCCTGPropConeSurface(double semiAngle, double refRadius, double height);

/// Cone volume (from V=0 to V=height).
double OCCTGPropConeVolume(double semiAngle, double refRadius, double height);

// MARK: - GProp Element Properties (v0.103.0)

/// Compute curve element (line segment) properties: length and center of mass.
/// @return false when OCCT rejected the input, which for a segment means two coincident endpoints
///         (`gp_Dir` throws on the zero direction). That used to surface as a length of 0 with a
///         centre of (0,0,0), which reads as a successful answer (#609).
bool OCCTGPropLineSegment(double x1,
                          double y1,
                          double z1,
                          double x2,
                          double y2,
                          double z2,
                          double* _Nonnull outLength,
                          double* _Nonnull cx,
                          double* _Nonnull cy,
                          double* _Nonnull cz);

/// Compute curve element (circular arc) properties: arc length and center of mass.
/// @return false when OCCT rejected the input, which for an arc means a zero normal vector. A
///         valid arc with u1 == u2 succeeds with a length of 0 and a correct centre (#609).
bool OCCTGPropCircularArc(double centerX,
                          double centerY,
                          double centerZ,
                          double normalX,
                          double normalY,
                          double normalZ,
                          double radius,
                          double u1,
                          double u2,
                          double* _Nonnull outLength,
                          double* _Nonnull cx,
                          double* _Nonnull cy,
                          double* _Nonnull cz);

/// Compute point set center of mass. points is array of [x,y,z,...]. Returns mass (count).
double OCCTGPropPointSetCentroid(const double* _Nonnull points,
                                 int32_t count,
                                 double* _Nonnull cx,
                                 double* _Nonnull cy,
                                 double* _Nonnull cz);

/// Compute sphere surface area and center of mass.
double OCCTGPropSphereSurface(double radius,
                              double* _Nonnull cx,
                              double* _Nonnull cy,
                              double* _Nonnull cz);

/// Compute sphere volume and center of mass.
double OCCTGPropSphereVolume(double radius,
                             double* _Nonnull cx,
                             double* _Nonnull cy,
                             double* _Nonnull cz);

// MARK: - GProp Torus (v0.105.0)

/// Compute torus surface area (full torus).
double OCCTGPropTorusSurface(double majorRadius, double minorRadius);

/// Compute torus volume (full torus).
double OCCTGPropTorusVolume(double majorRadius, double minorRadius);

// MARK: - GProp weighted point sets (v0.105.0)

/// Compute weighted centroid of a point set. Returns total mass (sum of weights), or 0 when there
/// is no centroid to report: an empty set, or one OCCT rejected because a weight was not strictly
/// positive (`GProp_PGProps::AddPoint` throws `Standard_DomainError` on the first such weight, so
/// one bad weight discards the whole set). The `cx`/`cy`/`cz` outputs are meaningless then (#609).
double OCCTGPropPointSetWeightedCentroid(const double* _Nonnull points,
                                         const double* _Nonnull weights,
                                         int32_t count,
                                         double* _Nonnull cx,
                                         double* _Nonnull cy,
                                         double* _Nonnull cz);

/// Compute barycentre of a point set (equal weights).
/// @return false for an empty set, which has no barycentre; the (0,0,0) reported there was
///         indistinguishable from the barycentre of a set centred on the origin (#609).
bool OCCTGPropBarycentre(const double* _Nonnull points,
                         int32_t count,
                         double* _Nonnull cx,
                         double* _Nonnull cy,
                         double* _Nonnull cz);

// MARK: - GeomGridEval_Curve / Geom2dGridEval_Curve / GeomGridEval_Surface (v0.111.0)
//
// #486: OCCTGridEvalCurveD0/D1, OCCTGridEvalCurve2dD0/D1 and OCCTGridEvalSurfaceD0/D1 lived
// here, a third spelling of the batch grid-evaluation job, calling exactly the same OCCT
// evaluators as v0.29.0's OCCTCurve3DEvaluateGrid/D1, OCCTCurve2DEvaluateGrid/D1 and
// OCCTSurfaceEvaluateGrid. The Surface pair is what made the duplication load-bearing: it
// wrote a U-major grid while OCCTSurfaceEvaluateGrid wrote V-major, both headers describing
// their own layout as "row-major". Removed; OCCTSurfaceEvaluateGridD1 (declared with its D0
// sibling, above) is the surviving surface-D1 entry point, and the Swift spellings
// (Curve3D/Curve2D.gridEvalD0/D1, Surface.gridEvalD0/D1) forward to the v0.29.0 family.

// MARK: - BRepLProp_CLProps (v0.111.0)
//
// Every function in this section and the SLProps one below builds its props through
// occtEdgeLocalProps / occtFaceLocalProps, so it asks whether a quantity exists at the same
// resolution as the GeomLProp_*-backed OCCTEdgeGet*3D / OCCTFaceGet* entry points (#529).

/// Get point on edge at parameter using local properties.
/// Returns true if the point was computed, false for a null edge or a parameter the edge's curve
/// cannot be evaluated at.
bool OCCTEdgeLPropValue(OCCTShapeRef _Nonnull edge,
                        double param,
                        double* _Nonnull x,
                        double* _Nonnull y,
                        double* _Nonnull z);

/// Get tangent direction on edge at parameter. Returns true if tangent is defined.
bool OCCTEdgeLPropTangent(OCCTShapeRef _Nonnull edge,
                          double param,
                          double* _Nonnull dx,
                          double* _Nonnull dy,
                          double* _Nonnull dz);

/// Get curvature on edge at parameter. Returns true if the curvature exists there, and false for a
/// null handle, a Shape that is not an edge, and an edge whose tangent is undefined at that
/// parameter: a degenerate edge, which every sphere carries at its poles, and which used to
/// report 0, a straight edge's real answer (#595). A cusp reports true with OCCT's RealLast()
/// infinity sentinel, matching OCCTEdgeGetCurvature3D.
bool OCCTEdgeLPropCurvature(OCCTShapeRef _Nonnull edge, double param, double* _Nonnull curvature);

/// Get normal direction on edge at parameter.
/// Returns false where there is no normal to report: an undefined tangent, or a curvature that
/// cannot be inverted (null on a straight stretch, RealLast() at a cusp).
bool OCCTEdgeLPropNormal(OCCTShapeRef _Nonnull edge,
                         double param,
                         double* _Nonnull dx,
                         double* _Nonnull dy,
                         double* _Nonnull dz);

/// Get centre of curvature on edge at parameter.
/// Returns false under the same conditions as OCCTEdgeLPropNormal. In particular a near-cusp used
/// to be reported as a successfully computed point of (nan, inf, nan) (#529, and #494 before it).
bool OCCTEdgeLPropCentreOfCurvature(OCCTShapeRef _Nonnull edge,
                                    double param,
                                    double* _Nonnull x,
                                    double* _Nonnull y,
                                    double* _Nonnull z);

/// Get first derivative on edge at parameter. Returns true if it was computed.
bool OCCTEdgeLPropD1(OCCTShapeRef _Nonnull edge,
                     double param,
                     double* _Nonnull d1x,
                     double* _Nonnull d1y,
                     double* _Nonnull d1z);

// MARK: - BRepLProp_SLProps (v0.111.0)
//
// #583: the six value-reporting entry points below report definedness the way
// OCCTFaceGetMeanCurvature and its siblings do: bool return, value in an out-parameter. They used
// to return the value bare and spell "undefined here" as 0, which is not a spare encoding, because
// a cylinder's Gaussian and maximum curvature are exactly 0 at every point with the curvature
// perfectly well defined.

/// Get point on face at (u, v) using local surface properties.
/// Returns false for a null handle or a shape that is not a face; the point itself does not depend
/// on the curvature gate, so it is reported at a cone apex and a sphere pole too.
bool OCCTFaceLPropValue(OCCTShapeRef _Nonnull face,
                        double u,
                        double v,
                        double* _Nonnull x,
                        double* _Nonnull y,
                        double* _Nonnull z);

/// Get normal on face at (u, v). Returns true if normal is defined.
bool OCCTFaceLPropNormal(OCCTShapeRef _Nonnull face,
                         double u,
                         double v,
                         double* _Nonnull dx,
                         double* _Nonnull dy,
                         double* _Nonnull dz);

/// Get maximum curvature on face at (u, v). Returns true if curvature is defined there.
bool OCCTFaceLPropMaxCurvature(OCCTShapeRef _Nonnull face,
                               double u,
                               double v,
                               double* _Nonnull curvature);

/// Get minimum curvature on face at (u, v). Returns true if curvature is defined there.
bool OCCTFaceLPropMinCurvature(OCCTShapeRef _Nonnull face,
                               double u,
                               double v,
                               double* _Nonnull curvature);

/// Get mean curvature on face at (u, v). Returns true if curvature is defined there.
bool OCCTFaceLPropMeanCurvature(OCCTShapeRef _Nonnull face,
                                double u,
                                double v,
                                double* _Nonnull curvature);

/// Get Gaussian curvature on face at (u, v). Returns true if curvature is defined there.
bool OCCTFaceLPropGaussianCurvature(OCCTShapeRef _Nonnull face,
                                    double u,
                                    double v,
                                    double* _Nonnull curvature);

/// Check if face at (u, v) is umbilic (all curvatures equal).
/// Returns true if curvature is defined there, i.e. if the question has an answer at all; the
/// answer itself goes to isUmbilic. A false return used to be indistinguishable from "not umbilic".
bool OCCTFaceLPropIsUmbilic(OCCTShapeRef _Nonnull face,
                            double u,
                            double v,
                            bool* _Nonnull isUmbilic);

/// Get tangent in U direction on face at (u, v). Returns true if tangent is defined.
bool OCCTFaceLPropTangentU(OCCTShapeRef _Nonnull face,
                           double u,
                           double v,
                           double* _Nonnull dx,
                           double* _Nonnull dy,
                           double* _Nonnull dz);

/// Get tangent in V direction on face at (u, v), the other axis of the tangent plane. #266
/// follow-up.
bool OCCTFaceLPropTangentV(OCCTShapeRef _Nonnull face,
                           double u,
                           double v,
                           double* _Nonnull dx,
                           double* _Nonnull dy,
                           double* _Nonnull dz);

// --- Shape mass properties expansion ---

/// Get linear properties (length + center of mass) for wires/edges.
/// @return false when the shape has no edges, so no length and no centroid (#609).
bool OCCTShapeLinearProperties(OCCTShapeRef _Nonnull shape,
                               double* _Nonnull length,
                               double* _Nonnull cx,
                               double* _Nonnull cy,
                               double* _Nonnull cz);

/// Get the moments of inertia (Ixx, Iyy, Izz) and products of inertia (Ixy, Ixz, Iyz) for a shape.
/// These are the diagonal and off-diagonal terms of `GProp_GProps::MatrixOfInertia`, referenced to
/// the centre of mass, not `StaticMoments()`, which is a different quantity about the origin.
/// @return false when the shape has no closed volume, so no inertia tensor (#609).
bool OCCTShapeMomentOfInertia(OCCTShapeRef _Nonnull shape,
                              double* _Nonnull ixx,
                              double* _Nonnull iyy,
                              double* _Nonnull izz,
                              double* _Nonnull ixy,
                              double* _Nonnull ixz,
                              double* _Nonnull iyz);

/// Get the principal axes of inertia (3 direction vectors = 9 doubles).
/// @return false when the shape has no closed volume, so no principal axes (#609).
bool OCCTShapePrincipalAxes(OCCTShapeRef _Nonnull shape, double* _Nonnull axes9);

/// Get the radius of gyration about an arbitrary axis.
/// @return false when the shape has no closed volume, where OCCT's own answer is NaN (#609).
bool OCCTShapeRadiusOfGyration(OCCTShapeRef _Nonnull shape,
                               double ax,
                               double ay,
                               double az,
                               double dx,
                               double dy,
                               double dz,
                               double* _Nonnull outRadius);

#endif /* OCCTBridge_Properties_h */
