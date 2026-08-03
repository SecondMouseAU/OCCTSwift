import Foundation
import simd
import OCCTBridge

/// Wire analysis utilities using ShapeAnalysis_Wire (v0.106.0).
public enum SAWireAnalysis {
    /// Check wire edge ordering. Returns true if problem found.
    public static func checkOrder(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOrder(wire.handle, face.handle, precision)
    }

    /// Check wire connectivity. Returns true if problem found.
    public static func checkConnected(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckConnected(wire.handle, face.handle, precision)
    }

    /// Check for small edges. Returns true if problem found.
    public static func checkSmall(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSmall(wire.handle, face.handle, precision)
    }

    /// Check for degenerated edges. Returns true if problem found.
    public static func checkDegenerated(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckDegenerated(wire.handle, face.handle, precision)
    }

    /// Check wire closure. Returns true if problem found.
    public static func checkClosed(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckClosed(wire.handle, face.handle, precision)
    }

    /// Check for self-intersection. Returns true if problem found.
    public static func checkSelfIntersection(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSelfIntersection(wire.handle, face.handle, precision)
    }

    /// Check for 3D gaps. Returns true if problem found.
    public static func checkGaps3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps3d(wire.handle, face.handle, precision)
    }

    /// Check for 2D gaps. Returns true if problem found.
    public static func checkGaps2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps2d(wire.handle, face.handle, precision)
    }

    /// Check edge curves consistency. Returns true if problem found.
    public static func checkEdgeCurves(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckEdgeCurves(wire.handle, face.handle, precision)
    }

    /// Check for lacking edges. Returns true if problem found.
    public static func checkLacking(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckLacking(wire.handle, face.handle, precision)
    }

    /// Get the number of edges in a wire on a face.
    public static func edgeCount(wire: Shape, face: Shape, precision: Double = 1e-6) -> Int {
        Int(OCCTWireEdgeCount(wire.handle, face.handle, precision))
    }

    /// Get the minimum 3D distance gap in a wire.
    public static func minDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 3D distance gap in a wire.
    public static func maxDistance3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance3d(wire.handle, face.handle, precision)
    }

    /// Get the minimum 2D distance gap in a wire.
    public static func minDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMinDistance2d(wire.handle, face.handle, precision)
    }

    /// Get the maximum 2D distance gap in a wire.
    public static func maxDistance2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Double {
        OCCTWireMaxDistance2d(wire.handle, face.handle, precision)
    }

    /// Check connectivity of a specific edge by index (1-based).
    public static func checkConnectedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                           edgeIndex: Int) -> Bool {
        OCCTWireCheckConnectedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is small (1-based).
    public static func checkSmallEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                       edgeIndex: Int) -> Bool {
        OCCTWireCheckSmallEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is degenerated (1-based).
    public static func checkDegeneratedEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                              edgeIndex: Int) -> Bool {
        OCCTWireCheckDegeneratedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check 3D gap at a specific edge (1-based).
    public static func checkGap3dEdge(wire: Shape, face: Shape, precision: Double = 1e-6,
                                       edgeIndex: Int) -> Bool {
        OCCTWireCheckGap3dEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a face has an outer bound wire.
    public static func checkOuterBound(face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOuterBound(face.handle, precision)
    }
}
