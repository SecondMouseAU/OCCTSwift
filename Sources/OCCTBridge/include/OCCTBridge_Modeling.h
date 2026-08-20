//
//  OCCTBridge_Modeling.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Modeling domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Modeling_h
#define OCCTBridge_Modeling_h

// MARK: - Shape Creation (Primitives)

OCCTShapeRef OCCTShapeCreateBox(double width, double height, double depth);
OCCTShapeRef OCCTShapeCreateBoxAt(double x,
                                  double y,
                                  double z,
                                  double width,
                                  double height,
                                  double depth);
OCCTShapeRef _Nullable OCCTShapeCreateBoxOriented(double originX,
                                                  double originY,
                                                  double originZ,
                                                  double dirX,
                                                  double dirY,
                                                  double dirZ,
                                                  double width,
                                                  double height,
                                                  double depth);
OCCTShapeRef OCCTShapeCreateCylinder(double radius, double height);
OCCTShapeRef OCCTShapeCreateCylinderAt(double cx,
                                       double cy,
                                       double bottomZ,
                                       double radius,
                                       double height);
/// Create a cylinder at an arbitrary origin along an arbitrary direction.
OCCTShapeRef _Nullable OCCTShapeCreateCylinderOriented(double originX,
                                                       double originY,
                                                       double originZ,
                                                       double dirX,
                                                       double dirY,
                                                       double dirZ,
                                                       double radius,
                                                       double height);
OCCTShapeRef _Nullable OCCTShapeCreateCylinderPartial(double radius, double height, double angle);
OCCTShapeRef OCCTShapeCreateToolSweep(double radius,
                                      double height,
                                      double x1,
                                      double y1,
                                      double z1,
                                      double x2,
                                      double y2,
                                      double z2);
OCCTShapeRef OCCTShapeCreateSphere(double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSphereAtCenter(double cx,
                                                     double cy,
                                                     double cz,
                                                     double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOriented(double originX,
                                                     double originY,
                                                     double originZ,
                                                     double dirX,
                                                     double dirY,
                                                     double dirZ,
                                                     double radius);
OCCTShapeRef _Nullable OCCTShapeCreateSpherePartial(double radius, double angle);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOrientedPartial(double originX,
                                                            double originY,
                                                            double originZ,
                                                            double dirX,
                                                            double dirY,
                                                            double dirZ,
                                                            double radius,
                                                            double angle);
OCCTShapeRef _Nullable OCCTShapeCreateSphereOrientedSegment(double originX,
                                                            double originY,
                                                            double originZ,
                                                            double dirX,
                                                            double dirY,
                                                            double dirZ,
                                                            double radius,
                                                            double angle1,
                                                            double angle2);
OCCTShapeRef OCCTShapeCreateCone(double bottomRadius, double topRadius, double height);
OCCTShapeRef _Nullable OCCTShapeCreateConeOriented(double originX,
                                                   double originY,
                                                   double originZ,
                                                   double dirX,
                                                   double dirY,
                                                   double dirZ,
                                                   double bottomRadius,
                                                   double topRadius,
                                                   double height);
OCCTShapeRef _Nullable OCCTShapeCreateConeOrientedPartial(double originX,
                                                          double originY,
                                                          double originZ,
                                                          double dirX,
                                                          double dirY,
                                                          double dirZ,
                                                          double bottomRadius,
                                                          double topRadius,
                                                          double height,
                                                          double angle);
OCCTShapeRef OCCTShapeCreateTorus(double majorRadius, double minorRadius);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOriented(double originX,
                                                    double originY,
                                                    double originZ,
                                                    double dirX,
                                                    double dirY,
                                                    double dirZ,
                                                    double majorRadius,
                                                    double minorRadius);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOrientedPartial(double originX,
                                                           double originY,
                                                           double originZ,
                                                           double dirX,
                                                           double dirY,
                                                           double dirZ,
                                                           double majorRadius,
                                                           double minorRadius,
                                                           double angle);
OCCTShapeRef _Nullable OCCTShapeCreateTorusOrientedSegment(double originX,
                                                           double originY,
                                                           double originZ,
                                                           double dirX,
                                                           double dirY,
                                                           double dirZ,
                                                           double majorRadius,
                                                           double minorRadius,
                                                           double angle1,
                                                           double angle2);
OCCTShapeRef _Nullable OCCTShapeCreateCylinderOrientedPartial(double originX,
                                                              double originY,
                                                              double originZ,
                                                              double dirX,
                                                              double dirY,
                                                              double dirZ,
                                                              double radius,
                                                              double height,
                                                              double angle);

// MARK: - Shape Creation (Sweeps)

OCCTShapeRef OCCTShapeCreatePipeSweep(OCCTWireRef profile, OCCTWireRef path);
OCCTShapeRef OCCTShapeCreateExtrusion(OCCTWireRef profile,
                                      double      dx,
                                      double      dy,
                                      double      dz,
                                      double      length);
/// Extrude a shape along a direction to infinity (or semi-infinite).
OCCTShapeRef _Nullable OCCTShapeCreateExtrusionInfinite(OCCTShapeRef _Nonnull shape,
                                                        double dirX,
                                                        double dirY,
                                                        double dirZ,
                                                        bool   infinite);
/// Extrude a shape by a vector (general shape, not just wire).
OCCTShapeRef _Nullable OCCTShapeCreateExtrusionShape(OCCTShapeRef _Nonnull shape,
                                                     double dx,
                                                     double dy,
                                                     double dz);
OCCTShapeRef OCCTShapeCreateRevolution(OCCTWireRef profile,
                                       double      axisX,
                                       double      axisY,
                                       double      axisZ,
                                       double      dirX,
                                       double      dirY,
                                       double      dirZ,
                                       double      angle);
/// Revolve a shape (not just wire) around an axis by a full 360 degrees.
OCCTShapeRef _Nullable OCCTShapeCreateRevolutionFull(OCCTShapeRef _Nonnull shape,
                                                     double axisX,
                                                     double axisY,
                                                     double axisZ,
                                                     double dirX,
                                                     double dirY,
                                                     double dirZ);
/// Revolve a shape (not just wire) around an axis by a partial angle.
OCCTShapeRef _Nullable OCCTShapeCreateRevolutionPartial(OCCTShapeRef _Nonnull shape,
                                                        double axisX,
                                                        double axisY,
                                                        double axisZ,
                                                        double dirX,
                                                        double dirY,
                                                        double dirZ,
                                                        double angle);
OCCTShapeRef OCCTShapeCreateLoft(const OCCTWireRef* profiles, int32_t count, bool solid);

// MARK: - Boolean Operations

OCCTShapeRef OCCTShapeUnion(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeSubtract(OCCTShapeRef shape1, OCCTShapeRef shape2);
OCCTShapeRef OCCTShapeIntersect(OCCTShapeRef shape1, OCCTShapeRef shape2);

// Boolean ops with robustness levers: fuzzyValue (tolerance-based fuzzy boolean;
// <= 0 keeps OCCT's default), glue (0 = off, 1 = BOPAlgo_GlueShift, 2 = BOPAlgo_GlueFull;
// glue helps when arguments share coincident faces). #202
// timeoutSeconds bounds the build via a wall-clock UserBreak watchdog; <= 0 means no
// bound. On timeout (or failure) the op returns NULL instead of hanging. #206
OCCTShapeRef OCCTShapeUnionEx(OCCTShapeRef shape1,
                              OCCTShapeRef shape2,
                              double       fuzzyValue,
                              int32_t      glue,
                              double       timeoutSeconds);
OCCTShapeRef OCCTShapeSubtractEx(OCCTShapeRef shape1,
                                 OCCTShapeRef shape2,
                                 double       fuzzyValue,
                                 int32_t      glue,
                                 double       timeoutSeconds);
OCCTShapeRef OCCTShapeIntersectEx(OCCTShapeRef shape1,
                                  OCCTShapeRef shape2,
                                  double       fuzzyValue,
                                  int32_t      glue,
                                  double       timeoutSeconds);

// Self-interference check (BOPAlgo_ArgumentAnalyzer), watchdog-bounded by timeoutSeconds
// (<= 0 = unbounded). Detects the self-intersection that BRepCheck misses and that hangs
// booleans (#206/#208). Returns 1 = self-intersects, 0 = clean, -1 = indeterminate.
// (Distinct from the older unbounded bool OCCTShapeSelfIntersects via BOPAlgo_CheckerSI.)
int32_t OCCTShapeSelfIntersectsBounded(OCCTShapeRef shape, double timeoutSeconds);

// MARK: - Modifications

OCCTShapeRef OCCTShapeFillet(OCCTShapeRef shape, double radius);
OCCTShapeRef OCCTShapeChamfer(OCCTShapeRef shape, double distance);
OCCTShapeRef OCCTShapeShell(OCCTShapeRef shape, double thickness);
OCCTShapeRef OCCTShapeOffset(OCCTShapeRef shape, double distance);

// MARK: - Transformations

OCCTShapeRef OCCTShapeTranslate(OCCTShapeRef shape, double dx, double dy, double dz);
OCCTShapeRef OCCTShapeRotate(OCCTShapeRef shape,
                             double       axisX,
                             double       axisY,
                             double       axisZ,
                             double       angle);
OCCTShapeRef OCCTShapeScale(OCCTShapeRef shape, double factor);
OCCTShapeRef OCCTShapeMirror(OCCTShapeRef shape,
                             double       originX,
                             double       originY,
                             double       originZ,
                             double       normalX,
                             double       normalY,
                             double       normalZ);

// MARK: - Compound

OCCTShapeRef OCCTShapeCreateCompound(const OCCTShapeRef* shapes, int32_t count);

// MARK: - Wire Creation (2D Profiles)

OCCTWireRef OCCTWireCreateRectangle(double width, double height);
OCCTWireRef OCCTWireCreateCircle(double radius);
OCCTWireRef OCCTWireCreateCircleEx(double radius,
                                   double ox,
                                   double oy,
                                   double oz,
                                   double nx,
                                   double ny,
                                   double nz);
OCCTWireRef OCCTWireCreatePolygon(const double* points, int32_t pointCount, bool closed);
OCCTWireRef OCCTWireCreateFromPoints3D(const double* points, int32_t pointCount, bool closed);

// MARK: - Wire Creation (3D Paths)

OCCTWireRef OCCTWireCreateLine(double x1, double y1, double z1, double x2, double y2, double z2);
OCCTWireRef OCCTWireCreateArc(double centerX,
                              double centerY,
                              double centerZ,
                              double radius,
                              double startAngle,
                              double endAngle,
                              double normalX,
                              double normalY,
                              double normalZ);
/// Build an arc-wire from three points (start, midpoint on the arc, end).
/// Avoids the gp_Ax2 X-direction ambiguity that the angle-based arc API has.
/// Returns NULL if the three points are collinear or the arc cannot be built.
OCCTWireRef OCCTWireCreateArcThroughPoints(double sx,
                                           double sy,
                                           double sz,
                                           double mx,
                                           double my,
                                           double mz,
                                           double ex,
                                           double ey,
                                           double ez);
OCCTWireRef OCCTWireCreateBSpline(const double* controlPoints, int32_t pointCount);
OCCTWireRef OCCTWireJoin(const OCCTWireRef* wires, int32_t count);

// MARK: - NURBS Curve Creation

/// Create a NURBS curve with full control over all parameters
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (count = poleCount, NULL for uniform weights)
/// @param knots Knot values (count = knotCount)
/// @param knotCount Number of distinct knot values
/// @param multiplicities Multiplicity of each knot (count = knotCount, NULL for all 1s)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic, etc.)
OCCTWireRef OCCTWireCreateNURBS(const double*  poles,
                                int32_t        poleCount,
                                const double*  weights,
                                const double*  knots,
                                int32_t        knotCount,
                                const int32_t* multiplicities,
                                int32_t        degree);

/// Create a NURBS curve with uniform knots (clamped, uniform parameterization)
/// @param poles Control points as [x,y,z] triplets (count = poleCount * 3)
/// @param poleCount Number of control points
/// @param weights Weight for each control point (NULL for uniform weights = non-rational B-spline)
/// @param degree Curve degree (1=linear, 2=quadratic, 3=cubic)
OCCTWireRef OCCTWireCreateNURBSUniform(const double* poles,
                                       int32_t       poleCount,
                                       const double* weights,
                                       int32_t       degree);

/// Create a clamped cubic B-spline through given control points (non-rational)
/// @param poles Control points as [x,y,z] triplets
/// @param poleCount Number of control points (minimum 4 for cubic)
OCCTWireRef OCCTWireCreateCubicBSpline(const double* poles, int32_t poleCount);

// MARK: - Slicing

OCCTShapeRef OCCTShapeSliceAtZ(OCCTShapeRef shape, double z);
// OCCTShapeGetEdgeCount is gone: it was a TopExp_Explorer occurrence count with no caller, and it
// disagreed with OCCTShapeGetTotalEdgeCount (24 vs 12 on a plain box). Use that one. #502
int32_t OCCTShapeGetEdgePoints(OCCTShapeRef shape,
                               int32_t      edgeIndex,
                               double*      outPoints,
                               int32_t      maxPoints);
int32_t OCCTShapeGetContourPoints(OCCTShapeRef shape, double* outPoints, int32_t maxPoints);

// MARK: - CAM Operations

/// Offset a planar wire by a distance (positive = outward, negative = inward)
/// @param wire The wire to offset (must be planar)
/// @param distance Offset distance (positive = outward, negative = inward)
/// @param joinType Join type: 0 = arc (round corners), 1 = intersection (sharp corners)
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset(OCCTWireRef wire, double distance, int32_t joinType);

/// Get closed wires from a shape section at Z level
/// @param shape The shape to section
/// @param z The Z level to section at
/// @param tolerance Tolerance for connecting edges into wires (use 1e-6 for default)
/// @param outCount Output: number of wires returned
/// @return Array of wire references, or NULL on failure. Caller must free with OCCTFreeWireArray.
OCCTWireRef* OCCTShapeSectionWiresAtZ(OCCTShapeRef shape,
                                      double       z,
                                      double       tolerance,
                                      int32_t*     outCount);

/// Free an array of wires returned by OCCTShapeSectionWiresAtZ (frees wires AND array)
/// @param wires Array of wire references
/// @param count Number of wires in the array
void OCCTFreeWireArray(OCCTWireRef* wires, int32_t count);

/// Free only the array container, not the wires - use when Swift takes ownership of wire handles
/// @param wires Array of wire references
void OCCTFreeWireArrayOnly(OCCTWireRef* wires);

/// Projection type
typedef enum
{
  OCCTProjectionOrthographic = 0,
  OCCTProjectionPerspective  = 1
} OCCTProjectionType;

/// Edge visibility type
typedef enum
{
  OCCTEdgeTypeVisible = 0,
  OCCTEdgeTypeHidden  = 1,
  OCCTEdgeTypeOutline = 2
} OCCTEdgeType;

/// Create 2D projection using Hidden Line Removal (HLR)
/// @param shape Shape to project
/// @param dirX, dirY, dirZ View direction (will be normalized)
/// @param projectionType Orthographic or perspective projection
/// @param focus Eye-to-origin distance along the view direction, used only for
///        OCCTProjectionPerspective, where it must be > 0. Ignored for the orthographic case.
/// @return Drawing reference, or NULL on failure
OCCTDrawingRef OCCTDrawingCreate(OCCTShapeRef       shape,
                                 double             dirX,
                                 double             dirY,
                                 double             dirZ,
                                 OCCTProjectionType projectionType,
                                 double             focus);

/// Release drawing resources
void OCCTDrawingRelease(OCCTDrawingRef drawing);

/// Get projected edges by visibility type as a compound shape
/// @param drawing Drawing to query
/// @param edgeType Type of edges to retrieve
/// @return Shape containing 2D edges (caller must release), or NULL if no edges
OCCTShapeRef OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType);

// MARK: - Advanced Modeling (v0.8.0)

/// Fillet specific edges with uniform radius
///
/// One of three entry points sharing occtShapeFilletEdgeList (OCCTBridge_Internal.h) with
/// OCCTShapeFilletEdgesLinear and OCCTShapeBlendEdges: same edge map, same 0-based index bounds
/// check, same positive-radius precondition. #489
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based; an index naming no edge of `shape` rejects
///   the whole call, #520)
/// @param edgeCount Number of edges to fillet
/// @param radius Fillet radius; must be > 0, or the call fails without touching OCCT
/// @param declinedEdgeIndices Optional (may be NULL): filled with the 0-based indices, from
///   `edgeIndices`, that OCCT declined to fillet (#639) -- a free-boundary edge, e.g. Must have
///   capacity >= edgeCount when non-NULL.
/// @param outDeclinedCount Optional (may be NULL): set to the number of entries written to
///   `declinedEdgeIndices`. **Read it only when the returned shape is non-NULL.** It is zeroed on
///   entry, so an early failure leaves 0, but a Build() failure returns NULL with the count already
///   written, and that count describes a shape the caller never receives.
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdges(OCCTShapeRef   shape,
                                  const int32_t* edgeIndices,
                                  int32_t        edgeCount,
                                  double         radius,
                                  int32_t* _Nullable declinedEdgeIndices,
                                  int32_t* _Nullable outDeclinedCount);

/// Fillet specific edges with linear radius interpolation
///
/// Shares occtShapeFilletEdgeList with OCCTShapeFilletEdges and OCCTShapeBlendEdges. #489
///
/// The law goes to each edge's own slot in its own contour, not to (NbContours(), 1). This is
/// observable here despite the batch sharing one law: with startRadius != endRadius, two
/// tangent-continuous edges written to slot 1 measure exactly as filleting the first alone
/// (10273.238348 on a slot rim at 1 -> 4) against 10297.711861 with each in its own slot. Done with
/// OCCT's own one-call Add(R1, R2, E), which is Add(E) + the same slot resolution + SetRadius. #612
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based; an index naming no edge of `shape` rejects
///   the whole call, #520). An edge OCCT declines to add is skipped, as Add(Radius, E) skips it.
/// @param edgeCount Number of edges to fillet
/// @param startRadius Radius at the start of each named edge's law; must be > 0
/// @param endRadius Radius at the end of each named edge's law; must be > 0
/// @param declinedEdgeIndices Optional (may be NULL): same #639 reporting contract as
///   OCCTShapeFilletEdges.
/// @param outDeclinedCount Optional (may be NULL): same contract as OCCTShapeFilletEdges.
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEdgesLinear(OCCTShapeRef   shape,
                                        const int32_t* edgeIndices,
                                        int32_t        edgeCount,
                                        double         startRadius,
                                        double         endRadius,
                                        int32_t* _Nullable declinedEdgeIndices,
                                        int32_t* _Nullable outDeclinedCount);

/// Add draft angle to faces for mold release
/// @param shape The shape to draft
/// @param faceIndices Array of face indices (0-based)
/// @param faceCount Number of faces to draft
/// @param dirX, dirY, dirZ Pull direction (typically vertical)
/// @param angle Draft angle in radians
/// @param planeX, planeY, planeZ Point on neutral plane
/// @param planeNx, planeNy, planeNz Normal of neutral plane
/// @return Drafted shape, or NULL on failure, including when an index names no face of `shape`,
///         which since #568 fails the call rather than being skipped. Skipping was worse here than
///         anywhere else in that sweep: BRepOffsetAPI_DraftAngle reports IsDone() for a request it
///         was handed no faces for, so a wholly unresolvable list returned `shape` undrafted.
OCCTShapeRef OCCTShapeDraft(OCCTShapeRef   shape,
                            const int32_t* faceIndices,
                            int32_t        faceCount,
                            double         dirX,
                            double         dirY,
                            double         dirZ,
                            double         angle,
                            double         planeX,
                            double         planeY,
                            double         planeZ,
                            double         planeNx,
                            double         planeNy,
                            double         planeNz);

/// Remove features (faces) from shape using defeaturing (BRepAlgoAPI_Defeaturing).
/// The shape-addressed form is OCCTShapeDefeature; for the same operation with history see
/// OCCTShapeHistoryFromDefeature. All of them share one skeleton — see the defeaturing block in
/// OCCTBridge_Internal.h. #497
/// @param shape The shape to modify
/// @param faceIndices Array of face indices to remove (0-based, into the shape's own face map)
/// @param faceCount Number of faces to remove
/// @return Shape with features removed, or NULL on failure — including when faceCount is 0 or an
///         index is out of range, which since #497 fails the call rather than being skipped
OCCTShapeRef OCCTShapeRemoveFeatures(OCCTShapeRef   shape,
                                     const int32_t* faceIndices,
                                     int32_t        faceCount);

/// Pipe sweep mode for advanced sweeps
typedef enum
{
  OCCTPipeModeFrenet          = 0, // Standard Frenet trihedron
  OCCTPipeModeCorrectedFrenet = 1, // Corrected for singularities
  OCCTPipeModeFixedBinormal   = 2, // Fixed binormal direction
  OCCTPipeModeAuxiliary       = 3  // Guided by auxiliary curve
} OCCTPipeMode;

/// Create a pipe shell by sweeping one or more profiles along a spine (issues #180, #503).
/// Adds each profile (positioned in 3D along the spine) to a single
/// BRepOffsetAPI_MakePipeShell, producing a swept solid/shell that interpolates between
/// sections. This is the only Add()-based pipe shell in the bridge: pass profileCount = 1
/// for an ordinary single-profile sweep. It supersedes OCCTShapeCreatePipeShell,
/// OCCTShapeCreatePipeShellWithBinormal, OCCTShapeCreatePipeShellWithAuxSpine and
/// OCCTShapeCreatePipeShellWithTransition, which were this function with arguments nailed
/// shut and which silently swept Frenet when asked for a mode they could not express (#503).
/// Every orientation mode is honoured:
///   - OCCTPipeModeFixedBinormal uses (bnX, bnY, bnZ), and fails the call rather than
///     substituting another mode if that vector is zero-length
///   - OCCTPipeModeAuxiliary uses auxSpine, and fails the call if it is NULL
/// @param spine Path wire for sweep
/// @param profiles Array of profile wires (length profileCount, all non-NULL)
/// @param profileCount Number of profiles (>= 1)
/// @param mode Sweep mode controlling profile orientation
/// @param bnX, bnY, bnZ Fixed binormal (used only for OCCTPipeModeFixedBinormal)
/// @param auxSpine Auxiliary spine (used only for OCCTPipeModeAuxiliary; else NULL)
/// @param transitionMode Corner behaviour at spine discontinuities:
///        0=Transformed (OCCT's own default), 1=RightCorner, 2=RoundCorner
/// @param withContact If true, move each profile to touch the spine before sweeping
/// @param withCorrection If true, rotate the profile to stay orthogonal to the spine
/// @param solid If true, create solid; if false, create shell
/// @return Swept shape, or NULL on failure
OCCTShapeRef OCCTShapeCreatePipeShellMultiSection(OCCTWireRef        spine,
                                                  const OCCTWireRef* profiles,
                                                  int32_t            profileCount,
                                                  OCCTPipeMode       mode,
                                                  double             bnX,
                                                  double             bnY,
                                                  double             bnZ,
                                                  OCCTWireRef        auxSpine,
                                                  int32_t            transitionMode,
                                                  bool               withContact,
                                                  bool               withCorrection,
                                                  bool               solid);

/// Build one thread-start cutter as a SMOOTH analytic helicoid solid (issue #187).
/// Each of the 4 ISO-68 V-profile corners traces a BSpline helix; the cutter is the
/// solid bounded by ruled faces (BRepFill::Face) between consecutive corner-helices plus
/// two V end caps, sewn. O(1) faces (no faceting), in-envelope, vs the MakePipeShell sweep
/// which bulges with the helix lead. The axis frame is given by (origin, axis-unit,
/// radial0-unit, with tangential0 = axis x radial0 computed internally).
/// @param ox,oy,oz Axis origin (a point on the thread axis)
/// @param ax,ay,az Thread axis direction (unit)
/// @param rx,ry,rz radial0 (unit, perpendicular to the axis)
/// @param pitch Axial advance per turn; turns Number of turns
/// @param apexSign -1 external (apex inward) / +1 internal (apex outward into the wall)
/// @param helixRadius Thread pitch-line radius (nominal/2)
/// @param cutDepth, rootHalf, crestHalf, bleed ISO-68 V-form dimensions
/// @param phase Angular start offset (radians; multi-start); handed -1 left-handed / +1 right
/// @param nSections BSpline interpolation samples per corner helix
/// @return The cutter solid, or NULL on failure
OCCTShapeRef OCCTShapeBuildThreadCutter(double  ox,
                                        double  oy,
                                        double  oz,
                                        double  ax,
                                        double  ay,
                                        double  az,
                                        double  rx,
                                        double  ry,
                                        double  rz,
                                        double  pitch,
                                        double  turns,
                                        double  apexSign,
                                        double  helixRadius,
                                        double  cutDepth,
                                        double  outerHalf,
                                        double  apexHalf,
                                        double  bleed,
                                        double  phase,
                                        double  handed,
                                        int32_t nSections);

/// Offset wire in 3D space along a direction
/// @param wire The wire to offset
/// @param distance Offset distance
/// @param dirX, dirY, dirZ Direction vector for offset
/// @return Offset wire, or NULL on failure
OCCTWireRef OCCTWireOffset3D(OCCTWireRef wire,
                             double      distance,
                             double      dirX,
                             double      dirY,
                             double      dirZ);

/// Create B-spline surface from a grid of control points
/// @param poles Control points as [x,y,z,...] in row-major order (uCount * vCount * 3 doubles)
/// @param uCount Number of control points in U direction
/// @param vCount Number of control points in V direction
/// @param uDegree Degree in U direction (typically 3)
/// @param vDegree Degree in V direction (typically 3)
/// @return Face shape from B-spline surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateBSplineSurface(const double* poles,
                                           int32_t       uCount,
                                           int32_t       vCount,
                                           int32_t       uDegree,
                                           int32_t       vDegree);

/// Create ruled surface between two wires
/// @param wire1 First boundary wire
/// @param wire2 Second boundary wire
/// @return Face shape from ruled surface, or NULL on failure
OCCTShapeRef OCCTShapeCreateRuled(OCCTWireRef wire1, OCCTWireRef wire2);

/// Create shell (hollow solid) with specific faces left open
/// @param shape The solid to shell
/// @param thickness Shell wall thickness (positive = inward, negative = outward)
/// @param openFaceIndices Array of face indices to leave open (0-based)
/// @param faceCount Number of faces to leave open
/// @return Shelled shape, or NULL on failure, including when an index names no face of `shape`,
///         which since #568 fails the call rather than being skipped. Only a list where *every*
///         index was unresolvable used to be caught, by the resulting empty face list.
OCCTShapeRef OCCTShapeShellWithOpenFaces(OCCTShapeRef   shape,
                                         double         thickness,
                                         const int32_t* openFaceIndices,
                                         int32_t        faceCount);

// MARK: - Geometry Construction (v0.11.0)

/// Create a planar face from a closed wire
/// @param wire Closed wire defining the face boundary
/// @param planar If true, require the wire to be planar; if false, attempt to create face anyway
/// @return Face shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceFromWire(OCCTWireRef wire, bool planar);

/// Create a face with holes from an outer wire and inner wires
/// @param outer Outer boundary wire (closed)
/// @param holes Array of inner boundary wires (holes)
/// @param holeCount Number of holes
/// @return Face shape with holes, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceWithHoles(OCCTWireRef        outer,
                                          const OCCTWireRef* holes,
                                          int32_t            holeCount);

