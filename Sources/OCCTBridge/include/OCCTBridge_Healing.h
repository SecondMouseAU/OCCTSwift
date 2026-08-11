//
//  OCCTBridge_Healing.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Healing domain.
//  Split from OCCTBridge.h (#395); see that file for the shared preamble
//  (opaque handle typedefs, nullability pragma, OCCT class cross-reference index).
//

#ifndef OCCTBridge_Healing_h
#define OCCTBridge_Healing_h


// MARK: - Validation

bool OCCTShapeIsValid(OCCTShapeRef shape);
OCCTShapeRef OCCTShapeHeal(OCCTShapeRef shape);

// MARK: - Shape Healing & Analysis (v0.13.0)

/// Shape analysis result structure
typedef struct {
    int32_t smallEdgeCount;        // Number of edges smaller than tolerance
    int32_t smallFaceCount;        // Number of faces smaller than tolerance
    int32_t gapCount;              // Number of gaps between edges/faces
    // selfIntersectionCount REMOVED (#726/#763): it was always 0, never computed ("would require
    // more expensive computation", the field's own former comment) -- see OCCTShapeSelfIntersects /
    // OCCTShapeSelfIntersectsBounded for the real answer (#702 documented the field as honest about
    // never being computed; #763 removed it, since a field that can never carry information has no
    // reason to exist).
    int32_t freeEdgeCount;         // Number of free (unconnected) edges, summed across every
                                    // shell of `shape`, via ShapeAnalysis_Shell::CheckOrientedShells
                                    // (#702: this was hardcoded 0 before, since LoadShells() alone
                                    // runs no edge analysis)
    int32_t freeFaceCount;         // Number of shells found to have at least one free edge above
                                    // (i.e. not fully closed); same #702 fix
    bool hasInvalidTopology;       // Whether topology is invalid
    bool isValid;                  // Whether analysis succeeded
} OCCTShapeAnalysisResult;

/// Analyze a shape for problems
/// @param shape The shape to analyze
/// @param tolerance Tolerance for small feature detection
/// @return Analysis result with problem counts
OCCTShapeAnalysisResult OCCTShapeAnalyze(OCCTShapeRef shape, double tolerance);

/// Fix a wire (close gaps, remove degenerate edges, reorder)
/// @param wire The wire to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed wire, or NULL on failure
OCCTWireRef OCCTWireFix(OCCTWireRef wire, double tolerance);

/// Fix a face (wire orientation, missing seams, surface parameters)
/// @param face The face to fix
/// @param tolerance Tolerance for fixing operations
/// @return Fixed face as a shape, or NULL on failure
OCCTShapeRef OCCTFaceFix(OCCTFaceRef face, double tolerance);

/// Fix a shape with detailed control
/// @param shape The shape to fix
/// @param tolerance Tolerance for fixing operations
/// @param fixSolid Whether to fix solid orientation (ShapeFix_Shape::FixSolidMode)
/// @param fixShell Whether to fix FREE shells -- not attached to a solid (ShapeFix_Shape::FixFreeShellMode)
/// @param fixFace Whether to fix FREE faces -- not attached to a shell (ShapeFix_Shape::FixFreeFaceMode)
/// @param fixWire Whether to fix FREE wires -- not attached to a face (ShapeFix_Shape::FixFreeWireMode)
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixDetailed(OCCTShapeRef shape, double tolerance,
                                   bool fixSolid, bool fixShell,
                                   bool fixFace, bool fixWire);

/// Unify faces and edges lying on the same geometry
/// @param shape The shape to simplify
/// @param unifyEdges Whether to unify edges on same curve
/// @param unifyFaces Whether to unify faces on same surface
/// @param concatBSplines Whether to concatenate adjacent B-splines
/// @return Unified shape, or NULL on failure
OCCTShapeRef OCCTShapeUnifySameDomain(OCCTShapeRef shape,
                                       bool unifyEdges, bool unifyFaces,
                                       bool concatBSplines);

/// Remove faces smaller than an area threshold, by defeaturing (BRepAlgoAPI_Defeaturing).
/// Picks the faces itself rather than taking a list, but is otherwise the same operation as
/// OCCTShapeRemoveFeatures / OCCTShapeDefeature. (It removes faces, not "internal wires (holes)"
/// as this comment claimed before #497.)
/// @param shape The shape to clean
/// @param minArea Minimum face area to keep
/// @return Cleaned shape — the input unchanged when no face is below the threshold — or NULL on
///         failure
OCCTShapeRef OCCTShapeRemoveSmallFaces(OCCTShapeRef shape, double minArea);

/// Simplify shape by removing small features
/// @param shape The shape to simplify
/// @param tolerance Size threshold for small features
/// @return Simplified shape, or NULL on failure
OCCTShapeRef OCCTShapeSimplify(OCCTShapeRef shape, double tolerance);

// MARK: - Advanced Blends & Surface Filling (v0.14.0)

/// Apply variable radius fillet to a specific edge
///
/// One of the two radius-law entry points, with OCCTShapeFilletEvolving: both resolve their edges
/// through occtFilletAddEdges and apply their profile through occtFilletSetRadiusProfile
/// (OCCTBridge_Internal.h), which is where the profile contract is documented and enforced. #520
/// @param shape The shape to fillet
/// @param edgeIndex Index of the edge to fillet (0-based; an index naming no edge of `shape`
///   rejects the call)
/// @param radii Array of radius values along the edge; every element must be > 0
/// @param params Array of relative parameters where those radii apply; each must lie in [0, 1] and
///   they must strictly increase
/// @param count Number of radius/parameter pairs; at least 2
/// @return Filleted shape, or NULL on failure
OCCTShapeRef OCCTShapeFilletVariable(OCCTShapeRef shape, int32_t edgeIndex,
                                      const double* radii, const double* params, int32_t count);

/// Apply 2D fillet to a wire at a specific vertex
/// @param wire The wire to fillet
/// @param vertexIndex Index of the vertex to fillet
/// @param radius Fillet radius
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFillet2D(OCCTWireRef wire, int32_t vertexIndex, double radius);

/// Apply 2D fillet to all vertices of a wire
/// @param wire The wire to fillet
/// @param radius Fillet radius for all corners
/// @return Filleted wire, or NULL on failure
OCCTWireRef OCCTWireFilletAll2D(OCCTWireRef wire, double radius);

/// Apply 2D chamfer to a wire at a specific vertex
/// @param wire The wire to chamfer
/// @param vertexIndex Index of the vertex to chamfer
/// @param dist1 First chamfer distance
/// @param dist2 Second chamfer distance
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamfer2D(OCCTWireRef wire, int32_t vertexIndex, double dist1, double dist2);

/// Apply 2D chamfer to all vertices of a wire
/// @param wire The wire to chamfer
/// @param distance Chamfer distance for all corners
/// @return Chamfered wire, or NULL on failure
OCCTWireRef OCCTWireChamferAll2D(OCCTWireRef wire, double distance);

/// Blend multiple edges with individual radii
///
/// The per-edge member of the occtShapeFilletEdgeList family (OCCTBridge_Internal.h), alongside
/// OCCTShapeFilletEdges and OCCTShapeFilletEdgesLinear. Implemented in OCCTBridge_Healing.mm
/// while the other two are in OCCTBridge_Modeling.mm, which is how it came to be the one without
/// a radius precondition. #489
///
/// #633: `declinedEdgeIndices`/`outDeclinedCount` report which of `edgeIndices` OCCT declined,
/// same contract #639 gave OCCTShapeFilletEdges/OCCTShapeFilletEdgesLinear/OCCTShapeFilletEvolving.
/// Both are nullable and the existing skip behaviour is unchanged when they are null;
/// `blendedEdges(_:)` passes null for both, `blendedEdgesWithReport(_:)` does not. The *other* axis
/// this function's caller has to report -- the same edge index named twice, which silently
/// overwrites one radius with another at the shared fillet slot -- needs no OCCT round trip at all,
/// since it is a property of `edgeIndices` itself; it is computed Swift-side.
/// @param shape The shape to blend
/// @param edgeIndices Array of edge indices (0-based; an index naming no edge of `shape` rejects
///   the whole call, #520)
/// @param radii Array of radii (one per edge); every element must be > 0, or the whole call fails
/// @param count Number of edges
/// @param declinedEdgeIndices Optional (may be NULL): buffer of at least `count` int32s to receive
///   the 0-based indices of requested edges OCCT declined to fillet, in `edgeIndices`' own order.
///   Same contract as OCCTShapeFilletEdges.
/// @param outDeclinedCount Optional (may be NULL): same contract as OCCTShapeFilletEdges.
/// @return Blended shape, or NULL on failure
OCCTShapeRef OCCTShapeBlendEdges(OCCTShapeRef shape,
                                  const int32_t* edgeIndices, const double* radii, int32_t count,
                                  int32_t* declinedEdgeIndices, int32_t* outDeclinedCount);

/// Parameters for surface filling operation
///
/// `continuity` is the plate constraint ORDER, not a GeomAbs_Shape ordinal:
/// 0 = position only, 1 = position + tangency, 2 = position + tangency + curvature.
/// BRepFill_Filling passes the GeomAbs_Shape value straight through to
/// GeomPlate_CurveConstraint/BRepFill_CurveConstraint as that integer order, and both
/// reject anything outside [-1, 2] — so curvature continuity is GeomAbs_C1 (ordinal 2),
/// and GeomAbs_G2 (ordinal 3) always throws despite what the OCCT header docs claim.
/// See OCCTFillingContinuityToGeomAbs in OCCTBridge_Healing.mm. (#430)
typedef struct {
    int32_t continuity;   // 0=position, 1=tangency, 2=curvature
    double tolerance;     // Surface tolerance
    int32_t maxDegree;    // Maximum surface degree (default 8)
    int32_t maxSegments;  // Maximum segments (default 9)
} OCCTFillingParams;

