import Foundation
import simd
import OCCTBridge

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
