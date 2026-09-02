//
//  OCCTBridge_Curve3D.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Curve3D domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Curve3D_h
#define OCCTBridge_Curve3D_h

void OCCTCurve3DRelease(OCCTCurve3DRef curve);

OCCTCompCurveRef OCCTCompCurveCreate(OCCTWireRef wire);
void             OCCTCompCurveRelease(OCCTCompCurveRef ref);
double           OCCTCompCurveLength(OCCTCompCurveRef ref); // total arc length, -1 on error
void             OCCTCompCurveParamRange(OCCTCompCurveRef ref, double* first, double* last);
bool    OCCTCompCurvePointAtParam(OCCTCompCurveRef ref, double u, double* x, double* y, double* z);
bool    OCCTCompCurveTangentAtParam(OCCTCompCurveRef ref,
                                    double           u,
                                    double*          x,
                                    double*          y,
                                    double*          z); // unit tangent (D1)
bool    OCCTCompCurveParamAtAbscissa(OCCTCompCurveRef ref,
                                     double           s,
                                     double*          outParam); // param at arc length s from start
int32_t OCCTCompCurveSampleUniform(
  OCCTCompCurveRef ref,
  int32_t          count,
  double*          outXYZ); // count equally-spaced (arc length) points; outXYZ holds count*3
OCCTEdgeCurveRef OCCTEdgeCurveCreate(OCCTEdgeRef edge);
void             OCCTEdgeCurveRelease(OCCTEdgeCurveRef ref);
double           OCCTEdgeCurveLength(OCCTEdgeCurveRef ref);
void             OCCTEdgeCurveParamRange(OCCTEdgeCurveRef ref, double* first, double* last);
bool OCCTEdgeCurvePointAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z);
bool OCCTEdgeCurveTangentAtParam(OCCTEdgeCurveRef ref, double u, double* x, double* y, double* z);
bool OCCTEdgeCurveParamAtAbscissa(OCCTEdgeCurveRef ref, double s, double* outParam);
int32_t OCCTEdgeCurveSampleUniform(OCCTEdgeCurveRef ref, int32_t count, double* outXYZ);

/// Get the 3D curve underlying an edge as a standalone Curve3D handle.
/// Returns nil if the edge has no 3D curve representation.
/// Ensures the 3D curve is built via BRepLib::BuildCurves3d for edges that
/// may only carry a pcurve (lofted / swept shapes). v0.147.
OCCTCurve3DRef _Nullable OCCTEdgeGetCurve3D(OCCTEdgeRef _Nonnull edge);

// Properties
void   OCCTCurve3DGetDomain(OCCTCurve3DRef curve, double* first, double* last);
bool   OCCTCurve3DIsClosed(OCCTCurve3DRef curve);
bool   OCCTCurve3DIsPeriodic(OCCTCurve3DRef curve);
double OCCTCurve3DGetPeriod(OCCTCurve3DRef curve);

// Evaluation
void OCCTCurve3DGetPoint(OCCTCurve3DRef curve, double u, double* x, double* y, double* z);
void OCCTCurve3DD1(OCCTCurve3DRef curve,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        vx,
                   double*        vy,
                   double*        vz);
void OCCTCurve3DD2(OCCTCurve3DRef curve,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        pz,
                   double*        v1x,
                   double*        v1y,
                   double*        v1z,
                   double*        v2x,
                   double*        v2y,
                   double*        v2z);

// Primitive Curves
OCCTCurve3DRef OCCTCurve3DCreateLine(double px,
                                     double py,
                                     double pz,
                                     double dx,
                                     double dy,
                                     double dz);
OCCTCurve3DRef OCCTCurve3DCreateSegment(double p1x,
                                        double p1y,
                                        double p1z,
                                        double p2x,
                                        double p2y,
                                        double p2z);
OCCTCurve3DRef OCCTCurve3DCreateCircle(double cx,
                                       double cy,
                                       double cz,
                                       double nx,
                                       double ny,
                                       double nz,
                                       double radius);
OCCTCurve3DRef OCCTCurve3DCreateArcOfCircle(double p1x,
                                            double p1y,
                                            double p1z,
                                            double p2x,
                                            double p2y,
                                            double p2z,
                                            double p3x,
                                            double p3y,
                                            double p3z);
OCCTCurve3DRef OCCTCurve3DCreateEllipse(double cx,
                                        double cy,
                                        double cz,
                                        double nx,
                                        double ny,
                                        double nz,
                                        double majorR,
                                        double minorR);
OCCTCurve3DRef OCCTCurve3DCreateParabola(double cx,
                                         double cy,
                                         double cz,
                                         double nx,
                                         double ny,
                                         double nz,
                                         double focal);
OCCTCurve3DRef OCCTCurve3DCreateHyperbola(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double majorR,
                                          double minorR);

// BSpline / Bezier / Interpolation
OCCTCurve3DRef OCCTCurve3DCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  weights,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree);
OCCTCurve3DRef OCCTCurve3DCreateBezier(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights);
OCCTCurve3DRef OCCTCurve3DInterpolate(const double* points,
                                      int32_t       count,
                                      bool          closed,
                                      double        tolerance);
OCCTCurve3DRef OCCTCurve3DInterpolateWithTangents(const double* points,
                                                  int32_t       count,
                                                  double        stx,
                                                  double        sty,
                                                  double        stz,
                                                  double        etx,
                                                  double        ety,
                                                  double        etz,
                                                  double        tolerance);
OCCTCurve3DRef OCCTCurve3DFitPoints(const double* points,
                                    int32_t       count,
                                    int32_t       minDeg,
                                    int32_t       maxDeg,
                                    double        tolerance);

// BSpline queries
int32_t OCCTCurve3DGetPoleCount(OCCTCurve3DRef curve);
int32_t OCCTCurve3DGetPoles(OCCTCurve3DRef curve, double* outXYZ);
int32_t OCCTCurve3DGetDegree(OCCTCurve3DRef curve);

// Operations
OCCTCurve3DRef OCCTCurve3DTrim(OCCTCurve3DRef curve, double u1, double u2);
OCCTCurve3DRef OCCTCurve3DReversed(OCCTCurve3DRef curve);
OCCTCurve3DRef OCCTCurve3DTranslate(OCCTCurve3DRef curve, double dx, double dy, double dz);
OCCTCurve3DRef OCCTCurve3DRotate(OCCTCurve3DRef curve,
                                 double         axisOx,
                                 double         axisOy,
                                 double         axisOz,
                                 double         axisDx,
                                 double         axisDy,
                                 double         axisDz,
                                 double         angle);
OCCTCurve3DRef OCCTCurve3DScale(OCCTCurve3DRef curve,
                                double         cx,
                                double         cy,
                                double         cz,
                                double         factor);
OCCTCurve3DRef OCCTCurve3DMirrorPoint(OCCTCurve3DRef curve, double px, double py, double pz);
OCCTCurve3DRef OCCTCurve3DMirrorAxis(OCCTCurve3DRef curve,
                                     double         px,
                                     double         py,
                                     double         pz,
                                     double         dx,
                                     double         dy,
                                     double         dz);
OCCTCurve3DRef OCCTCurve3DMirrorPlane(OCCTCurve3DRef curve,
                                      double         px,
                                      double         py,
                                      double         pz,
                                      double         nx,
                                      double         ny,
                                      double         nz);
double         OCCTCurve3DGetLength(OCCTCurve3DRef curve);
double         OCCTCurve3DGetLengthBetween(OCCTCurve3DRef curve, double u1, double u2);

// Conversion (GeomConvert)
OCCTCurve3DRef OCCTCurve3DToBSpline(OCCTCurve3DRef curve);
int32_t        OCCTCurve3DBSplineToBeziers(OCCTCurve3DRef curve, OCCTCurve3DRef* out, int32_t max);
void           OCCTCurve3DFreeArray(OCCTCurve3DRef* curves, int32_t count);
/// Join curves[0..count) end-to-end into a single BSpline via
/// GeomConvert_CompCurveToBSplineCurve. Returns nullptr, rather than a partial join, if any
/// curve after the first is not G0-continuous with the accumulated curve within `tolerance`
/// (#1441).
OCCTCurve3DRef OCCTCurve3DJoinToBSpline(const OCCTCurve3DRef* curves,
                                        int32_t               count,
                                        double                tolerance);
/// Approximate a curve as a BSpline. Returns the fit whenever GeomConvert_ApproxCurve produced one
/// (HasResult), which per OCCT includes a best-effort fit outside `tolerance`, use
/// OCCTGeomConvertApproxCurve for the same fit plus its maxError/isDone. Both share one
/// implementation (#491).
OCCTCurve3DRef OCCTCurve3DApproximate(OCCTCurve3DRef curve,
                                      double         tolerance,
                                      int32_t        continuity,
                                      int32_t        maxSegments,
                                      int32_t        maxDegree);

// Draw Methods (discretization for Metal)
int32_t OCCTCurve3DDrawAdaptive(OCCTCurve3DRef curve,
                                double         angularDefl,
                                double         chordalDefl,
                                double*        outXYZ,
                                int32_t        maxPoints);
int32_t OCCTCurve3DDrawUniform(OCCTCurve3DRef curve, int32_t pointCount, double* outXYZ);
int32_t OCCTCurve3DDrawDeflection(OCCTCurve3DRef curve,
                                  double         deflection,
                                  double*        outXYZ,
                                  int32_t        maxPoints);

// Local Properties

/// Get curvature at parameter u. Returns true if the curvature exists there: false for a null
/// curve, a parameter that cannot be evaluated, and a point where IsTangentDefined() is false --
/// which used to be spelled 0, indistinguishable from a straight curve's real answer (#595).
/// A cusp reports true with OCCT's RealLast() infinity sentinel, which is an answer, not an
/// absence.
bool OCCTCurve3DGetCurvature(OCCTCurve3DRef curve, double u, double* _Nonnull curvature);
bool OCCTCurve3DGetTangent(OCCTCurve3DRef curve, double u, double* tx, double* ty, double* tz);
bool OCCTCurve3DGetNormal(OCCTCurve3DRef curve, double u, double* nx, double* ny, double* nz);
bool OCCTCurve3DGetCenterOfCurvature(OCCTCurve3DRef curve,
                                     double         u,
                                     double*        cx,
                                     double*        cy,
                                     double*        cz);

/// Get torsion at parameter u, the rate the curve twists out of its osculating plane. Returns true
/// if the torsion exists there: false for a null curve, a parameter that cannot be evaluated, and a
/// point with no osculating plane to twist out of (|d1 x d2| under the gate, e.g. a straight
/// stretch). That last case used to be spelled 0, which is also every planar curve's real torsion,
/// so a circle and a line were indistinguishable (#595).
bool OCCTCurve3DGetTorsion(OCCTCurve3DRef curve, double u, double* _Nonnull torsion);

// Bounding Box
bool OCCTCurve3DGetBoundingBox(OCCTCurve3DRef curve,
                               double*        xMin,
                               double*        yMin,
                               double*        zMin,
                               double*        xMax,
                               double*        yMax,
                               double*        zMax);

// MARK: - Batch Curve3D Evaluation (v0.29.0)

// These six functions (OCCTCurve3DEvaluateGrid/D1, OCCTCurve2DEvaluateGrid/D1 above, and
// OCCTSurfaceEvaluateGrid/D1 below) are the *whole* batch grid-evaluation family. Extend
// this family; do not start a seventh spelling of the same job. Three generations of duplicates
// (v0.110's OCCTCurve3DEvalBatchD0/D1 + OCCTCurve2DEvalBatchD0/D1, v0.111's OCCTGridEvalCurveD0/D1
// + OCCTGridEvalCurve2dD0/D1 + OCCTGridEvalSurfaceD0/D1) were removed in #486 after the two
// Surface spellings were found writing opposite UV layouts. The family contract:
//
//   - one OCCT batch evaluator per job (GeomGridEval_Curve, Geom2dGridEval_Curve,
//     GeomGridEval_Surface), never a hand-rolled per-point loop;
//   - output buffers are interleaved coordinates, not per-axis planes;
//   - surface grids are U-major: index (iu, iv) sits at occtSurfaceGridIndex(iu, iv, vCount),
//     matching OCCTSurfaceDrawMesh and the Swift SurfaceGrid type (#404);
//   - the return value is the number of points written, 0 on failure, so a caller can tell a
//     failed evaluation from a grid of zeroes.

/// Evaluate a 3D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXYZ Output buffer for xyz triples, interleaved: outXYZ[i * 3 + {0,1,2}]
///               (must hold 3 * paramCount doubles)
/// @return Number of points evaluated (paramCount on success, 0 on failure)
int32_t OCCTCurve3DEvaluateGrid(OCCTCurve3DRef curve,
                                const double*  params,
                                int32_t        paramCount,
                                double*        outXYZ);

/// Evaluate a 3D curve and its first derivative at multiple parameters (batch).
/// @param outXYZ Output buffer for point xyz triples, interleaved (3 * paramCount doubles)
/// @param outDXDYDZ Output buffer for derivative xyz triples, interleaved (3 * paramCount doubles)
/// @return Number of points evaluated (paramCount on success, 0 on failure)
int32_t OCCTCurve3DEvaluateGridD1(OCCTCurve3DRef curve,
                                  const double*  params,
                                  int32_t        paramCount,
                                  double*        outXYZ,
                                  double*        outDXDYDZ);

// MARK: - Curve Planarity Check (v0.29.0)

/// Check if a 3D curve is planar.
/// @param curve The curve to check
/// @param tolerance Planarity tolerance
/// @param outNX, outNY, outNZ Output: normal of the plane (if planar)
/// @return true if the curve is planar
bool OCCTCurve3DIsPlanar(OCCTCurve3DRef curve,
                         double         tolerance,
                         double*        outNX,
                         double*        outNY,
                         double*        outNZ);

// MARK: - Curve-Curve Extrema (v0.30.0)

/// Result structure for curve-curve extrema computation.
typedef struct
{
  double distance;  ///< Distance between closest points
  double point1[3]; ///< Closest point on curve 1 (x, y, z)
  double point2[3]; ///< Closest point on curve 2 (x, y, z)
  double param1;    ///< Parameter on curve 1
  double param2;    ///< Parameter on curve 2
} OCCTCurveExtrema;

/// Compute the minimum distance between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @return Minimum distance, or -1.0 on failure
double OCCTCurve3DMinDistanceToCurve(OCCTCurve3DRef c1, OCCTCurve3DRef c2);

/// Compute all extrema (closest/farthest point pairs) between two 3D curves.
/// @param c1 First curve
/// @param c2 Second curve
/// @param outExtrema Output buffer for extrema results
/// @param maxCount Maximum number of results to write
/// @return Number of extrema found, or 0 on failure
int32_t OCCTCurve3DExtrema(OCCTCurve3DRef    c1,
                           OCCTCurve3DRef    c2,
                           OCCTCurveExtrema* outExtrema,
                           int32_t           maxCount);