/// Create a solid from every body-bounding shell of a shape, not just the first (#443).
/// Cavity shells are skipped; see occtBodyBoundingShells in OCCTBridge_Internal.h.
/// @param shell Shell shape (must be closed), or any shape holding shells
/// @return One solid, a compound of solids for multi-body input, or NULL if there is no shell
OCCTShapeRef OCCTShapeCreateSolidFromShell(OCCTShapeRef shell);

/// Sew multiple faces/shapes into a shell or solid
/// @param shapes Array of shapes to sew
/// @param count Number of shapes
/// @param tolerance Sewing tolerance (use 1e-6 for default)
/// @return Sewn shape (shell or solid), or NULL on failure
OCCTShapeRef OCCTShapeSew(const OCCTShapeRef* shapes, int32_t count, double tolerance);

/// Sew two shapes together
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeSewTwo(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create a smooth curve interpolating through given points
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param closed If true, create a closed (periodic) curve
/// @param tolerance Interpolation tolerance (use 1e-6 for default)
/// @return Wire representing the interpolated curve, or NULL on failure
OCCTWireRef OCCTWireInterpolate(const double* points, int32_t count, bool closed, double tolerance);

/// Create a curve interpolating through points with specified end tangents
/// @param points Points as [x,y,z,...] triplets (count * 3 doubles)
/// @param count Number of points (minimum 2)
/// @param startTanX, startTanY, startTanZ Tangent vector at start point
/// @param endTanX, endTanY, endTanZ Tangent vector at end point
/// @param tolerance Interpolation tolerance
/// @return Wire with specified end tangents, or NULL on failure
OCCTWireRef OCCTWireInterpolateWithTangents(const double* points,
                                            int32_t       count,
                                            double        startTanX,
                                            double        startTanY,
                                            double        startTanZ,
                                            double        endTanX,
                                            double        endTanY,
                                            double        endTanZ,
                                            double        tolerance);

// MARK: - Feature-Based Modeling (v0.12.0)

/// Add a prismatic boss to a shape by extruding a profile
/// @param shape The base shape to modify
/// @param profile Wire profile to extrude (must be on a face of shape)
/// @param dirX, dirY, dirZ Extrusion direction
/// @param height Extrusion height
/// @param fuse If true, fuse with base shape; if false, cut from base shape
/// @return Modified shape with boss/pocket, or NULL on failure
OCCTShapeRef OCCTShapePrism(OCCTShapeRef shape,
                            OCCTWireRef  profile,
                            double       dirX,
                            double       dirY,
                            double       dirZ,
                            double       height,
                            bool         fuse);

/// Drill a cylindrical hole into a shape, by cutting a cylinder out of it.
///
/// The tool is a FINITE cylinder based at (posX, posY, posZ), running along the normalized
/// direction for `depth` — or, when `depth <= 0`, for twice the shape's bounding-box diagonal,
/// which is long enough to leave the far side of any shape it started outside of. Everything is
/// subtracted with BRepAlgoAPI_Cut, so this works on solids, shells and faces alike, and a `depth`
/// that overshoots the stock costs nothing.
///
/// This is NOT the same contract as OCCTBRepFeatCylindricalHole below, which is OCCT's dedicated
/// feature-drilling operator. Neither subsumes the other (#496): choose this one when the hole
/// starts where you say it starts, when the input is not a solid, or when an over-long depth should
/// just drill through; choose the feature family when you need a solid's own faces to bound the
/// hole, or a diagnosis of why the drill failed.
///
/// @param shape The shape to drill
/// @param posX, posY, posZ Position of hole center on surface
/// @param dirX, dirY, dirZ Drill direction (into the shape); any non-zero axis
/// @param radius Hole radius; must exceed Precision::Confusion
/// @param depth Hole depth (0 or less for a through-hole)
/// @return Shape with hole, or NULL on failure
OCCTShapeRef OCCTShapeDrillHole(OCCTShapeRef shape,
                                double       posX,
                                double       posY,
                                double       posZ,
                                double       dirX,
                                double       dirY,
                                double       dirZ,
                                double       radius,
                                double       depth);

/// Split a shape using a cutting tool (wire, face, or shape)
/// @param shape The shape to split
/// @param tool The cutting tool
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplit(OCCTShapeRef shape, OCCTShapeRef tool, int32_t* outCount);

/// Split a shape by a plane
/// @param shape The shape to split
/// @param planeX, planeY, planeZ Point on the cutting plane
/// @param normalX, normalY, normalZ Normal vector of the cutting plane
/// @param outCount Output: number of resulting shapes
/// @return Array of split shapes (caller must free with OCCTFreeShapeArray), or NULL on failure
OCCTShapeRef* OCCTShapeSplitByPlane(OCCTShapeRef shape,
                                    double       planeX,
                                    double       planeY,
                                    double       planeZ,
                                    double       normalX,
                                    double       normalY,
                                    double       normalZ,
                                    int32_t*     outCount);

/// Free an array of shapes returned by split operations
/// @param shapes Array of shape references
/// @param count Number of shapes in the array
void OCCTFreeShapeArray(OCCTShapeRef* shapes, int32_t count);

/// Free only the shape array container, not the shapes themselves
/// @param shapes Array of shape references
void OCCTFreeShapeArrayOnly(OCCTShapeRef* shapes);

/// Glue two shapes together at coincident faces
/// @param shape1 First shape
/// @param shape2 Second shape (must have faces coincident with shape1)
/// @param tolerance Tolerance for face matching
/// @return Glued shape, or NULL on failure
OCCTShapeRef OCCTShapeGlue(OCCTShapeRef shape1, OCCTShapeRef shape2, double tolerance);

/// Create an evolved shape (profile swept along spine with rotation)
/// @param spine The spine wire
/// @param profile The profile wire to sweep
/// @return Evolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateEvolved(OCCTWireRef spine, OCCTWireRef profile);

/// Create a linear pattern of a shape
/// @param shape The shape to pattern
/// @param dirX, dirY, dirZ Direction of the pattern
/// @param spacing Distance between copies
/// @param count Number of copies (including original)
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeLinearPattern(OCCTShapeRef shape,
                                    double       dirX,
                                    double       dirY,
                                    double       dirZ,
                                    double       spacing,
                                    int32_t      count);

/// Create a circular pattern of a shape
/// @param shape The shape to pattern
/// @param axisX, axisY, axisZ Point on the rotation axis
/// @param axisDirX, axisDirY, axisDirZ Direction of the rotation axis
/// @param count Number of copies (including original)
/// @param angle Total angle to span (radians), 0 for full circle
/// @return Compound of patterned shapes, or NULL on failure
OCCTShapeRef OCCTShapeCircularPattern(OCCTShapeRef shape,
                                      double       axisX,
                                      double       axisY,
                                      double       axisZ,
                                      double       axisDirX,
                                      double       axisDirY,
                                      double       axisDirZ,
                                      int32_t      count,
                                      double       angle);

// Issue #39 — lift a 2D curve onto a 3D plane to produce a Wire
/// Creates a 3D wire by embedding the 2D curve into a gp_Pln.
/// The plane is defined by its origin (ox,oy,oz), normal (nx,ny,nz) and x-axis (xx,xy,xz).
/// Returns NULL on failure.
OCCTWireRef OCCTWireFromCurve2DOnPlane(OCCTCurve2DRef curve,
                                       double         ox,
                                       double         oy,
                                       double         oz,
                                       double         nx,
                                       double         ny,
                                       double         nz,
                                       double         xx,
                                       double         xy,
                                       double         xz);

// MARK: - Surface Intersection (v0.18.0)

/// Intersect two faces and return intersection curves as edges
OCCTShapeRef OCCTFaceIntersect(OCCTFaceRef face1, OCCTFaceRef face2, double tolerance);

void OCCTLawFunctionRelease(OCCTLawFunctionRef law);

/// Evaluate law value at parameter
double OCCTLawFunctionValue(OCCTLawFunctionRef law, double param);

/// Get law parameter bounds
void OCCTLawFunctionBounds(OCCTLawFunctionRef law, double* first, double* last);

/// Create a constant law: value is constant over [first, last]
OCCTLawFunctionRef OCCTLawCreateConstant(double value, double first, double last);

/// Create a linear law: linearly interpolates from (first, startVal) to (last, endVal)
OCCTLawFunctionRef OCCTLawCreateLinear(double first, double startVal, double last, double endVal);

/// Create an S-curve law: smooth sigmoid between (first, startVal) and (last, endVal)
OCCTLawFunctionRef OCCTLawCreateS(double first, double startVal, double last, double endVal);

/// Create an interpolated law from (parameter, value) pairs
/// points is array of [param0, val0, param1, val1, ...]
OCCTLawFunctionRef OCCTLawCreateInterpolate(const double* paramValues,
                                            int32_t       count,
                                            bool          periodic);

/// Create a BSpline law
OCCTLawFunctionRef OCCTLawCreateBSpline(const double*  poles,
                                        int32_t        poleCount,
                                        const double*  knots,
                                        int32_t        knotCount,
                                        const int32_t* multiplicities,
                                        int32_t        degree);

/// Create pipe shell with law-based scaling along spine
/// profile: wire cross-section, spine: wire path, law: scaling evolution
OCCTShapeRef OCCTShapeCreatePipeShellWithLaw(OCCTWireRef        spine,
                                             OCCTWireRef        profile,
                                             OCCTLawFunctionRef law,
                                             bool               solid);

// MARK: - Helix Curves (v0.28.0)

/// Create a helical wire (constant radius).
/// @param originX/Y/Z Helix axis origin
/// @param axisX/Y/Z Helix axis direction
/// @param radius Helix radius
/// @param pitch Distance between consecutive turns
/// @param turns Number of turns
/// @param clockwise true for clockwise, false for counter-clockwise
OCCTWireRef OCCTWireCreateHelix(double originX,
                                double originY,
                                double originZ,
                                double axisX,
                                double axisY,
                                double axisZ,
                                double radius,
                                double pitch,
                                double turns,
                                bool   clockwise);

/// Create a tapered (conical) helical wire.
/// @param startRadius Radius at the start
/// @param endRadius Radius at the end
OCCTWireRef OCCTWireCreateHelixTapered(double originX,
                                       double originY,
                                       double originZ,
                                       double axisX,
                                       double axisY,
                                       double axisZ,
                                       double startRadius,
                                       double endRadius,
                                       double pitch,
                                       double turns,
                                       bool   clockwise);

// MARK: - Wedge Primitive (v0.29.0)

/// Create a wedge (tapered box) primitive.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param ltx X dimension at the top (0 for a full taper to a ridge)
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedge(double dx, double dy, double dz, double ltx);

/// Create a wedge primitive with min/max control on the top face.
/// @param dx, dy, dz Full dimensions in X, Y, Z
/// @param xmin, zmin, xmax, zmax Bounds of the top face within the base
/// @return Wedge shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateWedgeAdvanced(double dx,
                                          double dy,
                                          double dz,
                                          double xmin,
                                          double zmin,
                                          double xmax,
                                          double zmax);
OCCTShapeRef _Nullable OCCTShapeCreateWedgeOriented(double originX,
                                                    double originY,
                                                    double originZ,
                                                    double dirX,
                                                    double dirY,
                                                    double dirZ,
                                                    double dx,
                                                    double dy,
                                                    double dz,
                                                    double ltx);

// MARK: - Normal Projection (v0.29.0)

/// Project a wire or edge normally onto a surface shape.
/// @param wireOrEdge Wire or edge to project
/// @param surface Surface shape to project onto
/// @param tol3d 3D tolerance
/// @param tol2d 2D tolerance
/// @param maxDegree Maximum degree of resulting curve
/// @param maxSeg Maximum segments of resulting curve
/// @return Projected shape, or NULL on failure
OCCTShapeRef OCCTShapeNormalProjection(OCCTShapeRef wireOrEdge,
                                       OCCTShapeRef surface,
                                       double       tol3d,
                                       double       tol2d,
                                       int          maxDegree,
                                       int          maxSeg);

// MARK: - Half-Space (v0.29.0)

/// Create a half-space solid from a face and a reference point.
/// The half-space is the solid containing the reference point.
/// @param faceShape Shape containing a face (first face is used)
/// @param refX, refY, refZ Reference point in the desired half-space
/// @return Half-space solid, or NULL on failure
OCCTShapeRef OCCTShapeCreateHalfSpace(OCCTShapeRef faceShape,
                                      double       refX,
                                      double       refY,
                                      double       refZ);

// MARK: - Periodic Shapes (v0.29.0)

/// Make a shape periodic in one or more directions.
/// @param shape The shape to make periodic
/// @param xPeriodic, yPeriodic, zPeriodic Enable periodicity in each direction
/// @param xPeriod, yPeriod, zPeriod Period value in each direction
/// @return Periodic shape, or NULL on failure
OCCTShapeRef OCCTShapeMakePeriodic(OCCTShapeRef shape,
                                   bool         xPeriodic,
                                   double       xPeriod,
                                   bool         yPeriodic,
                                   double       yPeriod,
                                   bool         zPeriodic,
                                   double       zPeriod);

/// Repeat a periodic shape in one or more directions.
/// @param shape The base shape (should be made periodic first)
/// @param xPeriodic, yPeriodic, zPeriodic Enable repetition in each direction
/// @param xPeriod, yPeriod, zPeriod Period value for repetition
/// @param xTimes, yTimes, zTimes Number of repetitions in each direction
/// @return Repeated shape, or NULL on failure
OCCTShapeRef OCCTShapeRepeat(OCCTShapeRef shape,
                             bool         xPeriodic,
                             double       xPeriod,
                             bool         yPeriodic,
                             double       yPeriod,
                             bool         zPeriodic,
                             double       zPeriod,
                             int32_t      xTimes,
                             int32_t      yTimes,
                             int32_t      zTimes);

// MARK: - Draft from Shape (v0.29.0)

/// Create a draft shell by sweeping a shape along a direction with taper angle.
/// @param shape Wire or edge to draft from
/// @param dirX, dirY, dirZ Draft direction
/// @param angle Taper angle in radians
/// @param lengthMax Maximum draft length
/// @return Draft shell shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeDraft(OCCTShapeRef shape,
                                double       dirX,
                                double       dirY,
                                double       dirZ,
                                double       angle,
                                double       lengthMax);

// MARK: - Revolution Feature (v0.29.0)

// NOTE: BRepFeat_MakeRevol is complex (requires sketch face identification).
// This function is omitted because identifying the correct sketch face from the
// profile shape is highly context-dependent and error-prone in a generic C bridge.
// Users should instead use OCCTShapeCreateRevolution (sweep-based) for revolution solids,
// or BRepAlgoAPI_Fuse/Cut for adding/subtracting revolved material.

// MARK: - Non-Uniform Transform (v0.30.0)

/// Apply non-uniform scaling to a shape using BRepBuilderAPI_GTransform.
/// @param shape The shape to scale
/// @param sx Scale factor in X direction
/// @param sy Scale factor in Y direction
/// @param sz Scale factor in Z direction
/// @return Scaled shape, or NULL on failure
OCCTShapeRef OCCTShapeNonUniformScale(OCCTShapeRef shape, double sx, double sy, double sz);

// MARK: - Make Shell (v0.30.0)

/// Create a shell from a surface using BRepBuilderAPI_MakeShell.
/// @param surface The surface to convert to a shell
/// @return Shell shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateShellFromSurface(OCCTSurfaceRef surface);

// MARK: - Make Vertex (v0.30.0)

/// Create a vertex at a point using BRepBuilderAPI_MakeVertex.
/// @param x X coordinate
/// @param y Y coordinate
/// @param z Z coordinate
/// @return Vertex shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateVertex(double x, double y, double z);

// MARK: - Simple Offset (v0.30.0)

/// Create a simple offset of a shape using BRepOffset_MakeSimpleOffset.
/// @param shape The shape to offset
/// @param offsetValue Offset distance (positive = outward)
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeSimpleOffset(OCCTShapeRef shape, double offsetValue);

// MARK: - Middle Path (v0.30.0)

/// Compute the middle path between two sub-shapes using BRepOffsetAPI_MiddlePath.
/// @param shape The main shape (typically a solid or shell)
/// @param startShape Start sub-shape (wire or edge on the shape)
/// @param endShape End sub-shape (wire or edge on the shape)
/// @return Middle path wire, or NULL on failure
OCCTShapeRef OCCTShapeMiddlePath(OCCTShapeRef shape,
                                 OCCTShapeRef startShape,
                                 OCCTShapeRef endShape);

// MARK: - Fuse Edges (v0.30.0)

/// Fuse connected edges sharing the same geometry using BRepLib_FuseEdges.
/// @param shape The shape containing edges to fuse
/// @return Shape with fused edges, or NULL on failure
OCCTShapeRef OCCTShapeFuseEdges(OCCTShapeRef shape);

// MARK: - Maker Volume (v0.30.0)

/// Create a solid volume from a set of shapes using BOPAlgo_MakerVolume.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Volume solid, or NULL on failure
OCCTShapeRef OCCTShapeMakeVolume(OCCTShapeRef* shapes, int32_t count);

// MARK: - Make Connected (v0.30.0)

/// Make a set of shapes connected using BOPAlgo_MakeConnected.
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Connected shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeConnected(OCCTShapeRef* shapes, int32_t count);

// MARK: - Quilt Faces (v0.31.0)

/// Quilt multiple shapes (faces/shells) together into a single shell.
/// @param shapes Array of shape references to quilt
/// @param count Number of shapes in the array
/// @return Resulting shell shape, or NULL on failure
OCCTShapeRef OCCTShapeQuilt(OCCTShapeRef* shapes, int32_t count);

// MARK: - Revolution from Curve (v0.31.0)

/// Create a solid of revolution from a meridian curve.
/// @param meridian The curve to revolve (meridian profile)
/// @param axOX, axOY, axOZ Origin of the revolution axis
/// @param axDX, axDY, axDZ Direction of the revolution axis
/// @param angle Revolution angle in radians (use 2*pi for full revolution)
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateRevolutionFromCurve(OCCTCurve3DRef meridian,
                                                double         axOX,
                                                double         axOY,
                                                double         axOZ,
                                                double         axDX,
                                                double         axDY,
                                                double         axDZ,
                                                double         angle);

// MARK: - Linear Rib Feature (v0.31.0)

/// Add a linear rib feature to a shape.
/// @param shape The base shape to add the rib to
/// @param profile The wire profile of the rib
/// @param dirX, dirY, dirZ Direction of the rib extrusion
/// @param dir1X, dir1Y, dir1Z Secondary direction (draft direction)
/// @param fuse true to fuse (add material), false to cut (remove material)
/// @return Shape with rib added, or NULL on failure
OCCTShapeRef OCCTShapeAddLinearRib(OCCTShapeRef shape,
                                   OCCTWireRef  profile,
                                   double       dirX,
                                   double       dirY,
                                   double       dirZ,
                                   double       dir1X,
                                   double       dir1Y,
                                   double       dir1Z,
                                   bool         fuse);

// MARK: - Asymmetric Chamfer (v0.32.0)

/// Chamfer specific edges with two different distances (asymmetric).
/// @param shape The shape to chamfer
/// @param edgeIndices Array of 0-based edge indices
/// @param faceIndices Array of 0-based face indices (one per edge, identifies reference face)
/// @param dist1 Array of first distances (measured on the reference face)
/// @param dist2 Array of second distances (measured on the other face)
/// @param count Number of edges to chamfer
/// @return Chamfered shape, or NULL on failure
OCCTShapeRef OCCTShapeChamferTwoDistances(OCCTShapeRef   shape,
                                          const int32_t* edgeIndices,
                                          const int32_t* faceIndices,
                                          const double*  dist1,
                                          const double*  dist2,
                                          int32_t        count);

/// Chamfer specific edges with distance + angle.
/// @param shape The shape to chamfer
/// @param edgeIndices Array of 0-based edge indices
/// @param faceIndices Array of 0-based face indices (one per edge, identifies reference face)
/// @param distances Array of distances (measured on the reference face)
/// @param anglesDeg Array of angles in degrees (must be between 0 and 90, exclusive)
/// @param count Number of edges to chamfer
/// @return Chamfered shape, or NULL on failure
OCCTShapeRef OCCTShapeChamferDistAngle(OCCTShapeRef   shape,
                                       const int32_t* edgeIndices,
                                       const int32_t* faceIndices,
                                       const double*  distances,
                                       const double*  anglesDeg,
                                       int32_t        count);

// MARK: - Loft Improvements (v0.32.0)

/// Create a lofted shape with ruled/smooth control and optional vertex endpoints.
/// @param profiles Array of wire profiles
/// @param profileCount Number of wire profiles
/// @param solid Whether to create a solid (true) or shell (false)
/// @param ruled Whether to use ruled surfaces (true) or smooth B-spline (false)
/// @param firstVertexX,Y,Z If not NaN, use as starting vertex (cone tip)
/// @param lastVertexX,Y,Z If not NaN, use as ending vertex (cone tip)
/// @return Lofted shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateLoftAdvanced(const OCCTWireRef* profiles,
                                         int32_t            profileCount,
                                         bool               solid,
                                         bool               ruled,
                                         double             firstVertexX,
                                         double             firstVertexY,
                                         double             firstVertexZ,
                                         double             lastVertexX,
                                         double             lastVertexY,
                                         double             lastVertexZ);

// MARK: - Offset with Join Type (v0.32.0)

/// Offset shape using the proper PerformByJoin algorithm.
/// @param shape The shape to offset
/// @param distance Offset distance (positive = outward, negative = inward)
/// @param tolerance Coincidence tolerance (typically 1e-7)
/// @param joinType Join type: 0=Arc (rounded gaps), 1=Tangent, 2=Intersection (sharp)
/// @param removeInternalEdges Whether to remove internal edges from result
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeOffsetByJoin(OCCTShapeRef shape,
                                   double       distance,
                                   double       tolerance,
                                   int32_t      joinType,
                                   bool         removeInternalEdges);

// MARK: - Revolution Form Feature (v0.32.0)

/// Add a revolution form (revolved rib/groove) to a shape.
/// @param shape The base shape
/// @param profile The wire profile of the rib
/// @param axOX,axOY,axOZ Origin of revolution axis
/// @param axDX,axDY,axDZ Direction of revolution axis
/// @param height1 Height on one side
/// @param height2 Height on the other side
/// @param fuse true for rib, false for groove
/// @return Shape with revolution form, or NULL on failure
OCCTShapeRef OCCTShapeAddRevolutionForm(OCCTShapeRef shape,
                                        OCCTWireRef  profile,
                                        double       axOX,
                                        double       axOY,
                                        double       axOZ,
                                        double       axDX,
                                        double       axDY,
                                        double       axDZ,
                                        double       height1,
                                        double       height2,
                                        bool         fuse);

// MARK: - Draft Prism Feature (v0.32.0)

/// Add a draft prism (tapered extrusion) to a shape, extruded to a given height.
/// @param shape The base shape
/// @param profileFace 0-based face index on shape to use as sketch/profile face
/// @param profile Wire profile to extrude
/// @param angleDeg Draft angle in degrees
/// @param height Extrusion height
/// @param fuse true to add material, false to cut
/// @return Shape with draft prism, or NULL on failure
OCCTShapeRef OCCTShapeDraftPrism(OCCTShapeRef shape,
                                 int32_t      profileFace,
                                 OCCTWireRef  profile,
                                 double       angleDeg,
                                 double       height,
                                 bool         fuse);

