//
//  OCCTBridge_Spatial.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Spatial domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Spatial_h
#define OCCTBridge_Spatial_h

/// OCCTShapeGetHorizontalFaces and OCCTShapeGetUpwardFaces were declared here: second copies of
/// the Face.isHorizontal / Face.isUpwardFacing predicates over the same midpoint normal
/// OCCTFaceGetNormal returns, which Shape.horizontalFaces / Shape.upwardFaces use instead. Neither
/// was called from anywhere. Removed by #529.

// MARK: - Ray Casting & Selection (Issues #12, #13, #14)

/// Ray hit result structure
typedef struct
{
  double  point[3];      // 3D intersection point
  double  normal[3];     // Surface normal at hit, (0,0,1) when normalDefined is false
  int32_t faceIndex;     // Index of hit face
  double  distance;      // Distance from ray origin
  double  uv[2];         // UV parameters on surface
  bool    normalDefined; // False at a singular point, where `normal` is the (0,0,1) fallback
} OCCTRayHit;

/// Cast ray against shape and return all intersections
/// @param shape The shape to test against
/// @param originX, originY, originZ Ray origin
/// @param dirX, dirY, dirZ Ray direction (will be normalized)
/// @param tolerance Intersection tolerance
/// @param outHits Output array for hits (caller allocates)
/// @param maxHits Maximum number of hits to return
/// @return Number of hits found, or -1 on error
int32_t OCCTShapeRaycast(OCCTShapeRef shape,
                         double       originX,
                         double       originY,
                         double       originZ,
                         double       dirX,
                         double       dirY,
                         double       dirZ,
                         double       tolerance,
                         OCCTRayHit*  outHits,
                         int32_t      maxHits);

/// Build a KD-tree from 3D points.
/// @param coords Flat array of xyz coordinates (3 * count doubles)
/// @param count Number of points
OCCTKDTreeRef OCCTKDTreeBuild(const double* coords, int32_t count);

/// Release a KD-tree.
void OCCTKDTreeRelease(OCCTKDTreeRef tree);

/// Find the nearest point in the tree to a query point.
/// @param outDistance If non-null, receives the distance (not squared)
/// @return 0-based index of the nearest point, or -1 on error
int32_t OCCTKDTreeNearestPoint(OCCTKDTreeRef tree,
                               double        qx,
                               double        qy,
                               double        qz,
                               double*       outDistance);

/// Find the K nearest points.
/// @param outIndices Buffer for 0-based indices (must hold at least k entries)
/// @param outSqDistances Buffer for squared distances (may be null)
/// @param k Number of neighbors to find
/// @return Number of points found
int32_t OCCTKDTreeKNearest(OCCTKDTreeRef tree,
                           double        qx,
                           double        qy,
                           double        qz,
                           int32_t       k,
                           int32_t*      outIndices,
                           double*       outSqDistances);

/// Find all points within a sphere of given radius.
/// @param outIndices Buffer for 0-based indices
/// @param maxResults Maximum number of results
/// @return Number of points found
int32_t OCCTKDTreeRangeSearch(OCCTKDTreeRef tree,
                              double        qx,
                              double        qy,
                              double        qz,
                              double        radius,
                              int32_t*      outIndices,
                              int32_t       maxResults);

/// Find all points within an axis-aligned bounding box.
int32_t OCCTKDTreeBoxSearch(OCCTKDTreeRef tree,
                            double        minX,
                            double        minY,
                            double        minZ,
                            double        maxX,
                            double        maxY,
                            double        maxZ,
                            int32_t*      outIndices,
                            int32_t       maxResults);

// MARK: - Polynomial Solvers (v0.29.0)

/// Result of a polynomial root finding operation.
typedef struct
{
  int32_t count;
  double  roots[4];
} OCCTPolynomialRoots;

/// Solve a quadratic equation: a*x^2 + b*x + c = 0
OCCTPolynomialRoots OCCTSolveQuadratic(double a, double b, double c);

/// Solve a cubic equation: a*x^3 + b*x^2 + c*x + d = 0
OCCTPolynomialRoots OCCTSolveCubic(double a, double b, double c, double d);

/// Solve a quartic equation: a*x^4 + b*x^3 + c*x^2 + d*x + e = 0
OCCTPolynomialRoots OCCTSolveQuartic(double a, double b, double c, double d, double e);

/// Point cloud geometry analysis result
typedef struct
{
  int32_t type;                      // 0=point, 1=linear, 2=planar, 3=space
  double  pointX, pointY, pointZ;    // Mean/centroid point
  double  dirX, dirY, dirZ;          // Line direction (if linear)
  double  normalX, normalY, normalZ; // Plane normal (if planar)
} OCCTPointCloudGeometry;

/// Analyze a point cloud to determine if points are coincident, collinear, coplanar, or 3D
/// @param coords Flat array of x,y,z coordinates
/// @param pointCount Number of points
/// @param tolerance Tolerance for degeneracy detection
/// @param outResult Result structure
/// @return true on success
bool OCCTAnalyzePointCloud(const double*           coords,
                           int32_t                 pointCount,
                           double                  tolerance,
                           OCCTPointCloudGeometry* outResult);

/// Create an interval [start, end] with optional tolerances.
OCCTIntrvIntervalRef _Nonnull OCCTIntrvIntervalCreate(double start,
                                                      double end,
                                                      float  tolStart,
                                                      float  tolEnd);

/// Release an interval.
void OCCTIntrvIntervalRelease(OCCTIntrvIntervalRef _Nonnull interval);

/// Get interval bounds.
typedef struct
{
  double start;
  double end;
  float  tolStart;
  float  tolEnd;
} OCCTIntrvBounds;

OCCTIntrvBounds OCCTIntrvIntervalBounds(OCCTIntrvIntervalRef _Nonnull interval);

/// Check if interval is probably empty.
bool OCCTIntrvIntervalIsProbablyEmpty(OCCTIntrvIntervalRef _Nonnull interval);

/// Get position of interval relative to another.
/// Returns Intrv_Position enum: 0=Before, 1=JustBefore, 2=OverlappingAtStart, ...12=After
int32_t OCCTIntrvIntervalPosition(OCCTIntrvIntervalRef _Nonnull interval,
                                  OCCTIntrvIntervalRef _Nonnull other);

/// Check spatial relationships between intervals.
bool OCCTIntrvIntervalIsBefore(OCCTIntrvIntervalRef _Nonnull interval,
                               OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsAfter(OCCTIntrvIntervalRef _Nonnull interval,
                              OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsInside(OCCTIntrvIntervalRef _Nonnull interval,
                               OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsEnclosing(OCCTIntrvIntervalRef _Nonnull interval,
                                  OCCTIntrvIntervalRef _Nonnull other);
bool OCCTIntrvIntervalIsSimilar(OCCTIntrvIntervalRef _Nonnull interval,
                                OCCTIntrvIntervalRef _Nonnull other);

/// Modify interval bounds.
void OCCTIntrvIntervalSetStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalSetEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);
void OCCTIntrvIntervalFuseAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalFuseAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);
void OCCTIntrvIntervalCutAtStart(OCCTIntrvIntervalRef _Nonnull interval, double start, float tol);
void OCCTIntrvIntervalCutAtEnd(OCCTIntrvIntervalRef _Nonnull interval, double end, float tol);

/// Create an interval sequence from a single interval.
OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreate(double start, double end);

/// Create an empty interval sequence.
OCCTIntrvIntervalsRef _Nonnull OCCTIntrvIntervalsCreateEmpty(void);

/// Release an interval sequence.
void OCCTIntrvIntervalsRelease(OCCTIntrvIntervalsRef _Nonnull intervals);

/// Get number of intervals in the sequence.
int32_t OCCTIntrvIntervalsCount(OCCTIntrvIntervalsRef _Nonnull intervals);

/// Get bounds of interval at index (1-based).
OCCTIntrvBounds OCCTIntrvIntervalsValue(OCCTIntrvIntervalsRef _Nonnull intervals, int32_t index);

/// Set operations on interval sequences (mutate in place).
void OCCTIntrvIntervalsUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);
void OCCTIntrvIntervalsSubtract(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);
void OCCTIntrvIntervalsIntersect(OCCTIntrvIntervalsRef _Nonnull intervals,
                                 double start,
                                 double end);