// MARK: - Quasi-Uniform Curve Sampling (v0.31.0)

/// Sample curve parameters using quasi-uniform abscissa distribution.
/// @param curve The curve to sample
/// @param nbPoints Desired number of sample points; must be >= 2, else 0 is returned
/// @param outParams Output array for parameter values (must hold nbPoints doubles)
/// @return Actual number of parameters written, never more than nbPoints, or 0 on failure.
///         GCPnts can compute one or more points beyond the request; the surplus is dropped, but
///         the last slot still gets the curve's last parameter so the result spans the curve
///         (#501).
int32_t OCCTCurve3DQuasiUniformAbscissa(OCCTCurve3DRef curve, int32_t nbPoints, double* outParams);

// MARK: - Quasi-Uniform Deflection Sampling (v0.31.0)

/// Sample curve points using quasi-uniform deflection distribution.
/// @param curve The curve to sample
/// @param deflection Maximum deflection tolerance
/// @param outXYZ Output array for point coordinates (x,y,z triples; must hold maxPoints*3 doubles)
/// @param maxPoints Maximum number of points to return
/// @return Actual number of points written, or 0 on failure
int32_t OCCTCurve3DQuasiUniformDeflection(OCCTCurve3DRef curve,
                                          double         deflection,
                                          double*        outXYZ,
                                          int32_t        maxPoints);

/// Create a 3D elliptical arc from angles
/// @param centerX..centerZ Center of the ellipse
/// @param normalX..normalZ Normal direction of the ellipse plane
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @param angle1, angle2 Start and end angles (radians)
/// @param sense true=counterclockwise
/// @return Curve3D handle, or NULL on failure
OCCTCurve3DRef OCCTCurve3DArcOfEllipse(double centerX,
                                       double centerY,
                                       double centerZ,
                                       double normalX,
                                       double normalY,
                                       double normalZ,
                                       double majorRadius,
                                       double minorRadius,
                                       double angle1,
                                       double angle2,
                                       bool   sense);

/// Create a 3D elliptical arc between two points on the ellipse
/// @return Curve3D handle, or NULL on failure
OCCTCurve3DRef OCCTCurve3DArcOfEllipsePoints(double centerX,
                                             double centerY,
                                             double centerZ,
                                             double normalX,
                                             double normalY,
                                             double normalZ,
                                             double majorRadius,
                                             double minorRadius,
                                             double p1X,
                                             double p1Y,
                                             double p1Z,
                                             double p2X,
                                             double p2Y,
                                             double p2Z,
                                             bool   sense);

// --- Approx_Curve3d: Curve approximation to BSpline ---

/// Approximate an edge's curve as a BSpline curve.
/// @param edge Edge whose curve to approximate
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum number of BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @return New Curve3D handle (BSpline), or NULL on failure
OCCTCurve3DRef OCCTEdgeApproxCurve(OCCTEdgeRef edge,
                                   double      tolerance,
                                   int32_t     maxSegments,
                                   int32_t     maxDegree);

/// Get the approximation error of the last edge curve approximation.
/// @param edge Edge whose curve was approximated
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum number of BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @param outMaxError Output: maximum approximation error
/// @param outDegree Output: BSpline degree
/// @param outNbPoles Output: number of BSpline poles (control points)
/// @return true if approximation succeeded
bool OCCTEdgeApproxCurveInfo(OCCTEdgeRef edge,
                             double      tolerance,
                             int32_t     maxSegments,
                             int32_t     maxDegree,
                             double*     outMaxError,
                             int32_t*    outDegree,
                             int32_t*    outNbPoles);

// --- GeomConvert_CompCurveToBSplineCurve ---

/// Join multiple curves into a single BSpline curve.
/// @param curves Array of curve handles to join (in order)
/// @param count Number of curves
/// @param tolerance Tolerance for joining (gap between endpoints)
/// @return Joined BSpline curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DJoinCurves(const OCCTCurve3DRef* curves,
                                               int32_t               count,
                                               double                tolerance);

// --- ShapeAnalysis_Curve expansion ---

/// Curve point projection result
typedef struct
{
  double distance;            // Distance from original point to projection
  double parameter;           // Parameter on curve at closest point, always within its domain
  double projX, projY, projZ; // Projected point coordinates
} OCCTCurveProjectResult;

/// Project a point onto a 3D curve, giving the closest point over the curve's own domain.
/// Where the point has no perpendicular foot on the curve, the closest point is one of its ends
/// (#539). Shares OCCTEdgeProjectPoint's implementation.
/// @param curve Curve to project onto
/// @param px,py,pz Point to project
/// @param precision Projection precision
/// @return Projection result with distance, parameter, and projected point
OCCTCurveProjectResult OCCTCurve3DProjectPoint(OCCTCurve3DRef curve,
                                               double         px,
                                               double         py,
                                               double         pz,
                                               double         precision);

/// Curve range validation result
typedef struct
{
  double first;       // Validated first parameter
  double last;        // Validated last parameter
  bool   wasAdjusted; // True if the range was adjusted
} OCCTCurveValidateRangeResult;

/// Validate and optionally adjust a curve parameter range.
/// @param curve Curve to validate against
/// @param first Desired first parameter
/// @param last Desired last parameter
/// @param precision Tolerance for validation
/// @return Validated range (adjusted if necessary)
OCCTCurveValidateRangeResult OCCTCurve3DValidateRange(OCCTCurve3DRef curve,
                                                      double         first,
                                                      double         last,
                                                      double         precision);

/// Get sample points along a 3D curve.
/// @param curve Curve to sample
/// @param first Start parameter
/// @param last End parameter
/// @param outXYZ Output buffer (must hold maxPoints * 3 doubles)
/// @param maxPoints Maximum number of points to return
/// @return Actual number of points written to outXYZ
int32_t OCCTCurve3DGetSamplePoints3D(OCCTCurve3DRef curve,
                                     double         first,
                                     double         last,
                                     double*        outXYZ,
                                     int32_t        maxPoints);

// MARK: - v0.50.0: GC_Make* geometry construction, BRepExtrema_Poly, BRepTools_History,
// GeomConvert knot splitting + CompBezier, ShapeAnalysis WireVertex + NearestPlane,
// ShapeCustom Curve/Surface, ShapeUpgrade SplitCurve3d/SplitSurfaceContinuity

/// Create an arc of hyperbola between two parameter values.
/// @param majorRadius Major radius (a) of the hyperbola
/// @param minorRadius Minor radius (b) of the hyperbola
/// @param axisX,axisY,axisZ Center of the hyperbola
/// @param dirX,dirY,dirZ Normal direction of the plane
/// @param alpha1 Start parameter
/// @param alpha2 End parameter
/// @param sense Direction of parameterization (true = natural)
/// @return Trimmed curve handle, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DArcOfHyperbola(double majorRadius,
                                                   double minorRadius,
                                                   double axisX,
                                                   double axisY,
                                                   double axisZ,
                                                   double dirX,
                                                   double dirY,
                                                   double dirZ,
                                                   double alpha1,
                                                   double alpha2,
                                                   bool   sense);

/// Create an arc of parabola between two parameter values.
/// @param focalDistance Focal distance of the parabola
/// @param axisX,axisY,axisZ Center of the parabola
/// @param dirX,dirY,dirZ Normal direction of the plane
/// @param alpha1 Start parameter
/// @param alpha2 End parameter
/// @param sense Direction of parameterization (true = natural)
/// @return Trimmed curve handle, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DArcOfParabola(double focalDistance,
                                                  double axisX,
                                                  double axisY,
                                                  double axisZ,
                                                  double dirX,
                                                  double dirY,
                                                  double dirZ,
                                                  double alpha1,
                                                  double alpha2,
                                                  bool   sense);

/// Convert a closed BSpline curve to periodic form.
/// @param curve Closed BSpline curve
/// @return Periodic curve, or NULL if conversion fails
OCCTCurve3DRef _Nullable OCCTCurve3DConvertToPeriodic(OCCTCurve3DRef curve);

/// Split a 3D curve at a specified parameter value.
/// @param curve Curve to split
/// @param splitParam Parameter at which to split
/// @param outCurve1 First segment (before split point)
/// @param outCurve2 Second segment (after split point)
/// @return True if split succeeded
bool OCCTCurve3DSplitAt(OCCTCurve3DRef curve,
                        double         splitParam,
                        OCCTCurve3DRef _Nullable* _Nonnull outCurve1,
                        OCCTCurve3DRef _Nullable* _Nonnull outCurve2);

// --- GC_MakeEllipse ---

/// Create a 3D ellipse curve from axis position and radii.
/// @param cx,cy,cz Center point
/// @param dx,dy,dz Normal direction (Z axis of the ellipse plane)
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @return Ellipse curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipse(double cx,
                                                double cy,
                                                double cz,
                                                double dx,
                                                double dy,
                                                double dz,
                                                double majorRadius,
                                                double minorRadius);

/// Create a 3D ellipse curve from three points.
/// @param s1x,s1y,s1z End of major axis
/// @param s2x,s2y,s2z Point defining minor axis
/// @param centerX,centerY,centerZ Center point
/// @return Ellipse curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeEllipseThreePoints(double s1x,
                                                           double s1y,
                                                           double s1z,
                                                           double s2x,
                                                           double s2y,
                                                           double s2z,
                                                           double centerX,
                                                           double centerY,
                                                           double centerZ);

// --- GC_MakeHyperbola ---

/// Create a 3D hyperbola curve from axis position and radii.
/// @param cx,cy,cz Center point
/// @param dx,dy,dz Normal direction
/// @param majorRadius Major radius
/// @param minorRadius Minor radius
/// @return Hyperbola curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbola(double cx,
                                                  double cy,
                                                  double cz,
                                                  double dx,
                                                  double dy,
                                                  double dz,
                                                  double majorRadius,
                                                  double minorRadius);

/// Create a 3D hyperbola curve from three points.
/// @param s1x,s1y,s1z End of major axis
/// @param s2x,s2y,s2z Point defining minor axis
/// @param centerX,centerY,centerZ Center point
/// @return Hyperbola curve, or NULL on failure
OCCTCurve3DRef _Nullable OCCTCurve3DMakeHyperbolaThreePoints(double s1x,
                                                             double s1y,
                                                             double s1z,
                                                             double s2x,
                                                             double s2y,
                                                             double s2z,
                                                             double centerX,
                                                             double centerY,
                                                             double centerZ);

// MARK: - Approx_CurveOnSurface (v0.61.0)

/// Approximate a 2D curve on a surface as a 3D BSpline curve.
/// Uses the edge's PCurve on the face.
/// @param edge Edge with PCurve
/// @param face Face with surface
/// @param tolerance Approximation tolerance
/// @param maxSegments Maximum BSpline segments
/// @param maxDegree Maximum BSpline degree
/// @return Approximated 3D shape (edge), or NULL on failure
OCCTShapeRef OCCTApproxCurveOnSurface(OCCTShapeRef edge,
                                      OCCTShapeRef face,
                                      double       tolerance,
                                      int32_t      maxSegments,
                                      int32_t      maxDegree);

// --- CPnts_UniformDeflection ---

/// Discretize an edge curve by uniform deflection.
/// @param shape Edge shape to discretize
/// @param deflection Maximum chordal deflection
/// @param outParams Output array of parameter values, caller must free with free()
/// @param outPoints Output array of (x,y,z) triples, caller must free with free()
/// @param outCount Number of points generated
/// @return true on success
bool OCCTCPntsUniformDeflection(OCCTShapeRef shape,
                                double       deflection,
                                double* _Nullable* _Nonnull outParams,
                                double* _Nullable* _Nonnull outPoints,
                                int32_t* outCount);

/// Discretize an edge curve by uniform deflection within a parameter range.
bool OCCTCPntsUniformDeflectionRange(OCCTShapeRef shape,
                                     double       deflection,
                                     double       u1,
                                     double       u2,
                                     double* _Nullable* _Nonnull outParams,
                                     double* _Nullable* _Nonnull outPoints,
                                     int32_t* outCount);

// --- Approx_CurvilinearParameter ---
// Reparameterize an edge curve by arc length → BSpline
OCCTShapeRef _Nullable OCCTApproxCurvilinearParameter(OCCTShapeRef edgeShape,
                                                      double       tolerance,
                                                      int          maxDegree,
                                                      int          maxSegments);

// --- LocalAnalysis_CurveContinuity ---

/// Analyze local continuity between two 3D curves at given parameters.
/// Uses BSpline curves extracted from edges via Curve3D handles.
/// @param curve1 First curve
/// @param u1 Parameter on first curve
/// @param curve2 Second curve
/// @param u2 Parameter on second curve
/// @param order Analysis order, see "Continuity vocabularies" at the top of this header.
///   Selects which predicates get computed, so it is not merely a strictness ceiling: an order
///   the caller does not ask for is never measured (#495).
/// @param outStatus Output: the *effective* analysis order, i.e. `order` after saturation.
///   `LocalAnalysis_*::ContinuityStatus()` returns the order it was constructed with verbatim,
///   so this is the request echoed back and never a measurement, the measurement is the flags
///   bitmask below.
/// @param outC0Value Output: C0 distance
/// @param outG1Angle Output: G1 angle (radians), or -1 if not measured at this order or not met
/// @param outC1Angle Output: C1 angle, or -1
/// @param outC1Ratio Output: C1 ratio, or -1
/// @param outC2Angle Output: C2 angle, or -1
/// @param outC2Ratio Output: C2 ratio, or -1
/// @param outG2Angle Output: G2 angle, or -1
/// @param outG2CurvatureVariation Output: G2 curvature variation, or -1
/// @return true if analysis succeeded
bool OCCTLocalAnalysisCurveContinuity(OCCTCurve3DRef _Nonnull curve1,
                                      double u1,
                                      OCCTCurve3DRef _Nonnull curve2,
                                      double  u2,
                                      int32_t order,
                                      int32_t* _Nonnull outStatus,
                                      double* _Nonnull outC0Value,
                                      double* _Nonnull outG1Angle,
                                      double* _Nonnull outC1Angle,
                                      double* _Nonnull outC1Ratio,
                                      double* _Nonnull outC2Angle,
                                      double* _Nonnull outC2Ratio,
                                      double* _Nonnull outG2Angle,
                                      double* _Nonnull outG2CurvatureVariation);

/// Check boolean continuity flags for curve continuity analysis.
/// @param outMeasured Output: bitmask of the classes this order actually measured. Only the
///   requested order's branch is computed; an unmeasured predicate reads a zero-initialised
///   member and answers true regardless of the geometry, so the returned flags are masked to
///   this set and a caller must consult it to tell "false" from "never asked" (#495).
/// @return Bitmask: bit 0=IsC0, bit 1=IsG1, bit 2=IsC1, bit 3=IsG2, bit 4=IsC2, masked to
///   `outMeasured`
int32_t OCCTLocalAnalysisCurveContinuityFlags(OCCTCurve3DRef _Nonnull curve1,
                                              double u1,
                                              OCCTCurve3DRef _Nonnull curve2,
                                              double  u2,
                                              int32_t order,
                                              int32_t* _Nonnull outMeasured);