/// Add a draft prism, extruded through the entire shape.
OCCTShapeRef OCCTShapeDraftPrismThruAll(OCCTShapeRef shape,
                                        int32_t      profileFace,
                                        OCCTWireRef  profile,
                                        double       angleDeg,
                                        bool         fuse);

// MARK: - Revolution Feature (v0.32.0)

/// Add a revolved feature (boss/pocket) to a shape, revolving to a given angle.
/// @param shape The base shape
/// @param profileFace 0-based face index on shape to use as sketch face
/// @param profile Wire profile to revolve
/// @param axOX,axOY,axOZ Origin of revolution axis
/// @param axDX,axDY,axDZ Direction of revolution axis
/// @param angleDeg Rotation angle in degrees
/// @param fuse true to add material, false to cut
/// @return Shape with revolved feature, or NULL on failure
OCCTShapeRef OCCTShapeRevolFeature(OCCTShapeRef shape,
                                   int32_t      profileFace,
                                   OCCTWireRef  profile,
                                   double       axOX,
                                   double       axOY,
                                   double       axOZ,
                                   double       axDX,
                                   double       axDY,
                                   double       axDZ,
                                   double       angleDeg,
                                   bool         fuse);

/// Add a revolved feature, revolving through 360 degrees.
OCCTShapeRef OCCTShapeRevolFeatureThruAll(OCCTShapeRef shape,
                                          int32_t      profileFace,
                                          OCCTWireRef  profile,
                                          double       axOX,
                                          double       axOY,
                                          double       axOZ,
                                          double       axDX,
                                          double       axDY,
                                          double       axDZ,
                                          bool         fuse);

// MARK: - Evolved Shape Advanced (v0.33.0)

/// Create an evolved shape with full parameter control.
/// @param spine The spine shape (wire or face)
/// @param profile The profile wire
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @param axeProf true if profile is in global coords, false for local
/// @param solid true to produce a solid
/// @param volume true for volume mode (remove self-intersections via BOPAlgo)
/// @param tolerance Tolerance for evolved shape creation
/// @return Evolved shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateEvolvedAdvanced(OCCTShapeRef spine,
                                            OCCTWireRef  profile,
                                            int32_t      joinType,
                                            bool         axeProf,
                                            bool         solid,
                                            bool         volume,
                                            double       tolerance);

// MARK: - Face from Surface with UV Bounds (v0.33.0)

/// Create a face from a surface with specific UV parameter bounds.
/// @param surface The surface to create a face from
/// @param uMin Minimum U parameter
/// @param uMax Maximum U parameter
/// @param vMin Minimum V parameter
/// @param vMax Maximum V parameter
/// @param tolerance Tolerance for face creation
/// @return Face shape, or NULL on failure
OCCTShapeRef OCCTShapeCreateFaceFromSurface(OCCTSurfaceRef surface,
                                            double         uMin,
                                            double         uMax,
                                            double         vMin,
                                            double         vMax,
                                            double         tolerance);

/// Build a face on a surface trimmed to a non-rectangular region given by a closed UV-space
/// boundary polygon (uv = [u0,v0,u1,v1,...], `count` points, >= 3). #233.
/// @return Trimmed face shape, or NULL on failure.
OCCTShapeRef OCCTShapeCreateFaceFromSurfaceUVPolygon(OCCTSurfaceRef surface,
                                                     const double*  uv,
                                                     int32_t        count);

/// Build a face from a surface bounded by a 3D wire lying (approximately) on it; pcurves are
/// projected via ShapeFix_Face. #233.
/// @return Trimmed face shape, or NULL on failure.
OCCTShapeRef OCCTShapeCreateFaceFromSurfaceWire(OCCTSurfaceRef surface, OCCTWireRef wire);

/// Build a face from a surface trimmed by an outer wire with N interior **hole** wires
/// (windows / cutouts). `BRepBuilderAPI_MakeFace(surface, outer)` then `.Add(hole)` per inner wire,
/// then ShapeFix_Face to project pcurves and orient the holes. All wires must lie (approximately)
/// on the surface. #266.
/// @return Trimmed face-with-holes shape, or NULL on failure.
OCCTShapeRef OCCTShapeCreateFaceFromSurfaceWireWithHoles(OCCTSurfaceRef     surface,
                                                         OCCTWireRef        outer,
                                                         const OCCTWireRef* innerWires,
                                                         int32_t            innerCount);

// MARK: - Edges to Faces (v0.33.0)

/// Reconstruct faces from a compound of loose edges.
/// @param compound Shape containing edges
/// @param isOnlyPlane true to only create planar faces
/// @return Compound of faces, or NULL on failure
OCCTShapeRef OCCTShapeEdgesToFaces(OCCTShapeRef compound, bool isOnlyPlane);

// MARK: - Shape-to-Shape Section (v0.34.0)

/// Compute the intersection curves/edges between two shapes.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @return Shape containing intersection edges/wires, or NULL on failure
OCCTShapeRef OCCTShapeSection(OCCTShapeRef shape1, OCCTShapeRef shape2);

// MARK: - Boolean Pre-Validation (v0.34.0)

/// Check whether shapes are valid for boolean operations.
/// @param shape1 First shape (argument)
/// @param shape2 Second shape (tool), may be NULL for self-check
/// @return true if shapes are valid for booleans
bool OCCTShapeBooleanCheck(OCCTShapeRef shape1, OCCTShapeRef shape2);

// MARK: - Split Shape by Wire (v0.34.0)

/// Split faces of a shape by imprinting a wire onto a face.
/// @param shape The shape to modify
/// @param wire The wire to imprint
/// @param faceIndex 0-based index of the face to split
/// @return Modified shape with split faces, or NULL on failure
OCCTShapeRef OCCTShapeSplitByWire(OCCTShapeRef shape, OCCTWireRef wire, int32_t faceIndex);

// MARK: - Multi-Tool Boolean Fuse (v0.34.0)

/// Fuse multiple shapes simultaneously (more robust than sequential pairwise union).
/// @param shapes Array of shape references
/// @param count Number of shapes
/// @return Fused shape, or NULL on failure
OCCTShapeRef OCCTShapeFuseMulti(const OCCTShapeRef* shapes, int32_t count);

// MARK: - Multi-Offset Wire (v0.35.0)

/// Generate multiple parallel offset wires from a face boundary.
/// @param face A planar face whose outer wire defines the offset contour
/// @param offsets Array of offset distances (positive = outward, negative = inward)
/// @param count Number of offset distances
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @param outWires Output array of wire refs (caller must release each)
/// @param maxWires Maximum number of output wires
/// @return Number of wires actually produced
int32_t OCCTWireMultiOffset(OCCTShapeRef  face,
                            const double* offsets,
                            int32_t       count,
                            int32_t       joinType,
                            OCCTWireRef*  outWires,
                            int32_t       maxWires);

// MARK: - Cylindrical Projection (v0.35.0)

/// Project a wire onto a shape along a direction (cylindrical projection).
/// @param wire Wire/edge to project
/// @param shape Target shape to project onto
/// @param dirX, dirY, dirZ Projection direction
/// @return Compound of projected wires, or NULL on failure
OCCTShapeRef OCCTShapeProjectWire(OCCTShapeRef wire,
                                  OCCTShapeRef shape,
                                  double       dirX,
                                  double       dirY,
                                  double       dirZ);

// MARK: - Conical Projection (v0.36.0)

/// Project a wire onto a shape from a point (conical projection).
/// @param wire Wire/edge to project
/// @param shape Target shape to project onto
/// @param eyeX, eyeY, eyeZ Point of projection (eye/viewpoint)
/// @return Compound of projected wires, or NULL on failure
OCCTShapeRef OCCTShapeProjectWireConical(OCCTShapeRef wire,
                                         OCCTShapeRef shape,
                                         double       eyeX,
                                         double       eyeY,
                                         double       eyeZ);

// MARK: - Boolean with Modified Shapes (v0.36.0)

/// Perform a boolean fuse and return modified shapes from shape1.
/// @param shape1 First shape (argument)
/// @param shape2 Second shape (tool)
/// @param outModified Output array for shapes in result that are modifications of shape1 faces
/// @param maxModified Maximum number of output shapes
/// @return Number of modified shapes found, or -1 on failure
int32_t OCCTShapeFuseWithHistory(OCCTShapeRef  shape1,
                                 OCCTShapeRef  shape2,
                                 OCCTShapeRef* outModified,
                                 int32_t       maxModified);

