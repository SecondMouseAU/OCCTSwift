//
//  OCCTBridge_ProjLib_NLPlate.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the ProjLib_NLPlate domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_ProjLib_NLPlate_h
#define OCCTBridge_ProjLib_NLPlate_h

// MARK: - NLPlate: Advanced Plate Surfaces (v0.23.0)

/// Constraint order for advanced plate surface construction
typedef enum
{
  OCCTPlateConstraintG0 = 0, // Position only
  OCCTPlateConstraintG1 = 1, // Position + tangent
  OCCTPlateConstraintG2 = 2  // Position + tangent + curvature
} OCCTPlateConstraintOrder;

/// Create a plate surface through points with specified constraint orders.
/// points: flat array of (x,y,z). orders: G0/G1/G2 per point.
/// Returns a BSpline face approximation.
OCCTShapeRef OCCTShapePlatePointsAdvanced(const double*  points,
                                          int32_t        pointCount,
                                          const int32_t* orders,
                                          int32_t        degree,
                                          int32_t        nbPtsOnCur,
                                          int32_t        nbIter,
                                          double         tolerance);

/// Create a plate surface with mixed point and curve constraints.
OCCTShapeRef OCCTShapePlateMixed(const double*      points,
                                 const int32_t*     pointOrders,
                                 int32_t            pointCount,
                                 const OCCTWireRef* curves,
                                 const int32_t*     curveOrders,
                                 int32_t            curveCount,
                                 int32_t            degree,
                                 double             tolerance);

/// Create a plate surface (as parametric Surface) through points.
/// Uses GeomPlate_BuildPlateSurface + GeomPlate_MakeApprox.
OCCTSurfaceRef OCCTSurfacePlateThrough(const double* points,
                                       int32_t       pointCount,
                                       int32_t       degree,
                                       double        tolerance);

/// Deform a surface to pass through constraint points (NLPlate G0).
/// constraints: flat array of (u, v, targetX, targetY, targetZ) per point.
/// resolutionOrder is NLPlate_NLPlate::Solve2's `ord`, the plate's resolution order, and must be
/// in [2, 9]; anything else returns NULL (#1017).
OCCTSurfaceRef OCCTSurfaceNLPlateG0(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    int32_t        resolutionOrder,
                                    double         tolerance);

/// Deform a surface with position + tangent constraints (NLPlate G0+G1).
/// constraints: flat (u, v, targetX, targetY, targetZ, d1uX, d1uY, d1uZ, d1vX, d1vY, d1vZ) per
/// point.
/// resolutionOrder is bounded the same way as OCCTSurfaceNLPlateG0's (#1017).
OCCTSurfaceRef OCCTSurfaceNLPlateG1(OCCTSurfaceRef initialSurface,
                                    const double*  constraints,
                                    int32_t        constraintCount,
                                    int32_t        resolutionOrder,
                                    double         tolerance);

// MARK: - ProjLib: Curve Projection onto Surfaces (v0.22.0)

/// Project a 3D curve onto a surface, returning a 2D (UV) curve.
/// Uses GeomProjLib::Curve2d. Returns NULL on failure.
OCCTCurve2DRef OCCTSurfaceProjectCurve2D(OCCTSurfaceRef surface,
                                         OCCTCurve3DRef curve,
                                         double         tolerance);

/// Project a 3D curve onto a surface using composite projection (multiple segments).
/// Returns the number of 2D curve segments written to outCurves (up to maxCurves).
/// Uses ProjLib_CompProjectedCurve.
int32_t OCCTSurfaceProjectCurveSegments(OCCTSurfaceRef  surface,
                                        OCCTCurve3DRef  curve,
                                        double          tolerance,
                                        OCCTCurve2DRef* outCurves,
                                        int32_t         maxCurves);

/// Project a 3D curve onto a surface, returning the result as a 3D curve.
/// Uses GeomProjLib::Project. Returns NULL on failure.
OCCTCurve3DRef OCCTSurfaceProjectCurve3D(OCCTSurfaceRef surface, OCCTCurve3DRef curve);

/// Project a 3D curve onto a plane along a direction, returning a 3D curve.
/// Uses GeomProjLib::ProjectOnPlane.
/// (oX,oY,oZ) = plane origin, (nX,nY,nZ) = plane normal, (dX,dY,dZ) = projection direction.
OCCTCurve3DRef OCCTCurve3DProjectOnPlane(OCCTCurve3DRef curve,
                                         double         oX,
                                         double         oY,
                                         double         oZ,
                                         double         nX,
                                         double         nY,
                                         double         nZ,
                                         double         dX,
                                         double         dY,
                                         double         dZ);

