//
//  OCCTBridge_Geom2d.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Geom2d domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Geom2d_h
#define OCCTBridge_Geom2d_h

void OCCTCurve2DRelease(OCCTCurve2DRef curve);

// Properties
void   OCCTCurve2DGetDomain(OCCTCurve2DRef curve, double* first, double* last);
bool   OCCTCurve2DIsClosed(OCCTCurve2DRef curve);
bool   OCCTCurve2DIsPeriodic(OCCTCurve2DRef curve);
double OCCTCurve2DGetPeriod(OCCTCurve2DRef curve);

// Evaluation
void OCCTCurve2DGetPoint(OCCTCurve2DRef curve, double u, double* x, double* y);
void OCCTCurve2DD1(OCCTCurve2DRef curve, double u, double* px, double* py, double* vx, double* vy);
void OCCTCurve2DD2(OCCTCurve2DRef curve,
                   double         u,
                   double*        px,
                   double*        py,
                   double*        v1x,
                   double*        v1y,
                   double*        v2x,
                   double*        v2y);

// Primitives
OCCTCurve2DRef OCCTCurve2DCreateLine(double px, double py, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DCreateSegment(double p1x, double p1y, double p2x, double p2y);
OCCTCurve2DRef OCCTCurve2DCreateCircle(double cx, double cy, double radius);
OCCTCurve2DRef OCCTCurve2DCreateArcOfCircle(double cx,
                                            double cy,
                                            double radius,
                                            double startAngle,
                                            double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcThrough(double p1x,
                                           double p1y,
                                           double p2x,
                                           double p2y,
                                           double p3x,
                                           double p3y);
OCCTCurve2DRef OCCTCurve2DCreateEllipse(double cx,
                                        double cy,
                                        double majorR,
                                        double minorR,
                                        double rotation);
OCCTCurve2DRef OCCTCurve2DCreateArcOfEllipse(double cx,
                                             double cy,
                                             double majorR,
                                             double minorR,
                                             double rotation,
                                             double startAngle,
                                             double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateParabola(double fx, double fy, double dx, double dy, double focal);
OCCTCurve2DRef OCCTCurve2DCreateHyperbola(double cx,
                                          double cy,
                                          double majorR,
                                          double minorR,
                                          double rotation);

// Draw (discretization for Metal)
int32_t OCCTCurve2DDrawAdaptive(OCCTCurve2DRef curve,
                                double         angularDefl,
                                double         chordalDefl,
                                double*        outXY,
                                int32_t        maxPoints);
int32_t OCCTCurve2DDrawUniform(OCCTCurve2DRef curve, int32_t pointCount, double* outXY);
int32_t OCCTCurve2DDrawDeflection(OCCTCurve2DRef curve,
                                  double         deflection,
                                  double*        outXY,
                                  int32_t        maxPoints);

// BSpline & Bezier
OCCTCurve2DRef OCCTCurve2DCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  weights,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree);
OCCTCurve2DRef OCCTCurve2DCreateBezier(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights);

// Interpolation & Fitting
OCCTCurve2DRef OCCTCurve2DInterpolate(const double* points,
                                      int32_t       count,
                                      bool          closed,
                                      double        tolerance);
OCCTCurve2DRef OCCTCurve2DInterpolateWithTangents(const double* points,
                                                  int32_t       count,
                                                  double        stx,
                                                  double        sty,
                                                  double        etx,
                                                  double        ety,
                                                  double        tolerance);
OCCTCurve2DRef OCCTCurve2DFitPoints(const double* points,
                                    int32_t       count,
                                    int32_t       minDeg,
                                    int32_t       maxDeg,
                                    double        tolerance);

// BSpline queries
int32_t OCCTCurve2DGetPoleCount(OCCTCurve2DRef curve);
int32_t OCCTCurve2DGetPoles(OCCTCurve2DRef curve, double* outXY);
int32_t OCCTCurve2DGetDegree(OCCTCurve2DRef curve);

// Operations
OCCTCurve2DRef OCCTCurve2DTrim(OCCTCurve2DRef curve, double u1, double u2);
OCCTCurve2DRef OCCTCurve2DOffset(OCCTCurve2DRef curve, double distance);
OCCTCurve2DRef OCCTCurve2DReversed(OCCTCurve2DRef curve);
OCCTCurve2DRef OCCTCurve2DTranslate(OCCTCurve2DRef curve, double dx, double dy);
OCCTCurve2DRef OCCTCurve2DRotate(OCCTCurve2DRef curve, double cx, double cy, double angle);
OCCTCurve2DRef OCCTCurve2DScale(OCCTCurve2DRef curve, double cx, double cy, double factor);
OCCTCurve2DRef OCCTCurve2DMirrorAxis(OCCTCurve2DRef curve,
                                     double         px,
                                     double         py,
                                     double         dx,
                                     double         dy);
OCCTCurve2DRef OCCTCurve2DMirrorPoint(OCCTCurve2DRef curve, double px, double py);
double         OCCTCurve2DGetLength(OCCTCurve2DRef curve);
double         OCCTCurve2DGetLengthBetween(OCCTCurve2DRef curve, double u1, double u2);

// Intersection
typedef struct
{
  double x, y, u1, u2;
} OCCTCurve2DIntersection;

int32_t OCCTCurve2DIntersect(OCCTCurve2DRef           c1,
                             OCCTCurve2DRef           c2,
                             double                   tolerance,
                             OCCTCurve2DIntersection* out,
                             int32_t                  max);
int32_t OCCTCurve2DSelfIntersect(OCCTCurve2DRef           curve,
                                 double                   tolerance,
                                 OCCTCurve2DIntersection* out,
                                 int32_t                  max);

// Projection
typedef struct
{
  double x, y, parameter, distance;
} OCCTCurve2DProjection;

/// Project a point onto a curve, nearest solution only.
/// @return Projection with `distance >= 0` on success; on failure `distance` is -1 and the
///         other fields are zeroed. The answer is the nearest point over the curve's own range,
///         ends included, so a point with no perpendicular foot (one beyond the ends of a bounded
///         curve, or a circle's centre) is answered rather than refused; -1 means there was no
///         curve to answer about (#615). OCCTCurve2DProjectPointAll asks for the extrema instead,
///         and still reports none for those points.
OCCTCurve2DProjection OCCTCurve2DProjectPoint(OCCTCurve2DRef curve, double px, double py);
/// Project a point onto a curve, all local-minimum solutions.
/// @return Number of solutions written to `out` (0 if there are none).
int32_t OCCTCurve2DProjectPointAll(OCCTCurve2DRef         curve,
                                   double                 px,
                                   double                 py,
                                   OCCTCurve2DProjection* out,
                                   int32_t                max);

// Extrema
typedef struct
{
  double p1x, p1y, p2x, p2y, u1, u2, distance;
} OCCTCurve2DExtrema;

OCCTCurve2DExtrema OCCTCurve2DMinDistance(OCCTCurve2DRef c1, OCCTCurve2DRef c2);
int32_t            OCCTCurve2DAllExtrema(OCCTCurve2DRef      c1,
                                         OCCTCurve2DRef      c2,
                                         OCCTCurve2DExtrema* out,
                                         int32_t             max);

// Conversion

/// Parameterisation applied when a conic is rewritten as a B-spline.
/// Mirrors Convert_ParameterisationType. Every value except OCCTParameterisationPolynomial is
/// exact; Polynomial approximates, which is what its own OCCT documentation says and what the
/// measurement in Scripts/repro/999-geom2d-curve3d-healing shows (6.5e-06 relative radial error
/// against ~1e-16 for the rest).
typedef enum
{
  OCCTParameterisationTgtThetaOver2   = 0,
  OCCTParameterisationTgtThetaOver2_1 = 1,
  OCCTParameterisationTgtThetaOver2_2 = 2,
  OCCTParameterisationTgtThetaOver2_3 = 3,
  OCCTParameterisationTgtThetaOver2_4 = 4,
  OCCTParameterisationQuasiAngular    = 5,
  OCCTParameterisationRationalC1      = 6,
  OCCTParameterisationPolynomial      = 7
} OCCTParameterisationType;

/// Convert a 2D curve to a B-spline.
/// Takes a parameterisation rather than a tolerance (#999): Geom2dConvert::CurveToBSplineCurve
/// has no tolerance, the conversion being exact for every type but Polynomial, and the
/// parameterisation is the knob it does have. Returns NULL when OCCT rejects the pairing, which
/// includes TgtThetaOver2_1 / _2 on an arc whose opening angle exceeds their documented limits,
/// and any type on an unbounded curve.
OCCTCurve2DRef OCCTCurve2DToBSpline(OCCTCurve2DRef           curve,
                                    OCCTParameterisationType parameterisation);
int32_t        OCCTCurve2DBSplineToBeziers(OCCTCurve2DRef curve, OCCTCurve2DRef* out, int32_t max);
void           OCCTCurve2DFreeArray(OCCTCurve2DRef* curves, int32_t count);
OCCTCurve2DRef OCCTCurve2DJoinToBSpline(const OCCTCurve2DRef* curves,
                                        int32_t               count,
                                        double                tolerance);

// Local Properties (Geom2dLProp)

/// Get curvature at parameter u. Returns true if the curvature exists there: false for a null
/// curve, a parameter that cannot be evaluated, and a point where IsTangentDefined() is false.
/// A cusp still reports true with OCCT's RealLast() infinity sentinel, which is an answer (#595).
bool OCCTCurve2DGetCurvature(OCCTCurve2DRef curve, double u, double* _Nonnull curvature);
bool OCCTCurve2DGetNormal(OCCTCurve2DRef curve, double u, double* nx, double* ny);
bool OCCTCurve2DGetTangentDir(OCCTCurve2DRef curve, double u, double* tx, double* ty);
bool OCCTCurve2DGetCenterOfCurvature(OCCTCurve2DRef curve, double u, double* cx, double* cy);

/// Curve inflection/curvature result type: 0=Inflection, 1=MinCurvature, 2=MaxCurvature
typedef struct
{
  double  parameter;
  int32_t type;
} OCCTCurve2DCurvePoint;

int32_t OCCTCurve2DGetInflectionPoints(OCCTCurve2DRef curve, double* outParams, int32_t max);
int32_t OCCTCurve2DGetCurvatureExtrema(OCCTCurve2DRef         curve,
                                       OCCTCurve2DCurvePoint* out,
                                       int32_t                max);
int32_t OCCTCurve2DGetAllSpecialPoints(OCCTCurve2DRef         curve,
                                       OCCTCurve2DCurvePoint* out,
                                       int32_t                max);

// Bounding Box
bool OCCTCurve2DGetBoundingBox(OCCTCurve2DRef curve,
                               double*        xMin,
                               double*        yMin,
                               double*        xMax,
                               double*        yMax);

// Additional Arc Types
OCCTCurve2DRef OCCTCurve2DCreateArcOfHyperbola(double cx,
                                               double cy,
                                               double majorR,
                                               double minorR,
                                               double rotation,
                                               double startAngle,
                                               double endAngle);
OCCTCurve2DRef OCCTCurve2DCreateArcOfParabola(double fx,
                                              double fy,
                                              double dx,
                                              double dy,
                                              double focal,
                                              double startParam,
                                              double endParam);

// Conversion Extras
OCCTCurve2DRef OCCTCurve2DApproximate(OCCTCurve2DRef curve,
                                      double         tolerance,
                                      int32_t        continuity,
                                      int32_t        maxSegments,
                                      int32_t        maxDegree);
// `continuity` is a ContinuityRange (a literal derivative order, splitting where
// `degree - multiplicity < continuity`), not a GeomAbs_Shape. See the #480 note in
// OCCTBridge_Internal.h. Returns the TRUE split count even when writing was truncated by `max`, so
// a caller that came up short can retry at the size it was just told, the #481 contract the rest
// of this family already shares. It used to return the count it had written, which is
// indistinguishable from a curve with exactly `max` splits (#562).
int32_t OCCTCurve2DSplitAtDiscontinuities(OCCTCurve2DRef curve,
                                          int32_t        continuity,
                                          int32_t*       outKnotIndices,
                                          int32_t        max);
int32_t OCCTCurve2DToArcsAndSegments(OCCTCurve2DRef  curve,
                                     double          tolerance,
                                     double          angleTol,
                                     OCCTCurve2DRef* out,
                                     int32_t         max);

// Issue #37, parameter at arc length
/// Returns the curve parameter at the given arc-length distance from fromParam.
/// Pass the curve's FirstParameter() as fromParam to measure from the start.
/// Returns -DBL_MAX on failure.
double OCCTCurve2DParameterAtLength(OCCTCurve2DRef curve, double arcLength, double fromParam);

// Issue #38, interpolate with interior tangent constraints
/// Interpolate through points with per-point tangent constraints.
/// tangents: flat array of (tx, ty) pairs, one per point.
/// tangentFlags: one bool per point; true means the tangent at that index is constrained.
/// Returns NULL on failure.
OCCTCurve2DRef OCCTCurve2DInterpolateWithInteriorTangents(const double* points,
                                                          int32_t       count,
                                                          const double* tangents,
                                                          const bool*   tangentFlags,
                                                          bool          closed,
                                                          double        tolerance);

// Gcc Constraint Solver. Qualifier enum
typedef enum
{
  OCCTGccQualUnqualified = 0,
  OCCTGccQualEnclosing   = 1,
  OCCTGccQualEnclosed    = 2,
  OCCTGccQualOutside     = 3
} OCCTGccQualifier;

/// Circle tangent solution result
typedef struct
{
  double  cx, cy, radius;
  int32_t qualifier;
} OCCTGccCircleSolution;

/// Line tangent solution result
typedef struct
{
  double  px, py, dx, dy;
  int32_t qualifier;
} OCCTGccLineSolution;

// Gcc Circle Construction
int32_t OCCTGccCircle2d3Tan(OCCTCurve2DRef         c1,
                            int32_t                q1,
                            OCCTCurve2DRef         c2,
                            int32_t                q2,
                            OCCTCurve2DRef         c3,
                            int32_t                q3,
                            double                 tolerance,
                            OCCTGccCircleSolution* out,
                            int32_t                max);
int32_t OCCTGccCircle2d2TanPt(OCCTCurve2DRef         c1,
                              int32_t                q1,
                              OCCTCurve2DRef         c2,
                              int32_t                q2,
                              double                 px,
                              double                 py,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max);
int32_t OCCTGccCircle2dTanCen(OCCTCurve2DRef         curve,
                              int32_t                qualifier,
                              double                 cx,
                              double                 cy,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max);
int32_t OCCTGccCircle2d2TanRad(OCCTCurve2DRef         c1,
                               int32_t                q1,
                               OCCTCurve2DRef         c2,
                               int32_t                q2,
                               double                 radius,
                               double                 tolerance,
                               OCCTGccCircleSolution* out,
                               int32_t                max);
int32_t OCCTGccCircle2dTanPtRad(OCCTCurve2DRef         curve,
                                int32_t                qualifier,
                                double                 px,
                                double                 py,
                                double                 radius,
                                double                 tolerance,
                                OCCTGccCircleSolution* out,
                                int32_t                max);
int32_t OCCTGccCircle2d2PtRad(double                 p1x,
                              double                 p1y,
                              double                 p2x,
                              double                 p2y,
                              double                 radius,
                              double                 tolerance,
                              OCCTGccCircleSolution* out,
                              int32_t                max);
int32_t OCCTGccCircle2d3Pt(double                 p1x,
                           double                 p1y,
                           double                 p2x,
                           double                 p2y,
                           double                 p3x,
                           double                 p3y,
                           double                 tolerance,
                           OCCTGccCircleSolution* out,
                           int32_t                max);

// Gcc Line Construction
int32_t OCCTGccLine2d2Tan(OCCTCurve2DRef       c1,
                          int32_t              q1,
                          OCCTCurve2DRef       c2,
                          int32_t              q2,
                          double               tolerance,
                          OCCTGccLineSolution* out,
                          int32_t              max);
int32_t OCCTGccLine2dTanPt(OCCTCurve2DRef       curve,
                           int32_t              qualifier,
                           double               px,
                           double               py,
                           double               tolerance,
                           OCCTGccLineSolution* out,
                           int32_t              max);

// Hatching
int32_t OCCTCurve2DHatch(const OCCTCurve2DRef* boundaries,
                         int32_t               boundaryCount,
                         double                originX,
                         double                originY,
                         double                dirX,
                         double                dirY,
                         double                spacing,
                         double                tolerance,
                         double*               outXY,
                         int32_t               maxPoints);

// Bisector
OCCTCurve2DRef OCCTCurve2DBisectorCC(OCCTCurve2DRef c1,
                                     OCCTCurve2DRef c2,
                                     double         originX,
                                     double         originY,
                                     bool           side);
/// Bisector between a point and a curve.
/// Takes a trimming distance rather than an origin (#999): Bisector_BisecPC::Perform is
/// (Cu, P, Side, DistMax) with no origin at all, unlike Bisector_BisecCC::Perform above, whose
/// origin this signature had been copied from. DistMax bounds the distance from the bisector back
/// to the curve, and 500 is OCCT's own default.
OCCTCurve2DRef OCCTCurve2DBisectorPC(double         px,
                                     double         py,
                                     OCCTCurve2DRef curve,
                                     double         maxDistance,
                                     bool           side);

/// Node in the medial axis graph: position (x,y) and distance to boundary.
typedef struct
{
  int32_t index;
  double  x;
  double  y;
  double  distance;  // inscribed circle radius at this node
  bool    isPending; // true if node has only one linked arc (endpoint)
  bool    isOnBoundary;
} OCCTMedialAxisNode;

/// Arc in the medial axis graph: connects two nodes, separates two boundary elements.
typedef struct
{
  int32_t index;
  int32_t geomIndex;
  int32_t firstNodeIndex;
  int32_t secondNodeIndex;
  int32_t firstEltIndex;
  int32_t secondEltIndex;
} OCCTMedialAxisArc;

/// Compute the medial axis of a planar face.
/// The shape must contain at least one face; the first face is used.
/// Returns NULL on failure.
/// No tolerance (#999): neither BRepMAT2d_Explorer::Perform(face) nor
/// BRepMAT2d_BisectingLocus::Compute takes one. Compute's own knobs, all fixed here at OCCT's
/// defaults, are LineIndex, aSide (MAT_Left / MAT_Right), aJoinType and IsOpenResult; exposing any
/// of them is a new capability rather than a repair of this signature.
OCCTMedialAxisRef OCCTMedialAxisCompute(OCCTShapeRef shape);

/// Release a medial axis computation.
void OCCTMedialAxisRelease(OCCTMedialAxisRef ma);

/// Get the number of arcs (bisector curves) in the medial axis graph.
int32_t OCCTMedialAxisGetArcCount(OCCTMedialAxisRef ma);

/// Get the number of nodes (arc endpoints) in the medial axis graph.
int32_t OCCTMedialAxisGetNodeCount(OCCTMedialAxisRef ma);

/// Get information about a node by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetNode(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisNode* outNode);

/// Get information about an arc by index (1-based).
/// Returns true on success.
bool OCCTMedialAxisGetArc(OCCTMedialAxisRef ma, int32_t index, OCCTMedialAxisArc* outArc);

/// Sample points along a bisector arc. Returns the number of points written.
/// Points are written as (x,y) pairs into outXY (so outXY needs 2*maxPoints capacity).
/// index is 1-based.
int32_t OCCTMedialAxisDrawArc(OCCTMedialAxisRef ma,
                              int32_t           arcIndex,
                              double*           outXY,
                              int32_t           maxPoints);

/// Sample all bisector arcs. Returns total number of points written.
/// outXY receives (x,y) pairs. lineStarts receives the starting index in outXY
/// for each arc. maxLines should be >= arc count.
int32_t OCCTMedialAxisDrawAll(OCCTMedialAxisRef ma,
                              double*           outXY,
                              int32_t           maxPoints,
                              int32_t*          lineStarts,
                              int32_t*          lineLengths,
                              int32_t           maxLines);

/// Get the inscribed circle distance (radius) at a point along an arc.
/// arcIndex is 1-based, t is in [0,1] where 0=firstNode, 1=secondNode.
double OCCTMedialAxisDistanceOnArc(OCCTMedialAxisRef ma, int32_t arcIndex, double t);

/// Get the minimum distance (half-thickness) across the entire medial axis.
/// Returns the smallest inscribed circle radius found at any node.
double OCCTMedialAxisMinThickness(OCCTMedialAxisRef ma);

/// Get the number of boundary elements (input edges) in the medial axis.
int32_t OCCTMedialAxisGetBasicEltCount(OCCTMedialAxisRef ma);

// MARK: - Batch Curve2D Evaluation (v0.28.0)
//
// One of the six batch grid-evaluation entry points. See the family contract documented
// above OCCTCurve3DEvaluateGrid.

/// Evaluate a 2D curve at multiple parameter values (batch).
/// @param curve The curve to evaluate
/// @param params Array of parameter values
/// @param paramCount Number of parameters
/// @param outXY Output buffer for xy pairs, interleaved: outXY[i * 2 + {0,1}]
///              (must hold 2 * paramCount doubles)
/// @return Number of points evaluated (paramCount on success, 0 on failure)
int32_t OCCTCurve2DEvaluateGrid(OCCTCurve2DRef curve,
                                const double*  params,
                                int32_t        paramCount,
                                double*        outXY);

/// Evaluate a 2D curve and its first derivative at multiple parameters (batch).
/// @param outXY Output buffer for point xy pairs, interleaved (2 * paramCount doubles)
/// @param outDXDY Output buffer for derivative xy pairs, interleaved (2 * paramCount doubles)
/// @return Number of points evaluated (paramCount on success, 0 on failure)
int32_t OCCTCurve2DEvaluateGridD1(OCCTCurve2DRef curve,
                                  const double*  params,
                                  int32_t        paramCount,
                                  double*        outXY,
                                  double*        outDXDY);

// MARK: - Hatch Patterns (v0.29.0)

/// Generate hatch line segments within a 2D polygon boundary.
/// @param boundaryXY Flat array of (x,y) pairs defining the boundary polygon
/// @param boundaryCount Number of boundary points
/// @param dirX, dirY Hatch line direction
/// @param spacing Distance between hatch lines
/// @param offset Offset of the first hatch line from origin
/// @param outSegments Output buffer: pairs of (x1,y1,x2,y2) per segment (4 doubles each)
/// @param maxSegments Maximum number of output segments
/// @return Number of segments written
int32_t OCCTHatchLines(const double* boundaryXY,
                       int32_t       boundaryCount,
                       double        dirX,
                       double        dirY,
                       double        spacing,
                       double        offset,
                       double*       outSegments,
                       int32_t       maxSegments);

// --- GC_MakeLine2d ---

/// Create a 2D infinite line through two points.
/// @param p1x,p1y First point
/// @param p2x,p2y Second point
/// @return 2D line curve, or NULL if points coincide
OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineThroughPoints(double p1x,
                                                          double p1y,
                                                          double p2x,
                                                          double p2y);

/// Create a 2D line parallel to another at a given distance.
/// @param px,py Point on reference line
/// @param dx,dy Direction of reference line
/// @param distance Signed distance to offset
/// @return 2D line curve, or NULL on failure
OCCTCurve2DRef _Nullable OCCTCurve2DMakeLineParallel(double px,
                                                     double py,
                                                     double dx,
                                                     double dy,
                                                     double distance);

// --- ShapeCustom_Curve2d ---

/// Check if a 2D curve's control points are collinear (i.e., nearly linear).
/// @param curve2D The 2D curve to check
/// @param tolerance Maximum deviation to consider as linear
/// @param deviation Output: actual maximum deviation from line
/// @return true if the curve is linear within tolerance
bool OCCTCurve2DIsLinear(OCCTCurve2DRef curve2D, double tolerance, double* deviation);

/// Convert a nearly-linear 2D curve to a Geom2d_Line.
/// @param curve2D The 2D curve to convert
/// @param first First parameter
/// @param last Last parameter
/// @param tolerance Maximum deviation tolerance
/// @param newFirst Output: new first parameter on line
/// @param newLast Output: new last parameter on line
/// @param deviation Output: actual deviation
/// @return Converted 2D line curve, or NULL if not linear
OCCTCurve2DRef _Nullable OCCTCurve2DConvertToLine(OCCTCurve2DRef curve2D,
                                                  double         first,
                                                  double         last,
                                                  double         tolerance,
                                                  double*        newFirst,
                                                  double*        newLast,
                                                  double*        deviation);

/// Simplify a 2D BSpline curve by removing unnecessary knots.
/// @param curve2D The 2D BSpline curve to simplify
/// @param tolerance Simplification tolerance
/// @return true if the curve was simplified
bool OCCTCurve2DSimplifyBSpline(OCCTCurve2DRef curve2D, double tolerance);

// --- Approx_Curve2d ---

/// Approximate a 2D curve as a BSpline.
/// @param curve2D The 2D curve to approximate
/// @param first First parameter
/// @param last Last parameter
/// @param tolU Tolerance in U
/// @param tolV Tolerance in V
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum number of segments
/// @return Approximated 2D BSpline curve, or NULL on failure
OCCTCurve2DRef _Nullable OCCTApproxCurve2d(OCCTCurve2DRef curve2D,
                                           double         first,
                                           double         last,
                                           double         tolU,
                                           double         tolV,
                                           int32_t        maxDegree,
                                           int32_t        maxSegments);

// ============================================================================
// MARK: - v0.53.0: 2D Geometry Completions
// ============================================================================

// --- GccAna Bisectors ---

/// Bisector result type
typedef enum
{
  OCCTBisecTypeLine      = 0,
  OCCTBisecTypeCircle    = 1,
  OCCTBisecTypeEllipse   = 2,
  OCCTBisecTypeHyperbola = 3,
  OCCTBisecTypeParabola  = 4,
  OCCTBisecTypePoint     = 5
} OCCTBisecType;

/// Bisector solution (stores the type and curve if applicable)
typedef struct
{
  OCCTBisecType type;
  /// For line: (px, py) is a point on it, (dx, dy) is its direction
  /// For circle: (px, py) is center, radius is radius
  /// For point: (px, py) is the point, others are 0
  /// For conics: (px, py) is focus/center, radius is semi-axis
  double px, py, dx, dy, radius;
} OCCTBisecSolution;

/// Perpendicular bisector between two points.
/// @return true if a solution exists
bool OCCTGccAnaPnt2dBisec(double  p1x,
                          double  p1y,
                          double  p2x,
                          double  p2y,
                          double* outPx,
                          double* outPy,
                          double* outDx,
                          double* outDy);

/// Angle bisectors between two lines.
/// @param l1px, l1py, l1dx, l1dy First line (point + direction)
/// @param l2px, l2py, l2dx, l2dy Second line (point + direction)
/// @param out Output array for line solutions
/// @param max Max solutions to return
/// @return Number of solutions
int32_t OCCTGccAnaLin2dBisec(double               l1px,
                             double               l1py,
                             double               l1dx,
                             double               l1dy,
                             double               l2px,
                             double               l2py,
                             double               l2dx,
                             double               l2dy,
                             OCCTGccLineSolution* out,
                             int32_t              max);

/// Bisector between a line and a point (returns a parabola as GccInt_Bisec).
/// @return Bisector type, with properties stored in solution
bool OCCTGccAnaLinPnt2dBisec(double             lpx,
                             double             lpy,
                             double             ldx,
                             double             ldy,
                             double             px,
                             double             py,
                             OCCTBisecSolution* out);

/// Bisectors between two circles.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2dBisec(double             c1x,
                              double             c1y,
                              double             c1r,
                              double             c2x,
                              double             c2y,
                              double             c2r,
                              OCCTBisecSolution* out,
                              int32_t            max);

/// Bisectors between a circle and a line.
/// @return Number of solutions
int32_t OCCTGccAnaCircLin2dBisec(double             cx,
                                 double             cy,
                                 double             cr,
                                 double             lpx,
                                 double             lpy,
                                 double             ldx,
                                 double             ldy,
                                 OCCTBisecSolution* out,
                                 int32_t            max);

/// Bisectors between a circle and a point.
/// @return Number of solutions
int32_t OCCTGccAnaCircPnt2dBisec(double             cx,
                                 double             cy,
                                 double             cr,
                                 double             px,
                                 double             py,
                                 OCCTBisecSolution* out,
                                 int32_t            max);

// --- GccAna Line Solvers ---

/// Line through a point parallel to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanParPt(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                OCCTGccLineSolution* out,
                                int32_t              max);