/// Boolean union (s1 ∪ s2) with retained history.
/// @param outResult If non-null, set to the result shape on success (caller owns; free with
/// OCCTShapeRelease).
/// @return History handle on success, NULL on failure.
OCCTBooleanHistoryRef _Nullable OCCTBooleanUnionWithHistory(
  OCCTShapeRef _Nonnull shape1,
  OCCTShapeRef _Nonnull shape2,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Boolean subtract (s1 \ s2) with retained history.
OCCTBooleanHistoryRef _Nullable OCCTBooleanSubtractWithHistory(
  OCCTShapeRef _Nonnull shape1,
  OCCTShapeRef _Nonnull shape2,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Boolean intersect (s1 ∩ s2) with retained history.
OCCTBooleanHistoryRef _Nullable OCCTBooleanIntersectWithHistory(
  OCCTShapeRef _Nonnull shape1,
  OCCTShapeRef _Nonnull shape2,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Split shape1 by shape2 (BRepAlgoAPI_Splitter). Result is a compound; use
/// OCCTShapeCompoundChildren to extract the pieces.
OCCTBooleanHistoryRef _Nullable OCCTBooleanSplitWithHistory(
  OCCTShapeRef _Nonnull shape1,
  OCCTShapeRef _Nonnull shape2,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Modified output sub-shapes for an input sub-shape. Returns count, fills outRefs (if non-null) up
/// to maxCount. Caller takes ownership of each OCCTShapeRef written.
int32_t OCCTBooleanHistoryModified(OCCTBooleanHistoryRef _Nonnull history,
                                   OCCTShapeRef _Nonnull inputSubShape,
                                   OCCTShapeRef _Nullable* _Nullable outRefs,
                                   int32_t maxCount);

/// Generated output sub-shapes for an input sub-shape (e.g. fillet faces generated FROM an edge).
int32_t OCCTBooleanHistoryGenerated(OCCTBooleanHistoryRef _Nonnull history,
                                    OCCTShapeRef _Nonnull inputSubShape,
                                    OCCTShapeRef _Nullable* _Nullable outRefs,
                                    int32_t maxCount);

/// True if the input sub-shape was deleted with no replacement.
bool OCCTBooleanHistoryIsDeleted(OCCTBooleanHistoryRef _Nonnull history,
                                 OCCTShapeRef _Nonnull inputSubShape);

/// Synthesize a standalone BRepTools_History from the retained builder (issue #290).
///
/// Works for every *WithHistory op, including fillet / chamfer / thick-solid,
/// which have no native History(). Only VERTEX / EDGE / FACE / SOLID are carried
/// (BRepTools_History::IsSupportedType) — wires, shells and compounds are not.
///
/// @return An OCCTHistoryRef the caller owns (free with OCCTHistoryDestroy), or
///         NULL on failure. Feed it to OCCTBRepGraphAddWithHistory to record the
///         operation into a graph's history log.
OCCTHistoryRef OCCTBooleanHistoryAsBRepToolsHistory(OCCTBooleanHistoryRef _Nonnull history);

void OCCTBooleanHistoryRelease(OCCTBooleanHistoryRef _Nonnull history);

/// Top-level children of a compound shape (TopoDS_Iterator). Returns count,
/// fills outRefs (if non-null) up to maxCount. Used to extract pieces from
/// BRepAlgoAPI_Splitter results. Caller takes ownership of each OCCTShapeRef.
int32_t OCCTShapeCompoundChildren(OCCTShapeRef _Nonnull compound,
                                  OCCTShapeRef _Nullable* _Nullable outRefs,
                                  int32_t maxCount);

// MARK: - Tier 2 modification ops with full per-input history (issue #165)

/// Uniform-radius fillet on the given edges, with retained history.
///
/// `radius` must be > 0, and the edge loop is occtFilletAddEdges (OCCTBridge_Internal.h), shared
/// with OCCTShapeFilletEdges: 0-based indices, an out-of-range one skipped. #489
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromFilletEdges(
  OCCTShapeRef _Nonnull shape,
  const int32_t* _Nonnull edgeIndices,
  int32_t count,
  double  radius,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Variable-radius fillet on a single edge (start radius linearly varies to end radius
/// along the edge's parameter range), with retained history.
///
/// Both radii must be > 0, matching OCCTShapeFilletEdgesLinear. #489
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromFilletEdgeVariable(
  OCCTShapeRef _Nonnull shape,
  int32_t edgeIndex,
  double  startRadius,
  double  endRadius,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Uniform chamfer on the given edges, with retained history.
///
/// Edge indices are 0-based into the shape's own edge map, and one naming no edge fails the call
/// rather than being skipped: the same contract #520 gave the fillet siblings, extended to this
/// family by #568. Both resolve their indices through occtUseSubShapesByIndex
/// (OCCTBridge_Internal.h).
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromChamferEdges(
  OCCTShapeRef _Nonnull shape,
  const int32_t* _Nonnull edgeIndices,
  int32_t count,
  double  distance,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Shell / thick-solid: remove given faces and offset inward by `thickness`, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromShell(
  OCCTShapeRef _Nonnull shape,
  const int32_t* _Nonnull faceIndices,
  int32_t faceCount,
  double  thickness,
  double  tolerance,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Defeature: remove given faces by smoothing surrounding topology, with retained history.
/// The same BRepAlgoAPI_Defeaturing operation as OCCTShapeRemoveFeatures / OCCTShapeDefeature,
/// keeping the builder alive to answer history queries. #497
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromDefeature(
  OCCTShapeRef _Nonnull shape,
  const int32_t* _Nonnull faceIndices,
  int32_t faceCount,
  OCCTShapeRef _Nullable* _Nullable outResult);

// MARK: - Sewing / quilting / healing with full history (issue #327)
//
// Same OCCTBooleanHistoryRef handle as booleans/Tier 2 above, so the Swift
// ShapeHistoryRef/record(of:)/OCCTBRepGraphAddWithHistory surface is shared
// unchanged. These algorithms don't derive from BRepBuilderAPI_MakeShape, so
// the history isn't synthesized from a retained builder — each function below
// builds a BRepTools_History directly (via BRepTools_ReShape::History() for
// sewing/healing, or a manual per-subshape walk for quilting) and wraps it.

/// Sew multiple shapes into a connected shell/solid, with full per-input-subshape
/// history (vertex/edge merges, small-face removal).
// Note: `shapes` intentionally has no nullability annotation on the pointer
// itself (matches OCCTShapeSew) — Swift's UnsafeMutableBufferPointer.baseAddress
// is always Optional, and an unannotated C pointer imports leniently enough to
// accept it directly without unwrapping at the call site.
OCCTBooleanHistoryRef _Nullable OCCTShapeSewWithHistory(
  const OCCTShapeRef* shapes,
  int32_t             count,
  double              tolerance,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Self-sew (merge disconnected faces within one shape), with full history.
OCCTBooleanHistoryRef _Nullable OCCTShapeSewSingleWithHistory(
  OCCTShapeRef _Nonnull shape,
  double tolerance,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Quilt multiple shapes (faces/shells) into a single shell, with full history.
/// See OCCTShapeSewWithHistory above for why `shapes` is unannotated.
OCCTBooleanHistoryRef _Nullable OCCTShapeQuiltWithHistory(
  OCCTShapeRef _Nonnull* _Nonnull shapes,
  int32_t count,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Heal/repair a shape (ShapeFix_Shape), with full history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHealWithHistory(
  OCCTShapeRef _Nonnull shape,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Create a solid from a closed shell (BRepBuilderAPI_MakeSolid + ShapeFix_Solid
/// orientation fix), with full history. Same body selection as
/// OCCTShapeCreateSolidFromShell; one shared ReShape context, so the single history
/// covers every body (#443).
OCCTBooleanHistoryRef _Nullable OCCTShapeCreateSolidFromShellWithHistory(
  OCCTShapeRef _Nonnull shell,
  OCCTShapeRef _Nullable* _Nullable outResult);

// MARK: - Transform / pattern with full history (issue #331)
//
// Same OCCTBooleanHistoryRef handle as above. translate/rotate/scale/mirror
// derive their history from a retained BRepBuilderAPI_Transform (same op/args
// synthesis path as fillet/chamfer/defeature). Patterns (linear/circular) are
// N:1 — history maps each source sub-shape to all N pattern-instance sub-shapes.

/// Translate by (dx, dy, dz), with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromTranslate(
  OCCTShapeRef _Nonnull shape,
  double dx,
  double dy,
  double dz,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Rotate around an axis through the origin, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromRotate(
  OCCTShapeRef _Nonnull shape,
  double axisX,
  double axisY,
  double axisZ,
  double angle,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Scale uniformly from the origin, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromScale(
  OCCTShapeRef _Nonnull shape,
  double factor,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Mirror across a plane, with retained history.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromMirror(
  OCCTShapeRef _Nonnull shape,
  double originX,
  double originY,
  double originZ,
  double normalX,
  double normalY,
  double normalZ,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Linear pattern (N copies along direction), with history mapping each source
/// sub-shape to all N corresponding pattern-instance sub-shapes.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromLinearPattern(
  OCCTShapeRef _Nonnull shape,
  double  dirX,
  double  dirY,
  double  dirZ,
  double  spacing,
  int32_t count,
  OCCTShapeRef _Nullable* _Nullable outResult);

/// Circular pattern (N copies around an axis), with history mapping each source
/// sub-shape to all N corresponding pattern-instance sub-shapes.
OCCTBooleanHistoryRef _Nullable OCCTShapeHistoryFromCircularPattern(
  OCCTShapeRef _Nonnull shape,
  double  axisX,
  double  axisY,
  double  axisZ,
  double  axisDirX,
  double  axisDirY,
  double  axisDirZ,
  int32_t count,
  double  angle,
  OCCTShapeRef _Nullable* _Nullable outResult);

// MARK: - Thick Solid / Hollowing (v0.37.0)

/// Create a hollowed (thick) solid by removing faces and offsetting inward.
/// @param shape The solid to hollow
/// @param faceIndices 0-based indices of faces to remove (openings)
/// @param faceCount Number of faces to remove
/// @param offset Wall thickness (positive = inward)
/// @param tolerance Tolerance
/// @param joinType Join type: 0=Arc, 1=Tangent, 2=Intersection
/// @return Hollowed solid, or NULL on failure
OCCTShapeRef OCCTShapeMakeThickSolid(OCCTShapeRef   shape,
                                     const int32_t* faceIndices,
                                     int32_t        faceCount,
                                     double         offset,
                                     double         tolerance,
                                     int32_t        joinType);

// MARK: - Shell from Surface (v0.37.0)

/// Create a shell from a parametric surface with UV bounds.
/// @param surface The surface
/// @param uMin, uMax, vMin, vMax UV parameter bounds
/// @return Shell shape, or NULL on failure
OCCTShapeRef OCCTShapeMakeShell(OCCTSurfaceRef surface,
                                double         uMin,
                                double         uMax,
                                double         vMin,
                                double         vMax);

// MARK: - Multi-Tool Boolean Common (v0.37.0)

/// Compute the common (intersection) of multiple shapes simultaneously.
/// @param shapes Array of shape references
/// @param count Number of shapes (must be >= 2)
/// @return Common shape (intersection of all), or NULL on failure
OCCTShapeRef OCCTShapeCommonMulti(const OCCTShapeRef* shapes, int32_t count);

// MARK: - Fuse and Blend (v0.38.0)

/// Fuse two shapes and fillet the intersection edges with the given radius.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param radius Fillet radius for intersection edges
/// @return Fused and filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFuseAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius);

/// Cut shape2 from shape1 and fillet the intersection edges with the given radius.
/// @param shape1 Base shape
/// @param shape2 Tool shape to cut
/// @param radius Fillet radius for intersection edges
/// @return Cut and filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeCutAndBlend(OCCTShapeRef shape1, OCCTShapeRef shape2, double radius);

// MARK: - Multi-Edge Evolving Fillet (v0.38.0)

/// Parameter-radius pair for evolving fillets.
typedef struct
{
  double parameter;
  double radius;
} OCCTFilletRadiusPoint;

/// Apply evolving-radius fillets to multiple edges simultaneously.
///
/// The multi-edge radius-law entry point, sharing occtFilletAddEdges with the other four fillet
/// edge-list functions and occtFilletSetRadiusProfile with OCCTShapeFilletVariable
/// (OCCTBridge_Internal.h). Its indices were 1-based until #520 made the family agree.
///
/// Each edge's law is written to that edge's own slot in that edge's own contour, resolved with
/// Contour(E) and NbEdges(IC)/Edge(IC, J). It used to be written to (NbContours(), 1): the first is
/// the edge's contour only when every Add(edge) creates one — a tangent-continuous edge extends an
/// existing contour instead — and the second collapsed every edge of a contour onto one slot, so
/// only the last law of a tangent chain survived. #612
/// @param shape The shape
/// @param edgeIndices Array of edge indices (0-based since #520; an index naming no edge of
///   `shape` rejects the whole call). Tangent-continuous edges share a contour but not a slot, so
///   each keeps its own law; the same index twice writes one slot twice and the later law wins. An
///   edge OCCT declines to add has no slot and is skipped, as Add(Radius, E) skips it. #612
/// @param edgeCount Number of edges
/// @param radiusPoints Array of parameter-radius pairs per edge (flattened: edge0[rp0,rp1,...],
/// edge1[rp0,...], ...);
///   every radius must be > 0, and each edge's parameters must lie in [0, 1] and strictly increase
/// @param pointCounts Array of how many radius points per edge; fewer than 1 for any edge rejects
///   the call, since a contour with no radius SIGSEGVs in Build()
/// @param declinedEdgeIndices Optional (may be NULL): same #639 reporting contract as
///   OCCTShapeFilletEdges.
/// @param outDeclinedCount Optional (may be NULL): same contract as OCCTShapeFilletEdges.
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletEvolving(OCCTShapeRef                 shape,
                                     const int32_t*               edgeIndices,
                                     int32_t                      edgeCount,
                                     const OCCTFilletRadiusPoint* radiusPoints,
                                     const int32_t*               pointCounts,
                                     int32_t* _Nullable declinedEdgeIndices,
                                     int32_t* _Nullable outDeclinedCount);

// MARK: - Per-Face Variable Offset (v0.38.0)

/// Offset a shape with per-face variable distances.
/// @param shape The shape to offset
/// @param defaultOffset Default offset distance for all faces
/// @param faceIndices Array of 0-based face indices with custom offsets; an index outside
///        0..<faceCount fails the call rather than being skipped (#541)
/// @param faceOffsets Array of offset values for those faces
/// @param faceCount Number of custom face offsets
/// @param tolerance Offset tolerance
/// @param joinType Join type (0=Arc, 1=Tangent, 2=Intersection)
/// @return Offset shape, or NULL on failure
OCCTShapeRef OCCTShapeOffsetPerFace(OCCTShapeRef   shape,
                                    double         defaultOffset,
                                    const int32_t* faceIndices,
                                    const double*  faceOffsets,
                                    int32_t        faceCount,
                                    double         tolerance,
                                    int32_t        joinType);

// MARK: - v0.39.0: Poly HLR, Free Bounds, Pipe Feature, Semi-Infinite Extrusion

/// Create a fast polygon-based HLR (hidden-line removal) drawing.
/// Uses the triangulation mesh rather than exact geometry — much faster but approximate.
/// The shape must have a triangulation (mesh); if not, it will be meshed at the given deflection.
/// Orthographic only, and there is no projectionType parameter because HLRBRep_PolyAlgo ignores
/// the projector's perspective flag: measured against the pinned 8.0.1 kernel, its output is
/// identical for HLRAlgo_Projector(cs) and HLRAlgo_Projector(cs, focus) at every focus tried,
/// including one short enough to make HLRBRep_Algo diverge 4x. See OCCTDrawingCreate for the
/// exact algorithm, which does honour it.
/// @param shape The shape to project
/// @param dirX,dirY,dirZ View direction vector
/// @param deflection Mesh deflection for triangulation (smaller = more accurate, default 0.01)
/// @return Drawing reference, or NULL on failure
OCCTDrawingRef OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                     double       dirX,
                                     double       dirY,
                                     double       dirZ,
                                     double       deflection);

/// Create a pipe feature (protrusion or depression) by sweeping a profile along a spine.
/// The profile is swept along the spine wire and fused/cut with the base shape.
/// @param shape Base solid shape
/// @param profileFaceIndex Index (0-based) of the profile face to sweep
/// @param sketchFaceIndex Index (0-based) of the face on the base solid where the profile sits
/// @param spine Wire defining the sweep path
/// @param fuse 1 to add material (boss), 0 to remove (pocket)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePipeFeature(OCCTShapeRef shape,
                                  int32_t      profileFaceIndex,
                                  int32_t      sketchFaceIndex,
                                  OCCTWireRef  spine,
                                  int32_t      fuse);

/// Create a pipe feature from a standalone profile shape swept along a spine.
/// @param baseShape Base solid shape
/// @param profileShape Profile shape (face or wire) to sweep
/// @param sketchFaceIndex Index (0-based) of the face on base where profile sits
/// @param spine Wire defining the sweep path
/// @param fuse 1 to add material (boss), 0 to remove (pocket)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePipeFeatureFromProfile(OCCTShapeRef baseShape,
                                             OCCTShapeRef profileShape,
                                             int32_t      sketchFaceIndex,
                                             OCCTWireRef  spine,
                                             int32_t      fuse);

/// Create a semi-infinite extrusion of a shape in a direction.
/// The shape is extruded infinitely in the given direction from its original position.
/// @param profile The profile shape (face, wire, or edge) to extrude
/// @param dirX,dirY,dirZ Direction of extrusion
/// @param semiInfinite If true, extrude in one direction only; if false, both directions (infinite)
/// @return Extruded shape, or NULL on failure
OCCTShapeRef OCCTShapeExtrudeSemiInfinite(OCCTShapeRef profile,
                                          double       dirX,
                                          double       dirY,
                                          double       dirZ,
                                          bool         semiInfinite);

/// Prism feature: extrude a profile until it reaches a target face.
/// Uses BRepFeat_MakePrism which is smarter than simple extrusion+boolean.
/// @param baseShape Base solid shape
/// @param profileShape Profile face to extrude
/// @param sketchFaceIndex Face on base where profile sits (0-based)
/// @param dirX,dirY,dirZ Extrusion direction
/// @param fuse 1=add material, 0=remove material
/// @param untilFaceIndex Face index (0-based) on base where extrusion stops (-1 for thru-all)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapePrismUntilFace(OCCTShapeRef baseShape,
                                     OCCTShapeRef profileShape,
                                     int32_t      sketchFaceIndex,
                                     double       dirX,
                                     double       dirY,
                                     double       dirZ,
                                     int32_t      fuse,
                                     int32_t      untilFaceIndex);

// MARK: - v0.42.0: Solid Construction, Fast Polygon, 2D Fillet, Point Cloud Analysis

/// Create a solid from one or more shell shapes
/// @param shells Array of shell shapes (first is outer, rest are cavities)
/// @param count Number of shells
/// @return Solid shape, or NULL on failure
OCCTShapeRef OCCTSolidFromShells(OCCTShapeRef* shells, int32_t count);

/// Create a polygon wire from 3D points (fast, rectilinear edges)
/// @param coords Flat array of x,y,z coordinates
/// @param pointCount Number of points
/// @param closed Whether to close the polygon
/// @return Wire handle, or NULL on failure
OCCTWireRef OCCTWireCreateFastPolygon(const double* coords, int32_t pointCount, bool closed);

/// Add a 2D fillet to a planar face at specified vertex indices
/// @param shape Face shape to fillet
/// @param vertexIndices Array of 0-based vertex indices
/// @param radii Array of fillet radii (one per vertex)
/// @param count Number of fillets to add
/// @return Filleted face shape, or NULL on failure
/// A vertex index naming no vertex of that face fails the call rather than being skipped (#568).
OCCTShapeRef OCCTFace2DFillet(OCCTShapeRef   shape,
                              const int32_t* vertexIndices,
                              const double*  radii,
                              int32_t        count);

/// Add a 2D chamfer to a planar face between adjacent edges
/// @param shape Face shape to chamfer
/// @param edge1Indices Array of first edge indices (0-based)
/// @param edge2Indices Array of second edge indices (0-based)
/// @param distances Array of chamfer distances
/// @param count Number of chamfers to add
/// @return Chamfered face shape, or NULL on failure, including when *either* half of a pair names
///         no edge of that face, which since #568 fails the call rather than dropping the pair
OCCTShapeRef OCCTFace2DChamfer(OCCTShapeRef   shape,
                               const int32_t* edge1Indices,
                               const int32_t* edge2Indices,
                               const double*  distances,
                               int32_t        count);

/// Create a filling surface builder with specified degree and number of points.
/// @param degree Target polynomial degree (default 3)
/// @param nbPtsOnCur Number of discretization points on each constraint curve (default 15)
/// @param maxDegree Maximum polynomial degree (default 8)
/// @param maxSegments Maximum number of segments (default 9)
/// @param tolerance3d 3D tolerance (default 1e-4)
/// @return Filling handle
OCCTFillingRef OCCTFillingCreate(int32_t degree,
                                 int32_t nbPtsOnCur,
                                 int32_t maxDegree,
                                 int32_t maxSegments,
                                 double  tolerance3d);

/// Release a filling surface builder.
void OCCTFillingRelease(OCCTFillingRef filling);

/// Add a boundary edge constraint, deriving the continuity reference from the edge's own pcurve.
///
/// With no nominated support face to validate, this only refuses a constraint OCCT itself throws
/// on. A refusal is sticky either way; see OCCTFillingBuild.
/// @param filling Filling handle
/// @param edge Edge to add as constraint
/// @param continuity Continuity order: 0=position, 1=tangency, 2=curvature (see OCCTFillingParams)
/// @return true if edge was added
bool OCCTFillingAddEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity);

/// Add a free boundary edge constraint (not required to be connected to other edges).
/// @param filling Filling handle
/// @param edge Edge to add
/// @param continuity Continuity order: 0=position, 1=tangency, 2=curvature (see OCCTFillingParams)
/// @return true if edge was added
bool OCCTFillingAddFreeEdge(OCCTFillingRef filling, OCCTEdgeRef edge, int32_t continuity);

/// Add a boundary edge constraint with an explicit reference face for tangency/curvature.
///
/// `support` is used or the constraint fails: if it carries no pcurve for `edge` it cannot
/// serve as the continuity reference, matching OCCTShapeFillConstraints' per-constraint
/// contract. Pass NULL to derive the reference from the edge itself, same as OCCTFillingAddEdge.
/// A refusal is sticky; see OCCTFillingBuild.
/// @param filling Filling handle
/// @param edge Edge to add as constraint
/// @param support Face to be continuous with, or NULL to derive one from the edge
/// @param continuity Continuity order: 0=position, 1=tangency, 2=curvature (see OCCTFillingParams)
/// @return true if the edge was added successfully
bool OCCTFillingAddEdgeWithSupport(OCCTFillingRef filling,
                                   OCCTEdgeRef    edge,
                                   OCCTFaceRef    support,
                                   int32_t        continuity);

/// Add a point constraint that the filling surface must pass through.
/// @param filling Filling handle
/// @param x, y, z Point coordinates
/// @return true if point was added
bool OCCTFillingAddPoint(OCCTFillingRef filling, double x, double y, double z);

/// Number of OCCTFillingAdd* calls this builder refused (#482).
///
/// A refused constraint is one that is NOT in the builder, so it distinguishes a poisoned
/// OCCTFillingBuild from an ordinary fitting failure. Only ever increases; a later successful
/// Add does not clear it.
/// @param filling Filling handle
/// @return Refusal count, or 0 for a NULL handle
int32_t OCCTFillingRefusedConstraintCount(OCCTFillingRef filling);

/// Build the filling surface.
///
/// Fails immediately, without attempting the build, if any OCCTFillingAdd* was refused (#482).
/// Fitting a surface to the constraints that did make it in would answer a different question
/// than the caller asked. Matches OCCTShapeFillConstraints, which returns NULL on the same
/// refusal. Use OCCTFillingRefusedConstraintCount to tell the two failures apart.
/// @param filling Filling handle
/// @return true if build succeeded
bool OCCTFillingBuild(OCCTFillingRef filling);

/// Check if the filling surface was built successfully.
/// @param filling Filling handle
/// @return true if done
bool OCCTFillingIsDone(OCCTFillingRef filling);

/// Get the resulting face from a successful build.
/// @param filling Filling handle
/// @return Face shape, or NULL if not built
OCCTShapeRef OCCTFillingGetFace(OCCTFillingRef filling);

/// Get the G0 (positional) error of the filling surface.
/// @param filling Filling handle
/// @return G0 error value, or -1 on error
double OCCTFillingG0Error(OCCTFillingRef filling);

/// Get the G1 (tangent) error of the filling surface.
/// @param filling Filling handle
/// @return G1 error value, or -1 on error
double OCCTFillingG1Error(OCCTFillingRef filling);

/// Get the G2 (curvature) error of the filling surface.
/// @param filling Filling handle
/// @return G2 error value, or -1 on error
double OCCTFillingG2Error(OCCTFillingRef filling);

// --- LocOpe_Prism: Local prism with shape tracking ---

/// Create a local prism (extrusion) from a face along a direction vector.
/// Tracks generated shapes for each input sub-shape.
/// @param face Face to extrude
/// @param dx, dy, dz Direction vector
/// @return Shape result, or NULL on failure
OCCTShapeRef OCCTLocOpePrism(OCCTShapeRef face, double dx, double dy, double dz);

/// Create a local prism with a secondary translation vector.
/// @param face Face to extrude
/// @param dx, dy, dz Primary direction vector
/// @param tx, ty, tz Secondary translation vector
/// @return Shape result, or NULL on failure
OCCTShapeRef OCCTLocOpePrismWithTranslation(OCCTShapeRef face,
                                            double       dx,
                                            double       dy,
                                            double       dz,
                                            double       tx,
                                            double       ty,
                                            double       tz);

// MARK: - v0.47.0: LocOpe_Revol, LocOpe_DPrism, GeomFill_ConstrainedFilling, BRepCheck

// --- LocOpe_Revol: Local revolution with shape tracking ---

/// Create a revolved shape from a profile face around an axis.
/// Uses default constructor + Perform pattern.
/// @param profile Face to revolve
/// @param axisOriginX,Y,Z Origin point of rotation axis
/// @param axisDirX,Y,Z Direction of rotation axis
/// @param angle Rotation angle in radians
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTLocOpeRevol(OCCTShapeRef profile,
                             double       axisOriginX,
                             double       axisOriginY,
                             double       axisOriginZ,
                             double       axisDirX,
                             double       axisDirY,
                             double       axisDirZ,
                             double       angle);

/// Create a revolved shape with angular offset for positioning.
/// @param profile Face to revolve
/// @param axisOriginX,Y,Z Origin of rotation axis
/// @param axisDirX,Y,Z Direction of rotation axis
/// @param angle Rotation angle in radians
/// @param angledec Angular offset in radians
/// @return Revolved shape, or NULL on failure
OCCTShapeRef OCCTLocOpeRevolWithOffset(OCCTShapeRef profile,
                                       double       axisOriginX,
                                       double       axisOriginY,
                                       double       axisOriginZ,
                                       double       axisDirX,
                                       double       axisDirY,
                                       double       axisDirZ,
                                       double       angle,
                                       double       angledec);

// --- LocOpe_DPrism: Draft prism (tapered extrusion) ---

/// Create a draft prism with two heights and a draft angle.
/// @param spineFace Face defining the prism spine
/// @param height1 First height
/// @param height2 Second height
/// @param angle Draft angle in radians
/// @return Draft prism shape, or NULL on failure
OCCTShapeRef OCCTLocOpeDPrism(OCCTFaceRef spineFace, double height1, double height2, double angle);

/// Create a draft prism with single height and draft angle.
/// @param spineFace Face defining the prism spine
/// @param height Height
/// @param angle Draft angle in radians
/// @return Draft prism shape, or NULL on failure
OCCTShapeRef OCCTLocOpeDPrismSingleHeight(OCCTFaceRef spineFace, double height, double angle);

// MARK: - v0.48.0: Comprehensive Local Operations, Validation, Fixing, Extrema

// --- LocOpe_Pipe ---

/// Perform a pipe sweep of a profile along a wire spine with shape tracking.
/// @param shape Profile shape (face) to sweep
/// @param spineWire Wire shape to use as spine
/// @return Result swept shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpePipe(OCCTShapeRef shape, OCCTShapeRef spineWire);

// --- LocOpe_LinearForm ---

/// Perform a linear form (translation sweep) with shape tracking.
/// @param shape Base shape (face) to sweep
/// @param dx,dy,dz Direction vector
/// @param p1x,p1y,p1z Start point
/// @param p2x,p2y,p2z End point
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeLinearForm(OCCTShapeRef shape,
                                            double       dx,
                                            double       dy,
                                            double       dz,
                                            double       p1x,
                                            double       p1y,
                                            double       p1z,
                                            double       p2x,
                                            double       p2y,
                                            double       p2z);

// --- LocOpe_RevolutionForm ---

/// Perform a revolution form with shape tracking.
/// @param shape Base shape (face) to revolve
/// @param axisOriginX,Y,Z Axis origin
/// @param axisDirX,Y,Z Axis direction
/// @param angle Revolution angle in radians
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeRevolutionForm(OCCTShapeRef shape,
                                                double       axisOriginX,
                                                double       axisOriginY,
                                                double       axisOriginZ,
                                                double       axisDirX,
                                                double       axisDirY,
                                                double       axisDirZ,
                                                double       angle);

// --- LocOpe_SplitShape ---

/// Split a shape by adding a wire on a face. Returns the modified shape.
/// @param shape Shape to split
/// @param faceIndex Index of the face to split (0-based)
/// @param wire Wire to split the face with
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitShapeByWire(OCCTShapeRef shape,
                                                  int32_t      faceIndex,
                                                  OCCTShapeRef wire);

/// Split a shape by adding a vertex on an edge. Returns the modified shape.
/// @param shape Shape to split
/// @param edgeIndex Index of the edge to split (0-based)
/// @param parameter Parameter along the edge [0,1]
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitShapeByVertex(OCCTShapeRef shape,
                                                    int32_t      edgeIndex,
                                                    double       parameter);

// --- LocOpe_SplitDrafts ---

/// Split a face with draft angles on both sides of a wire.
/// @param shape Shape containing the face
/// @param faceIndex Index of the face to split
/// @param wire Wire defining the split
/// @param dirX,dirY,dirZ Extraction direction
/// @param planeOriginX,Y,Z Neutral plane origin
/// @param planeNormalX,Y,Z Neutral plane normal
/// @param angle Draft angle in radians
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitDrafts(OCCTShapeRef shape,
                                             int32_t      faceIndex,
                                             OCCTShapeRef wire,
                                             double       dirX,
                                             double       dirY,
                                             double       dirZ,
                                             double       planeOriginX,
                                             double       planeOriginY,
                                             double       planeOriginZ,
                                             double       planeNormalX,
                                             double       planeNormalY,
                                             double       planeNormalZ,
                                             double       angle);

// --- LocOpe_FindEdges ---

// #613: both finders return a SELECTION of edges, not an enumeration, so the position of an entry
// in outEdges says nothing about which edge it is. Swift was writing that position into Edge.index
// anyway, producing indices that address a different edge -- or no edge -- through edges().
// Both now report each found edge's index in the shape's own deduplicated enumeration alongside it.

/// Find common edges between two shapes.
/// @param shape1 First shape
/// @param shape2 Second shape
/// @param outEdges Output buffer for edge shapes
/// @param outIndices Optional buffer, same length as outEdges, receiving each found edge's 0-based
///        index in shape1's edge enumeration (the one Shape.edges() / Shape.edge(at:) read), or -1
///        when shape1 has no such edge. Pass NULL to skip. Entries may repeat: LocOpe_FindEdges
///        yields one entry per matched pair, so one edge of shape1 can be reported more than once.
/// @param maxEdges Max edges to return
/// @return Number of common edges found
int32_t OCCTLocOpeFindEdges(OCCTShapeRef shape1,
                            OCCTShapeRef shape2,
                            OCCTShapeRef _Nullable* _Nonnull outEdges,
                            int32_t* _Nullable outIndices,
                            int32_t maxEdges);

// --- LocOpe_FindEdgesInFace ---

/// Find edges of a shape that lie in a specific face.
/// @param shape Shape whose edges to check
/// @param faceIndex Face index to check against, in the shared enumeration (#541)
/// @param outEdges Output buffer for edge shapes
/// @param outIndices Optional buffer, same length as outEdges, receiving each found edge's 0-based
///        index in `shape`'s edge enumeration, or -1 when `shape` has no such edge. Pass NULL to
///        skip.
/// @param maxEdges Max edges to return
/// @return Number of edges found in the face
int32_t OCCTLocOpeFindEdgesInFace(OCCTShapeRef shape,
                                  int32_t      faceIndex,
                                  OCCTShapeRef _Nullable* _Nonnull outEdges,
                                  int32_t* _Nullable outIndices,
                                  int32_t maxEdges);

// --- LocOpe_CSIntersector ---

/// Result of a curve-shape intersection point
typedef struct
{
  double  px, py, pz;  // Intersection point
  double  parameter;   // Parameter on curve
  double  uOnFace;     // U parameter on face
  double  vOnFace;     // V parameter on face
  int32_t orientation; // TopAbs_Orientation value
} OCCTCSIntersectionPoint;

/// Intersect a line with a shape.
/// @param shape Shape to intersect
/// @param lineOriginX,Y,Z Line origin
/// @param lineDirX,Y,Z Line direction
/// @param outPoints Output buffer for intersection points
/// @param maxPoints Max points to return
/// @return Number of intersection points found
int32_t OCCTLocOpeCSIntersectLine(OCCTShapeRef             shape,
                                  double                   lineOriginX,
                                  double                   lineOriginY,
                                  double                   lineOriginZ,
                                  double                   lineDirX,
                                  double                   lineDirY,
                                  double                   lineDirZ,
                                  OCCTCSIntersectionPoint* outPoints,
                                  int32_t                  maxPoints);

// OCCTHistoryRef is typedef'd at its first use, in the boolean-history section
// above (OCCTBooleanHistoryAsBRepToolsHistory).

/// Create an empty shape modification history.
OCCTHistoryRef OCCTHistoryCreate(void);

/// Record that a shape was modified into a new shape.
void OCCTHistoryAddModified(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef modified);

/// Record that a shape generated a new shape.
void OCCTHistoryAddGenerated(OCCTHistoryRef history, OCCTShapeRef initial, OCCTShapeRef generated);

/// Record that a shape was removed.
void OCCTHistoryRemove(OCCTHistoryRef history, OCCTShapeRef shape);

/// Check if a shape was removed.
bool OCCTHistoryIsRemoved(OCCTHistoryRef history, OCCTShapeRef shape);

/// Query flags for history state.
bool OCCTHistoryHasModified(OCCTHistoryRef history);
bool OCCTHistoryHasGenerated(OCCTHistoryRef history);
bool OCCTHistoryHasRemoved(OCCTHistoryRef history);

/// Get the number of shapes that the initial shape was modified to.
int32_t OCCTHistoryModifiedCount(OCCTHistoryRef history, OCCTShapeRef initial);

/// Get the number of shapes that the initial shape generated.
int32_t OCCTHistoryGeneratedCount(OCCTHistoryRef history, OCCTShapeRef initial);

/// Destroy a history object.
void OCCTHistoryDestroy(OCCTHistoryRef history);

// MARK: - v0.51.0: BRepLib makers, GC geometry, GC 2D, ChFi2d_AnaFilletAlgo

// --- BRepLib_MakePolygon ---

/// Create a polygonal wire from an array of 3D points.
/// @param coords Array of point coordinates (x,y,z triples), length = nPoints * 3
/// @param nPoints Number of points (must be >= 2)
/// @param close If true, close the polygon
/// @return Wire shape, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakePolygonFromPoints(const double* coords,
                                                    int32_t       nPoints,
                                                    bool          close);

// --- BRepLib_MakeWire ---

/// Create a wire from an array of edge shapes.
/// @param edges Array of edge shapes
/// @param count Number of edges
/// @return Wire, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakeWireFromEdges(const OCCTShapeRef _Nonnull* _Nonnull edges,
                                                int32_t count);

/// Create a wire from an array of OCCTEdgeRef objects.
/// @param edges Array of edge refs
/// @param count Number of edges
/// @return Wire, or NULL on failure
OCCTWireRef _Nullable OCCTWireMakeWireFromEdgeRefs(const OCCTEdgeRef _Nonnull* _Nonnull edges,
                                                   int32_t count);

// --- BRepLib_MakeSolid ---

/// Create a solid from a shell shape.
/// @param shell Shape containing a shell
/// @return Solid shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMakeSolidFromShell(OCCTShapeRef shell);

// --- GC_MakeMirror ---

/// Mirror a shape about a point (point symmetry).
/// @param shape Shape to mirror
/// @param px,py,pz Mirror point
/// @return Mirrored shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMirrorAboutPoint(OCCTShapeRef shape,
                                                 double       px,
                                                 double       py,
                                                 double       pz);

/// Mirror a shape about an axis line.
/// @param shape Shape to mirror
/// @param ox,oy,oz Point on axis
/// @param dx,dy,dz Axis direction
/// @return Mirrored shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeMirrorAboutAxis(OCCTShapeRef shape,
                                                double       ox,
                                                double       oy,
                                                double       oz,
                                                double       dx,
                                                double       dy,
                                                double       dz);

// --- GC_MakeScale ---

/// Scale a shape about a specific point.
/// @param shape Shape to scale
/// @param px,py,pz Center of scaling
/// @param factor Scale factor
/// @return Scaled shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeScaleAboutPoint(OCCTShapeRef shape,
                                                double       px,
                                                double       py,
                                                double       pz,
                                                double       factor);

// --- GC_MakeTranslation ---

/// Translate a shape by the vector from point1 to point2.
/// @param shape Shape to translate
/// @param p1x,p1y,p1z Start point
/// @param p2x,p2y,p2z End point
/// @return Translated shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeTranslateByPoints(OCCTShapeRef shape,
                                                  double       p1x,
                                                  double       p1y,
                                                  double       p1z,
                                                  double       p2x,
                                                  double       p2y,
                                                  double       p2z);

// --- ChFi2d_AnaFilletAlgo ---

/// Result of a 2D analytical fillet operation.
typedef struct
{
  OCCTShapeRef _Nullable fillet; // The fillet arc edge
  OCCTShapeRef _Nullable edge1;  // Trimmed first edge
  OCCTShapeRef _Nullable edge2;  // Trimmed second edge
  bool success;
} OCCTAnaFilletResult;

/// Compute a 2D analytical fillet between two edges (segments/arcs).
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @param planeOx,planeOy,planeOz Point on the plane
/// @param planeNx,planeNy,planeNz Plane normal direction
/// @param radius Fillet radius
/// @return Fillet result with fillet arc and trimmed edges
OCCTAnaFilletResult OCCTChFi2dAnaFillet(OCCTShapeRef edge1,
                                        OCCTShapeRef edge2,
                                        double       planeOx,
                                        double       planeOy,
                                        double       planeOz,
                                        double       planeNx,
                                        double       planeNy,
                                        double       planeNz,
                                        double       radius);

// MARK: - v0.52.0: BRepFill, LocOpe, Healing Utilities, 2D Curve Tools

// --- BRepFill_Generator ---

/// Create a ruled shell by lofting between multiple wire sections.
/// @param wires Array of wire handles
/// @param count Number of wires
/// @return Shell shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillGenerator(const OCCTWireRef _Nonnull* _Nonnull wires,
                                             int32_t count);

// --- BRepFill_AdvancedEvolved ---

/// Create an evolved solid from a spine wire and profile wire.
/// @param spine Wire defining the sweep path
/// @param profile Wire defining the cross-section
/// @param tolerance Geometric tolerance (default 1e-3)
/// @param solidReq Whether to produce a solid (vs shell)
/// @return Evolved shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillAdvancedEvolved(OCCTWireRef spine,
                                                   OCCTWireRef profile,
                                                   double      tolerance,
                                                   bool        solidReq);

// --- BRepFill_OffsetWire ---

/// Offset a planar wire on its face.
/// @param faceRef Face containing the wire
/// @param offset Signed offset distance (positive = outward, negative = inward)
/// @return Offset wire shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillOffsetWire(OCCTFaceRef faceRef, double offset);

// --- BRepFill_Draft ---

/// Create a draft surface from a wire along a direction with a taper angle.
/// @param wire Wire defining the base profile
/// @param dirX,dirY,dirZ Draft direction
/// @param angle Taper angle in radians
/// @param length Draft length
/// @return Draft shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFillDraft(OCCTWireRef wire,
                                         double      dirX,
                                         double      dirY,
                                         double      dirZ,
                                         double      angle,
                                         double      length);

// --- BRepFill_Pipe ---

/// Result of a pipe sweep operation.
typedef struct
{
  OCCTShapeRef _Nullable shape; // The swept pipe shape
  double errorOnSurface;        // Surface approximation error
} OCCTBRepFillPipeResult;

/// Create a pipe sweep of a profile along a spine.
/// @param spine Wire defining the sweep path
/// @param profile Wire defining the cross-section
/// @return Pipe result with shape and error metric
OCCTBRepFillPipeResult OCCTBRepFillPipe(OCCTWireRef spine, OCCTWireRef profile);

// --- BRepFill_CompatibleWires ---

/// Make wires compatible for lofting (same number of edges, aligned).
/// @param wires Array of wire handles
/// @param count Number of wires
/// @param outWires Output array for compatible wires (must be pre-allocated to count)
/// @return Number of compatible wires produced, or 0 on failure
int32_t OCCTBRepFillCompatibleWires(const OCCTWireRef _Nonnull* _Nonnull wires,
                                    int32_t count,
                                    OCCTWireRef _Nullable* _Nonnull outWires);

// --- ChFi2d_FilletAlgo ---

/// Result of a 2D iterative fillet operation.
typedef struct
{
  OCCTShapeRef _Nullable fillet; // The fillet arc edge
  OCCTShapeRef _Nullable edge1;  // Trimmed first edge
  OCCTShapeRef _Nullable edge2;  // Trimmed second edge
  int32_t resultCount;           // Number of fillet solutions found
  bool    success;
} OCCTChFi2dFilletResult;

/// Compute a 2D iterative fillet between two edges in a plane.
/// @param edge1 First edge shape
/// @param edge2 Second edge shape
/// @param planeOx,planeOy,planeOz Point on the working plane
/// @param planeNx,planeNy,planeNz Plane normal direction
/// @param radius Fillet radius
/// @return Fillet result with fillet edge and trimmed input edges
OCCTChFi2dFilletResult OCCTChFi2dFilletAlgo(OCCTShapeRef edge1,
                                            OCCTShapeRef edge2,
                                            double       planeOx,
                                            double       planeOy,
                                            double       planeOz,
                                            double       planeNx,
                                            double       planeNy,
                                            double       planeNz,
                                            double       radius);

// --- LocOpe_BuildShape ---

/// Build a shape from a list of faces.
/// @param shape Shape containing faces
/// @return Built shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeBuildShape(OCCTShapeRef shape);

// MARK: - BOPAlgo — Splitter (v0.61.0)

/// Split shapes by tools. Returns the result shape.
/// @param objects Array of object shapes
/// @param objCount Number of objects
/// @param tools Array of tool shapes
/// @param toolCount Number of tools
/// @return Result shape, or NULL on failure
OCCTShapeRef OCCTBOPAlgoSplit(const OCCTShapeRef* objects,
                              int32_t             objCount,
                              const OCCTShapeRef* tools,
                              int32_t             toolCount);

/// Create a CellsBuilder, add arguments, and perform splitting.
/// @param shapes Array of input shapes
/// @param count Number of shapes
/// @return CellsBuilder handle, or NULL on failure
OCCTCellsBuilderRef OCCTCellsBuilderCreate(const OCCTShapeRef* shapes, int32_t count);

/// Release a CellsBuilder.
void OCCTCellsBuilderRelease(OCCTCellsBuilderRef builder);

/// Add all split parts to result with a material ID.
void OCCTCellsBuilderAddAllToResult(OCCTCellsBuilderRef builder, int32_t material);

/// Remove all parts from result.
void OCCTCellsBuilderRemoveAllFromResult(OCCTCellsBuilderRef builder);

/// Remove internal boundaries between cells with the same material.
void OCCTCellsBuilderRemoveInternalBoundaries(OCCTCellsBuilderRef builder);

/// Get the current result shape.
OCCTShapeRef OCCTCellsBuilderGetResult(OCCTCellsBuilderRef builder);

// MARK: - BOPAlgo — ArgumentAnalyzer (v0.61.0)

/// Analyze two shapes for Boolean operation validity.
/// @param shape1 First shape (object)
/// @param shape2 Second shape (tool)
/// @param operation 0=FUSE, 1=COMMON, 2=CUT, 3=CUT21, 4=SECTION
/// @return true if shapes are valid for the operation (no faults found)
bool OCCTBOPAlgoAnalyzeArguments(OCCTShapeRef shape1, OCCTShapeRef shape2, int32_t operation);

// MARK: - BRepBuilderAPI_MakeShapeOnMesh (v0.61.0)

/// Build a shape from a triangulation mesh.
/// @param points Array of point coordinates (x,y,z triples), length = nodeCount*3
/// @param nodeCount Number of nodes
/// @param triangles Array of triangle indices (i,j,k triples, 1-based), length = triCount*3
/// @param triCount Number of triangles
/// @return Shape, or NULL on failure
OCCTShapeRef OCCTShapeFromMesh(const double*  points,
                               int32_t        nodeCount,
                               const int32_t* triangles,
                               int32_t        triCount);

// MARK: - v0.62.0: BRepLib, LocOpe completion, ShapeUpgrade/ShapeCustom, CPnts, IntCurvesFace

// --- BRepLib_MakeEdge ---

/// Create an edge from a line segment between two parameters.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromLine(double ox,
                                                   double oy,
                                                   double oz,
                                                   double dx,
                                                   double dy,
                                                   double dz,
                                                   double p1,
                                                   double p2);

/// Create an edge from two 3D points.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromPoints(double x1,
                                                     double y1,
                                                     double z1,
                                                     double x2,
                                                     double y2,
                                                     double z2);