void OCCTIntrvIntervalsXUnite(OCCTIntrvIntervalsRef _Nonnull intervals, double start, double end);

/// Create a range [min, max].
OCCTRangeRef _Nonnull OCCTRangeCreate(double min, double max);

/// Create a void range.
OCCTRangeRef _Nonnull OCCTRangeCreateVoid(void);

/// Release a range.
void OCCTRangeRelease(OCCTRangeRef _Nonnull range);

/// Check if range is void.
bool OCCTRangeIsVoid(OCCTRangeRef _Nonnull range);

/// Get bounds. Returns false if void.
bool OCCTRangeGetBounds(OCCTRangeRef _Nonnull range, double* _Nonnull first, double* _Nonnull last);

/// Get delta (max - min).
double OCCTRangeDelta(OCCTRangeRef _Nonnull range);

/// Check if value is in range.
bool OCCTRangeContains(OCCTRangeRef _Nonnull range, double value);

/// Extend range to include a value.
void OCCTRangeAddValue(OCCTRangeRef _Nonnull range, double value);

/// Extend range to include another range.
void OCCTRangeAddRange(OCCTRangeRef _Nonnull range, OCCTRangeRef _Nonnull other);

/// Intersect with another range (modifies this range).
void OCCTRangeCommon(OCCTRangeRef _Nonnull range, OCCTRangeRef _Nonnull other);

/// Enlarge both boundaries by delta.
void OCCTRangeEnlarge(OCCTRangeRef _Nonnull range, double delta);

/// Trim lower boundary.
void OCCTRangeTrimFrom(OCCTRangeRef _Nonnull range, double lower);

/// Trim upper boundary.
void OCCTRangeTrimTo(OCCTRangeRef _Nonnull range, double upper);

/// Create an NxN matrix initialized to a value.
OCCTMathMatrixRef _Nonnull OCCTMathMatrixCreate(int32_t rows, int32_t cols, double initValue);

/// Release a matrix.
void OCCTMathMatrixRelease(OCCTMathMatrixRef _Nonnull m);

/// Get matrix dimensions.
int32_t OCCTMathMatrixRows(OCCTMathMatrixRef _Nonnull m);
int32_t OCCTMathMatrixCols(OCCTMathMatrixRef _Nonnull m);

/// Get/set matrix value (1-based indices).
double OCCTMathMatrixGetValue(OCCTMathMatrixRef _Nonnull m, int32_t row, int32_t col);
void   OCCTMathMatrixSetValue(OCCTMathMatrixRef _Nonnull m, int32_t row, int32_t col, double value);

/// Get matrix determinant.
double OCCTMathMatrixDeterminant(OCCTMathMatrixRef _Nonnull m);

/// Invert the matrix in-place.
bool OCCTMathMatrixInvert(OCCTMathMatrixRef _Nonnull m);

/// Multiply all elements by a scalar.
void OCCTMathMatrixMultiplyScalar(OCCTMathMatrixRef _Nonnull m, double scalar);

/// Transpose the matrix in-place.
void OCCTMathMatrixTranspose(OCCTMathMatrixRef _Nonnull m);

// MARK: - math_Gauss (v0.94.0)

/// Solve linear system Ax=b using Gaussian elimination.
/// @param matrixData Row-major NxN matrix
/// @param n Matrix dimension
/// @param rhs Right-hand side vector (length n)
/// @param outSolution Output solution vector (length n)
/// @return true on success
bool OCCTMathGaussSolve(const double* _Nonnull matrixData,
                        int32_t n,
                        const double* _Nonnull rhs,
                        double* _Nonnull outSolution);

/// Compute determinant using Gauss elimination.
double OCCTMathGaussDeterminant(const double* _Nonnull matrixData, int32_t n);

// MARK: - math_SVD (v0.94.0)

/// Solve least-squares system using SVD.
/// @param matrixData Row-major MxN matrix
/// @param rows Number of rows (M)
/// @param cols Number of cols (N)
/// @param rhs Right-hand side vector (length M)
/// @param outSolution Output solution vector (length N)
/// @return true on success
bool OCCTMathSVDSolve(const double* _Nonnull matrixData,
                      int32_t rows,
                      int32_t cols,
                      const double* _Nonnull rhs,
                      double* _Nonnull outSolution);

// MARK: - math_DirectPolynomialRoots (v0.94.0)

/// Find real roots of polynomial up to degree 4.
/// Coefficients: a*x^n + b*x^(n-1) + ... + constant
/// @param coeffs Array of coefficients [a, b, c, ...] (2-5 elements)
/// @param nCoeffs Number of coefficients (2=linear, 3=quadratic, 4=cubic, 5=quartic)
/// @param outRoots Output buffer for roots (max 4)
/// @return Number of real roots found, or -1 on error
int32_t OCCTMathPolynomialRoots(const double* _Nonnull coeffs,
                                int32_t nCoeffs,
                                double* _Nonnull outRoots);

// MARK: - math_Jacobi (v0.94.0)

/// Compute eigenvalues of a symmetric NxN matrix using Jacobi method.
/// @param matrixData Row-major NxN symmetric matrix
/// @param n Matrix dimension
/// @param outEigenvalues Output eigenvalues (length n)
/// @return true on success
bool OCCTMathJacobiEigenvalues(const double* _Nonnull matrixData,
                               int32_t n,
                               double* _Nonnull outEigenvalues);

// MARK: - math_Householder (v0.95.0)

/// Solve overdetermined system using Householder QR.
/// @param matrixData Row-major MxN matrix (M >= N)
/// @param rows M, cols N
/// @param rhs Right-hand side (length M)
/// @param outSolution Output (length N)
/// @return true on success
bool OCCTMathHouseholderSolve(const double* _Nonnull matrixData,
                              int32_t rows,
                              int32_t cols,
                              const double* _Nonnull rhs,
                              double* _Nonnull outSolution);

// MARK: - math_Crout (v0.95.0)

/// Solve symmetric system using Crout LDL^T decomposition.
/// @param matrixData Row-major NxN symmetric matrix
/// @param n Matrix dimension
/// @param rhs Right-hand side (length N)
/// @param outSolution Output (length N)
/// @return true on success
bool OCCTMathCroutSolve(const double* _Nonnull matrixData,
                        int32_t n,
                        const double* _Nonnull rhs,
                        double* _Nonnull outSolution);

/// Determinant of symmetric matrix via Crout decomposition.
double OCCTMathCroutDeterminant(const double* _Nonnull matrixData, int32_t n);

// MARK: - Precision (v0.97.0)

/// Get OCCT confusion tolerance (1e-7).
double OCCTPrecisionConfusion(void);

/// Get OCCT angular tolerance (1e-12).
double OCCTPrecisionAngular(void);

/// Get OCCT intersection tolerance.
double OCCTPrecisionIntersection(void);

/// Get OCCT approximation tolerance.
double OCCTPrecisionApproximation(void);

/// Get OCCT infinite value (2e100).
double OCCTPrecisionInfinite(void);

/// Get OCCT parametric confusion tolerance.
double OCCTPrecisionPConfusion(void);

/// Check if a value is considered infinite.
bool OCCTPrecisionIsInfinite(double value);

// MARK: - IntAna_IntConicQuad (v0.98.0)

