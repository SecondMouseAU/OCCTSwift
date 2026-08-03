//
//  OCCTBridge_Surface.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Surface domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Surface_h
#define OCCTBridge_Surface_h


void OCCTSurfaceRelease(OCCTSurfaceRef surface);

// Properties
void   OCCTSurfaceGetDomain(OCCTSurfaceRef surface,
                             double* uMin, double* uMax,
                             double* vMin, double* vMax);
bool   OCCTSurfaceIsUClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVClosed(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsUPeriodic(OCCTSurfaceRef surface);
bool   OCCTSurfaceIsVPeriodic(OCCTSurfaceRef surface);
double OCCTSurfaceGetUPeriod(OCCTSurfaceRef surface);
double OCCTSurfaceGetVPeriod(OCCTSurfaceRef surface);

// Evaluation
void OCCTSurfaceGetPoint(OCCTSurfaceRef surface, double u, double v,
                          double* x, double* y, double* z);
void OCCTSurfaceD1(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* dux, double* duy, double* duz,
                    double* dvx, double* dvy, double* dvz);
void OCCTSurfaceD2(OCCTSurfaceRef surface, double u, double v,
                    double* px, double* py, double* pz,
                    double* d1ux, double* d1uy, double* d1uz,
                    double* d1vx, double* d1vy, double* d1vz,
                    double* d2ux, double* d2uy, double* d2uz,
                    double* d2vx, double* d2vy, double* d2vz,
                    double* d2uvx, double* d2uvy, double* d2uvz);
bool OCCTSurfaceGetNormal(OCCTSurfaceRef surface, double u, double v,
                           double* nx, double* ny, double* nz);

// Analytic Surfaces
OCCTSurfaceRef OCCTSurfaceCreatePlane(double px, double py, double pz,
                                       double nx, double ny, double nz);
OCCTSurfaceRef OCCTSurfaceCreateCylinder(double px, double py, double pz,
                                          double dx, double dy, double dz,
                                          double radius);
OCCTSurfaceRef OCCTSurfaceCreateCone(double px, double py, double pz,
                                      double dx, double dy, double dz,
                                      double radius, double semiAngle);
OCCTSurfaceRef OCCTSurfaceCreateSphere(double cx, double cy, double cz,
                                        double radius);
OCCTSurfaceRef OCCTSurfaceCreateTorus(double px, double py, double pz,
                                       double dx, double dy, double dz,
                                       double majorRadius, double minorRadius);

// Swept Surfaces
OCCTSurfaceRef OCCTSurfaceCreateExtrusion(OCCTCurve3DRef profile,
                                           double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceCreateRevolution(OCCTCurve3DRef meridian,
                                            double px, double py, double pz,
                                            double dx, double dy, double dz);

// Freeform Surfaces
OCCTSurfaceRef OCCTSurfaceCreateBezier(const double* poles,
                                        int32_t uCount, int32_t vCount,
                                        const double* weights);
OCCTSurfaceRef OCCTSurfaceCreateBSpline(const double* poles,
                                         int32_t uPoleCount, int32_t vPoleCount,
                                         const double* weights,
                                         const double* uKnots, int32_t uKnotCount,
                                         const double* vKnots, int32_t vKnotCount,
                                         const int32_t* uMults, const int32_t* vMults,
                                         int32_t uDegree, int32_t vDegree);

// Operations
OCCTSurfaceRef OCCTSurfaceTrim(OCCTSurfaceRef surface,
                                double u1, double u2, double v1, double v2);
OCCTSurfaceRef OCCTSurfaceOffset(OCCTSurfaceRef surface, double distance);
OCCTSurfaceRef OCCTSurfaceTranslate(OCCTSurfaceRef surface,
                                     double dx, double dy, double dz);
OCCTSurfaceRef OCCTSurfaceRotate(OCCTSurfaceRef surface,
                                  double axOx, double axOy, double axOz,
                                  double axDx, double axDy, double axDz,
                                  double angle);
OCCTSurfaceRef OCCTSurfaceScale(OCCTSurfaceRef surface,
                                 double cx, double cy, double cz, double factor);
OCCTSurfaceRef OCCTSurfaceMirrorPlane(OCCTSurfaceRef surface,
                                       double px, double py, double pz,
                                       double nx, double ny, double nz);
OCCTSurfaceRef OCCTSurfaceMirrorPoint(OCCTSurfaceRef surface,
                                       double px, double py, double pz);
OCCTSurfaceRef OCCTSurfaceMirrorAxis(OCCTSurfaceRef surface,
                                      double px, double py, double pz,
                                      double dx, double dy, double dz);

// Conversion
OCCTSurfaceRef OCCTSurfaceToBSpline(OCCTSurfaceRef surface);
/// Approximate a surface as a BSpline surface. Returns the fit whenever GeomConvert_ApproxSurface
/// produced one (HasResult), which per OCCT includes a best-effort fit outside `tolerance` — use
/// OCCTGeomConvertApproxSurface for the same fit plus its maxError/isDone. Both share one
/// implementation, including the PrecisCode they pass (#491). `continuity` applies to both
/// parametric directions; the detailed entry point takes them separately.
OCCTSurfaceRef OCCTSurfaceApproximate(OCCTSurfaceRef surface, double tolerance,
                                       int32_t continuity, int32_t maxSegments,
                                       int32_t maxDegree);

// Iso Curves (returns Curve3D)
OCCTCurve3DRef OCCTSurfaceUIso(OCCTSurfaceRef surface, double u);
OCCTCurve3DRef OCCTSurfaceVIso(OCCTSurfaceRef surface, double v);

// Pipe Surface (GeomFill_Pipe)
OCCTSurfaceRef OCCTSurfaceCreatePipe(OCCTCurve3DRef path, double radius);
OCCTSurfaceRef OCCTSurfaceCreatePipeWithSection(OCCTCurve3DRef path,
                                                 OCCTCurve3DRef section);

// Draw Methods (discretization for Metal)
/// Draw iso-parameter grid lines: uCount U-iso lines + vCount V-iso lines
/// Returns total point count. outXYZ[pointIndex*3..+3] for coordinates.
/// outLineLengths[lineIndex] = number of points in that line.
int32_t OCCTSurfaceDrawGrid(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             int32_t pointsPerLine,
                             double* outXYZ, int32_t maxPoints,
                             int32_t* outLineLengths, int32_t maxLines);

/// Sample a uniform grid of points for mesh triangulation.
/// Returns total point count (uCount * vCount), or 0 on failure.
/// uCount and vCount must each be **at least 1**, not 2: this samples Geom_Surface::D0 over the
/// sampled range and a single iso-row (or a single point) is a valid request (#620).
/// The sampled range is the surface's parametric bounds with infinite ends clamped to ±100, so on
/// an unbounded surface a single sample lands on the clamp (-100), not on the surface's own uMin.
/// Output is U-major, `outXYZ[(iu * vCount + iv) * 3 + {0,1,2}]`, matching occtSurfaceGridIndex.
int32_t OCCTSurfaceDrawMesh(OCCTSurfaceRef surface,
                             int32_t uCount, int32_t vCount,
                             double* outXYZ);

// Local Properties (GeomLProp_SLProps)

/// Get Gaussian / mean curvature at (u, v). Both return true if the curvature exists there, and
/// false for a null surface, a parameter that cannot be evaluated, and a point where
/// IsCurvatureDefined() is false (a cone apex, a sphere pole). Each used to return the value bare
/// with 0 for the undefined case, which is also a plane's mean curvature and the Gaussian curvature
/// of every point of every plane, cylinder and cone -- whole surfaces reading as "no answer" (#595).
/// Same shape as their OCCTFaceGetGaussianCurvature / OCCTFaceGetMeanCurvature counterparts.
bool   OCCTSurfaceGetGaussianCurvature(OCCTSurfaceRef surface, double u, double v,
                                        double* _Nonnull curvature);
bool   OCCTSurfaceGetMeanCurvature(OCCTSurfaceRef surface, double u, double v,
                                    double* _Nonnull curvature);
bool   OCCTSurfaceGetPrincipalCurvatures(OCCTSurfaceRef surface, double u, double v,
                                          double* kMin, double* kMax,
                                          double* d1x, double* d1y, double* d1z,
                                          double* d2x, double* d2y, double* d2z);

// Bounding Box
bool OCCTSurfaceGetBoundingBox(OCCTSurfaceRef surface,
                                double* xMin, double* yMin, double* zMin,
                                double* xMax, double* yMax, double* zMax);

// BSpline Queries
int32_t OCCTSurfaceGetUPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVPoleCount(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetPoles(OCCTSurfaceRef surface, double* outXYZ);
int32_t OCCTSurfaceGetUDegree(OCCTSurfaceRef surface);
int32_t OCCTSurfaceGetVDegree(OCCTSurfaceRef surface);

// MARK: - Batch Surface Evaluation (v0.29.0)

/// Evaluate a surface at a grid of UV parameter values (batch).
///
/// Output is **U-major**, u varying slowest and v fastest:
/// `outXYZ[(iu * vCount + iv) * 3 + {0,1,2}]`. Same layout as OCCTSurfaceDrawMesh and
/// OCCTSurfaceEvaluateGridD1. It was v-major until #486, which is why the Swift wrapper no
/// longer transposes.
///
/// @param surface The surface to evaluate
/// @param uParams Array of U parameter values
/// @param uCount Number of U parameters
/// @param vParams Array of V parameter values
/// @param vCount Number of V parameters
/// @param outXYZ Output buffer for xyz triples (must hold 3 * uCount * vCount doubles)
/// @return Number of points evaluated (uCount * vCount on success, 0 on failure)
int32_t OCCTSurfaceEvaluateGrid(OCCTSurfaceRef surface,
                                 const double* uParams, int32_t uCount,
                                 const double* vParams, int32_t vCount,
                                 double* outXYZ);

/// Evaluate a surface and its first partial derivatives at a grid of UV parameters (batch).
///
/// Output is **U-major**, identical indexing to OCCTSurfaceEvaluateGrid:
/// `outXYZ[(iu * vCount + iv) * 3 + {0,1,2}]`, and likewise for the two derivative buffers.
///
/// @param surface The surface to evaluate
/// @param uParams Array of U parameter values
/// @param uCount Number of U parameters
/// @param vParams Array of V parameter values
/// @param vCount Number of V parameters
/// @param outXYZ Output buffer for point xyz triples (3 * uCount * vCount doubles)
/// @param outD1U Output buffer for dS/du xyz triples (3 * uCount * vCount doubles)
/// @param outD1V Output buffer for dS/dv xyz triples (3 * uCount * vCount doubles)
/// @return Number of points evaluated (uCount * vCount on success, 0 on failure)
int32_t OCCTSurfaceEvaluateGridD1(OCCTSurfaceRef surface,
                                   const double* uParams, int32_t uCount,
                                   const double* vParams, int32_t vCount,
                                   double* outXYZ, double* outD1U, double* outD1V);

// MARK: - Curve-Surface Intersection (v0.30.0)

/// Result structure for curve-surface intersection.
typedef struct {
    double point[3];    ///< Intersection point (x, y, z)
    double paramCurve;  ///< W parameter on the curve
    double paramU;      ///< U parameter on the surface
    double paramV;      ///< V parameter on the surface
} OCCTCurveSurfaceIntersection;

/// Compute intersection points between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @param outHits Output buffer for intersection results
/// @param maxHits Maximum number of results to write
/// @return Number of intersections found, or 0 on failure
int32_t OCCTCurve3DIntersectSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                     OCCTCurveSurfaceIntersection* outHits, int32_t maxHits);

// MARK: - Surface-Surface Intersection (v0.30.0)

/// Compute intersection curves between two surfaces.
/// @param s1 First surface
/// @param s2 Second surface
/// @param tolerance Intersection tolerance
/// @param outCurves Output buffer for intersection curve references
/// @param maxCurves Maximum number of curves to write
/// @return Number of intersection curves found, or 0 on failure
int32_t OCCTSurfaceIntersect(OCCTSurfaceRef s1, OCCTSurfaceRef s2, double tolerance,
                              OCCTCurve3DRef* outCurves, int32_t maxCurves);

// MARK: - Curve-Surface Distance (v0.30.0)

/// Compute the minimum distance between a 3D curve and a surface.
/// @param curve The 3D curve
/// @param surface The surface
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DDistanceToSurface(OCCTCurve3DRef curve, OCCTSurfaceRef surface);

// MARK: - Canonical Recognition (v0.30.0)

/// Structure describing a recognized canonical geometric form.
typedef struct {
    int32_t type;       ///< 0=unknown, 1=plane, 2=cylinder, 3=cone, 4=sphere, 5=line, 6=circle, 7=ellipse
    double origin[3];   ///< Origin point (x, y, z)
    double direction[3];///< Direction or normal (x, y, z)
    double radius;      ///< Primary radius (for cylinder/cone/sphere/circle)
    double radius2;     ///< Secondary radius (for cone/ellipse)
    double gap;         ///< Approximation gap
} OCCTCanonicalForm;

/// Attempt to recognize a shape as a canonical geometric form.
/// @param shape The shape to recognize (face, edge, etc.)
/// @param tolerance Recognition tolerance
/// @return Recognized form (type=0 if unrecognized)
OCCTCanonicalForm OCCTShapeRecognizeCanonical(OCCTShapeRef shape, double tolerance);

// MARK: - Bezier Surface Fill (v0.31.0)

/// Create a Bezier surface by filling 4 Bezier boundary curves.
/// @param c1, c2, c3, c4 The four boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill4(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                        int32_t fillStyle);

/// Create a Bezier surface by filling 2 Bezier boundary curves.
/// @param c1, c2 The two boundary curves (must be Bezier curves)
/// @param fillStyle Filling style: 0=stretch, 1=coons, 2=curved
/// @return Surface reference, or NULL on failure
OCCTSurfaceRef OCCTSurfaceBezierFill2(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                        int32_t fillStyle);

// MARK: - Surface-Surface Intersection (v0.35.0)

/// Compute intersection curves between two parametric surfaces.
/// @param surface1 First surface
/// @param surface2 Second surface
/// @param tolerance Tolerance
/// @param outCurves Output array of Curve3D refs (caller must release each)
/// @param maxCurves Maximum number of output curves
/// @return Number of intersection curves found
int32_t OCCTSurfaceSurfaceIntersect(OCCTSurfaceRef surface1, OCCTSurfaceRef surface2,
                                     double tolerance,
                                     OCCTCurve3DRef* outCurves, int32_t maxCurves);

// MARK: - Curve-Surface Intersection (v0.35.0)

/// Intersection result point for curve-surface intersection.
typedef struct {
    double x, y, z;    // 3D intersection point
    double u, v;       // Surface parameters at intersection
    double w;          // Curve parameter at intersection
} OCCTCurveSurfacePoint;

/// Compute intersection points between a curve and a surface.
/// @param curve The curve
/// @param surface The surface
/// @param outPoints Output array of intersection points
/// @param maxPoints Maximum number of output points
/// @return Number of intersection points found
int32_t OCCTCurveSurfaceIntersect(OCCTCurve3DRef curve, OCCTSurfaceRef surface,
                                   OCCTCurveSurfacePoint* outPoints, int32_t maxPoints);

// MARK: - Surface to Bezier Patches (v0.36.0)

/// Convert a BSpline surface to an array of Bezier surface patches.
/// @param surface The BSpline surface
/// @param outPatches Output array of surface refs (caller must release each)
/// @param maxPatches Maximum number of output patches
/// @return Number of Bezier patches produced
int32_t OCCTSurfaceToBezierPatches(OCCTSurfaceRef surface,
                                    OCCTSurfaceRef* outPatches, int32_t maxPatches);

// MARK: - Surface Singularity Analysis (v0.37.0)

/// Check if a surface has singularities (poles/degenerate points).
/// @param surface The surface to check
/// @param tolerance Precision for singularity detection
/// @return Number of singularities found (0 = none)
int32_t OCCTSurfaceSingularityCount(OCCTSurfaceRef surface, double tolerance);

/// Check if a surface is degenerated at a given point.
/// @param surface The surface
/// @param x, y, z The 3D point to check
/// @param tolerance Precision
/// @return true if the point is at a degenerate region
bool OCCTSurfaceIsDegenerated(OCCTSurfaceRef surface, double x, double y, double z, double tolerance);

/// Create a BSpline surface from 2 boundary curves (Stretch/Coons/Curved fill)
/// @param curve1 First boundary curve (OCCTCurve3DRef)
/// @param curve2 Second boundary curve
/// @param fillStyle 0=Stretch, 1=Coons, 2=Curved
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef OCCTSurfaceFillBSpline2Curves(OCCTCurve3DRef curve1, OCCTCurve3DRef curve2,
                                               int32_t fillStyle);

/// Create a BSpline surface from 4 boundary curves
/// @param c1,c2,c3,c4 Boundary curves in order
/// @param fillStyle 0=Stretch, 1=Coons, 2=Curved
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef OCCTSurfaceFillBSpline4Curves(OCCTCurve3DRef c1, OCCTCurve3DRef c2,
                                               OCCTCurve3DRef c3, OCCTCurve3DRef c4,
                                               int32_t fillStyle);

// MARK: - v0.44.0: Surface Extrema, Curve-on-Surface Check, Ellipse Arc, Edge Connect, Bezier Convert

/// Surface-to-surface extrema result
typedef struct {
    double distance;
    double p1X, p1Y, p1Z;  // Nearest point on surface 1
    double p2X, p2Y, p2Z;  // Nearest point on surface 2
    double u1, v1, u2, v2;  // UV parameters on each surface
} OCCTSurfaceExtremaResult;

/// Compute min distance between two surfaces
/// @param s1, s2 Surface handles
/// @param u1Min..v2Max UV bounds for each surface
/// @param outResult Result structure for the minimum distance
/// @return Number of extrema found, or 0 on failure
int32_t OCCTSurfaceExtrema(OCCTSurfaceRef s1, OCCTSurfaceRef s2,
                            double u1Min, double u1Max, double v1Min, double v1Max,
                            double u2Min, double u2Max, double v2Min, double v2Max,
                            OCCTSurfaceExtremaResult* outResult);

/// Check edge-on-surface consistency (max deviation between 3D curve and pcurve)
/// @param shape Shape containing edges and faces
/// @param outMaxDist Maximum distance found across all edge-face pairs
/// @param outMaxParam Parameter at maximum distance
/// @return true if check completed successfully
bool OCCTShapeCheckCurveOnSurface(OCCTShapeRef shape, double* outMaxDist, double* outMaxParam);

// --- GeomFill_ConstrainedFilling: BSpline surface from boundary curves ---

/// Result of constrained filling
typedef struct {
    bool isValid;
    int32_t uDegree;
    int32_t vDegree;
    int32_t uPoles;
    int32_t vPoles;
} OCCTConstrainedFillingInfo;

/// Create a BSpline surface by filling a region bounded by 3 or 4 curves.
/// Curves are specified as edges; the function extracts their geometric curves.
/// @param edge1,edge2,edge3 Three boundary edges (required)
/// @param edge4 Fourth boundary edge (optional, pass NULL for 3-sided fill)
/// @param maxDeg Maximum degree of the resulting surface
/// @param maxSeg Maximum number of segments
/// @return Face built on the filled surface, or NULL on failure
OCCTShapeRef OCCTGeomFillConstrained(OCCTEdgeRef edge1, OCCTEdgeRef edge2,
                                      OCCTEdgeRef edge3, OCCTEdgeRef edge4,
                                      int32_t maxDeg, int32_t maxSeg);

/// Get information about a constrained filling result surface.
/// @param face Face from constrained filling
/// @param info Output info struct
/// @return true on success
bool OCCTGeomFillConstrainedInfo(OCCTShapeRef face, OCCTConstrainedFillingInfo* info);

// --- ShapeAnalysis_FreeBoundsProperties ---
//
// OCCTFreeBoundsAnalyze, OCCTFreeBoundsGetClosedBoundInfo, OCCTFreeBoundsGetOpenBoundInfo,
// OCCTFreeBoundsGetClosedBoundWire and OCCTFreeBoundsGetOpenBoundWire were declared here.
// Each rebuilt a whole ShapeAnalysis_FreeBoundsProperties and re-ran Perform() from scratch,
// so a per-bound report cost one full free-bound search per bound; each also took a 0-based
// index while the later OCCTFreeBoundsProps* family, wrapping the identical OCCT class, took a
// 1-based one. Removed by #504: the one family, and the two structs that were declared here,
// are with the v0.114.0 block (search OCCTFreeBoundsPropsCreate).

// --- ShapeAnalysis_Surface expansion ---

/// Surface UV projection result
typedef struct {
    double u, v;   // Projected UV parameters
    double gap;    // Distance between 3D point and surface at (u,v)
} OCCTSurfaceUVResult;

/// Project a 3D point onto a surface to find UV parameters.
/// @param surface Surface to project onto
/// @param px,py,pz 3D point to project
/// @param precision Projection precision
/// @return UV coordinates and gap distance
OCCTSurfaceUVResult OCCTSurfaceValueOfUV(OCCTSurfaceRef surface,
    double px, double py, double pz, double precision);

/// Project a 3D point onto a surface using a previous UV as starting hint.
/// More efficient than ValueOfUV for iterative projections along a path.
/// @param surface Surface to project onto
/// @param prevU,prevV Previous UV hint
/// @param px,py,pz 3D point to project
/// @param precision Projection precision
/// @return UV coordinates and gap distance
OCCTSurfaceUVResult OCCTSurfaceNextValueOfUV(OCCTSurfaceRef surface,
    double prevU, double prevV, double px, double py, double pz, double precision);

/// Create a conical surface from axis, semi-angle, and base radius.
/// @param semiAngle Half-angle of the cone in radians (must be in (0, PI/2))
/// @param radius Base radius of the cone
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceConicalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double semiAngle, double radius);

/// Create a conical surface from two points and two radii.
/// @param r1 Radius at p1, r2 Radius at p2
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceConicalFromPointsRadii(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2);

/// Create a cylindrical surface from axis and radius.
OCCTSurfaceRef _Nullable OCCTSurfaceCylindricalFromAxis(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius);

/// Create a cylindrical surface from 3 points.
OCCTSurfaceRef _Nullable OCCTSurfaceCylindricalFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z);

