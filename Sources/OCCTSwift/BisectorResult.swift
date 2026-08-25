import Foundation
import OCCTBridge
import simd

// BisectorPoint was declared here: a Swift struct with no public initializer and no constructor
// call site anywhere in this module, mirroring the orphaned OCCTBisectorPointOnBis/
// OCCTBisectorPointOnBisCreate bridge pair it was built for (see OCCTBridge_Geom2d.mm's
// tombstone). Neither this package nor an external consumer could ever have produced one.
// Removed by #771.

/// Result of bisector intersection computation.
public struct BisectorIntersection {
    public let x: Double
    public let y: Double
    public let paramOnFirst: Double
    public let paramOnSecond: Double
    
    /// Maximum safe coordinate magnitude for bisector intersection computation.
    /// Values exceeding this threshold (1e150) may cause numerical issues in the underlying
    /// OCCT bisector computation. The threshold is well below Double's max (~1.8e308) but
    /// large enough to not affect normal use cases; it matches the "near-1e300" bound from #1085.
    public static let maxSafeMagnitude: Double = 1e150
}

/// Computes where the perpendicular bisector of `(a, b)` crosses that of `(c, d)`.
///
/// Each bisector is a half-line from its pair's midpoint, so reversing a pair can turn a crossing
/// into an empty result. An empty result has four causes that are not distinguished here: the pair
/// is too close together to have a bisector, the bisectors are parallel, they cross off a kept ray,
/// or they coincide and the overlap is not a point. See `docs/reference/Shape-Recognition.md` for
/// those, for the parameter range the search actually covers, and for why a distant crossing is
/// accurate but ill-conditioned in the input.
///
/// - Parameters:
///   - a: First point of the first pair, as `(x, y)`.
///   - b: Second point of the first pair.
///   - c: First point of the second pair.
///   - d: Second point of the second pair.
/// - Returns: The crossing, or an empty array. Two distinct half-lines meet at most once.
///
/// ```swift
/// // The circumcentre of the triangle (0,0) (4,0) (2,3).
/// let hits = bisectorIntersections(a: (0, 0), b: (4, 0), c: (4, 0), d: (2, 3))
/// // hits[0].x == 2, hits[0].y == 0.8333...
///
/// // A crossing far from all four points is found too, since #1050.
/// let far = bisectorIntersections(a: (0, 0), b: (0, 10), c: (-155, 0), d: (-145, 0))
/// // far[0].x == -150, far[0].y == 5, far[0].paramOnFirst == 150
/// ```
public func bisectorIntersections(
    a: (Double, Double), b: (Double, Double),
    c: (Double, Double), d: (Double, Double)
) -> [BisectorIntersection] {
    // Early return for non-finite coordinates (NaN, +Infinity, -Infinity) or extremely large
    // finite coordinates (near 1e300) to avoid hangs or undefined behaviour in the underlying
    // OCCT bisector computation. The threshold `BisectorIntersection.maxSafeMagnitude` (1e150)
    // is well below Double's max (~1.8e308) but large enough to not affect normal use cases;
    // it matches the "near-1e300" bound from #1085.
    let coords = [a.0, a.1, b.0, b.1, c.0, c.1, d.0, d.1]
    guard coords.allSatisfy({ $0.isFinite && $0.magnitude <= BisectorIntersection.maxSafeMagnitude }) else { return [] }

    var points = [OCCTBisectorIntersectionPoint](
        repeating: OCCTBisectorIntersectionPoint(), count: 10)
    let count = points.withUnsafeMutableBufferPointer { buf in
        OCCTBisectorInterPointPoint(
            a.0, a.1, b.0, b.1,
            c.0, c.1, d.0, d.1,
            buf.baseAddress, Int32(buf.count))
    }
    return (0..<Int(count)).map { i in
        BisectorIntersection(
            x: points[i].x, y: points[i].y,
            paramOnFirst: points[i].paramOnFirst,
            paramOnSecond: points[i].paramOnSecond)
    }
}