/// Result of a conic-quadric intersection.
typedef struct
{
  double  points[12]; // up to 4 points (x,y,z each)
  double  params[4];  // parameter on conic for each point
  int32_t count;      // number of intersection points
  bool    isParallel;
  bool    isInQuadric;
} OCCTIntConicQuadResult;

/// Intersect a line with a plane.
OCCTIntConicQuadResult OCCTIntAnaLineQuad(double lox,
                                          double loy,
                                          double loz,
                                          double ldx,
                                          double ldy,
                                          double ldz,
                                          double pox,
                                          double poy,
                                          double poz,
                                          double pnx,
                                          double pny,
                                          double pnz);

/// Intersect a line with a sphere.
OCCTIntConicQuadResult OCCTIntAnaLineSphere(double lox,
                                            double loy,
                                            double loz,
                                            double ldx,
                                            double ldy,
                                            double ldz,
                                            double sx,
                                            double sy,
                                            double sz,
                                            double snx,
                                            double sny,
                                            double snz,
                                            double radius);

// MARK: - IntAna_QuadQuadGeo (v0.98.0)

/// Result of a quadric-quadric intersection.
///
/// `resultType` mirrors `IntAna_ResultType` (`IntAna_Point` = 0 ... `IntAna_NoGeometricSolution` =
/// 9) and says which of `points`/`lines`/`circles` actually holds the solution at index `i`: a
/// plane-sphere intersection is `IntAna_Point` only in the tangent case, `IntAna_Circle` for the
/// ordinary secant case (#1495), a plane-plane intersection is always `IntAna_Line`.
typedef struct
{
  int32_t solutionCount;
  int32_t resultType;  // IntAna_ResultType enum
  double  points[12];  // up to 4 result points (valid when resultType == IntAna_Point)
  double  lines[24];   // up to 4 lines (origin xyz + direction xyz)
  double  circles[28]; // up to 4 circles (center xyz + axis xyz + radius), IntAna_Circle
} OCCTQuadQuadGeoResult;

/// Intersect two planes.
OCCTQuadQuadGeoResult OCCTIntAnaPlanePlane(double p1ox,
                                           double p1oy,
                                           double p1oz,
                                           double p1nx,
                                           double p1ny,
                                           double p1nz,
                                           double p2ox,
                                           double p2oy,
                                           double p2oz,
                                           double p2nx,
                                           double p2ny,
                                           double p2nz);

/// Intersect a plane with a sphere.
OCCTQuadQuadGeoResult OCCTIntAnaPlaneSphere(double pox,
                                            double poy,
                                            double poz,
                                            double pnx,
                                            double pny,
                                            double pnz,
                                            double sx,
                                            double sy,
                                            double sz,
                                            double snx,
                                            double sny,
                                            double snz,
                                            double radius);

// MARK: - IntAna_Int3Pln (v0.98.0)

/// Intersect three planes. Returns intersection point or invalid point if parallel.
/// @param outX,outY,outZ Output intersection point
/// @return true if intersection exists
bool OCCTIntAna3Planes(double p1ox,
                       double p1oy,
                       double p1oz,
                       double p1nx,
                       double p1ny,
                       double p1nz,
                       double p2ox,
                       double p2oy,
                       double p2oz,
                       double p2nx,
                       double p2ny,
                       double p2nz,
                       double p3ox,
                       double p3oy,
                       double p3oz,
                       double p3nx,
                       double p3ny,
                       double p3nz,
                       double* _Nonnull outX,
                       double* _Nonnull outY,
                       double* _Nonnull outZ);

// MARK: - IntAna_IntLinTorus (v0.98.0)

/// Intersect a line with a torus.
/// @param outPoints Output buffer for intersection points (max 4 * 3 = 12 doubles)
/// @return Number of intersection points (0-4)
int32_t OCCTIntAnaLineTorus(double lox,
                            double loy,
                            double loz,
                            double ldx,
                            double ldy,
                            double ldz,
                            double tox,
                            double toy,
                            double toz,
                            double tnx,
                            double tny,
                            double tnz,
                            double majorRadius,
                            double minorRadius,
                            double* _Nonnull outPoints);

// MARK: - BndLib Analytic Bounding (v0.104.0)

/// Bounding box of a line segment. Returns xmin,ymin,zmin,xmax,ymax,zmax.
void OCCTBndLibLine(double px,
                    double py,
                    double pz,
                    double dx,
                    double dy,
                    double dz,
                    double p1,
                    double p2,
                    double tol,
                    double* _Nonnull xmin,
                    double* _Nonnull ymin,
                    double* _Nonnull zmin,
                    double* _Nonnull xmax,
                    double* _Nonnull ymax,
                    double* _Nonnull zmax);

/// Bounding box of a full circle.
void OCCTBndLibCircle(double cx,
                      double cy,
                      double cz,
                      double nx,
                      double ny,
                      double nz,
                      double radius,
                      double tol,
                      double* _Nonnull xmin,
                      double* _Nonnull ymin,
                      double* _Nonnull zmin,
                      double* _Nonnull xmax,
                      double* _Nonnull ymax,
                      double* _Nonnull zmax);

/// Bounding box of a full sphere.
void OCCTBndLibSphere(double cx,
                      double cy,
                      double cz,
                      double radius,
                      double tol,
                      double* _Nonnull xmin,
                      double* _Nonnull ymin,
                      double* _Nonnull zmin,
                      double* _Nonnull xmax,
                      double* _Nonnull ymax,
                      double* _Nonnull zmax);

/// Bounding box of a cylinder patch (V range).
void OCCTBndLibCylinder(double cx,
                        double cy,
                        double cz,
                        double nx,
                        double ny,
                        double nz,
                        double radius,
                        double vmin,
                        double vmax,
                        double tol,
                        double* _Nonnull xmin,
                        double* _Nonnull ymin,
                        double* _Nonnull zmin,
                        double* _Nonnull xmax,
                        double* _Nonnull ymax,
                        double* _Nonnull zmax);

/// Bounding box of a full torus.
void OCCTBndLibTorus(double cx,
                     double cy,
                     double cz,
                     double nx,
                     double ny,
                     double nz,
                     double majorRadius,
                     double minorRadius,
                     double tol,
                     double* _Nonnull xmin,
                     double* _Nonnull ymin,
                     double* _Nonnull zmin,
                     double* _Nonnull xmax,
                     double* _Nonnull ymax,
                     double* _Nonnull zmax);

/// Bounding box of a 3D edge curve (BndLib_Add3dCurve).
void OCCTBndLibEdge(OCCTShapeRef _Nonnull edge,
                    double tol,
                    double* _Nonnull xmin,
                    double* _Nonnull ymin,
                    double* _Nonnull zmin,
                    double* _Nonnull xmax,
                    double* _Nonnull ymax,
                    double* _Nonnull zmax);

/// Bounding box of a face surface (BndLib_AddSurface).
void OCCTBndLibFace(OCCTShapeRef _Nonnull face,
                    double tol,
                    double* _Nonnull xmin,
                    double* _Nonnull ymin,
                    double* _Nonnull zmin,
                    double* _Nonnull xmax,
                    double* _Nonnull ymax,
                    double* _Nonnull zmax);

// MARK: - IntAna_IntQuadQuad (v0.104.0)

/// Cylinder-sphere intersection. Returns number of curves found.
int32_t OCCTIntAnaCylinderSphere(double cylRadius,
                                 double sphCx,
                                 double sphCy,
                                 double sphCz,
                                 double sphRadius,
                                 double tol);

/// Check if cylinder-sphere intersection produced identical elements.
bool OCCTIntAnaCylinderSphereIdentical(double cylRadius,
                                       double sphCx,
                                       double sphCy,
                                       double sphCz,
                                       double sphRadius,
                                       double tol);