// MARK: - GeomConvert_ApproxCurve

/// Approximate a curve as BSpline.
typedef struct
{
  OCCTCurve3DRef _Nullable curve; // result BSpline (as Curve3D)
  double maxError;
  bool   isDone;
  bool   hasResult;
} OCCTApproxCurveResult;

/// The same approximation OCCTCurve3DApproximate performs (one shared implementation since #491),
/// reporting the fit's maxError and completion flags. `curve` is populated exactly when
/// `hasResult`; `isDone` is whether the fit reached `tolerance`.
OCCTApproxCurveResult OCCTGeomConvertApproxCurve(OCCTCurve3DRef _Nonnull curve,
                                                 double  tolerance,
                                                 int32_t continuity,
                                                 int32_t maxSegments,
                                                 int32_t maxDegree);

// MARK: - GCPnts_QuasiUniformAbscissa

/// Compute quasi-uniform parameter distribution on an edge curve.
/// The Curve3D form of this is OCCTCurve3DQuasiUniformAbscissa (v0.31.0), not a second function
/// here. The one that used to be, OCCTGCPntsQuasiUniformCurve, was a never-called re-wrap (#501).
/// @param edge The edge to sample
/// @param nbPoints Desired number of sample points; must be >= 2, else 0 is returned
/// @param params Output array for parameter values (must hold maxParams doubles)
/// @param maxParams Capacity of params. The sampler can report more points than nbPoints, so this
///        is a real bound, not a formality; when it bites, the last slot still gets the edge's last
///        parameter so the distribution spans the whole edge.
/// @return Actual number of parameters written, or 0 on failure
int32_t OCCTGCPntsQuasiUniform(OCCTEdgeRef _Nonnull edge,
                               int32_t nbPoints,
                               double* _Nonnull params,
                               int32_t maxParams);

// MARK: - GCPnts_TangentialDeflection

/// Tangential deflection-based parameter/point sampling on an edge curve.
/// Returns point count, fills params and optionally coords (x,y,z triples).
int32_t OCCTGCPntsTangentialDeflection(OCCTEdgeRef _Nonnull edge,
                                       double  angularDeflection,
                                       double  curvatureDeflection,
                                       int32_t minPoints,
                                       double* _Nonnull params,
                                       double* _Nullable coords,
                                       int32_t maxPoints);

/// Tangential deflection sampling on a Curve3D.
int32_t OCCTGCPntsTangentialDeflectionCurve(OCCTCurve3DRef _Nonnull curve,
                                            double  angularDeflection,
                                            double  curvatureDeflection,
                                            int32_t minPoints,
                                            double* _Nonnull params,
                                            double* _Nullable coords,
                                            int32_t maxPoints);

OCCTGeomPoint3DRef _Nonnull OCCTGeomPoint3DCreate(double x, double y, double z);
void   OCCTGeomPoint3DRelease(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DX(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DY(OCCTGeomPoint3DRef _Nonnull ref);
double OCCTGeomPoint3DZ(OCCTGeomPoint3DRef _Nonnull ref);
void   OCCTGeomPoint3DSetCoord(OCCTGeomPoint3DRef _Nonnull ref, double x, double y, double z);
double OCCTGeomPoint3DDistance(OCCTGeomPoint3DRef _Nonnull ref, OCCTGeomPoint3DRef _Nonnull other);
double OCCTGeomPoint3DSquareDistance(OCCTGeomPoint3DRef _Nonnull ref,
                                     OCCTGeomPoint3DRef _Nonnull other);
void   OCCTGeomPoint3DTranslate(OCCTGeomPoint3DRef _Nonnull ref, double dx, double dy, double dz);

OCCTGeomDirectionRef _Nonnull OCCTGeomDirectionCreate(double x, double y, double z);
void OCCTGeomDirectionRelease(OCCTGeomDirectionRef _Nonnull ref);
void OCCTGeomDirectionCoords(OCCTGeomDirectionRef _Nonnull ref,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);
void OCCTGeomDirectionSetCoord(OCCTGeomDirectionRef _Nonnull ref, double x, double y, double z);
/// Cross product of two unit directions, returns new direction.
OCCTGeomDirectionRef _Nullable OCCTGeomDirectionCrossed(OCCTGeomDirectionRef _Nonnull ref,
                                                        OCCTGeomDirectionRef _Nonnull other);

OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCreate(double x, double y, double z);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DFromPoints(double x1,
                                                        double y1,
                                                        double z1,
                                                        double x2,
                                                        double y2,
                                                        double z2);
void   OCCTGeomVector3DRelease(OCCTGeomVector3DRef _Nonnull ref);
void   OCCTGeomVector3DCoords(OCCTGeomVector3DRef _Nonnull ref,
                              double* _Nonnull x,
                              double* _Nonnull y,
                              double* _Nonnull z);
double OCCTGeomVector3DMagnitude(OCCTGeomVector3DRef _Nonnull ref);
double OCCTGeomVector3DDot(OCCTGeomVector3DRef _Nonnull ref, OCCTGeomVector3DRef _Nonnull other);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DAdded(OCCTGeomVector3DRef _Nonnull ref,
                                                   OCCTGeomVector3DRef _Nonnull other);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DMultiplied(OCCTGeomVector3DRef _Nonnull ref,
                                                        double scalar);
OCCTGeomVector3DRef _Nullable OCCTGeomVector3DNormalized(OCCTGeomVector3DRef _Nonnull ref);
OCCTGeomVector3DRef _Nonnull OCCTGeomVector3DCrossed(OCCTGeomVector3DRef _Nonnull ref,
                                                     OCCTGeomVector3DRef _Nonnull other);

OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementCreate(double px,
                                                        double py,
                                                        double pz,
                                                        double dx,
                                                        double dy,
                                                        double dz);
void OCCTAxis1PlacementRelease(OCCTAxis1PlacementRef _Nonnull ref);
void OCCTAxis1PlacementLocation(OCCTAxis1PlacementRef _Nonnull ref,
                                double* _Nonnull x,
                                double* _Nonnull y,
                                double* _Nonnull z);
void OCCTAxis1PlacementDirection(OCCTAxis1PlacementRef _Nonnull ref,
                                 double* _Nonnull x,
                                 double* _Nonnull y,
                                 double* _Nonnull z);
void OCCTAxis1PlacementReverse(OCCTAxis1PlacementRef _Nonnull ref);
OCCTAxis1PlacementRef _Nonnull OCCTAxis1PlacementReversed(OCCTAxis1PlacementRef _Nonnull ref);
void OCCTAxis1PlacementSetDirection(OCCTAxis1PlacementRef _Nonnull ref,
                                    double dx,
                                    double dy,
                                    double dz);
void OCCTAxis1PlacementSetLocation(OCCTAxis1PlacementRef _Nonnull ref,
                                   double px,
                                   double py,
                                   double pz);

OCCTAxis2PlacementRef _Nonnull OCCTAxis2PlacementCreate(double px,
                                                        double py,
                                                        double pz,
                                                        double nx,
                                                        double ny,
                                                        double nz,
                                                        double vx,
                                                        double vy,
                                                        double vz);
void OCCTAxis2PlacementRelease(OCCTAxis2PlacementRef _Nonnull ref);
void OCCTAxis2PlacementLocation(OCCTAxis2PlacementRef _Nonnull ref,
                                double* _Nonnull x,
                                double* _Nonnull y,
                                double* _Nonnull z);
void OCCTAxis2PlacementDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                 double* _Nonnull x,
                                 double* _Nonnull y,
                                 double* _Nonnull z);
void OCCTAxis2PlacementXDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                  double* _Nonnull x,
                                  double* _Nonnull y,
                                  double* _Nonnull z);
void OCCTAxis2PlacementYDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                  double* _Nonnull x,
                                  double* _Nonnull y,
                                  double* _Nonnull z);
void OCCTAxis2PlacementSetDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                    double nx,
                                    double ny,
                                    double nz);
void OCCTAxis2PlacementSetXDirection(OCCTAxis2PlacementRef _Nonnull ref,
                                     double vx,
                                     double vy,
                                     double vz);

// MARK: - ShapeConstruct_Curve

/// Convert any 3D curve segment to BSpline.
OCCTCurve3DRef _Nullable OCCTShapeConstructConvertToBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                              double first,
                                                              double last,
                                                              double precision);
/// Adjust 3D curve endpoints to match given points.
bool OCCTShapeConstructAdjustCurve3D(OCCTCurve3DRef _Nonnull curve,
                                     double p1x,
                                     double p1y,
                                     double p1z,
                                     double p2x,
                                     double p2y,
                                     double p2z);

// MARK: - GeomLib_Tool (Parameter Finding)

/// Find parameter of 3D point on 3D curve. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParameter3D(OCCTCurve3DRef _Nonnull curve,
                                double px,
                                double py,
                                double pz,
                                double maxDist,
                                double* _Nonnull outParam);

// MARK: - GeomLib_CheckBSplineCurve / Check2dBSplineCurve

/// Check BSpline 3D curve for reversed end tangents. Returns true if check completed.
bool OCCTGeomLibCheckBSpline3D(OCCTCurve3DRef _Nonnull curve,
                               double tolerance,
                               double angularTol,
                               bool* _Nonnull needFixFirst,
                               bool* _Nonnull needFixLast);

/// Fix BSpline 3D curve end tangents, returns new curve or NULL if not needed.
OCCTCurve3DRef _Nullable OCCTGeomLibFixBSpline3D(OCCTCurve3DRef _Nonnull curve,
                                                 double tolerance,
                                                 double angularTol,
                                                 bool   fixFirst,
                                                 bool   fixLast);

// MARK: - GeomLib_Interpolate

/// Interpolate 3D points at given parameters to create BSpline curve.
/// degree: polynomial degree (typically 3). numPoints: count of points/params.
OCCTCurve3DRef _Nullable OCCTGeomLibInterpolate(int degree,
                                                int numPoints,
                                                const double* _Nonnull pointsXYZ,
                                                const double* _Nonnull parameters);

// MARK: - Approx_SameParameter

/// Check if 2D curve on surface has same parameterization as 3D curve.
/// Returns true if check completed. outIsSame is true if already same parameter.
/// outTolReached is the max distance between 3D curve and surface evaluation.
bool OCCTApproxSameParameter(OCCTCurve3DRef _Nonnull curve3d,
                             OCCTCurve2DRef _Nonnull curve2d,
                             OCCTSurfaceRef _Nonnull surface,
                             double tolerance,
                             bool* _Nonnull outIsSame,
                             double* _Nonnull outTolReached);

// MARK: - ShapeUpgrade_SplitCurve3dContinuity

/// Split 3D curve at continuity breaks. criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns number of resulting curve segments, or 0 on failure.
int OCCTSplitCurve3dContinuity(OCCTCurve3DRef _Nonnull curve,
                               int    criterion,
                               double tolerance,
                               OCCTCurve3DRef _Nullable* _Nullable outCurves,
                               int maxCurves);

// MARK: - GeomConvert_CurveToAnaCurve

/// Result struct for curve-to-analytical conversion.
typedef struct
{
  OCCTCurve3DRef _Nullable curve; ///< Owned by the caller; independent of the input curve
  double newFirst;                ///< Range start, in the RECOGNISED curve's parameterisation
  double newLast;                 ///< Range end, in the RECOGNISED curve's parameterisation
  double gap; ///< Max deviation from the input; exactly 0 when already analytical
  bool   success;
} OCCTCurveToAnaCurveResult;

/// Convert a curve to an analytical curve (line, circle, ellipse) over [first, last].
///
/// The sole entry point for GeomConvert_CurveToAnaCurve; the v0.30.0 OCCTCurve3DToAnalytical, which
/// hardcoded the curve's own range and dropped newFirst/newLast/gap, was retired into it (#492).
/// An already-analytical input succeeds with gap 0 rather than being rejected, and the returned
/// curve never aliases the input.
OCCTCurveToAnaCurveResult OCCTGeomConvertCurveToAnalytical(OCCTCurve3DRef _Nonnull curveRef,
                                                           double tolerance,
                                                           double first,
                                                           double last);

/// Check if an array of points is linear within tolerance.
bool OCCTGeomConvertIsLinear(const double* _Nonnull points,
                             int    count,
                             double tolerance,
                             double* _Nullable deviation);

// MARK: - v0.80.0: Extrema 3D/2D, GeomTools persistence, ProjLib, gce_* factories

// --- Extrema_ExtCC: Curve-Curve distance ---
typedef struct
{
  bool isDone;
  bool isParallel;
  int  nbExt;
} OCCTExtremaExtCCResult;

/// Compute curve-to-curve extrema
OCCTExtremaExtCCResult OCCTExtremaExtCC(OCCTCurve3DRef _Nonnull curve1,
                                        double u1First,
                                        double u1Last,
                                        OCCTCurve3DRef _Nonnull curve2,
                                        double u2First,
                                        double u2Last);

/// Get Nth extremum from curve-curve computation (1-based index)
OCCTExtremaPointPair OCCTExtremaExtCCPoint(OCCTCurve3DRef _Nonnull curve1,
                                           double u1First,
                                           double u1Last,
                                           OCCTCurve3DRef _Nonnull curve2,
                                           double u2First,
                                           double u2Last,
                                           int    index);

// --- Extrema_ExtCS: Curve-Surface distance ---
typedef struct
{
  bool isDone;
  bool isParallel;
  int  nbExt;
} OCCTExtremaExtCSResult;

/// Compute curve-to-surface extrema
OCCTExtremaExtCSResult OCCTExtremaExtCS(OCCTCurve3DRef _Nonnull curve,
                                        double uFirst,
                                        double uLast,
                                        OCCTSurfaceRef _Nonnull surface);

/// Get Nth extremum from curve-surface computation
OCCTExtremaPointPair OCCTExtremaExtCSPoint(OCCTCurve3DRef _Nonnull curve,
                                           double uFirst,
                                           double uLast,
                                           OCCTSurfaceRef _Nonnull surface,
                                           int index);

// --- Extrema_LocateExtCC: Local curve-curve distance ---
typedef struct
{
  bool   isDone;
  double squareDistance;
  double x1, y1, z1, param1;
  double x2, y2, z2, param2;
} OCCTExtremaLocateExtCCResult;

/// Find local curve-curve extremum near seed parameters
OCCTExtremaLocateExtCCResult OCCTExtremaLocateExtCC(OCCTCurve3DRef _Nonnull curve1,
                                                    double u1First,
                                                    double u1Last,
                                                    OCCTCurve3DRef _Nonnull curve2,
                                                    double u2First,
                                                    double u2Last,
                                                    double seedU,
                                                    double seedV);