/// Create a plane surface from 3 points.
OCCTSurfaceRef _Nullable OCCTSurfacePlaneFromPoints(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double p3x, double p3y, double p3z);

/// Create a plane surface from a point and normal direction.
OCCTSurfaceRef _Nullable OCCTSurfacePlaneFromPointNormal(
    double px, double py, double pz,
    double nx, double ny, double nz);

/// Create a trimmed conical surface from two endpoints and two radii.
/// @return Rectangular trimmed surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceTrimmedCone(
    double p1x, double p1y, double p1z,
    double p2x, double p2y, double p2z,
    double r1, double r2);

/// Create a trimmed cylindrical surface from axis, radius, and height.
OCCTSurfaceRef _Nullable OCCTSurfaceTrimmedCylinder(
    double axisX, double axisY, double axisZ,
    double dirX, double dirY, double dirZ,
    double radius, double height);

/// Result of BSpline surface knot splitting analysis.
typedef struct {
    int32_t nbUSplits;  // Number of U split indices
    int32_t nbVSplits;  // Number of V split indices
} OCCTSurfaceKnotSplitResult;

/// Analyze BSpline surface knot splitting at a given continuity level.
/// @param surface BSpline surface to analyze
/// @param uContinuity Desired U continuity, as a literal derivative order: a knot splits when
///   `degree - multiplicity < uContinuity`. Useful domain 0...U degree, saturating there: a
///   cubic with simple interior knots needs 3. See the #480 note in OCCTBridge_Internal.h
/// @param vContinuity Desired V continuity, same contract against the V degree and knots
/// @param outUParams Pre-allocated array for U split parameter values (may be NULL)
/// @param outUIndices Pre-allocated array for the 1-based U knot-table indices those parameters
///   were read from, i.e. `outUParams[i] == UKnot(outUIndices[i])` (may be NULL). #562: the
///   analyzer reports indices and this function converts them, so the caller only ever saw the
///   converted form and a second family of bridge functions existed to serve the raw one
/// @param maxU Capacity of outUParams and outUIndices
/// @param outVParams Pre-allocated array for V split parameter values (may be NULL)
/// @param outVIndices Pre-allocated array for the 1-based V knot-table indices (may be NULL)
/// @param maxV Capacity of outVParams and outVIndices
/// @return Split counts; nbUSplits/nbVSplits are the true counts even when writing
///   was truncated by maxU/maxV, so a caller can retry with a bigger buffer
OCCTSurfaceKnotSplitResult OCCTSurfaceKnotSplitting(OCCTSurfaceRef surface,
    int32_t uContinuity, int32_t vContinuity,
    double* outUParams, int32_t* outUIndices, int32_t maxU,
    double* outVParams, int32_t* outVIndices, int32_t maxV);

/// Join an array of Bezier surface patches into a single BSpline surface.
/// @param patches Array of surface handles (row-major, nRows x nCols)
/// @param nRows Number of rows in the patch grid
/// @param nCols Number of columns in the patch grid
/// @return BSpline surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTSurfaceJoinBezierPatches(
    const OCCTSurfaceRef _Nullable * _Nonnull patches,
    int32_t nRows, int32_t nCols);