OCCTBndSphereRef _Nonnull OCCTBndSphereCreate(double cx, double cy, double cz, double radius);
void   OCCTBndSphereRelease(OCCTBndSphereRef _Nonnull sphere);
double OCCTBndSphereRadius(OCCTBndSphereRef _Nonnull sphere);
void   OCCTBndSphereCenter(OCCTBndSphereRef _Nonnull sphere,
                           double* _Nonnull x,
                           double* _Nonnull y,
                           double* _Nonnull z);
double OCCTBndSphereDistance(OCCTBndSphereRef _Nonnull sphere, double x, double y, double z);
bool   OCCTBndSphereIsOut(OCCTBndSphereRef _Nonnull sphere, double x, double y, double z);
bool   OCCTBndSphereIsOutSphere(OCCTBndSphereRef _Nonnull s1, OCCTBndSphereRef _Nonnull s2);
void   OCCTBndSphereAdd(OCCTBndSphereRef _Nonnull sphere, OCCTBndSphereRef _Nonnull other);

// MARK: - GeomConvert_BSplineSurfaceKnotSplitting / Geom2dConvert_BSplineCurveKnotSplitting
//
// #562: five functions used to live here (OCCTBSplineSurfaceKnotSplitsU/V,
// OCCTBSplineSurfaceKnotSplitValues, OCCTBSplineCurve2dKnotSplits,
// OCCTBSplineCurve2dKnotSplitValues), added in v0.105.0 over the same two analyzers
// OCCTSurfaceKnotSplitting and OCCTCurve2DSplitAtDiscontinuities already drove. They are gone;
// those two are the sole wrappers of their analyzer. Both now report the split knot-table
// indices, which is all the deleted family carried that the survivors did not.
//
// Two contract hazards the deleted family had, recorded so they are not reintroduced: neither
// values function took a buffer capacity (each wrote NbSplits() entries into a buffer the caller
// had sized from a *separate* call), and the surface one constructed the analyzer three times per
// logical query, once per count call and once for the values.

// MARK: - BndLib extras (v0.105.0)

/// Compute bounding box of an ellipse. bounds6 = [xmin,ymin,zmin,xmax,ymax,zmax].
void OCCTBndLibEllipse(double cx,
                       double cy,
                       double cz,
                       double nx,
                       double ny,
                       double nz,
                       double xdx,
                       double xdy,
                       double xdz,
                       double major,
                       double minor,
                       double tol,
                       double* _Nonnull bounds6);

/// Compute bounding box of a cone segment.
void OCCTBndLibCone(double cx,
                    double cy,
                    double cz,
                    double nx,
                    double ny,
                    double nz,
                    double semiAngle,
                    double refRadius,
                    double vmin,
                    double vmax,
                    double tol,
                    double* _Nonnull bounds6);

/// Compute bounding box of a circular arc.
void OCCTBndLibCircleArc(double cx,
                         double cy,
                         double cz,
                         double nx,
                         double ny,
                         double nz,
                         double radius,
                         double u1,
                         double u2,
                         double tol,
                         double* _Nonnull bounds6);

/// Compute bounding box of an ellipse arc.
void OCCTBndLibEllipseArc(double cx,
                          double cy,
                          double cz,
                          double nx,
                          double ny,
                          double nz,
                          double xdx,
                          double xdy,
                          double xdz,
                          double major,
                          double minor,
                          double u1,
                          double u2,
                          double tol,
                          double* _Nonnull bounds6);

/// Compute bounding box of a parabola arc.
void OCCTBndLibParabolaArc(double cx,
                           double cy,
                           double cz,
                           double nx,
                           double ny,
                           double nz,
                           double xdx,
                           double xdy,
                           double xdz,
                           double focal,
                           double u1,
                           double u2,
                           double tol,
                           double* _Nonnull bounds6);

/// Compute bounding box of a hyperbola arc.
void OCCTBndLibHyperbolaArc(double cx,
                            double cy,
                            double cz,
                            double nx,
                            double ny,
                            double nz,
                            double xdx,
                            double xdy,
                            double xdz,
                            double major,
                            double minor,
                            double u1,
                            double u2,
                            double tol,
                            double* _Nonnull bounds6);

// MARK: - IntAna extensions (v0.105.0)

/// Cone-sphere intersection curve count. Returns -1 on error, -2 if identical.
int32_t OCCTIntAnaConeSphere(double semiAngle,
                             double refRadius,
                             double sphCx,
                             double sphCy,
                             double sphCz,
                             double sphRadius,
                             double tol);

/// Sample points along a cone-sphere intersection curve. Returns actual number of points.
int32_t OCCTIntAnaConeSpherePoints(double  semiAngle,
                                   double  refRadius,
                                   double  sphCx,
                                   double  sphCy,
                                   double  sphCz,
                                   double  sphRadius,
                                   double  tol,
                                   int32_t curveIndex,
                                   int32_t nbSamples,
                                   double* _Nonnull xs,
                                   double* _Nonnull ys,
                                   double* _Nonnull zs);

/// Check if a cone-sphere intersection curve is open.
bool OCCTIntAnaConeSphereIsOpen(double  semiAngle,
                                double  refRadius,
                                double  sphCx,
                                double  sphCy,
                                double  sphCz,
                                double  sphRadius,
                                double  tol,
                                int32_t curveIndex);

/// Get the domain of a cone-sphere intersection curve.
void OCCTIntAnaConeSphereGetDomain(double  semiAngle,
                                   double  refRadius,
                                   double  sphCx,
                                   double  sphCy,
                                   double  sphCz,
                                   double  sphRadius,
                                   double  tol,
                                   int32_t curveIndex,
                                   double* _Nonnull first,
                                   double* _Nonnull last);

// MARK: - math_TrigonometricFunctionRoots (v0.109.0)

/// Find roots of A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0 on [inf,sup].
/// @return Number of roots found (-1 on error)
int32_t OCCTTrigRoots(double A,
                      double B,
                      double C,
                      double D,
                      double E,
                      double inf,
                      double sup,
                      double* _Nonnull roots,
                      int32_t maxRoots);

/// Check if all reals in [inf,sup] are solutions.
bool OCCTTrigRootsInfinite(double A,
                           double B,
                           double C,
                           double D,
                           double E,
                           double inf,
                           double sup);

// MARK: - Math Solver Callbacks (v0.110.0)

/// Callback for 1D function with derivative: f(x) -> (value, derivative). Returns true on success.
typedef bool (*OCCTMathFuncDerivCallback)(double x,
                                          double* _Nonnull value,
                                          double* _Nonnull derivative,
                                          void* _Nullable context);

/// Callback for N-dim function: f(X[n]) -> value. Returns true on success.
typedef bool (*OCCTMathMultiVarCallback)(const double* _Nonnull x,
                                         int32_t n,
                                         double* _Nonnull value,
                                         void* _Nullable context);

/// Callback for N-dim function with gradient: f(X[n]) -> (value, grad[n]). Returns true on success.
typedef bool (*OCCTMathMultiVarGradCallback)(const double* _Nonnull x,
                                             int32_t n,
                                             double* _Nonnull value,
                                             double* _Nonnull gradient,
                                             void* _Nullable context);

/// Callback for equation system values: F(X[nVars]) -> values[nEqs]. Returns true on success.
typedef bool (*OCCTMathFuncSetCallback)(const double* _Nonnull x,
                                        int32_t nVars,
                                        double* _Nonnull values,
                                        int32_t nEqs,
                                        void* _Nullable context);

/// Callback for equation system Jacobian: J(X[nVars]) -> jacobian[nEqs*nVars] (row-major). Returns
/// true on success.
typedef bool (*OCCTMathFuncSetDerivCallback)(const double* _Nonnull x,
                                             int32_t nVars,
                                             double* _Nonnull jacobian,
                                             int32_t nEqs,
                                             void* _Nullable context);

// MARK: - math_FunctionRoot (v0.110.0)