/// Create an edge from a circle arc between two parameters.
OCCTShapeRef _Nullable OCCTBRepLibMakeEdgeFromCircle(double cx,
                                                     double cy,
                                                     double cz,
                                                     double dx,
                                                     double dy,
                                                     double dz,
                                                     double radius,
                                                     double p1,
                                                     double p2);

// --- BRepLib_MakeFace ---

/// Create a face from a plane surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromPlane(double ox,
                                                    double oy,
                                                    double oz,
                                                    double nx,
                                                    double ny,
                                                    double nz,
                                                    double uMin,
                                                    double uMax,
                                                    double vMin,
                                                    double vMax,
                                                    double tolerance);

/// Create a face from a cylindrical surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeFaceFromCylinder(double ox,
                                                       double oy,
                                                       double oz,
                                                       double dx,
                                                       double dy,
                                                       double dz,
                                                       double radius,
                                                       double uMin,
                                                       double uMax,
                                                       double vMin,
                                                       double vMax,
                                                       double tolerance);

// --- BRepLib_MakeShell ---

/// Create a shell from a plane surface with UV bounds.
OCCTShapeRef _Nullable OCCTBRepLibMakeShellFromPlane(double ox,
                                                     double oy,
                                                     double oz,
                                                     double nx,
                                                     double ny,
                                                     double nz,
                                                     double uMin,
                                                     double uMax,
                                                     double vMin,
                                                     double vMax);

// --- BRepTools_Modifier + NurbsConvertModification ---

/// Apply NURBS conversion to a shape via BRepTools_Modifier.
/// This is a more flexible alternative to BRepBuilderAPI_NurbsConvert.
OCCTShapeRef _Nullable OCCTBRepToolsModifierNurbsConvert(OCCTShapeRef shape);

// --- LocOpe_BuildWires ---

/// Build wires from loose edges of a shape.
/// @param shape The shape whose edges to build into wires
/// @param faceIndex 0-based face index to get edges from (negative = every edge of the shape)
/// @param outWires Output array of wire shapes — caller must release each
/// @param outCount Number of wires built
/// @return true on success
bool OCCTLocOpeBuildWires(OCCTShapeRef shape,
                          int32_t      faceIndex,
                          OCCTShapeRef _Nullable* _Nullable* _Nonnull outWires,
                          int32_t* outCount);

// --- LocOpe_WiresOnShape + LocOpe_Spliter ---

/// Split a shape by projecting a wire onto a face and splitting along it.
/// @param shape The shape to split
/// @param wire The splitting wire
/// @param faceIndex 0-based index of the face to split
/// @return The split shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWireOnFace(OCCTShapeRef shape,
                                                   OCCTShapeRef wire,
                                                   int32_t      faceIndex);

// --- LocOpe_CurveShapeIntersector ---

/// Intersect a line with a shape and return intersection parameters.
/// @param shape The shape to intersect
/// @param ox,oy,oz Origin of the line
/// @param dx,dy,dz Direction of the line
/// @param outParams Output array of parameter values — caller must free with free()
/// @param outCount Number of intersection points
/// @return true if intersections found
bool OCCTLocOpeCurveShapeIntersectLine(OCCTShapeRef shape,
                                       double       ox,
                                       double       oy,
                                       double       oz,
                                       double       dx,
                                       double       dy,
                                       double       dz,
                                       double* _Nullable* _Nonnull outParams,
                                       int32_t* outCount);

// --- BRepOffset_SimpleOffset ---
OCCTShapeRef _Nullable OCCTBRepOffsetSimpleOffset(OCCTShapeRef shape,
                                                  double       offset,
                                                  double       tolerance);

// --- BRepFeat_Builder ---
// Feature-based boolean with part selection
OCCTShapeRef _Nullable OCCTBRepFeatBuilderFuse(OCCTShapeRef shape, OCCTShapeRef tool);
OCCTShapeRef _Nullable OCCTBRepFeatBuilderCut(OCCTShapeRef shape, OCCTShapeRef tool);

// --- BRepOffset_Offset ---
// Offset a face by a distance
OCCTShapeRef _Nullable OCCTBRepOffsetOffsetFace(OCCTShapeRef faceShape, double offset);

// MARK: - v0.65.0: Shape Processing Completions + Boolean Completions

// OCCTBOPAlgoRemoveFeatures was declared here. It drove BOPAlgo_RemoveFeatures directly, which is
// the algorithm BRepAlgoAPI_Defeaturing forwards to — so it was OCCTShapeDefeature one OCCT layer
// down, with the same forwarded option defaults. #536

// --- BOPAlgo_Section ---
/// Compute section (intersection curves/vertices) between shapes.
/// @param objects Array of object shapes
/// @param objCount Number of objects
/// @param tools Array of tool shapes
/// @param toolCount Number of tools
/// @return Result compound of edges/vertices, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoSection(const OCCTShapeRef _Nonnull* _Nonnull objects,
                                          int32_t objCount,
                                          const OCCTShapeRef _Nonnull* _Nonnull tools,
                                          int32_t toolCount);

// --- Law_BSplineKnotSplitting ---
/// Find knot indices where a BSpline law drops below given continuity.
/// @param law BSpline law function handle
/// @param continuityOrder Continuity level to check, as a literal derivative order: a knot
///   splits when `degree - multiplicity < continuityOrder`. Useful domain 0...degree, saturating
///   there: a cubic with simple interior knots needs 3. See the #480 note in
///   OCCTBridge_Internal.h
/// @param outIndices Output array of split knot indices
/// @param maxIndices Maximum number of indices to write
/// @return Number of split knot indices found (true count, even if writing was truncated
///   by maxIndices), or -1 on failure. #481: was the written count, which capped callers
///   at their first-pass buffer size; matches OCCTLawBSplineKnotSplitParams below.
int32_t OCCTLawBSplineKnotSplitting(OCCTLawFunctionRef _Nonnull law,
                                    int32_t continuityOrder,
                                    int32_t* _Nonnull outIndices,
                                    int32_t maxIndices);

/// Find PARAMETER values (not knot-table indices) where a BSpline law drops below
/// given continuity -- the law-function analogue of OCCTCurve3DBSplineKnotSplits. #403.
/// @param law BSpline law function handle
/// @param continuityOrder Continuity level to check, same contract as
///   OCCTLawBSplineKnotSplitting above
/// @param outParams Pre-allocated array for break parameter values
/// @param maxParams Maximum number of parameters to return
/// @return Number of break parameters found (true count, even if writing was truncated
///   by maxParams), or -1 on failure
int32_t OCCTLawBSplineKnotSplitParams(OCCTLawFunctionRef _Nonnull law,
                                      int32_t continuityOrder,
                                      double* _Nonnull outParams,
                                      int32_t maxParams);

// --- Law_Composite ---
/// Create a composite law from multiple sub-laws stitched together.
/// @param lawRefs Array of law function handles
/// @param count Number of sub-laws
/// @param first Start of parametric range
/// @param last End of parametric range
/// @return Composite law handle
OCCTLawFunctionRef _Nullable OCCTLawComposite(const OCCTLawFunctionRef _Nonnull* _Nonnull lawRefs,
                                              int32_t count,
                                              double  first,
                                              double  last);

// MARK: - IntTools (v0.70.0)

/// Result of an edge-edge or edge-face intersection common part.
typedef struct
{
  int32_t type;        // 0 = vertex, 1 = edge (TopAbs_VERTEX=7, TopAbs_EDGE=6 mapped to 0/1)
  double  param1First; // First parameter on edge 1
  double  param1Last;  // Last parameter on edge 1 (same as first for vertex)
  double  param2First; // First parameter on edge 2
  double  param2Last;  // Last parameter on edge 2 (same as first for vertex)
  double  pointX, pointY, pointZ; // Bounding point (for vertex intersections)
} OCCTCommonPart;

/// Intersect two edges. Returns array of common parts.
/// @param edge1, edge2 Input edges
/// @param outParts Pointer to receive allocated array (caller must free)
/// @param outCount Number of common parts found
/// @return true if intersection succeeded (IsDone)
bool OCCTIntToolsEdgeEdge(OCCTShapeRef _Nonnull edge1,
                          OCCTShapeRef _Nonnull edge2,
                          OCCTCommonPart* _Nullable* _Nonnull outParts,
                          int32_t* _Nonnull outCount);

/// Intersect an edge with a face. Returns array of common parts.
/// @param edge Input edge
/// @param face Input face
/// @param outParts Pointer to receive allocated array (caller must free)
/// @param outCount Number of common parts found
/// @return true if intersection succeeded
bool OCCTIntToolsEdgeFace(OCCTShapeRef _Nonnull edge,
                          OCCTShapeRef _Nonnull face,
                          OCCTCommonPart* _Nullable* _Nonnull outParts,
                          int32_t* _Nonnull outCount);

/// Result of a face-face intersection curve.
typedef struct
{
  double startX, startY, startZ;
  double endX, endY, endZ;
  bool   hasStart;
  bool   hasEnd;
} OCCTFaceFaceCurve;

/// Result of a face-face intersection point.
typedef struct
{
  double x1, y1, z1; // Point on face 1
  double x2, y2, z2; // Point on face 2
} OCCTFaceFacePoint;

/// Intersect two faces. Returns intersection curves and points.
/// @param face1, face2 Input faces
/// @param tolerance Approximation tolerance
/// @param outCurves Pointer to receive allocated curve array (caller must free)
/// @param outCurveCount Number of intersection curves
/// @param outPoints Pointer to receive allocated point array (caller must free)
/// @param outPointCount Number of intersection points
/// @param outTangent Whether the faces are tangent
/// @return true if intersection succeeded
bool OCCTIntToolsFaceFace(OCCTShapeRef _Nonnull face1,
                          OCCTShapeRef _Nonnull face2,
                          double tolerance,
                          OCCTFaceFaceCurve* _Nullable* _Nonnull outCurves,
                          int32_t* _Nonnull outCurveCount,
                          OCCTFaceFacePoint* _Nullable* _Nonnull outPoints,
                          int32_t* _Nonnull outPointCount,
                          bool* _Nonnull outTangent);

/// Classify a 2D point with respect to a face's boundary.
/// @param face Input face
/// @param u, v 2D point coordinates in face parameter space
/// @param tolerance Classification tolerance
/// @return 0=IN, 1=ON, 2=OUT, 3=UNKNOWN
int32_t OCCTIntToolsFClass2dPerform(OCCTShapeRef _Nonnull face,
                                    double u,
                                    double v,
                                    double tolerance);

/// Check if a face represents a hole (inner wire orientation).
/// @param face Input face
/// @param tolerance Classification tolerance
/// @return true if the face is a hole
bool OCCTIntToolsFClass2dIsHole(OCCTShapeRef _Nonnull face, double tolerance);

// MARK: - BOPAlgo Builder (v0.70.0)

/// Build faces from edges on a base face.
/// @param baseFace The face that provides the surface
/// @param edges Array of edge shapes to build faces from
/// @param edgeCount Number of edges
/// @param outFaces Pointer to receive allocated array of face shapes (caller must free each +
/// array)
/// @param outFaceCount Number of result faces
/// @return true if succeeded
bool OCCTBOPAlgoBuilderFace(OCCTShapeRef _Nonnull baseFace,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            OCCTShapeRef _Nullable* _Nullable* _Nonnull outFaces,
                            int32_t* _Nonnull outFaceCount);

/// Build solids from faces.
/// @param faces Array of face shapes
/// @param faceCount Number of faces
/// @param outSolids Pointer to receive allocated array of solid shapes (caller must free each +
/// array)
/// @param outSolidCount Number of result solids
/// @return true if succeeded
bool OCCTBOPAlgoBuilderSolid(const OCCTShapeRef _Nonnull* _Nonnull faces,
                             int32_t faceCount,
                             OCCTShapeRef _Nullable* _Nullable* _Nonnull outSolids,
                             int32_t* _Nonnull outSolidCount);

/// Split a shell into connected components.
/// @param shell Input shell shape
/// @param outShells Pointer to receive allocated array of shell shapes (caller must free each +
/// array)
/// @param outShellCount Number of result shells
/// @return true if succeeded
bool OCCTBOPAlgoShellSplitter(OCCTShapeRef _Nonnull shell,
                              OCCTShapeRef _Nullable* _Nullable* _Nonnull outShells,
                              int32_t* _Nonnull outShellCount);

/// Convert a set of edges into wires.
/// @param edges Compound of edges
/// @param tolerance Tolerance for connecting edges
/// @return Result compound of wires, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoEdgesToWires(OCCTShapeRef _Nonnull edges, double tolerance);

/// Convert a set of wires into faces.
/// @param wires Compound of wires
/// @param tolerance Tolerance for face building
/// @return Result compound of faces, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoWiresToFaces(OCCTShapeRef _Nonnull wires, double tolerance);

// MARK: - BOPTools (v0.70.0)

/// Get the normal to a face at an edge.
/// @param edge Edge on the face
/// @param face Face containing the edge
/// @param outNX/NY/NZ Output normal direction
/// @return true if succeeded
bool OCCTBOPToolsNormalOnEdge(OCCTShapeRef _Nonnull edge,
                              OCCTShapeRef _Nonnull face,
                              double* _Nonnull outNX,
                              double* _Nonnull outNY,
                              double* _Nonnull outNZ);

/// Find a point strictly inside a face.
/// @param face Input face
/// @param outX/Y/Z Output 3D point
/// @return true if a point was found
bool OCCTBOPToolsPointInFace(OCCTShapeRef _Nonnull face,
                             double* _Nonnull outX,
                             double* _Nonnull outY,
                             double* _Nonnull outZ);

/// Check if a shape is empty (has no sub-shapes).
bool OCCTBOPToolsIsEmptyShape(OCCTShapeRef _Nonnull shape);

/// Check if a shell is open (not all edges are shared by two faces).
bool OCCTBOPToolsIsOpenShell(OCCTShapeRef _Nonnull shell);

// MARK: - IntTools_BeanFaceIntersector (v0.71.0)

/// Result range from bean-face intersection.
typedef struct
{
  double first;
  double last;
} OCCTParameterRange;

/// Intersect an edge curve with a face surface to find coincident ranges.
/// @param edge The edge
/// @param face The face
/// @param outRanges Pointer to receive allocated array of ranges (caller must free)
/// @param outCount Number of ranges found
/// @param outMinSquareDist Minimum square distance between edge and face
/// @return true if intersection succeeded
bool OCCTIntToolsBeanFaceIntersect(OCCTShapeRef _Nonnull edge,
                                   OCCTShapeRef _Nonnull face,
                                   OCCTParameterRange* _Nullable* _Nonnull outRanges,
                                   int32_t* _Nonnull outCount,
                                   double* _Nonnull outMinSquareDist);

// MARK: - BOPAlgo_WireSplitter (v0.71.0)

/// Build a wire from a list of edges (static utility).
/// @param edges Array of edge shapes
/// @param edgeCount Number of edges
/// @return Result wire as shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBOPAlgoMakeWire(const OCCTShapeRef _Nonnull* _Nonnull edges,
                                           int32_t edgeCount);

// MARK: - BRepFeat_SplitShape (v0.71.0)

/// Split a shape by adding an edge to a face.
/// @param shape Input shape to split
/// @param edge Edge to add as split line
/// @param face Face on which to add the edge
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeEdge(OCCTShapeRef _Nonnull shape,
                                                  OCCTShapeRef _Nonnull edge,
                                                  OCCTShapeRef _Nonnull face);

/// Split a shape by adding a wire to a face.
/// @param shape Input shape to split
/// @param wire Wire to add as split line
/// @param face Face on which to add the wire
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWire(OCCTShapeRef _Nonnull shape,
                                                  OCCTShapeRef _Nonnull wire,
                                                  OCCTShapeRef _Nonnull face);

/// Split a shape by adding edges/wires to faces, with left/right face outputs.
/// @param shape Input shape to split
/// @param edgesOnFaces Array of (edge, face) pairs — alternating edge, face shapes
/// @param pairCount Number of (edge, face) pairs (array has 2*pairCount elements)
/// @param outLeft Pointer to receive allocated array of left-side face shapes (caller must free
/// each + array)
/// @param outLeftCount Number of left faces
/// @param outRight Pointer to receive allocated array of right-side face shapes (caller must free
/// each + array)
/// @param outRightCount Number of right faces
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatSplitShapeWithSides(
  OCCTShapeRef _Nonnull shape,
  const OCCTShapeRef _Nonnull* _Nonnull edgesOnFaces,
  int32_t pairCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outLeft,
  int32_t* _Nonnull outLeftCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outRight,
  int32_t* _Nonnull outRightCount);

// MARK: - BRepFeat_MakeCylindricalHole (v0.71.0, unified #496)

/// How a BRepFeat_MakeCylindricalHole request bounds its hole. Mirrors Swift's
/// Shape.CylindricalHoleExtent; the values are the wire contract, so do not renumber them.
///
/// The two `extentP*` parameters below are read per mode: unused by ThroughAll, UntilEnd and
/// ThruNext, `extentP0` is the blind length, and `extentP0`/`extentP1` are the range's parameters.
typedef enum
{
  /// Perform(R). An INFINITE cylinder along the axis, in BOTH directions. The axis origin
  /// anchors the axis; it is not where the hole starts.
  OCCTCylindricalHoleExtentThroughAll = 0,
  /// PerformUntilEnd(R). Bounded by the stock's own first and last faces along the axis.
  OCCTCylindricalHoleExtentUntilEnd = 1,
  /// PerformThruNext(R). Stops at the next face after the origin.
  OCCTCylindricalHoleExtentThruNext = 2,
  /// PerformBlind(R, extentP0). Length measured from the axis origin. This is the only mode that
  /// can report HoleTooLong, and it does so rather than drilling through when the length leaves
  /// the stock.
  OCCTCylindricalHoleExtentBlind = 3,
  /// Perform(R, extentP0, extentP1). Bounded by two parameters on the axis.
  OCCTCylindricalHoleExtentRange = 4,
} OCCTCylindricalHoleExtentMode;

/// Drill a cylindrical hole with BRepFeat_MakeCylindricalHole, OCCT's local-operation feature
/// drill.
///
/// Wants a solid — a shell or a face is InvalidPlacement for every mode but ThroughAll. See
/// OCCTShapeDrillHole above for the boolean-subtraction drill, which is a different contract rather
/// than a lesser one (#496).
///
/// @param shape Input solid shape
/// @param axisOriginX/Y/Z Axis origin
/// @param axisDirX/Y/Z Axis direction; any non-zero axis
/// @param radius Hole radius; must exceed Precision::Confusion, below which OCCT reports success
///        and removes no material
/// @param extent One of OCCTCylindricalHoleExtentMode
/// @param extentP0, extentP1 The extent's parameters, per the enum above
/// @return Result shape with hole, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatCylindricalHole(OCCTShapeRef _Nonnull shape,
                                                   double  axisOriginX,
                                                   double  axisOriginY,
                                                   double  axisOriginZ,
                                                   double  axisDirX,
                                                   double  axisDirY,
                                                   double  axisDirZ,
                                                   double  radius,
                                                   int32_t extent,
                                                   double  extentP0,
                                                   double  extentP1);

/// Ask what OCCTBRepFeatCylindricalHole would report for this exact request, without building the
/// result shape.
///
/// Takes the extent for a reason: the status depends on it. The same request can be NoError for
/// ThroughAll and InvalidPlacement for ThruNext, and HoleTooLong exists only under Blind.
///
/// @return 0 = NoError, 1 = InvalidPlacement, 2 = HoleTooLong, 3 = Unknown
int32_t OCCTBRepFeatCylindricalHoleStatus(OCCTShapeRef _Nonnull shape,
                                          double  axisOriginX,
                                          double  axisOriginY,
                                          double  axisOriginZ,
                                          double  axisDirX,
                                          double  axisDirY,
                                          double  axisDirZ,
                                          double  radius,
                                          int32_t extent,
                                          double  extentP0,
                                          double  extentP1);

// MARK: - BRepFeat_Gluer (v0.71.0)

/// Glue two shapes together by binding matching faces.
/// @param baseShape The base shape
/// @param gluedShape The shape to glue onto the base
/// @param baseFaces Array of base shape faces to bind
/// @param gluedFaces Array of glued shape faces to bind (same count)
/// @param faceCount Number of face pairs
/// @return Result glued shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepFeatGluer(OCCTShapeRef _Nonnull baseShape,
                                         OCCTShapeRef _Nonnull gluedShape,
                                         const OCCTShapeRef _Nonnull* _Nonnull baseFaces,
                                         const OCCTShapeRef _Nonnull* _Nonnull gluedFaces,
                                         int32_t faceCount);

// MARK: - LocOpe_WiresOnShape + LocOpe_Spliter (v0.71.0)