// --- gce_MakeCirc: Circle from 3 points ---
/// Create a 3D circle through 3 points (returns Geom_Circle)
OCCTCurve3DRef _Nullable OCCTGceMakeCircFrom3Points(double p1x,
                                                    double p1y,
                                                    double p1z,
                                                    double p2x,
                                                    double p2y,
                                                    double p2z,
                                                    double p3x,
                                                    double p3y,
                                                    double p3z);

/// Create a 3D circle from center + normal + radius
OCCTCurve3DRef _Nullable OCCTGceMakeCircFromCenterNormal(double cx,
                                                         double cy,
                                                         double cz,
                                                         double nx,
                                                         double ny,
                                                         double nz,
                                                         double radius);

// --- gce_MakeCone / gce_MakeCylinder ---
// Note (#420): conical/cylindrical surface-from-points construction is unified
// on OCCTSurfaceConicalFromPointsRadii / OCCTSurfaceCylindricalFromPoints
// (GC_MakeConicalSurface / GC_MakeCylindricalSurface, which return the
// Handle(Geom_*) directly). The gce_MakeCone / gce_MakeCylinder-backed bridge
// functions that previously duplicated this path were removed; the Swift
// `Surface.coneFrom2PointsRadii`/`cylinderFrom3Points` entry points now call
// through to `conicalSurface`/`cylindricalSurface`.

// --- gce_MakeLin ---
/// Create a line from 2 points
OCCTCurve3DRef _Nullable OCCTGceMakeLinFrom2Points(double p1x,
                                                   double p1y,
                                                   double p1z,
                                                   double p2x,
                                                   double p2y,
                                                   double p2z);

// --- gce_MakeDir ---
/// Create a direction from 2 points (P1→P2)
bool OCCTGceMakeDir(double p1x,
                    double p1y,
                    double p1z,
                    double p2x,
                    double p2y,
                    double p2z,
                    double* _Nonnull outX,
                    double* _Nonnull outY,
                    double* _Nonnull outZ);

// --- gce_MakeElips ---
/// Create an ellipse from center, normal, major axis direction, and radii
OCCTCurve3DRef _Nullable OCCTGceMakeElips(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double majorRadius,
                                          double minorRadius);

// --- gce_MakeHypr ---
/// Create a hyperbola from center, normal, and radii
OCCTCurve3DRef _Nullable OCCTGceMakeHypr(double cx,
                                         double cy,
                                         double cz,
                                         double nx,
                                         double ny,
                                         double nz,
                                         double majorRadius,
                                         double minorRadius);

// --- gce_MakeParab ---
/// Create a parabola from center, normal, and focal length
OCCTCurve3DRef _Nullable OCCTGceMakeParab(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double focal);

/// Create an identity transformation
OCCTGeomTransformRef _Nullable OCCTGeomTransformCreate(void);

/// Release a Geom_Transformation
void OCCTGeomTransformRelease(OCCTGeomTransformRef _Nonnull transform);

/// Set translation by vector
void OCCTGeomTransformSetTranslation(OCCTGeomTransformRef _Nonnull transform,
                                     double dx,
                                     double dy,
                                     double dz);

/// Set rotation about an axis
void OCCTGeomTransformSetRotation(OCCTGeomTransformRef _Nonnull transform,
                                  double originX,
                                  double originY,
                                  double originZ,
                                  double dirX,
                                  double dirY,
                                  double dirZ,
                                  double angleRadians);

/// Set scale about a point
void OCCTGeomTransformSetScale(OCCTGeomTransformRef _Nonnull transform,
                               double centerX,
                               double centerY,
                               double centerZ,
                               double scaleFactor);

/// Set point mirror
void OCCTGeomTransformSetMirrorPoint(OCCTGeomTransformRef _Nonnull transform,
                                     double x,
                                     double y,
                                     double z);

/// Set axis mirror
void OCCTGeomTransformSetMirrorAxis(OCCTGeomTransformRef _Nonnull transform,
                                    double originX,
                                    double originY,
                                    double originZ,
                                    double dirX,
                                    double dirY,
                                    double dirZ);

/// Get scale factor
double OCCTGeomTransformScaleFactor(OCCTGeomTransformRef _Nonnull transform);

/// Check if negative (reflection)
bool OCCTGeomTransformIsNegative(OCCTGeomTransformRef _Nonnull transform);

/// Transform a point (in-place)
void OCCTGeomTransformApply(OCCTGeomTransformRef _Nonnull transform,
                            double* _Nonnull x,
                            double* _Nonnull y,
                            double* _Nonnull z);

/// Get matrix value (row 1-3, col 1-4)
double OCCTGeomTransformValue(OCCTGeomTransformRef _Nonnull transform, int row, int col);

/// Multiply two transformations, return new
OCCTGeomTransformRef _Nullable OCCTGeomTransformMultiplied(OCCTGeomTransformRef _Nonnull t1,
                                                           OCCTGeomTransformRef _Nonnull t2);

/// Invert a transformation, return new
OCCTGeomTransformRef _Nullable OCCTGeomTransformInverted(OCCTGeomTransformRef _Nonnull transform);

// MARK: - Geom_OffsetCurve

/// Create an offset curve from a Curve3D handle
OCCTCurve3DRef _Nullable OCCTCurve3DCreateOffset(OCCTCurve3DRef _Nonnull basisCurve,
                                                 double offset,
                                                 double dirX,
                                                 double dirY,
                                                 double dirZ);

/// Get offset value from an offset curve
double OCCTCurve3DOffsetValue(OCCTCurve3DRef _Nonnull curve);

/// Get offset direction from an offset curve
bool OCCTCurve3DOffsetDirection(OCCTCurve3DRef _Nonnull curve,
                                double* _Nonnull dirX,
                                double* _Nonnull dirY,
                                double* _Nonnull dirZ);

// MARK: - ElCLib. Elementary Curve Library (v0.91.0)

/// Evaluate point on a line at parameter u. Line defined by origin + direction.
void OCCTElCLibValueOnLine(double u,
                           double ox,
                           double oy,
                           double oz,
                           double dx,
                           double dy,
                           double dz,
                           double* _Nonnull outX,
                           double* _Nonnull outY,
                           double* _Nonnull outZ);

/// Evaluate point on a circle at parameter u. Circle defined by axis + radius.
void OCCTElCLibValueOnCircle(double u,
                             double cx,
                             double cy,
                             double cz,
                             double nx,
                             double ny,
                             double nz,
                             double radius,
                             double* _Nonnull outX,
                             double* _Nonnull outY,
                             double* _Nonnull outZ);

/// Evaluate point on an ellipse at parameter u.
void OCCTElCLibValueOnEllipse(double u,
                              double cx,
                              double cy,
                              double cz,
                              double nx,
                              double ny,
                              double nz,
                              double majorRadius,
                              double minorRadius,
                              double* _Nonnull outX,
                              double* _Nonnull outY,
                              double* _Nonnull outZ);

/// Evaluate point + tangent on a line at parameter u.
void OCCTElCLibD1OnLine(double u,
                        double ox,
                        double oy,
                        double oz,
                        double dx,
                        double dy,
                        double dz,
                        double* _Nonnull outPX,
                        double* _Nonnull outPY,
                        double* _Nonnull outPZ,
                        double* _Nonnull outVX,
                        double* _Nonnull outVY,
                        double* _Nonnull outVZ);

/// Evaluate point + tangent on a circle at parameter u.
void OCCTElCLibD1OnCircle(double u,
                          double cx,
                          double cy,
                          double cz,
                          double nx,
                          double ny,
                          double nz,
                          double radius,
                          double* _Nonnull outPX,
                          double* _Nonnull outPY,
                          double* _Nonnull outPZ,
                          double* _Nonnull outVX,
                          double* _Nonnull outVY,
                          double* _Nonnull outVZ);

/// Get parameter of nearest point on line.
double OCCTElCLibParameterOnLine(double ox,
                                 double oy,
                                 double oz,
                                 double dx,
                                 double dy,
                                 double dz,
                                 double px,
                                 double py,
                                 double pz);

/// Get parameter of nearest point on circle.
double OCCTElCLibParameterOnCircle(double cx,
                                   double cy,
                                   double cz,
                                   double nx,
                                   double ny,
                                   double nz,
                                   double radius,
                                   double px,
                                   double py,
                                   double pz);

/// Normalize parameter to periodic range [uFirst, uLast).
double OCCTElCLibInPeriod(double u, double uFirst, double uLast);

/// Create a quaternion from components (x, y, z, w).
OCCTQuaternionRef _Nonnull OCCTQuaternionCreate(double x, double y, double z, double w);

/// Create a quaternion from axis-angle rotation.
OCCTQuaternionRef _Nonnull OCCTQuaternionCreateFromAxisAngle(double ax,
                                                             double ay,
                                                             double az,
                                                             double angle);

/// Create a quaternion from two vectors (shortest arc rotation).
OCCTQuaternionRef _Nonnull OCCTQuaternionCreateFromVectors(double fromX,
                                                           double fromY,
                                                           double fromZ,
                                                           double toX,
                                                           double toY,
                                                           double toZ);

/// Release a quaternion.
void OCCTQuaternionRelease(OCCTQuaternionRef _Nonnull q);

/// Get quaternion components.
void OCCTQuaternionGetComponents(OCCTQuaternionRef _Nonnull q,
                                 double* _Nonnull x,
                                 double* _Nonnull y,
                                 double* _Nonnull z,
                                 double* _Nonnull w);

/// Set Euler angles on a quaternion. Order: 0=Intrinsic_XYZ, etc.
void OCCTQuaternionSetEulerAngles(OCCTQuaternionRef _Nonnull q,
                                  int32_t order,
                                  double  alpha,
                                  double  beta,
                                  double  gamma);

/// Get Euler angles from a quaternion.
void OCCTQuaternionGetEulerAngles(OCCTQuaternionRef _Nonnull q,
                                  int32_t order,
                                  double* _Nonnull alpha,
                                  double* _Nonnull beta,
                                  double* _Nonnull gamma);

/// Get rotation matrix as 9 doubles (row-major).
void OCCTQuaternionGetMatrix(OCCTQuaternionRef _Nonnull q, double* _Nonnull matrix9);

/// Rotate a vector by the quaternion.
void OCCTQuaternionMultiplyVec(OCCTQuaternionRef _Nonnull q,
                               double vx,
                               double vy,
                               double vz,
                               double* _Nonnull outX,
                               double* _Nonnull outY,
                               double* _Nonnull outZ);

/// Multiply two quaternions (Hamilton product). Returns new quaternion.
OCCTQuaternionRef _Nonnull OCCTQuaternionMultiply(OCCTQuaternionRef _Nonnull q1,
                                                  OCCTQuaternionRef _Nonnull q2);

/// Get axis-angle representation.
void OCCTQuaternionGetVectorAndAngle(OCCTQuaternionRef _Nonnull q,
                                     double* _Nonnull ax,
                                     double* _Nonnull ay,
                                     double* _Nonnull az,
                                     double* _Nonnull angle);

/// Get the rotation angle.
double OCCTQuaternionGetRotationAngle(OCCTQuaternionRef _Nonnull q);

/// Normalize the quaternion to unit length.
void OCCTQuaternionNormalize(OCCTQuaternionRef _Nonnull q);

// MARK: - Convert_CompBezierCurvesToBSplineCurve (v0.99.0)

/// Result structure for composite Bezier → BSpline 3D curve conversion.
typedef struct
{
  int32_t degree;
  int32_t nbPoles;
  int32_t nbKnots;
  double  poles[300]; ///< Up to 100 3D poles (x,y,z interleaved)
  double  knots[50];
  int32_t mults[50];
} OCCTBezierBSplineResult;

/// Convert N composite Bezier segments (3D) to a single BSpline curve.
/// @param poles Flattened array of [x,y,z] control points; length = segCount * ptsPerSeg * 3
/// @param segCount Number of Bezier segments
/// @param ptsPerSeg Number of control points per segment (degree+1)
/// @param out Result filled on success
/// @return true on success; false if segCount/ptsPerSeg are invalid, the underlying conversion
///         throws, or the composite curve needs more poles/knots than `out`'s fixed capacity
///         (100 poles, 50 knots) can hold (#1441).
bool OCCTConvertCompBezierToBSpline(const double* _Nonnull poles,
                                    int32_t segCount,
                                    int32_t ptsPerSeg,
                                    OCCTBezierBSplineResult* _Nonnull out);

/// Result structure for composite Bezier → BSpline 2D curve conversion.
typedef struct
{
  int32_t degree;
  int32_t nbPoles;
  int32_t nbKnots;
  double  poles[200]; ///< Up to 100 2D poles (x,y interleaved)
  double  knots[50];
  int32_t mults[50];
} OCCTBezierBSpline2dResult;

/// Convert N composite Bezier segments (2D) to a single BSpline curve.
/// @param poles Flattened array of [x,y] control points; length = segCount * ptsPerSeg * 2
/// @param segCount Number of Bezier segments
/// @param ptsPerSeg Number of control points per segment (degree+1)
/// @param out Result filled on success
/// @return true on success; false if segCount/ptsPerSeg are invalid, the underlying conversion
///         throws, or the composite curve needs more poles/knots than `out`'s fixed capacity
///         (100 poles, 50 knots) can hold (#1441).
bool OCCTConvertCompBezier2dToBSpline2d(const double* _Nonnull poles,
                                        int32_t segCount,
                                        int32_t ptsPerSeg,
                                        OCCTBezierBSpline2dResult* _Nonnull out);

// --- ShapeAnalysis_Curve static methods ---

/// Check if a 3D curve is closed within the given precision.
/// Uses ShapeAnalysis_Curve::IsClosed (static).
bool OCCTCurve3DIsClosedWithPreci(OCCTCurve3DRef _Nonnull curve, double preci);

/// Check if a 3D curve is periodic.
/// Uses ShapeAnalysis_Curve::IsPeriodic (static).
bool OCCTCurve3DIsPeriodicSA(OCCTCurve3DRef _Nonnull curve);

// --- Geom_OffsetCurve basis curve ---

/// Get the basis curve of an offset curve.
/// @return Basis curve, or NULL if not an offset curve
OCCTCurve3DRef _Nullable OCCTCurve3DOffsetBasis(OCCTCurve3DRef _Nonnull curve);

// MARK: - v0.101.0: Geom_TrimmedCurve, BRepLib_FindSurface, ShapeAnalysis_Surface,
//                    Resource_Manager

// --- Geom_TrimmedCurve ---

/// Create a trimmed curve from basis curve between u1 and u2.
OCCTCurve3DRef _Nullable OCCTCurve3DTrimmed(OCCTCurve3DRef _Nonnull basisCurve,
                                            double u1,
                                            double u2);