/// Project a point onto a parametric surface (closest point).
/// Returns true on success, writing UV parameters and distance.
/// Uses GeomAPI_ProjectPointOnSurf.
bool OCCTSurfaceProjectPoint(OCCTSurfaceRef surface,
                             double         px,
                             double         py,
                             double         pz,
                             double*        u,
                             double*        v,
                             double*        distance);

// MARK: - GeomPlate_Surface (v0.61.0)

/// Build a plate surface through point constraints and return as a BSpline face.
/// @param points Array of point coordinates (x,y,z triples), length = ptCount*3
/// @param ptCount Number of points
/// @param tolerance Approximation tolerance
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum BSpline segments
/// @return Face shape with plate surface, or NULL on failure
OCCTShapeRef OCCTGeomPlateSurface(const double* points,
                                  int32_t       ptCount,
                                  double        tolerance,
                                  int32_t       maxDegree,
                                  int32_t       maxSegments);

// MARK: - v0.64.0: ProjLib, BRepOffset_Offset, Adaptor3d_IsoCurve,
// ShapeAnalysis_TransferParametersProj

// --- ProjLib_ComputeApprox ---
// Project a 3D curve (edge) onto a surface (face) → 2D BSpline curve edge
OCCTShapeRef _Nullable OCCTProjLibComputeApprox(OCCTShapeRef edgeShape,
                                                OCCTShapeRef faceShape,
                                                double       tolerance);

// --- ProjLib_ComputeApproxOnPolarSurface ---
// Project curve onto polar surface (sphere, torus, etc.)
OCCTShapeRef _Nullable OCCTProjLibComputeApproxOnPolarSurface(OCCTShapeRef edgeShape,
                                                              OCCTShapeRef faceShape,
                                                              double       tolerance);

// MARK: - v0.69.0: NLPlate G2/G3, Plate_Plate, GeomPlate_BuildAveragePlane,
// GeomFill_Generator/Bound

// --- NLPlate G0+G2 constraint ---

/// Deform a surface with position + tangent + curvature constraints (NLPlate G0+G2).
/// constraints: flat array per point of (u, v, targetX, targetY, targetZ,
///   d1uX,d1uY,d1uZ, d1vX,d1vY,d1vZ,
///   d2uuX,d2uuY,d2uuZ, d2uvX,d2uvY,d2uvZ, d2vvX,d2vvY,d2vvZ) = 20 doubles each.
/// No iteration count: NLPlate_NLPlate::Solve2(ord, InitialConsraintOrder) takes none. See the
/// note on the implementation for why IncrementalSolve is not the answer either (#999).
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateG2(OCCTSurfaceRef _Nonnull initialSurface,
                                              const double* _Nonnull constraints,
                                              int32_t constraintCount,
                                              double  tolerance);

/// Deform a surface with G0+G1+G2+G3 constraints.
/// constraints: flat array per point of 32 doubles each:
///   (u, v, targetX,Y,Z, d1uX,Y,Z, d1vX,Y,Z, d2uuX,Y,Z, d2uvX,Y,Z, d2vvX,Y,Z,
///    d3uuuX,Y,Z, d3uuvX,Y,Z, d3uvvX,Y,Z, d3vvvX,Y,Z)
/// No iteration count, for the same reason as OCCTSurfaceNLPlateG2 (#999).
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateG3(OCCTSurfaceRef _Nonnull initialSurface,
                                              const double* _Nonnull constraints,
                                              int32_t constraintCount,
                                              double  tolerance);

/// NLPlate with IncrementalSolve strategy (for challenging constraint sets).
/// Same constraint format as OCCTSurfaceNLPlateG0.
OCCTSurfaceRef _Nullable OCCTSurfaceNLPlateIncrementalG0(OCCTSurfaceRef _Nonnull initialSurface,
                                                         const double* _Nonnull constraints,
                                                         int32_t constraintCount,
                                                         int32_t maxOrder,
                                                         int32_t initConstraintOrder,
                                                         int32_t nbIncrements);

/// Evaluate derivative of NLPlate solution at a UV point.
/// Deforms initial surface, solves, and returns derivative (iu,iv) at UV.
/// Returns false if solve fails. Writes result to outX/Y/Z.
bool OCCTSurfaceNLPlateEvaluateDerivative(OCCTSurfaceRef _Nonnull initialSurface,
                                          const double* _Nonnull constraints,
                                          int32_t constraintCount,
                                          double  u,
                                          double  v,
                                          int32_t iu,
                                          int32_t iv,
                                          double* _Nonnull outX,
                                          double* _Nonnull outY,
                                          double* _Nonnull outZ);