/// Split a shape by projecting wires onto faces using LocOpe_WiresOnShape + LocOpe_Spliter.
/// @param shape Input shape
/// @param wiresOnFaces Array of (wire, face) pairs — alternating wire, face shapes
/// @param pairCount Number of (wire, face) pairs
/// @param outDirectLeft Pointer to receive allocated array of directly-left face shapes
/// @param outDirectLeftCount Number of directly-left faces
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWires(
  OCCTShapeRef _Nonnull shape,
  const OCCTShapeRef _Nonnull* _Nonnull wiresOnFaces,
  int32_t pairCount,
  OCCTShapeRef _Nullable* _Nullable* _Nonnull outDirectLeft,
  int32_t* _Nonnull outDirectLeftCount);

/// Bind all edges of wires to shape faces automatically, then split.
/// @param shape Input shape
/// @param wires Array of wire shapes to project onto shape
/// @param wireCount Number of wires
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeSplitByWiresAuto(OCCTShapeRef _Nonnull shape,
                                                  const OCCTShapeRef _Nonnull* _Nonnull wires,
                                                  int32_t wireCount);

// MARK: - LocOpe_Gluer (v0.72.0)

/// Glue two shapes by binding matching faces and edges using LocOpe_Gluer.
/// @param baseShape Base shape
/// @param gluedShape Shape to glue onto base
/// @param baseFaces Base shape faces to bind (parallel array with gluedFaces)
/// @param gluedFaces Glued shape faces to bind
/// @param faceCount Number of face pairs
/// @param baseEdges Base shape edges to bind (parallel array with gluedEdges), may be NULL
/// @param gluedEdges Glued shape edges to bind, may be NULL
/// @param edgeCount Number of edge pairs
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTLocOpeGlue(OCCTShapeRef _Nonnull baseShape,
                                      OCCTShapeRef _Nonnull gluedShape,
                                      const OCCTShapeRef _Nonnull* _Nonnull baseFaces,
                                      const OCCTShapeRef _Nonnull* _Nonnull gluedFaces,
                                      int32_t faceCount,
                                      const OCCTShapeRef _Nullable* _Nullable baseEdges,
                                      const OCCTShapeRef _Nullable* _Nullable gluedEdges,
                                      int32_t edgeCount);

// MARK: - ChFi2d_Builder (v0.72.0)

/// Add a 2D fillet at a vertex on a planar face.
/// @param face Planar face shape
/// @param vertexIndex 0-based vertex index
/// @param radius Fillet radius
/// @return Result face with fillet, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddFillet(OCCTShapeRef _Nonnull face,
                                           int32_t vertexIndex,
                                           double  radius);

/// Add a 2D chamfer between two edges on a planar face (two distances).
/// @param face Planar face shape
/// @param edge1Index 0-based index of first edge
/// @param edge2Index 0-based index of second edge
/// @param d1 Distance on first edge
/// @param d2 Distance on second edge
/// @return Result face with chamfer, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddChamfer(OCCTShapeRef _Nonnull face,
                                            int32_t edge1Index,
                                            int32_t edge2Index,
                                            double  d1,
                                            double  d2);

/// Add a 2D chamfer at a vertex on a planar face (distance + angle).
/// @param face Planar face shape
/// @param edgeIndex 0-based edge index
/// @param vertexIndex 0-based vertex index on that edge
/// @param distance Distance on edge
/// @param angle Chamfer angle in radians
/// @return Result face with chamfer, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dAddChamferAngle(OCCTShapeRef _Nonnull face,
                                                 int32_t edgeIndex,
                                                 int32_t vertexIndex,
                                                 double  distance,
                                                 double  angle);

/// Modify an existing fillet radius on a face using ChFi2d_Builder.
/// @param originalFace The original face before any fillet was added
/// @param modifiedFace The face with existing fillet
/// @param filletEdgeIndex 0-based index of the fillet edge in modified face
/// @param newRadius New fillet radius
/// @return Result face with modified fillet, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dModifyFillet(OCCTShapeRef _Nonnull originalFace,
                                              OCCTShapeRef _Nonnull modifiedFace,
                                              int32_t filletEdgeIndex,
                                              double  newRadius);

/// Remove a fillet from a face using ChFi2d_Builder.
/// @param originalFace The original face before fillet was added
/// @param modifiedFace The face with existing fillet
/// @param filletEdgeIndex 0-based index of the fillet edge in modified face
/// @return Result face with fillet removed, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dRemoveFillet(OCCTShapeRef _Nonnull originalFace,
                                              OCCTShapeRef _Nonnull modifiedFace,
                                              int32_t filletEdgeIndex);

/// Remove a chamfer from a face using ChFi2d_Builder.
/// @param originalFace The original face before chamfer was added
/// @param modifiedFace The face with existing chamfer
/// @param chamferEdgeIndex 0-based index of the chamfer edge in modified face
/// @return Result face with chamfer removed, or NULL on failure
OCCTShapeRef _Nullable OCCTChFi2dRemoveChamfer(OCCTShapeRef _Nonnull originalFace,
                                               OCCTShapeRef _Nonnull modifiedFace,
                                               int32_t chamferEdgeIndex);

// MARK: - ChFi2d_ChamferAPI (v0.72.0)

/// Result of a 2D chamfer operation between two edges.
typedef struct
{
  OCCTShapeRef _Nullable chamferEdge;
  OCCTShapeRef _Nullable modifiedEdge1;
  OCCTShapeRef _Nullable modifiedEdge2;
} OCCTChamfer2DResult;

/// Create a chamfer between two linear edges.
/// @param edge1 First edge
/// @param edge2 Second edge
/// @param d1 Distance on first edge
/// @param d2 Distance on second edge
/// @return Chamfer result with chamfer edge and modified edges
OCCTChamfer2DResult OCCTChFi2dChamferEdges(OCCTShapeRef _Nonnull edge1,
                                           OCCTShapeRef _Nonnull edge2,
                                           double d1,
                                           double d2);

// MARK: - ChFi2d_FilletAPI (v0.72.0)

/// Result of a 2D fillet operation between two edges.
typedef struct
{
  OCCTShapeRef _Nullable filletEdge;
  OCCTShapeRef _Nullable modifiedEdge1;
  OCCTShapeRef _Nullable modifiedEdge2;
  int32_t solutionCount;
} OCCTFillet2DResult;

/// Create a fillet between two edges in a plane.
/// @param edge1 First edge
/// @param edge2 Second edge
/// @param planeNx/Ny/Nz Plane normal
/// @param radius Fillet radius
/// @param nearX/Y/Z Point near desired fillet location
/// @return Fillet result with fillet edge, modified edges, and solution count
OCCTFillet2DResult OCCTChFi2dFilletEdges(OCCTShapeRef _Nonnull edge1,
                                         OCCTShapeRef _Nonnull edge2,
                                         double planeNx,
                                         double planeNy,
                                         double planeNz,
                                         double radius,
                                         double nearX,
                                         double nearY,
                                         double nearZ);

// MARK: - FilletSurf_Builder (v0.72.0)

/// Info about a single fillet surface from FilletSurf_Builder.
typedef struct
{
  OCCTSurfaceRef _Nullable surface;
  OCCTShapeRef _Nullable supportFace1;
  OCCTShapeRef _Nullable supportFace2;
  double  tolerance;
  double  firstParam;
  double  lastParam;
  int32_t startStatus; // FilletSurf_StatusType: 0=OneExtremityOnFace, 1=TwoExtremityOnFace, etc.
  int32_t endStatus;
} OCCTFilletSurfInfo;

/// Compute fillet surfaces on a shape.
/// @param shape Input shape
/// @param edges Array of edge shapes to fillet
/// @param edgeCount Number of edges
/// @param radius Fillet radius
/// @param outSurfaces Pointer to receive allocated array of fillet surface info (caller must free
/// surfaces + array)
/// @param outCount Number of fillet surfaces
/// @return 0=IsOk, 1=IsNotOk, 2=IsPartial
int32_t OCCTFilletSurfBuild(OCCTShapeRef _Nonnull shape,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            double  radius,
                            OCCTFilletSurfInfo* _Nullable* _Nonnull outSurfaces,
                            int32_t* _Nonnull outCount);

/// Get the error status when FilletSurf_Builder fails.
/// @return 0=EdgeNotG1, 1=FacesNotG1, 2=EdgeNotOnShape, 3=NotSharpEdge, 4=PbFilletCompute
int32_t OCCTFilletSurfError(OCCTShapeRef _Nonnull shape,
                            const OCCTShapeRef _Nonnull* _Nonnull edges,
                            int32_t edgeCount,
                            double  radius);

// MARK: - v0.73.0: TKHlr — Extended HLR, ReflectLines, TopCnx, Intrv

/// Extended HLR edge category type for fine-grained edge extraction
typedef enum
{
  OCCTHLREdgeVisibleSharp     = 0, ///< Visible C0-continuity (sharp) edges
  OCCTHLREdgeVisibleSmooth    = 1, ///< Visible G1-continuity (smooth) edges
  OCCTHLREdgeVisibleSewn      = 2, ///< Visible CN-continuity (sewn) edges
  OCCTHLREdgeVisibleOutline   = 3, ///< Visible silhouette/outline edges
  OCCTHLREdgeVisibleIso       = 4, ///< Visible isoparameter lines (exact HLR only)
  OCCTHLREdgeVisibleOutline3d = 5, ///< Visible outline edges in 3D (exact HLR only)
  OCCTHLREdgeHiddenSharp      = 6, ///< Hidden C0-continuity (sharp) edges
  OCCTHLREdgeHiddenSmooth     = 7, ///< Hidden G1-continuity (smooth) edges
  OCCTHLREdgeHiddenSewn       = 8, ///< Hidden CN-continuity (sewn) edges
  OCCTHLREdgeHiddenOutline    = 9, ///< Hidden silhouette/outline edges
  OCCTHLREdgeHiddenIso        = 10 ///< Hidden isoparameter lines (exact HLR only)
} OCCTHLREdgeCategory;

/// Get edges by fine-grained category from an exact HLR drawing.
/// @param shape Input shape
/// @param dirX,dirY,dirZ View direction
/// @param category Edge category to extract
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
                                                 double              dirX,
                                                 double              dirY,
                                                 double              dirZ,
                                                 OCCTHLREdgeCategory category);

/// Get edges by fine-grained category from a polygon-based (fast) HLR drawing.
/// Note: IsoLine and Outline3d categories are not available for poly HLR (returns NULL).
/// @param shape Input shape (meshed internally for the polyhedral projection)
/// @param dirX,dirY,dirZ View direction
/// @param category Edge category to extract
/// @param deflection Linear mesh deflection (mm) for the internal triangulation —
///        smaller = finer drawing (more, shorter edges), larger = coarser/faster
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRPolyGetEdgesByCategory(OCCTShapeRef _Nonnull shape,
                                                     double              dirX,
                                                     double              dirY,
                                                     double              dirZ,
                                                     OCCTHLREdgeCategory category,
                                                     double              deflection);

/// Get edges using the generic CompoundOfEdges API from exact HLR.
/// @param shape Input shape
/// @param dirX,dirY,dirZ View direction
/// @param edgeType 0=Undefined, 1=IsoLine, 2=OutLine, 3=Rg1Line, 4=RgNLine, 5=Sharp
/// @param visible true for visible edges, false for hidden
/// @param in3d true for 3D result, false for 2D projected
/// @return Shape containing edges, or NULL if none
OCCTShapeRef _Nullable OCCTHLRCompoundOfEdges(OCCTShapeRef _Nonnull shape,
                                              double  dirX,
                                              double  dirY,
                                              double  dirZ,
                                              int32_t edgeType,
                                              bool    visible,
                                              bool    in3d);

// --- HLRAppli_ReflectLines ---

/// Compute reflect (silhouette) lines on a shape.
/// @param shape Input shape
/// @param nx,ny,nz View plane normal direction
/// @param xAt,yAt,zAt View target point
/// @param xUp,yUp,zUp Up direction
/// @return Compound of reflect line edges in 3D, or NULL on failure
OCCTShapeRef _Nullable OCCTHLRReflectLines(OCCTShapeRef _Nonnull shape,
                                           double nx,
                                           double ny,
                                           double nz,
                                           double xAt,
                                           double yAt,
                                           double zAt,
                                           double xUp,
                                           double yUp,
                                           double zUp);

/// Compute reflect lines and get specific edge types.
/// @param shape Input shape
/// @param nx,ny,nz View plane normal direction
/// @param xAt,yAt,zAt View target point
/// @param xUp,yUp,zUp Up direction
/// @param edgeType 0=Undefined, 1=IsoLine, 2=OutLine, 3=Rg1Line, 4=RgNLine, 5=Sharp
/// @param visible true for visible, false for hidden
/// @param in3d true for 3D result, false for 2D projected
/// @return Compound of edges, or NULL on failure
OCCTShapeRef _Nullable OCCTHLRReflectLinesFiltered(OCCTShapeRef _Nonnull shape,
                                                   double  nx,
                                                   double  ny,
                                                   double  nz,
                                                   double  xAt,
                                                   double  yAt,
                                                   double  zAt,
                                                   double  xUp,
                                                   double  yUp,
                                                   double  zUp,
                                                   int32_t edgeType,
                                                   bool    visible,
                                                   bool    in3d);

// MARK: - BiTgte_Blend (Rolling-Ball Blend)

/// Result of BiTgte_Blend operation.
typedef struct
{
  bool    isDone;
  int32_t nbSurfaces;
} OCCTBiTgteBlendInfo;

/// Create rolling-ball blend on shape edges.
OCCTShapeRef _Nullable OCCTBiTgteBlend(OCCTShapeRef _Nonnull shape,
                                       const int32_t* _Nonnull edgeIndices,
                                       int32_t edgeCount,
                                       double  radius,
                                       double  tolerance,
                                       bool    nubs);

/// Get blend info (isDone, nbSurfaces) without building result.
OCCTBiTgteBlendInfo OCCTBiTgteBlendInfo_(OCCTShapeRef _Nonnull shape,
                                         const int32_t* _Nonnull edgeIndices,
                                         int32_t edgeCount,
                                         double  radius,
                                         double  tolerance);

// MARK: - BRepPreviewAPI_MakeBox

/// Create a preview box shape (handles degenerate dimensions: face, edge, vertex).
OCCTShapeRef _Nullable OCCTPreviewBox(double dx, double dy, double dz);

// MARK: - v0.78.0: Shape Modifications, Surface Recognition & Polygon Data

// MARK: - BRepTools_TrsfModification

/// Apply a gp_Trsf transformation to a shape via BRepTools_Modifier.
/// Returns the modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeTrsfModification(OCCTShapeRef _Nonnull shapeRef,
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
                                                 double a34);

// MARK: - BRepTools_GTrsfModification

/// Apply a gp_GTrsf general transformation to a shape via BRepTools_Modifier.
/// The shape should be NURBS-converted first for non-uniform scaling.
/// Returns the modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeGTrsfModification(OCCTShapeRef _Nonnull shapeRef,
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
                                                  double a34);

// MARK: - BRepTools_CopyModification

/// Deep copy a shape via BRepTools_Modifier with optional geometry/mesh copying.
/// Returns the copied shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeCopyModification(OCCTShapeRef _Nonnull shapeRef,
                                                 bool copyGeometry,
                                                 bool copyMesh);

// --- BRepFill_Evolved ---
/// Create evolved shape from face spine + wire profile
OCCTShapeRef _Nullable OCCTBRepFillEvolved(OCCTShapeRef _Nonnull spineFaceRef,
                                           OCCTShapeRef _Nonnull profileWireRef,
                                           double axOriginX,
                                           double axOriginY,
                                           double axOriginZ,
                                           double axNormalX,
                                           double axNormalY,
                                           double axNormalZ,
                                           double axXDirX,
                                           double axXDirY,
                                           double axXDirZ,
                                           int    joinType,
                                           bool   makeSolid);

OCCTOffsetAncestorsRef OCCTBRepFillOffsetAncestorsCreate(OCCTShapeRef _Nonnull faceRef,
                                                         double offset,
                                                         int    joinType);
bool                   OCCTBRepFillOffsetAncestorsIsDone(OCCTOffsetAncestorsRef _Nonnull ref);
bool                   OCCTBRepFillOffsetAncestorsHasAncestor(OCCTOffsetAncestorsRef _Nonnull ref,
                                                              OCCTShapeRef _Nonnull edgeRef);
OCCTShapeRef _Nullable OCCTBRepFillOffsetAncestorsGetAncestor(OCCTOffsetAncestorsRef _Nonnull ref,
                                                              OCCTShapeRef _Nonnull edgeRef);
void OCCTBRepFillOffsetAncestorsRelease(OCCTOffsetAncestorsRef _Nonnull ref);

/// Create N-section law from array of wire shapes
OCCTNSectionsRef OCCTBRepFillNSectionsCreate(const OCCTShapeRef _Nonnull* _Nonnull wireRefs,
                                             int count);
int              OCCTBRepFillNSectionsNbLaw(OCCTNSectionsRef _Nonnull ref);
bool             OCCTBRepFillNSectionsIsConstant(OCCTNSectionsRef _Nonnull ref);
bool             OCCTBRepFillNSectionsIsVertex(OCCTNSectionsRef _Nonnull ref);
void             OCCTBRepFillNSectionsRelease(OCCTNSectionsRef _Nonnull ref);

// MARK: - BRepOffsetAPI_FindContigousEdges

/// Result struct for contiguous edge finding
typedef struct
{
  int contigousEdgeCount;
  int degeneratedShapeCount;
} OCCTContigousEdgeResult;

/// Find contiguous edges in a shape
OCCTContigousEdgeResult OCCTShapeFindContigousEdges(OCCTShapeRef _Nonnull shape, double tolerance);

// MARK: - IntTools_Tools (v0.90.0)

/// Check if two vertices are coincident (within tolerance).
/// @return 0 if coincident, non-zero otherwise
int32_t OCCTIntToolsComputeVV(OCCTShapeRef _Nonnull vertex1, OCCTShapeRef _Nonnull vertex2);

/// Compute an intermediate parameter between two values.
double OCCTIntToolsIntermediatePoint(double first, double last);

/// Check if two directions are coincident (parallel or anti-parallel).
bool OCCTIntToolsIsDirsCoinside(double dx1,
                                double dy1,
                                double dz1,
                                double dx2,
                                double dy2,
                                double dz2);

/// Check if two directions are coincident within a tolerance.
bool OCCTIntToolsIsDirsCoinisdeWithTol(double dx1,
                                       double dy1,
                                       double dz1,
                                       double dx2,
                                       double dy2,
                                       double dz2,
                                       double tol);

/// Compute intersection range from tolerances and angle.
double OCCTIntToolsComputeIntRange(double tol1, double tol2, double angle);

/// Create a shape image mapping.
OCCTBRepAlgoImageRef _Nonnull OCCTBRepAlgoImageCreate(void);

/// Release a shape image.
void OCCTBRepAlgoImageRelease(OCCTBRepAlgoImageRef _Nonnull img);