/// Line tangent to a circle, parallel to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanParCirc(double               cx,
                                  double               cy,
                                  double               cr,
                                  int32_t              qualifier,
                                  double               lpx,
                                  double               lpy,
                                  double               ldx,
                                  double               ldy,
                                  OCCTGccLineSolution* out,
                                  int32_t              max);

/// Line through a point perpendicular to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanPerPtLin(double               px,
                                   double               py,
                                   double               lpx,
                                   double               lpy,
                                   double               ldx,
                                   double               ldy,
                                   OCCTGccLineSolution* out,
                                   int32_t              max);

/// Line tangent to a circle, perpendicular to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanPerCircLin(double               cx,
                                     double               cy,
                                     double               cr,
                                     int32_t              qualifier,
                                     double               lpx,
                                     double               lpy,
                                     double               ldx,
                                     double               ldy,
                                     OCCTGccLineSolution* out,
                                     int32_t              max);

/// Line through a point at an angle to a reference line.
/// @return Number of solutions
int32_t OCCTGccAnaLin2dTanOblPt(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                double               angle,
                                OCCTGccLineSolution* out,
                                int32_t              max);

/// Line tangent to a curve at an angle to a reference line (Geom2dGcc version).
/// @return Number of solutions
int32_t OCCTGeom2dGccLin2dTanObl(OCCTCurve2DRef       curve,
                                 int32_t              qualifier,
                                 double               lpx,
                                 double               lpy,
                                 double               ldx,
                                 double               ldy,
                                 double               tolerance,
                                 double               angle,
                                 OCCTGccLineSolution* out,
                                 int32_t              max);

