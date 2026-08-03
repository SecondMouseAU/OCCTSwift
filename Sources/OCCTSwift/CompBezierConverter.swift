import Foundation
import simd
import OCCTBridge

/// Result of converting composite Bezier segments to a BSpline curve (3D).
public struct BezierToBSplineResult {
    public let degree: Int
    public let poles: [SIMD3<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}

/// Result of converting composite 2D Bezier segments to a BSpline curve.
public struct BezierToBSpline2dResult {
    public let degree: Int
    public let poles: [SIMD2<Double>]
    public let knots: [Double]
    public let multiplicities: [Int]
}

/// Utilities for converting composite Bezier curves to BSpline form.
public enum CompBezierConverter {

    /// Convert a sequence of connected Bezier segments (3D) to a single BSpline curve.
    /// - Parameters:
    ///   - segments: Each element is an array of control points for one Bezier segment.
    ///               All segments must have the same number of control points.
    /// - Returns: BSpline data, or nil on failure.
    public static func toBSpline(segments: [[SIMD3<Double>]]) -> BezierToBSplineResult? {
        guard !segments.isEmpty,
              let ptsPerSeg = segments.first?.count, ptsPerSeg > 0,
              segments.allSatisfy({ $0.count == ptsPerSeg }) else { return nil }

        var flat = [Double]()
        flat.reserveCapacity(segments.count * ptsPerSeg * 3)
        for seg in segments {
            for pt in seg { flat += [pt.x, pt.y, pt.z] }
        }

        var raw = OCCTBezierBSplineResult()
        let ok = flat.withUnsafeBufferPointer { buf in
            OCCTConvertCompBezierToBSpline(buf.baseAddress!, Int32(segments.count),
                                           Int32(ptsPerSeg), &raw)
        }
        guard ok else { return nil }

        let nb = Int(raw.nbPoles)
        let nk = Int(raw.nbKnots)

        var poles = [SIMD3<Double>]()
        poles.reserveCapacity(nb)
        withUnsafeBytes(of: raw.poles) { ptr in
            let dbl = ptr.bindMemory(to: Double.self)
            for i in 0..<nb {
                poles.append(SIMD3(dbl[i * 3], dbl[i * 3 + 1], dbl[i * 3 + 2]))
            }
        }

        var knots = [Double]()
        var mults = [Int]()
        knots.reserveCapacity(nk)
        mults.reserveCapacity(nk)
        withUnsafeBytes(of: raw.knots) { kptr in
            withUnsafeBytes(of: raw.mults) { mptr in
                let kd = kptr.bindMemory(to: Double.self)
                let mi = mptr.bindMemory(to: Int32.self)
                for i in 0..<nk {
                    knots.append(kd[i])
                    mults.append(Int(mi[i]))
                }
            }
        }

        return BezierToBSplineResult(degree: Int(raw.degree), poles: poles,
                                     knots: knots, multiplicities: mults)
    }

    /// Convert a sequence of connected 2D Bezier segments to a single BSpline curve.
    /// - Parameters:
    ///   - segments: Each element is an array of 2D control points for one Bezier segment.
    ///               All segments must have the same number of control points.
    /// - Returns: BSpline 2D data, or nil on failure.
    public static func toBSpline2d(segments: [[SIMD2<Double>]]) -> BezierToBSpline2dResult? {
        guard !segments.isEmpty,
              let ptsPerSeg = segments.first?.count, ptsPerSeg > 0,
              segments.allSatisfy({ $0.count == ptsPerSeg }) else { return nil }

        var flat = [Double]()
        flat.reserveCapacity(segments.count * ptsPerSeg * 2)
        for seg in segments {
            for pt in seg { flat += [pt.x, pt.y] }
        }

        var raw = OCCTBezierBSpline2dResult()
        let ok = flat.withUnsafeBufferPointer { buf in
            OCCTConvertCompBezier2dToBSpline2d(buf.baseAddress!, Int32(segments.count),
                                               Int32(ptsPerSeg), &raw)
        }
        guard ok else { return nil }

        let nb = Int(raw.nbPoles)
        let nk = Int(raw.nbKnots)

        var poles = [SIMD2<Double>]()
        poles.reserveCapacity(nb)
        withUnsafeBytes(of: raw.poles) { ptr in
            let dbl = ptr.bindMemory(to: Double.self)
            for i in 0..<nb {
                poles.append(SIMD2(dbl[i * 2], dbl[i * 2 + 1]))
            }
        }

        var knots = [Double]()
        var mults = [Int]()
        knots.reserveCapacity(nk)
        mults.reserveCapacity(nk)
        withUnsafeBytes(of: raw.knots) { kptr in
            withUnsafeBytes(of: raw.mults) { mptr in
                let kd = kptr.bindMemory(to: Double.self)
                let mi = mptr.bindMemory(to: Int32.self)
                for i in 0..<nk {
                    knots.append(kd[i])
                    mults.append(Int(mi[i]))
                }
            }
        }

        return BezierToBSpline2dResult(degree: Int(raw.degree), poles: poles,
                                       knots: knots, multiplicities: mults)
    }
}
