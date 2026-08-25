//
//  OCCTBridge_AdvancedModeling.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the Advanced Modeling domain.
//  Split from OCCTBridge_Modeling.h (#1071).
//

#ifndef OCCTBridge_AdvancedModeling_h
#define OCCTBridge_AdvancedModeling_h

// MARK: - Advanced Modeling (v0.8.0)

/// Fillet specific edges with uniform radius
///
/// One of three entry points sharing occtShapeFilletEdgeList (OCCTBridge_Internal.h) with
/// OCCTShapeFilletEdgesLinear and OCCTShapeBlendEdges: same edge map, same 0-based index bounds
/// check, same positive-radius precondition. #489
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based; an index naming no edge of `shape` rejects
///   the whole call, #520). An edge OCCT declines to add is skipped, as Add(Radius, E) skips it.
/// @param edgeCount Number of edges to fillet
/// @param radius Fillet radius; must be > 0, or the call fails without touching OCCT
/// @param declinedEdgeIndices Optional (may be NULL): filled with the 0-based indices, from
///   `edgeIndices`, that OCCT declined to fillet (#639), a free-boundary edge, e.g. Must have
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

/// Fillet edges with variable radius law
///
/// Same #639 reporting contract as OCCTShapeFilletEdges above.
/// @param shape The shape to fillet
/// @param edgeIndices Array of edge indices (0-based)
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
/// OCCTShapeHistoryFromDefeature. All of them share one skeleton, see the defeaturing block in
/// OCCTBridge_Internal.h. #497
/// @param shape The shape to modify
/// @param faceIndices Array of face indices to remove (0-based, into the shape's own face map)
/// @param faceCount Number of faces to remove
/// @return Shape with features removed, or NULL on failure, including when faceCount is 0 or an
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

#endif /* OCCTBridge_AdvancedModeling_h */