// --- GccAna Circle Solvers ---

/// Circle tangent to 2 lines, center on a line.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2d2TanOnLinLin(double                 l1px,
                                     double                 l1py,
                                     double                 l1dx,
                                     double                 l1dy,
                                     int32_t                q1,
                                     double                 l2px,
                                     double                 l2py,
                                     double                 l2dx,
                                     double                 l2dy,
                                     int32_t                q2,
                                     double                 onPx,
                                     double                 onPy,
                                     double                 onDx,
                                     double                 onDy,
                                     double                 tolerance,
                                     OCCTGccCircleSolution* out,
                                     int32_t                max);

/// Circle tangent to line, center on line, given radius.
/// @return Number of solutions
int32_t OCCTGccAnaCirc2dTanOnRadLin(double                 lpx,
                                    double                 lpy,
                                    double                 ldx,
                                    double                 ldy,
                                    int32_t                qualifier,
                                    double                 onPx,
                                    double                 onPy,
                                    double                 onDx,
                                    double                 onDy,
                                    double                 radius,
                                    double                 tolerance,
                                    OCCTGccCircleSolution* out,
                                    int32_t                max);

// --- Geom2dGcc Circle Solvers ---

/// Circle tangent to 2 curves, center on curve (Geom2dGcc).
/// @return Number of solutions
int32_t OCCTGeom2dGccCirc2d2TanOn(OCCTCurve2DRef         c1,
                                  int32_t                q1,
                                  OCCTCurve2DRef         c2,
                                  int32_t                q2,
                                  OCCTCurve2DRef         onCurve,
                                  double                 tolerance,
                                  double                 initParam1,
                                  double                 initParam2,
                                  double                 initParamOn,
                                  OCCTGccCircleSolution* out,
                                  int32_t                max);

/// Circle tangent to curve, center on curve, given radius (Geom2dGcc).
/// @return Number of solutions
int32_t OCCTGeom2dGccCirc2dTanOnRad(OCCTCurve2DRef         curve,
                                    int32_t                qualifier,
                                    OCCTCurve2DRef         onCurve,
                                    double                 radius,
                                    double                 tolerance,
                                    OCCTGccCircleSolution* out,
                                    int32_t                max);

// --- IntAna2d_AnaIntersection ---

/// 2D intersection point result
typedef struct
{
  double x, y;   ///< Intersection point
  double param1; ///< Parameter on first curve
  double param2; ///< Parameter on second curve
} OCCTIntAna2dPoint;

/// Intersect two 2D lines.
/// @return Number of intersection points
int32_t OCCTIntAna2dLinLin(double             l1px,
                           double             l1py,
                           double             l1dx,
                           double             l1dy,
                           double             l2px,
                           double             l2py,
                           double             l2dx,
                           double             l2dy,
                           OCCTIntAna2dPoint* out,
                           int32_t            max);

/// Intersect a 2D line and circle.
/// @return Number of intersection points
int32_t OCCTIntAna2dLinCirc(double             lpx,
                            double             lpy,
                            double             ldx,
                            double             ldy,
                            double             cx,
                            double             cy,
                            double             cr,
                            OCCTIntAna2dPoint* out,
                            int32_t            max);

/// Intersect two 2D circles.
/// @return Number of intersection points
int32_t OCCTIntAna2dCircCirc(double             c1x,
                             double             c1y,
                             double             c1r,
                             double             c2x,
                             double             c2y,
                             double             c2r,
                             OCCTIntAna2dPoint* out,
                             int32_t            max);

// --- Extrema 2D ---

/// 2D extrema result point
typedef struct
{
  double squareDistance;
  double param1;   ///< Parameter on first curve
  double param2;   ///< Parameter on second curve
  double p1x, p1y; ///< Point on first curve
  double p2x, p2y; ///< Point on second curve
} OCCTExtrema2dResult;

/// Distance between two 2D lines (checks parallel).
/// @param outIsParallel Set to true if lines are parallel
/// @return Number of extrema (-1 on error)
int32_t OCCTExtremaExtElC2dLinLin(double               l1px,
                                  double               l1py,
                                  double               l1dx,
                                  double               l1dy,
                                  double               l2px,
                                  double               l2py,
                                  double               l2dx,
                                  double               l2dy,
                                  double               tolerance,
                                  bool*                outIsParallel,
                                  OCCTExtrema2dResult* out,
                                  int32_t              max);

/// Distance between a 2D line and circle.
/// @return Number of extrema
int32_t OCCTExtremaExtElC2dLinCirc(double               lpx,
                                   double               lpy,
                                   double               ldx,
                                   double               ldy,
                                   double               cx,
                                   double               cy,
                                   double               cr,
                                   double               tolerance,
                                   OCCTExtrema2dResult* out,
                                   int32_t              max);

/// Closest point(s) on a 2D circle to a point.
/// @return Number of extrema
int32_t OCCTExtremaExtPElC2dCirc(double               px,
                                 double               py,
                                 double               cx,
                                 double               cy,
                                 double               cr,
                                 double               tolerance,
                                 OCCTExtrema2dResult* out,
                                 int32_t              max);

/// Closest point(s) on a 2D line to a point.
/// @return Number of extrema
int32_t OCCTExtremaExtPElC2dLin(double               px,
                                double               py,
                                double               lpx,
                                double               lpy,
                                double               ldx,
                                double               ldy,
                                double               tolerance,
                                OCCTExtrema2dResult* out,
                                int32_t              max);

/// Distance between two 2D curves (Extrema_ExtCC2d).
/// @return Number of extrema
int32_t OCCTExtremaExtCC2d(OCCTCurve2DRef       c1,
                           double               first1,
                           double               last1,
                           OCCTCurve2DRef       c2,
                           double               first2,
                           double               last2,
                           OCCTExtrema2dResult* out,
                           int32_t              max);

// --- Bisector_BisecAna ---

/// Compute analytical bisector between two 2D curves.
/// @return A 2D curve representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurveCurve(OCCTCurve2DRef curve1,
                                                        OCCTCurve2DRef curve2,
                                                        double         px,
                                                        double         py,
                                                        double         v1x,
                                                        double         v1y,
                                                        double         v2x,
                                                        double         v2y,
                                                        double         sense,
                                                        double         tolerance);

/// Compute analytical bisector between a 2D curve and a point.
/// @return A 2D curve representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaCurvePoint(OCCTCurve2DRef curve,
                                                        double         ptx,
                                                        double         pty,
                                                        double         px,
                                                        double         py,
                                                        double         v1x,
                                                        double         v1y,
                                                        double         v2x,
                                                        double         v2y,
                                                        double         sense,
                                                        double         tolerance);

/// Compute analytical bisector between two points.
/// @return A 2D curve (line) representing the bisector, or NULL on failure
OCCTCurve2DRef _Nullable OCCTBisectorBisecAnaPointPoint(double pt1x,
                                                        double pt1y,
                                                        double pt2x,
                                                        double pt2y,
                                                        double px,
                                                        double py,
                                                        double v1x,
                                                        double v1y,
                                                        double v2x,
                                                        double v2y,
                                                        double sense,
                                                        double tolerance);

// MARK: - BRepAdaptor_Curve2d (v0.61.0)

/// Get 2D curve parameters for an edge on a face.
/// @param edge Edge shape
/// @param face Face shape
/// @param outFirst Output first parameter
/// @param outLast Output last parameter
/// @return true if PCurve exists
bool OCCTEdgePCurveParams(OCCTShapeRef edge, OCCTShapeRef face, double* outFirst, double* outLast);