/// Result of surface analytical conversion.
typedef struct {
    OCCTSurfaceRef _Nullable surface;  // Recognized analytical surface, or NULL
    double gap;  // Maximum deviation from original
} OCCTSurfaceAnalyticalResult;

/// Try to recognize an analytical surface (plane, cylinder, etc.) from a BSpline.
/// @param surface Input BSpline surface
/// @param tolerance Recognition tolerance
OCCTSurfaceAnalyticalResult OCCTSurfaceConvertToAnalytical(OCCTSurfaceRef surface, double tolerance);

/// Result of surface continuity splitting.
typedef struct {
    bool wasSplit;      // True if the surface was actually split
    bool isOk;          // True if no split was needed (already meets criterion)
    int32_t nUSplits;   // Number of U split values
    int32_t nVSplits;   // Number of V split values
} OCCTSurfaceContinuitySplitResult;

/// Split a BSpline surface at continuity breaks.
/// @param surface BSpline surface to split
/// @param criterion Continuity level: 0=C0, 1=C1, 2=C2, 3=C3
/// @param tolerance Tolerance for continuity checking
OCCTSurfaceContinuitySplitResult OCCTSurfaceSplitByContinuity(OCCTSurfaceRef surface,
    int32_t criterion, double tolerance);

/// Contour type enum: 0=Line, 1=Circle, 2=Walking, 3=Restriction
/// Compute analytical contours on a sphere with a view direction.
/// @return Number of contours, or -1 on failure. If circle, outCx/Cy/Cz/Cr are filled.
int32_t OCCTContapSphereDir(double cx, double cy, double cz, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData);

/// Compute analytical contours on a cylinder with a view direction.
int32_t OCCTContapCylinderDir(double px, double py, double pz,
    double axX, double axY, double axZ, double radius,
    double dirX, double dirY, double dirZ,
    int32_t* outType, double* outData);

/// Compute analytical contours on a sphere with an eye point (perspective).
int32_t OCCTContapSphereEye(double cx, double cy, double cz, double radius,
    double eyeX, double eyeY, double eyeZ,
    int32_t* outType, double* outData);
OCCTGeomIntSSRef _Nullable OCCTGeomIntSSCreate(OCCTShapeRef face1, OCCTShapeRef face2, double tolerance);
int OCCTGeomIntSSLineCount(OCCTGeomIntSSRef ref);
OCCTShapeRef _Nullable OCCTGeomIntSSLine(OCCTGeomIntSSRef ref, int index);
int OCCTGeomIntSSPointCount(OCCTGeomIntSSRef ref);
void OCCTGeomIntSSPoint(OCCTGeomIntSSRef ref, int index, double* x, double* y, double* z);
void OCCTGeomIntSSRelease(OCCTGeomIntSSRef ref);
OCCTContapContourRef _Nullable OCCTContapContourDirection(OCCTShapeRef faceShape,
    double dx, double dy, double dz);
OCCTContapContourRef _Nullable OCCTContapContourEye(OCCTShapeRef faceShape,
    double ex, double ey, double ez);
int OCCTContapContourLineCount(OCCTContapContourRef ref);
int OCCTContapContourLinePointCount(OCCTContapContourRef ref, int lineIndex);
void OCCTContapContourLinePoint(OCCTContapContourRef ref, int lineIndex, int pointIndex,
    double* x, double* y, double* z);
int OCCTContapContourLineType(OCCTContapContourRef ref, int lineIndex);
void OCCTContapContourRelease(OCCTContapContourRef ref);

// --- GeomFill Trihedron Laws ---
// Evaluate trihedron frame (tangent, normal, binormal) on an edge at parameter
typedef struct {
    double tx, ty, tz;  // tangent
    double nx, ny, nz;  // normal
    double bx, by, bz;  // binormal
} OCCTTrihedronFrame;

OCCTTrihedronFrame OCCTGeomFillDraftTrihedron(OCCTShapeRef edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ, double angle);
OCCTTrihedronFrame OCCTGeomFillDiscreteTrihedron(OCCTShapeRef edgeShape, double param);
OCCTTrihedronFrame OCCTGeomFillCorrectedFrenet(OCCTShapeRef edgeShape, double param);

// --- GeomFill_Coons / GeomFill_Curved ---
// Fill from 4 boundary point arrays; returns computed pole grid
// pointsPerSide: how many points define each boundary
// boundary arrays are flat [x,y,z, x,y,z, ...]
// outPoints: flat output [x,y,z, ...], maxPoints: max poles to write
// outNbU, outNbV: pole grid dimensions
// Returns: number of poles written
int OCCTGeomFillCoonsPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV);
int OCCTGeomFillCurvedPoles(
    const double* b1, const double* b2, const double* b3, const double* b4,
    int pointsPerSide, double* outPoints, int maxPoints,
    int* outNbU, int* outNbV);

// --- GeomFill_CoonsAlgPatch ---
// Evaluate Coons algorithmic patch from 4 boundary curves (edges)
void OCCTGeomFillCoonsAlgPatchEval(
    OCCTShapeRef edge1, OCCTShapeRef edge2, OCCTShapeRef edge3, OCCTShapeRef edge4,
    int evalU, int evalV, double* outPoints);

// --- GeomFill_Sweep ---
// Sweep a section curve along a path curve with corrected Frenet frame
// Returns the swept surface as a face
OCCTShapeRef _Nullable OCCTGeomFillSweep(OCCTShapeRef pathEdge, OCCTShapeRef sectionEdge);

// --- GeomFill_EvolvedSection ---
// Query section shape info from evolved section (curve + law)
typedef struct {
    int nbPoles;
    int nbKnots;
    int degree;
    bool isRational;
} OCCTEvolvedSectionInfo;

OCCTEvolvedSectionInfo OCCTGeomFillEvolvedSectionInfo(OCCTShapeRef edgeShape);

// --- Adaptor3d_IsoCurve ---
// Extract U-iso or V-iso curve from a face at given parameter
// isoType: 0 = IsoU, 1 = IsoV
// evalCount: number of evaluation points
// outPoints: flat [x,y,z,...] array of size evalCount*3
void OCCTAdaptor3dIsoCurveEval(OCCTShapeRef faceShape, int isoType, double param,
    int evalCount, double* outPoints);

// Extract iso-curve as an edge shape
OCCTShapeRef _Nullable OCCTAdaptor3dIsoCurveEdge(OCCTShapeRef faceShape, int isoType,
    double param, double p1, double p2);

// --- LocalAnalysis_SurfaceContinuity ---

/// Analyze local continuity between two surfaces at given UV parameters.
/// @param surface1 First surface
/// @param u1 U parameter on first surface
/// @param v1 V parameter on first surface
/// @param surface2 Second surface
/// @param u2 U parameter on second surface
/// @param v2 V parameter on second surface
/// @param order Analysis order — same vocabulary and same measured-set semantics as
///   OCCTLocalAnalysisCurveContinuity above.
/// @param outStatus Output: the *effective* analysis order (the request after saturation, echoed
///   back by `ContinuityStatus()`), never a measurement.
/// @param outC0Value Output: C0 distance
/// @param outG1Angle Output: G1 angle, or -1 if not measured at this order or not met
/// @param outC1UAngle Output: C1 U angle, or -1
/// @param outC1VAngle Output: C1 V angle, or -1
/// @return true if analysis succeeded
bool OCCTLocalAnalysisSurfaceContinuity(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order,
    int32_t* _Nonnull outStatus,
    double* _Nonnull outC0Value, double* _Nonnull outG1Angle,
    double* _Nonnull outC1UAngle, double* _Nonnull outC1VAngle);

/// Check boolean continuity flags for surface continuity analysis.
/// @param outMeasured Output: bitmask of the classes this order actually measured — see
///   OCCTLocalAnalysisCurveContinuityFlags for why the caller needs it.
/// @return Bitmask: bit 0=IsC0, bit 1=IsG1, bit 2=IsC1, bit 3=IsG2, bit 4=IsC2, masked to
///   `outMeasured`
int32_t OCCTLocalAnalysisSurfaceContinuityFlags(OCCTSurfaceRef _Nonnull surface1, double u1, double v1,
    OCCTSurfaceRef _Nonnull surface2, double u2, double v2, int32_t order,
    int32_t* _Nonnull outMeasured);

// --- GeomFill Trihedrons ---
/// Evaluate Darboux trihedron on a surface-curve (edge on face).
OCCTTrihedronFrame OCCTGeomFillDarbouxTrihedron(OCCTShapeRef _Nonnull edgeShape, OCCTShapeRef _Nonnull faceShape, double param);

/// Evaluate Fixed trihedron (constant tangent and normal).
OCCTTrihedronFrame OCCTGeomFillFixedTrihedron(
    double tangentX, double tangentY, double tangentZ,
    double normalX, double normalY, double normalZ, double param);

/// Evaluate Frenet trihedron on a curve.
OCCTTrihedronFrame OCCTGeomFillFrenetTrihedron(OCCTShapeRef _Nonnull edgeShape, double param);

/// Evaluate ConstantBiNormal trihedron on a curve.
OCCTTrihedronFrame OCCTGeomFillConstantBiNormalTrihedron(OCCTShapeRef _Nonnull edgeShape, double param,
    double biNormalX, double biNormalY, double biNormalZ);

// --- GeomFill_NSections ---
/// Create a BSpline surface by lofting through N section curves.
/// @param curveRefs Array of Curve3D handles (section curves)
/// @param params Array of parameter values for each section (0..1)
/// @param count Number of sections
/// @return Surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTGeomFillNSections(
    const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs,
    const double* _Nonnull params, int32_t count);

/// Query section shape info from N-sections surface creation.
/// Returns section pole count, knot count, and degree.
void OCCTGeomFillNSectionsInfo(
    const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs,
    const double* _Nonnull params, int32_t count,
    int32_t* _Nonnull outNbPoles, int32_t* _Nonnull outNbKnots, int32_t* _Nonnull outDegree);

// --- GeomFill_Generator ---

/// Generate a ruled/lofted surface from a sequence of section curves.
/// Uses GeomFill_Generator (linear interpolation in V direction).
/// @param curves Array of curve handles
/// @param curveCount Number of curves
/// @param tolerance Parametric tolerance
/// @return BSpline surface, or NULL on failure
OCCTSurfaceRef _Nullable OCCTGeomFillGenerator(
    const OCCTCurve3DRef _Nonnull * _Nonnull curves, int32_t curveCount,
    double tolerance);

// --- GeomFill_DegeneratedBound ---

/// Result struct for GeomFill boundary evaluation.
typedef struct {
    double x, y, z;
} OCCTBoundaryPoint;

/// Create a degenerated boundary (single point) and evaluate at parameter.
/// @return The degenerated point value
OCCTBoundaryPoint OCCTGeomFillDegeneratedBoundValue(
    double px, double py, double pz,
    double first, double last, double param);

/// Check if a degenerated boundary is degenerated (always true).
bool OCCTGeomFillDegeneratedBoundIsDegenerated(
    double px, double py, double pz, double first, double last);

// --- GeomFill_BoundWithSurf ---

/// Evaluate a boundary-with-surface at a parameter.
/// The boundary is defined by a 2D curve on a surface.
/// @param surface The surface
/// @param curve2d The 2D curve on the surface (Curve2D handle)
/// @param first, last Parameter range of the 2D curve
/// @param param Parameter to evaluate at
/// @param outX/Y/Z Output point coordinates
/// @param outNX/NY/NZ Output surface normal at that point
/// @return true if evaluation succeeded
bool OCCTGeomFillBoundWithSurfEvaluate(
    OCCTSurfaceRef _Nonnull surface,
    OCCTCurve2DRef _Nonnull curve2d,
    double first, double last, double param,
    double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ,
    double* _Nonnull outNX, double* _Nonnull outNY, double* _Nonnull outNZ);

// MARK: - ShapeCustom_Surface (additional: ConvertToPeriodic, Gap)

/// Convert surface to periodic form. Returns null if already periodic or not convertible.
OCCTSurfaceRef _Nullable OCCTSurfaceConvertToPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Get gap after last ShapeCustom_Surface conversion.
double OCCTSurfaceConversionGap(OCCTSurfaceRef _Nonnull surface);

// MARK: - GeomConvert_ApproxSurface

/// Approximate a surface as BSpline surface.
typedef struct {
    OCCTSurfaceRef _Nullable surface;  // result BSpline surface
    double maxError;
    bool isDone;
    bool hasResult;
} OCCTApproxSurfaceResult;

