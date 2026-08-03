import Foundation
import simd
import OCCTBridge

/// Point on a bisector curve with parameter and distance information.
public struct BisectorPoint {
    public let paramOnC1: Double
    public let paramOnC2: Double
    public let paramOnBis: Double
    public let distance: Double
    public let x: Double
    public let y: Double
    public let isInfinite: Bool
}

/// Result of bisector intersection computation.
public struct BisectorIntersection {
    public let x: Double
    public let y: Double
    public let paramOnFirst: Double
    public let paramOnSecond: Double
}

/// Compute intersections between perpendicular bisectors of two point pairs.
/// The bisector of (a,b) is intersected with the bisector of (c,d).
/// Returns intersection points (the circumcenter for triangle problems).
public func bisectorIntersections(
    a: (Double, Double), b: (Double, Double),
    c: (Double, Double), d: (Double, Double)
) -> [BisectorIntersection] {
    var points = [OCCTBisectorIntersectionPoint](repeating: OCCTBisectorIntersectionPoint(), count: 10)
    let count = points.withUnsafeMutableBufferPointer { buf in
        OCCTBisectorInterPointPoint(a.0, a.1, b.0, b.1,
                                     c.0, c.1, d.0, d.1,
                                     buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(count)).map { i in
        BisectorIntersection(x: points[i].x, y: points[i].y,
                             paramOnFirst: points[i].paramOnFirst,
                             paramOnSecond: points[i].paramOnSecond)
    }
}
