import Foundation
import OCCTBridge
import simd

/// Analyzer for wire geometry and topology, wrapping ShapeAnalysis_Wire.
public final class WireAnalyzer: @unchecked Sendable {
    private let handle: OCCTWireAnalyzerRef

    /// Create a wire analyzer from a wire shape, a face it lies on, and precision.
    public init?(wire: Wire, face: Shape, precision: Double = 1e-7) {
        guard let ref = OCCTWireAnalyzerCreate(wire.handle, face.handle, precision) else {
            return nil
        }
        self.handle = ref
    }

    deinit { OCCTWireAnalyzerRelease(handle) }

    /// Run all checks (order, small, connected, degenerated, self-intersection, lacking, closed).
    public func perform() -> Bool {
        OCCTWireAnalyzerPerform(handle)
    }

    /// Check edge ordering.
    public func checkOrder() -> Bool {
        OCCTWireAnalyzerCheckOrder(handle)
    }

    /// Check if edge (1-based) is connected to the previous one.
    public func checkConnected(edgeNum: Int) -> Bool {
        OCCTWireAnalyzerCheckConnected(handle, Int32(edgeNum))
    }

    /// Check if edge (1-based) is small.
    public func checkSmall(edgeNum: Int) -> Bool {
        OCCTWireAnalyzerCheckSmall(handle, Int32(edgeNum))
    }

    /// Check if edge (1-based) is degenerated.
    public func checkDegenerated(edgeNum: Int) -> Bool {
        OCCTWireAnalyzerCheckDegenerated(handle, Int32(edgeNum))
    }

    /// Check 3D gap at edge (1-based, 0 = check all).
    public func checkGap3d(edgeNum: Int = 0) -> Bool {
        OCCTWireAnalyzerCheckGap3d(handle, Int32(edgeNum))
    }

    /// Check 2D gap at edge (1-based, 0 = check all).
    public func checkGap2d(edgeNum: Int = 0) -> Bool {
        OCCTWireAnalyzerCheckGap2d(handle, Int32(edgeNum))
    }

    /// Check if edge (1-based) is a seam.
    public func checkSeam(edgeNum: Int) -> Bool {
        OCCTWireAnalyzerCheckSeam(handle, Int32(edgeNum))
    }

    /// Check if edge (1-based) is lacking.
    public func checkLacking(edgeNum: Int) -> Bool {
        OCCTWireAnalyzerCheckLacking(handle, Int32(edgeNum))
    }

    /// Check wire self-intersection.
    public func checkSelfIntersection() -> Bool {
        OCCTWireAnalyzerCheckSelfIntersection(handle)
    }

    /// Check if wire is closed.
    public func checkClosed() -> Bool {
        OCCTWireAnalyzerCheckClosed(handle)
    }

    /// Get the minimum 3D distance computed.
    public var minDistance3d: Double {
        OCCTWireAnalyzerMinDistance3d(handle)
    }

    /// Get the maximum 3D distance computed.
    public var maxDistance3d: Double {
        OCCTWireAnalyzerMaxDistance3d(handle)
    }

    /// Number of edges in the wire.
    public var edgeCount: Int {
        Int(OCCTWireAnalyzerNbEdges(handle))
    }

    /// Whether the wire is loaded.
    public var isLoaded: Bool {
        OCCTWireAnalyzerIsLoaded(handle)
    }

    /// Whether the analyzer is ready (wire + face loaded).
    public var isReady: Bool {
        OCCTWireAnalyzerIsReady(handle)
    }
}