/// Fill an N-sided boundary with a surface
///
/// Tangency/curvature continuity needs a support surface to be continuous WITH. Each
/// boundary edge's own pcurve support surface is used, so continuity > 0 requires every
/// boundary edge to carry a pcurve (i.e. to have been borrowed from an existing face);
/// a free-standing edge with no pcurve makes the whole call fail. Use
/// OCCTShapeFillWithSupport or OCCTShapeFillConstraints to nominate support faces
/// explicitly.
///
/// @param boundaries Array of boundary wires
/// @param wireCount Number of boundary wires
/// @param params Filling parameters
/// @return Filled face, or NULL on failure
OCCTShapeRef OCCTShapeFill(const OCCTWireRef* boundaries, int32_t wireCount,
                            OCCTFillingParams params);

/// Fill an N-sided boundary, taking tangency/curvature from a surrounding shape
///
/// For each boundary edge, the support face is the edge's own ancestor face in
/// `support` — the "cap this opening, continuous with the walls around it" case. A
/// boundary edge with no ancestor face in `support` falls back to its own pcurve
/// surface, and failing that is added with position-only continuity.
///
/// @param boundaries Array of boundary wires
/// @param wireCount Number of boundary wires
/// @param support Shape whose faces supply the tangency/curvature reference
/// @param params Filling parameters
/// @return Filled face, or NULL on failure
OCCTShapeRef OCCTShapeFillWithSupport(const OCCTWireRef* boundaries, int32_t wireCount,
                                       OCCTShapeRef support, OCCTFillingParams params);

/// One edge constraint for OCCTShapeFillConstraints
typedef struct {
    OCCTEdgeRef edge;      // Constrained edge (required)
    OCCTFaceRef support;   // Face to be continuous with, or NULL to derive one
    int32_t continuity;    // 0=position, 1=tangency, 2=curvature
    int32_t isBound;       // 1 = bounds the resulting face, 0 = internal constraint
} OCCTFillConstraint;

/// Fill a surface from explicit per-edge constraints
///
/// The precise form: every edge names its own support face and continuity order, and
/// may be a boundary or an internal constraint. `params.continuity` is ignored.
///
/// @param constraints Array of edge constraints
/// @param count Number of constraints
/// @param params Filling parameters (continuity field unused)
/// @return Filled face, or NULL on failure
OCCTShapeRef OCCTShapeFillConstraints(const OCCTFillConstraint* constraints, int32_t count,
                                       OCCTFillingParams params);

/// Create a surface constrained to pass through points
/// @param points Array of points [x,y,z triplets]
/// @param pointCount Number of points
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlatePoints(const double* points, int32_t pointCount, double tolerance);

/// Create a surface constrained by curves
/// @param curves Array of constraint curves
/// @param curveCount Number of curves
/// @param continuity Desired continuity (0=C0, 1=G1, 2=G2)
/// @param tolerance Surface tolerance
/// @return Surface face, or NULL on failure
OCCTShapeRef OCCTShapePlateCurves(const OCCTWireRef* curves, int32_t curveCount,
                                   int32_t continuity, double tolerance);

// MARK: - Advanced Healing (v0.17.0)

/// Divide a shape wherever its geometry drops below the required continuity.
///
/// The sole entry point behind `Shape.divided(at:tolerance:)` since #438 folded in
/// `OCCTShapeUpgradeDivideContinuity`, the narrower bridge function that used to sit behind the
/// now-deprecated `Shape.dividedByContinuity(criterion:tolerance:)`.
/// @param shape Shape to divide
/// @param continuity Target continuity (0=C0, 1=C1, 2=C2, 3=C3, 4=CN, 5=G1, 6=G2)
/// @param tolerance Tolerance for the continuity check
/// @return Divided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivide(OCCTShapeRef shape, int32_t continuity, double tolerance);

/// Convert geometry to direct faces (canonical surfaces)
OCCTShapeRef OCCTShapeDirectFaces(OCCTShapeRef shape);

/// Scale shape geometry
OCCTShapeRef OCCTShapeScaleGeometry(OCCTShapeRef shape, double factor);

/// Convert BSpline surfaces to their closest analytical form
/// (planes, cylinders, cones, spheres, tori)
OCCTShapeRef OCCTShapeBSplineRestriction(OCCTShapeRef shape,
                                          double surfaceTol, double curveTol,
                                          int32_t maxDegree, int32_t maxSegments);

/// Convert swept surfaces to elementary (canonical) surfaces
OCCTShapeRef OCCTShapeSweptToElementary(OCCTShapeRef shape);

/// Convert surfaces of revolution to elementary surfaces
OCCTShapeRef OCCTShapeRevolutionToElementary(OCCTShapeRef shape);

/// Convert all surfaces to BSpline
OCCTShapeRef OCCTShapeConvertToBSpline(OCCTShapeRef shape);

/// Sew a single shape (reconnect disconnected faces)
OCCTShapeRef OCCTShapeSewSingle(OCCTShapeRef shape, double tolerance);

/// Upgrade shape: sew + make solid + heal (pipeline). One solid per body-bounding shell of
/// the sewn result, so multi-body input stays multi-body (#443).
OCCTShapeRef OCCTShapeUpgrade(OCCTShapeRef shape, double tolerance);

// MARK: - NURBS Conversion (v0.29.0)

/// Convert all geometry in a shape to NURBS representation.
/// @param shape The shape to convert
/// @return NURBS shape, or NULL on failure
OCCTShapeRef OCCTShapeConvertToNURBS(OCCTShapeRef shape);

// MARK: - Fast Sewing (v0.29.0)

/// Sew faces using the fast sewing algorithm (less robust but faster).
/// @param shape The shape to sew
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef OCCTShapeFastSewn(OCCTShapeRef shape, double tolerance);

// MARK: - Shape Fix Wireframe (v0.30.0)

/// Fix wireframe issues (small edges, wire gaps) in a shape.
/// @param shape The shape to fix
/// @param tolerance Precision for fixing
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixWireframe(OCCTShapeRef shape, double tolerance);

// MARK: - Remove Internal Wires (v0.30.0)

/// Remove internal wires (holes) below a minimum area from a shape.
/// @param shape The shape to process
/// @param minArea Minimum area threshold; wires enclosing less area are removed
/// @return Shape with internal wires removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveInternalWires(OCCTShapeRef shape, double minArea);

// MARK: - Fix Small Faces (v0.31.0)

/// Fix small faces in a shape by removing or merging them.
/// @param shape The shape to fix
/// @param tolerance Precision tolerance for identifying small faces
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixSmallFaces(OCCTShapeRef shape, double tolerance);

// MARK: - Remove Locations (v0.31.0)

/// Remove all locations (transformations) from a shape, baking them into geometry.
/// @param shape The shape to process
/// @return Shape with locations removed, or NULL on failure
OCCTShapeRef OCCTShapeRemoveLocations(OCCTShapeRef shape);

// MARK: - Split Shape by Angle (v0.34.0)

/// Split surfaces that span more than a specified angle.
/// Useful for export to systems that cannot handle full 360° surfaces.
/// @param shape The shape to split
/// @param maxAngleDegrees Maximum angle in degrees (e.g. 90 = quarter-turns)
/// @return Shape with split surfaces, or NULL on failure
OCCTShapeRef OCCTShapeSplitByAngle(OCCTShapeRef shape, double maxAngleDegrees);

// MARK: - Drop Small Edges (v0.34.0)

/// Remove degenerate/tiny edges from a shape.
/// @param shape The shape to clean
/// @param tolerance Tolerance for identifying small edges
/// @return Shape with small edges removed, or NULL on failure
OCCTShapeRef OCCTShapeDropSmallEdges(OCCTShapeRef shape, double tolerance);

// MARK: - Same Parameter (v0.35.0)

/// Enforce same-parameter consistency on a shape.
/// Ensures 3D and 2D curve representations are consistent.
/// @param shape The shape to fix
/// @param tolerance Tolerance for same-parameter check
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeSameParameter(OCCTShapeRef shape, double tolerance);

// MARK: - Encode Regularity (v0.36.0)

/// Mark smooth (G1) edges as "regular" so downstream algorithms can skip them.
/// @param shape The shape to process
/// @param toleranceAngleDegrees Angular tolerance for smoothness (degrees)
/// @return Shape with regularity encoded, or NULL on failure
OCCTShapeRef OCCTShapeEncodeRegularity(OCCTShapeRef shape, double toleranceAngleDegrees);

// MARK: - Update Tolerances (v0.36.0)

/// Recalculate and update geometric tolerances on a shape.
/// @param shape The shape to update
/// @param verifyFaceTolerance Whether to verify and correct face tolerances
/// @return Shape with updated tolerances, or NULL on failure
OCCTShapeRef OCCTShapeUpdateTolerances(OCCTShapeRef shape, bool verifyFaceTolerance);

// MARK: - Shape Divide by Number (v0.36.0)

/// Split faces of a shape into a specified number of patches in U and V.
/// @param shape The shape to divide
/// @param nbU Number of segments in U direction
/// @param nbV Number of segments in V direction
/// @return Shape with divided faces, or NULL on failure
OCCTShapeRef OCCTShapeDivideByNumber(OCCTShapeRef shape, int32_t nbU, int32_t nbV);