/// Find root of f(x)=0 near guess using Newton-Raphson. Returns root value; isDone indicates
/// convergence.
double OCCTMathFunctionRoot(OCCTMathFuncDerivCallback _Nonnull callback,
                            void* _Nullable context,
                            double  guess,
                            double  tolerance,
                            int32_t maxIter,
                            bool* _Nonnull isDone);

/// Find root of f(x)=0 near guess in [a,b] using Newton-Raphson. Returns root value; isDone
/// indicates convergence.
double OCCTMathFunctionRootBounded(OCCTMathFuncDerivCallback _Nonnull callback,
                                   void* _Nullable context,
                                   double  guess,
                                   double  tolerance,
                                   double  a,
                                   double  b,
                                   int32_t maxIter,
                                   bool* _Nonnull isDone);

/// Find root of f(x)=0 in [a,b] using bisection+Newton hybrid. Returns root value; isDone indicates
/// convergence.
double OCCTMathBissecNewton(OCCTMathFuncDerivCallback _Nonnull callback,
                            void* _Nullable context,
                            double  a,
                            double  b,
                            double  tolerance,
                            int32_t maxIter,
                            bool* _Nonnull isDone);

// MARK: - math_FunctionSetRoot (v0.110.0)

/// Solve a system of nEqs equations in nVars variables using Newton's method.
/// startPoint[nVars], tolerance: scalar tolerance, result[nVars]. Returns true on convergence.
bool OCCTMathFunctionSetRoot(int32_t nVars,
                             int32_t nEqs,
                             OCCTMathFuncSetCallback _Nonnull valueCallback,
                             OCCTMathFuncSetDerivCallback _Nonnull derivCallback,
                             void* _Nullable context,
                             const double* _Nonnull startPoint,
                             double  tolerance,
                             int32_t maxIter,
                             double* _Nonnull result);

// MARK: - math_BFGS (v0.110.0)

/// Minimize a multivariate function using BFGS quasi-Newton method.
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathBFGS(int32_t nVars,
                  OCCTMathMultiVarGradCallback _Nonnull callback,
                  void* _Nullable context,
                  const double* _Nonnull startPoint,
                  double  tolerance,
                  int32_t maxIter,
                  double* _Nonnull result,
                  double* _Nonnull minimum);

// MARK: - math_Powell (v0.110.0)

/// Minimize a multivariate function using Powell's method (derivative-free).
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathPowell(int32_t nVars,
                    OCCTMathMultiVarCallback _Nonnull callback,
                    void* _Nullable context,
                    const double* _Nonnull startPoint,
                    double  tolerance,
                    int32_t maxIter,
                    double* _Nonnull result,
                    double* _Nonnull minimum);

// MARK: - math_BrentMinimum (v0.110.0)

/// Minimize a 1D function using Brent's method on [ax, cx] with initial bracket at bx.
/// Returns true on convergence; location and minimum are output.
bool OCCTMathBrentMinimum(OCCTMathFuncDerivCallback _Nonnull callback,
                          void* _Nullable context,
                          double  ax,
                          double  bx,
                          double  cx,
                          double  tolerance,
                          int32_t maxIter,
                          double* _Nonnull location,
                          double* _Nonnull minimum);

// MARK: - Batch Curve Evaluation (v0.110.0)
//
// #486: OCCTCurve3DEvalBatchD0/D1 and OCCTCurve2DEvalBatchD0/D1 lived here. They evaluated
// Geom_Curve::EvalD0/EvalD1 in a plain per-point loop, duplicating v0.29.0's already
// batch-optimised OCCTCurve3DEvaluateGrid/D1 and OCCTCurve2DEvaluateGrid/D1 under a second
// name and a per-axis-plane output shape. Removed; their Swift spellings
// (Curve3D/Curve2D.evalBatchD0/D1) now forward to the v0.29.0 family.

// MARK: - math_PSO (v0.111.0)

/// Minimize a multivariate function using Particle Swarm Optimization.
/// lower[nVars], upper[nVars], steps[nVars], result[nVars]. Returns true on success.
bool OCCTMathPSO(int32_t nVars,
                 OCCTMathMultiVarCallback _Nonnull callback,
                 void* _Nullable context,
                 const double* _Nonnull lower,
                 const double* _Nonnull upper,
                 const double* _Nonnull steps,
                 int32_t nbParticles,
                 int32_t nbIter,
                 double* _Nonnull result,
                 double* _Nonnull minimum);

// MARK: - math_GlobOptMin (v0.111.0)

/// Find global minimum of a multivariate function using Lipschitz optimization.
/// lower[nVars], upper[nVars], result[nVars]. Returns true on success.
bool OCCTMathGlobOptMin(int32_t nVars,
                        OCCTMathMultiVarCallback _Nonnull callback,
                        void* _Nullable context,
                        const double* _Nonnull lower,
                        const double* _Nonnull upper,
                        double* _Nonnull result,
                        double* _Nonnull minimum);

// MARK: - math_FunctionRoots (v0.111.0)

/// Find all roots of f(x)=0 in [a, b] using derivative-based method.
/// Returns number of roots found; roots[maxRoots] is filled with values.
int32_t OCCTMathFunctionRoots(OCCTMathFuncDerivCallback _Nonnull callback,
                              void* _Nullable context,
                              double  a,
                              double  b,
                              int32_t nbSample,
                              double* _Nonnull roots,
                              int32_t maxRoots);

// MARK: - math_GaussSingleIntegration (v0.111.0)

/// Callback for simple 1D function (no derivative): f(x) -> value. Returns true on success.
typedef bool (*OCCTMathSimpleFuncCallback)(double x,
                                           double* _Nonnull value,
                                           void* _Nullable context);

/// Integrate a function from lower to upper using Gauss quadrature of given order.
/// Returns the integral value.
double OCCTMathGaussIntegrate(OCCTMathSimpleFuncCallback _Nonnull callback,
                              void* _Nullable context,
                              double  lower,
                              double  upper,
                              int32_t order);

// MARK: - math_NewtonFunctionSetRoot (v0.111.0)

/// Solve a system of equations using Newton's method (NewtonFunctionSetRoot variant).
/// start[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathNewtonFuncSetRoot(int32_t nVars,
                               int32_t nEqs,
                               OCCTMathFuncSetCallback _Nonnull valCb,
                               OCCTMathFuncSetDerivCallback _Nonnull derivCb,
                               void* _Nullable context,
                               const double* _Nonnull start,
                               double  tol,
                               int32_t maxIter,
                               double* _Nonnull result);

// MARK: - MathPoly_Laguerre (v0.111.0)

/// Find real roots of a polynomial using Laguerre's method.
/// coefficients[degree+1] in ascending order (constant first). Returns number of real roots found.
int32_t OCCTPolyLaguerreRoots(const double* _Nonnull coefficients,
                              int32_t degree,
                              double* _Nonnull roots,
                              int32_t maxRoots);

/// Find complex roots of a polynomial using Laguerre's method.
/// Returns number of complex roots found; realParts[maxRoots], imagParts[maxRoots].
int32_t OCCTPolyLaguerreComplexRoots(const double* _Nonnull coefficients,
                                     int32_t degree,
                                     double* _Nonnull realParts,
                                     double* _Nonnull imagParts,
                                     int32_t maxRoots);

/// Find real roots of quintic: a*x^5 + b*x^4 + c*x^3 + d*x^2 + e*x + f = 0.
/// Returns number of real roots found.
int32_t OCCTPolyQuinticRoots(double a,
                             double b,
                             double c,
                             double d,
                             double e,
                             double f,
                             double* _Nonnull roots,
                             int32_t maxRoots);

// MARK: - math_NewtonMinimum (v0.111.1)