/// Set root shape.
void OCCTBRepAlgoImageSetRoot(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Bind old shape to new shape (replacement).
void OCCTBRepAlgoImageBind(OCCTBRepAlgoImageRef _Nonnull img,
                           OCCTShapeRef _Nonnull oldShape,
                           OCCTShapeRef _Nonnull newShape);

/// Check if shape has image.
bool OCCTBRepAlgoImageHasImage(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Check if shape is an image of another.
bool OCCTBRepAlgoImageIsImage(OCCTBRepAlgoImageRef _Nonnull img, OCCTShapeRef _Nonnull shape);

/// Clear all mappings.
void OCCTBRepAlgoImageClear(OCCTBRepAlgoImageRef _Nonnull img);

// MARK: - BRepAlgo_Loop (v0.97.0)

/// Build loops (wires) from edges on a face, then optionally convert to faces.
/// @return Number of result wires/faces, or -1 on error
int32_t OCCTShapeBuildLoops(OCCTShapeRef _Nonnull shape, int32_t faceIndex);

// MARK: - Draft_Modification (v0.98.0)

/// Apply a draft angle to a face of a shape.
/// @return Result shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeDraftModification(OCCTShapeRef _Nonnull shape,
                                                  int32_t faceIndex,
                                                  double  dirX,
                                                  double  dirY,
                                                  double  dirZ,
                                                  double  angle,
                                                  double  planeOX,
                                                  double  planeOY,
                                                  double  planeOZ,
                                                  double  planeNX,
                                                  double  planeNY,
                                                  double  planeNZ);

// MARK: - gce Transform Factories 3D (v0.103.0)

/// Create a 3D point mirror transformation. Stores result in 12-element matrix (row-major 3x4).
void OCCTMakeMirrorPoint(double px, double py, double pz, double* _Nonnull matrix);

/// Create a 3D axis mirror transformation.
void OCCTMakeMirrorAxis(double px,
                        double py,
                        double pz,
                        double dx,
                        double dy,
                        double dz,
                        double* _Nonnull matrix);

/// Create a 3D plane mirror transformation.
void OCCTMakeMirrorPlane(double px,
                         double py,
                         double pz,
                         double nx,
                         double ny,
                         double nz,
                         double* _Nonnull matrix);

/// Create a 3D rotation transformation.
void OCCTMakeRotation(double px,
                      double py,
                      double pz,
                      double dx,
                      double dy,
                      double dz,
                      double angle,
                      double* _Nonnull matrix);

/// Create a 3D scale transformation.
void OCCTMakeScaleTransform(double px,
                            double py,
                            double pz,
                            double factor,
                            double* _Nonnull matrix);

/// Create a 3D translation transformation from vector.
void OCCTMakeTranslationVec(double vx, double vy, double vz, double* _Nonnull matrix);

/// Create a 3D translation transformation from two points.
void OCCTMakeTranslationPoints(double x1,
                               double y1,
                               double z1,
                               double x2,
                               double y2,
                               double z2,
                               double* _Nonnull matrix);

// MARK: - gce Transform Factories 2D (v0.103.0)

/// Create a 2D point mirror transformation. Stores result in 6-element matrix (row-major 2x3).
void OCCTMakeMirror2dPoint(double px, double py, double* _Nonnull matrix);

/// Create a 2D axis mirror transformation.
void OCCTMakeMirror2dAxis(double px, double py, double dx, double dy, double* _Nonnull matrix);

/// Create a 2D rotation transformation.
void OCCTMakeRotation2d(double px, double py, double angle, double* _Nonnull matrix);

/// Create a 2D scale transformation.
void OCCTMakeScale2d(double px, double py, double factor, double* _Nonnull matrix);

/// Create a 2D translation from vector.
void OCCTMakeTranslation2dVec(double vx, double vy, double* _Nonnull matrix);

/// Create a 2D translation from two points.
void OCCTMakeTranslation2dPoints(double x1,
                                 double y1,
                                 double x2,
                                 double y2,
                                 double* _Nonnull matrix);

/// Create a 2D direction from coordinates. Returns false if zero vector.
bool OCCTMakeDir2d(double x, double y, double* _Nonnull outX, double* _Nonnull outY);

/// Create a 2D direction from two points. Returns false if coincident.
bool OCCTMakeDir2dFromPoints(double x1,
                             double y1,
                             double x2,
                             double y2,
                             double* _Nonnull outX,
                             double* _Nonnull outY);

// MARK: - Law_Interpolate (v0.103.0)

/// Create an interpolated law function from values. Returns law function ref.
/// values/parameters are arrays of length count. If parameters is NULL, auto-parameterized.
OCCTLawFunctionRef _Nullable OCCTLawInterpolate(const double* _Nonnull values,
                                                int32_t count,
                                                const double* _Nullable parameters,
                                                bool periodic);

/// Create a pipe shell from a spine wire.
OCCTPipeShellRef _Nullable OCCTPipeShellCreate(OCCTShapeRef _Nonnull spineWire);

/// Release a pipe shell.
void OCCTPipeShellRelease(OCCTPipeShellRef _Nonnull ps);

/// Set Frenet trihedron mode.
void OCCTPipeShellSetFrenet(OCCTPipeShellRef _Nonnull ps, bool frenet);

/// Set discrete trihedron mode.
void OCCTPipeShellSetDiscrete(OCCTPipeShellRef _Nonnull ps);

/// Set fixed binormal direction.
void OCCTPipeShellSetFixed(OCCTPipeShellRef _Nonnull ps, double bx, double by, double bz);

/// Add a profile (wire or vertex) at the current location.
void OCCTPipeShellAdd(OCCTPipeShellRef _Nonnull ps, OCCTShapeRef _Nonnull profile);

/// Add a profile at a specific vertex on the spine.
void OCCTPipeShellAddAtVertex(OCCTPipeShellRef _Nonnull ps,
                              OCCTShapeRef _Nonnull profile,
                              OCCTShapeRef _Nonnull vertex);

/// Set a profile with a scaling law.
void OCCTPipeShellSetLaw(OCCTPipeShellRef _Nonnull ps,
                         OCCTShapeRef _Nonnull profile,
                         OCCTLawFunctionRef _Nonnull law);

/// Set tolerances.
void OCCTPipeShellSetTolerance(OCCTPipeShellRef _Nonnull ps,
                               double tol3d,
                               double boundTol,
                               double tolAngular);

/// Set transition mode (0=Modified, 1=Right, 2=Round).
void OCCTPipeShellSetTransition(OCCTPipeShellRef _Nonnull ps, int32_t mode);

/// Build the pipe shell. Returns true on success.
bool OCCTPipeShellBuild(OCCTPipeShellRef _Nonnull ps);

/// Get the resulting shape.
OCCTShapeRef _Nullable OCCTPipeShellShape(OCCTPipeShellRef _Nonnull ps);

/// Make the result into a solid. Returns true on success.
bool OCCTPipeShellMakeSolid(OCCTPipeShellRef _Nonnull ps);

/// Get the approximation error.
double OCCTPipeShellError(OCCTPipeShellRef _Nonnull ps);

/// Check if the pipe shell is ready to build.
bool OCCTPipeShellIsReady(OCCTPipeShellRef _Nonnull ps);

// MARK: - Draft info types (v0.105.0)

/// Create a Draft_EdgeInfo and query NewGeometry status.
bool OCCTDraftEdgeInfoNewGeometry(void);

/// Create a Draft_FaceInfo and query NewGeometry status.
bool OCCTDraftFaceInfoNewGeometry(void);

/// Create a Draft_VertexInfo and query its geometry point.
void OCCTDraftVertexInfoGeometry(double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Create a Draft_EdgeInfo with tangent direction.
bool OCCTDraftEdgeInfoSetTangent(double dx, double dy, double dz);

/// Create a Draft_FaceInfo from a surface and check RootFace.
bool OCCTDraftFaceInfoFromSurface(OCCTSurfaceRef _Nonnull surface);

/// Create a Draft_VertexInfo, add a parameter, and check ChangeParameter.
double OCCTDraftVertexInfoAddParameter(double param);

// MARK: - BRepFill_PipeShell extensions (v0.106.0)

/// Set maximum degree for pipe shell approximation.
void OCCTPipeShellSetMaxDegree(OCCTPipeShellRef _Nonnull ps, int32_t maxDeg);

/// Set maximum number of segments for pipe shell approximation.
void OCCTPipeShellSetMaxSegments(OCCTPipeShellRef _Nonnull ps, int32_t maxSeg);

/// Force C1 approximation on pipe shell.
void OCCTPipeShellSetForceApproxC1(OCCTPipeShellRef _Nonnull ps, bool force);

/// Get the error on the generated surface.
double OCCTPipeShellErrorOnSurface(OCCTPipeShellRef _Nonnull ps);

/// Get the first shape of the pipe shell (start cap).
OCCTShapeRef _Nullable OCCTPipeShellFirstShape(OCCTPipeShellRef _Nonnull ps);

/// Get the last shape of the pipe shell (end cap).
OCCTShapeRef _Nullable OCCTPipeShellLastShape(OCCTPipeShellRef _Nonnull ps);

// MARK: - MakeFace Extras (v0.107.0)

/// Create a face from a sphere with UV bounds (no tolerance param).
OCCTShapeRef _Nullable OCCTMakeFaceFromSphere(double cx,
                                              double cy,
                                              double cz,
                                              double radius,
                                              double umin,
                                              double umax,
                                              double vmin,
                                              double vmax);

/// Create a face from a torus with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromTorus(double cx,
                                             double cy,
                                             double cz,
                                             double nx,
                                             double ny,
                                             double nz,
                                             double major,
                                             double minor,
                                             double umin,
                                             double umax,
                                             double vmin,
                                             double vmax);

/// Create a face from a cone with UV bounds.
OCCTShapeRef _Nullable OCCTMakeFaceFromCone(double cx,
                                            double cy,
                                            double cz,
                                            double nx,
                                            double ny,
                                            double nz,
                                            double angle,
                                            double radius,
                                            double umin,
                                            double umax,
                                            double vmin,
                                            double vmax);

/// Create a face from a surface trimmed by a wire.
OCCTShapeRef _Nullable OCCTMakeFaceFromSurfaceWire(OCCTSurfaceRef _Nonnull surface,
                                                   OCCTShapeRef _Nonnull wire,
                                                   bool inside);

/// Add a hole (inner wire) to a face.
OCCTShapeRef _Nullable OCCTMakeFaceAddHole(OCCTShapeRef _Nonnull face, OCCTShapeRef _Nonnull wire);

/// Copy a face.
OCCTShapeRef _Nullable OCCTMakeFaceCopy(OCCTShapeRef _Nonnull face);

/// Create a sewing builder with given tolerance.
OCCTSewingRef _Nullable OCCTSewingCreate(double tolerance);

/// Release a sewing builder.
void OCCTSewingRelease(OCCTSewingRef _Nullable sewing);

/// Add a shape to the sewing builder.
void OCCTSewingAdd(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Perform sewing.
void OCCTSewingPerform(OCCTSewingRef _Nonnull sewing);

/// Get the result of sewing.
OCCTShapeRef _Nullable OCCTSewingResult(OCCTSewingRef _Nonnull sewing);

/// Get the number of free edges after sewing.
int32_t OCCTSewingNbFreeEdges(OCCTSewingRef _Nonnull sewing);

/// Get the number of contiguous edges after sewing.
int32_t OCCTSewingNbContigousEdges(OCCTSewingRef _Nonnull sewing);

/// Get the number of degenerated shapes after sewing.
int32_t OCCTSewingNbDegeneratedShapes(OCCTSewingRef _Nonnull sewing);

/// Create a normal projection tool targeting the given shape.
OCCTNormalProjectionRef _Nullable OCCTNormalProjectionCreate(OCCTShapeRef _Nonnull targetShape);

/// Release a normal projection tool.
void OCCTNormalProjectionRelease(OCCTNormalProjectionRef _Nullable proj);

/// Add a wire/edge to be projected.
void OCCTNormalProjectionAdd(OCCTNormalProjectionRef _Nonnull proj, OCCTShapeRef _Nonnull wire);

/// Build the projection. Returns true on success.
bool OCCTNormalProjectionBuild(OCCTNormalProjectionRef _Nonnull proj);

/// Get the projection result shape.
OCCTShapeRef _Nullable OCCTNormalProjectionResult(OCCTNormalProjectionRef _Nonnull proj);

/// Create an AsDes tracker.
OCCTAsDesRef _Nonnull OCCTAsDesCreate(void);

/// Release an AsDes tracker.
void OCCTAsDesRelease(OCCTAsDesRef _Nonnull ad);

/// Add a parent-child relationship.
void OCCTAsDesAdd(OCCTAsDesRef _Nonnull ad,
                  OCCTShapeRef _Nonnull parent,
                  OCCTShapeRef _Nonnull child);

/// Check if a shape has descendants.
bool OCCTAsDesHasDescendant(OCCTAsDesRef _Nonnull ad, OCCTShapeRef _Nonnull shape);

/// Get number of descendants for a shape.
int32_t OCCTAsDesDescendantCount(OCCTAsDesRef _Nonnull ad, OCCTShapeRef _Nonnull shape);

// MARK: - v0.113.0: MakeEdge completions, ProjOnCurve/Surf, DistShapeShape, ShapeFix_Wire/Face,
//                    MakeFace extras, IntCS, BSplineCurve/Surface mutations

// --- BRepBuilderAPI_MakeEdge completions ---

/// Create a full ellipse edge.
OCCTShapeRef _Nullable OCCTMakeEdgeFromEllipse(double cx,
                                               double cy,
                                               double cz,
                                               double nx,
                                               double ny,
                                               double nz,
                                               double major,
                                               double minor);

/// Create an ellipse arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromEllipseArc(double cx,
                                                  double cy,
                                                  double cz,
                                                  double nx,
                                                  double ny,
                                                  double nz,
                                                  double major,
                                                  double minor,
                                                  double u1,
                                                  double u2);

/// Create a hyperbola arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromHyperbolaArc(double cx,
                                                    double cy,
                                                    double cz,
                                                    double nx,
                                                    double ny,
                                                    double nz,
                                                    double major,
                                                    double minor,
                                                    double u1,
                                                    double u2);

/// Create a parabola arc edge between parameters u1 and u2.
OCCTShapeRef _Nullable OCCTMakeEdgeFromParabolaArc(double cx,
                                                   double cy,
                                                   double cz,
                                                   double nx,
                                                   double ny,
                                                   double nz,
                                                   double focal,
                                                   double u1,
                                                   double u2);

/// Create an edge from a Geom_Curve (full domain).
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurve(OCCTCurve3DRef _Nonnull curve);

/// Create an edge from a Geom_Curve with parameter bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurveParams(OCCTCurve3DRef _Nonnull curve,
                                                   double u1,
                                                   double u2);

/// Create an edge from a Geom_Curve with point bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeFromCurvePoints(OCCTCurve3DRef _Nonnull curve,
                                                   double x1,
                                                   double y1,
                                                   double z1,
                                                   double x2,
                                                   double y2,
                                                   double z2);

/// Create an edge from a 2D pcurve on a surface (full domain).
OCCTShapeRef _Nullable OCCTMakeEdgeOnSurface(OCCTCurve2DRef _Nonnull pcurve,
                                             OCCTSurfaceRef _Nonnull surface);

/// Create an edge from a 2D pcurve on a surface with parameter bounds.
OCCTShapeRef _Nullable OCCTMakeEdgeOnSurfaceParams(OCCTCurve2DRef _Nonnull pcurve,
                                                   OCCTSurfaceRef _Nonnull surface,
                                                   double u1,
                                                   double u2);

/// Get the first vertex point of an edge.
void OCCTEdgeVertex1(OCCTShapeRef _Nonnull edge,
                     double* _Nonnull x,
                     double* _Nonnull y,
                     double* _Nonnull z);

/// Get the last vertex point of an edge.
void OCCTEdgeVertex2(OCCTShapeRef _Nonnull edge,
                     double* _Nonnull x,
                     double* _Nonnull y,
                     double* _Nonnull z);

/// Validity verdict for a finished edge: 0 valid, 1 invalid, -1 null input or exception.
/// NOT BRepBuilderAPI_EdgeError, which this comment claimed until #808: that enum is a property of
/// a live BRepBuilderAPI_MakeEdge builder and cannot be recovered from a TopoDS_Edge, so the
/// implementation runs BRepCheck_Analyzer instead.
int32_t OCCTMakeEdgeError(OCCTShapeRef _Nonnull edge);

// --- BRepBuilderAPI_MakeFace completions ---

/// Create a face from a Geom_Surface with UV bounds and tolerance.
OCCTShapeRef _Nullable OCCTMakeFaceFromSurfaceUV(OCCTSurfaceRef _Nonnull surface,
                                                 double umin,
                                                 double umax,
                                                 double vmin,
                                                 double vmax,
                                                 double tol);

// OCCTMakeFaceFromGpPlane / OCCTMakeFaceFromGpCylinder used to live here (BRepBuilderAPI_MakeFace's
// tolerance-less gp_Pln/gp_Cylinder constructors). Removed (#841): they duplicated
// OCCTBRepLibMakeFaceFromPlane/OCCTBRepLibMakeFaceFromCylinder above with a hardcoded tolerance
// (BRepLib_MakeFace's own Precision::Confusion() default) instead of an explicit parameter.
// Shape.faceFromPlane(...:uBounds:vBounds:tolerance:)/faceFromCylinder(...) now delegate to the
// tolerance-taking Swift overloads directly, defaulting to that same 1e-7 value.

/// Create an empty wire builder.
OCCTWireBuilderRef _Nonnull OCCTWireBuilderCreate(void);

/// Release a wire builder.
void OCCTWireBuilderRelease(OCCTWireBuilderRef _Nonnull wb);

/// Add an edge to the wire builder.
void OCCTWireBuilderAddEdge(OCCTWireBuilderRef _Nonnull wb, OCCTShapeRef _Nonnull edge);

/// Add a wire to the wire builder.
void OCCTWireBuilderAddWire(OCCTWireBuilderRef _Nonnull wb, OCCTShapeRef _Nonnull wire);

/// Get the resulting wire.
OCCTShapeRef _Nullable OCCTWireBuilderWire(OCCTWireBuilderRef _Nonnull wb);

/// Check if the wire builder succeeded.
bool OCCTWireBuilderIsDone(OCCTWireBuilderRef _Nonnull wb);

/// Get error status: 0=WireDone, 1=EmptyWire, 2=DisconnectedWire, 3=NonManifoldWire.
int32_t OCCTWireBuilderError(OCCTWireBuilderRef _Nonnull wb);

// --- Boolean operations with tolerance ---

/// Fuse two shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanFuseWithTolerance(OCCTShapeRef _Nonnull s1,
                                                    OCCTShapeRef _Nonnull s2,
                                                    double fuzzyTol);

/// Cut s2 from s1 with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanCutWithTolerance(OCCTShapeRef _Nonnull s1,
                                                   OCCTShapeRef _Nonnull s2,
                                                   double fuzzyTol);

/// Common of two shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanCommonWithTolerance(OCCTShapeRef _Nonnull s1,
                                                      OCCTShapeRef _Nonnull s2,
                                                      double fuzzyTol);

/// Fuse two shapes with glue mode (0=shift, 1=full, 2=none).
OCCTShapeRef _Nullable OCCTBooleanFuseGlue(OCCTShapeRef _Nonnull s1,
                                           OCCTShapeRef _Nonnull s2,
                                           int32_t glueMode);

/// Cut with glue mode.
OCCTShapeRef _Nullable OCCTBooleanCutGlue(OCCTShapeRef _Nonnull s1,
                                          OCCTShapeRef _Nonnull s2,
                                          int32_t glueMode);

/// Common with glue mode.
OCCTShapeRef _Nullable OCCTBooleanCommonGlue(OCCTShapeRef _Nonnull s1,
                                             OCCTShapeRef _Nonnull s2,
                                             int32_t glueMode);

// --- BRepOffsetAPI_MakeOffset expansion ---

/// Offset a wire on a plane. joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTOffsetWireOnPlane(OCCTShapeRef _Nonnull wire,
                                             double  distance,
                                             int32_t joinType);

/// Offset a face. joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTOffsetFace(OCCTShapeRef _Nonnull face,
                                      double  distance,
                                      int32_t joinType);

// --- BRepOffsetAPI_MakeThickSolid expansion ---

/// Create thick solid with tolerance and join type control.
/// joinType: 0=Arc, 1=Tangent, 2=Intersection.
OCCTShapeRef _Nullable OCCTThickSolidWithOptions(
  OCCTShapeRef _Nonnull shape,
  OCCTShapeRef _Nonnull const* _Nonnull facesToRemove,
  int32_t faceCount,
  double  offset,
  double  tolerance,
  int32_t joinType);

// --- BRepBuilderAPI_Transform expansion ---

/// Apply a general gp_Trsf (12 doubles: 3x3 rotation matrix + 3 translation).
/// matrix12 = [r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]
OCCTShapeRef _Nullable OCCTShapeTransformed(OCCTShapeRef _Nonnull shape,
                                            const double* _Nonnull matrix12);

/// Apply a gp_GTrsf (non-uniform scaling). matrix12 = 3x4 affine matrix row-major.
OCCTShapeRef _Nullable OCCTShapeGTransformed(OCCTShapeRef _Nonnull shape,
                                             const double* _Nonnull matrix12);

// --- BRepAlgoAPI expansion ---

/// Boolean section (intersection curves) with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanSectionWithTolerance(OCCTShapeRef _Nonnull s1,
                                                       OCCTShapeRef _Nonnull s2,
                                                       double fuzzyTol);

/// Split shape by multiple tool shapes with fuzzy tolerance.
OCCTShapeRef _Nullable OCCTBooleanSplitMulti(OCCTShapeRef _Nonnull shape,
                                             const OCCTShapeRef _Nonnull* _Nonnull tools,
                                             int32_t toolCount,
                                             double  fuzzyTol);

/// Boolean cut with history tracking. Returns result and sets hasDeleted/hasModified/hasGenerated.
OCCTShapeRef _Nullable OCCTBooleanCutWithHistory(OCCTShapeRef _Nonnull s1,
                                                 OCCTShapeRef _Nonnull s2,
                                                 double fuzzyTol,
                                                 bool* _Nonnull hasDeleted,
                                                 bool* _Nonnull hasModified,
                                                 bool* _Nonnull hasGenerated);

/// Create a ThruSections builder.
OCCTThruSectionsRef _Nonnull OCCTThruSectionsCreate(bool isSolid, bool isRuled, double pres3d);

/// Release a ThruSections builder.
void OCCTThruSectionsRelease(OCCTThruSectionsRef _Nonnull ts);

/// Add a wire profile to the ThruSections builder.
void OCCTThruSectionsAddWire(OCCTThruSectionsRef _Nonnull ts, OCCTShapeRef _Nonnull wire);

/// Add a vertex (point) as a degenerate section.
void OCCTThruSectionsAddVertex(OCCTThruSectionsRef _Nonnull ts, OCCTShapeRef _Nonnull vertex);

/// Enable/disable smoothing (default: true for non-ruled). Invalidates the cached "built"
/// result until the next successful OCCTThruSectionsBuild — see its own doc comment.
void OCCTThruSectionsSetSmoothing(OCCTThruSectionsRef _Nonnull ts, bool smoothing);

/// Set maximum BSpline degree. Invalidates the cached "built" result — see OCCTThruSectionsBuild.
void OCCTThruSectionsSetMaxDegree(OCCTThruSectionsRef _Nonnull ts, int32_t maxDeg);

/// Set continuity: parametric continuity — see "Continuity vocabularies" at the top of this
/// header. Before #490 only 0 and 1 were read; everything else meant C2. Invalidates the cached
/// "built" result — see OCCTThruSectionsBuild.
void OCCTThruSectionsSetContinuity(OCCTThruSectionsRef _Nonnull ts, int32_t continuity);

/// Build the ThruSections shape. Returns true if successful. OCCTThruSectionsShape and
/// OCCTThruSectionsGeneratedFace both answer nil unless this has succeeded since the most recent
/// AddWire/AddVertex/Set*/CheckCompatibility call on this instance — every one of those
/// invalidates the previous build's result, since none of OCCT's own internal state resets
/// itself on a reused builder (#910).
bool OCCTThruSectionsBuild(OCCTThruSectionsRef _Nonnull ts);

/// Get the result shape from the ThruSections builder — see OCCTThruSectionsBuild's doc comment
/// for when this is nil.
OCCTShapeRef _Nullable OCCTThruSectionsShape(OCCTThruSectionsRef _Nonnull ts);

// MARK: - BRepAlgoAPI_Defeaturing (v0.118.0)

/// Remove faces (features) from a solid shape, addressing the faces as shapes.
/// Fails (NULL) on an empty request or a null face, rather than removing a subset of what was
/// asked for. The index-addressed form is OCCTShapeRemoveFeatures; for the same operation with
/// history see OCCTShapeHistoryFromDefeature. All of them share one skeleton — see the
/// defeaturing block in OCCTBridge_Internal.h. #497
OCCTShapeRef _Nullable OCCTShapeDefeature(OCCTShapeRef _Nonnull shape,
                                          const OCCTShapeRef _Nonnull* _Nonnull faces,
                                          int32_t faceCount);

// MARK: - Sewing extras (v0.118.0)

/// Get number of multiple edges from sewing operation.
int32_t OCCTSewingNbMultipleEdges(OCCTSewingRef _Nonnull sewing);

/// Check if edge is a multiple edge (shared by >2 faces) after sewing.
bool OCCTSewingIsMultipleEdge(OCCTSewingRef _Nonnull sewing,
                              int32_t index,
                              OCCTShapeRef _Nullable* _Nonnull outEdge);

/// Create a fillet builder on a shape.
OCCTFilletBuilderRef _Nullable OCCTFilletBuilderCreate(OCCTShapeRef _Nonnull shape);

/// Release a fillet builder.
void OCCTFilletBuilderRelease(OCCTFilletBuilderRef _Nonnull builder);

/// Add an edge with constant radius.
bool OCCTFilletBuilderAddEdge(OCCTFilletBuilderRef _Nonnull builder,
                              OCCTEdgeRef _Nonnull edge,
                              double radius);

/// Add an edge with evolving radius (r1 at start, r2 at end).
bool OCCTFilletBuilderAddEdgeEvolving(OCCTFilletBuilderRef _Nonnull builder,
                                      OCCTEdgeRef _Nonnull edge,
                                      double r1,
                                      double r2);

/// Build the filleted result.
OCCTShapeRef _Nullable OCCTFilletBuilderBuild(OCCTFilletBuilderRef _Nonnull builder);

/// Number of contours.
int32_t OCCTFilletBuilderNbContours(OCCTFilletBuilderRef _Nonnull builder);