/// The same approximation OCCTSurfaceApproximate performs (one shared implementation since #491,
/// including the PrecisCode passed to GeomConvert_ApproxSurface), reporting the fit's maxError and
/// completion flags. `surface` is populated exactly when `hasResult`; `isDone` is whether the fit
/// reached `tolerance`. Note maxDegree comes BEFORE maxSegments here, the reverse of
/// OCCTSurfaceApproximate's argument order.
OCCTApproxSurfaceResult OCCTGeomConvertApproxSurface(OCCTSurfaceRef _Nonnull surface,
                                                      double tolerance,
                                                      int32_t uContinuity,
                                                      int32_t vContinuity,
                                                      int32_t maxDegree,
                                                      int32_t maxSegments);

/// Find UV parameters of 3D point on surface. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParametersSurface(OCCTSurfaceRef _Nonnull surface,
                                       double px, double py, double pz,
                                       double maxDist,
                                       double* _Nonnull outU, double* _Nonnull outV);

// MARK: - GeomLib_IsPlanarSurface

/// Check if a surface is planar within tolerance. Returns true if planar.
bool OCCTGeomLibIsPlanarSurface(OCCTSurfaceRef _Nonnull surface, double tolerance);

/// If surface is planar, get the plane parameters (origin + normal + X direction).
bool OCCTGeomLibPlanarSurfacePlane(OCCTSurfaceRef _Nonnull surface, double tolerance,
                                    double* _Nonnull ox, double* _Nonnull oy, double* _Nonnull oz,
                                    double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz,
                                    double* _Nonnull xx, double* _Nonnull xy, double* _Nonnull xz);

// MARK: - GeomConvert_SurfToAnaSurf

/// Result struct for surface-to-analytical conversion.
typedef struct {
    OCCTSurfaceRef _Nullable surface;  ///< Owned by the caller; independent of the input surface
    double gap;                        ///< Max deviation from the input; exactly 0 when already analytical
    bool success;
} OCCTSurfToAnaSurfResult;

/// Convert a surface to an analytical surface (plane, cylinder, cone, sphere, torus).
///
/// The sole unbounded entry point for GeomConvert_SurfToAnaSurf; the v0.30.0
/// OCCTSurfaceToAnalytical was retired into it (#492), along with its "if the result is the same
/// handle it was already analytical" guard, which never fired -- every branch of
/// ConvertToAnalytical allocates. An already-analytical input succeeds with gap 0.
OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalytical(OCCTSurfaceRef _Nonnull surfaceRef, double tolerance);

/// Convert, fitting only the [uMin, uMax] x [vMin, vMax] sub-patch. Inverted bounds fail (OCCT
/// throws Geom_BSplineSurface::Segment, caught here) rather than being normalised.
OCCTSurfToAnaSurfResult OCCTGeomConvertSurfToAnalyticalBounded(OCCTSurfaceRef _Nonnull surfaceRef,
                                                                  double tolerance,
                                                                  double uMin, double uMax,
                                                                  double vMin, double vMax);

/// Check if a surface is already canonical (analytical).
bool OCCTGeomConvertIsCanonical(OCCTSurfaceRef _Nonnull surfaceRef);

OCCTGeomFillProfilerRef OCCTGeomFillProfilerCreate(void);
void OCCTGeomFillProfilerAddCurve(OCCTGeomFillProfilerRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef);
bool OCCTGeomFillProfilerPerform(OCCTGeomFillProfilerRef _Nonnull ref, double tolerance);
int OCCTGeomFillProfilerDegree(OCCTGeomFillProfilerRef _Nonnull ref);
int OCCTGeomFillProfilerNbPoles(OCCTGeomFillProfilerRef _Nonnull ref);
int OCCTGeomFillProfilerNbKnots(OCCTGeomFillProfilerRef _Nonnull ref);
bool OCCTGeomFillProfilerIsPeriodic(OCCTGeomFillProfilerRef _Nonnull ref);
/// Gets poles for curve at index (1-based). outX/Y/Z must be sized to NbPoles.
bool OCCTGeomFillProfilerPoles(OCCTGeomFillProfilerRef _Nonnull ref, int curveIndex,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ, int maxPoles);
/// Gets knots and multiplicities. Arrays must be sized to NbKnots.
bool OCCTGeomFillProfilerKnotsAndMults(OCCTGeomFillProfilerRef _Nonnull ref,
                                        double* _Nonnull outKnots, int* _Nonnull outMults, int maxKnots);
void OCCTGeomFillProfilerRelease(OCCTGeomFillProfilerRef _Nonnull ref);

// --- GeomFill_Stretch ---
typedef struct {
    int nbUPoles;
    int nbVPoles;
    bool isRational;
} OCCTStretchFillResult;

/// Create stretch-filled surface from 4 boundary point arrays.
/// Each array is (x,y,z) triples; count is number of points per boundary.
OCCTStretchFillResult OCCTGeomFillStretch(const double* _Nonnull p1, const double* _Nonnull p2,
                                           const double* _Nonnull p3, const double* _Nonnull p4,
                                           int count,
                                           double* _Nullable outPoles, int maxPoles);

OCCTLocationDraftRef OCCTGeomFillLocationDraftCreate(double dirX, double dirY, double dirZ, double angle);
bool OCCTGeomFillLocationDraftSetCurve(OCCTLocationDraftRef _Nonnull ref, OCCTCurve3DRef _Nonnull curveRef);
bool OCCTGeomFillLocationDraftD0(OCCTLocationDraftRef _Nonnull ref, double param,
                                  double* _Nonnull mat, double* _Nonnull vecX, double* _Nonnull vecY, double* _Nonnull vecZ);
void OCCTGeomFillLocationDraftSetAngle(OCCTLocationDraftRef _Nonnull ref, double angle);
void OCCTGeomFillLocationDraftDirection(OCCTLocationDraftRef _Nonnull ref,
                                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);
void OCCTGeomFillLocationDraftRelease(OCCTLocationDraftRef _Nonnull ref);

OCCTGuideTrihedronACRef OCCTGeomFillGuideTrihedronACCreate(OCCTCurve3DRef _Nonnull guideCurveRef);
bool OCCTGeomFillGuideTrihedronACSetCurve(OCCTGuideTrihedronACRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef);
bool OCCTGeomFillGuideTrihedronACD0(OCCTGuideTrihedronACRef _Nonnull ref, double param,
                                     double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                     double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                     double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ);
void OCCTGeomFillGuideTrihedronACRelease(OCCTGuideTrihedronACRef _Nonnull ref);

OCCTGuideTrihedronPlanRef OCCTGeomFillGuideTrihedronPlanCreate(OCCTCurve3DRef _Nonnull guideCurveRef);
bool OCCTGeomFillGuideTrihedronPlanSetCurve(OCCTGuideTrihedronPlanRef _Nonnull ref, OCCTCurve3DRef _Nonnull pathCurveRef);
bool OCCTGeomFillGuideTrihedronPlanD0(OCCTGuideTrihedronPlanRef _Nonnull ref, double param,
                                       double* _Nonnull tX, double* _Nonnull tY, double* _Nonnull tZ,
                                       double* _Nonnull nX, double* _Nonnull nY, double* _Nonnull nZ,
                                       double* _Nonnull bX, double* _Nonnull bY, double* _Nonnull bZ);
void OCCTGeomFillGuideTrihedronPlanRelease(OCCTGuideTrihedronPlanRef _Nonnull ref);

// --- GeomFill_SectionPlacement ---
typedef struct {
    double parameterOnPath;
    double parameterOnSection;
    double distance;
    double angle;
    bool isDone;
} OCCTSectionPlacementResult;

/// Place a section curve on a path using LocationDraft law
OCCTSectionPlacementResult OCCTGeomFillSectionPlacement(OCCTCurve3DRef _Nonnull pathCurveRef,
                                                         OCCTCurve3DRef _Nonnull sectionCurveRef,
                                                         double dirX, double dirY, double dirZ,
                                                         double draftAngle, double tolerance);

// --- GeomFill_AppSurf ---
typedef struct {
    int uDegree;
    int vDegree;
    int nbUPoles;
    int nbVPoles;
    int nbUKnots;
    int nbVKnots;
    bool isDone;
} OCCTAppSurfResult;

/// Approximate surface from N section curves (uses GeomFill_SectionGenerator + GeomFill_AppSurf)
OCCTAppSurfResult OCCTGeomFillAppSurf(const OCCTCurve3DRef _Nonnull * _Nonnull curveRefs, int count,
                                       int degMin, int degMax, double tol3d, double tol2d);

// --- Extrema_ExtPS: Point-Surface distance ---
typedef struct {
    bool isDone;
    int nbExt;
} OCCTExtremaExtPSResult;

/// Compute point-to-surface extrema
OCCTExtremaExtPSResult OCCTExtremaExtPS(double px, double py, double pz,
                                         OCCTSurfaceRef _Nonnull surface);

typedef struct {
    double squareDistance;
    double x, y, z;
    double u, v;
} OCCTExtremaPointOnSurf;

/// Get Nth extremum from point-surface computation
OCCTExtremaPointOnSurf OCCTExtremaExtPSPoint(double px, double py, double pz,
                                              OCCTSurfaceRef _Nonnull surface, int index);

// --- Extrema_ExtSS: Surface-Surface distance ---
typedef struct {
    bool isDone;
    bool isParallel;
    int nbExt;
} OCCTExtremaExtSSResult;

/// Compute surface-to-surface extrema
OCCTExtremaExtSSResult OCCTExtremaExtSS(OCCTSurfaceRef _Nonnull surface1,
                                         OCCTSurfaceRef _Nonnull surface2);

/// Get Nth extremum from surface-surface computation
OCCTExtremaPointPair OCCTExtremaExtSSPoint(OCCTSurfaceRef _Nonnull surface1,
                                            OCCTSurfaceRef _Nonnull surface2, int index);

// --- gce_MakePln ---
/// Create a plane from equation Ax+By+Cz+D=0
OCCTSurfaceRef _Nullable OCCTGceMakePlnFromEquation(double a, double b, double c, double d);

/// Create a plane from 3 points
OCCTSurfaceRef _Nullable OCCTGceMakePlnFrom3Points(double p1x, double p1y, double p1z,
                                                    double p2x, double p2y, double p2z,
                                                    double p3x, double p3y, double p3z);

// MARK: - Geom_RectangularTrimmedSurface

/// Create a rectangular trimmed surface from a surface handle
OCCTSurfaceRef _Nullable OCCTSurfaceCreateRectangularTrimmed(OCCTSurfaceRef _Nonnull basisSurface,
                                                               double u1, double u2,
                                                               double v1, double v2);

/// Create a single-direction trimmed surface (U or V only)
OCCTSurfaceRef _Nullable OCCTSurfaceCreateTrimmedInU(OCCTSurfaceRef _Nonnull basisSurface,
                                                       double param1, double param2);

OCCTSurfaceRef _Nullable OCCTSurfaceCreateTrimmedInV(OCCTSurfaceRef _Nonnull basisSurface,
                                                       double param1, double param2);

// MARK: - ElSLib — Elementary Surface Library (v0.91.0)