/// Compute free boundary wires on a shape (open edges not shared by two faces).
/// Returns a compound of wire shapes representing the free boundaries.
/// @param shape The shape to analyze
/// @param sewingTolerance Tolerance for grouping free edges into wires
/// @param outClosedCount Number of closed free boundary wires (output)
/// @param outOpenCount Number of open free boundary wires (output)
/// @return Compound of free boundary wires, or NULL if none found
OCCTShapeRef OCCTShapeFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                  int32_t* outClosedCount, int32_t* outOpenCount);

/// Fix free boundary wires by closing gaps.
/// @param shape The shape whose free boundaries to fix
/// @param sewingTolerance Tolerance for sewing free edges
/// @param closingTolerance Maximum distance to close a gap
/// @param outFixedCount Number of wires that were fixed (output)
/// @return Fixed shape, or NULL on failure
OCCTShapeRef OCCTShapeFixFreeBounds(OCCTShapeRef shape, double sewingTolerance,
                                     double closingTolerance, int32_t* outFixedCount);

/// Split closed (periodic) edges in a shape
/// @param shape Shape containing closed edges
/// @param nbSplitPoints Number of split points per closed edge (default 1)
/// @return Modified shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideClosedEdges(OCCTShapeRef shape, int32_t nbSplitPoints);

/// Convert all surfaces in a shape to BSpline form
/// @param shape Shape to convert
/// @param extrusion Convert extrusion surfaces
/// @param revolution Convert revolution surfaces
/// @param offset Convert offset surfaces
/// @param plane Convert planar surfaces
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeCustomConvertToBSpline(OCCTShapeRef shape,
                                              bool extrusion, bool revolution,
                                              bool offset, bool plane);

/// Convert surfaces in a shape to revolution form
/// @param shape Shape to convert
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeCustomConvertToRevolution(OCCTShapeRef shape);

/// Build restricted faces from a surface and wire boundaries
/// @param faceShape Face providing the underlying surface
/// @param wires Array of wire handles for boundaries
/// @param wireCount Number of wires
/// @param outFaces Pre-allocated array for result faces
/// @param maxFaces Maximum faces to return
/// @return Number of faces created, or -1 on failure
int32_t OCCTShapeFaceRestrict(OCCTShapeRef faceShape,
                               OCCTWireRef* wires, int32_t wireCount,
                               OCCTShapeRef* outFaces, int32_t maxFaces);

// MARK: - v0.43.0: Face Subdivision, Small Face Detection, BSpline Fill, Location Purge

/// Subdivide faces of a shape whose area exceeds a maximum threshold
/// @param shape Input shape
/// @param maxArea Maximum face area (faces larger than this get split)
/// @return Subdivided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideByArea(OCCTShapeRef shape, double maxArea);

/// Subdivide faces into a target number of parts per face
/// @param shape Input shape
/// @param nbParts Target number of parts per face
/// @return Subdivided shape, or NULL on failure
OCCTShapeRef OCCTShapeDivideByParts(OCCTShapeRef shape, int32_t nbParts);

/// Small face analysis result for a single face
typedef struct {
    bool isSpotFace;      // Face collapsed to a point
    bool isStripFace;     // Face has negligible width
    bool isTwisted;       // Face is twisted
    double spotX, spotY, spotZ;   // Spot face location (if isSpotFace)
} OCCTSmallFaceResult;

/// Check a shape's faces for small/degenerate conditions
/// @param shape Shape to analyze
/// @param tolerance Analysis tolerance
/// @param outResults Array to receive per-face results
/// @param maxResults Maximum number of results
/// @return Number of degenerate faces found (results written to outResults)
int32_t OCCTShapeCheckSmallFaces(OCCTShapeRef shape, double tolerance,
                                  OCCTSmallFaceResult* outResults, int32_t maxResults);

/// Purge problematic location datums from a shape
/// Removes negative-scale and non-unit-scale transforms from sub-shapes
/// @param shape Input shape
/// @return Purged shape, or NULL if nothing to purge
OCCTShapeRef OCCTShapePurgeLocations(OCCTShapeRef shape);

/// Connect edges by merging shared vertices in a shape
/// @param shape Shape to process
/// @return Shape with connected edges, or NULL on failure
OCCTShapeRef OCCTShapeConnectEdges(OCCTShapeRef shape);

/// Convert all curves and surfaces in a shape to Bezier representations
/// @param shape Input shape
/// @return Converted shape, or NULL on failure
OCCTShapeRef OCCTShapeConvertToBezier(OCCTShapeRef shape);

// --- ShapeAnalysis_WireOrder ---

/// Wire ordering result entry
typedef struct {
    int32_t originalIndex;  ///< Original edge index (1-based, negative if reversed)
} OCCTWireOrderEntry;

/// Result of wire ordering analysis
typedef struct {
    int32_t status;         ///< 0=closed, 1=open, 2=gaps, -1=failed
    int32_t nbEdges;        ///< Number of edges in the order
} OCCTWireOrderResult;

/// Analyze the ordering of edges to form connected chains.
/// Edges are specified by their start/end 3D points.
/// @param starts Array of start points (x,y,z triples)
/// @param ends Array of end points (x,y,z triples)
/// @param nbEdges Number of edges
/// @param tolerance Connection tolerance
/// @param outOrder Output array for ordered edge indices (must hold nbEdges entries)
/// @return Wire order result (status and count)
OCCTWireOrderResult OCCTWireOrderAnalyze(const double* starts, const double* ends,
                                          int32_t nbEdges, double tolerance,
                                          OCCTWireOrderEntry* outOrder);

/// Analyze the ordering of edges from a wire shape.
/// @param wire Wire to analyze
/// @param tolerance Connection tolerance
/// @param outOrder Output array for ordered edge indices (must hold enough entries)
/// @param maxEntries Maximum entries in outOrder
/// @return Wire order result
OCCTWireOrderResult OCCTWireOrderAnalyzeWire(OCCTWireRef wire, double tolerance,
                                              OCCTWireOrderEntry* outOrder, int32_t maxEntries);

// --- BRepCheck: Shape validity checking ---

/// Shape validity status codes (maps to BRepCheck_Status)
typedef enum {
    OCCTCheckNoError = 0,
    OCCTCheckInvalidPointOnCurve = 1,
    OCCTCheckInvalidPointOnCurveOnSurface = 2,
    OCCTCheckInvalidPointOnSurface = 3,
    OCCTCheckNo3DCurve = 4,
    OCCTCheckMultiple3DCurve = 5,
    OCCTCheckInvalid3DCurve = 6,
    OCCTCheckNoCurveOnSurface = 7,
    OCCTCheckInvalidCurveOnSurface = 8,
    OCCTCheckInvalidCurveOnClosedSurface = 9,
    OCCTCheckInvalidSameRangeFlag = 10,
    OCCTCheckInvalidSameParameterFlag = 11,
    OCCTCheckInvalidDegeneratedFlag = 12,
    OCCTCheckFreeEdge = 13,
    OCCTCheckInvalidMultiConnexity = 14,
    OCCTCheckInvalidRange = 15,
    OCCTCheckEmptyWire = 16,
    OCCTCheckRedundantEdge = 17,
    OCCTCheckSelfIntersectingWire = 18,
    OCCTCheckNoSurface = 19,
    OCCTCheckInvalidWire = 20,
    OCCTCheckRedundantWire = 21,
    OCCTCheckIntersectingWires = 22,
    OCCTCheckInvalidImbricationOfWires = 23,
    OCCTCheckEmptyShell = 24,
    OCCTCheckRedundantFace = 25,
    OCCTCheckInvalidImbricationOfShells = 26,
    OCCTCheckUnorientableShape = 27,
    OCCTCheckNotClosed = 28,
    OCCTCheckNotConnected = 29,
    OCCTCheckSubshapeNotInShape = 30,
    OCCTCheckBadOrientation = 31,
    OCCTCheckBadOrientationOfSubshape = 32,
    OCCTCheckInvalidPolygonOnTriangulation = 33,
    OCCTCheckInvalidToleranceValue = 34,
    OCCTCheckEnclosedRegion = 35,
    OCCTCheckCheckFail = 36
} OCCTCheckStatus;

/// Result of shape validity check
typedef struct {
    bool isValid;           ///< True if no errors found
    int32_t errorCount;     ///< Number of errors
    OCCTCheckStatus firstError;  ///< First error code (if any)
} OCCTShapeCheckResult;

/// Check validity of a face.
/// @param face Face to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckFace(OCCTFaceRef face);

/// BRepCheck_Face per-check diagnostics — the specific BRepCheck_Status for one wire-topology check
/// of a face. `geometricControls` toggles the (more expensive) geometric intersection checks.
/// Returns OCCTCheckCheckFail if `face` is not a face. #266 follow-up.
OCCTCheckStatus OCCTBRepCheckFaceIntersectWires(OCCTShapeRef face, bool geometricControls);
OCCTCheckStatus OCCTBRepCheckFaceClassifyWires(OCCTShapeRef face, bool geometricControls);
OCCTCheckStatus OCCTBRepCheckFaceOrientationOfWires(OCCTShapeRef face, bool geometricControls);

/// Check validity of a solid.
/// @param shape Solid shape to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckSolid(OCCTShapeRef shape);

/// Check overall validity of any shape (comprehensive check).
/// Uses BRepCheck_Analyzer for full topology + geometry validation.
/// @param shape Shape to check
/// @return Check result
OCCTShapeCheckResult OCCTCheckShape(OCCTShapeRef shape);

/// Get detailed check status codes for a shape.
/// @param shape Shape to analyze
/// @param outStatuses Output array of status codes
/// @param maxStatuses Max entries in output
/// @return Number of status entries written
int32_t OCCTCheckShapeDetailed(OCCTShapeRef shape, OCCTCheckStatus* outStatuses, int32_t maxStatuses);