/// Evaluate 2D curve point for an edge on a face at parameter t.
/// @return true if successful
bool OCCTEdgePCurveValue(OCCTShapeRef edge,
                         OCCTShapeRef face,
                         double       t,
                         double*      outU,
                         double*      outV);

// --- BRepBuilderAPI_MakeEdge2d ---

/// Create a 2D edge from two 2D points.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromPoints(double x1, double y1, double x2, double y2);

/// Create a 2D edge from a 2D circle arc.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromCircle(double cx,
                                                double cy,
                                                double dx,
                                                double dy,
                                                double radius,
                                                double p1,
                                                double p2);

/// Create a 2D edge from a 2D line with parameters.
OCCTShapeRef _Nullable OCCTMakeEdge2dFromLine(double ox,
                                              double oy,
                                              double dx,
                                              double dy,
                                              double p1,
                                              double p2);

/// Create a 2D point at (x, y)
OCCTPoint2DRef _Nullable OCCTPoint2DCreate(double x, double y);
/// Release a 2D point
void OCCTPoint2DRelease(OCCTPoint2DRef _Nonnull ref);
/// Get X coordinate
double OCCTPoint2DGetX(OCCTPoint2DRef _Nonnull ref);
/// Get Y coordinate
double OCCTPoint2DGetY(OCCTPoint2DRef _Nonnull ref);
/// Set coordinates
void OCCTPoint2DSetCoords(OCCTPoint2DRef _Nonnull ref, double x, double y);
/// Distance to another point
double OCCTPoint2DDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other);
/// Square distance to another point
double OCCTPoint2DSquareDistance(OCCTPoint2DRef _Nonnull ref, OCCTPoint2DRef _Nonnull other);
/// Translate by (dx, dy), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DTranslated(OCCTPoint2DRef _Nonnull ref, double dx, double dy);
/// Rotate around center by angle (radians), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DRotated(OCCTPoint2DRef _Nonnull ref,
                                            double cx,
                                            double cy,
                                            double angle);
/// Scale from center by factor, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DScaled(OCCTPoint2DRef _Nonnull ref,
                                           double cx,
                                           double cy,
                                           double factor);
/// Mirror across a point, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DMirroredPoint(OCCTPoint2DRef _Nonnull ref,
                                                  double px,
                                                  double py);
/// Mirror across an axis (origin + direction), returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DMirroredAxis(OCCTPoint2DRef _Nonnull ref,
                                                 double ox,
                                                 double oy,
                                                 double dx,
                                                 double dy);
/// Distance from point to curve
/// @return Minimum distance over the curve's own range, ends included, so a point with no
///         perpendicular foot (one beyond the ends of a bounded curve, or a circle's centre) is
///         measured rather than refused (#615). -1 means there was no curve to measure to; Swift's
///         Point2D.distance(to:) maps that to .infinity.
double OCCTPoint2DDistanceToCurve(OCCTPoint2DRef _Nonnull ref, OCCTCurve2DRef _Nonnull curve);
/// Apply a Transform2D to a point, returns new point
OCCTPoint2DRef _Nullable OCCTPoint2DTransformed(OCCTPoint2DRef _Nonnull ref,
                                                OCCTTransform2DRef _Nonnull trsf);

// --- Transform2D (Geom2d_Transformation) ---

/// Create identity transform
OCCTTransform2DRef _Nullable OCCTTransform2DCreateIdentity(void);
/// Release a transform
void OCCTTransform2DRelease(OCCTTransform2DRef _Nonnull ref);
/// Create translation transform
OCCTTransform2DRef _Nullable OCCTTransform2DCreateTranslation(double dx, double dy);
/// Create rotation transform around center by angle
OCCTTransform2DRef _Nullable OCCTTransform2DCreateRotation(double cx, double cy, double angle);
/// Create scale transform from center by factor
OCCTTransform2DRef _Nullable OCCTTransform2DCreateScale(double cx, double cy, double factor);
/// Create mirror about a point
OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorPoint(double px, double py);
/// Create mirror about an axis (origin + direction)
OCCTTransform2DRef _Nullable OCCTTransform2DCreateMirrorAxis(double ox,
                                                             double oy,
                                                             double dx,
                                                             double dy);
/// Inverted transform
OCCTTransform2DRef _Nullable OCCTTransform2DInverted(OCCTTransform2DRef _Nonnull ref);
/// Composed (multiplied) transforms: this * other
OCCTTransform2DRef _Nullable OCCTTransform2DComposed(OCCTTransform2DRef _Nonnull ref,
                                                     OCCTTransform2DRef _Nonnull other);
/// Powered transform: this^n
OCCTTransform2DRef _Nullable OCCTTransform2DPowered(OCCTTransform2DRef _Nonnull ref, int32_t n);
/// Apply transform to a point (returns transformed coordinates)
void OCCTTransform2DApply(OCCTTransform2DRef _Nonnull ref, double* _Nonnull x, double* _Nonnull y);
/// Get scale factor
double OCCTTransform2DScaleFactor(OCCTTransform2DRef _Nonnull ref);
/// Is the transform negative (reflection)?
bool OCCTTransform2DIsNegative(OCCTTransform2DRef _Nonnull ref);
/// Get 2x3 matrix values [a11, a12, a13, a21, a22, a23]
void OCCTTransform2DGetValues(OCCTTransform2DRef _Nonnull ref,
                              double* _Nonnull a11,
                              double* _Nonnull a12,
                              double* _Nonnull a13,
                              double* _Nonnull a21,
                              double* _Nonnull a22,
                              double* _Nonnull a23);
/// Apply transform to a Curve2D, returns new curve
OCCTCurve2DRef _Nullable OCCTTransform2DApplyToCurve(OCCTTransform2DRef _Nonnull ref,
                                                     OCCTCurve2DRef _Nonnull curve);

/// Create a 2D axis placement from origin and direction
OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DCreate(double ox,
                                                           double oy,
                                                           double dx,
                                                           double dy);
/// Release
void OCCTAxisPlacement2DRelease(OCCTAxisPlacement2DRef _Nonnull ref);
/// Get origin
void OCCTAxisPlacement2DGetOrigin(OCCTAxisPlacement2DRef _Nonnull ref,
                                  double* _Nonnull x,
                                  double* _Nonnull y);
/// Get direction
void OCCTAxisPlacement2DGetDirection(OCCTAxisPlacement2DRef _Nonnull ref,
                                     double* _Nonnull x,
                                     double* _Nonnull y);
/// Reversed axis
OCCTAxisPlacement2DRef _Nullable OCCTAxisPlacement2DReversed(OCCTAxisPlacement2DRef _Nonnull ref);
/// Angle between two axes
double OCCTAxisPlacement2DAngle(OCCTAxisPlacement2DRef _Nonnull ref,
                                OCCTAxisPlacement2DRef _Nonnull other);

// --- Vector2D (Geom2d_VectorWithMagnitude) ---

/// Signed angle between two 2D vectors (radians, -PI to PI)
double OCCTVector2DAngle(double ax, double ay, double bx, double by);
/// Cross product of two 2D vectors (scalar)
double OCCTVector2DCross(double ax, double ay, double bx, double by);
/// Dot product of two 2D vectors
double OCCTVector2DDot(double ax, double ay, double bx, double by);
/// Magnitude of a 2D vector
double OCCTVector2DMagnitude(double x, double y);
/// Normalize a 2D vector (returns via pointers)
void OCCTVector2DNormalize(double* _Nonnull x, double* _Nonnull y);

// --- Direction2D (Geom2d_Direction) ---

/// Create a normalized direction from components (returns via pointers)
void OCCTDirection2DNormalize(double* _Nonnull x, double* _Nonnull y);
/// Signed angle between two directions
double OCCTDirection2DAngle(double ax, double ay, double bx, double by);
/// Cross product of two directions
double OCCTDirection2DCross(double ax, double ay, double bx, double by);

// --- LProp_AnalyticCurInf ---

/// Compute curvature special points for analytic curve types.
/// @param curveType GeomAbs_CurveType: 0=Line, 1=Circle, 2=Ellipse, 3=Hyperbola, 4=Parabola
/// @param first First parameter
/// @param last Last parameter
/// @param outParams Output array of parameters at special points
/// @param outTypes Output array of types (0=Inflection, 1=MinCur, 2=MaxCur)
/// @param maxResults Maximum number of results to return
/// @return Number of special points found
int32_t OCCTLPropAnalyticCurInf(int32_t curveType,
                                double  first,
                                double  last,
                                double* _Nonnull outParams,
                                int32_t* _Nonnull outTypes,
                                int32_t maxResults);

// --- Curve2D ↔ Point2D integration ---

/// Create a Point2D from a Curve2D at parameter t
OCCTPoint2DRef _Nullable OCCTCurve2DPointAt(OCCTCurve2DRef _Nonnull curve, double t);

/// Create a line segment Curve2D between two Point2Ds
OCCTCurve2DRef _Nullable OCCTCurve2DSegmentFromPoints(OCCTPoint2DRef _Nonnull p1,
                                                      OCCTPoint2DRef _Nonnull p2);

/// Project a Point2D onto a Curve2D, returns parameter at closest point
/// @param outDistance Output: minimum distance, or -1 on failure, this is the failure signal.
///         Since #615 failure means only "no curve": the nearest point is taken over the curve's
///         own range, ends included, so a point with no perpendicular foot is answered.
/// @return parameter on curve, or NaN on failure. Do NOT test the return value against 0: 0 is a
///         legitimate parameter on any curve whose domain includes it (projecting a segment's own
///         start point onto it returns exactly 0). Test `outDistance < 0` instead.
double OCCTCurve2DProjectPoint2D(OCCTCurve2DRef _Nonnull curve,
                                 OCCTPoint2DRef _Nonnull point,
                                 double* _Nonnull outDistance);

// MARK: - v0.67.0: TKGeomAlgo Part 1. FairCurve, LocalAnalysis, TopTrans

// --- FairCurve_Batten ---

/// Create a fair curve (batten) between two 2D points.
/// @param height Height of deformation (must be > 0)
/// @param slope Slope value (0 = uniform section)
/// @return Curve2D result after computation, or NULL on failure
OCCTCurve2DRef _Nullable OCCTFairCurveBatten(double  p1x,
                                             double  p1y,
                                             double  p2x,
                                             double  p2y,
                                             double  height,
                                             double  slope,
                                             double  angle1,
                                             double  angle2,
                                             int32_t constraintOrder1,
                                             int32_t constraintOrder2,
                                             bool    freeSliding,
                                             int32_t* _Nonnull outCode);

/// Create a minimal variation fair curve between two 2D points.
/// @param physicalRatio Physical ratio (0-1, balance between curvature and jerk energy)
/// @param curvature1 Desired curvature at P1 (only used if constraintOrder >= 2)
/// @param curvature2 Desired curvature at P2 (only used if constraintOrder >= 2)
/// @return Curve2D result after computation, or NULL on failure
OCCTCurve2DRef _Nullable OCCTFairCurveMinimalVariation(double  p1x,
                                                       double  p1y,
                                                       double  p2x,
                                                       double  p2y,
                                                       double  height,
                                                       double  slope,
                                                       double  angle1,
                                                       double  angle2,
                                                       int32_t constraintOrder1,
                                                       int32_t constraintOrder2,
                                                       bool    freeSliding,
                                                       double  physicalRatio,
                                                       double  curvature1,
                                                       double  curvature2,
                                                       int32_t* _Nonnull outCode);

// --- GccAna_Circ2d3Tan ---

/// Result struct for GccAna_Circ2d3Tan solutions.
typedef struct
{
  double centerX, centerY;
  double radius;
} OCCTCircle2DSolution;

/// Find circles tangent to / through 3 points.
int32_t OCCTGccAnaCirc2d3TanPoints(double p1x,
                                   double p1y,
                                   double p2x,
                                   double p2y,
                                   double p3x,
                                   double p3y,
                                   double tolerance,
                                   OCCTCircle2DSolution* _Nonnull outSolutions,
                                   int32_t maxSolutions);

/// Find circles tangent to 3 lines.
int32_t OCCTGccAnaCirc2d3TanLines(double l1px,
                                  double l1py,
                                  double l1dx,
                                  double l1dy,
                                  double l2px,
                                  double l2py,
                                  double l2dx,
                                  double l2dy,
                                  double l3px,
                                  double l3py,
                                  double l3dx,
                                  double l3dy,
                                  double tolerance,
                                  OCCTCircle2DSolution* _Nonnull outSolutions,
                                  int32_t maxSolutions);