/// Get start point of a trimmed (bounded) curve.
void OCCTCurve3DStartPoint(OCCTCurve3DRef _Nonnull curve,
                           double* _Nonnull x,
                           double* _Nonnull y,
                           double* _Nonnull z);

/// Get end point of a trimmed (bounded) curve.
void OCCTCurve3DEndPoint(OCCTCurve3DRef _Nonnull curve,
                         double* _Nonnull x,
                         double* _Nonnull y,
                         double* _Nonnull z);

/// Get basis curve of a trimmed curve (returns null if not a trimmed curve).
OCCTCurve3DRef _Nullable OCCTCurve3DTrimmedBasis(OCCTCurve3DRef _Nonnull curve);

/// Change trim parameters on a trimmed curve.
bool OCCTCurve3DSetTrim(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

// MARK: - GC_MakeCircle (v0.105.0)

/// Create a 3D circle from axis (center+normal) and radius.
OCCTCurve3DRef _Nullable OCCTGCMakeCircle(double cx,
                                          double cy,
                                          double cz,
                                          double nx,
                                          double ny,
                                          double nz,
                                          double radius);

/// Create a 3D circle through 3 points.
OCCTCurve3DRef _Nullable OCCTGCMakeCircle3Points(double x1,
                                                 double y1,
                                                 double z1,
                                                 double x2,
                                                 double y2,
                                                 double z2,
                                                 double x3,
                                                 double y3,
                                                 double z3);

/// Create a 3D circle from center, normal direction, and radius.
OCCTCurve3DRef _Nullable OCCTGCMakeCircleCenterNormal(double cx,
                                                      double cy,
                                                      double cz,
                                                      double nx,
                                                      double ny,
                                                      double nz,
                                                      double radius);

/// Create a 3D circle parallel to an existing circle at given distance.
OCCTCurve3DRef _Nullable OCCTGCMakeCircleParallel(double cx,
                                                  double cy,
                                                  double cz,
                                                  double nx,
                                                  double ny,
                                                  double nz,
                                                  double radius,
                                                  double dist);

// MARK: - GC_MakeEllipse (v0.105.0)

/// Create a 3D ellipse from axis and major/minor radii.
OCCTCurve3DRef _Nullable OCCTGCMakeEllipse(double cx,
                                           double cy,
                                           double cz,
                                           double nx,
                                           double ny,
                                           double nz,
                                           double major,
                                           double minor);

/// Create a 3D ellipse from 3 points (S1, S2, center).
OCCTCurve3DRef _Nullable OCCTGCMakeEllipse3Points(double x1,
                                                  double y1,
                                                  double z1,
                                                  double x2,
                                                  double y2,
                                                  double z2,
                                                  double x3,
                                                  double y3,
                                                  double z3);

/// Create a 3D ellipse from full Ax2 (center+normal+xdir) and radii.
OCCTCurve3DRef _Nullable OCCTGCMakeEllipseFromElips(double cx,
                                                    double cy,
                                                    double cz,
                                                    double nx,
                                                    double ny,
                                                    double nz,
                                                    double xdx,
                                                    double xdy,
                                                    double xdz,
                                                    double major,
                                                    double minor);

// MARK: - GC_MakeHyperbola (v0.105.0)

/// Create a 3D hyperbola from axis and major/minor radii.
OCCTCurve3DRef _Nullable OCCTGCMakeHyperbola(double cx,
                                             double cy,
                                             double cz,
                                             double nx,
                                             double ny,
                                             double nz,
                                             double major,
                                             double minor);

/// Create a 3D hyperbola from 3 points (S1, S2, center).
OCCTCurve3DRef _Nullable OCCTGCMakeHyperbola3Points(double x1,
                                                    double y1,
                                                    double z1,
                                                    double x2,
                                                    double y2,
                                                    double z2,
                                                    double x3,
                                                    double y3,
                                                    double z3);

// MARK: - GCPnts_UniformAbscissa (v0.105.0)

/// Uniform abscissa sampling by point count. Call with params=NULL to get count, then with
/// allocated array.
int32_t OCCTUniformAbscissaByCount(OCCTShapeRef _Nonnull edge,
                                   int32_t nbPoints,
                                   double* _Nullable params);

/// Uniform abscissa sampling by arc distance. Call with params=NULL to get count, then with
/// allocated array.
int32_t OCCTUniformAbscissaByDistance(OCCTShapeRef _Nonnull edge,
                                      double abscissa,
                                      double* _Nullable params);

/// Uniform abscissa by count within parameter range.
int32_t OCCTUniformAbscissaByCountRange(OCCTShapeRef _Nonnull edge,
                                        int32_t nbPoints,
                                        double  u1,
                                        double  u2,
                                        double* _Nullable params);

/// Uniform abscissa by distance within parameter range.
int32_t OCCTUniformAbscissaByDistanceRange(OCCTShapeRef _Nonnull edge,
                                           double abscissa,
                                           double u1,
                                           double u2,
                                           double* _Nullable params);

// MARK: - GeomConvert_CompCurveToBSplineCurve (v0.105.0)

/// Concatenate an array of bounded 3D curves into a single BSpline curve.
OCCTCurve3DRef _Nullable OCCTConcatenateCurves3D(OCCTCurve3DRef _Nonnull* _Nonnull curves,
                                                 int32_t count,
                                                 double  tolerance);

// MARK: - GeomLib_LogSample (v0.105.0)

/// Compute logarithmically spaced parameter values. params must be allocated with n elements.
void OCCTLogSample(double a, double b, int32_t n, double* _Nonnull params);

// MARK: - Curve3D continuity (v0.106.0)

/// Get the global continuity of a 3D curve.
///
/// Returns the raw GeomAbs_Shape ordinal in its own declared order, which is NOT a
/// monotonic 0/1/2 "order" and interleaves the geometric classes with the parametric ones:
/// 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN. Returns 0 for a null curve.
int32_t OCCTCurve3DGetContinuity(OCCTCurve3DRef _Nonnull curve);

// MARK: - Geom_BSplineCurve Methods (v0.107.0)

/// Get the number of knots of a BSpline curve. Returns 0 if not a BSpline.
int32_t OCCTCurve3DBSplineKnotCount(OCCTCurve3DRef _Nonnull curve);

/// Get the number of poles (control points) of a BSpline curve.
int32_t OCCTCurve3DBSplinePoleCount(OCCTCurve3DRef _Nonnull curve);

/// Get the degree of a BSpline curve.
int32_t OCCTCurve3DBSplineDegree(OCCTCurve3DRef _Nonnull curve);

/// Check if a BSpline curve is rational.
bool OCCTCurve3DBSplineIsRational(OCCTCurve3DRef _Nonnull curve);

/// Get all knot values (pre-allocated array of size NbKnots).
void OCCTCurve3DBSplineGetKnots(OCCTCurve3DRef _Nonnull curve, double* _Nonnull knots);

/// Get all knot multiplicities (pre-allocated array of size NbKnots).
void OCCTCurve3DBSplineGetMults(OCCTCurve3DRef _Nonnull curve, int32_t* _Nonnull mults);

/// Get a pole (1-based index).
void OCCTCurve3DBSplineGetPole(OCCTCurve3DRef _Nonnull curve,
                               int32_t index,
                               double* _Nonnull x,
                               double* _Nonnull y,
                               double* _Nonnull z);

/// Set a pole (1-based index).
bool OCCTCurve3DBSplineSetPole(OCCTCurve3DRef _Nonnull curve,
                               int32_t index,
                               double  x,
                               double  y,
                               double  z);

/// Set a weight for a pole (1-based index).
bool OCCTCurve3DBSplineSetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index, double weight);

/// Get the weight of a pole (1-based index).
double OCCTCurve3DBSplineGetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Insert a knot at parameter u with given multiplicity.
bool OCCTCurve3DBSplineInsertKnot(OCCTCurve3DRef _Nonnull curve,
                                  double  u,
                                  int32_t mult,
                                  double  tol);

/// Remove a knot at index down to given multiplicity.
bool OCCTCurve3DBSplineRemoveKnot(OCCTCurve3DRef _Nonnull curve,
                                  int32_t index,
                                  int32_t mult,
                                  double  tol);

/// Segment the BSpline to [u1, u2].
bool OCCTCurve3DBSplineSegment(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Increase the degree to the given value.
bool OCCTCurve3DBSplineIncreaseDegree(OCCTCurve3DRef _Nonnull curve, int32_t degree);

/// Compute the parametric resolution for a given 3D tolerance.
double OCCTCurve3DBSplineResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d);

/// Set periodic/non-periodic.
bool OCCTCurve3DBSplineSetPeriodic(OCCTCurve3DRef _Nonnull curve, bool periodic);

// MARK: - Bezier Curve Methods (v0.107.0)

/// Get a Bezier pole (1-based index).
void OCCTCurve3DBezierGetPole(OCCTCurve3DRef _Nonnull curve,
                              int32_t index,
                              double* _Nonnull x,
                              double* _Nonnull y,
                              double* _Nonnull z);

/// Set a Bezier pole (1-based index).
bool OCCTCurve3DBezierSetPole(OCCTCurve3DRef _Nonnull curve,
                              int32_t index,
                              double  x,
                              double  y,
                              double  z);

/// Set a Bezier weight (1-based index).
bool OCCTCurve3DBezierSetWeight(OCCTCurve3DRef _Nonnull curve, int32_t index, double weight);

/// Insert a pole after given index.
bool OCCTCurve3DBezierInsertPoleAfter(OCCTCurve3DRef _Nonnull curve,
                                      int32_t index,
                                      double  x,
                                      double  y,
                                      double  z);

/// Remove a pole at given index.
bool OCCTCurve3DBezierRemovePole(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Segment a Bezier curve to [u1, u2].
bool OCCTCurve3DBezierSegment(OCCTCurve3DRef _Nonnull curve, double u1, double u2);

/// Increase the degree of a Bezier curve.
bool OCCTCurve3DBezierIncreaseDegree(OCCTCurve3DRef _Nonnull curve, int32_t degree);

/// Check if a Bezier curve is rational.
bool OCCTCurve3DBezierIsRational(OCCTCurve3DRef _Nonnull curve);

/// Get the degree of a Bezier curve.
int32_t OCCTCurve3DBezierDegree(OCCTCurve3DRef _Nonnull curve);

/// Get the number of poles of a Bezier curve.
int32_t OCCTCurve3DBezierPoleCount(OCCTCurve3DRef _Nonnull curve);

// MARK: - Geom_Circle Methods (v0.108.0)

/// Get the radius of a Geom_Circle.
double OCCTCurve3DCircleRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the radius of a Geom_Circle. Returns false if not a circle.
bool OCCTCurve3DCircleSetRadius(OCCTCurve3DRef _Nonnull curve, double radius);

/// Get the eccentricity of a Geom_Circle (always 0).
double OCCTCurve3DCircleEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the XAxis of a Geom_Circle.
void OCCTCurve3DCircleXAxis(OCCTCurve3DRef _Nonnull curve,
                            double* _Nonnull px,
                            double* _Nonnull py,
                            double* _Nonnull pz,
                            double* _Nonnull dx,
                            double* _Nonnull dy,
                            double* _Nonnull dz);

/// Get the YAxis of a Geom_Circle.
void OCCTCurve3DCircleYAxis(OCCTCurve3DRef _Nonnull curve,
                            double* _Nonnull px,
                            double* _Nonnull py,
                            double* _Nonnull pz,
                            double* _Nonnull dx,
                            double* _Nonnull dy,
                            double* _Nonnull dz);

/// Get the center of a Geom_Circle.
void OCCTCurve3DCircleCenter(OCCTCurve3DRef _Nonnull curve,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);

// MARK: - Geom_Ellipse Methods (v0.108.0)

/// Get the major radius of a Geom_Ellipse.
double OCCTCurve3DEllipseMajorRadius(OCCTCurve3DRef _Nonnull curve);

/// Get the minor radius of a Geom_Ellipse.
double OCCTCurve3DEllipseMinorRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the major radius of a Geom_Ellipse.
bool OCCTCurve3DEllipseSetMajorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom_Ellipse.
bool OCCTCurve3DEllipseSetMinorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom_Ellipse.
double OCCTCurve3DEllipseEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the focal distance of a Geom_Ellipse.
double OCCTCurve3DEllipseFocal(OCCTCurve3DRef _Nonnull curve);

/// Get the first focus of a Geom_Ellipse.
void OCCTCurve3DEllipseFocus1(OCCTCurve3DRef _Nonnull curve,
                              double* _Nonnull x,
                              double* _Nonnull y,
                              double* _Nonnull z);

/// Get the second focus of a Geom_Ellipse.
void OCCTCurve3DEllipseFocus2(OCCTCurve3DRef _Nonnull curve,
                              double* _Nonnull x,
                              double* _Nonnull y,
                              double* _Nonnull z);

/// Get the parameter (semi-latus rectum) of a Geom_Ellipse.
double OCCTCurve3DEllipseParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the first directrix of a Geom_Ellipse.
void OCCTCurve3DEllipseDirectrix1(OCCTCurve3DRef _Nonnull curve,
                                  double* _Nonnull px,
                                  double* _Nonnull py,
                                  double* _Nonnull pz,
                                  double* _Nonnull dx,
                                  double* _Nonnull dy,
                                  double* _Nonnull dz);

// MARK: - Geom_Hyperbola Methods (v0.108.0)

/// Get the major radius of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaMajorRadius(OCCTCurve3DRef _Nonnull curve);

/// Get the minor radius of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaMinorRadius(OCCTCurve3DRef _Nonnull curve);

/// Set the major radius of a Geom_Hyperbola.
bool OCCTCurve3DHyperbolaSetMajorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom_Hyperbola.
bool OCCTCurve3DHyperbolaSetMinorRadius(OCCTCurve3DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the focal distance of a Geom_Hyperbola.
double OCCTCurve3DHyperbolaFocal(OCCTCurve3DRef _Nonnull curve);

/// Get the first focus of a Geom_Hyperbola.
void OCCTCurve3DHyperbolaFocus1(OCCTCurve3DRef _Nonnull curve,
                                double* _Nonnull x,
                                double* _Nonnull y,
                                double* _Nonnull z);

/// Get the first asymptote of a Geom_Hyperbola.
void OCCTCurve3DHyperbolaAsymptote1(OCCTCurve3DRef _Nonnull curve,
                                    double* _Nonnull px,
                                    double* _Nonnull py,
                                    double* _Nonnull pz,
                                    double* _Nonnull dx,
                                    double* _Nonnull dy,
                                    double* _Nonnull dz);

// MARK: - Geom_Parabola Methods (v0.108.0)

/// Get the focal distance of a Geom_Parabola.
double OCCTCurve3DParabolaFocal(OCCTCurve3DRef _Nonnull curve);

/// Set the focal distance of a Geom_Parabola.
bool OCCTCurve3DParabolaSetFocal(OCCTCurve3DRef _Nonnull curve, double focal);

/// Get the focus point of a Geom_Parabola.
void OCCTCurve3DParabolaFocus(OCCTCurve3DRef _Nonnull curve,
                              double* _Nonnull x,
                              double* _Nonnull y,
                              double* _Nonnull z);

/// Get the eccentricity of a Geom_Parabola (always 1).
double OCCTCurve3DParabolaEccentricity(OCCTCurve3DRef _Nonnull curve);

/// Get the parameter (2*focal) of a Geom_Parabola.
double OCCTCurve3DParabolaParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the directrix of a Geom_Parabola.
void OCCTCurve3DParabolaDirectrix(OCCTCurve3DRef _Nonnull curve,
                                  double* _Nonnull px,
                                  double* _Nonnull py,
                                  double* _Nonnull pz,
                                  double* _Nonnull dx,
                                  double* _Nonnull dy,
                                  double* _Nonnull dz);

// MARK: - Geom_Line Methods (v0.108.0)

/// Get the direction of a Geom_Line.
void OCCTCurve3DLineDirection(OCCTCurve3DRef _Nonnull curve,
                              double* _Nonnull dx,
                              double* _Nonnull dy,
                              double* _Nonnull dz);

/// Get the location of a Geom_Line.
void OCCTCurve3DLineLocation(OCCTCurve3DRef _Nonnull curve,
                             double* _Nonnull x,
                             double* _Nonnull y,
                             double* _Nonnull z);

/// Set the direction of a Geom_Line.
bool OCCTCurve3DLineSetDirection(OCCTCurve3DRef _Nonnull curve, double dx, double dy, double dz);

/// Set the location of a Geom_Line.
bool OCCTCurve3DLineSetLocation(OCCTCurve3DRef _Nonnull curve, double x, double y, double z);

/// Get the position (Ax1) of a Geom_Line.
void OCCTCurve3DLinePosition(OCCTCurve3DRef _Nonnull curve,
                             double* _Nonnull px,
                             double* _Nonnull py,
                             double* _Nonnull pz,
                             double* _Nonnull dx,
                             double* _Nonnull dy,
                             double* _Nonnull dz);

/// Get the gp_Lin of a Geom_Line.
void OCCTCurve3DLineLin(OCCTCurve3DRef _Nonnull curve,
                        double* _Nonnull px,
                        double* _Nonnull py,
                        double* _Nonnull pz,
                        double* _Nonnull dx,
                        double* _Nonnull dy,
                        double* _Nonnull dz);

// MARK: - Extrema_ExtElC: Elementary Curve-Curve Distance (v0.109.0)

/// Distance between two 3D lines (Extrema_ExtElC).
/// @param outIsParallel Set to true if lines are parallel
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinLin(double l1px,
                             double l1py,
                             double l1pz,
                             double l1dx,
                             double l1dy,
                             double l1dz,
                             double l2px,
                             double l2py,
                             double l2pz,
                             double l2dx,
                             double l2dy,
                             double l2dz,
                             double tolerance,
                             bool* _Nonnull outIsParallel,
                             OCCTExtremaElResult* _Nonnull out,
                             int32_t max);

/// Distance between a 3D line and circle (Extrema_ExtElC).
/// A line coincident with the circle's own axis is a degenerate, parallel case with a
/// well-defined constant distance (the circle's radius): returns 1 result with that distance
/// (points zeroed, undefined) rather than 0 (#1501).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinCirc(double lpx,
                              double lpy,
                              double lpz,
                              double ldx,
                              double ldy,
                              double ldz,
                              double cx,
                              double cy,
                              double cz,
                              double nx,
                              double ny,
                              double nz,
                              double radius,
                              double tolerance,
                              OCCTExtremaElResult* _Nonnull out,
                              int32_t max);

/// Distance between two 3D circles (Extrema_ExtElC).
/// Coaxial, coplanar circles are a degenerate, parallel case with a well-defined constant
/// distance (the radii's absolute difference): returns 1 result with that distance (points
/// zeroed, undefined) rather than 0 (#1501).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCCircCirc(double c1x,
                               double c1y,
                               double c1z,
                               double n1x,
                               double n1y,
                               double n1z,
                               double r1,
                               double c2x,
                               double c2y,
                               double c2z,
                               double n2x,
                               double n2y,
                               double n2z,
                               double r2,
                               OCCTExtremaElResult* _Nonnull out,
                               int32_t max);

