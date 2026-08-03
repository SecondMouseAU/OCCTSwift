import Foundation
import simd
import OCCTBridge

/// Draft geometry information queries.
public enum DraftInfo {
    /// Check default EdgeInfo new geometry status.
    public static var edgeInfoNewGeometry: Bool {
        OCCTDraftEdgeInfoNewGeometry()
    }

    /// Check default FaceInfo new geometry status.
    public static var faceInfoNewGeometry: Bool {
        OCCTDraftFaceInfoNewGeometry()
    }

    /// Get default VertexInfo geometry point.
    public static var vertexInfoGeometry: SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTDraftVertexInfoGeometry(&x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Set tangent on an EdgeInfo and check success.
    public static func edgeInfoSetTangent(direction: SIMD3<Double>) -> Bool {
        OCCTDraftEdgeInfoSetTangent(direction.x, direction.y, direction.z)
    }

    /// Create FaceInfo from a surface and check RootFace.
    public static func faceInfoFromSurface(_ surface: Surface) -> Bool {
        OCCTDraftFaceInfoFromSurface(surface.handle)
    }

    /// Add a parameter to VertexInfo and get it back.
    public static func vertexInfoAddParameter(_ param: Double) -> Double {
        OCCTDraftVertexInfoAddParameter(param)
    }
}