/// Callback for N-dim function with gradient AND Hessian.
/// hessian is row-major n*n matrix.
typedef bool (*OCCTMathHessianCallback)(const double* _Nonnull x,
                                        int32_t n,
                                        double* _Nonnull value,
                                        double* _Nonnull gradient,
                                        double* _Nonnull hessian,
                                        void* _Nullable context);

/// Minimize using Newton's method with Hessian.
/// Returns true if converged. result is n-element array.
bool OCCTMathNewtonMinimum(int32_t nVars,
                           OCCTMathHessianCallback _Nonnull callback,
                           void* _Nullable context,
                           const double* _Nonnull startPoint,
                           double  tolerance,
                           int32_t maxIter,
                           double* _Nonnull result,
                           double* _Nonnull minimum);

/// Create an Intf_Tool instance.
OCCTIntfToolRef _Nonnull OCCTIntfToolCreate(void);

/// Release an Intf_Tool instance.
void OCCTIntfToolRelease(OCCTIntfToolRef _Nonnull tool);

/// Clip a line to a bounding box. Returns number of segments.
int32_t OCCTIntfToolLinBox(OCCTIntfToolRef _Nonnull tool,
                           double px,
                           double py,
                           double pz,
                           double dx,
                           double dy,
                           double dz,
                           double xmin,
                           double ymin,
                           double zmin,
                           double xmax,
                           double ymax,
                           double zmax);

/// Get the begin parameter of a segment (1-based index).
double OCCTIntfToolBeginParam(OCCTIntfToolRef _Nonnull tool, int32_t segIndex);

/// Get the end parameter of a segment (1-based index).
double OCCTIntfToolEndParam(OCCTIntfToolRef _Nonnull tool, int32_t segIndex);

// MARK: - gp_Ax3 (v0.116.0)

/// Create Ax3 from point + main direction + X direction. isDirect reports handedness.
void OCCTAx3Create(double px,
                   double py,
                   double pz,
                   double nx,
                   double ny,
                   double nz,
                   double xDirX,
                   double xDirY,
                   double xDirZ,
                   bool* _Nonnull isDirect,
                   double* _Nonnull xDx,
                   double* _Nonnull xDy,
                   double* _Nonnull xDz,
                   double* _Nonnull yDx,
                   double* _Nonnull yDy,
                   double* _Nonnull yDz);

/// Create Ax3 from point + main direction only (X/Y auto-computed).
void OCCTAx3CreateFromNormal(double px,
                             double py,
                             double pz,
                             double nx,
                             double ny,
                             double nz,
                             bool* _Nonnull isDirect,
                             double* _Nonnull xDx,
                             double* _Nonnull xDy,
                             double* _Nonnull xDz,
                             double* _Nonnull yDx,
                             double* _Nonnull yDy,
                             double* _Nonnull yDz);

/// Angle between two Ax3 coordinate systems.
double OCCTAx3Angle(double p1x,
                    double p1y,
                    double p1z,
                    double n1x,
                    double n1y,
                    double n1z,
                    double x1x,
                    double x1y,
                    double x1z,
                    double p2x,
                    double p2y,
                    double p2z,
                    double n2x,
                    double n2y,
                    double n2z,
                    double x2x,
                    double x2y,
                    double x2z);

/// Check if two Ax3 are coplanar.
bool OCCTAx3IsCoplanar(double p1x,
                       double p1y,
                       double p1z,
                       double n1x,
                       double n1y,
                       double n1z,
                       double x1x,
                       double x1y,
                       double x1z,
                       double p2x,
                       double p2y,
                       double p2z,
                       double n2x,
                       double n2y,
                       double n2z,
                       double x2x,
                       double x2y,
                       double x2z,
                       double linearTol,
                       double angularTol);

/// Mirror Ax3 about a point.
void OCCTAx3MirrorPoint(double px,
                        double py,
                        double pz,
                        double nx,
                        double ny,
                        double nz,
                        double xDx,
                        double xDy,
                        double xDz,
                        double mx,
                        double my,
                        double mz,
                        double* _Nonnull rpx,
                        double* _Nonnull rpy,
                        double* _Nonnull rpz,
                        double* _Nonnull rnx,
                        double* _Nonnull rny,
                        double* _Nonnull rnz,
                        double* _Nonnull rxDx,
                        double* _Nonnull rxDy,
                        double* _Nonnull rxDz);

/// Rotate Ax3 about an axis.
void OCCTAx3Rotate(double px,
                   double py,
                   double pz,
                   double nx,
                   double ny,
                   double nz,
                   double xDx,
                   double xDy,
                   double xDz,
                   double axPx,
                   double axPy,
                   double axPz,
                   double axDx,
                   double axDy,
                   double axDz,
                   double angle,
                   double* _Nonnull rpx,
                   double* _Nonnull rpy,
                   double* _Nonnull rpz,
                   double* _Nonnull rnx,
                   double* _Nonnull rny,
                   double* _Nonnull rnz,
                   double* _Nonnull rxDx,
                   double* _Nonnull rxDy,
                   double* _Nonnull rxDz);

/// Translate Ax3.
void OCCTAx3Translate(double px,
                      double py,
                      double pz,
                      double nx,
                      double ny,
                      double nz,
                      double xDx,
                      double xDy,
                      double xDz,
                      double vx,
                      double vy,
                      double vz,
                      double* _Nonnull rpx,
                      double* _Nonnull rpy,
                      double* _Nonnull rpz);

// MARK: - Quaternion Interpolation (v0.116.0)

/// Spherical linear interpolation (SLERP) between two quaternions at parameter t.
void OCCTQuaternionSLerp(double x1,
                         double y1,
                         double z1,
                         double w1,
                         double x2,
                         double y2,
                         double z2,
                         double w2,
                         double t,
                         double* _Nonnull rx,
                         double* _Nonnull ry,
                         double* _Nonnull rz,
                         double* _Nonnull rw);

/// Linear interpolation (NLERP) between two quaternions at parameter t. Result is normalized.
void OCCTQuaternionNLerp(double x1,
                         double y1,
                         double z1,
                         double w1,
                         double x2,
                         double y2,
                         double z2,
                         double w2,
                         double t,
                         double* _Nonnull rx,
                         double* _Nonnull ry,
                         double* _Nonnull rz,
                         double* _Nonnull rw);

/// Interpolate between two gp_Trsf at parameter t (translation + rotation interpolation).
/// Each transform is: translation(tx,ty,tz) + quaternion(qx,qy,qz,qw) + scale.
void OCCTTrsfInterpolate(double tx1,
                         double ty1,
                         double tz1,
                         double qx1,
                         double qy1,
                         double qz1,
                         double qw1,
                         double tx2,
                         double ty2,
                         double tz2,
                         double qx2,
                         double qy2,
                         double qz2,
                         double qw2,
                         double t,
                         double* _Nonnull rtx,
                         double* _Nonnull rty,
                         double* _Nonnull rtz,
                         double* _Nonnull rqx,
                         double* _Nonnull rqy,
                         double* _Nonnull rqz,
                         double* _Nonnull rqw);

// MARK: - gp_XY (v0.116.0)

/// 2D vector modulus (length).
double OCCTXYModulus(double x, double y);

/// 2D cross product (scalar).
double OCCTXYCrossed(double x1, double y1, double x2, double y2);

/// 2D dot product.
double OCCTXYDot(double x1, double y1, double x2, double y2);

/// Normalize 2D vector. Returns false if zero length.
bool OCCTXYNormalize(double x, double y, double* _Nonnull rx, double* _Nonnull ry);

// MARK: - gp_XYZ (v0.116.0)

/// 3D vector modulus (length).
double OCCTXYZModulus(double x, double y, double z);

/// 3D cross product.
void OCCTXYZCrossed(double x1,
                    double y1,
                    double z1,
                    double x2,
                    double y2,
                    double z2,
                    double* _Nonnull rx,
                    double* _Nonnull ry,
                    double* _Nonnull rz);