/// Distance between a 3D line and ellipse (Extrema_ExtElC).
/// No tolerance (#999): of Extrema_ExtElC's six constructors only the line/line and line/circle
/// ones take one (AngTol and Tol respectively), and Extrema_ExtElC(gp_Lin, gp_Elips) takes none.
/// A line coincident with the ellipse's own axis is a degenerate, parallel case with a
/// well-defined constant distance: returns 1 result with that distance (points zeroed,
/// undefined) rather than 0 (#1501).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCLinElips(double lpx,
                               double lpy,
                               double lpz,
                               double ldx,
                               double ldy,
                               double ldz,
                               double cx,
                               double cy,
                               double cz,
                               double nx,
                               double ny,
                               double nz,
                               double xdx,
                               double xdy,
                               double xdz,
                               double majorRadius,
                               double minorRadius,
                               OCCTExtremaElResult* _Nonnull out,
                               int32_t max);

// MARK: - Extrema_ExtElCS: Elementary Curve-Surface Distance (v0.109.0)

/// Distance between a 3D line and plane (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinPlane(double lpx,
                                double lpy,
                                double lpz,
                                double ldx,
                                double ldy,
                                double ldz,
                                double plx,
                                double ply,
                                double plz,
                                double pnx,
                                double pny,
                                double pnz,
                                bool* _Nonnull outIsParallel,
                                OCCTExtremaElResult* _Nonnull out,
                                int32_t max);

/// Distance between a 3D line and sphere (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinSphere(double lpx,
                                 double lpy,
                                 double lpz,
                                 double ldx,
                                 double ldy,
                                 double ldz,
                                 double cx,
                                 double cy,
                                 double cz,
                                 double radius,
                                 OCCTExtremaElResult* _Nonnull out,
                                 int32_t max);

/// Distance between a 3D line and cylinder (Extrema_ExtElCS).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaElCSLinCylinder(double lpx,
                                   double lpy,
                                   double lpz,
                                   double ldx,
                                   double ldy,
                                   double ldz,
                                   double cx,
                                   double cy,
                                   double cz,
                                   double nx,
                                   double ny,
                                   double nz,
                                   double radius,
                                   OCCTExtremaElResult* _Nonnull out,
                                   int32_t max);

// MARK: - Extrema_ExtPElC: Point to Elementary Curve Distance (v0.109.0)

/// Closest distance from a point to a 3D line (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCLin(double px,
                              double py,
                              double pz,
                              double lx,
                              double ly,
                              double lz,
                              double ldx,
                              double ldy,
                              double ldz,
                              double tolerance,
                              OCCTExtremaElResult* _Nonnull out,
                              int32_t max);

/// Closest distance from a point to a 3D circle (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCCirc(double px,
                               double py,
                               double pz,
                               double cx,
                               double cy,
                               double cz,
                               double nx,
                               double ny,
                               double nz,
                               double radius,
                               double tolerance,
                               OCCTExtremaElResult* _Nonnull out,
                               int32_t max);

/// Closest distance from a point to a 3D ellipse (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCElips(double px,
                                double py,
                                double pz,
                                double cx,
                                double cy,
                                double cz,
                                double nx,
                                double ny,
                                double nz,
                                double xdx,
                                double xdy,
                                double xdz,
                                double majorRadius,
                                double minorRadius,
                                double tolerance,
                                OCCTExtremaElResult* _Nonnull out,
                                int32_t max);

/// Closest distance from a point to a 3D parabola (Extrema_ExtPElC).
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtPElCParab(double px,
                                double py,
                                double pz,
                                double cx,
                                double cy,
                                double cz,
                                double nx,
                                double ny,
                                double nz,
                                double xdx,
                                double xdy,
                                double xdz,
                                double focal,
                                double tolerance,
                                OCCTExtremaElResult* _Nonnull out,
                                int32_t max);

// MARK: - Curve3D Extras (v0.109.0)

/// Reverse the curve in-place.
bool OCCTCurve3DReverse(OCCTCurve3DRef _Nonnull curve);

/// Deep copy a 3D curve.
OCCTCurve3DRef _Nullable OCCTCurve3DCopy(OCCTCurve3DRef _Nonnull curve);

/// Deprecated alias of OCCTCurve3DGetContinuity, kept for ABI compatibility (#485).
///
/// Prefer OCCTCurve3DGetContinuity. This used to re-encode the same GeomAbs_Shape through a
/// hand-written switch producing {C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}, an encoding
/// that matched neither the real enum nor its own doc comment; it now returns the raw
/// GeomAbs_Shape ordinal, identical to OCCTCurve3DGetContinuity.
int32_t OCCTCurve3DContinuity(OCCTCurve3DRef _Nonnull curve);

// MARK: - Curve3D Evaluation (v0.110.0)

/// Evaluate curve at parameter u, returning point (x, y, z).
void OCCTCurve3DEvalD0(OCCTCurve3DRef _Nonnull curve,
                       double u,
                       double* _Nonnull x,
                       double* _Nonnull y,
                       double* _Nonnull z);

/// Evaluate curve at parameter u, returning point and first derivative.
void OCCTCurve3DEvalD1(OCCTCurve3DRef _Nonnull curve,
                       double u,
                       double* _Nonnull px,
                       double* _Nonnull py,
                       double* _Nonnull pz,
                       double* _Nonnull d1x,
                       double* _Nonnull d1y,
                       double* _Nonnull d1z);

/// Evaluate curve at parameter u, returning point, first and second derivatives.
void OCCTCurve3DEvalD2(OCCTCurve3DRef _Nonnull curve,
                       double u,
                       double* _Nonnull px,
                       double* _Nonnull py,
                       double* _Nonnull pz,
                       double* _Nonnull d1x,
                       double* _Nonnull d1y,
                       double* _Nonnull d1z,
                       double* _Nonnull d2x,
                       double* _Nonnull d2y,
                       double* _Nonnull d2z);

/// Evaluate curve at parameter u, returning point, first, second and third derivatives.
void OCCTCurve3DEvalD3(OCCTCurve3DRef _Nonnull curve,
                       double u,
                       double* _Nonnull px,
                       double* _Nonnull py,
                       double* _Nonnull pz,
                       double* _Nonnull d1x,
                       double* _Nonnull d1y,
                       double* _Nonnull d1z,
                       double* _Nonnull d2x,
                       double* _Nonnull d2y,
                       double* _Nonnull d2z,
                       double* _Nonnull d3x,
                       double* _Nonnull d3y,
                       double* _Nonnull d3z);

// --- Curve3D extras ---

/// Get the curve type enum (GeomAbs_CurveType: 0=Line..7=OtherCurve).
int32_t OCCTCurve3DCurveType(OCCTCurve3DRef _Nonnull curve);

/// Find the parameter on a 3D curve nearest to a 3D point, over the curve's whole range.
///
/// The nearest point over the curve's own range, ends included, not the nearest perpendicular
/// foot: a point beyond the end of a bounded curve is nearest to that end, and a circle's centre
/// is equidistant from every point on it, so both are answered (#615). Agrees exactly with
/// OCCTCurve3DProjectPoint, which shares occtNearestPointOnCurveRange with it.
///
/// Returns false and leaves *outParameter untouched only when there is no curve to answer about.
/// Failure cannot be signalled through the parameter: every double is a legitimate parameter on
/// some curve. Replaces OCCTCurve3DParameterAtPoint and OCCTCurve3DClosestParameter, which ran the
/// identical projection and disagreed about how to report its absence (#500).
bool OCCTCurve3DNearestParameter(OCCTCurve3DRef _Nonnull curve,
                                 double x,
                                 double y,
                                 double z,
                                 double* _Nonnull outParameter);

// --- Extrema extras ---

/// Local point-on-curve search from an initial parameter guess.
///
/// Two searches with two different contracts. The PRIMARY one reports the LOWEST-DISTANCE extremum
/// within a window of +/-10% of the domain around the guess: initParam bounds the window, it does
/// not rank what is found inside it, so the extremum returned need not be the one nearest the
/// guess. The window is what makes the answer local, and a windowed minimum can still be a global
/// MAXIMUM. The FALLBACK, which fires only when that window holds no extremum, searches the whole
/// curve and reports its true nearest point, agreeing with OCCTCurve3DNearestParameter (#615).
/// Callers wanting the global answer should use that instead.
///
/// Returns false only when there is no curve to answer about.
///
/// No tolerance (#999): both halves of this function reach OCCT through
/// GeomAPI_ProjectPointOnCurve, whose windowed constructor takes none, and the fallback goes
/// through occtNearestPointOnCurveRange at Precision::Confusion(). Extrema_LocateExtPC, which the
/// name echoes, does take a TolU, but #615 deliberately moved this off that path so the local and
/// global answers could not disagree; its sibling OCCTExtremaLocateOnSurface keeps its tol because
/// Extrema_GenLocateExtPS genuinely takes one.
bool OCCTExtremaLocateOnCurve(OCCTCurve3DRef _Nonnull curve,
                              double px,
                              double py,
                              double pz,
                              double initParam,
                              double* _Nonnull param,
                              double* _Nonnull distance);

/// Local point-on-surface search from initial (u,v) guess.
bool OCCTExtremaLocateOnSurface(OCCTSurfaceRef _Nonnull surface,
                                double px,
                                double py,
                                double pz,
                                double initU,
                                double initV,
                                double tol,
                                double* _Nonnull u,
                                double* _Nonnull v,
                                double* _Nonnull distance);

/// Global point-to-curve extrema. Returns number of solutions found.
int32_t OCCTExtremaPointCurve(OCCTCurve3DRef _Nonnull curve,
                              double px,
                              double py,
                              double pz,
                              double* _Nonnull params,
                              double* _Nonnull distances,
                              int32_t maxResults);

/// Global point-to-surface extrema. Returns number of solutions found.
int32_t OCCTExtremaPointSurface(OCCTSurfaceRef _Nonnull surface,
                                double px,
                                double py,
                                double pz,
                                double* _Nonnull us,
                                double* _Nonnull vs,
                                double* _Nonnull distances,
                                int32_t maxResults);

/// Create a multi-result projection of a point onto a curve.
OCCTProjOnCurveRef _Nullable OCCTProjOnCurveCreate(OCCTCurve3DRef _Nonnull curve,
                                                   double px,
                                                   double py,
                                                   double pz);

/// Release a projection on curve object.
void OCCTProjOnCurveRelease(OCCTProjOnCurveRef _Nonnull proj);

