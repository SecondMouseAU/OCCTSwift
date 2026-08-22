import Foundation
import OCCTBridge
import simd

/// Trigonometric equation solver: A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0.
public enum TrigRoots {

    /// Find roots of A*cos(x) + B*sin(x) + C*cos(2x) + D*sin(2x) + E = 0 on [inf, sup].
    public static func solve(
        A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
        from inf: Double, to sup: Double
    ) -> [Double] {
        var roots = [Double](repeating: 0, count: 100)
        let n = OCCTTrigRoots(A, B, C, D, E, inf, sup, &roots, 100)
        guard n > 0 else { return [] }
        return Array(roots.prefix(Int(n)))
    }

    /// Check if all reals in [inf, sup] are solutions.
    public static func hasInfiniteRoots(
        A: Double = 0, B: Double = 0, C: Double = 0, D: Double = 0, E: Double = 0,
        from inf: Double, to sup: Double
    ) -> Bool {
        OCCTTrigRootsInfinite(A, B, C, D, E, inf, sup)
    }
}