/// Create a Plate_Plate solver.
OCCTPlateRef OCCTPlateCreate(void);

/// Release a Plate_Plate solver.
void OCCTPlateRelease(OCCTPlateRef plate);

/// Load a pinpoint constraint into the plate solver.
/// @param iu, iv Derivative orders (0 for position, 1+ for derivatives)
void OCCTPlateLoadPinpoint(OCCTPlateRef plate,
                           double       u,
                           double       v,
                           double       x,
                           double       y,
                           double       z,
                           int32_t      iu,
                           int32_t      iv);

/// Load a G-to-C constraint (G1 level: source D1 → target D1).
/// d1s/d1t: flat (duX,duY,duZ, dvX,dvY,dvZ) = 6 doubles each.
void OCCTPlateLoadGtoC(OCCTPlateRef plate,
                       double       u,
                       double       v,
                       const double* _Nonnull d1s,
                       const double* _Nonnull d1t);

/// Solve the plate.
/// @param order Solution polynomial order (default 4)
/// @param anisotropy Anisotropy parameter (default 1.0)
/// @return true if solve succeeded
bool OCCTPlateSolve(OCCTPlateRef plate, int32_t order, double anisotropy);

/// Check if plate solve succeeded.
bool OCCTPlateIsDone(OCCTPlateRef plate);

/// Evaluate the plate at a UV point. Returns (x,y,z).
void OCCTPlateEvaluate(OCCTPlateRef plate,
                       double       u,
                       double       v,
                       double* _Nonnull outX,
                       double* _Nonnull outY,
                       double* _Nonnull outZ);

/// Evaluate derivative at a UV point.
void OCCTPlateEvaluateDerivative(OCCTPlateRef plate,
                                 double       u,
                                 double       v,
                                 int32_t      iu,
                                 int32_t      iv,
                                 double* _Nonnull outX,
                                 double* _Nonnull outY,
                                 double* _Nonnull outZ);

/// Get UV bounding box of constraints.
void OCCTPlateUVBox(OCCTPlateRef plate,
                    double* _Nonnull umin,
                    double* _Nonnull umax,
                    double* _Nonnull vmin,
                    double* _Nonnull vmax);

/// Get continuity order of the plate solution.
int32_t OCCTPlateContinuity(OCCTPlateRef plate);

// --- GeomPlate_BuildAveragePlane ---

/// Result struct for average plane computation.
typedef struct
{
  bool   isPlane;
  bool   isLine;
  double normalX, normalY, normalZ;             // plane normal (if isPlane)
  double originX, originY, originZ;             // plane origin (if isPlane)
  double umin, umax, vmin, vmax;                // min-max box on plane
  double lineOriginX, lineOriginY, lineOriginZ; // line origin (if isLine)
  double lineDirX, lineDirY, lineDirZ;          // line direction (if isLine)
} OCCTAveragePlaneResult;

/// Compute average plane (or line) through a set of 3D points.
/// @param points Flat array of (x,y,z) triples
/// @param pointCount Number of points
/// @param nbBoundPoints Number of boundary points (for plane orientation)
/// @param tolerance Tolerance
/// @return Average plane result
OCCTAveragePlaneResult OCCTGeomPlateBuildAveragePlane(const double* _Nonnull points,
                                                      int32_t pointCount,
                                                      int32_t nbBoundPoints,
                                                      double  tolerance);

// OCCTGeomPlateErrors is deliberately gone (#999). It reported
// GeomPlate_BuildPlateSurface::G0Error/G1Error/G2Error for a point-only plate, and the kernel never
// assigns myG0Error/myG1Error/myG2Error on that path: VerifSurface() is the only writer and it runs
// only when there are curve constraints, while the point branch computes its deviations into three
// locals and discards them. The members have no initialiser, so the three doubles were
// uninitialised memory. Measured through the real bridge: repeated calls on one fixture
// returned 1.94e-313, -3.11e+231 and then -nan, and no value moved with tolerance, maxDegree or
// maxSegments. A curve-constraint entry point would be a real one; that is new API, not a repair of
// this.

// MARK: - ShapeConstruct_ProjectCurveOnSurface