/// Number of projection results.
int32_t OCCTProjOnCurveNbPoints(OCCTProjOnCurveRef _Nonnull proj);

/// Get the i-th projection point (1-based index).
void OCCTProjOnCurvePoint(OCCTProjOnCurveRef _Nonnull proj,
                          int32_t index,
                          double* _Nonnull x,
                          double* _Nonnull y,
                          double* _Nonnull z);

/// Get the parameter of the i-th projection (1-based).
double OCCTProjOnCurveParameter(OCCTProjOnCurveRef _Nonnull proj, int32_t index);

/// Get the distance of the i-th projection (1-based).
double OCCTProjOnCurveDistance(OCCTProjOnCurveRef _Nonnull proj, int32_t index);

/// Get the minimum distance across all projections.
double OCCTProjOnCurveLowerDistance(OCCTProjOnCurveRef _Nonnull proj);

/// Get the parameter of the nearest projection.
double OCCTProjOnCurveLowerParam(OCCTProjOnCurveRef _Nonnull proj);

// --- BSplineCurve remaining mutations ---

/// Set the knot value at a given index (1-based).
bool OCCTCurve3DBSplineSetKnot(OCCTCurve3DRef _Nonnull curve, int32_t index, double knot);

/// Get the full knot sequence (with multiplicities expanded). Caller must pre-allocate knotSeq.
/// Returns the count in *count.
void OCCTCurve3DBSplineGetKnotSequence(OCCTCurve3DRef _Nonnull curve,
                                       double* _Nonnull knotSeq,
                                       int32_t* _Nonnull count);

/// Get all weights (one per pole). Caller must pre-allocate weights array.
void OCCTCurve3DBSplineGetWeights(OCCTCurve3DRef _Nonnull curve, double* _Nonnull weights);

/// Insert multiple knots at once with specified multiplicities.
bool OCCTCurve3DBSplineInsertKnots(OCCTCurve3DRef _Nonnull curve,
                                   const double* _Nonnull knots,
                                   const int32_t* _Nonnull mults,
                                   int32_t count,
                                   double  tol);

/// Move a point on the curve to a new position. index1/index2 define the pole range to modify.
bool OCCTCurve3DBSplineMovePoint(OCCTCurve3DRef _Nonnull curve,
                                 double  u,
                                 double  x,
                                 double  y,
                                 double  z,
                                 int32_t index1,
                                 int32_t index2);

/// Evaluate the curve locally within a knot span (fromK1..toK2 are 1-based knot indices).
void OCCTCurve3DBSplineLocalValue(OCCTCurve3DRef _Nonnull curve,
                                  double  u,
                                  int32_t fromK1,
                                  int32_t toK2,
                                  double* _Nonnull x,
                                  double* _Nonnull y,
                                  double* _Nonnull z);

/// Get the maximum BSpline degree supported (static).
int32_t OCCTCurve3DBSplineMaxDegree(void);

/// Locate the knot span containing parameter u.
int32_t OCCTCurve3DBSplineLocateU(OCCTCurve3DRef _Nonnull curve, double u, double tol);

// --- Curve isBounded ---

/// Check if a 3D curve is bounded (Geom_BoundedCurve subclass).
bool OCCTCurve3DIsBounded(OCCTCurve3DRef _Nonnull curve);

// --- Geom_Curve DN (arbitrary derivative) ---

/// Evaluate the N-th derivative of a 3D curve at parameter u.
void OCCTCurve3DDN(OCCTCurve3DRef _Nonnull curve,
                   double  u,
                   int32_t n,
                   double* _Nonnull x,
                   double* _Nonnull y,
                   double* _Nonnull z);

// --- Curve/Surface type names ---

/// Get the 3D curve type as a string (Geom_Line, Geom_Circle, etc.).
const char* _Nullable OCCTCurve3DTypeName(OCCTCurve3DRef _Nonnull curve);

// MARK: - v0.115.0: Interpolation expansion, ThruSections builder, Triangulation queries, Adaptor
// exposure, Shape queries

// --- GeomAPI_Interpolate expansion ---

/// Interpolate 3D BSpline with endpoint tangents. Forwards to
/// OCCTCurve3DInterpolateWithTangents with a fixed 1e-6 tolerance; kept for
/// existing C callers of this exact signature.
OCCTCurve3DRef _Nullable OCCTInterpolateWithTangents(const double* _Nonnull points,
                                                     int32_t count,
                                                     double  t1x,
                                                     double  t1y,
                                                     double  t1z,
                                                     double  t2x,
                                                     double  t2y,
                                                     double  t2z);

/// Interpolate 3D BSpline with per-point tangents. tangentFlags[i] indicates if tangent[i] is set.
OCCTCurve3DRef _Nullable OCCTInterpolateWithAllTangents(const double* _Nonnull points,
                                                        int32_t count,
                                                        const double* _Nonnull tangents,
                                                        const bool* _Nonnull tangentFlags);

/// Interpolate 3D BSpline with explicit parameters.
OCCTCurve3DRef _Nullable OCCTInterpolateWithParameters(const double* _Nonnull points,
                                                       int32_t count,
                                                       const double* _Nonnull parameters);

/// Interpolate 3D BSpline as periodic (closed) curve.
OCCTCurve3DRef _Nullable OCCTInterpolatePeriodic(const double* _Nonnull points, int32_t count);

// --- PointsToBSpline expansion ---
//
// One section, three different OCCT classes, one per dimension:
//   GeomAPI_PointsToBSpline          (3D curve)   OCCTPointsToBSplineWithParams/WithParameters
//   Geom2dAPI_PointsToBSpline        (2D curve)   OCCTPoints2DToBSplineWithParams
//   GeomAPI_PointsToBSplineSurface   (surface)    OCCTPointsToSurfaceBSpline

/// Approximate 3D BSpline through points with degree and continuity control.
/// continuity: parametric continuity, see "Continuity vocabularies" at the top of this header.
OCCTCurve3DRef _Nullable OCCTPointsToBSplineWithParams(const double* _Nonnull points,
                                                       int32_t count,
                                                       int32_t degMin,
                                                       int32_t degMax,
                                                       int32_t continuity,
                                                       double  tol);

/// Approximate 3D BSpline with explicit parameter values.
OCCTCurve3DRef _Nullable OCCTPointsToBSplineWithParameters(const double* _Nonnull points,
                                                           const double* _Nonnull params,
                                                           int32_t count,
                                                           int32_t degMin,
                                                           int32_t degMax,
                                                           int32_t continuity,
                                                           double  tol);

// --- GeomConvert utilities ---

/// Split a 3D curve at discontinuities of given continuity.
/// Returns number of segments written to outSegments (up to maxSegments).
int32_t OCCTCurve3DSplitAtContinuity(OCCTCurve3DRef _Nonnull curve,
                                     int32_t continuity,
                                     double  tol,
                                     OCCTCurve3DRef _Nullable* _Nonnull outSegments,
                                     int32_t maxSegments);

/// Concatenate an array of 3D curves with G1 continuity. Returns nullptr, rather than a partial
/// concatenation, if any curve after the first is not G0-continuous with the accumulated curve
/// within `tol` (#1441).
OCCTCurve3DRef _Nullable OCCTCurve3DConcatenateG1(const OCCTCurve3DRef _Nonnull* _Nonnull curves,
                                                  int32_t count,
                                                  double  tol);

/// Find parameter on a 3D curve at a given arc length from startParam.
double OCCTCurve3DParameterAtLength(OCCTCurve3DRef _Nonnull curve,
                                    double arcLength,
                                    double fromParam);

// MARK: - HelixGeom (v0.116.0)

/// Build a helix curve approximated as BSpline. Returns curve handle; NULL on failure.
/// t1/t2: parameter range, pitch: helix pitch, rStart: radius, taperAngle: taper in radians,
/// isClockwise. posX/Y/Z + dirX/Y/Z + xDirX/Y/Z define the gp_Ax2 position.
OCCTCurve3DRef _Nullable OCCTHelixBuild(double posX,
                                        double posY,
                                        double posZ,
                                        double dirX,
                                        double dirY,
                                        double dirZ,
                                        double xDirX,
                                        double xDirY,
                                        double xDirZ,
                                        double t1,
                                        double t2,
                                        double pitch,
                                        double rStart,
                                        double taperAngle,
                                        bool   isClockwise,
                                        double tolerance,
                                        double* _Nonnull tolReached);

/// Build a helix coil (closed loop helix). Returns curve handle; NULL on failure.
OCCTCurve3DRef _Nullable OCCTHelixCoilBuild(double t1,
                                            double t2,
                                            double pitch,
                                            double rStart,
                                            double taperAngle,
                                            bool   isClockwise,
                                            double tolerance,
                                            double* _Nonnull tolReached);

/// Evaluate helix curve at parameter u. Returns point.
void OCCTHelixCurveEval(double t1,
                        double t2,
                        double pitch,
                        double rStart,
                        double taperAngle,
                        bool   isClockwise,
                        double u,
                        double* _Nonnull px,
                        double* _Nonnull py,
                        double* _Nonnull pz);

/// Evaluate helix curve D1 (point + first derivative) at parameter u.
void OCCTHelixCurveD1(double t1,
                      double t2,
                      double pitch,
                      double rStart,
                      double taperAngle,
                      bool   isClockwise,
                      double u,
                      double* _Nonnull px,
                      double* _Nonnull py,
                      double* _Nonnull pz,
                      double* _Nonnull vx,
                      double* _Nonnull vy,
                      double* _Nonnull vz);

/// Evaluate helix curve D2 at parameter u.
void OCCTHelixCurveD2(double t1,
                      double t2,
                      double pitch,
                      double rStart,
                      double taperAngle,
                      bool   isClockwise,
                      double u,
                      double* _Nonnull px,
                      double* _Nonnull py,
                      double* _Nonnull pz,
                      double* _Nonnull v1x,
                      double* _Nonnull v1y,
                      double* _Nonnull v1z,
                      double* _Nonnull v2x,
                      double* _Nonnull v2y,
                      double* _Nonnull v2z);

/// Approximate a helix to BSpline directly via HelixGeom_Tools::ApprHelix.
OCCTCurve3DRef _Nullable OCCTHelixApproxToBSpline(double t1,
                                                  double t2,
                                                  double pitch,
                                                  double rStart,
                                                  double taperAngle,
                                                  bool   isClockwise,
                                                  double tolerance,
                                                  double* _Nonnull maxError);

// MARK: - LProp3d_CLProps (v0.117.0)

// OCCTCurve3DLocalCurvature was removed in #595. Since #494 converged its resolution it built the
// same GeomLProp_CLProps as OCCTCurve3DGetCurvature at the same occtLocalPropsResolution() and
// gated on the same IsTangentDefined(); measured over the same curves the two never disagreed on
// any row, including the degenerate ones. Curve3D.localCurvature(at:) is deprecated onto
// curvature(at:).

/// Get tangent direction at parameter on a 3D curve.
void OCCTCurve3DLocalTangent(OCCTCurve3DRef _Nonnull curve,
                             double u,
                             double* _Nonnull tx,
                             double* _Nonnull ty,
                             double* _Nonnull tz,
                             bool* _Nonnull isDefined);

/// Get normal direction at parameter on a 3D curve.
void OCCTCurve3DLocalNormal(OCCTCurve3DRef _Nonnull curve,
                            double u,
                            double* _Nonnull nx,
                            double* _Nonnull ny,
                            double* _Nonnull nz,
                            bool* _Nonnull isDefined);

/// Get centre of curvature at parameter on a 3D curve.
void OCCTCurve3DLocalCentreOfCurvature(OCCTCurve3DRef _Nonnull curve,
                                       double u,
                                       double* _Nonnull cx,
                                       double* _Nonnull cy,
                                       double* _Nonnull cz,
                                       bool* _Nonnull isDefined);

// MARK: - v0.120.0: Final cleanup. IsCN, ReversedParameter, ParametricTransformation,
//                    gp extras, surface reversed copies, BSpline/Bezier MaxDegree/Resolution

// --- Curve3D continuity queries ---

/// Check if a 3D curve has Cn continuity.
bool OCCTCurve3DIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n);

/// Get the reversed parameter value for a 3D curve.
double OCCTCurve3DReversedParameter(OCCTCurve3DRef _Nonnull curve, double u);

/// Get the parametric transformation scale factor for a 3D curve under a geometric transform.
/// Pass the transform as 12 doubles: 3x3 rotation matrix (row-major) + 3 translation.
double OCCTCurve3DParametricTransformation(OCCTCurve3DRef _Nonnull curve,
                                           const double* _Nonnull trsf12);

// --- Bezier curve/surface Resolution + MaxDegree ---

/// Compute parameter resolution for a 3D Bezier curve from a 3D tolerance.
double OCCTCurve3DBezierResolution(OCCTCurve3DRef _Nonnull curve, double tolerance3d);

/// Get the maximum degree for Bezier curves (3D).
int32_t OCCTCurve3DBezierMaxDegree(void);

// --- BSplineCurve 3D completions ---

/// Remove periodicity from 3D BSpline curve.
bool OCCTCurve3DBSplineSetNotPeriodic(OCCTCurve3DRef _Nonnull curve);

/// Set origin knot index (1-based) on periodic 3D BSpline curve.
bool OCCTCurve3DBSplineSetOrigin(OCCTCurve3DRef _Nonnull curve, int32_t index);

/// Increase multiplicity of knot at index to at least mult (1-based).
bool OCCTCurve3DBSplineIncreaseMultiplicity(OCCTCurve3DRef _Nonnull curve,
                                            int32_t index,
                                            int32_t mult);

/// Increment multiplicity of all knots from index1 to index2 by step (1-based).
bool OCCTCurve3DBSplineIncrementMultiplicity(OCCTCurve3DRef _Nonnull curve,
                                             int32_t index1,
                                             int32_t index2,
                                             int32_t step);

/// Set all knot values at once (count must match NbKnots).
bool OCCTCurve3DBSplineSetKnots(OCCTCurve3DRef _Nonnull curve,
                                const double* _Nonnull knots,
                                int32_t count);

/// Reverse parameterization of 3D BSpline curve.
bool OCCTCurve3DBSplineReverse(OCCTCurve3DRef _Nonnull curve);

/// Move point and tangent at parameter u on 3D BSpline curve.
bool OCCTCurve3DBSplineMovePointAndTangent(OCCTCurve3DRef _Nonnull curve,
                                           double  u,
                                           double  px,
                                           double  py,
                                           double  pz,
                                           double  tx,
                                           double  ty,
                                           double  tz,
                                           double  tolerance,
                                           int32_t startIndex,
                                           int32_t endIndex);

// --- Curve3D queries ---

/// Get the period of a periodic curve (0.0 if not periodic).
double OCCTCurve3DPeriod(OCCTCurve3DRef _Nonnull curve);