/// Find circles tangent to 3 circles.
int32_t OCCTGccAnaCirc2d3TanCircles(double c1x,
                                    double c1y,
                                    double c1r,
                                    double c2x,
                                    double c2y,
                                    double c2r,
                                    double c3x,
                                    double c3y,
                                    double c3r,
                                    double tolerance,
                                    OCCTCircle2DSolution* _Nonnull outSolutions,
                                    int32_t maxSolutions);

/// Find circles tangent to 2 circles through 1 point.
int32_t OCCTGccAnaCirc2d2CirclesPoint(double c1x,
                                      double c1y,
                                      double c1r,
                                      double c2x,
                                      double c2y,
                                      double c2r,
                                      double px,
                                      double py,
                                      double tolerance,
                                      OCCTCircle2DSolution* _Nonnull outSolutions,
                                      int32_t maxSolutions);

/// Find circles tangent to 1 circle through 2 points.
int32_t OCCTGccAnaCirc2dCircle2Points(double cx,
                                      double cy,
                                      double cr,
                                      double p1x,
                                      double p1y,
                                      double p2x,
                                      double p2y,
                                      double tolerance,
                                      OCCTCircle2DSolution* _Nonnull outSolutions,
                                      int32_t maxSolutions);

/// Find circles tangent to 2 lines through 1 point.
int32_t OCCTGccAnaCirc2d2LinesPoint(double l1px,
                                    double l1py,
                                    double l1dx,
                                    double l1dy,
                                    double l2px,
                                    double l2py,
                                    double l2dx,
                                    double l2dy,
                                    double px,
                                    double py,
                                    double tolerance,
                                    OCCTCircle2DSolution* _Nonnull outSolutions,
                                    int32_t maxSolutions);

// --- Intf_InterferencePolygon2d ---

/// Intersection point result for polygon interference.
typedef struct
{
  double x, y;
} OCCTIntfPoint2D;

/// Compute interference (intersection) between two 2D polylines.
/// @param poly1 Flat array of (x,y) pairs for first polyline
/// @param count1 Number of points in first polyline
/// @param poly2 Flat array of (x,y) pairs for second polyline
/// @param count2 Number of points in second polyline
/// @param outPoints Output array of intersection points
/// @param maxPoints Maximum intersection points to write
/// @return Number of intersection points found
int32_t OCCTIntfInterferencePolygon2d(const double* _Nonnull poly1,
                                      int32_t count1,
                                      const double* _Nonnull poly2,
                                      int32_t count2,
                                      OCCTIntfPoint2D* _Nonnull outPoints,
                                      int32_t maxPoints);

/// Compute self-interference of a 2D polyline.
int32_t OCCTIntfSelfInterferencePolygon2d(const double* _Nonnull poly,
                                          int32_t count,
                                          OCCTIntfPoint2D* _Nonnull outPoints,
                                          int32_t maxPoints);
/// Convert any 2D curve segment to BSpline.
OCCTCurve2DRef _Nullable OCCTShapeConstructConvertToBSpline2D(OCCTCurve2DRef _Nonnull curve,
                                                              double first,
                                                              double last,
                                                              double precision);
/// Adjust 2D curve endpoints to match given points.
bool OCCTShapeConstructAdjustCurve2D(OCCTCurve2DRef _Nonnull curve,
                                     double p1x,
                                     double p1y,
                                     double p2x,
                                     double p2y);

// MARK: - Bisector_PointOnBis / PolyBis / Inter

/// OCCTBisectorPointOnBis and OCCTBisectorPointOnBisCreate were declared here: a plain
/// echo-your-parameters-into-a-struct constructor that never called into Bisector_PointOnBis
/// itself, had no Swift call site, and the Swift-side BisectorPoint it built for had no public
/// initializer either, so nothing outside this bridge could construct one. Its isInfinite field,
/// always the literal false this constructor's own 6-double parameter list has no way to set, is
/// what census-unmeasured-values.py's sub-kind 3 (#771) flagged; the field's fate turned out to be
/// dead code around it, not a stuck gate on a live path. Removed by #771.

/// Bisector intersection point result.
typedef struct
{
  double x, y;
  double paramOnFirst;
  double paramOnSecond;
} OCCTBisectorIntersectionPoint;

/// Compute intersections between two point-bisectors. Returns number of intersection points.
/// Bisector of (ax,ay)-(bx,by) is intersected with bisector of (cx,cy)-(dx,dy).
int OCCTBisectorInterPointPoint(double ax,
                                double ay,
                                double bx,
                                double by,
                                double cx,
                                double cy,
                                double dx,
                                double dy,
                                OCCTBisectorIntersectionPoint* _Nullable outPoints,
                                int maxPoints);

/// Find parameter of 2D point on 2D curve. Returns false if point is beyond maxDist.
bool OCCTGeomLibToolParameter2D(OCCTCurve2DRef _Nonnull curve,
                                double px,
                                double py,
                                double maxDist,
                                double* _Nonnull outParam);

/// Check BSpline 2D curve for reversed end tangents. Returns true if check completed.
bool OCCTGeomLibCheckBSpline2D(OCCTCurve2DRef _Nonnull curve,
                               double tolerance,
                               double angularTol,
                               bool* _Nonnull needFixFirst,
                               bool* _Nonnull needFixLast);

/// Fix BSpline 2D curve end tangents, returns new curve or NULL if not needed.
OCCTCurve2DRef _Nullable OCCTGeomLibFixBSpline2D(OCCTCurve2DRef _Nonnull curve,
                                                 double tolerance,
                                                 double angularTol,
                                                 bool   fixFirst,
                                                 bool   fixLast);

// MARK: - GccAna_Circ2d2TanRad

/// Find circles tangent to two lines with given radius. Returns solution count.
int OCCTGccAnaCirc2d2TanRadLineLin(double l1px,
                                   double l1py,
                                   double l1dx,
                                   double l1dy,
                                   double l2px,
                                   double l2py,
                                   double l2dx,
                                   double l2dy,
                                   double radius,
                                   double tolerance,
                                   OCCTCircle2DSolution* _Nullable outSolutions,
                                   int maxSolutions);

/// Find circles through two points with given radius. Returns solution count.
int OCCTGccAnaCirc2d2TanRadPntPnt(double p1x,
                                  double p1y,
                                  double p2x,
                                  double p2y,
                                  double radius,
                                  double tolerance,
                                  OCCTCircle2DSolution* _Nullable outSolutions,
                                  int maxSolutions);

// MARK: - GccAna_Circ2dTanCen

/// Find circle through a point centered at another point. Returns solution count.
int OCCTGccAnaCirc2dTanCenPntPnt(double px,
                                 double py,
                                 double cx,
                                 double cy,
                                 OCCTCircle2DSolution* _Nullable outSolutions,
                                 int maxSolutions);

/// Find circle tangent to a line centered at a point. Returns solution count.
int OCCTGccAnaCirc2dTanCenLinPnt(double lpx,
                                 double lpy,
                                 double ldx,
                                 double ldy,
                                 double cx,
                                 double cy,
                                 OCCTCircle2DSolution* _Nullable outSolutions,
                                 int maxSolutions);

// MARK: - GccAna_Lin2d2Tan

/// Line through two points result.
typedef struct
{
  double originX, originY;
  double dirX, dirY;
} OCCTLine2DSolution;

/// Find line through two points. Returns solution count (0 or 1).
int OCCTGccAnaLin2d2TanPntPnt(double p1x,
                              double p1y,
                              double p2x,
                              double p2y,
                              double tolerance,
                              OCCTLine2DSolution* _Nullable outSolutions,
                              int maxSolutions);

/// Find lines tangent to a circle through a point. Returns solution count.
int OCCTGccAnaLin2d2TanCircPnt(double cx,
                               double cy,
                               double radius,
                               double px,
                               double py,
                               double tolerance,
                               OCCTLine2DSolution* _Nullable outSolutions,
                               int maxSolutions);

// MARK: - ShapeUpgrade_SplitCurve2dContinuity

/// Split 2D curve at continuity breaks. criterion: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN.
/// Returns number of resulting curve segments, or 0 on failure.
int OCCTSplitCurve2dContinuity(OCCTCurve2DRef _Nonnull curve,
                               int    criterion,
                               double tolerance,
                               OCCTCurve2DRef _Nullable* _Nullable outCurves,
                               int maxCurves);

// MARK: - ShapeUpgrade_ConvertCurve2dToBezier

/// Convert 2D curve to Bezier segments. Returns number of segments, or 0 on failure.
int OCCTConvertCurve2dToBezier(OCCTCurve2DRef _Nonnull curve,
                               OCCTCurve2DRef _Nullable* _Nullable outCurves,
                               int maxCurves);

// MARK: - Geom2dConvert_ApproxArcsSegments

/// Approximate a 2D curve as arcs and line segments.
/// Returns number of resulting curves, or 0 on failure.
int OCCTGeom2dConvertApproxArcsSegments(OCCTCurve2DRef _Nonnull curveRef,
                                        double tolerance,
                                        double angleTolerance,
                                        OCCTCurve2DRef _Nullable* _Nullable outCurves,
                                        int maxCurves);

// --- Extrema_LocateExtCC2d: Local 2D curve-curve distance ---
typedef struct
{
  bool   isDone;
  double squareDistance;
  double x1, y1, param1;
  double x2, y2, param2;
} OCCTExtremaLocateExtCC2dResult;

/// Find local 2D curve-curve extremum near seed parameters
OCCTExtremaLocateExtCC2dResult OCCTExtremaLocateExtCC2d(OCCTCurve2DRef _Nonnull curve1,
                                                        double u1First,
                                                        double u1Last,
                                                        OCCTCurve2DRef _Nonnull curve2,
                                                        double u2First,
                                                        double u2Last,
                                                        double seedU,
                                                        double seedV);

// --- gce_MakeCirc2d ---
/// Create a 2D circle from center + radius
OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFromCenterRadius(double cx, double cy, double radius);

/// Create a 2D circle from 3 points
OCCTCurve2DRef _Nullable OCCTGceMakeCirc2dFrom3Points(double p1x,
                                                      double p1y,
                                                      double p2x,
                                                      double p2y,
                                                      double p3x,
                                                      double p3y);

// --- gce_MakeLin2d ---
/// Create a 2D line from 2 points
OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFrom2Points(double p1x,
                                                     double p1y,
                                                     double p2x,
                                                     double p2y);

/// Create a 2D line from equation Ax+By+C=0
OCCTCurve2DRef _Nullable OCCTGceMakeLin2dFromEquation(double a, double b, double c);

// --- gce_MakeElips2d ---
/// Create a 2D ellipse from center, major axis direction, and radii
OCCTCurve2DRef _Nullable OCCTGceMakeElips2d(double cx,
                                            double cy,
                                            double dirX,
                                            double dirY,
                                            double majorRadius,
                                            double minorRadius);

// --- gce_MakeHypr2d ---
/// Create a 2D hyperbola from center, major axis direction, and radii
OCCTCurve2DRef _Nullable OCCTGceMakeHypr2d(double cx,
                                           double cy,
                                           double dirX,
                                           double dirY,
                                           double majorRadius,
                                           double minorRadius);

// --- gce_MakeParab2d ---
/// Create a 2D parabola from center, axis direction, and focal length
OCCTCurve2DRef _Nullable OCCTGceMakeParab2d(double cx,
                                            double cy,
                                            double dirX,
                                            double dirY,
                                            double focal);

// MARK: - Geom2dAPI_Interpolate (v0.93.0)

/// Interpolate a 2D BSpline curve through points.
/// @param xs Array of X coordinates
/// @param ys Array of Y coordinates
/// @param count Number of points
/// @param periodic If true, create a periodic (closed) curve
/// @param tolerance Interpolation tolerance
/// @return Opaque curve handle, or NULL on failure. Caller must free with OCCTCurve2DRelease.
OCCTCurve2DRef _Nullable OCCTCurve2DInterpolate2D(const double* _Nonnull xs,
                                                  const double* _Nonnull ys,
                                                  int32_t count,
                                                  bool    periodic,
                                                  double  tolerance);

// MARK: - Geom2dAPI_PointsToBSpline (v0.93.0)

/// Approximate a 2D BSpline curve through points.
/// @param xs Array of X coordinates
/// @param ys Array of Y coordinates
/// @param count Number of points
/// @return Opaque curve handle, or NULL on failure. Caller must free with OCCTCurve2DRelease.
OCCTCurve2DRef _Nullable OCCTCurve2DApproximate2D(const double* _Nonnull xs,
                                                  const double* _Nonnull ys,
                                                  int32_t count);

// MARK: - Convert_CircleToBSplineCurve (v0.94.0)