/// Evaluate point on a plane at (u,v). Plane defined by origin + normal.
void OCCTElSLibValueOnPlane(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a cylinder at (u,v).
void OCCTElSLibValueOnCylinder(double u, double v,
                                double ox, double oy, double oz,
                                double nx, double ny, double nz, double radius,
                                double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a cone at (u,v).
void OCCTElSLibValueOnCone(double u, double v,
                            double ox, double oy, double oz,
                            double nx, double ny, double nz,
                            double refRadius, double semiAngle,
                            double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a sphere at (u,v).
void OCCTElSLibValueOnSphere(double u, double v,
                              double ox, double oy, double oz,
                              double nx, double ny, double nz, double radius,
                              double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Evaluate point on a torus at (u,v).
void OCCTElSLibValueOnTorus(double u, double v,
                             double ox, double oy, double oz,
                             double nx, double ny, double nz,
                             double majorRadius, double minorRadius,
                             double* _Nonnull outX, double* _Nonnull outY, double* _Nonnull outZ);

/// Get (u,v) parameters of nearest point on sphere.
void OCCTElSLibParametersOnSphere(double ox, double oy, double oz,
                                   double nx, double ny, double nz, double radius,
                                   double px, double py, double pz,
                                   double* _Nonnull outU, double* _Nonnull outV);

/// Evaluate point + partial derivatives on sphere at (u,v).
void OCCTElSLibD1OnSphere(double u, double v,
                           double ox, double oy, double oz,
                           double nx, double ny, double nz, double radius,
                           double* _Nonnull outPX, double* _Nonnull outPY, double* _Nonnull outPZ,
                           double* _Nonnull outVuX, double* _Nonnull outVuY, double* _Nonnull outVuZ,
                           double* _Nonnull outVvX, double* _Nonnull outVvY, double* _Nonnull outVvZ);

// MARK: - Convert_SphereToBSplineSurface (v0.94.0)

/// Convert a sphere to a BSpline surface.
/// @param ox,oy,oz Center
/// @param nx,ny,nz Axis direction
/// @param radius Sphere radius
/// @return Opaque surface handle, or NULL on failure
OCCTSurfaceRef _Nullable OCCTConvertSphereToBSplineSurface(double ox, double oy, double oz,
                                                             double nx, double ny, double nz,
                                                             double radius);

// MARK: - Convert_CylinderToBSplineSurface (v0.95.0)

/// Convert a cylinder patch to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertCylinderToBSplineSurface(double ox, double oy, double oz,
                                                               double nx, double ny, double nz,
                                                               double radius,
                                                               double u1, double u2,
                                                               double v1, double v2);

// MARK: - Convert_ConeToBSplineSurface (v0.95.0)

/// Convert a cone patch to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertConeToBSplineSurface(double ox, double oy, double oz,
                                                           double nx, double ny, double nz,
                                                           double semiAngle, double refRadius,
                                                           double u1, double u2,
                                                           double v1, double v2);

// MARK: - Convert_TorusToBSplineSurface (v0.95.0)

/// Convert a full torus to a BSpline surface.
OCCTSurfaceRef _Nullable OCCTConvertTorusToBSplineSurface(double ox, double oy, double oz,
                                                            double nx, double ny, double nz,
                                                            double majorRadius, double minorRadius);

// MARK: - Geom_OffsetSurface Extensions (v0.99.0)

/// Get the offset distance of an offset surface.
/// @return The offset value, or 0.0 if not an offset surface
double OCCTSurfaceOffsetValue(OCCTSurfaceRef _Nonnull surface);

/// Set the offset distance of an offset surface (mutates in place).
void OCCTSurfaceSetOffsetValue(OCCTSurfaceRef _Nonnull surface, double offset);

/// Get the basis (underlying) surface of an offset surface.
/// @return The basis surface, or NULL if not an offset surface
OCCTSurfaceRef _Nullable OCCTSurfaceOffsetBasis(OCCTSurfaceRef _Nonnull surface);

// --- ShapeAnalysis_Surface ---

/// Project a 3D point onto a surface, returning UV parameters and gap distance.
double OCCTSurfaceProjectPointUV(OCCTSurfaceRef _Nonnull surface,
                                   double px, double py, double pz, double preci,
                                   double* _Nonnull u, double* _Nonnull v);

/// Check if a surface has singularities at the given precision.
bool OCCTSurfaceHasSingularities(OCCTSurfaceRef _Nonnull surface, double preci);

/// Get number of singularities on a surface.
int32_t OCCTSurfaceNbSingularities(OCCTSurfaceRef _Nonnull surface, double preci);

/// Check if surface is spatially U-closed at given precision.
bool OCCTSurfaceIsUClosedSA(OCCTSurfaceRef _Nonnull surface, double preci);

/// Check if surface is spatially V-closed at given precision.
bool OCCTSurfaceIsVClosedSA(OCCTSurfaceRef _Nonnull surface, double preci);

// --- ShapeAnalysis_Surface extras + BRepGProp_Face (#266 follow-up) ---

/// Refine a (U,V) for a 3D point by projecting onto the surface's iso-lines; returns the 3D gap.
double OCCTSurfaceUVFromIso(OCCTSurfaceRef _Nonnull surface, double px, double py, double pz,
                            double preci, double* _Nonnull u, double* _Nonnull v);

/// Detail of singularity #num (1-based): pole 3D point, first/last 2D points + params of the
/// degenerate iso-line, and whether it is U-iso. `preci` is in/out. Returns false if num out of range.
bool OCCTSurfaceSingularityDetail(OCCTSurfaceRef _Nonnull surface, int32_t num, double* _Nonnull preci,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                  double* _Nonnull firstU, double* _Nonnull firstV,
                                  double* _Nonnull lastU, double* _Nonnull lastV,
                                  double* _Nonnull firstPar, double* _Nonnull lastPar,
                                  bool* _Nonnull uIsoDegenerate);

/// Adjust the indeterminate 2D coordinate of a point in a surface singularity, taking the fixed
/// coordinate from a neighbour 2D point. Returns the resolved (ru, rv).
bool OCCTSurfaceProjectDegenerated(OCCTSurfaceRef _Nonnull surface, double px, double py, double pz,
                                   double preci, double neighbourU, double neighbourV,
                                   double* _Nonnull ru, double* _Nonnull rv);

/// Project a 3D point onto a surface restricted to the [u1,u2]×[v1,v2] domain (SetDomain) — for
/// periodic / self-overlapping surfaces. Returns the 3D gap, or -1 on failure.
double OCCTSurfaceProjectPointUVInDomain(OCCTSurfaceRef _Nonnull surface, double px, double py, double pz,
                                         double preci, double u1, double u2, double v1, double v2,
                                         double* _Nonnull u, double* _Nonnull v);

/// BRepGProp_Face Gauss-integration orders in U and V (non-zero only for BSpline faces).
bool OCCTBRepGPropFaceIntegrationOrders(OCCTShapeRef _Nonnull face, int32_t* _Nonnull uOrder,
                                        int32_t* _Nonnull vOrder);

/// BRepGProp_Face U-direction integration knots; fills up to maxCount, returns the count.
int32_t OCCTBRepGPropFaceUKnots(OCCTShapeRef _Nonnull face, double* _Nullable buffer, int32_t maxCount);

/// BRepGProp_Face V-direction integration knots (companion to UKnots); fills up to maxCount, returns count.
int32_t OCCTBRepGPropFaceVKnots(OCCTShapeRef _Nonnull face, double* _Nullable buffer, int32_t maxCount);

/// BRepGProp_Face precision-driven surface integration parameters: order (points) for tolerance `eps`,
/// and the U / V subinterval counts. Returns false if `face` is not a face.
bool OCCTBRepGPropFaceSurfaceIntegration(OCCTShapeRef _Nonnull face, double eps,
                                         int32_t* _Nonnull order, int32_t* _Nonnull uSubs,
                                         int32_t* _Nonnull vSubs);

/// BRepGProp_Face boundary (edge-loaded) integration: loads face edge #edgeIndex as the boundary arc
/// and returns its integration order (for tolerance `eps`), subinterval count, and knots (up to
/// maxKnots into knotBuffer). Returns false if the face/edge is invalid or the edge can't be loaded.
bool OCCTBRepGPropFaceBoundaryIntegration(OCCTShapeRef _Nonnull face, int32_t edgeIndex, double eps,
                                          int32_t* _Nonnull order, int32_t* _Nonnull subs,
                                          double* _Nullable knotBuffer, int32_t maxKnots,
                                          int32_t* _Nonnull knotCount);

// MARK: - GC_MakeConicalSurface (v0.106.0)

/// Create a conical surface from axis (center+normal), semi-angle, and reference radius.
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface(double cx, double cy, double cz,
                                                    double nx, double ny, double nz,
                                                    double semiAngle, double radius);

/// Create a conical surface from 2 points and 2 radii.
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface2Pts(double x1, double y1, double z1,
                                                       double x2, double y2, double z2,
                                                       double r1, double r2);

/// Create a conical surface from 4 points (2 on each circle).
OCCTSurfaceRef _Nullable OCCTGCMakeConicalSurface4Pts(double x1, double y1, double z1,
                                                       double x2, double y2, double z2,
                                                       double x3, double y3, double z3,
                                                       double x4, double y4, double z4);

// MARK: - GC_MakeCylindricalSurface (v0.106.0)

/// Create a cylindrical surface from axis (center+normal) and radius.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurface(double cx, double cy, double cz,
                                                        double nx, double ny, double nz,
                                                        double radius);

/// Create a cylindrical surface from 3 points.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurface3Pts(double x1, double y1, double z1,
                                                            double x2, double y2, double z2,
                                                            double x3, double y3, double z3);

/// Create a cylindrical surface from a circle (center+normal+radius).
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceFromCircle(double cx, double cy, double cz,
                                                                  double nx, double ny, double nz,
                                                                  double radius);

/// Create a cylindrical surface parallel to another at a given distance.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceParallel(double cx, double cy, double cz,
                                                                double nx, double ny, double nz,
                                                                double radius, double dist);

/// Create a cylindrical surface from axis (point+direction) and radius.
OCCTSurfaceRef _Nullable OCCTGCMakeCylindricalSurfaceAxis(double px, double py, double pz,
                                                            double dx, double dy, double dz,
                                                            double radius);

// MARK: - GC_MakeTrimmedCone (v0.106.0)

/// Create a trimmed cone from 2 points and 2 radii.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCone2Pts(double x1, double y1, double z1,
                                                     double x2, double y2, double z2,
                                                     double r1, double r2);

/// Create a trimmed cone from 4 points.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCone4Pts(double x1, double y1, double z1,
                                                     double x2, double y2, double z2,
                                                     double x3, double y3, double z3,
                                                     double x4, double y4, double z4);

// MARK: - GC_MakeTrimmedCylinder (v0.106.0)

/// Create a trimmed cylinder from a circle (center+normal+radius) and height.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinderCircle(double cx, double cy, double cz,
                                                           double nx, double ny, double nz,
                                                           double radius, double height);

/// Create a trimmed cylinder from axis (point+direction), radius, and height.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinderAxis(double px, double py, double pz,
                                                         double dx, double dy, double dz,
                                                         double radius, double height);

/// Create a trimmed cylinder from 3 points.
OCCTSurfaceRef _Nullable OCCTGCMakeTrimmedCylinder3Pts(double x1, double y1, double z1,
                                                         double x2, double y2, double z2,
                                                         double x3, double y3, double z3);

// MARK: - Surface continuity (v0.106.0)

/// Get the global continuity of a surface.
///
/// Returns the raw GeomAbs_Shape ordinal: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN.
/// Returns 0 for a null surface.
int32_t OCCTSurfaceGetContinuity(OCCTSurfaceRef _Nonnull surface);

/// Get number of UV bounds for a surface.
void OCCTSurfaceGetNBounds(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull uSpans, int32_t* _Nonnull vSpans);

// MARK: - Geom_BSplineSurface Methods (v0.107.0)

/// Get the number of U knots.
int32_t OCCTSurfaceBSplineNbUKnots(OCCTSurfaceRef _Nonnull surface);

/// Get the number of V knots.
int32_t OCCTSurfaceBSplineNbVKnots(OCCTSurfaceRef _Nonnull surface);

/// Get the number of U poles.
int32_t OCCTSurfaceBSplineNbUPoles(OCCTSurfaceRef _Nonnull surface);

/// Get the number of V poles.
int32_t OCCTSurfaceBSplineNbVPoles(OCCTSurfaceRef _Nonnull surface);

/// Get the U degree.
int32_t OCCTSurfaceBSplineUDegree(OCCTSurfaceRef _Nonnull surface);

/// Get the V degree.
int32_t OCCTSurfaceBSplineVDegree(OCCTSurfaceRef _Nonnull surface);

/// Check if the surface is U-rational.
bool OCCTSurfaceBSplineIsURational(OCCTSurfaceRef _Nonnull surface);

/// Check if the surface is V-rational.
bool OCCTSurfaceBSplineIsVRational(OCCTSurfaceRef _Nonnull surface);

/// Get a pole at (uIndex, vIndex) — both 1-based.
void OCCTSurfaceBSplineGetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a pole at (uIndex, vIndex) — both 1-based.
bool OCCTSurfaceBSplineSetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double x, double y, double z);

/// Set the weight at (uIndex, vIndex).
bool OCCTSurfaceBSplineSetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex, double weight);

/// Insert a U knot.
bool OCCTSurfaceBSplineInsertUKnot(OCCTSurfaceRef _Nonnull surface, double u, int32_t mult, double tol);

/// Insert a V knot.
bool OCCTSurfaceBSplineInsertVKnot(OCCTSurfaceRef _Nonnull surface, double v, int32_t mult, double tol);

/// Segment the BSpline surface to [u1,u2] x [v1,v2].
bool OCCTSurfaceBSplineSegment(OCCTSurfaceRef _Nonnull surface, double u1, double u2, double v1, double v2);

/// Increase the degree to (uDeg, vDeg).
bool OCCTSurfaceBSplineIncreaseDegree(OCCTSurfaceRef _Nonnull surface, int32_t uDeg, int32_t vDeg);

/// Exchange U and V directions.
bool OCCTSurfaceBSplineExchangeUV(OCCTSurfaceRef _Nonnull surface);

// MARK: - Geom_Plane Methods (v0.108.0)

/// Get the plane coefficients (A, B, C, D) of a Geom_Plane.
void OCCTSurfacePlaneCoefficients(OCCTSurfaceRef _Nonnull surface, double* _Nonnull A, double* _Nonnull B, double* _Nonnull C, double* _Nonnull D);