/// Get the first parameter of a curve.
double OCCTCurve3DFirstParameter(OCCTCurve3DRef _Nonnull curve);

/// Get the last parameter of a curve.
double OCCTCurve3DLastParameter(OCCTCurve3DRef _Nonnull curve);

// --- Geom_BezierCurve completions ---

/// Get start point.
void OCCTCurve3DBezierStartPoint(OCCTCurve3DRef _Nonnull curve,
                                 double* _Nonnull x,
                                 double* _Nonnull y,
                                 double* _Nonnull z);

/// Get end point.
void OCCTCurve3DBezierEndPoint(OCCTCurve3DRef _Nonnull curve,
                               double* _Nonnull x,
                               double* _Nonnull y,
                               double* _Nonnull z);

/// Get all poles as flat array (x1,y1,z1,...). Array must be pre-allocated to NbPoles*3.
void OCCTCurve3DBezierGetPoles(OCCTCurve3DRef _Nonnull curve, double* _Nonnull poles);

/// Get all weights. Array must be pre-allocated to NbPoles. Returns false if non-rational.
bool OCCTCurve3DBezierGetWeights(OCCTCurve3DRef _Nonnull curve, double* _Nonnull weights);

/// Is the curve closed?
bool OCCTCurve3DBezierIsClosed(OCCTCurve3DRef _Nonnull curve);

/// Is the curve periodic?
bool OCCTCurve3DBezierIsPeriodic(OCCTCurve3DRef _Nonnull curve);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTCurve3DBezierContinuity(OCCTCurve3DRef _Nonnull curve);

/// IsCN: is the curve at least CN continuous?
bool OCCTCurve3DBezierIsCN(OCCTCurve3DRef _Nonnull curve, int32_t n);

// --- Bezier 3D curve InsertPoleBefore (complement to InsertPoleAfter) ---

/// Insert a pole before index in a 3D Bezier curve. Index is 1-based.
bool OCCTCurve3DBezierInsertPoleBefore(OCCTCurve3DRef _Nonnull curve,
                                       int32_t index,
                                       double  x,
                                       double  y,
                                       double  z);

/// Reverse the parameterization of a 3D Bezier curve.
bool OCCTCurve3DBezierReverse(OCCTCurve3DRef _Nonnull curve);

/// Get all poles of a 3D Bezier curve as flat array (x1,y1,z1,...). Already exists as
/// OCCTCurve3DBezierGetPoles.

/// Set pole with weight for a 3D Bezier curve.
bool OCCTCurve3DBezierSetPoleWithWeight(OCCTCurve3DRef _Nonnull curve,
                                        int32_t index,
                                        double  x,
                                        double  y,
                                        double  z,
                                        double  weight);

// --- Geom_BSplineCurve completions ---

/// Normalize parameter for periodic BSpline curve. Returns normalized u.
/// Returns false if curve is not periodic.
bool OCCTCurve3DBSplinePeriodicNormalization(OCCTCurve3DRef _Nonnull curve, double* _Nonnull u);

/// Check G1 continuity on parameter range [tFirst, tLast] with angular tolerance.
bool OCCTCurve3DBSplineIsG1(OCCTCurve3DRef _Nonnull curve,
                            double tFirst,
                            double tLast,
                            double angTol);

// --- Geometry Transform (in-place) ---

/// Transform a 3D curve in place using a gp_Trsf (translate/rotate/scale/mirror).
/// transformType: 0=translation(dx,dy,dz), 1=rotation(ox,oy,oz,dx,dy,dz,angle),
/// 2=scale(cx,cy,cz,factor), 3=mirror point(px,py,pz), 4=mirror axis(ox,oy,oz,dx,dy,dz), 5=mirror
/// plane(ox,oy,oz,nx,ny,nz)
bool OCCTCurve3DTransform(OCCTCurve3DRef _Nonnull curve,
                          int32_t transformType,
                          double  p1,
                          double  p2,
                          double  p3,
                          double  p4,
                          double  p5,
                          double  p6,
                          double  p7);

// --- v0.129.0: BSplineCurve3D LocalD0-D3/DN, BSplineSurface completions, BezierSurface completions
// ---

// BSplineCurve3D local evaluation on knot span

/// Evaluate point on BSpline curve within knot span [fromK1, toK2].
void OCCTCurve3DBSplineLocalD0(OCCTCurve3DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull pz);

/// Evaluate point + 1st derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD1(OCCTCurve3DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull pz,
                               double* _Nonnull vx,
                               double* _Nonnull vy,
                               double* _Nonnull vz);

/// Evaluate point + 1st + 2nd derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD2(OCCTCurve3DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull pz,
                               double* _Nonnull v1x,
                               double* _Nonnull v1y,
                               double* _Nonnull v1z,
                               double* _Nonnull v2x,
                               double* _Nonnull v2y,
                               double* _Nonnull v2z);

/// Evaluate point + 1st + 2nd + 3rd derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalD3(OCCTCurve3DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull pz,
                               double* _Nonnull v1x,
                               double* _Nonnull v1y,
                               double* _Nonnull v1z,
                               double* _Nonnull v2x,
                               double* _Nonnull v2y,
                               double* _Nonnull v2z,
                               double* _Nonnull v3x,
                               double* _Nonnull v3y,
                               double* _Nonnull v3z);

/// Evaluate Nth derivative on BSpline curve within knot span.
void OCCTCurve3DBSplineLocalDN(OCCTCurve3DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               int32_t n,
                               double* _Nonnull vx,
                               double* _Nonnull vy,
                               double* _Nonnull vz);

// MARK: - v0.130.0: GeomEval Curves, GeomEval Surfaces, Geom2dEval Curves, GeomFill Gordon,
// PointSetLib, ExtremaPC

// --- GeomEval 3D Curve Evaluators ---

/// Evaluate a circular helix at parameter u. Returns point (px,py,pz).
/// Helix: C(t) = O + R*cos(t)*XDir + R*sin(t)*YDir + (P*t/(2*Pi))*ZDir
void OCCTGeomEvalCircularHelixD0(double radius,
                                 double pitch,
                                 double u,
                                 double* _Nonnull px,
                                 double* _Nonnull py,
                                 double* _Nonnull pz);

/// Evaluate circular helix D1: point + first derivative.
void OCCTGeomEvalCircularHelixD1(double radius,
                                 double pitch,
                                 double u,
                                 double* _Nonnull px,
                                 double* _Nonnull py,
                                 double* _Nonnull pz,
                                 double* _Nonnull vx,
                                 double* _Nonnull vy,
                                 double* _Nonnull vz);

/// Evaluate circular helix D2: point + first + second derivatives.
void OCCTGeomEvalCircularHelixD2(double radius,
                                 double pitch,
                                 double u,
                                 double* _Nonnull px,
                                 double* _Nonnull py,
                                 double* _Nonnull pz,
                                 double* _Nonnull d1x,
                                 double* _Nonnull d1y,
                                 double* _Nonnull d1z,
                                 double* _Nonnull d2x,
                                 double* _Nonnull d2y,
                                 double* _Nonnull d2z);

/// Create circular helix as OCCTCurve3DRef (Geom_Curve subclass). Returns NULL on error.
OCCTCurve3DRef _Nullable OCCTGeomEvalCircularHelixCurveCreate(double radius, double pitch);

/// Evaluate a 3D sine wave at parameter u. Returns point.
/// C(t) = O + t*XDir + A*sin(omega*t + phi)*YDir
void OCCTGeomEvalSineWaveD0(double amplitude,
                            double omega,
                            double phase,
                            double u,
                            double* _Nonnull px,
                            double* _Nonnull py,
                            double* _Nonnull pz);

/// Evaluate 3D sine wave D1: point + first derivative.
void OCCTGeomEvalSineWaveD1(double amplitude,
                            double omega,
                            double phase,
                            double u,
                            double* _Nonnull px,
                            double* _Nonnull py,
                            double* _Nonnull pz,
                            double* _Nonnull vx,
                            double* _Nonnull vy,
                            double* _Nonnull vz);

/// Create 3D sine wave as OCCTCurve3DRef. Returns NULL on error.
OCCTCurve3DRef _Nullable OCCTGeomEvalSineWaveCurveCreate(double amplitude,
                                                         double omega,
                                                         double phase);

// --- ExtremaPC (Point-Curve Extrema) ---

/// Find closest point on a Geom_Curve to a query point.
/// Returns number of extrema found (0 on failure).
/// outParams[i] = parameter on curve, outDistances[i] = distance.
int32_t OCCTExtremaPCCurve(OCCTCurve3DRef _Nonnull curve,
                           double px,
                           double py,
                           double pz,
                           double* _Nonnull outParams,
                           double* _Nonnull outDistances,
                           double* _Nonnull outPx,
                           double* _Nonnull outPy,
                           double* _Nonnull outPz,
                           int32_t maxResults);

/// Find closest point on a bounded Geom_Curve segment to a query point.
int32_t OCCTExtremaPCCurveBounded(OCCTCurve3DRef _Nonnull curve,
                                  double px,
                                  double py,
                                  double pz,
                                  double uMin,
                                  double uMax,
                                  double* _Nonnull outParams,
                                  double* _Nonnull outDistances,
                                  double* _Nonnull outPx,
                                  double* _Nonnull outPy,
                                  double* _Nonnull outPz,
                                  int32_t maxResults);

/// Find minimum distance from point to curve (convenience, returns distance, -1 on error).
double OCCTExtremaPCMinDistance(OCCTCurve3DRef _Nonnull curve, double px, double py, double pz);

/// Create a least-squares B-spline approximation solver.
/// points: flat [x,y,z,...], count = number of 3D points.
/// nbControlPts and continuousIfClosed are advisory and currently ignored (see section note);
/// degree widens the fit's degree range to [min(3, degree), max(degree, 8)].
OCCTBSplineApproxInterpRef _Nullable OCCTBSplineApproxInterpCreate(const double* _Nonnull points,
                                                                   int32_t count,
                                                                   int32_t nbControlPts,
                                                                   int32_t degree,
                                                                   bool    continuousIfClosed);

/// Release the solver.
void OCCTBSplineApproxInterpRelease(OCCTBSplineApproxInterpRef _Nonnull ref);

/// No-op. Originally: mark a point to be exactly interpolated (0-based index), withKink
/// inserting a C0 break. GeomAPI_PointsToBSpline has no per-point exact-interpolation or
/// kink control; the approximation still passes near every input point.
void OCCTBSplineApproxInterpInterpolatePoint(OCCTBSplineApproxInterpRef _Nonnull ref,
                                             int32_t pointIndex,
                                             bool    withKink);

/// Perform the fit using auto-computed parameters.
void OCCTBSplineApproxInterpPerform(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Perform the fit. Identical to OCCTBSplineApproxInterpPerform: GeomAPI_PointsToBSpline
/// has no iterative parameter-optimization mode, so maxIter is ignored.
void OCCTBSplineApproxInterpPerformOptimal(OCCTBSplineApproxInterpRef _Nonnull ref,
                                           int32_t maxIter);

/// Returns true if the fit was computed successfully.
bool OCCTBSplineApproxInterpIsDone(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Returns the resulting curve, or null if not done.
OCCTCurve3DRef _Nullable OCCTBSplineApproxInterpCurve(OCCTBSplineApproxInterpRef _Nonnull ref);

/// Returns the maximum approximation error: the largest distance from an input point to its
/// projection on the fitted curve. -1 if the fit has not run or did not succeed.
double OCCTBSplineApproxInterpMaxError(OCCTBSplineApproxInterpRef _Nonnull ref);

/// No-op. Originally: set parametrization alpha (0=uniform, 0.5=centripetal, 1=chord-length).
/// GeomAPI_PointsToBSpline takes an Approx_ParametrizationType, not an alpha, and the bridge
/// does not currently forward one.
void OCCTBSplineApproxInterpSetAlpha(OCCTBSplineApproxInterpRef _Nonnull ref, double alpha);

/// No-op. Originally: set the minimum pivot value for the Gauss solver (default 1e-20).
/// GeomAPI_PointsToBSpline exposes no solver internals.
void OCCTBSplineApproxInterpSetMinPivot(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// No-op. Originally: set the closed-curve detection tolerance (default 1e-12).
/// GeomAPI_PointsToBSpline has no closed-curve detection to tune.
void OCCTBSplineApproxInterpSetClosedTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// No-op. Originally: set the knot insertion tolerance (default 1e-4). Knot insertion was
/// part of the removed solver's kink handling, which no longer exists.
void OCCTBSplineApproxInterpSetKnotTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Set the 3D fit tolerance (default 1e-3). Values <= 0 are ignored.
void OCCTBSplineApproxInterpSetConvergenceTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

/// Tighten the 3D fit tolerance to min(current, val) (default 1e-6). Values <= 0 are ignored.
/// Note this shares one tolerance with OCCTBSplineApproxInterpSetConvergenceTol; the two are
/// not independent knobs.
void OCCTBSplineApproxInterpSetProjectionTol(OCCTBSplineApproxInterpRef _Nonnull ref, double val);

// --- GeomAdaptor_TransformedCurve ---

/// Create a transformed curve adaptor: wraps a Geom_Curve with a translation.
/// Returns a new Curve3D that evaluates the curve with the transform applied.
OCCTCurve3DRef _Nullable OCCTGeomAdaptorTransformedCurveCreate(OCCTCurve3DRef _Nonnull curve,
                                                               double tx,
                                                               double ty,
                                                               double tz);

// --- GeomEval TBezier / AHTBezier Curves ---

/// Create a 3D Trigonometric Bezier curve. poles: flat [x,y,z,...], count must be odd >= 3.
OCCTCurve3DRef _Nullable OCCTGeomEvalTBezierCurveCreate(const double* _Nonnull poles,
                                                        int32_t count,
                                                        double  alpha);

/// Create a 3D rational Trigonometric Bezier curve.
OCCTCurve3DRef _Nullable OCCTGeomEvalTBezierCurveCreateRational(const double* _Nonnull poles,
                                                                const double* _Nonnull weights,
                                                                int32_t count,
                                                                double  alpha);

/// Create a 3D AHT Bezier curve. count = algDeg+1 + 2*(alpha>0) + 2*(beta>0).
OCCTCurve3DRef _Nullable OCCTGeomEvalAHTBezierCurveCreate(const double* _Nonnull poles,
                                                          int32_t count,
                                                          int32_t algDegree,
                                                          double  alpha,
                                                          double  beta);

/// Create a 3D rational AHT Bezier curve.
OCCTCurve3DRef _Nullable OCCTGeomEvalAHTBezierCurveCreateRational(const double* _Nonnull poles,
                                                                  const double* _Nonnull weights,
                                                                  int32_t count,
                                                                  int32_t algDegree,
                                                                  double  alpha,
                                                                  double  beta);

#endif /* OCCTBridge_Curve3D_h */