/// Convert a 2D circle (arc) to a BSpline curve.
/// @param cx,cy Center coordinates
/// @param radius Circle radius
/// @param u1,u2 Parameter range (0 to 2*PI for full circle)
/// @return Opaque 2D curve handle, or NULL on failure
OCCTCurve2DRef _Nullable OCCTConvertCircleToBSpline2D(double cx,
                                                      double cy,
                                                      double radius,
                                                      double u1,
                                                      double u2);

// MARK: - Convert_EllipseToBSplineCurve (v0.95.0)

/// Convert a 2D ellipse arc to a BSpline curve.
/// Requires 0 < minorRadius <= majorRadius (#514); returns NULL otherwise.
OCCTCurve2DRef _Nullable OCCTConvertEllipseToBSpline2D(double cx,
                                                       double cy,
                                                       double majorRadius,
                                                       double minorRadius,
                                                       double u1,
                                                       double u2);

// MARK: - Convert_HyperbolaToBSplineCurve (v0.95.0)

/// Convert a 2D hyperbola arc to a BSpline curve.
/// Requires both radii > 0, in either order (#514); returns NULL otherwise.
OCCTCurve2DRef _Nullable OCCTConvertHyperbolaToBSpline2D(double cx,
                                                         double cy,
                                                         double majorRadius,
                                                         double minorRadius,
                                                         double u1,
                                                         double u2);

// MARK: - Convert_ParabolaToBSplineCurve (v0.95.0)

/// Convert a 2D parabola arc to a BSpline curve.
/// Requires focal > 0 (#514): at focal 0 the conversion succeeds with NaN poles.
OCCTCurve2DRef _Nullable OCCTConvertParabolaToBSpline2D(double cx,
                                                        double cy,
                                                        double focal,
                                                        double u1,
                                                        double u2);

// MARK: - GC_MakeCircle2d (v0.105.0)

/// Create a 2D circle from center and radius.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeCircleCenterRadius(double cx, double cy, double radius);

/// Create a 2D circle through 3 points.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeCircle3Points(double x1,
                                                      double y1,
                                                      double x2,
                                                      double y2,
                                                      double x3,
                                                      double y3);

/// Create a 2D circle from center and point on circle.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeCircleCenterPoint(double cx,
                                                          double cy,
                                                          double px,
                                                          double py);

/// Create a 2D circle parallel to existing circle at distance.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeCircleParallel(double cx,
                                                       double cy,
                                                       double dx,
                                                       double dy,
                                                       double radius,
                                                       double dist);

/// Create a 2D circle from axis and radius.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeCircleAxis(double cx,
                                                   double cy,
                                                   double dx,
                                                   double dy,
                                                   double radius);

// MARK: - GC_MakeEllipse2d (v0.105.0)

/// Create a 2D ellipse from axis and radii.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeEllipse(double cx,
                                                double cy,
                                                double dx,
                                                double dy,
                                                double major,
                                                double minor);

/// Create a 2D ellipse from 3 points (S1, S2, center).
OCCTCurve2DRef _Nullable OCCTCurve2DMakeEllipse3Points(double x1,
                                                       double y1,
                                                       double x2,
                                                       double y2,
                                                       double x3,
                                                       double y3);

/// Create a 2D ellipse from full Ax22d and radii.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeEllipseAxis22d(double cx,
                                                       double cy,
                                                       double xdx,
                                                       double xdy,
                                                       double ydx,
                                                       double ydy,
                                                       double major,
                                                       double minor);

// MARK: - GC_MakeHyperbola2d (v0.105.0)

/// Create a 2D hyperbola from axis and radii.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeHyperbola(double cx,
                                                  double cy,
                                                  double dx,
                                                  double dy,
                                                  double major,
                                                  double minor);

/// Create a 2D hyperbola from 3 points (S1, S2, center).
OCCTCurve2DRef _Nullable OCCTCurve2DMakeHyperbola3Points(double x1,
                                                         double y1,
                                                         double x2,
                                                         double y2,
                                                         double x3,
                                                         double y3);

// MARK: - GC_MakeParabola2d (v0.105.0)

/// Create a 2D parabola from axis and focal distance.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeParabola(double cx,
                                                 double cy,
                                                 double dx,
                                                 double dy,
                                                 double focal);

/// Create a 2D parabola from directrix and focus.
OCCTCurve2DRef _Nullable OCCTCurve2DMakeParabolaDirectrixFocus(double dx,
                                                               double dy,
                                                               double ddx,
                                                               double ddy,
                                                               double fx,
                                                               double fy);

// MARK: - Geom2dConvert_CompCurveToBSplineCurve (v0.105.0)

/// Concatenate an array of bounded 2D curves into a single BSpline curve.
OCCTCurve2DRef _Nullable OCCTConcatenateCurves2D(OCCTCurve2DRef _Nonnull* _Nonnull curves,
                                                 int32_t count,
                                                 double  tolerance);

// MARK: - BRepLib_MakeEdge2d extensions (v0.106.0)

/// Create a 2D edge from a full circle. Requires radius > 0 (#514).
OCCTShapeRef _Nullable OCCTMakeEdge2dFullCircle(double cx,
                                                double cy,
                                                double dx,
                                                double dy,
                                                double radius);

/// Create a 2D edge from an ellipse. Requires 0 < minor <= major (#514):
/// BRepLib_MakeEdge2d reports IsDone() for a degenerate ellipse and builds a zero-length or
/// doubled-back edge from it.
OCCTShapeRef _Nullable OCCTMakeEdge2dEllipse(double cx,
                                             double cy,
                                             double dx,
                                             double dy,
                                             double major,
                                             double minor);

/// Create a 2D edge from an ellipse arc with parameter range.
/// Requires 0 < minor <= major (#514).
OCCTShapeRef _Nullable OCCTMakeEdge2dEllipseArc(double cx,
                                                double cy,
                                                double dx,
                                                double dy,
                                                double major,
                                                double minor,
                                                double u1,
                                                double u2);

/// Create a 2D edge from a Geom2d_Curve.
OCCTShapeRef _Nullable OCCTMakeEdge2dCurve(OCCTCurve2DRef _Nonnull curve);

/// Create a 2D edge from a Geom2d_Curve with parameter range.
OCCTShapeRef _Nullable OCCTMakeEdge2dCurveRange(OCCTCurve2DRef _Nonnull curve,
                                                double u1,
                                                double u2);

// MARK: - Curve2D continuity (v0.106.0)

/// Get the global continuity of a 2D curve.
///
/// Returns the raw GeomAbs_Shape ordinal: 0=C0, 1=G1, 2=C1, 3=G2, 4=C2, 5=C3, 6=CN.
/// Returns 0 for a null curve.
int32_t OCCTCurve2DGetContinuity(OCCTCurve2DRef _Nonnull curve);

// MARK: - Geom2d_BSplineCurve Methods (v0.107.0)

/// Get the number of knots of a 2D BSpline curve.
int32_t OCCTCurve2DBSplineKnotCount(OCCTCurve2DRef _Nonnull curve);

/// Get the number of poles of a 2D BSpline curve.
int32_t OCCTCurve2DBSplinePoleCount(OCCTCurve2DRef _Nonnull curve);

/// Get the degree of a 2D BSpline curve.
int32_t OCCTCurve2DBSplineDegree(OCCTCurve2DRef _Nonnull curve);

/// Check if a 2D BSpline curve is rational.
bool OCCTCurve2DBSplineIsRational(OCCTCurve2DRef _Nonnull curve);

/// Get a 2D pole (1-based index).
void OCCTCurve2DBSplineGetPole(OCCTCurve2DRef _Nonnull curve,
                               int32_t index,
                               double* _Nonnull x,
                               double* _Nonnull y);

/// Set a 2D pole (1-based index).
bool OCCTCurve2DBSplineSetPole(OCCTCurve2DRef _Nonnull curve, int32_t index, double x, double y);

/// Set a weight for a 2D pole (1-based index).
bool OCCTCurve2DBSplineSetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index, double weight);

/// Insert a knot into a 2D BSpline curve.
bool OCCTCurve2DBSplineInsertKnot(OCCTCurve2DRef _Nonnull curve,
                                  double  u,
                                  int32_t mult,
                                  double  tol);

/// Remove a knot from a 2D BSpline curve.
bool OCCTCurve2DBSplineRemoveKnot(OCCTCurve2DRef _Nonnull curve,
                                  int32_t index,
                                  int32_t mult,
                                  double  tol);

