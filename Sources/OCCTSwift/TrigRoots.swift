import Foundation
import OCCTBridge
import simd

/// Trigonometric equation solver: a*cos(x) + b*sin(x) + c*cos(2x) + d*sin(2x) + e = 0.
public enum TrigRoots {

    /// Find roots of a*cos(x) + b*sin(x) + c*cos(2x) + d*sin(2x) + e = 0 on [inf, sup].
    public static func solve(
        a: Double = 0, b: Double = 0, c: Double = 0, d: Double = 0, e: Double = 0,
        from inf: Double, to sup: Double
    ) -> [Double] {
        var roots = [Double](repeating: 0, count: 100)
        let n = OCCTTrigRoots(a, b, c, d, e, inf, sup, &roots, 100)
        guard n > 0 else { return [] }
        return Array(roots.prefix(Int(n)))
    }

    /// Check if all reals in [inf, sup] are solutions.
    public static func hasInfiniteRoots(
        a: Double = 0, b: Double = 0, c: Double = 0, d: Double = 0, e: Double = 0,
        from inf: Double, to sup: Double
    ) -> Bool {
        OCCTTrigRootsInfinite(a, b, c, d, e, inf, sup)
    }
}