/// Get a U iso-curve from a Geom_Plane.
OCCTCurve3DRef _Nullable OCCTSurfacePlaneUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// Get a V iso-curve from a Geom_Plane.
OCCTCurve3DRef _Nullable OCCTSurfacePlaneVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Get the gp_Pln data (origin + normal) from a Geom_Plane.
void OCCTSurfacePlanePln(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

// MARK: - Geom_SphericalSurface Methods (v0.108.0)

/// Get the radius of a Geom_SphericalSurface.
double OCCTSurfaceSphereRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the radius of a Geom_SphericalSurface.
bool OCCTSurfaceSphereSetRadius(OCCTSurfaceRef _Nonnull surface, double radius);

/// Get the area of a Geom_SphericalSurface.
double OCCTSurfaceSphereArea(OCCTSurfaceRef _Nonnull surface);

/// Get the volume of a Geom_SphericalSurface.
double OCCTSurfaceSphereVolume(OCCTSurfaceRef _Nonnull surface);

/// Get the center of a Geom_SphericalSurface.
void OCCTSurfaceSphereCenter(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get a U iso-curve from a Geom_SphericalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSphereUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// Get a V iso-curve from a Geom_SphericalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSphereVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Get the gp_Sphere data (center + radius) from a Geom_SphericalSurface.
void OCCTSurfaceSphereSphere(OCCTSurfaceRef _Nonnull surface, double* _Nonnull cx, double* _Nonnull cy, double* _Nonnull cz, double* _Nonnull radius);

// MARK: - Geom_ToroidalSurface Methods (v0.108.0)

/// Get the major radius of a Geom_ToroidalSurface.
double OCCTSurfaceTorusMajorRadius(OCCTSurfaceRef _Nonnull surface);

/// Get the minor radius of a Geom_ToroidalSurface.
double OCCTSurfaceTorusMinorRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the major radius of a Geom_ToroidalSurface.
bool OCCTSurfaceTorusSetMajorRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Set the minor radius of a Geom_ToroidalSurface.
bool OCCTSurfaceTorusSetMinorRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Get the area of a Geom_ToroidalSurface.
double OCCTSurfaceTorusArea(OCCTSurfaceRef _Nonnull surface);

/// Get the volume of a Geom_ToroidalSurface.
double OCCTSurfaceTorusVolume(OCCTSurfaceRef _Nonnull surface);

/// Get the axis of a Geom_ToroidalSurface (origin + direction of rotation axis). v0.137.
void OCCTSurfaceTorusAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_SurfaceOfRevolution Methods (v0.137)

/// Get the axis of revolution (origin + direction). Valid only when surface type == Revolution.
void OCCTSurfaceRevolutionAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the location (anchor point on the axis) of a Geom_SurfaceOfRevolution.
void OCCTSurfaceRevolutionLocation(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// MARK: - Geom_CylindricalSurface Methods (v0.108.0)

/// Get the radius of a Geom_CylindricalSurface.
double OCCTSurfaceCylinderRadius(OCCTSurfaceRef _Nonnull surface);

/// Set the radius of a Geom_CylindricalSurface.
bool OCCTSurfaceCylinderSetRadius(OCCTSurfaceRef _Nonnull surface, double r);

/// Get the axis of a Geom_CylindricalSurface.
void OCCTSurfaceCylinderAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get a U iso-curve from a Geom_CylindricalSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceCylinderUIso(OCCTSurfaceRef _Nonnull surface, double u);

// MARK: - Geom_ConicalSurface Methods (v0.108.0)

/// Get the semi-angle of a Geom_ConicalSurface.
double OCCTSurfaceConeSemiAngle(OCCTSurfaceRef _Nonnull surface);

/// Get the reference radius of a Geom_ConicalSurface.
double OCCTSurfaceConeRefRadius(OCCTSurfaceRef _Nonnull surface);

/// Get the apex of a Geom_ConicalSurface.
void OCCTSurfaceConeApex(OCCTSurfaceRef _Nonnull surface, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the axis of a Geom_ConicalSurface.
void OCCTSurfaceConeAxis(OCCTSurfaceRef _Nonnull surface, double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

// MARK: - Geom_SweptSurface Methods (v0.108.0)

/// Get the extrusion/revolution direction of a Geom_SweptSurface.
void OCCTSurfaceSweptDirection(OCCTSurfaceRef _Nonnull surface, double* _Nonnull dx, double* _Nonnull dy, double* _Nonnull dz);

/// Get the basis curve of a Geom_SweptSurface.
OCCTCurve3DRef _Nullable OCCTSurfaceSweptBasisCurve(OCCTSurfaceRef _Nonnull surface);

// MARK: - Extrema_ExtElSS: Elementary Surface-Surface Distance (v0.109.0)

/// Distance between two planes (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSPlanePlane(double pl1x, double pl1y, double pl1z, double pn1x, double pn1y, double pn1z,
                                    double pl2x, double pl2y, double pl2z, double pn2x, double pn2y, double pn2z,
                                    bool* _Nonnull outIsParallel,
                                    OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between a plane and sphere (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSPlaneSphere(double plx, double ply, double plz, double pnx, double pny, double pnz,
                                     double cx, double cy, double cz, double radius,
                                     OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Distance between two spheres (Extrema_ExtElSS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElSSSphereSphere(double c1x, double c1y, double c1z, double r1,
                                      double c2x, double c2y, double c2z, double r2,
                                      OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Extrema_ExtPElS: Point to Elementary Surface Distance (v0.109.0)

/// Closest distance from a point to a plane (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSPlane(double px, double py, double pz,
                                  double plx, double ply, double plz, double pnx, double pny, double pnz,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a sphere (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSSphere(double px, double py, double pz,
                                   double cx, double cy, double cz, double radius,
                                   double tolerance,
                                   OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a cylinder (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSCylinder(double px, double py, double pz,
                                     double cx, double cy, double cz, double nx, double ny, double nz, double radius,
                                     double tolerance,
                                     OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a cone (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSCone(double px, double py, double pz,
                                 double cx, double cy, double cz, double nx, double ny, double nz,
                                 double semiAngle, double refRadius,
                                 double tolerance,
                                 OCCTExtremaElResult* _Nonnull out, int32_t max);

/// Closest distance from a point to a torus (Extrema_ExtPElS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElSTorus(double px, double py, double pz,
                                  double cx, double cy, double cz, double nx, double ny, double nz,
                                  double majorRadius, double minorRadius,
                                  double tolerance,
                                  OCCTExtremaElResult* _Nonnull out, int32_t max);

// MARK: - Surface Extras (v0.109.0)

/// Get the parameter bounds of a surface.
void OCCTSurfaceBounds(OCCTSurfaceRef _Nonnull surface,
                        double* _Nonnull uMin, double* _Nonnull uMax,
                        double* _Nonnull vMin, double* _Nonnull vMax);

/// Deprecated alias of OCCTSurfaceGetContinuity, kept for ABI compatibility (#485).
///
/// Prefer OCCTSurfaceGetContinuity. Formerly re-encoded the same GeomAbs_Shape as
/// {C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}; now returns the raw ordinal.
int32_t OCCTSurfaceContinuity(OCCTSurfaceRef _Nonnull surface);

/// Deep copy a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceCopy(OCCTSurfaceRef _Nonnull surface);

// MARK: - Surface Evaluation (v0.110.0)

/// Evaluate surface at (u, v), returning point (x, y, z).
void OCCTSurfaceEvalD0(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Evaluate surface at (u, v), returning point and first partial derivatives D1U, D1V.
void OCCTSurfaceEvalD1(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                         double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz);

/// Evaluate surface at (u, v), returning point, D1U, D1V, D2U, D2V, D2UV.
void OCCTSurfaceEvalD2(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                         double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                         double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                         double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                         double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                         double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz);

/// Create a curve-on-edge adaptor.
OCCTBiTgteCurveOnEdgeRef _Nullable OCCTBiTgteCurveOnEdgeCreate(
    OCCTShapeRef _Nonnull edgeOnFace, OCCTShapeRef _Nonnull edge);

/// Release a curve-on-edge.
void OCCTBiTgteCurveOnEdgeRelease(OCCTBiTgteCurveOnEdgeRef _Nonnull curve);

/// Get the parameter domain.
void OCCTBiTgteCurveOnEdgeDomain(OCCTBiTgteCurveOnEdgeRef _Nonnull curve,
                                 double* _Nonnull first, double* _Nonnull last);

/// Evaluate point at parameter u.
void OCCTBiTgteCurveOnEdgeValue(OCCTBiTgteCurveOnEdgeRef _Nonnull curve, double u,
                                double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

// --- Surface extras ---

/// Get the surface type enum (GeomAbs_SurfaceType: 0=Plane..10=OtherSurface).
int32_t OCCTSurfaceGetType(OCCTSurfaceRef _Nonnull surface);

/// Create a multi-result projection of a point onto a surface.
OCCTProjOnSurfRef _Nullable OCCTProjOnSurfCreate(OCCTSurfaceRef _Nonnull surface,
                                                   double px, double py, double pz);

/// Release a projection on surface object.
void OCCTProjOnSurfRelease(OCCTProjOnSurfRef _Nonnull proj);

/// Number of projection results.
int32_t OCCTProjOnSurfNbPoints(OCCTProjOnSurfRef _Nonnull proj);

/// Get the i-th projection point (1-based index).
void OCCTProjOnSurfPoint(OCCTProjOnSurfRef _Nonnull proj, int32_t index,
                          double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the (u,v) parameters of the i-th projection (1-based).
void OCCTProjOnSurfParameters(OCCTProjOnSurfRef _Nonnull proj, int32_t index,
                               double* _Nonnull u, double* _Nonnull v);

/// Get the distance of the i-th projection (1-based).
double OCCTProjOnSurfDistance(OCCTProjOnSurfRef _Nonnull proj, int32_t index);

/// Get the minimum distance across all projections.
double OCCTProjOnSurfLowerDistance(OCCTProjOnSurfRef _Nonnull proj);

/// Get the (u,v) parameters of the nearest projection.
void OCCTProjOnSurfLowerParams(OCCTProjOnSurfRef _Nonnull proj,
                                double* _Nonnull u, double* _Nonnull v);

/// Create a curve-surface intersection computation.
OCCTIntCSRef _Nullable OCCTIntCSCreate(OCCTCurve3DRef _Nonnull curve,
                                        OCCTSurfaceRef _Nonnull surface);

/// Release an IntCS object.
void OCCTIntCSRelease(OCCTIntCSRef _Nonnull intcs);

/// Number of intersection points.
int32_t OCCTIntCSNbPoints(OCCTIntCSRef _Nonnull intcs);

/// Get the i-th intersection point (1-based) with curve param (w) and surface params (u,v).
void OCCTIntCSPoint(OCCTIntCSRef _Nonnull intcs, int32_t index,
                     double* _Nonnull x, double* _Nonnull y, double* _Nonnull z,
                     double* _Nonnull w, double* _Nonnull u, double* _Nonnull v);

/// Number of intersection segments.
int32_t OCCTIntCSNbSegments(OCCTIntCSRef _Nonnull intcs);

// --- BSplineSurface remaining mutations ---

/// Set U knot at given index (1-based).
bool OCCTSurfaceBSplineSetUKnot(OCCTSurfaceRef _Nonnull surface, int32_t index, double knot);

/// Set V knot at given index (1-based).
bool OCCTSurfaceBSplineSetVKnot(OCCTSurfaceRef _Nonnull surface, int32_t index, double knot);

/// Get all U knots. Caller must pre-allocate array of size NbUKnots.
void OCCTSurfaceBSplineGetUKnots(OCCTSurfaceRef _Nonnull surface, double* _Nonnull knots);

/// Get all V knots. Caller must pre-allocate array of size NbVKnots.
void OCCTSurfaceBSplineGetVKnots(OCCTSurfaceRef _Nonnull surface, double* _Nonnull knots);

/// Get all weights. Caller must pre-allocate array of size NbUPoles * NbVPoles (row-major).
void OCCTSurfaceBSplineGetWeights(OCCTSurfaceRef _Nonnull surface,
                                    double* _Nonnull weights,
                                    int32_t* _Nonnull rows, int32_t* _Nonnull cols);

/// Remove a U knot. Returns true if successful.
bool OCCTSurfaceBSplineRemoveUKnot(OCCTSurfaceRef _Nonnull surface,
                                     int32_t index, int32_t mult, double tol);

/// Evaluate the (Nu, Nv) partial derivative of a surface at (u,v).
void OCCTSurfaceDN(OCCTSurfaceRef _Nonnull surface, double u, double v,
                    int32_t nu, int32_t nv,
                    double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the surface type as a string (Geom_Plane, Geom_SphericalSurface, etc.).
const char* _Nullable OCCTSurfaceTypeName(OCCTSurfaceRef _Nonnull surface);

/// Approximate a BSpline surface through a grid of 3D points.
/// points is row-major (u varies fastest): point[v*uCount+u] = (x,y,z).
OCCTSurfaceRef _Nullable OCCTPointsToSurfaceBSpline(const double* _Nonnull points,
                                                       int32_t uCount, int32_t vCount,
                                                       int32_t degMin, int32_t degMax,
                                                       int32_t continuity, double tol);

/// OCCTCurve2DLength was declared here: a second spelling of OCCTCurve2DGetLengthBetween that
/// measured through a pre-bounded Geom2dAdaptor_Curve, so it extrapolated past a multi-span
/// curve's knots instead of clamping and reported a reversed range as a failure. Removed by
/// #549, matching what #506 did to the 3D spelling.

// --- Surface additional (v0.115.0) ---

/// Compute the surface normal at (u,v).
void OCCTSurfaceNormal(OCCTSurfaceRef _Nonnull surface, double u, double v,
                         double* _Nonnull nx, double* _Nonnull ny, double* _Nonnull nz);

/// Compute Gaussian and mean curvature at (u,v). Returns true if the curvature exists there, on the
/// same terms as OCCTSurfaceGetGaussianCurvature / OCCTSurfaceGetMeanCurvature, which it shares one
/// GeomLProp_SLProps construction with (#595).
bool OCCTSurfaceCurvatures(OCCTSurfaceRef _Nonnull surface, double u, double v,
                             double* _Nonnull gaussian, double* _Nonnull mean);

// MARK: - LProp3d_SLProps (v0.117.0)

/// Get surface curvatures at (u,v).
void OCCTSurfaceLocalCurvatures(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                  double* _Nonnull gaussian, double* _Nonnull mean,
                                  double* _Nonnull maxCurvature, double* _Nonnull minCurvature,
                                  bool* _Nonnull isDefined);

/// Get curvature directions at (u,v).
void OCCTSurfaceLocalCurvatureDirections(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                           double* _Nonnull maxDx, double* _Nonnull maxDy, double* _Nonnull maxDz,
                                           double* _Nonnull minDx, double* _Nonnull minDy, double* _Nonnull minDz,
                                           bool* _Nonnull isDefined);

// --- Geom_BezierSurface queries ---

/// Number of U poles of a Bezier surface.
int32_t OCCTSurfaceBezierNbUPoles(OCCTSurfaceRef _Nonnull surface);

/// Number of V poles of a Bezier surface.
int32_t OCCTSurfaceBezierNbVPoles(OCCTSurfaceRef _Nonnull surface);

/// U degree of a Bezier surface.
int32_t OCCTSurfaceBezierUDegree(OCCTSurfaceRef _Nonnull surface);

/// V degree of a Bezier surface.
int32_t OCCTSurfaceBezierVDegree(OCCTSurfaceRef _Nonnull surface);

/// Get a pole from a Bezier surface (1-based indices).
void OCCTSurfaceBezierGetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                              double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Set a pole on a Bezier surface (1-based indices).
bool OCCTSurfaceBezierSetPole(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                              double x, double y, double z);

/// Set a weight on a Bezier surface (1-based indices).
bool OCCTSurfaceBezierSetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex,
                                double weight);

/// Extract a segment of a Bezier surface.
bool OCCTSurfaceBezierSegment(OCCTSurfaceRef _Nonnull surface,
                              double u1, double u2, double v1, double v2);

/// Check if Bezier surface is rational in U.
bool OCCTSurfaceBezierIsURational(OCCTSurfaceRef _Nonnull surface);

/// Check if Bezier surface is rational in V.
bool OCCTSurfaceBezierIsVRational(OCCTSurfaceRef _Nonnull surface);

/// Exchange U and V parametric directions of a Bezier surface.
bool OCCTSurfaceBezierExchangeUV(OCCTSurfaceRef _Nonnull surface);

// --- BSplineSurface extras ---

/// Compute U and V parameter resolution for a given 3D tolerance.
void OCCTSurfaceBSplineResolution(OCCTSurfaceRef _Nonnull surface, double tolerance3d,
                                  double* _Nonnull uResolution, double* _Nonnull vResolution);

/// Set U periodic on a BSpline surface.
bool OCCTSurfaceBSplineSetUPeriodic(OCCTSurfaceRef _Nonnull surface, bool periodic);

/// Set V periodic on a BSpline surface.
bool OCCTSurfaceBSplineSetVPeriodic(OCCTSurfaceRef _Nonnull surface, bool periodic);

/// Get a weight from a BSpline surface (1-based indices).
double OCCTSurfaceBSplineGetWeight(OCCTSurfaceRef _Nonnull surface, int32_t uIndex, int32_t vIndex);

// --- Surface continuity queries ---

/// Check if a surface has Cn continuity in U direction.
bool OCCTSurfaceIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Check if a surface has Cn continuity in V direction.
bool OCCTSurfaceIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Create a U-reversed copy of a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceUReversed(OCCTSurfaceRef _Nonnull surface);

/// Create a V-reversed copy of a surface.
OCCTSurfaceRef _Nullable OCCTSurfaceVReversed(OCCTSurfaceRef _Nonnull surface);

/// Get the reversed U parameter value.
double OCCTSurfaceUReversedParameter(OCCTSurfaceRef _Nonnull surface, double u);

/// Get the reversed V parameter value.
double OCCTSurfaceVReversedParameter(OCCTSurfaceRef _Nonnull surface, double v);

// --- BSpline surface RemoveVKnot ---

/// Remove a V knot from a BSpline surface. Returns true if successful.
bool OCCTSurfaceBSplineRemoveVKnot(OCCTSurfaceRef _Nonnull surface,
                                     int32_t index, int32_t mult, double tol);

/// Compute U and V parameter resolution for a Bezier surface from a 3D tolerance.
void OCCTSurfaceBezierResolution(OCCTSurfaceRef _Nonnull surface, double tolerance3d,
                                  double* _Nonnull uResolution, double* _Nonnull vResolution);

/// Get the maximum degree for Bezier surfaces.
int32_t OCCTSurfaceBezierMaxDegree(void);

// --- BSpline MaxDegree (surface + 2D curve) ---

/// Get the maximum degree for BSpline surfaces (static).
int32_t OCCTSurfaceBSplineMaxDegree(void);

// =============================================================================
// MARK: - v0.121.0: BSpline completions, FilletBuilder, ChamferBuilder
// =============================================================================

// --- BSplineSurface completions ---

/// Remove U periodicity from BSpline surface.
bool OCCTSurfaceBSplineSetUNotPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Remove V periodicity from BSpline surface.
bool OCCTSurfaceBSplineSetVNotPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Set origin knot index in U direction (1-based).
bool OCCTSurfaceBSplineSetUOrigin(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Set origin knot index in V direction (1-based).
bool OCCTSurfaceBSplineSetVOrigin(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Increase U multiplicity at knot index to at least mult (1-based).
bool OCCTSurfaceBSplineIncreaseUMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index, int32_t mult);

/// Increase V multiplicity at knot index to at least mult (1-based).
bool OCCTSurfaceBSplineIncreaseVMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index, int32_t mult);

/// Batch insert U knots with multiplicities.
bool OCCTSurfaceBSplineInsertUKnots(OCCTSurfaceRef _Nonnull surface,
                                     const double* _Nonnull knots,
                                     const int32_t* _Nonnull mults,
                                     int32_t count, double tol);

/// Batch insert V knots with multiplicities.
bool OCCTSurfaceBSplineInsertVKnots(OCCTSurfaceRef _Nonnull surface,
                                     const double* _Nonnull knots,
                                     const int32_t* _Nonnull mults,
                                     int32_t count, double tol);

/// Move point on BSpline surface to pass through (px,py,pz) at (u,v), adjusting poles in range.
bool OCCTSurfaceBSplineMovePoint(OCCTSurfaceRef _Nonnull surface,
                                  double u, double v,
                                  double px, double py, double pz,
                                  int32_t uIndex1, int32_t uIndex2,
                                  int32_t vIndex1, int32_t vIndex2);

/// Set an entire column of poles (all U poles at vIndex, 1-based).
bool OCCTSurfaceBSplineSetPoleCol(OCCTSurfaceRef _Nonnull surface,
                                   int32_t vIndex,
                                   const double* _Nonnull coords, int32_t count);

/// Set an entire row of poles (all V poles at uIndex, 1-based).
bool OCCTSurfaceBSplineSetPoleRow(OCCTSurfaceRef _Nonnull surface,
                                   int32_t uIndex,
                                   const double* _Nonnull coords, int32_t count);

// --- Surface queries ---

/// Get the U period of a periodic surface (0.0 if not periodic in U).
double OCCTSurfaceUPeriod(OCCTSurfaceRef _Nonnull surface);

/// Get the V period of a periodic surface (0.0 if not periodic in V).
double OCCTSurfaceVPeriod(OCCTSurfaceRef _Nonnull surface);

// MARK: - v0.125.0: BSpline/Bezier deep method completion

// --- Geom_BSplineSurface completions ---

/// Local evaluation D0 within knot span.
void OCCTSurfaceBSplineLocalD0(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Local evaluation D1 within knot span.
void OCCTSurfaceBSplineLocalD1(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz);

/// Local evaluation D2 within knot span.
void OCCTSurfaceBSplineLocalD2(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                                double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                                double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                                double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz);

/// Local evaluation D3 within knot span.
void OCCTSurfaceBSplineLocalD3(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz,
                                double* _Nonnull d1ux, double* _Nonnull d1uy, double* _Nonnull d1uz,
                                double* _Nonnull d1vx, double* _Nonnull d1vy, double* _Nonnull d1vz,
                                double* _Nonnull d2ux, double* _Nonnull d2uy, double* _Nonnull d2uz,
                                double* _Nonnull d2vx, double* _Nonnull d2vy, double* _Nonnull d2vz,
                                double* _Nonnull d2uvx, double* _Nonnull d2uvy, double* _Nonnull d2uvz,
                                double* _Nonnull d3ux, double* _Nonnull d3uy, double* _Nonnull d3uz,
                                double* _Nonnull d3vx, double* _Nonnull d3vy, double* _Nonnull d3vz,
                                double* _Nonnull d3uuvx, double* _Nonnull d3uuvy, double* _Nonnull d3uuvz,
                                double* _Nonnull d3uvvx, double* _Nonnull d3uvvy, double* _Nonnull d3uvvz);

/// Local derivative DN within knot span.
void OCCTSurfaceBSplineLocalDN(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                int32_t nu, int32_t nv,
                                double* _Nonnull vx, double* _Nonnull vy, double* _Nonnull vz);

/// Local value within knot span.
void OCCTSurfaceBSplineLocalValue(OCCTSurfaceRef _Nonnull surface, double u, double v,
                                   int32_t fromUK1, int32_t toUK2, int32_t fromVK1, int32_t toVK2,
                                   double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// UIso: extract isoparametric curve at U.
OCCTCurve3DRef _Nullable OCCTSurfaceBSplineUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// VIso: extract isoparametric curve at V.
OCCTCurve3DRef _Nullable OCCTSurfaceBSplineVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Locate U knot span. Returns I1 and I2 via out params.
void OCCTSurfaceBSplineLocateU(OCCTSurfaceRef _Nonnull surface, double u, double paramTol,
                                int32_t* _Nonnull i1, int32_t* _Nonnull i2);

/// Locate V knot span. Returns I1 and I2 via out params.
void OCCTSurfaceBSplineLocateV(OCCTSurfaceRef _Nonnull surface, double v, double paramTol,
                                int32_t* _Nonnull i1, int32_t* _Nonnull i2);

/// Get a single U knot value by index (1-based).
double OCCTSurfaceBSplineUKnot(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get a single V knot value by index (1-based).
double OCCTSurfaceBSplineVKnot(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get U multiplicity by index (1-based).
int32_t OCCTSurfaceBSplineUMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// Get V multiplicity by index (1-based).
int32_t OCCTSurfaceBSplineVMultiplicity(OCCTSurfaceRef _Nonnull surface, int32_t index);

/// U knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTSurfaceBSplineUKnotDistribution(OCCTSurfaceRef _Nonnull surface);

/// V knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTSurfaceBSplineVKnotDistribution(OCCTSurfaceRef _Nonnull surface);

/// Get all poles as flat array (x1,y1,z1,x2,...). Array must be pre-allocated to NbUPoles*NbVPoles*3.
void OCCTSurfaceBSplineGetPoles(OCCTSurfaceRef _Nonnull surface, double* _Nonnull poles);

/// Get parameter bounds (u1, u2, v1, v2).
void OCCTSurfaceBSplineBounds(OCCTSurfaceRef _Nonnull surface,
                               double* _Nonnull u1, double* _Nonnull u2,
                               double* _Nonnull v1, double* _Nonnull v2);

/// Is the surface closed in U?
bool OCCTSurfaceBSplineIsUClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface closed in V?
bool OCCTSurfaceBSplineIsVClosed(OCCTSurfaceRef _Nonnull surface);

// --- Geom_BezierSurface completions ---

/// UIso: extract isoparametric curve at U.
OCCTCurve3DRef _Nullable OCCTSurfaceBezierUIso(OCCTSurfaceRef _Nonnull surface, double u);

/// VIso: extract isoparametric curve at V.
OCCTCurve3DRef _Nullable OCCTSurfaceBezierVIso(OCCTSurfaceRef _Nonnull surface, double v);

/// Is the surface closed in U?
bool OCCTSurfaceBezierIsUClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface closed in V?
bool OCCTSurfaceBezierIsVClosed(OCCTSurfaceRef _Nonnull surface);

/// Is the surface periodic in U?
bool OCCTSurfaceBezierIsUPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Is the surface periodic in V?
bool OCCTSurfaceBezierIsVPeriodic(OCCTSurfaceRef _Nonnull surface);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTSurfaceBezierContinuity(OCCTSurfaceRef _Nonnull surface);

/// IsCNu: is the surface at least CN continuous in U?
bool OCCTSurfaceBezierIsCNu(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// IsCNv: is the surface at least CN continuous in V?
bool OCCTSurfaceBezierIsCNv(OCCTSurfaceRef _Nonnull surface, int32_t n);

/// Get all poles as flat array (x1,y1,z1,...). Array must be pre-allocated to NbUPoles*NbVPoles*3.
void OCCTSurfaceBezierGetPoles(OCCTSurfaceRef _Nonnull surface, double* _Nonnull poles);

/// Get all weights as flat array. Array must be pre-allocated to NbUPoles*NbVPoles. Returns false if non-rational.
bool OCCTSurfaceBezierGetWeights(OCCTSurfaceRef _Nonnull surface, double* _Nonnull weights);

/// Get parameter bounds (u1, u2, v1, v2).
void OCCTSurfaceBezierBounds(OCCTSurfaceRef _Nonnull surface,
                              double* _Nonnull u1, double* _Nonnull u2,
                              double* _Nonnull v1, double* _Nonnull v2);

// --- BSpline Surface bulk multiplicities and reverse ---

/// Get all U multiplicities. Array must be pre-allocated to NbUKnots.
void OCCTSurfaceBSplineGetUMultiplicities(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull mults);

/// Get all V multiplicities. Array must be pre-allocated to NbVKnots.
void OCCTSurfaceBSplineGetVMultiplicities(OCCTSurfaceRef _Nonnull surface, int32_t* _Nonnull mults);

/// Reverse the U parameter direction of a BSpline surface (in-place).
bool OCCTSurfaceBSplineUReverse(OCCTSurfaceRef _Nonnull surface);

/// Reverse the V parameter direction of a BSpline surface (in-place).
bool OCCTSurfaceBSplineVReverse(OCCTSurfaceRef _Nonnull surface);

/// Normalize U,V parameters for a periodic BSpline surface.
bool OCCTSurfaceBSplinePeriodicNormalization(OCCTSurfaceRef _Nonnull surface,
                                              double* _Nonnull u, double* _Nonnull v);

// --- Bezier Surface insert/remove poles ---

/// Insert a pole column after index in a Bezier surface.
bool OCCTSurfaceBezierInsertPoleColAfter(OCCTSurfaceRef _Nonnull surface, int32_t colIndex,
                                          const double* _Nonnull poles, int32_t poleCount);

/// Insert a pole row after index in a Bezier surface.
bool OCCTSurfaceBezierInsertPoleRowAfter(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex,
                                          const double* _Nonnull poles, int32_t poleCount);

/// Remove a pole column from a Bezier surface.
bool OCCTSurfaceBezierRemovePoleCol(OCCTSurfaceRef _Nonnull surface, int32_t colIndex);

/// Remove a pole row from a Bezier surface.
bool OCCTSurfaceBezierRemovePoleRow(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex);

/// Increase the degree of a Bezier surface.
bool OCCTSurfaceBezierIncreaseDegree(OCCTSurfaceRef _Nonnull surface, int32_t uDeg, int32_t vDeg);

/// Reverse U parameter direction of a Bezier surface (in-place).
bool OCCTSurfaceBezierUReverse(OCCTSurfaceRef _Nonnull surface);

/// Reverse V parameter direction of a Bezier surface (in-place).
bool OCCTSurfaceBezierVReverse(OCCTSurfaceRef _Nonnull surface);

// --- Geom_BezierSurface completions ---

/// Set a pole column with weights on a Bezier surface. vIndex is 1-based.
/// poles: flat array [x1,y1,z1,...] of NbUPoles points. weights: array of NbUPoles values.
bool OCCTSurfaceBezierSetPoleColWeights(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                         const double* _Nonnull poles, const double* _Nonnull weights,
                                         int32_t count);

/// Set a pole row with weights on a Bezier surface. uIndex is 1-based.
/// poles: flat array [x1,y1,z1,...] of NbVPoles points. weights: array of NbVPoles values.
bool OCCTSurfaceBezierSetPoleRowWeights(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                         const double* _Nonnull poles, const double* _Nonnull weights,
                                         int32_t count);

/// Transform a surface in place using a gp_Trsf.
/// Same transformType as OCCTCurve3DTransform.
bool OCCTSurfaceTransform(OCCTSurfaceRef _Nonnull surface, int32_t transformType,
                           double p1, double p2, double p3,
                           double p4, double p5, double p6,
                           double p7);

// BSplineSurface completions

/// Set a column of weights on a BSpline surface. vIndex is 1-based. count = NbUPoles.
bool OCCTSurfaceBSplineSetWeightCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                     const double* _Nonnull weights, int32_t count);

/// Set a row of weights on a BSpline surface. uIndex is 1-based. count = NbVPoles.
bool OCCTSurfaceBSplineSetWeightRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                     const double* _Nonnull weights, int32_t count);

/// Increment U knot multiplicities in range [fromIndex, toIndex] by step.
bool OCCTSurfaceBSplineIncrementUMultiplicity(OCCTSurfaceRef _Nonnull surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step);

/// Increment V knot multiplicities in range [fromIndex, toIndex] by step.
bool OCCTSurfaceBSplineIncrementVMultiplicity(OCCTSurfaceRef _Nonnull surface,
                                               int32_t fromIndex, int32_t toIndex, int32_t step);

/// First U knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineFirstUKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Last U knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineLastUKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// First V knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineFirstVKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Last V knot index of a BSpline surface.
int32_t OCCTSurfaceBSplineLastVKnotIndex(OCCTSurfaceRef _Nonnull surface);

/// Validate parameter ranges and segment the BSpline surface.
bool OCCTSurfaceBSplineCheckAndSegment(OCCTSurfaceRef _Nonnull surface,
                                        double u1, double u2, double v1, double v2,
                                        double uTol, double vTol);

// BezierSurface completions

/// Insert a pole column before index in a Bezier surface. poles: flat [x,y,z,...], count = NbUPoles.
bool OCCTSurfaceBezierInsertPoleColBefore(OCCTSurfaceRef _Nonnull surface, int32_t colIndex,
                                           const double* _Nonnull poles, int32_t poleCount);

/// Insert a pole row before index in a Bezier surface. poles: flat [x,y,z,...], count = NbVPoles.
bool OCCTSurfaceBezierInsertPoleRowBefore(OCCTSurfaceRef _Nonnull surface, int32_t rowIndex,
                                           const double* _Nonnull poles, int32_t poleCount);

/// Set a pole column (without weights) on a Bezier surface. vIndex is 1-based.
bool OCCTSurfaceBezierSetPoleCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                  const double* _Nonnull poles, int32_t count);

/// Set a pole row (without weights) on a Bezier surface. uIndex is 1-based.
bool OCCTSurfaceBezierSetPoleRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                  const double* _Nonnull poles, int32_t count);

/// Set a column of weights on a Bezier surface. vIndex is 1-based. count = NbUPoles.
bool OCCTSurfaceBezierSetWeightCol(OCCTSurfaceRef _Nonnull surface, int32_t vIndex,
                                    const double* _Nonnull weights, int32_t count);

/// Set a row of weights on a Bezier surface. uIndex is 1-based. count = NbVPoles.
bool OCCTSurfaceBezierSetWeightRow(OCCTSurfaceRef _Nonnull surface, int32_t uIndex,
                                    const double* _Nonnull weights, int32_t count);

// --- GeomEval Surfaces ---

/// Evaluate ellipsoid surface D0 at (u,v). Returns point.
void OCCTGeomEvalEllipsoidD0(double a, double b, double c, double u, double v,
                              double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create ellipsoid as OCCTSurfaceRef. Returns NULL on error.
OCCTSurfaceRef _Nullable OCCTGeomEvalEllipsoidCreate(double a, double b, double c);

/// Evaluate hyperboloid D0 at (u,v). mode: 0=one-sheet, 1=two-sheets.
void OCCTGeomEvalHyperboloidD0(double r1, double r2, int32_t mode, double u, double v,
                                double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create hyperboloid as OCCTSurfaceRef. mode: 0=one-sheet, 1=two-sheets.
OCCTSurfaceRef _Nullable OCCTGeomEvalHyperboloidCreate(double r1, double r2, int32_t mode);

/// Evaluate paraboloid D0 at (u,v).
void OCCTGeomEvalParaboloidD0(double focal, double u, double v,
                               double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create paraboloid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalParaboloidCreate(double focal);

/// Evaluate circular helicoid D0 at (u,v).
void OCCTGeomEvalCircularHelicoidD0(double pitch, double u, double v,
                                     double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create circular helicoid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalCircularHelicoidCreate(double pitch);

/// Evaluate hyperbolic paraboloid D0 at (u,v).
void OCCTGeomEvalHypParaboloidD0(double a, double b, double u, double v,
                                  double* _Nonnull px, double* _Nonnull py, double* _Nonnull pz);

/// Create hyperbolic paraboloid as OCCTSurfaceRef.
OCCTSurfaceRef _Nullable OCCTGeomEvalHypParaboloidCreate(double a, double b);

// --- GeomFill_Gordon ---

/// Build a Gordon surface from a network of profile and guide curves.
/// profiles and guides are arrays of OCCTCurve3DRef. Returns surface or NULL.
OCCTSurfaceRef _Nullable OCCTGeomFillGordon(const OCCTCurve3DRef _Nonnull * _Nonnull profiles,
                                             int32_t profileCount,
                                             const OCCTCurve3DRef _Nonnull * _Nonnull guides,
                                             int32_t guideCount,
                                             double tolerance);

// --- GeomEval TBezier / AHTBezier Surfaces ---

/// Create a Trigonometric Bezier surface. poles: flat row-major [x,y,z,...], uCount*vCount poles.
OCCTSurfaceRef _Nullable OCCTGeomEvalTBezierSurfaceCreate(
    const double* _Nonnull poles, int32_t uCount, int32_t vCount,
    double alphaU, double alphaV);

/// Create an AHT Bezier surface. poles: flat row-major, uCount*vCount poles.
OCCTSurfaceRef _Nullable OCCTGeomEvalAHTBezierSurfaceCreate(
    const double* _Nonnull poles, int32_t uCount, int32_t vCount,
    int32_t algDegreeU, int32_t algDegreeV,
    double alphaU, double alphaV, double betaU, double betaV);

// MARK: - GeomFill_NetworkSurface / GeomFill_Gordon report — OCCT 8.0.0p1

/// Build a Gordon surface (GeomFill_Gordon) reporting status and approximate flag.
/// approximationMode: 0 = ExactOnly (default), 1 = AllowApproximateFallback.
/// Writes the GeomFill_Gordon::ResultStatus ordinal to *outStatus and the
/// IsApproximate flag to *outIsApproximate. Returns the surface or NULL.
OCCTSurfaceRef _Nullable OCCTGeomFillGordonReport(
    const OCCTCurve3DRef _Nonnull * _Nonnull profiles, int32_t profileCount,
    const OCCTCurve3DRef _Nonnull * _Nonnull guides, int32_t guideCount,
    double tolerance, int32_t approximationMode,
    int32_t* _Nonnull outStatus, bool* _Nonnull outIsApproximate);

/// Build a surface with the low-level GeomFill_NetworkSurface builder from a
/// profile/guide curve network. Writes the GeomFill_NetworkSurface::ResultStatus
/// ordinal to *outStatus. Returns the surface or NULL.
OCCTSurfaceRef _Nullable OCCTGeomFillNetworkSurface(
    const OCCTCurve3DRef _Nonnull * _Nonnull profiles, int32_t profileCount,
    const OCCTCurve3DRef _Nonnull * _Nonnull guides, int32_t guideCount,
    double tolerance, int32_t* _Nonnull outStatus);

#endif /* OCCTBridge_Surface_h */