/// 3D dot product.
double OCCTXYZDot(double x1, double y1, double z1, double x2, double y2, double z2);

/// Scalar triple product (a . (b x c)).
double OCCTXYZDotCross(double ax,
                       double ay,
                       double az,
                       double bx,
                       double by,
                       double bz,
                       double cx,
                       double cy,
                       double cz);

/// Normalize 3D vector. Returns false if zero length.
bool OCCTXYZNormalize(double x,
                      double y,
                      double z,
                      double* _Nonnull rx,
                      double* _Nonnull ry,
                      double* _Nonnull rz);

// MARK: - math_BracketedRoot (v0.116.0)

/// Find root of f(x)=0 in [bound1, bound2] using Brent's method.
/// Uses OCCTMathFuncDerivCallback. Returns root value; isDone indicates convergence.
double OCCTMathBracketedRoot(OCCTMathFuncDerivCallback _Nonnull callback,
                             void* _Nullable context,
                             double  bound1,
                             double  bound2,
                             double  tolerance,
                             int32_t maxIter,
                             bool* _Nonnull isDone,
                             int32_t* _Nonnull nbIter);

// MARK: - math_BracketMinimum (v0.116.0)

/// Bracket a minimum of f(x) starting from points a and b.
/// Returns the bracketing triplet (a,b,c) with f(b) < f(a) and f(b) < f(c).
bool OCCTMathBracketMinimum(OCCTMathSimpleFuncCallback _Nonnull callback,
                            void* _Nullable context,
                            double a,
                            double b,
                            double* _Nonnull ra,
                            double* _Nonnull rb,
                            double* _Nonnull rc,
                            double* _Nonnull fa,
                            double* _Nonnull fb,
                            double* _Nonnull fc);

// MARK: - math_FRPR (v0.116.0)

/// Minimize a multivariate function using Fletcher-Reeves-Polak-Ribiere conjugate gradient.
/// startPoint[nVars], result[nVars]. Returns true on convergence.
bool OCCTMathFRPR(int32_t nVars,
                  OCCTMathMultiVarGradCallback _Nonnull callback,
                  void* _Nullable context,
                  const double* _Nonnull startPoint,
                  double  tolerance,
                  int32_t maxIter,
                  double* _Nonnull result,
                  double* _Nonnull minimum,
                  int32_t* _Nonnull nbIter);

// MARK: - math_FunctionAllRoots (v0.116.0)

/// Find all roots of f(x)=0 in [a,b] using sampling + refinement.
/// Returns number of isolated roots found. roots[] must be pre-allocated with maxRoots capacity.
int32_t OCCTMathFunctionAllRoots(OCCTMathFuncDerivCallback _Nonnull callback,
                                 void* _Nullable context,
                                 double  a,
                                 double  b,
                                 int32_t nbSamples,
                                 double  epsX,
                                 double  epsF,
                                 double  epsNul,
                                 double* _Nonnull roots,
                                 int32_t maxRoots);

// MARK: - math_GaussLeastSquare (v0.116.0)

/// Solve overdetermined linear system Ax=b in least-squares sense.
/// matA is row-major [nRows x nCols], b[nRows], x[nCols]. Returns true on success.
bool OCCTMathGaussLeastSquare(const double* _Nonnull matA,
                              int32_t nRows,
                              int32_t nCols,
                              const double* _Nonnull b,
                              double* _Nonnull x);

// MARK: - math_NewtonFunctionRoot (v0.116.0)

/// Find root of f(x)=0 starting from guess, optionally bounded.
/// Uses OCCTMathFuncDerivCallback. Returns root; isDone on convergence.
double OCCTMathNewtonFunctionRoot(OCCTMathFuncDerivCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  guess,
                                  double  epsX,
                                  double  epsF,
                                  int32_t maxIter,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull derivative,
                                  int32_t* _Nonnull nbIter);

/// Bounded variant.
double OCCTMathNewtonFunctionRootBounded(OCCTMathFuncDerivCallback _Nonnull callback,
                                         void* _Nullable context,
                                         double  guess,
                                         double  epsX,
                                         double  epsF,
                                         double  a,
                                         double  b,
                                         int32_t maxIter,
                                         bool* _Nonnull isDone);

// MARK: - math_Uzawa (v0.116.0)

/// Solve constrained optimization: minimize ||x||^2 subject to Cont * x = Secont.
/// Cont is row-major [nConstraints x nVars], Secont[nConstraints], startPoint[nVars],
/// result[nVars].
bool OCCTMathUzawa(const double* _Nonnull contData,
                   int32_t nConstraints,
                   int32_t nVars,
                   const double* _Nonnull secont,
                   const double* _Nonnull startPoint,
                   double  epsLix,
                   double  epsLic,
                   int32_t maxIter,
                   double* _Nonnull result,
                   int32_t* _Nonnull nbIter);

// MARK: - math_EigenValuesSearcher (v0.116.0)

/// Find eigenvalues of symmetric tridiagonal matrix.
/// diagonal[n], subdiagonal[n] (last element unused). eigenvalues[n].
/// Returns number of eigenvalues found (n on success, 0 on failure).
int32_t OCCTMathEigenValues(const double* _Nonnull diagonal,
                            const double* _Nonnull subdiagonal,
                            int32_t n,
                            double* _Nonnull eigenvalues);

/// Find eigenvalues and eigenvectors. eigenvectors is row-major [n x n].
int32_t OCCTMathEigenValuesAndVectors(const double* _Nonnull diagonal,
                                      const double* _Nonnull subdiagonal,
                                      int32_t n,
                                      double* _Nonnull eigenvalues,
                                      double* _Nonnull eigenvectors);

// MARK: - math_KronrodSingleIntegration (v0.116.0)

/// Gauss-Kronrod integration of f(x) over [lower, upper].
/// Returns integral value; errorReached and nbIterReached are output.
double OCCTMathKronrodIntegration(OCCTMathSimpleFuncCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  lower,
                                  double  upper,
                                  int32_t nbPoints,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull errorReached);

/// Adaptive Gauss-Kronrod with tolerance.
double OCCTMathKronrodIntegrationAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                          void* _Nullable context,
                                          double  lower,
                                          double  upper,
                                          int32_t nbPoints,
                                          double  tolerance,
                                          int32_t maxIter,
                                          bool* _Nonnull isDone,
                                          double* _Nonnull errorReached,
                                          int32_t* _Nonnull nbIterReached);

// MARK: - math_GaussMultipleIntegration (v0.116.0)

/// Multi-dimensional Gauss-Legendre integration.
/// lower[nVars], upper[nVars], order[nVars]. Returns integral value.
double OCCTMathGaussMultipleIntegration(OCCTMathMultiVarCallback _Nonnull callback,
                                        void* _Nullable context,
                                        int32_t nVars,
                                        const double* _Nonnull lower,
                                        const double* _Nonnull upper,
                                        const int32_t* _Nonnull order,
                                        bool* _Nonnull isDone);

// MARK: - math_GaussSetIntegration (v0.116.0)

/// Gauss-Legendre integration for function sets.
/// lower[nVars], upper[nVars], order[nVars], result[nEqs].
bool OCCTMathGaussSetIntegration(OCCTMathFuncSetCallback _Nonnull callback,
                                 void* _Nullable context,
                                 int32_t nVars,
                                 int32_t nEqs,
                                 const double* _Nonnull lower,
                                 const double* _Nonnull upper,
                                 const int32_t* _Nonnull order,
                                 double* _Nonnull result);

// MARK: - MathPoly rc4 polynomial solvers (v0.117.0)

/// Solve linear equation: a*x + b = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyLinear(double a, double b, double* _Nonnull roots, int32_t maxRoots);

/// Solve quadratic equation: a*x^2 + b*x + c = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyQuadratic(double a,
                              double b,
                              double c,
                              double* _Nonnull roots,
                              int32_t maxRoots);

