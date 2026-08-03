import Foundation
import simd
import OCCTBridge

/// Support type for distance solution points.
public enum DistanceSupportType: Int32, Sendable {
    case vertex = 0
    case edge = 1
    case face = 2
}

/// Full multi-result distance computation between two shapes.
public final class ShapeDistance: @unchecked Sendable {
    private let ref: OCCTDistSSRef

    /// Compute distance between two shapes.
    public init?(shape1: Shape, shape2: Shape) {
        guard let r = OCCTDistSSCreate(shape1.handle, shape2.handle) else { return nil }
        self.ref = r
    }

    deinit { OCCTDistSSRelease(ref) }

    /// Whether the computation succeeded.
    public var isDone: Bool { OCCTDistSSIsDone(ref) }

    /// The minimum distance value.
    public var value: Double { OCCTDistSSValue(ref) }

    /// Number of distance solutions.
    public var solutionCount: Int { Int(OCCTDistSSNbSolution(ref)) }

    /// Get the i-th point on shape 1 (0-based).
    public func pointOnShape1(at index: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTDistSSPointOnShape1(ref, Int32(index + 1), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the i-th point on shape 2 (0-based).
    public func pointOnShape2(at index: Int) -> SIMD3<Double> {
        var x = 0.0, y = 0.0, z = 0.0
        OCCTDistSSPointOnShape2(ref, Int32(index + 1), &x, &y, &z)
        return SIMD3(x, y, z)
    }

    /// Get the support type on shape 1 (0-based).
    public func supportType1(at index: Int) -> DistanceSupportType? {
        DistanceSupportType(rawValue: OCCTDistSSSupportType1(ref, Int32(index + 1)))
    }

    /// Get the support type on shape 2 (0-based).
    public func supportType2(at index: Int) -> DistanceSupportType? {
        DistanceSupportType(rawValue: OCCTDistSSSupportType2(ref, Int32(index + 1)))
    }

    /// Get the support sub-shape on shape 1 (0-based).
    public func supportShape1(at index: Int) -> Shape? {
        guard let r = OCCTDistSSSupportShape1(ref, Int32(index + 1)) else { return nil }
        return Shape(handle: r)
    }

    /// Get the support sub-shape on shape 2 (0-based).
    public func supportShape2(at index: Int) -> Shape? {
        guard let r = OCCTDistSSSupportShape2(ref, Int32(index + 1)) else { return nil }
        return Shape(handle: r)
    }
}