// --- BRepCheck_Analyzer ---

/// Perform comprehensive shape validity analysis.
/// @param shape Shape to analyze
/// @param geometryChecks Whether to include geometry checks
/// @return true if shape is valid
bool OCCTBRepCheckAnalyzerIsValid(OCCTShapeRef shape, bool geometryChecks);

/// Check if a specific sub-shape is valid within its parent shape context.
/// @param parentShape Parent shape for context
/// @param subShapeType TopAbs_ShapeEnum type to check (0=COMPOUND, 1=COMPSOLID, 2=SOLID, 3=SHELL, 4=FACE, 5=WIRE, 6=EDGE, 7=VERTEX)
/// @param subShapeIndex 0-based index of sub-shape of that type
/// @return true if the sub-shape is valid
bool OCCTBRepCheckSubShapeValid(OCCTShapeRef parentShape, int32_t subShapeType, int32_t subShapeIndex);

// --- BRepCheck_Edge / Wire / Shell / Vertex ---

/// Check validity of an edge by index.
/// @param shape Parent shape
/// @param edgeIndex 0-based edge index
/// @return Check result
OCCTShapeCheckResult OCCTCheckEdge(OCCTShapeRef shape, int32_t edgeIndex);

/// Check validity of a wire by index.
/// @param shape Parent shape
/// @param wireIndex 0-based wire index
/// @return Check result
OCCTShapeCheckResult OCCTCheckWire(OCCTShapeRef shape, int32_t wireIndex);

/// Check validity of a shell by index.
/// @param shape Parent shape
/// @param shellIndex 0-based shell index
/// @return Check result
OCCTShapeCheckResult OCCTCheckShell(OCCTShapeRef shape, int32_t shellIndex);

/// Check validity of a vertex by index.
/// @param shape Parent shape
/// @param vertexIndex 0-based vertex index
/// @return Check result
OCCTShapeCheckResult OCCTCheckVertex(OCCTShapeRef shape, int32_t vertexIndex);

// --- ShapeFix_ShapeTolerance ---

/// Limit all tolerances in a shape to a given range.
/// @param shape Shape to modify
/// @param minTolerance Minimum tolerance
/// @param maxTolerance Maximum tolerance
/// @return true if any tolerance was changed
bool OCCTShapeFixLimitTolerance(OCCTShapeRef shape, double minTolerance, double maxTolerance);

/// Set all tolerances in a shape to a specific value.
/// @param shape Shape to modify
/// @param tolerance Tolerance value to set
void OCCTShapeFixSetTolerance(OCCTShapeRef shape, double tolerance);

// --- ShapeFix_SplitCommonVertex ---

/// Split vertices that are shared between edges in incompatible ways.
/// @param shape Shape to fix
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixSplitCommonVertex(OCCTShapeRef shape);

// --- ShapeFix_FaceConnect ---

/// Connect adjacent faces in a shell.
/// @param shape Shell shape to fix
/// @param tolerance Connection tolerance
/// @return Fixed shell shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixFaceConnect(OCCTShapeRef shape, double tolerance);

// --- ShapeFix_Edge ---

/// Fix same-parameter inconsistencies on all edges in a shape.
/// @param shape Shape to fix
/// @param tolerance Tolerance for fixing (0 = default)
/// @return Number of edges fixed
int32_t OCCTShapeFixEdgeSameParameter(OCCTShapeRef shape, double tolerance);

/// Fix vertex tolerance issues on all edges in a shape.
/// @param shape Shape to fix
/// @return Number of edges fixed
int32_t OCCTShapeFixEdgeVertexTolerance(OCCTShapeRef shape);

// --- ShapeFix_WireVertex ---

/// Fix vertex issues in all wires of a shape.
/// @param shape Shape to fix
/// @param precision Precision for fixing
/// @return Number of fixes applied
int32_t OCCTShapeFixWireVertex(OCCTShapeRef shape, double precision);

// --- ShapeUpgrade_ShapeDivideClosed ---

/// Divide closed faces in a shape.
/// @param shape Shape to process
/// @param nbSplitPoints Number of split points per closed face
/// @return Divided shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeDivideClosed(OCCTShapeRef shape, int32_t nbSplitPoints);

// --- ShapeUpgrade_ShapeDivideContinuity: OCCTShapeDivide (above), the sole entry point since
// #438 folded in OCCTShapeUpgradeDivideContinuity, which used to sit behind the now-deprecated
// Shape.dividedByContinuity(criterion:tolerance:).

// --- ShapeFix_FixSmallSolid ---

/// Remove small solids from a shape based on volume threshold.
/// @param shape Shape containing solids
/// @param volumeThreshold Volume below which solids are removed
/// @return Shape with small solids removed, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixRemoveSmallSolids(OCCTShapeRef shape, double volumeThreshold);

/// Merge small solids into adjacent larger solids.
/// @param shape Shape containing solids
/// @param widthFactorThreshold Width factor below which solids are merged
/// @return Shape with small solids merged, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixMergeSmallSolids(OCCTShapeRef shape, double widthFactorThreshold);

// --- ShapeCustom ---

/// Redress indirect (left-handed) surfaces to direct (right-handed).
/// @param shape Shape to process
/// @return Shape with all surfaces made direct, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeCustomDirectFaces(OCCTShapeRef shape);

/// Simplify BSpline surfaces and curves by restricting degree and segment count.
/// @param shape Shape to process
/// @param tol3d 3D tolerance
/// @param tol2d 2D tolerance
/// @param maxDegree Maximum BSpline degree
/// @param maxSegments Maximum number of BSpline segments
/// @param continuity3d 3D continuity (0=C0, 1=C1, 2=C2)
/// @param continuity2d 2D continuity (0=C0, 1=C1, 2=C2)
/// @param degreePriority If true, prioritize degree reduction over segment count
/// @param rational If true, allow rational BSplines
/// @return Simplified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeCustomBSplineRestriction(OCCTShapeRef shape,
    double tol3d, double tol2d, int32_t maxDegree, int32_t maxSegments,
    int32_t continuity3d, int32_t continuity2d, bool degreePriority, bool rational);

/// Result of wire vertex analysis.
typedef struct {
    int32_t nbEdges;    // Number of edges analyzed
    bool isDone;        // True if analysis completed
} OCCTWireVertexResult;

/// Analyze wire vertex connections.
/// @param wire Wire to analyze
/// @param precision Tolerance for vertex analysis
OCCTWireVertexResult OCCTShapeWireVertexAnalysis(OCCTShapeRef wire, double precision);

/// Get the status of a specific vertex in a wire vertex analysis.
/// @param wire Wire that was analyzed
/// @param precision Same precision used in analysis
/// @param vertexIndex 0-based vertex index
/// @return Status code: 0=SameVertex, 1=SameCoords, 2=Close, 3=End, 4=Start, 5=Inters, -1=Disjoined
int32_t OCCTShapeWireVertexStatus(OCCTShapeRef wire, double precision, int32_t vertexIndex);

/// Result of nearest plane fitting.
typedef struct {
    double normalX, normalY, normalZ;  // Plane normal direction
    double originX, originY, originZ;  // Point on the plane
    double maxDeviation;  // Maximum distance from points to plane
    bool success;
} OCCTNearestPlaneResult;

/// Fit the nearest plane to a set of 3D points.
/// @param points Array of point coordinates (x,y,z triples)
/// @param nPoints Number of points
OCCTNearestPlaneResult OCCTShapeNearestPlane(const double* points, int32_t nPoints);

// --- BRepTools_Substitution ---

/// Substitute a sub-shape within a parent shape.
/// @param parentShape The shape to modify
/// @param oldSubShape The sub-shape to replace
/// @param newSubShape The replacement sub-shape
/// @return Modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTBRepToolsSubstitute(OCCTShapeRef parentShape,
    OCCTShapeRef oldSubShape, OCCTShapeRef newSubShape);

// --- ShapeUpgrade_ShellSewing ---

/// Sew disconnected shells in a shape.
/// @param shape Shape containing shells to sew
/// @param tolerance Sewing tolerance
/// @return Sewn shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeShellSewing(OCCTShapeRef shape, double tolerance);

// --- ShapeFix_SplitTool ---

/// Split an edge at a parameter value.
/// @param edge The edge to split
/// @param param Parameter value at which to split
/// @param vertexX,vertexY,vertexZ Position of split vertex
/// @param outEdge1 Output: first half of split edge
/// @param outEdge2 Output: second half of split edge
/// @return true if split succeeded
bool OCCTShapeFixSplitEdge(OCCTEdgeRef edge, double param,
    double vertexX, double vertexY, double vertexZ,
    OCCTEdgeRef _Nullable * _Nonnull outEdge1,
    OCCTEdgeRef _Nullable * _Nonnull outEdge2);

// --- ShapeCustom_DirectModification ---

/// Apply ShapeCustom_DirectModification to orient face normals outward.
OCCTShapeRef _Nullable OCCTShapeCustomDirectModification(OCCTShapeRef shape);

// --- ShapeCustom_TrsfModification ---

/// Apply a transformation as a shape modification with correct tolerance scaling.
/// @param shape Input shape
/// @param sx Scale X (uniform scaling: sx=sy=sz)
/// @param sy Scale Y
/// @param sz Scale Z
OCCTShapeRef _Nullable OCCTShapeCustomTrsfModificationScale(OCCTShapeRef shape, double scaleFactor);

// --- ShapeUpgrade_ClosedFaceDivide ---

