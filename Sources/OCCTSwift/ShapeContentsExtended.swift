import Foundation
import OCCTBridge
import simd

/// Extended shape contents analysis result.
public struct ShapeContentsExtended: Sendable {
    public let nbSolids: Int
    public let nbShells: Int
    public let nbFaces: Int
    public let nbWires: Int
    public let nbEdges: Int
    public let nbVertices: Int
    public let nbFreeEdges: Int
    public let nbFreeWires: Int
    public let nbFreeFaces: Int
    public let nbSolidsWithVoids: Int
    public let nbBigSplines: Int
    public let nbC0Surfaces: Int
    public let nbC0Curves: Int
    public let nbOffsetSurf: Int
    public let nbIndirectSurf: Int
    public let nbOffsetCurves: Int
    public let nbTrimmedCurve2d: Int
    public let nbTrimmedCurve3d: Int
    public let nbBSplineSurf: Int
    public let nbBezierSurf: Int
    public let nbTrimSurf: Int
    public let nbWireWithSeam: Int
    public let nbWireWithSevSeams: Int
    public let nbFaceWithSevWires: Int
    public let nbNoPCurve: Int
    public let nbSharedSolids: Int
    public let nbSharedShells: Int
    public let nbSharedFaces: Int
    public let nbSharedWires: Int
    public let nbSharedEdges: Int
    public let nbSharedVertices: Int
}