/// Number of edges in a contour (1-based index).
int32_t OCCTFilletBuilderNbEdges(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether the builder has a result (may be partial).
bool OCCTFilletBuilderHasResult(OCCTFilletBuilderRef _Nonnull builder);

/// Get the shape that caused failure (if any).
OCCTShapeRef _Nullable OCCTFilletBuilderBadShape(OCCTFilletBuilderRef _Nonnull builder);

/// Number of faulty contours.
int32_t OCCTFilletBuilderNbFaultyContours(OCCTFilletBuilderRef _Nonnull builder);

/// Number of faulty vertices.
int32_t OCCTFilletBuilderNbFaultyVertices(OCCTFilletBuilderRef _Nonnull builder);

/// Get radius of a contour (1-based index).
double OCCTFilletBuilderGetRadius(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get length of a contour (1-based index).
double OCCTFilletBuilderGetLength(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether a contour has constant radius (1-based index).
bool OCCTFilletBuilderIsConstant(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Remove an edge from its contour.
bool OCCTFilletBuilderRemoveEdge(OCCTFilletBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Reset all contours.
void OCCTFilletBuilderReset(OCCTFilletBuilderRef _Nonnull builder);

/// Create a chamfer builder on a shape.
OCCTChamferBuilderRef _Nullable OCCTChamferBuilderCreate(OCCTShapeRef _Nonnull shape);

/// Release a chamfer builder.
void OCCTChamferBuilderRelease(OCCTChamferBuilderRef _Nonnull builder);

/// Add an edge with symmetric distance.
bool OCCTChamferBuilderAddEdge(OCCTChamferBuilderRef _Nonnull builder,
                               OCCTEdgeRef _Nonnull edge,
                               double dist);

/// Add an edge with two distances (requires face for orientation).
bool OCCTChamferBuilderAddEdgeTwoDists(OCCTChamferBuilderRef _Nonnull builder,
                                       OCCTEdgeRef _Nonnull edge,
                                       OCCTFaceRef _Nonnull face,
                                       double d1,
                                       double d2);

/// Add an edge with distance and angle (requires face for orientation).
bool OCCTChamferBuilderAddEdgeDistAngle(OCCTChamferBuilderRef _Nonnull builder,
                                        OCCTEdgeRef _Nonnull edge,
                                        OCCTFaceRef _Nonnull face,
                                        double dist,
                                        double angle);

/// Build the chamfered result.
OCCTShapeRef _Nullable OCCTChamferBuilderBuild(OCCTChamferBuilderRef _Nonnull builder);

/// Number of contours.
int32_t OCCTChamferBuilderNbContours(OCCTChamferBuilderRef _Nonnull builder);

/// Whether a contour uses distance-angle mode (1-based index).
bool OCCTChamferBuilderIsDistAngle(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

// --- ChamferBuilder completions (v0.124.0) ---

/// Number of edges in a contour (1-based index).
int32_t OCCTChamferBuilderNbEdges(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the symmetric distance for contour IC (1-based).
void OCCTChamferBuilderGetDist(OCCTChamferBuilderRef _Nonnull builder,
                               int32_t contourIndex,
                               double* _Nonnull dist);

/// Get the two distances for contour IC (1-based).
void OCCTChamferBuilderGetDists(OCCTChamferBuilderRef _Nonnull builder,
                                int32_t contourIndex,
                                double* _Nonnull d1,
                                double* _Nonnull d2);

/// Get distance and angle for contour IC (1-based).
void OCCTChamferBuilderGetDistAngle(OCCTChamferBuilderRef _Nonnull builder,
                                    int32_t contourIndex,
                                    double* _Nonnull dist,
                                    double* _Nonnull angle);

/// Set symmetric distance on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDist(OCCTChamferBuilderRef _Nonnull builder,
                               double  dist,
                               int32_t contourIndex,
                               OCCTFaceRef _Nonnull face);

/// Set two distances on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDists(OCCTChamferBuilderRef _Nonnull builder,
                                double  d1,
                                double  d2,
                                int32_t contourIndex,
                                OCCTFaceRef _Nonnull face);

/// Set distance and angle on a contour (requires face for orientation).
bool OCCTChamferBuilderSetDistAngle(OCCTChamferBuilderRef _Nonnull builder,
                                    double  dist,
                                    double  angle,
                                    int32_t contourIndex,
                                    OCCTFaceRef _Nonnull face);

/// Length of contour IC (1-based).
double OCCTChamferBuilderLength(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Remove the contour containing the given edge.
bool OCCTChamferBuilderRemoveEdge(OCCTChamferBuilderRef _Nonnull builder,
                                  OCCTEdgeRef _Nonnull edge);

/// Reset all contours, canceling effects of Build.
void OCCTChamferBuilderReset(OCCTChamferBuilderRef _Nonnull builder);

/// Whether contour IC (1-based) is closed.
bool OCCTChamferBuilderClosed(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC (1-based) is closed and tangent at closure.
bool OCCTChamferBuilderClosedAndTangent(OCCTChamferBuilderRef _Nonnull builder,
                                        int32_t contourIndex);

/// Whether contour IC is symmetric.
bool OCCTChamferBuilderIsSymmetric(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC uses two distances.
bool OCCTChamferBuilderIsTwoDists(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get edge J in contour I (both 1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderEdge(OCCTChamferBuilderRef _Nonnull builder,
                                              int32_t contourIndex,
                                              int32_t edgeIndex);

/// Get first vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderFirstVertex(OCCTChamferBuilderRef _Nonnull builder,
                                                     int32_t contourIndex);

/// Get last vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTChamferBuilderLastVertex(OCCTChamferBuilderRef _Nonnull builder,
                                                    int32_t contourIndex);

/// Get the contour index containing the given edge (0 if not found).
int32_t OCCTChamferBuilderContour(OCCTChamferBuilderRef _Nonnull builder,
                                  OCCTEdgeRef _Nonnull edge);

/// Curvilinear abscissa of vertex on contour IC (1-based).
double OCCTChamferBuilderAbscissa(OCCTChamferBuilderRef _Nonnull builder,
                                  int32_t contourIndex,
                                  OCCTShapeRef _Nonnull vertex);

/// Relative abscissa (0..1) of vertex on contour IC (1-based).
double OCCTChamferBuilderRelativeAbscissa(OCCTChamferBuilderRef _Nonnull builder,
                                          int32_t contourIndex,
                                          OCCTShapeRef _Nonnull vertex);

// --- FilletBuilder completions (v0.124.0) ---

/// Set radius on a specific edge in a contour (1-based indices).
bool OCCTFilletBuilderSetRadiusOnEdge(OCCTFilletBuilderRef _Nonnull builder,
                                      double  radius,
                                      int32_t contourIndex,
                                      OCCTEdgeRef _Nonnull edge);

/// Set radius at a specific vertex in a contour (1-based index).
bool OCCTFilletBuilderSetRadiusAtVertex(OCCTFilletBuilderRef _Nonnull builder,
                                        double  radius,
                                        int32_t contourIndex,
                                        OCCTShapeRef _Nonnull vertex);

/// Set two radii (evolving) on a contour edge (1-based indices).
bool OCCTFilletBuilderSetTwoRadii(OCCTFilletBuilderRef _Nonnull builder,
                                  double  r1,
                                  double  r2,
                                  int32_t contourIndex,
                                  int32_t edgeInContour);

/// Get contour index for an edge (0 if not found, 1-based otherwise).
int32_t OCCTFilletBuilderContour(OCCTFilletBuilderRef _Nonnull builder, OCCTEdgeRef _Nonnull edge);

/// Get edge J in contour I (both 1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderEdge(OCCTFilletBuilderRef _Nonnull builder,
                                             int32_t contourIndex,
                                             int32_t edgeIndex);

/// First vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderFirstVertex(OCCTFilletBuilderRef _Nonnull builder,
                                                    int32_t contourIndex);

/// Last vertex of contour IC (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderLastVertex(OCCTFilletBuilderRef _Nonnull builder,
                                                   int32_t contourIndex);

/// Curvilinear abscissa of vertex on contour IC (1-based).
double OCCTFilletBuilderAbscissa(OCCTFilletBuilderRef _Nonnull builder,
                                 int32_t contourIndex,
                                 OCCTShapeRef _Nonnull vertex);

/// Relative abscissa (0..1) of vertex on contour IC (1-based).
double OCCTFilletBuilderRelativeAbscissa(OCCTFilletBuilderRef _Nonnull builder,
                                         int32_t contourIndex,
                                         OCCTShapeRef _Nonnull vertex);

/// Whether contour IC (1-based) is closed and tangent.
bool OCCTFilletBuilderClosedAndTangent(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Whether contour IC (1-based) is closed.
bool OCCTFilletBuilderClosed(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Number of surfaces after build.
int32_t OCCTFilletBuilderNbSurfaces(OCCTFilletBuilderRef _Nonnull builder);

/// Number of computed surfaces for contour IC (1-based).
int32_t OCCTFilletBuilderNbComputedSurfaces(OCCTFilletBuilderRef _Nonnull builder,
                                            int32_t contourIndex);

/// Error status for contour IC (1-based). Returns ChFiDS_ErrorStatus as int.
int32_t OCCTFilletBuilderStripeStatus(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the faulty contour index for the I-th fault (1-based).
int32_t OCCTFilletBuilderFaultyContour(OCCTFilletBuilderRef _Nonnull builder, int32_t faultIndex);

/// Get the faulty vertex for the I-th fault (1-based).
OCCTShapeRef _Nullable OCCTFilletBuilderFaultyVertex(OCCTFilletBuilderRef _Nonnull builder,
                                                     int32_t faultIndex);

// --- History extended ---

/// Merge another history into this one.
void OCCTHistoryMerge(OCCTHistoryRef history, OCCTHistoryRef other);

/// Replace a generated entry.
void OCCTHistoryReplaceGenerated(OCCTHistoryRef history,
                                 OCCTShapeRef   initial,
                                 OCCTShapeRef   generated);

/// Replace a modified entry.
void OCCTHistoryReplaceModified(OCCTHistoryRef history,
                                OCCTShapeRef   initial,
                                OCCTShapeRef   modified);

/// Get the list of shapes that the initial shape was modified to.
/// Writes up to maxCount shape refs into outShapes, returns actual count.
int32_t OCCTHistoryGetModifiedShapes(OCCTHistoryRef history,
                                     OCCTShapeRef   initial,
                                     OCCTShapeRef _Nullable* _Nonnull outShapes,
                                     int32_t maxCount);

/// Get the list of shapes generated from the initial shape.
int32_t OCCTHistoryGetGeneratedShapes(OCCTHistoryRef history,
                                      OCCTShapeRef   initial,
                                      OCCTShapeRef _Nullable* _Nonnull outShapes,
                                      int32_t maxCount);

// --- Sewing extended ---

/// Get the number of deleted faces after sewing.
int32_t OCCTSewingNbDeletedFaces(OCCTSewingRef _Nonnull sewing);

/// Get a deleted face by index (1-based).
OCCTShapeRef _Nullable OCCTSewingDeletedFace(OCCTSewingRef _Nonnull sewing, int32_t index);

/// Check if a sub-shape was modified by sewing.
bool OCCTSewingIsModified(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Get the modified version of a shape. Returns NULL if not modified.
OCCTShapeRef _Nullable OCCTSewingModified(OCCTSewingRef _Nonnull sewing,
                                          OCCTShapeRef _Nonnull shape);

/// Check if a shape is degenerated.
bool OCCTSewingIsDegenerated(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Check if an edge is a section bound.
bool OCCTSewingIsSectionBound(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull edge);

/// Get the face that contains the given edge (after sewing).
OCCTShapeRef _Nullable OCCTSewingWhichFace(OCCTSewingRef _Nonnull sewing,
                                           OCCTShapeRef _Nonnull edge);

/// Load the base shape context for sewing.
void OCCTSewingLoad(OCCTSewingRef _Nonnull sewing, OCCTShapeRef _Nonnull shape);

/// Set non-manifold mode for sewing.
void OCCTSewingSetNonManifoldMode(OCCTSewingRef _Nonnull sewing, bool nonManifold);

/// Set face mode for sewing (controls face analysis).
void OCCTSewingSetFaceMode(OCCTSewingRef _Nonnull sewing, bool faceMode);

/// Set floating edges mode for sewing.
void OCCTSewingSetFloatingEdgesMode(OCCTSewingRef _Nonnull sewing, bool floatingEdges);

/// Set minimum tolerance for sewing.
void OCCTSewingSetMinTolerance(OCCTSewingRef _Nonnull sewing, double minTol);

/// Set maximum tolerance for sewing.
void OCCTSewingSetMaxTolerance(OCCTSewingRef _Nonnull sewing, double maxTol);

// MARK: - v0.123.0: Builder extensions, Section ops, Curve/Surface queries

// --- ThruSections extensions ---

/// Enable/disable wire compatibility checking. Invalidates the cached "built" result — see
/// OCCTThruSectionsBuild.
void OCCTThruSectionsCheckCompatibility(OCCTThruSectionsRef _Nonnull ts, bool check);

/// Set parameterization type (0=ChordLength, 1=Centripetal, 2=IsoParametric). Invalidates the
/// cached "built" result — see OCCTThruSectionsBuild.
void OCCTThruSectionsSetParType(OCCTThruSectionsRef _Nonnull ts, int32_t parType);

/// Set criterium weights for the approximation. Invalidates the cached "built" result — see
/// OCCTThruSectionsBuild. Returns true if all weights are non-negative (valid); returns false
/// and does not call OCCT if any weight is negative (OCCT silently ignores negative weights
/// and Build() erases the failure status, making it unobservable otherwise).
bool OCCTThruSectionsSetCriteriumWeight(OCCTThruSectionsRef _Nonnull ts,
                                        double w1,
                                        double w2,
                                        double w3);

/// Get the face generated from a profile edge. Null if not found, if the last build did not
/// succeed (see OCCTThruSectionsBuild), or if the found face is not part of the current build's
/// own Shape() — a stale binding from an earlier build that a later reconciliation never
/// overwrote in OCCT's own edge->face map (#910 review round 2).
OCCTShapeRef _Nullable OCCTThruSectionsGeneratedFace(OCCTThruSectionsRef _Nonnull ts,
                                                     OCCTShapeRef _Nonnull edge);

// --- CellsBuilder extensions ---

/// Add cells to result selectively: take shapes present in theLSToTake, avoid shapes in
/// theLSToAvoid.
void OCCTCellsBuilderAddToResultSelective(OCCTCellsBuilderRef _Nonnull builder,
                                          const OCCTShapeRef _Nonnull* _Nonnull takeShapes,
                                          int32_t takeCount,
                                          const OCCTShapeRef _Nonnull* _Nonnull avoidShapes,
                                          int32_t avoidCount,
                                          int32_t material,
                                          bool    update);

/// Remove cells from result selectively: remove shapes in take but not in avoid.
void OCCTCellsBuilderRemoveFromResult(OCCTCellsBuilderRef _Nonnull builder,
                                      const OCCTShapeRef _Nonnull* _Nonnull takeShapes,
                                      int32_t takeCount,
                                      const OCCTShapeRef _Nonnull* _Nonnull avoidShapes,
                                      int32_t avoidCount);

/// Get all split parts (before any result composition).
OCCTShapeRef _Nullable OCCTCellsBuilderGetAllParts(OCCTCellsBuilderRef _Nonnull builder);

/// Make containers (wires from edges, shells from faces, etc.).
void OCCTCellsBuilderMakeContainers(OCCTCellsBuilderRef _Nonnull builder);

// --- PipeShell extensions ---

/// Get the pipe shell build status (0=Ok, 1=NotOk, 2=PlaneNotIntersectGuide, 3=ImpossibleContact).
int32_t OCCTPipeShellGetStatus(OCCTPipeShellRef _Nonnull ps);

/// Simulate the pipe shell with a given number of sections.
/// Returns an array of simulated section shapes and their count.
OCCTShapeRef _Nullable* _Nullable OCCTPipeShellSimulate(OCCTPipeShellRef _Nonnull ps,
                                                        int32_t numSections,
                                                        int32_t* _Nonnull outCount);

/// Free an array of shapes returned by OCCTPipeShellSimulate.
void OCCTPipeShellSimulateFree(OCCTShapeRef _Nullable* _Nullable shapes, int32_t count);

/// Enable or disable build history tracking. Disabled by default to avoid
/// segfault on closed spine+profile geometries (OCCT bug in BuildHistory).
void OCCTPipeShellSetBuildHistory(OCCTPipeShellRef _Nonnull ps, bool enabled);

/// Create a UnifySameDomain builder.
///
/// The builder unifies a private COPY of `shape` — the algorithm rewrites its input, and those
/// rewrites used to reach the caller's shape (#446). `OCCTUnifySameDomainKeepShape` takes the
/// CALLER's sub-shapes and maps them onto the copy.
///
/// NOTE: despite the `_Nonnull` annotation this can return null — on a construction failure (which
/// predates #446) and now also if the input cannot be copied. Every accessor below tolerates a null
/// builder, and `OCCTUnifySameDomainRelease` accepts one, so a null degrades to "does nothing,
/// answers null" rather than crashing. The annotation is kept for source compatibility: correcting
/// it to `_Nullable` would make the Swift `UnifySameDomainBuilder.init` failable, which is a
/// breaking API change for a path no caller can hit with a valid shape.
OCCTUnifySameDomainRef _Nonnull OCCTUnifySameDomainCreate(OCCTShapeRef _Nonnull shape,
                                                          bool unifyEdges,
                                                          bool unifyFaces,
                                                          bool concatBSplines);

/// Release a UnifySameDomain builder.
void OCCTUnifySameDomainRelease(OCCTUnifySameDomainRef _Nonnull usd);

/// Allow or disallow internal edges in unification.
void OCCTUnifySameDomainAllowInternalEdges(OCCTUnifySameDomainRef _Nonnull usd, bool allow);

/// Keep a specific shape from being unified.
void OCCTUnifySameDomainKeepShape(OCCTUnifySameDomainRef _Nonnull usd, OCCTShapeRef _Nonnull shape);

/// Set safe input mode (copies input shape).
void OCCTUnifySameDomainSetSafeInputMode(OCCTUnifySameDomainRef _Nonnull usd, bool safe);

/// Set linear tolerance for unification.
void OCCTUnifySameDomainSetLinearTolerance(OCCTUnifySameDomainRef _Nonnull usd, double tol);

/// Set angular tolerance for unification.
void OCCTUnifySameDomainSetAngularTolerance(OCCTUnifySameDomainRef _Nonnull usd, double tol);

/// Build (perform unification).
void OCCTUnifySameDomainBuild(OCCTUnifySameDomainRef _Nonnull usd);

/// Get the unified result shape.
OCCTShapeRef _Nullable OCCTUnifySameDomainShape(OCCTUnifySameDomainRef _Nonnull usd);

// --- BRepAlgoAPI_Section extended ---

/// Compute section between two shapes with approximation and pcurve options.
/// Returns the section shape.
OCCTShapeRef _Nullable OCCTShapeSectionWithOptions(OCCTShapeRef _Nonnull shape1,
                                                   OCCTShapeRef _Nonnull shape2,
                                                   bool approximation,
                                                   bool computePCurve1,
                                                   bool computePCurve2);

/// Check if an edge of the section has an ancestor face on shape1.
/// Returns the ancestor face, or NULL.
OCCTShapeRef _Nullable OCCTSectionAncestorFaceOn1(OCCTShapeRef _Nonnull shape1,
                                                  OCCTShapeRef _Nonnull shape2,
                                                  OCCTShapeRef _Nonnull edge,
                                                  bool approximation,
                                                  bool computePCurve1,
                                                  bool computePCurve2);

/// Check if an edge of the section has an ancestor face on shape2.
OCCTShapeRef _Nullable OCCTSectionAncestorFaceOn2(OCCTShapeRef _Nonnull shape1,
                                                  OCCTShapeRef _Nonnull shape2,
                                                  OCCTShapeRef _Nonnull edge,
                                                  bool approximation,
                                                  bool computePCurve1,
                                                  bool computePCurve2);

// --- FilletBuilder completions ---

/// Set fillet tolerances: tang, tesp, t2d, tApp3d, tApp2d, fleche.
void OCCTFilletBuilderSetParams(OCCTFilletBuilderRef _Nonnull builder,
                                double tang,
                                double tesp,
                                double t2d,
                                double tApp3d,
                                double tApp2d,
                                double fleche);

/// Set fillet continuity: internalContinuity (0=C0, 1=C1, 2=C2), angularTolerance.
void OCCTFilletBuilderSetContinuity(OCCTFilletBuilderRef _Nonnull builder,
                                    int32_t internalContinuity,
                                    double  angularTolerance);

/// Set fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
void OCCTFilletBuilderSetFilletShape(OCCTFilletBuilderRef _Nonnull builder, int32_t filletShape);

/// Get fillet shape type: 0=Rational, 1=QuasiAngular, 2=Polynomial.
int32_t OCCTFilletBuilderGetFilletShape(OCCTFilletBuilderRef _Nonnull builder);

/// Reset a specific contour's radius info.
void OCCTFilletBuilderResetContour(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Simulate filleting on contour IC (computes sections without building).
void OCCTFilletBuilderSimulate(OCCTFilletBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the number of simulated surfaces for contour IC.
int32_t OCCTFilletBuilderNbSimulatedSurf(OCCTFilletBuilderRef _Nonnull builder,
                                         int32_t contourIndex);

// --- XCAFDoc_ShapeTool completions ---

/// Check if a label is a free shape (top-level, not referenced by other shapes).
bool OCCTDocumentShapeToolIsFree(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a simple shape (not assembly, not compound).
bool OCCTDocumentShapeToolIsSimpleShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a component (reference to another shape).
bool OCCTDocumentShapeToolIsComponent(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a compound shape.
bool OCCTDocumentShapeToolIsCompound(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is a sub-shape.
bool OCCTDocumentShapeToolIsSubShape(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Check if a label is an external reference.
bool OCCTDocumentShapeToolIsExternRef(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of users (references) of a shape label.
int32_t OCCTDocumentShapeToolGetUsers(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Compute shapes (update internal state) for a label.
void OCCTDocumentShapeToolComputeShapes(OCCTDocumentRef _Nonnull doc, int64_t labelId);

/// Get the number of components of a label.
int32_t OCCTDocumentShapeToolNbComponents(OCCTDocumentRef _Nonnull doc,
                                          int64_t labelId,
                                          bool    getSubChildren);

// MARK: - v0.127.0: Section ops, BSpline/Bezier completions, BRep_Tool, ColorTool, FilletBuilder
// history

// --- BRepAlgoAPI_Section with plane ---

/// Compute section of a shape with a plane (ax + by + cz + d = 0).
/// @param normalX,normalY,normalZ Plane normal direction
/// @param originX,originY,originZ A point on the plane
OCCTShapeRef _Nullable OCCTShapeSectionWithPlane(OCCTShapeRef _Nonnull shape,
                                                 double normalX,
                                                 double normalY,
                                                 double normalZ,
                                                 double originX,
                                                 double originY,
                                                 double originZ);

/// Compute section of a shape with a surface.
OCCTShapeRef _Nullable OCCTShapeSectionWithSurface(OCCTShapeRef _Nonnull shape,
                                                   OCCTSurfaceRef _Nonnull surface);

// --- FilletBuilder radius laws, keyed by contour edge ---
//
// These three take an OCCTEdgeRef because the OCCT functions behind them take a const TopoDS_Edge&,
// and all three resolve that edge the same way. They reject a contour index outside
// [1, NbContours()] and an edge the named contour does not hold, which OCCT does not; see
// occtFilletContourHoldsEdge in OCCTBridge_Internal.h for what happens without that (#505).
//
// The three below them (Generated/Modified/IsDeleted) take an OCCTShapeRef because their OCCT
// counterparts take a const TopoDS_Shape&: any sub-shape of the input can be asked about, not just
// an edge.

/// Get the parameter bounds of the radius law on a contour edge. Returns false in four cases:
/// contourIndex outside [1, NbContours()], an edge the contour does not hold, a contour whose spine
/// has not been split yet (before Build or Simulate), or a constant radius, which OCCT represents
/// as no law rather than a flat one.
bool OCCTFilletBuilderGetBounds(OCCTFilletBuilderRef _Nonnull builder,
                                int32_t contourIndex,
                                OCCTEdgeRef _Nonnull edge,
                                double* _Nonnull outFirst,
                                double* _Nonnull outLast);

/// Get the radius law on a contour edge. Returns NULL in the same four cases as GetBounds.
OCCTLawFunctionRef _Nullable OCCTFilletBuilderGetLaw(OCCTFilletBuilderRef _Nonnull builder,
                                                     int32_t contourIndex,
                                                     OCCTEdgeRef _Nonnull edge);

/// Set the radius law on a contour edge. Returns false in the same four cases as GetBounds.
bool OCCTFilletBuilderSetLaw(OCCTFilletBuilderRef _Nonnull builder,
                             int32_t contourIndex,
                             OCCTEdgeRef _Nonnull edge,
                             OCCTLawFunctionRef _Nonnull law);

/// Get shapes generated from an input shape by the fillet operation.
/// Returns array of shape refs. Caller must free the array (not the shapes) with free().
int32_t OCCTFilletBuilderGenerated(OCCTFilletBuilderRef _Nonnull builder,
                                   OCCTShapeRef _Nonnull shape,
                                   OCCTShapeRef _Nullable* _Nullable* _Nonnull outShapes);

/// Get shapes modified from an input shape by the fillet operation.
/// Returns array of shape refs. Caller must free the array (not the shapes) with free().
int32_t OCCTFilletBuilderModified(OCCTFilletBuilderRef _Nonnull builder,
                                  OCCTShapeRef _Nonnull shape,
                                  OCCTShapeRef _Nullable* _Nullable* _Nonnull outShapes);

/// Check if a shape was deleted by the fillet operation.
bool OCCTFilletBuilderIsDeleted(OCCTFilletBuilderRef _Nonnull builder, OCCTShapeRef _Nonnull shape);

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface
// Transform

// --- ChamferBuilder history & extras ---

/// Get shapes generated from an input shape by the chamfer operation.
/// Returns count. Caller must free the array (not the shapes) with free().
int32_t OCCTChamferBuilderGenerated(OCCTChamferBuilderRef _Nonnull builder,
                                    OCCTShapeRef _Nonnull shape,
                                    OCCTShapeRef _Nullable* _Nullable* _Nonnull outShapes);

/// Get shapes modified from an input shape by the chamfer operation.
/// Returns count. Caller must free the array (not the shapes) with free().
int32_t OCCTChamferBuilderModified(OCCTChamferBuilderRef _Nonnull builder,
                                   OCCTShapeRef _Nonnull shape,
                                   OCCTShapeRef _Nullable* _Nullable* _Nonnull outShapes);

/// Check if a shape was deleted by the chamfer operation.
bool OCCTChamferBuilderIsDeleted(OCCTChamferBuilderRef _Nonnull builder,
                                 OCCTShapeRef _Nonnull shape);

/// Set the chamfer mode: 0=ClassicChamfer, 1=ConstThroatChamfer,
/// 2=ConstThroatWithPenetrationChamfer.
void OCCTChamferBuilderSetMode(OCCTChamferBuilderRef _Nonnull builder, int32_t mode);

/// Simulate the chamfer on a contour (1-based) to prepare surface data.
bool OCCTChamferBuilderSimulate(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Get the number of simulated surfaces for a contour (1-based). Call after Simulate.
int32_t OCCTChamferBuilderNbSurf(OCCTChamferBuilderRef _Nonnull builder, int32_t contourIndex);

/// Create a section builder with default initialization.
OCCTSectionBuilderRef _Nullable OCCTSectionBuilderCreate(void);

/// Create a section builder from two shapes.
OCCTSectionBuilderRef _Nullable OCCTSectionBuilderCreateFromShapes(OCCTShapeRef _Nonnull shape1,
                                                                   OCCTShapeRef _Nonnull shape2);

/// Release a section builder.
void OCCTSectionBuilderRelease(OCCTSectionBuilderRef _Nonnull builder);

/// Set the first argument as a shape.
void OCCTSectionBuilderInit1Shape(OCCTSectionBuilderRef _Nonnull builder,
                                  OCCTShapeRef _Nonnull shape);

/// Set the first argument as a plane (ax + by + cz + d = 0).
void OCCTSectionBuilderInit1Plane(OCCTSectionBuilderRef _Nonnull builder,
                                  double a,
                                  double b,
                                  double c,
                                  double d);

/// Set the first argument as a surface.
void OCCTSectionBuilderInit1Surface(OCCTSectionBuilderRef _Nonnull builder,
                                    OCCTSurfaceRef _Nonnull surface);

/// Set the second argument as a shape.
void OCCTSectionBuilderInit2Shape(OCCTSectionBuilderRef _Nonnull builder,
                                  OCCTShapeRef _Nonnull shape);

/// Set the second argument as a plane (ax + by + cz + d = 0).
void OCCTSectionBuilderInit2Plane(OCCTSectionBuilderRef _Nonnull builder,
                                  double a,
                                  double b,
                                  double c,
                                  double d);

/// Set the second argument as a surface.
void OCCTSectionBuilderInit2Surface(OCCTSectionBuilderRef _Nonnull builder,
                                    OCCTSurfaceRef _Nonnull surface);

/// Toggle curve approximation (default: false).
void OCCTSectionBuilderSetApproximation(OCCTSectionBuilderRef _Nonnull builder, bool approx);

/// Toggle computation of PCurves on first shape.
void OCCTSectionBuilderComputePCurveOn1(OCCTSectionBuilderRef _Nonnull builder, bool compute);

/// Toggle computation of PCurves on second shape.
void OCCTSectionBuilderComputePCurveOn2(OCCTSectionBuilderRef _Nonnull builder, bool compute);

/// Build the section. Returns the result shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTSectionBuilderBuild(OCCTSectionBuilderRef _Nonnull builder);

/// Check if an edge has an ancestor face on the first shape. Returns the face, or NULL.
OCCTShapeRef _Nullable OCCTSectionBuilderAncestorFaceOn1(OCCTSectionBuilderRef _Nonnull builder,
                                                         OCCTShapeRef _Nonnull edge);

/// Check if an edge has an ancestor face on the second shape. Returns the face, or NULL.
OCCTShapeRef _Nullable OCCTSectionBuilderAncestorFaceOn2(OCCTSectionBuilderRef _Nonnull builder,
                                                         OCCTShapeRef _Nonnull edge);

#endif /* OCCTBridge_Modeling_h */
