import Foundation
import OCCTBridge
import simd

/// Wire analysis utilities using ShapeAnalysis_Wire (v0.106.0).
public enum SAWireAnalysis {
    /// Check wire edge ordering.
    ///
    /// Returns true if a problem is found.
    public static func checkOrder(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckOrder(wire.handle, face.handle, precision)
    }

    /// Check wire connectivity.
    ///
    /// Returns true if a problem is found.
    public static func checkConnected(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckConnected(wire.handle, face.handle, precision)
    }

    /// Check for small edges.
    ///
    /// Returns true if a problem is found.
    public static func checkSmall(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckSmall(wire.handle, face.handle, precision)
    }

    /// Check for degenerated edges.
    ///
    /// Returns true if a problem is found.
    public static func checkDegenerated(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool
    {
        OCCTWireCheckDegenerated(wire.handle, face.handle, precision)
    }

    /// Check wire closure.
    ///
    /// Returns true if a problem is found.
    public static func checkClosed(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckClosed(wire.handle, face.handle, precision)
    }

    /// Check for self-intersection.
    ///
    /// Returns true if a problem is found.
    public static func checkSelfIntersection(wire: Shape, face: Shape, precision: Double = 1e-6)
        -> Bool
    {
        OCCTWireCheckSelfIntersection(wire.handle, face.handle, precision)
    }

    /// Check for 3D gaps.
    ///
    /// Returns true if a problem is found.
    public static func checkGaps3d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps3d(wire.handle, face.handle, precision)
    }

    /// Check for 2D gaps.
    ///
    /// Returns true if a problem is found.
    public static func checkGaps2d(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckGaps2d(wire.handle, face.handle, precision)
    }

    /// Check edge curves consistency.
    ///
    /// Returns true if a problem is found.
    public static func checkEdgeCurves(wire: Shape, face: Shape, precision: Double = 1e-6) -> Bool {
        OCCTWireCheckEdgeCurves(wire.handle, face.handle, precision)
    }

    /// Check for lacking edges.
    ///
    /// Returns true if a problem is found.
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
    public static func checkConnectedEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckConnectedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is small (1-based).
    public static func checkSmallEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckSmallEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check if a specific edge is degenerated (1-based).
    public static func checkDegeneratedEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckDegeneratedEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check 3D gap at a specific edge (1-based).
    public static func checkGap3dEdge(
        wire: Shape, face: Shape, precision: Double = 1e-6,
        edgeIndex: Int
    ) -> Bool {
        OCCTWireCheckGap3dEdge(wire.handle, face.handle, precision, Int32(edgeIndex))
    }

    /// Check whether a wire fails to define an outer bound on a face, or nil when the check.
    /// could not be run at all.
    ///
    /// Returns true if a problem is found, false if none is, and nil for four inputs the check.
    /// cannot evaluate: a Shape that is not a wire or not a face, **a null shape included**; a
    /// wire with no edges; a wire whose edges do not assemble; and a wire with no pcurve on the.
    /// face (#1058).
    ///
    /// The other fourteen **check** members of this enum answer a plain Bool, so a.
    /// refused call and a clean verdict are the same value for them; edgeCount and the four.
    /// distance members return Int/Double and have their own version of that collision.
    ///
    /// Unlike every sibling above, this takes no precision, because.
    /// `ShapeAnalysis_Wire::CheckOuterBound` consults none.
    ///
    /// ```swift.
    /// let outer = SAWireAnalysis.checkOuterBound(wire: outerWire, face: face)   // false
    /// let inner = SAWireAnalysis.checkOuterBound(wire: holeWire, face: face)    // true
    /// let alien = SAWireAnalysis.checkOuterBound(wire: outerWire, face: cylinderFace)  // nil
    /// ```.
    public static func checkOuterBound(wire: Shape, face: Shape) -> Bool? {
        // Third copy of the bridge's 1/0/-1 decoder; #1077 has the census that decides whether it
        // becomes a shared helper, and which int32_t returns are eligible for one.
        switch OCCTWireCheckOuterBound(wire.handle, face.handle) {
        case 1: return true
        case 0: return false
        default: return nil
        }
    }
}