/// Divide closed faces (e.g., full cylinders) into multiple faces.
/// @param shape The shape containing closed faces
/// @param nbSplitPoints Number of splitting lines (result = nbSplitPoints+1 faces per closed face)
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeClosedFaceDivide(OCCTShapeRef shape, int32_t nbSplitPoints);

// --- ShapeUpgrade_SplitSurfaceAngle ---

/// Split surfaces of revolution so each segment covers no more than maxAngle degrees.
/// @param shape The shape to process
/// @param maxAngleDegrees Maximum angle per segment in degrees
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceAngle(OCCTShapeRef shape, double maxAngleDegrees);

// --- ShapeUpgrade_SplitSurfaceArea ---

/// Split faces into approximately nbParts equal-area parts.
/// @param shape The shape to process
/// @param nbParts Target number of parts per face
/// @return The modified shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeSplitSurfaceArea(OCCTShapeRef shape, int32_t nbParts);

// --- ShapeAnalysis_TransferParametersProj ---
// Transfer a parameter from edge 3D curve to face 2D representation
double OCCTShapeAnalysisTransferParam(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    double param, bool toFace);

// --- ShapeBuild_Edge ---
/// Copy an edge, optionally sharing PCurves.
OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopy(OCCTShapeRef edgeShape, bool sharePCurves);

/// Copy an edge replacing its vertices.
OCCTShapeRef _Nullable OCCTShapeBuildEdgeCopyReplaceVertices(OCCTShapeRef edgeShape,
    OCCTShapeRef vertex1Shape, OCCTShapeRef vertex2Shape);

/// Set the 3D parameter range on an edge.
void OCCTShapeBuildEdgeSetRange3d(OCCTShapeRef edgeShape, double first, double last);

/// Rebuild the 3D curve of an edge from its PCurves.
/// @return true if successful
bool OCCTShapeBuildEdgeBuildCurve3d(OCCTShapeRef edgeShape);

/// Remove the 3D curve from an edge.
void OCCTShapeBuildEdgeRemoveCurve3d(OCCTShapeRef edgeShape);

/// Copy parameter ranges from one edge to another.
void OCCTShapeBuildEdgeCopyRanges(OCCTShapeRef toEdge, OCCTShapeRef fromEdge);

/// Copy PCurves from one edge to another.
void OCCTShapeBuildEdgeCopyPCurves(OCCTShapeRef toEdge, OCCTShapeRef fromEdge);

/// Remove a PCurve from an edge for a given face.
void OCCTShapeBuildEdgeRemovePCurve(OCCTShapeRef edgeShape, OCCTShapeRef faceShape);

/// Reassign a PCurve from one face to another.
/// @return true if successful
bool OCCTShapeBuildEdgeReassignPCurve(OCCTShapeRef edgeShape, OCCTShapeRef oldFaceShape,
    OCCTShapeRef newFaceShape);

// --- ShapeBuild_Vertex ---
/// Combine two vertices into one at the average position.
/// @param tolFactor Tolerance factor (default 1.0001)
OCCTShapeRef _Nullable OCCTShapeBuildVertexCombine(OCCTShapeRef v1Shape, OCCTShapeRef v2Shape,
    double tolFactor);

/// Combine two points into a vertex.
OCCTShapeRef _Nullable OCCTShapeBuildVertexCombineFromPoints(
    double x1, double y1, double z1, double tol1,
    double x2, double y2, double z2, double tol2,
    double tolFactor);

// --- ShapeExtend_Explorer ---
/// Filter a compound shape, extracting only sub-shapes of the specified type.
/// @param shapeType TopAbs_ShapeEnum value (0=COMPOUND..7=SHAPE)
/// @param explore If true, explore sub-compounds recursively
/// @return Compound containing only shapes of the specified type, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeExtendSortedCompound(OCCTShapeRef shape, int32_t shapeType,
    bool explore);

/// Get the predominant shape type in a compound.
/// @param compound If true, look inside compounds
/// @return TopAbs_ShapeEnum value
int32_t OCCTShapeExtendShapeType(OCCTShapeRef shape, bool compound);

// --- ShapeUpgrade_FaceDivide ---
/// Divide a face using surface segmentation.
/// Uses ShapeUpgrade_FaceDivide with surface segment mode.
/// @param faceShape Input face shape
/// @return Divided shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFaceDivide(OCCTShapeRef faceShape);

// --- ShapeUpgrade_WireDivide ---
/// Divide a wire on a face.
/// @param wireShape Input wire shape
/// @param faceShape Face the wire lies on
/// @return Divided wire as shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeWireDivideOnFace(OCCTShapeRef wireShape, OCCTShapeRef faceShape);

// --- ShapeUpgrade_EdgeDivide ---
/// Analyze an edge for potential division on a face.
/// @param edgeShape Input edge shape
/// @param faceShape Face context
/// @param outHasCurve2d Output: whether edge has 2D curve on face
/// @param outHasCurve3d Output: whether edge has 3D curve
/// @return true if computation succeeded
bool OCCTShapeUpgradeEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape,
    bool* outHasCurve2d, bool* outHasCurve3d);

// --- ShapeUpgrade_ClosedEdgeDivide ---
/// Analyze a closed (seam) edge for division on a face.
/// @return true if the edge is closed and can be divided
bool OCCTShapeUpgradeClosedEdgeDivideCompute(OCCTShapeRef edgeShape, OCCTShapeRef faceShape);

// --- ShapeUpgrade_FixSmallCurves ---
/// Fix small curves in a shape by removing degenerate edges.
/// @param shape Input shape
/// @param tolerance Tolerance for small curve detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallCurves(OCCTShapeRef shape, double tolerance);

// --- ShapeUpgrade_FixSmallBezierCurves ---
/// Fix small Bezier curves in a shape.
/// @param shape Input shape
/// @param tolerance Tolerance for small curve detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeFixSmallBezierCurves(OCCTShapeRef shape, double tolerance);

// --- ShapeUpgrade_ConvertCurve3dToBezier ---
/// Convert 3D curves in a shape to Bezier representation.
/// @param shape Input shape
/// @param lineMode Convert lines to Bezier
/// @param circleMode Convert circles to Bezier
/// @param conicMode Convert conics to Bezier
/// @return Shape with Bezier curves, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeConvertCurves3dToBezier(OCCTShapeRef shape,
    bool lineMode, bool circleMode, bool conicMode);

// --- ShapeUpgrade_ConvertSurfaceToBezierBasis ---
/// Convert surfaces in a shape to Bezier patches.
/// @param shape Input shape
/// @param planeMode Convert planes
/// @param revolutionMode Convert surfaces of revolution
/// @param extrusionMode Convert extrusion surfaces
/// @param bsplineMode Convert BSpline surfaces
/// @return Shape with Bezier surfaces, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeUpgradeConvertSurfaceToBezier(OCCTShapeRef shape,
    bool planeMode, bool revolutionMode, bool extrusionMode, bool bsplineMode);

// MARK: - BRepLib_ValidateEdge

/// Validate edge geometry (3D curve vs curve-on-surface consistency).
typedef struct {
    bool isDone;
    bool isWithinTolerance;  // at default tolerance
    double maxDistance;
    double tolerance;        // tolerance used for check
} OCCTValidateEdgeResult;

/// Validate an edge on a face. Returns validation metrics.
OCCTValidateEdgeResult OCCTValidateEdge(OCCTEdgeRef _Nonnull edge, OCCTFaceRef _Nonnull face, double tolerance);

// MARK: - ShapeCustom_BSplineRestriction (advanced)

/// Restrict BSpline degree and segments with full control over parameters.
/// continuity3d/continuity2d: parametric continuity, same as OCCTShapeCustomBSplineRestriction —
/// both drive a ShapeCustom_BSplineRestriction through BRepTools_Modifier, and before #490 this
/// one read the value as a GeomAbs_Shape ordinal instead. See "Continuity vocabularies" at the
/// top of this header. Above C2 the operation yields a null shape.
/// Returns modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeBSplineRestrictionAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                             bool approxSurface, bool approxCurve3d, bool approxCurve2d,
                                                             double tol3d, double tol2d,
                                                             int continuity3d, int continuity2d,
                                                             int maxDegree, int maxSegments,
                                                             bool priorityDegree, bool convertRational);

// MARK: - ShapeCustom_ConvertToBSpline (advanced)

/// Convert surfaces of a shape to BSpline with per-type control.
/// Returns modified shape, or NULL on failure.
OCCTShapeRef _Nullable OCCTShapeConvertToBSplineAdvanced(OCCTShapeRef _Nonnull shapeRef,
                                                           bool extrusionMode, bool revolutionMode,
                                                           bool offsetMode, bool planeMode);

// MARK: - ShapeUpgrade_SplitSurfaceContinuity

