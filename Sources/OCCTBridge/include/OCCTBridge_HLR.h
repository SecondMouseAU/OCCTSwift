//
//  OCCTBridge_HLR.h
//  OCCTSwift
//
//  Objective-C++ bridge declarations for the HLR (Hidden Line Removal) / Drawing domain.
//  Split from OCCTBridge_Modeling.h (#1071).
//

#ifndef OCCTBridge_HLR_h
#define OCCTBridge_HLR_h

// MARK: - HLR / Drawing

typedef struct OCCTDrawing* OCCTDrawingRef;

typedef enum
{
  OCCTProjectionOrthographic = 0,
  OCCTProjectionPerspective  = 1
} OCCTProjectionType;

typedef enum
{
  OCCTEdgeTypeVisible = 0,
  OCCTEdgeTypeHidden  = 1,
  OCCTEdgeTypeOutline = 2
} OCCTEdgeType;

/// Create an HLR (Hidden Line Removal) drawing from a shape.
/// @param shape The shape to project
/// @param dirX, dirY, dirZ View direction vector
/// @param projectionType Orthographic or perspective projection
/// @param focus Focus distance for perspective projection (must be > 0)
/// @return Drawing reference, or NULL on failure. Caller must release with OCCTDrawingRelease.
OCCTDrawingRef _Nullable OCCTDrawingCreate(OCCTShapeRef       shape,
                                           double             dirX,
                                           double             dirY,
                                           double             dirZ,
                                           OCCTProjectionType projectionType,
                                           double             focus);

/// Create an HLR drawing using polygonal (triangulation-based) algorithm.
/// @param shape The shape to project
/// @param dirX, dirY, dirZ View direction vector
/// @param deflection Deflection for triangulation
/// @return Drawing reference, or NULL on failure. Caller must release with OCCTDrawingRelease.
OCCTDrawingRef _Nullable OCCTDrawingCreatePoly(OCCTShapeRef shape,
                                               double       dirX,
                                               double       dirY,
                                               double       dirZ,
                                               double       deflection);

/// Extract edges of a specific type from a drawing.
/// @param drawing The drawing reference
/// @param edgeType Type of edges to extract
/// @return Shape containing the edges, or NULL on failure. Caller must release with
/// OCCTShapeRelease.
OCCTShapeRef _Nullable OCCTDrawingGetEdges(OCCTDrawingRef drawing, OCCTEdgeType edgeType);

/// Release a drawing reference.
void OCCTDrawingRelease(OCCTDrawingRef drawing);

#endif /* OCCTBridge_HLR_h */