/// Project a 3D curve onto a surface, returning a 2D curve.
OCCTCurve2DRef _Nullable OCCTProjectCurveOnSurface(OCCTCurve3DRef _Nonnull curve,
                                                   OCCTSurfaceRef _Nonnull surface,
                                                   double firstParam,
                                                   double lastParam,
                                                   double precision);

// --- ProjLib_ProjectOnSurface ---
/// Project a 3D curve onto a surface, returning BSpline approximation
OCCTCurve3DRef _Nullable OCCTProjLibProjectOnSurface(OCCTCurve3DRef _Nonnull curve,
                                                     double uFirst,
                                                     double uLast,
                                                     OCCTSurfaceRef _Nonnull surface,
                                                     double tolerance);

// MARK: - Plate Constraint Extensions (v0.103.0)

/// Create plate plane constraint and load into solver. Returns true if loaded.
bool OCCTPlateLoadPlaneConstraint(OCCTPlateRef _Nonnull plate,
                                  double u,
                                  double v,
                                  double px,
                                  double py,
                                  double pz,
                                  double nx,
                                  double ny,
                                  double nz);

/// Create plate line constraint and load into solver. Returns true if loaded.
bool OCCTPlateLoadLineConstraint(OCCTPlateRef _Nonnull plate,
                                 double u,
                                 double v,
                                 double px,
                                 double py,
                                 double pz,
                                 double dx,
                                 double dy,
                                 double dz);

/// Create plate free G1 constraint. Returns true if loaded.
bool OCCTPlateLoadFreeG1Constraint(OCCTPlateRef _Nonnull plate,
                                   double u,
                                   double v,
                                   double duX,
                                   double duY,
                                   double duZ,
                                   double dvX,
                                   double dvY,
                                   double dvZ);

// MARK: - Plate Constraints Extensions (v0.109.0)

/// Load a global translation constraint on the plate solver.
/// All sample points are constrained to move by the same unknown displacement.
/// @param plate The Plate_Plate solver ref
/// @param uvs Array of [u,v] pairs (count*2 doubles)
/// @param count Number of UV points
/// @return true on success
bool OCCTPlateLoadGlobalTranslation(OCCTPlateRef _Nonnull plate,
                                    const double* _Nonnull uvs,
                                    int32_t count);

/// Load a linear XYZ constraint on the plate solver.
/// @param plate The Plate_Plate solver ref
/// @param uvs Array of [u,v] pairs (count*2 doubles)
/// @param targets Array of [x,y,z] target values (count*3 doubles)
/// @param coeffs Array of coefficients (count doubles)
/// @param count Number of constraint points
/// @return true on success
bool OCCTPlateLoadLinearXYZ(OCCTPlateRef _Nonnull plate,
                            const double* _Nonnull uvs,
                            const double* _Nonnull targets,
                            const double* _Nonnull coeffs,
                            int32_t count);

// MARK: - ProjLib (v0.117.0)

/// Project 3D line onto plane, return 2D line parameters.
bool OCCTProjLibPlaneProjectLine(double plnPx,
                                 double plnPy,
                                 double plnPz,
                                 double plnNx,
                                 double plnNy,
                                 double plnNz,
                                 double linPx,
                                 double linPy,
                                 double linPz,
                                 double linDx,
                                 double linDy,
                                 double linDz,
                                 double* _Nonnull resPx,
                                 double* _Nonnull resPy,
                                 double* _Nonnull resDx,
                                 double* _Nonnull resDy);

/// Project 3D line onto cylinder, return 2D line parameters.
bool OCCTProjLibCylinderProjectLine(double cylPx,
                                    double cylPy,
                                    double cylPz,
                                    double cylDx,
                                    double cylDy,
                                    double cylDz,
                                    double cylRadius,
                                    double linPx,
                                    double linPy,
                                    double linPz,
                                    double linDx,
                                    double linDy,
                                    double linDz,
                                    double* _Nonnull resPx,
                                    double* _Nonnull resPy,
                                    double* _Nonnull resDx,
                                    double* _Nonnull resDy);

/// Project 3D circle onto plane, return 2D circle parameters.
bool OCCTProjLibPlaneProjectCircle(double plnPx,
                                   double plnPy,
                                   double plnPz,
                                   double plnNx,
                                   double plnNy,
                                   double plnNz,
                                   double cirCx,
                                   double cirCy,
                                   double cirCz,
                                   double cirNx,
                                   double cirNy,
                                   double cirNz,
                                   double cirRadius,
                                   double* _Nonnull resCx,
                                   double* _Nonnull resCy,
                                   double* _Nonnull resRadius);

#endif /* OCCTBridge_ProjLib_NLPlate_h */