/// Split a surface by continuity criterion.
/// criterion: parametric continuity, same as OCCTSurfaceSplitByContinuity — both wrap
/// ShapeUpgrade_SplitSurfaceContinuity, and before #490 this one read the value as a
/// GeomAbs_Shape ordinal instead. See "Continuity vocabularies" at the top of this header.
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceContinuity(OCCTSurfaceRef _Nonnull surfaceRef,
                                 int criterion, double tolerance,
                                 int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// MARK: - ShapeUpgrade_SplitSurfaceAngle

/// Split a surface by maximum angle (radians).
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceAngle(OCCTSurfaceRef _Nonnull surfaceRef, double maxAngle,
                            int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// MARK: - ShapeUpgrade_SplitSurfaceArea

/// Split a surface into approximately equal-area parts.
/// Returns number of U split values (0 on failure).
int OCCTSplitSurfaceArea(OCCTSurfaceRef _Nonnull surfaceRef, int nbParts, bool intoSquares,
                           int* _Nullable outUSplitCount, int* _Nullable outVSplitCount);

// --- ShapeFix_ComposeShell ---
/// Perform compose shell on a face with composite surface grid
/// Returns the result shape (shell or compound of faces)
OCCTShapeRef _Nullable OCCTShapeFixComposeShell(OCCTShapeRef _Nonnull faceRef, double precision);

// MARK: - ShapeFix_Solid

/// Fix a solid shape (topology and orientation). Heals EVERY solid in the input, not
/// just the first (#442): a single body comes back as a solid, several as a compound of
/// one result per input body. No body is ever dropped, so a result is not always a solid
/// — ShapeFix_Solid returns a SHELL it could not close, and a solid it fails to heal
/// comes back unhealed. Returns NULL only when the input holds no solid.
OCCTShapeRef _Nullable OCCTShapeFixSolid(OCCTShapeRef _Nonnull shape);

/// Create a solid from a shell using ShapeFix_Solid. One solid per body-bounding shell
/// (#442) — within each solid, every shell an even number of the others enclose, plus
/// every free shell; a solid's cavity shells are skipped. A single body comes back as a
/// solid, several as a compound.
OCCTShapeRef _Nullable OCCTShapeSolidFromShell(OCCTShapeRef _Nonnull shellShape);

// MARK: - ShapeFix_EdgeConnect

/// Connect edges in a shape by extending/trimming to match
OCCTShapeRef _Nullable OCCTShapeFixEdgeConnect(OCCTShapeRef _Nonnull shape);

// MARK: - ShapeAnalysis_Shell

/// Result struct for shell analysis
typedef struct {
    bool hasOrientationProblems;
    bool hasFreeEdges;
    bool hasBadEdges;
    bool hasConnectedEdges;
    int freeEdgeCount;
} OCCTShellAnalysisResult;

/// Analyze shell orientation and edge connectivity
OCCTShellAnalysisResult OCCTShapeAnalyzeShell(OCCTShapeRef _Nonnull shape);

// MARK: - ShapeAnalysis_CanonicalRecognition (detailed)

/// Canonical geometry types for detailed recognition
typedef enum {
    OCCTCanonicalTypeNone = 0,
    OCCTCanonicalTypePlane = 1,
    OCCTCanonicalTypeCylinder = 2,
    OCCTCanonicalTypeCone = 3,
    OCCTCanonicalTypeSphere = 4,
    OCCTCanonicalTypeLine = 5,
    OCCTCanonicalTypeCircle = 6,
    OCCTCanonicalTypeEllipse = 7
} OCCTCanonicalType;

/// Result struct for detailed canonical recognition with geometry parameters
typedef struct {
    OCCTCanonicalType type;
    double gap;
    double originX, originY, originZ;
    double dirX, dirY, dirZ;
    double param1, param2;
} OCCTCanonicalResult;

/// Recognize canonical surface geometry with detailed parameters (plane/cylinder/cone/sphere)
OCCTCanonicalResult OCCTShapeRecognizeCanonicalSurface(OCCTShapeRef _Nonnull faceShape, double tolerance);

/// Recognize canonical curve geometry with detailed parameters (line/circle/ellipse)
OCCTCanonicalResult OCCTShapeRecognizeCanonicalCurve(OCCTShapeRef _Nonnull edgeShape, double tolerance);

// MARK: - ShapeFix_EdgeProjAux (v0.93.0)

/// Project edge endpoints onto face pcurve.
/// @param outFirst Output first parameter
/// @param outLast Output last parameter
/// @return true if both projections done
bool OCCTShapeFixEdgeProjAux(OCCTShapeRef _Nonnull shape, int32_t faceIndex, int32_t edgeIndex,
                              double precision,
                              double* _Nonnull outFirst, double* _Nonnull outLast);

// MARK: - BRepAlgo_FaceRestrictor (v0.93.0)

/// Restrict a face to its wires using BRepAlgo_FaceRestrictor and return result face count.
/// @return Number of result faces, or -1 on error
int32_t OCCTShapeFaceRestrictAlgo(OCCTShapeRef _Nonnull shape, int32_t faceIndex,
                                    OCCTShapeRef _Nullable * _Nullable outFaces, int32_t maxFaces);

// MARK: - ShapeFix_IntersectionTool (v0.95.0)

/// Fix intersecting wires on a face of a shape.
/// @return true if any fixes were applied
bool OCCTShapeFixIntersectingWires(OCCTShapeRef _Nonnull shape, int32_t faceIndex, double precision);

// MARK: - ShapeFix_Wireframe Extensions (v0.99.0)

/// Fix only wire gaps in a shape (no small-edge removal).
/// @param shape The shape to fix
/// @param tolerance Precision for gap detection
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixWireGaps(OCCTShapeRef _Nonnull shape, double tolerance);

/// Fix only small edges in a shape (no gap repair).
/// @param shape The shape to fix
/// @param tolerance Precision for small-edge detection
/// @param dropSmall If true, drop small edges; if false, merge them
/// @param limitAngle Maximum angle between tangents for merging (radians); use -1 for no limit
/// @return Fixed shape, or NULL on failure
OCCTShapeRef _Nullable OCCTShapeFixSmallEdges(OCCTShapeRef _Nonnull shape, double tolerance,
                                               bool dropSmall, double limitAngle);

// --- ShapeAnalysis_FreeBounds simplified API ---

/// Get the number of closed free-boundary wires in a shape.
int32_t OCCTShapeFreeBoundsClosedCount(OCCTShapeRef _Nonnull shape, double tolerance);

/// Get the compound of closed free-boundary wires.
OCCTShapeRef _Nullable OCCTShapeFreeBoundsClosed(OCCTShapeRef _Nonnull shape, double tolerance);

/// Get the compound of open free-boundary wires.
OCCTShapeRef _Nullable OCCTShapeFreeBoundsOpen(OCCTShapeRef _Nonnull shape, double tolerance);

// MARK: - ShapeAnalysis_Wire (v0.106.0)

/// Check wire edge ordering. Returns true if problem found.
bool OCCTWireCheckOrder(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check wire connectivity. Returns true if problem found.
bool OCCTWireCheckConnected(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for small edges. Returns true if problem found.
bool OCCTWireCheckSmall(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for degenerated edges. Returns true if problem found.
bool OCCTWireCheckDegenerated(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check wire closure. Returns true if problem found.
bool OCCTWireCheckClosed(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for self-intersection. Returns true if problem found.
bool OCCTWireCheckSelfIntersection(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for 3D gaps. Returns true if problem found.
bool OCCTWireCheckGaps3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for 2D gaps. Returns true if problem found.
bool OCCTWireCheckGaps2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check edge curves consistency. Returns true if problem found.
bool OCCTWireCheckEdgeCurves(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check for lacking edges. Returns true if problem found.
bool OCCTWireCheckLacking(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the number of edges in a wire on a face.
int32_t OCCTWireEdgeCount(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the minimum 3D distance gap in a wire.
double OCCTWireMinDistance3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the maximum 3D distance gap in a wire.
double OCCTWireMaxDistance3d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the minimum 2D distance gap in a wire.
double OCCTWireMinDistance2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Get the maximum 2D distance gap in a wire.
double OCCTWireMaxDistance2d(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec);

/// Check connectivity of a specific edge by index (1-based).
bool OCCTWireCheckConnectedEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a specific edge is small (1-based).
bool OCCTWireCheckSmallEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a specific edge is degenerated (1-based).
bool OCCTWireCheckDegeneratedEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check 3D gap at a specific edge (1-based).
bool OCCTWireCheckGap3dEdge(OCCTShapeRef _Nonnull wire, OCCTShapeRef _Nonnull face, double prec, int32_t edgeIndex);

/// Check if a face has an outer bound wire.
bool OCCTWireCheckOuterBound(OCCTShapeRef _Nonnull face, double prec);

// MARK: - ShapeAnalysis_Edge (v0.106.0)

/// Check if an edge has a 3D curve.
bool OCCTEdgeHasCurve3dSA(OCCTShapeRef _Nonnull edge);

/// Check if an edge is closed in 3D.
bool OCCTEdgeIsClosed3dSA(OCCTShapeRef _Nonnull edge);

/// Check if an edge has a PCurve on a face.
bool OCCTEdgeHasPCurveSA(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Check if an edge is a seam edge on a face.
bool OCCTEdgeIsSeamSA(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Check same parameter consistency. maxdev returns the maximum deviation.
bool OCCTEdgeCheckSameParameter(OCCTShapeRef _Nonnull edge, double* _Nonnull maxdev);

/// Check vertices with 3D curve positions.
bool OCCTEdgeCheckVerticesWithCurve3d(OCCTShapeRef _Nonnull edge, double prec);

/// Check vertices with PCurve positions on a face.
bool OCCTEdgeCheckVerticesWithPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face, double prec);

/// Check 3D curve vs PCurve consistency on a face.
bool OCCTEdgeCheckCurve3dWithPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Get the first vertex position of an edge.
void OCCTEdgeFirstVertexSA(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Get the last vertex position of an edge.
void OCCTEdgeLastVertexSA(OCCTShapeRef _Nonnull edge, double* _Nonnull x, double* _Nonnull y, double* _Nonnull z);

/// Check vertex tolerances on a face edge. Returns true if tolerance is OK.
bool OCCTEdgeCheckVertexTolerance(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                                   double* _Nonnull toler1, double* _Nonnull toler2);

/// Check if two edges overlap. Returns true if overlapping.
bool OCCTEdgeCheckOverlapping(OCCTShapeRef _Nonnull edge1, OCCTShapeRef _Nonnull edge2,
                                double* _Nonnull tolOverlap);

/// Get UV bounds of an edge on a face.
bool OCCTEdgeBoundUV(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                      double* _Nonnull uFirst, double* _Nonnull vFirst,
                      double* _Nonnull uLast, double* _Nonnull vLast);

/// Get end tangent in 2D for an edge on a face. atEnd=true for last vertex.
bool OCCTEdgeGetEndTangent2d(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                              bool atEnd, double* _Nonnull px, double* _Nonnull py,
                              double* _Nonnull tx, double* _Nonnull ty);

/// Check PCurve range on a face.
bool OCCTEdgeCheckPCurveRange(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face,
                               double first, double last);

// --- BRepCheck extended ---

/// Check status of a specific face within a shape. Returns BRepCheck_Status enum.
int32_t OCCTCheckFaceStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull face);

/// Check status of a specific edge within a shape.
int32_t OCCTCheckEdgeStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull edge);

/// Check status of a specific vertex within a shape.
int32_t OCCTCheckVertexStatus(OCCTShapeRef _Nonnull shape, OCCTShapeRef _Nonnull vertex);

/// Get max tolerance of sub-shapes of given type (0=vertex, 1=edge, 2=face).
double OCCTShapeMaxTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Get min tolerance of sub-shapes of given type.
double OCCTShapeMinTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Get average tolerance of sub-shapes of given type.
double OCCTShapeAvgTolerance(OCCTShapeRef _Nonnull shape, int32_t type);

/// Fix tolerance on a shape to specified value. Returns true on success.
bool OCCTShapeFixTolerance(OCCTShapeRef _Nonnull shape, double tolerance);

/// Limit max tolerance on a shape. Returns true on success.
bool OCCTShapeLimitMaxTolerance(OCCTShapeRef _Nonnull shape, double maxTol);

/// Create a wire fixer from a wire shape on a face with given precision.
OCCTWireFixerRef _Nullable OCCTWireFixerCreate(OCCTShapeRef _Nonnull wire,
                                                 OCCTShapeRef _Nonnull face,
                                                 double precision);

/// Release a wire fixer.
void OCCTWireFixerRelease(OCCTWireFixerRef _Nonnull fixer);

/// Fix the order of edges in the wire.
bool OCCTWireFixerFixReorder(OCCTWireFixerRef _Nonnull fixer);

/// Fix connectivity of edges.
bool OCCTWireFixerFixConnected(OCCTWireFixerRef _Nonnull fixer);

/// Fix small edges.
bool OCCTWireFixerFixSmall(OCCTWireFixerRef _Nonnull fixer, double precSmall);

/// Fix degenerated edges.
bool OCCTWireFixerFixDegenerated(OCCTWireFixerRef _Nonnull fixer);

/// Fix self-intersection.
bool OCCTWireFixerFixSelfIntersection(OCCTWireFixerRef _Nonnull fixer);

/// Fix lacking edges.
bool OCCTWireFixerFixLacking(OCCTWireFixerRef _Nonnull fixer);

/// Fix closed wire.
bool OCCTWireFixerFixClosed(OCCTWireFixerRef _Nonnull fixer);

/// Fix 3D gaps between edges.
bool OCCTWireFixerFixGaps3d(OCCTWireFixerRef _Nonnull fixer);

/// Fix edge curves.
bool OCCTWireFixerFixEdgeCurves(OCCTWireFixerRef _Nonnull fixer);

/// Get the resulting fixed wire.
OCCTShapeRef _Nullable OCCTWireFixerWire(OCCTWireFixerRef _Nonnull fixer);

/// Create a face fixer from a face shape with given precision.
OCCTFaceFixerRef _Nullable OCCTFaceFixerCreate(OCCTShapeRef _Nonnull face, double precision);

/// Release a face fixer.
void OCCTFaceFixerRelease(OCCTFaceFixerRef _Nonnull fixer);

/// Perform all fixes on the face.
bool OCCTFaceFixerPerform(OCCTFaceFixerRef _Nonnull fixer);

/// Fix orientation of wires.
bool OCCTFaceFixerFixOrientation(OCCTFaceFixerRef _Nonnull fixer);

/// Add natural bound (outer wire) if missing.
bool OCCTFaceFixerFixAddNaturalBound(OCCTFaceFixerRef _Nonnull fixer);

/// Fix missing seam edge.
bool OCCTFaceFixerFixMissingSeam(OCCTFaceFixerRef _Nonnull fixer);

/// Fix small area wires.
bool OCCTFaceFixerFixSmallAreaWire(OCCTFaceFixerRef _Nonnull fixer);

/// Get the resulting fixed face.
OCCTShapeRef _Nullable OCCTFaceFixerFace(OCCTFaceFixerRef _Nonnull fixer);

// --- ShapeFix_Face control surface (#266 follow-up) ---

/// Toggle an individual ShapeFix_Face healing pass before Perform(). `modeId` selects the pass
/// (0 FixWire, 1 FixOrientation, 2 FixAddNaturalBound, 3 FixMissingSeam, 4 FixSmallAreaWire,
/// 5 RemoveSmallAreaFace, 6 FixIntersectingWires, 7 FixLoopWires, 8 FixSplitFace,
/// 9 AutoCorrectPrecision, 10 FixPeriodicDegenerated). `value`: -1 = default/auto, 0 = off, 1 = on.
void OCCTFaceFixerSetMode(OCCTFaceFixerRef _Nonnull fixer, int32_t modeId, int32_t value);

/// Fix self-intersecting wires on the face.
bool OCCTFaceFixerFixIntersectingWires(OCCTFaceFixerRef _Nonnull fixer);

/// Reconstruct a degenerate edge at a pole on a periodic surface.
bool OCCTFaceFixerFixPeriodicDegenerated(OCCTFaceFixerRef _Nonnull fixer);

/// Remove coincident-edge pairs from the face's wires.
bool OCCTFaceFixerFixWiresTwoCoincEdges(OCCTFaceFixerRef _Nonnull fixer);

/// Split a wire that loops back on itself (result wires are discarded; returns whether it fixed).
bool OCCTFaceFixerFixLoopWire(OCCTFaceFixerRef _Nonnull fixer);

/// The result of the fix — a Face, or a Shell when FixMissingSeam split the face. May differ from
/// OCCTFaceFixerFace (which always returns a Face).
OCCTShapeRef _Nullable OCCTFaceFixerResult(OCCTFaceFixerRef _Nonnull fixer);

/// Query which fixes fired after Perform(). `status`: 0 = OK (no flags), 1..8 = DONE1..DONE8,
/// 9..16 = FAIL1..FAIL8, 17 = DONE (any), 18 = FAIL (any).
bool OCCTFaceFixerStatus(OCCTFaceFixerRef _Nonnull fixer, int32_t status);

/// Clamp the max / min tolerance the fixer may set on the healed face (ShapeFix_Root). Call before Perform().
void OCCTFaceFixerSetMaxTolerance(OCCTFaceFixerRef _Nonnull fixer, double maxTolerance);
void OCCTFaceFixerSetMinTolerance(OCCTFaceFixerRef _Nonnull fixer, double minTolerance);

// --- ShapeAnalysis_ShapeContents expanded ---

/// Extended shape contents structure with additional detail counts.
typedef struct {
    int32_t nbSolids;
    int32_t nbShells;
    int32_t nbFaces;
    int32_t nbWires;
    int32_t nbEdges;
    int32_t nbVertices;
    int32_t nbFreeEdges;
    int32_t nbFreeWires;
    int32_t nbFreeFaces;
    int32_t nbSolidsWithVoids;
    int32_t nbBigSplines;
    int32_t nbC0Surfaces;
    int32_t nbC0Curves;
    int32_t nbOffsetSurf;
    int32_t nbIndirectSurf;
    int32_t nbOffsetCurves;
    int32_t nbTrimmedCurve2d;
    int32_t nbTrimmedCurve3d;
    int32_t nbBSplineSurf;
    int32_t nbBezierSurf;
    int32_t nbTrimSurf;
    int32_t nbWireWithSeam;
    int32_t nbWireWithSevSeams;
    int32_t nbFaceWithSevWires;
    int32_t nbNoPCurve;
    int32_t nbSharedSolids;
    int32_t nbSharedShells;
    int32_t nbSharedFaces;
    int32_t nbSharedWires;
    int32_t nbSharedEdges;
    int32_t nbSharedVertices;
} OCCTShapeContentsExtended;

/// Get extended shape contents analysis.
OCCTShapeContentsExtended OCCTShapeGetContentsExtended(OCCTShapeRef _Nonnull shape);

/// Which of an analysis' two result sequences an accessor addresses.
typedef enum {
    OCCTFreeBoundClosed = 0,
    OCCTFreeBoundOpen = 1
} OCCTFreeBoundKind;

/// Free bounds analysis result (summary)
typedef struct {
    int32_t totalFreeBounds;    // closedFreeBounds + openFreeBounds, per OCCT's own NbFreeBounds()
    int32_t closedFreeBounds;
    int32_t openFreeBounds;
} OCCTFreeBoundsResult;

/// Individual free bound properties
typedef struct {
    double area;
    double perimeter;
    // Aspect ratio: contour length divided by contour width, so 1 for a square-ish bound and 10
    // for a 100x10 one. NOT area/perimeter^2, which is what this field claimed before #504.
    // OCCT solves it from area and perimeter and leaves BOTH this and width at 0 when that solve
    // has no real root, which an exactly square bound hits by one ulp, since it sits precisely on
    // the boundary of the two branches. 0 here means "not solvable", not "degenerate contour".
    double ratio;
    double width;       // Average width, on the same 0-means-unsolved contract as ratio
    int32_t notchCount; // Narrow 'V'-like sub-contours found on this bound
} OCCTFreeBoundInfo;

/// Create a free bounds analyzer over a shape. The shape should be a compound or shell of faces;
/// a lone face has no free bounds, because the search runs over the shape's direct children.
/// @param tolerance Sewing tolerance used to chain free edges into contours. A tolerance of 0 (or
///        below) selects a different algorithm inside OCCT: the free edges are taken from the
///        shape's already-shared topology instead of from a sewing pass.
OCCTFreeBoundsPropsRef _Nullable OCCTFreeBoundsPropsCreate(OCCTShapeRef _Nonnull shape, double tolerance);

/// Release a free bounds analyzer.
void OCCTFreeBoundsPropsRelease(OCCTFreeBoundsPropsRef _Nonnull props);

/// Run the analysis, if it has not already run, and report whether results are available.
///
/// Idempotent: OCCT's own Perform() appends to its result sequences without clearing them, so
/// calling it twice doubles every count (#504). Calling this is optional: the accessors below
/// run it on demand.
bool OCCTFreeBoundsPropsPerform(OCCTFreeBoundsPropsRef _Nonnull props);

/// Number of closed, open and total free bounds.
OCCTFreeBoundsResult OCCTFreeBoundsPropsCounts(OCCTFreeBoundsPropsRef _Nonnull props);

/// Get the properties of one free bound.
/// @param kind Which sequence to index
/// @param index 0-based index within that sequence
/// @return true on success; false, with *outInfo untouched, when index is out of range
bool OCCTFreeBoundsPropsInfo(OCCTFreeBoundsPropsRef _Nonnull props, OCCTFreeBoundKind kind,
                             int32_t index, OCCTFreeBoundInfo* _Nonnull outInfo);

/// Get the contour wire of one free bound, as a shape.
/// @param kind Which sequence to index
/// @param index 0-based index within that sequence
/// @return Wire shape, or NULL when index is out of range
OCCTShapeRef _Nullable OCCTFreeBoundsPropsWire(OCCTFreeBoundsPropsRef _Nonnull props,
                                               OCCTFreeBoundKind kind, int32_t index);

/// Create a ShapeFix_Shape fixer for the given shape.
OCCTShapeFixerRef _Nonnull OCCTShapeFixerCreate(OCCTShapeRef _Nonnull shape);

/// Release a ShapeFix_Shape fixer.
void OCCTShapeFixerRelease(OCCTShapeFixerRef _Nonnull fixer);

/// Set the precision for the shape fixer.
void OCCTShapeFixerSetPrecision(OCCTShapeFixerRef _Nonnull fixer, double precision);

/// Set the maximum tolerance for the shape fixer.
void OCCTShapeFixerSetMaxTolerance(OCCTShapeFixerRef _Nonnull fixer, double maxTol);

/// Set the minimum tolerance for the shape fixer.
void OCCTShapeFixerSetMinTolerance(OCCTShapeFixerRef _Nonnull fixer, double minTol);

/// Perform the shape fix. Returns true if something was fixed.
bool OCCTShapeFixerPerform(OCCTShapeFixerRef _Nonnull fixer);

/// Get the result shape after fixing.
OCCTShapeRef _Nullable OCCTShapeFixerShape(OCCTShapeFixerRef _Nonnull fixer);

/// Query status. statusType: 1=ShapeFixOk, 2=ShapeFixDone, 3=ShapeFixFail.
/// Legacy — see OCCTShapeFixerStatusFlag for the full ShapeExtend_Status flag space (#849).
bool OCCTShapeFixerStatus(OCCTShapeFixerRef _Nonnull fixer, int32_t statusType);

/// Query a specific ShapeExtend_Status flag directly (#849), mirroring OCCTFaceFixerStatus.
/// Unlike OCCTShapeFixerStatus's legacy 1/2/3 remap, `flag` is the real ShapeExtend_Status
/// ordinal: OK=0, DONE1..DONE8=1..8, the combined DONE=9, FAIL1..FAIL8=10..17, the combined
/// FAIL=18.
bool OCCTShapeFixerStatusFlag(OCCTShapeFixerRef _Nonnull fixer, int32_t flag);

// MARK: - ShapeAnalysis_ShapeTolerance (v0.118.0)

/// Get shape tolerance: mode 0=average, >0=max, <0=min. type: 0=all, 7=VERTEX, 6=EDGE, 4=FACE.
double OCCTShapeToleranceValue(OCCTShapeRef _Nonnull shape, int32_t mode, int32_t shapeType);

/// Count shapes with tolerance over given value.
int32_t OCCTShapeToleranceOverCount(OCCTShapeRef _Nonnull shape, double value, int32_t shapeType);

/// Count shapes with tolerance in given interval.
int32_t OCCTShapeToleranceInRangeCount(OCCTShapeRef _Nonnull shape, double valmin, double valmax, int32_t shapeType);

// MARK: - BRepAlgoAPI_Check (v0.118.0)

/// Check validity of a single shape for boolean operations. Returns true if valid.
bool OCCTShapeBooleanCheckSingle(OCCTShapeRef _Nonnull shape, bool testSmallEdges, bool testSelfInterference);

/// Check validity of two shapes for boolean operation. Returns true if valid.
bool OCCTShapeBooleanCheckPair(OCCTShapeRef _Nonnull shape1, OCCTShapeRef _Nonnull shape2,
                                int32_t operation, bool testSmallEdges, bool testSelfInterference);

/// Create a wire analyzer from a wire, face, and precision.
OCCTWireAnalyzerRef _Nullable OCCTWireAnalyzerCreate(OCCTShapeRef _Nonnull wire,
                                                       OCCTShapeRef _Nonnull face,
                                                       double precision);

/// Release a wire analyzer.
void OCCTWireAnalyzerRelease(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Run all checks (CheckOrder, CheckSmall, CheckConnected, etc.).
bool OCCTWireAnalyzerPerform(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check edge ordering.
bool OCCTWireAnalyzerCheckOrder(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check if edge num (1-based) is connected to previous.
bool OCCTWireAnalyzerCheckConnected(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is small.
bool OCCTWireAnalyzerCheckSmall(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is degenerated.
bool OCCTWireAnalyzerCheckDegenerated(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check 3D gap at edge num (1-based, 0 = all).
bool OCCTWireAnalyzerCheckGap3d(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check 2D gap at edge num (1-based, 0 = all).
bool OCCTWireAnalyzerCheckGap2d(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is a seam.
bool OCCTWireAnalyzerCheckSeam(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check if edge num (1-based) is lacking.
bool OCCTWireAnalyzerCheckLacking(OCCTWireAnalyzerRef _Nonnull analyzer, int32_t edgeNum);

/// Check wire self-intersection.
bool OCCTWireAnalyzerCheckSelfIntersection(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Check if wire is closed.
bool OCCTWireAnalyzerCheckClosed(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Get the minimum 3D distance computed.
double OCCTWireAnalyzerMinDistance3d(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Get the maximum 3D distance computed.
double OCCTWireAnalyzerMaxDistance3d(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Number of edges in the wire.
int32_t OCCTWireAnalyzerNbEdges(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Whether the wire is loaded.
bool OCCTWireAnalyzerIsLoaded(OCCTWireAnalyzerRef _Nonnull analyzer);

/// Whether the analyzer is ready (wire + face loaded).
bool OCCTWireAnalyzerIsReady(OCCTWireAnalyzerRef _Nonnull analyzer);

// MARK: - v0.122.0: WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended

// --- WireFixer extended (ShapeFix_Wire) ---

/// Fix 2D gaps between edges.
bool OCCTWireFixerFixGaps2d(OCCTWireFixerRef _Nonnull fixer);

/// Fix seam edge at the given index (1-based).
bool OCCTWireFixerFixSeam(OCCTWireFixerRef _Nonnull fixer, int32_t edgeIndex);

/// Fix shifted pcurves.
bool OCCTWireFixerFixShifted(OCCTWireFixerRef _Nonnull fixer);

/// Fix notched edges.
bool OCCTWireFixerFixNotchedEdges(OCCTWireFixerRef _Nonnull fixer);

/// Fix tail edges.
bool OCCTWireFixerFixTails(OCCTWireFixerRef _Nonnull fixer);

/// Set the maximum tail angle (radians).
void OCCTWireFixerSetMaxTailAngle(OCCTWireFixerRef _Nonnull fixer, double angle);

/// Set the maximum tail width.
void OCCTWireFixerSetMaxTailWidth(OCCTWireFixerRef _Nonnull fixer, double width);

// --- ShapeFix_Edge extended ---

/// Add missing 3D curve to an edge. Returns true if fixed.
bool OCCTShapeFixEdgeAddCurve3d(OCCTShapeRef _Nonnull edge);

/// Add missing PCurve to an edge on a face. isSeam: true for seam edges.
bool OCCTShapeFixEdgeAddPCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face, bool isSeam);

/// Remove 3D curve from an edge. Returns true if removed.
bool OCCTShapeFixEdgeRemoveCurve3d(OCCTShapeRef _Nonnull edge);

/// Remove PCurve from an edge on a face. Returns true if removed.
bool OCCTShapeFixEdgeRemovePCurve(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

/// Fix reversed 2D curve on an edge/face pair.
bool OCCTShapeFixEdgeFixReversed2d(OCCTShapeRef _Nonnull edge, OCCTShapeRef _Nonnull face);

#endif /* OCCTBridge_Healing_h */