/// Solve cubic equation: a*x^3 + b*x^2 + c*x + d = 0. Returns number of roots found (-1 on error).
int32_t OCCTMathPolyCubic(double a,
                          double b,
                          double c,
                          double d,
                          double* _Nonnull roots,
                          int32_t maxRoots);

/// Solve quartic equation: a*x^4 + b*x^3 + c*x^2 + d*x + e = 0. Returns number of roots found (-1
/// on error).
int32_t OCCTMathPolyQuartic(double a,
                            double b,
                            double c,
                            double d,
                            double e,
                            double* _Nonnull roots,
                            int32_t maxRoots);

// MARK: - MathInteg rc4 integration (v0.117.0)

/// Gauss-Legendre quadrature using rc4 MathInteg templates.
double OCCTMathIntegGauss(OCCTMathSimpleFuncCallback _Nonnull callback,
                          void* _Nullable context,
                          double  lower,
                          double  upper,
                          int32_t nbPoints,
                          bool* _Nonnull isDone,
                          double* _Nonnull error);

/// Adaptive Gauss-Legendre using rc4 MathInteg templates.
double OCCTMathIntegGaussAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                  void* _Nullable context,
                                  double  lower,
                                  double  upper,
                                  double  tolerance,
                                  int32_t maxIter,
                                  bool* _Nonnull isDone,
                                  double* _Nonnull error,
                                  int32_t* _Nonnull nbIter);

/// Gauss-Kronrod rule using rc4 MathInteg templates.
double OCCTMathIntegKronrod(OCCTMathSimpleFuncCallback _Nonnull callback,
                            void* _Nullable context,
                            double  lower,
                            double  upper,
                            int32_t nbGaussPoints,
                            bool* _Nonnull isDone,
                            double* _Nonnull error);

/// Adaptive Gauss-Kronrod using rc4 MathInteg templates.
double OCCTMathIntegKronrodAdaptive(OCCTMathSimpleFuncCallback _Nonnull callback,
                                    void* _Nullable context,
                                    double  lower,
                                    double  upper,
                                    int32_t nbGaussPoints,
                                    double  tolerance,
                                    int32_t maxIter,
                                    bool* _Nonnull isDone,
                                    double* _Nonnull error,
                                    int32_t* _Nonnull nbIter);

/// Tanh-Sinh (double exponential) quadrature using rc4 MathInteg templates.
double OCCTMathIntegTanhSinh(OCCTMathSimpleFuncCallback _Nonnull callback,
                             void* _Nullable context,
                             double  lower,
                             double  upper,
                             double  tolerance,
                             int32_t maxLevels,
                             bool* _Nonnull isDone,
                             double* _Nonnull error,
                             int32_t* _Nonnull nbIter);

// MARK: - Convert_CompPolynomialToPoles (v0.118.0)

/// Convert a single polynomial segment to BSpline poles/knots/mults.
/// Returns true on success. Caller must free outPoles and outKnots with free().
bool OCCTConvertPolynomialToPoles(int32_t dimension,
                                  int32_t maxDegree,
                                  int32_t degree,
                                  const double* _Nonnull coefficients,
                                  int32_t coeffCount,
                                  double  polyStart,
                                  double  polyEnd,
                                  double  trueStart,
                                  double  trueEnd,
                                  double* _Nullable* _Nonnull outPoles,
                                  int32_t* _Nonnull outPoleCount,
                                  double* _Nullable* _Nonnull outKnots,
                                  int32_t* _Nonnull outKnotCount,
                                  int32_t* _Nonnull outDegree);

/// Create displacement transform from one coordinate system to another.
void OCCTTrsfDisplacement(double fromPx,
                          double fromPy,
                          double fromPz,
                          double fromDx,
                          double fromDy,
                          double fromDz,
                          double toPx,
                          double toPy,
                          double toPz,
                          double toDx,
                          double toDy,
                          double toDz,
                          double* _Nonnull a11,
                          double* _Nonnull a12,
                          double* _Nonnull a13,
                          double* _Nonnull a14,
                          double* _Nonnull a21,
                          double* _Nonnull a22,
                          double* _Nonnull a23,
                          double* _Nonnull a24,
                          double* _Nonnull a31,
                          double* _Nonnull a32,
                          double* _Nonnull a33,
                          double* _Nonnull a34);

/// Create transformation between two coordinate systems.
void OCCTTrsfTransformation(double fromPx,
                            double fromPy,
                            double fromPz,
                            double fromDx,
                            double fromDy,
                            double fromDz,
                            double toPx,
                            double toPy,
                            double toPz,
                            double toDx,
                            double toDy,
                            double toDz,
                            double* _Nonnull a11,
                            double* _Nonnull a12,
                            double* _Nonnull a13,
                            double* _Nonnull a14,
                            double* _Nonnull a21,
                            double* _Nonnull a22,
                            double* _Nonnull a23,
                            double* _Nonnull a24,
                            double* _Nonnull a31,
                            double* _Nonnull a32,
                            double* _Nonnull a33,
                            double* _Nonnull a34);

// --- gp_Pln distance/contains ---

/// Distance from a plane (given by origin + normal) to a point.
double OCCTPlaneDistanceToPoint(double ox,
                                double oy,
                                double oz,
                                double nx,
                                double ny,
                                double nz,
                                double px,
                                double py,
                                double pz);

/// Distance from a plane to a line (given by line point + direction).
double OCCTPlaneDistanceToLine(double ox,
                               double oy,
                               double oz,
                               double nx,
                               double ny,
                               double nz,
                               double lx,
                               double ly,
                               double lz,
                               double dx,
                               double dy,
                               double dz);

/// Check if a plane contains a point within tolerance.
bool OCCTPlaneContainsPoint(double ox,
                            double oy,
                            double oz,
                            double nx,
                            double ny,
                            double nz,
                            double px,
                            double py,
                            double pz,
                            double tolerance);

// --- gp_Lin distance/contains ---

/// Distance from a line (point + direction) to a point.
double OCCTLineDistanceToPoint(double lx,
                               double ly,
                               double lz,
                               double dx,
                               double dy,
                               double dz,
                               double px,
                               double py,
                               double pz);

/// Distance between two lines.
double OCCTLineDistanceToLine(double l1x,
                              double l1y,
                              double l1z,
                              double d1x,
                              double d1y,
                              double d1z,
                              double l2x,
                              double l2y,
                              double l2z,
                              double d2x,
                              double d2y,
                              double d2z);

/// Check if a line contains a point within tolerance.
bool OCCTLineContainsPoint(double lx,
                           double ly,
                           double lz,
                           double dx,
                           double dy,
                           double dz,
                           double px,
                           double py,
                           double pz,
                           double tolerance);

// --- gp_Vec extras ---

/// Compute the magnitude of the cross product of two vectors.
double OCCTVecCrossMagnitude(double v1x,
                             double v1y,
                             double v1z,
                             double v2x,
                             double v2y,
                             double v2z);

/// Compute the square magnitude of the cross product of two vectors.
double OCCTVecCrossSquareMagnitude(double v1x,
                                   double v1y,
                                   double v1z,
                                   double v2x,
                                   double v2y,
                                   double v2z);

// --- gp_Dir extras ---

/// Check if two directions are opposite within angular tolerance (radians).
bool OCCTDirIsOpposite(double d1x,
                       double d1y,
                       double d1z,
                       double d2x,
                       double d2y,
                       double d2z,
                       double angularTolerance);

/// Check if two directions are normal (perpendicular) within angular tolerance (radians).
bool OCCTDirIsNormal(double d1x,
                     double d1y,
                     double d1z,
                     double d2x,
                     double d2y,
                     double d2z,
                     double angularTolerance);

#endif /* OCCTBridge_Spatial_h */