/// Segment a 2D BSpline curve to [u1, u2].
bool OCCTCurve2DBSplineSegment(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

/// Increase the degree of a 2D BSpline curve.
bool OCCTCurve2DBSplineIncreaseDegree(OCCTCurve2DRef _Nonnull curve, int32_t degree);

/// Compute parametric resolution for a 2D BSpline curve.
double OCCTCurve2DBSplineResolution(OCCTCurve2DRef _Nonnull curve, double tolerance);

/// Create a Hatch_Hatcher with given tolerance.
OCCTHatcherRef _Nullable OCCTHatcherCreate(double tolerance);

/// Release a hatcher.
void OCCTHatcherRelease(OCCTHatcherRef _Nullable hatcher);

/// Add a vertical line at x.
void OCCTHatcherAddXLine(OCCTHatcherRef _Nonnull hatcher, double x);

/// Add a horizontal line at y.
void OCCTHatcherAddYLine(OCCTHatcherRef _Nonnull hatcher, double y);

/// Trim hatch lines with a segment from (x1,y1) to (x2,y2).
void OCCTHatcherTrim(OCCTHatcherRef _Nonnull hatcher, double x1, double y1, double x2, double y2);

/// Get the number of hatch lines.
int32_t OCCTHatcherNbLines(OCCTHatcherRef _Nonnull hatcher);

/// Get the number of intervals on a line (1-based index).
int32_t OCCTHatcherNbIntervals(OCCTHatcherRef _Nonnull hatcher, int32_t lineIndex);

// MARK: - Geom2d_Circle Methods (v0.108.0)

/// Get the radius of a Geom2d_Circle.
double OCCTCurve2DCircleRadius(OCCTCurve2DRef _Nonnull curve);

/// Set the radius of a Geom2d_Circle.
bool OCCTCurve2DCircleSetRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom2d_Circle (always 0).
double OCCTCurve2DCircleEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the center of a Geom2d_Circle.
void OCCTCurve2DCircleCenter(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Get the XAxis of a Geom2d_Circle.
void OCCTCurve2DCircleXAxis(OCCTCurve2DRef _Nonnull curve,
                            double* _Nonnull px,
                            double* _Nonnull py,
                            double* _Nonnull dx,
                            double* _Nonnull dy);

// MARK: - Geom2d_Ellipse Methods (v0.108.0)

/// Get the major radius of a Geom2d_Ellipse.
double OCCTCurve2DEllipseMajorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the minor radius of a Geom2d_Ellipse.
double OCCTCurve2DEllipseMinorRadius(OCCTCurve2DRef _Nonnull curve);

/// Set the major radius of a Geom2d_Ellipse.
bool OCCTCurve2DEllipseSetMajorRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Set the minor radius of a Geom2d_Ellipse.
bool OCCTCurve2DEllipseSetMinorRadius(OCCTCurve2DRef _Nonnull curve, double r);

/// Get the eccentricity of a Geom2d_Ellipse.
double OCCTCurve2DEllipseEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the focal distance of a Geom2d_Ellipse.
double OCCTCurve2DEllipseFocal(OCCTCurve2DRef _Nonnull curve);

/// Get the first focus of a Geom2d_Ellipse.
void OCCTCurve2DEllipseFocus1(OCCTCurve2DRef _Nonnull curve,
                              double* _Nonnull x,
                              double* _Nonnull y);

// MARK: - Geom2d_Hyperbola Methods (v0.108.0)

/// Get the major radius of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaMajorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the minor radius of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaMinorRadius(OCCTCurve2DRef _Nonnull curve);

/// Get the eccentricity of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the focal distance of a Geom2d_Hyperbola.
double OCCTCurve2DHyperbolaFocal(OCCTCurve2DRef _Nonnull curve);

/// Get the first focus of a Geom2d_Hyperbola.
void OCCTCurve2DHyperbolaFocus1(OCCTCurve2DRef _Nonnull curve,
                                double* _Nonnull x,
                                double* _Nonnull y);

// MARK: - Geom2d_Parabola Methods (v0.108.0)

/// Get the focal distance of a Geom2d_Parabola.
double OCCTCurve2DParabolaFocal(OCCTCurve2DRef _Nonnull curve);

/// Set the focal distance of a Geom2d_Parabola.
bool OCCTCurve2DParabolaSetFocal(OCCTCurve2DRef _Nonnull curve, double focal);

/// Get the focus of a Geom2d_Parabola.
void OCCTCurve2DParabolaFocus(OCCTCurve2DRef _Nonnull curve,
                              double* _Nonnull x,
                              double* _Nonnull y);

/// Get the eccentricity of a Geom2d_Parabola (always 1).
double OCCTCurve2DParabolaEccentricity(OCCTCurve2DRef _Nonnull curve);

/// Get the parameter (2*focal) of a Geom2d_Parabola.
double OCCTCurve2DParabolaParameter(OCCTCurve2DRef _Nonnull curve);

// MARK: - Geom2d_Line Methods (v0.108.0)

/// Get the direction of a Geom2d_Line.
void OCCTCurve2DLineDirection(OCCTCurve2DRef _Nonnull curve,
                              double* _Nonnull dx,
                              double* _Nonnull dy);

/// Get the location of a Geom2d_Line.
void OCCTCurve2DLineLocation(OCCTCurve2DRef _Nonnull curve, double* _Nonnull x, double* _Nonnull y);

/// Set the direction of a Geom2d_Line.
bool OCCTCurve2DLineSetDirection(OCCTCurve2DRef _Nonnull curve, double dx, double dy);

/// Set the location of a Geom2d_Line.
bool OCCTCurve2DLineSetLocation(OCCTCurve2DRef _Nonnull curve, double x, double y);

/// Get the distance from a Geom2d_Line to a point.
double OCCTCurve2DLineDistance(OCCTCurve2DRef _Nonnull curve, double px, double py);

/// Get the gp_Lin2d of a Geom2d_Line.
void OCCTCurve2DLineLin2d(OCCTCurve2DRef _Nonnull curve,
                          double* _Nonnull px,
                          double* _Nonnull py,
                          double* _Nonnull dx,
                          double* _Nonnull dy);

// MARK: - Geom2d_OffsetCurve Methods (v0.108.0)

/// Get the offset value of a Geom2d_OffsetCurve.
double OCCTCurve2DOffsetValue(OCCTCurve2DRef _Nonnull curve);

/// Set the offset value of a Geom2d_OffsetCurve.
bool OCCTCurve2DOffsetSetValue(OCCTCurve2DRef _Nonnull curve, double offset);

/// Get the basis curve of a Geom2d_OffsetCurve.
OCCTCurve2DRef _Nullable OCCTCurve2DOffsetBasisCurve(OCCTCurve2DRef _Nonnull curve);

// MARK: - IntAna2d_Conic (v0.109.0)

/// Get 6 conic coefficients from a 2D circle: A*x^2 + B*y^2 + 2C*x*y + 2D*x + 2E*y + F = 0.
/// Requires radius > 0 (#514). The coefficients are zeroed and false returned otherwise.
/// @return true when the coefficients were computed.
bool OCCTConic2dFromCircle(double cx,
                           double cy,
                           double dx,
                           double dy,
                           double radius,
                           double* _Nonnull coeffs);

/// Get 6 conic coefficients from a 2D line, in the same order as OCCTConic2dFromCircle.
/// @return true when the coefficients were computed (false for a zero direction).
bool OCCTConic2dFromLine(double px, double py, double dx, double dy, double* _Nonnull coeffs);

/// Get 6 conic coefficients from a 2D ellipse, in the same order as OCCTConic2dFromCircle.
/// Requires 0 < minorRadius <= majorRadius (#514): all-zero coefficients are the equation
/// 0 = 0, which holds everywhere, so a degenerate ellipse cannot be reported through them.
/// @return true when the coefficients were computed.
bool OCCTConic2dFromEllipse(double cx,
                            double cy,
                            double dx,
                            double dy,
                            double majorRadius,
                            double minorRadius,
                            double* _Nonnull coeffs);

/// Intersect a 2D line with a 2D circle conic. Returns intersection points.
/// Requires radius > 0 (#514).
/// @return Number of intersection points (-1 on error)
int32_t OCCTConic2dLineCircleIntersect(double lpx,
                                       double lpy,
                                       double ldx,
                                       double ldy,
                                       double cx,
                                       double cy,
                                       double cdx,
                                       double cdy,
                                       double radius,
                                       double* _Nonnull xs,
                                       double* _Nonnull ys,
                                       int32_t max);

// MARK: - Curve2D Extras (v0.109.0)

/// Reverse a 2D curve in-place.
bool OCCTCurve2DReverse(OCCTCurve2DRef _Nonnull curve);

/// Deep copy a 2D curve.
OCCTCurve2DRef _Nullable OCCTCurve2DCopy(OCCTCurve2DRef _Nonnull curve);

/// Deprecated alias of OCCTCurve2DGetContinuity, kept for ABI compatibility (#485).
///
/// Prefer OCCTCurve2DGetContinuity. Formerly re-encoded the same GeomAbs_Shape as
/// {C0=0, C1=1, C2=2, C3=3, CN=99, G1=-2, G2=-3}; now returns the raw ordinal.
int32_t OCCTCurve2DContinuity(OCCTCurve2DRef _Nonnull curve);

// MARK: - Curve2D Evaluation (v0.110.0)

/// Evaluate 2D curve at parameter u, returning point (x, y).
void OCCTCurve2DEvalD0(OCCTCurve2DRef _Nonnull curve,
                       double u,
                       double* _Nonnull x,
                       double* _Nonnull y);

/// Evaluate 2D curve at parameter u, returning point and first derivative.
void OCCTCurve2DEvalD1(OCCTCurve2DRef _Nonnull curve,
                       double u,
                       double* _Nonnull px,
                       double* _Nonnull py,
                       double* _Nonnull d1x,
                       double* _Nonnull d1y);

/// Evaluate 2D curve at parameter u, returning point, first and second derivatives.
void OCCTCurve2DEvalD2(OCCTCurve2DRef _Nonnull curve,
                       double u,
                       double* _Nonnull px,
                       double* _Nonnull py,
                       double* _Nonnull d1x,
                       double* _Nonnull d1y,
                       double* _Nonnull d2x,
                       double* _Nonnull d2y);

// --- Curve2D extras ---

/// Get the 2D curve type enum.
int32_t OCCTCurve2DCurveType(OCCTCurve2DRef _Nonnull curve);

/// Find the parameter on a 2D curve nearest to a 2D point, over the curve's whole range.
///
/// The nearest point over the curve's own range, ends included, not the nearest perpendicular
/// foot, on the same contract as the other three 2D nearest-point entry points it shares
/// occtNearestPointOnCurve2dRange with: OCCTCurve2DProjectPoint, OCCTCurve2DProjectPoint2D and
/// OCCTPoint2DDistanceToCurve (#413, #500, #615).
///
/// Returns false and leaves *outParameter untouched only when there is no curve to answer about.
/// Replaces OCCTCurve2DParameterAtPoint, which reported that case as FirstParameter().
bool OCCTCurve2DNearestParameter(OCCTCurve2DRef _Nonnull curve,
                                 double x,
                                 double y,
                                 double* _Nonnull outParameter);

/// Check if a 2D curve is bounded (Geom2d_BoundedCurve subclass).
bool OCCTCurve2DIsBounded(OCCTCurve2DRef _Nonnull curve);

/// Evaluate the N-th derivative of a 2D curve at parameter u.
void OCCTCurve2DDN(OCCTCurve2DRef _Nonnull curve,
                   double  u,
                   int32_t n,
                   double* _Nonnull x,
                   double* _Nonnull y);

/// Get the 2D curve type as a string (Geom2d_Line, Geom2d_Circle, etc.).
const char* _Nullable OCCTCurve2DTypeName(OCCTCurve2DRef _Nonnull curve);

/// Interpolate 2D BSpline with endpoint tangents.
OCCTCurve2DRef _Nullable OCCTInterpolate2DWithTangents(const double* _Nonnull points,
                                                       int32_t count,
                                                       double  t1x,
                                                       double  t1y,
                                                       double  t2x,
                                                       double  t2y);

/// Interpolate 2D BSpline as periodic (closed) curve.
OCCTCurve2DRef _Nullable OCCTInterpolate2DPeriodic(const double* _Nonnull points, int32_t count);

/// Approximate 2D BSpline through points with degree and continuity control.
OCCTCurve2DRef _Nullable OCCTPoints2DToBSplineWithParams(const double* _Nonnull points,
                                                         int32_t count,
                                                         int32_t degMin,
                                                         int32_t degMax,
                                                         int32_t continuity,
                                                         double  tol);

/// Split a 2D curve at discontinuities of given continuity.
int32_t OCCTCurve2DSplitAtContinuity(OCCTCurve2DRef _Nonnull curve,
                                     int32_t continuity,
                                     double  tol,
                                     OCCTCurve2DRef _Nullable* _Nonnull outSegments,
                                     int32_t maxSegments);

// --- Curve3D/2D additional (v0.115.0) ---

/// OCCTCurve3DLength was declared here: a third spelling of OCCTCurve3DGetLengthBetween that
/// measured through a pre-bounded GeomAdaptor_Curve, so it extrapolated past the curve's knots
/// instead of clamping and read a reversed range as zero length. Removed by #506.

/// OCCTCurve3DClosestParameter was declared here: a second spelling of the projection
/// OCCTCurve3DNearestParameter now performs. Removed by #500.

/// Create a trimmed copy of a 2D curve between parameters u1 and u2.
OCCTCurve2DRef _Nullable OCCTCurve2DTrimmed(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

// MARK: - gp_GTrsf2d (v0.116.0)

/// Create a 2D affinity transformation about an axis with given ratio.
/// Returns the 2x2 matrix (row-major) and translation vector.
void OCCTGTrsf2dAffinity(double axPx,
                         double axPy,
                         double axDx,
                         double axDy,
                         double ratio,
                         double* _Nonnull mat,
                         double* _Nonnull tx,
                         double* _Nonnull ty);

/// Multiply two GTrsf2d (each as 2x2 matrix + translation). Result = A * B.
void OCCTGTrsf2dMultiply(const double* _Nonnull matA,
                         double txA,
                         double tyA,
                         const double* _Nonnull matB,
                         double txB,
                         double tyB,
                         double* _Nonnull matR,
                         double* _Nonnull txR,
                         double* _Nonnull tyR);

/// Invert a GTrsf2d. Returns false if singular.
bool OCCTGTrsf2dInvert(const double* _Nonnull mat,
                       double tx,
                       double ty,
                       double* _Nonnull matR,
                       double* _Nonnull txR,
                       double* _Nonnull tyR);

/// Transform a 2D point by GTrsf2d.
void OCCTGTrsf2dTransformPoint(const double* _Nonnull mat,
                               double tx,
                               double ty,
                               double px,
                               double py,
                               double* _Nonnull rx,
                               double* _Nonnull ry);

// MARK: - gp_Mat2d (v0.116.0)

/// Create 2x2 identity matrix (row-major output: m11, m12, m21, m22).
void OCCTMat2dIdentity(double* _Nonnull mat);

/// Create 2x2 rotation matrix.
void OCCTMat2dRotation(double angle, double* _Nonnull mat);

/// Create 2x2 scale matrix.
void OCCTMat2dScale(double s, double* _Nonnull mat);

/// Determinant of 2x2 matrix.
double OCCTMat2dDeterminant(const double* _Nonnull mat);

/// Invert 2x2 matrix. Returns false if singular.
bool OCCTMat2dInvert(const double* _Nonnull mat, double* _Nonnull result);

/// Multiply two 2x2 matrices. Result = A * B.
void OCCTMat2dMultiply(const double* _Nonnull matA,
                       const double* _Nonnull matB,
                       double* _Nonnull result);

/// Transpose 2x2 matrix.
void OCCTMat2dTranspose(const double* _Nonnull mat, double* _Nonnull result);

// --- Curve2D Bezier methods ---

/// Get a pole from a 2D Bezier curve (1-based index).
void OCCTCurve2DBezierGetPole(OCCTCurve2DRef _Nonnull curve,
                              int32_t index,
                              double* _Nonnull x,
                              double* _Nonnull y);

/// Set a pole on a 2D Bezier curve (1-based index).
bool OCCTCurve2DBezierSetPole(OCCTCurve2DRef _Nonnull curve, int32_t index, double x, double y);

/// Set a weight on a 2D Bezier curve (1-based index).
bool OCCTCurve2DBezierSetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index, double weight);

/// Degree of a 2D Bezier curve.
int32_t OCCTCurve2DBezierDegree(OCCTCurve2DRef _Nonnull curve);

/// Number of poles of a 2D Bezier curve.
int32_t OCCTCurve2DBezierPoleCount(OCCTCurve2DRef _Nonnull curve);

/// Check if a 2D Bezier curve is rational.
bool OCCTCurve2DBezierIsRational(OCCTCurve2DRef _Nonnull curve);

/// Compute parameter resolution from 2D tolerance for a 2D Bezier curve.
double OCCTCurve2DBezierResolution(OCCTCurve2DRef _Nonnull curve, double tolerance);

// --- Curve2D BSpline extras ---

/// Set periodic/non-periodic on a 2D BSpline curve.
bool OCCTCurve2DBSplineSetPeriodic(OCCTCurve2DRef _Nonnull curve, bool periodic);

/// Get weight at index (1-based) from a 2D BSpline curve.
double OCCTCurve2DBSplineGetWeight(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Get all weights from a 2D BSpline curve (caller allocates array of size PoleCount).
void OCCTCurve2DBSplineGetWeights(OCCTCurve2DRef _Nonnull curve, double* _Nonnull weights);

// --- Curve2D continuity queries ---

/// Check if a 2D curve has Cn continuity.
bool OCCTCurve2DIsCN(OCCTCurve2DRef _Nonnull curve, int32_t n);

/// Get the reversed parameter value for a 2D curve.
double OCCTCurve2DReversedParameter(OCCTCurve2DRef _Nonnull curve, double u);

/// Get the maximum degree for 2D Bezier curves.
int32_t OCCTCurve2DBezierMaxDegree(void);

/// Get the maximum degree for 2D BSpline curves (static).
int32_t OCCTCurve2DBSplineMaxDegree(void);

// --- BSplineCurve 2D completions ---

/// Remove periodicity from 2D BSpline curve.
bool OCCTCurve2DBSplineSetNotPeriodic(OCCTCurve2DRef _Nonnull curve);

/// Set origin knot index (1-based) on periodic 2D BSpline curve.
bool OCCTCurve2DBSplineSetOrigin(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Increase multiplicity of knot at index to at least mult (1-based).
bool OCCTCurve2DBSplineIncreaseMultiplicity(OCCTCurve2DRef _Nonnull curve,
                                            int32_t index,
                                            int32_t mult);

/// Increment multiplicity of all knots from index1 to index2 by step (1-based).
bool OCCTCurve2DBSplineIncrementMultiplicity(OCCTCurve2DRef _Nonnull curve,
                                             int32_t index1,
                                             int32_t index2,
                                             int32_t step);

/// Set all knot values at once (count must match NbKnots).
bool OCCTCurve2DBSplineSetKnots(OCCTCurve2DRef _Nonnull curve,
                                const double* _Nonnull knots,
                                int32_t count);

/// Reverse parameterization of 2D BSpline curve.
bool OCCTCurve2DBSplineReverse(OCCTCurve2DRef _Nonnull curve);

/// Move point and tangent at parameter u on 2D BSpline curve.
bool OCCTCurve2DBSplineMovePointAndTangent(OCCTCurve2DRef _Nonnull curve,
                                           double  u,
                                           double  px,
                                           double  py,
                                           double  tx,
                                           double  ty,
                                           double  tolerance,
                                           int32_t startIndex,
                                           int32_t endIndex);

// --- Geom2d_BSplineCurve completions ---

/// Local D0 within knot span.
void OCCTCurve2DBSplineLocalD0(OCCTCurve2DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull x,
                               double* _Nonnull y);

/// Local D1 within knot span.
void OCCTCurve2DBSplineLocalD1(OCCTCurve2DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull v1x,
                               double* _Nonnull v1y);

/// Local D2 within knot span.
void OCCTCurve2DBSplineLocalD2(OCCTCurve2DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull v1x,
                               double* _Nonnull v1y,
                               double* _Nonnull v2x,
                               double* _Nonnull v2y);

/// Local D3 within knot span.
void OCCTCurve2DBSplineLocalD3(OCCTCurve2DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull v1x,
                               double* _Nonnull v1y,
                               double* _Nonnull v2x,
                               double* _Nonnull v2y,
                               double* _Nonnull v3x,
                               double* _Nonnull v3y);

/// Local DN within knot span.
void OCCTCurve2DBSplineLocalDN(OCCTCurve2DRef _Nonnull curve,
                               double  u,
                               int32_t fromK1,
                               int32_t toK2,
                               int32_t n,
                               double* _Nonnull vx,
                               double* _Nonnull vy);

/// Local value within knot span.
void OCCTCurve2DBSplineLocalValue(OCCTCurve2DRef _Nonnull curve,
                                  double  u,
                                  int32_t fromK1,
                                  int32_t toK2,
                                  double* _Nonnull x,
                                  double* _Nonnull y);

/// Locate U knot span. Returns I1 and I2 via out params.
void OCCTCurve2DBSplineLocateU(OCCTCurve2DRef _Nonnull curve,
                               double u,
                               double paramTol,
                               int32_t* _Nonnull i1,
                               int32_t* _Nonnull i2);

/// First U knot index.
int32_t OCCTCurve2DBSplineFirstUKnotIndex(OCCTCurve2DRef _Nonnull curve);

/// Last U knot index.
int32_t OCCTCurve2DBSplineLastUKnotIndex(OCCTCurve2DRef _Nonnull curve);

/// Get a single knot value by index (1-based).
double OCCTCurve2DBSplineKnot(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Knot distribution: 0=NonUniform, 1=Uniform, 2=QuasiUniform, 3=PiecewiseBezier.
int32_t OCCTCurve2DBSplineKnotDistribution(OCCTCurve2DRef _Nonnull curve);

/// Get multiplicity by index (1-based).
int32_t OCCTCurve2DBSplineMultiplicity(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Get all multiplicities. Array must be pre-allocated to KnotCount.
void OCCTCurve2DBSplineGetMultiplicities(OCCTCurve2DRef _Nonnull curve, int32_t* _Nonnull mults);

/// Get start point.
void OCCTCurve2DBSplineStartPoint(OCCTCurve2DRef _Nonnull curve,
                                  double* _Nonnull x,
                                  double* _Nonnull y);

/// Get end point.
void OCCTCurve2DBSplineEndPoint(OCCTCurve2DRef _Nonnull curve,
                                double* _Nonnull x,
                                double* _Nonnull y);

/// Get all poles as flat array (x1,y1,x2,y2,...). Array must be pre-allocated to NbPoles*2.
void OCCTCurve2DBSplineGetPoles(OCCTCurve2DRef _Nonnull curve, double* _Nonnull poles);

/// Is the curve closed?
bool OCCTCurve2DBSplineIsClosed(OCCTCurve2DRef _Nonnull curve);

/// Is the curve periodic?
bool OCCTCurve2DBSplineIsPeriodic(OCCTCurve2DRef _Nonnull curve);

/// Continuity: 0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2.
int32_t OCCTCurve2DBSplineContinuity(OCCTCurve2DRef _Nonnull curve);

/// IsCN: is the curve at least CN continuous?
bool OCCTCurve2DBSplineIsCN(OCCTCurve2DRef _Nonnull curve, int32_t n);

// --- Geom2d_BezierCurve completions ---

/// Insert a pole after index in a 2D Bezier curve.
bool OCCTCurve2DBezierInsertPoleAfter(OCCTCurve2DRef _Nonnull curve,
                                      int32_t index,
                                      double  x,
                                      double  y);

/// Remove a pole at index from a 2D Bezier curve.
bool OCCTCurve2DBezierRemovePole(OCCTCurve2DRef _Nonnull curve, int32_t index);

/// Segment a 2D Bezier curve to [u1, u2].
bool OCCTCurve2DBezierSegment(OCCTCurve2DRef _Nonnull curve, double u1, double u2);

/// Increase degree of a 2D Bezier curve.
bool OCCTCurve2DBezierIncreaseDegree(OCCTCurve2DRef _Nonnull curve, int32_t degree);

/// Get start point of a 2D Bezier curve.
void OCCTCurve2DBezierStartPoint(OCCTCurve2DRef _Nonnull curve,
                                 double* _Nonnull x,
                                 double* _Nonnull y);

/// Get end point of a 2D Bezier curve.
void OCCTCurve2DBezierEndPoint(OCCTCurve2DRef _Nonnull curve,
                               double* _Nonnull x,
                               double* _Nonnull y);

/// Get all poles of a 2D Bezier curve as flat array (x1,y1,x2,y2,...). Array must be pre-allocated
/// to PoleCount*2.
void OCCTCurve2DBezierGetPoles(OCCTCurve2DRef _Nonnull curve, double* _Nonnull poles);

/// Reverse the parameterization of a 2D Bezier curve.
bool OCCTCurve2DBezierReverse(OCCTCurve2DRef _Nonnull curve);

/// Transform a 2D curve in place using a gp_Trsf2d.
/// transformType: 0=translation(dx,dy), 1=rotation(cx,cy,angle), 2=scale(cx,cy,factor),
/// 3=mirror point(px,py), 4=mirror axis(ox,oy,dx,dy)
/// Four scalars, not five (#999): the widest case is mirror-axis, and no gp_Trsf2d setter this
/// dispatcher reaches takes a fifth. The 3D twin OCCTCurve3DTransform needs six for the same
/// reason it needs three coordinates per point.
bool OCCTCurve2DTransform(OCCTCurve2DRef _Nonnull curve,
                          int32_t transformType,
                          double  p1,
                          double  p2,
                          double  p3,
                          double  p4);

// --- Geom2dEval 2D Curve Evaluators ---

/// Evaluate Archimedean spiral D0 at parameter u. Returns 2D point.
/// C(t) = O + (a + b*t)*cos(t)*XDir + (a + b*t)*sin(t)*YDir
void OCCTGeom2dEvalArchimedeanSpiralD0(double initialRadius,
                                       double growthRate,
                                       double u,
                                       double* _Nonnull px,
                                       double* _Nonnull py);

/// Evaluate Archimedean spiral D1: point + first derivative.
void OCCTGeom2dEvalArchimedeanSpiralD1(double initialRadius,
                                       double growthRate,
                                       double u,
                                       double* _Nonnull px,
                                       double* _Nonnull py,
                                       double* _Nonnull vx,
                                       double* _Nonnull vy);

/// Evaluate logarithmic spiral D0 at parameter u.
/// C(t) = O + a*exp(b*t)*cos(t)*XDir + a*exp(b*t)*sin(t)*YDir
void OCCTGeom2dEvalLogSpiralD0(double scale,
                               double growthExponent,
                               double u,
                               double* _Nonnull px,
                               double* _Nonnull py);

/// Evaluate logarithmic spiral D1: point + derivative.
void OCCTGeom2dEvalLogSpiralD1(double scale,
                               double growthExponent,
                               double u,
                               double* _Nonnull px,
                               double* _Nonnull py,
                               double* _Nonnull vx,
                               double* _Nonnull vy);

/// Evaluate circle involute D0 at parameter u.
/// C(t) = O + R*(cos(t) + t*sin(t))*XDir + R*(sin(t) - t*cos(t))*YDir
void OCCTGeom2dEvalCircleInvoluteD0(double radius,
                                    double u,
                                    double* _Nonnull px,
                                    double* _Nonnull py);

/// Evaluate circle involute D1: point + derivative.
void OCCTGeom2dEvalCircleInvoluteD1(double radius,
                                    double u,
                                    double* _Nonnull px,
                                    double* _Nonnull py,
                                    double* _Nonnull vx,
                                    double* _Nonnull vy);

/// Evaluate 2D sine wave D0 at parameter u.
/// C(t) = O + t*XDir + A*sin(omega*t + phi)*YDir
void OCCTGeom2dEvalSineWaveD0(double amplitude,
                              double omega,
                              double phase,
                              double u,
                              double* _Nonnull px,
                              double* _Nonnull py);

/// Evaluate 2D sine wave D1: point + derivative.
void OCCTGeom2dEvalSineWaveD1(double amplitude,
                              double omega,
                              double phase,
                              double u,
                              double* _Nonnull px,
                              double* _Nonnull py,
                              double* _Nonnull vx,
                              double* _Nonnull vy);

// --- Geom2dEval TBezier / AHTBezier Curves ---

/// Create a 2D Trigonometric Bezier curve. poles: flat [x,y,...], count must be odd >= 3.
OCCTCurve2DRef _Nullable OCCTGeom2dEvalTBezierCurveCreate(const double* _Nonnull poles,
                                                          int32_t count,
                                                          double  alpha);

/// Create a 2D AHT Bezier curve. count = algDeg+1 + 2*(alpha>0) + 2*(beta>0).
OCCTCurve2DRef _Nullable OCCTGeom2dEvalAHTBezierCurveCreate(const double* _Nonnull poles,
                                                            int32_t count,
                                                            int32_t algDegree,
                                                            double  alpha,
                                                            double  beta);

#endif /* OCCTBridge_Geom2d_h */
