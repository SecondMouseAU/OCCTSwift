import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// PROBE, not a regression test: #2926's discriminator. The issue's reading 2 is that the G3
// solver converges identically at 1e-1 and 1e-3, which a different libm makes plausible. Eleven
// orders of tolerance separate the two runs here, so a max delta of exactly 0.0 across that span
// is not convergence agreeing, it is the parameter not reaching the solver. Delete once #2926 is
// answered.
@Suite("Probe 2926, G3 tolerance reach")
struct Probe2926Tolerance {

    /// The same three-point G3 fixture `Issue999NLPlateParameters` uses, so the probe measures
    /// that suite's subject rather than a new one.
    static let constraints:
        [(
            uv: SIMD2<Double>, target: SIMD3<Double>,
            tangentU: SIMD3<Double>, tangentV: SIMD3<Double>,
            curvatureUU: SIMD3<Double>, curvatureUV: SIMD3<Double>, curvatureVV: SIMD3<Double>,
            d3UUU: SIMD3<Double>, d3UUV: SIMD3<Double>, d3UVV: SIMD3<Double>, d3VVV: SIMD3<Double>
        )] = [
            (
                uv: SIMD2(0.2, 0.2), target: SIMD3(0.2, 0.2, 1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
            (
                uv: SIMD2(0.8, 0.2), target: SIMD3(0.8, 0.2, -1.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
            (
                uv: SIMD2(0.5, 0.8), target: SIMD3(0.5, 0.8, 2.0),
                tangentU: SIMD3(1, 0, 0), tangentV: SIMD3(0, 1, 0),
                curvatureUU: .zero, curvatureUV: .zero, curvatureVV: .zero,
                d3UUU: .zero, d3UUV: .zero, d3UVV: .zero, d3VVV: .zero
            ),
        ]

    private func fingerprint(_ s: Surface) -> [Double] {
        var out: [Double] = []
        for i in 0...4 {
            for j in 0...4 {
                let u = Double(i) / 4.0
                let v = Double(j) / 4.0
                let p = s.point(atU: u, v: v)
                out.append(p.x)
                out.append(p.y)
                out.append(p.z)
            }
        }
        return out
    }

    @Test("Eleven orders of G3 tolerance, and what reaches the surface")
    func toleranceSpanIsLive() throws {
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let constraints = Probe2926Tolerance.constraints

        var fingerprints: [(Double, [Double])] = []
        var diagnosticCounts: [(Double, Int)] = []
        for tol in [100.0, 10.0, 1.0, 1e-1, 1e-3, 1e-12] {
            let captured = OCCTDiagnostics.capturing { () -> Surface? in
                plane.nlPlateDeformedG3(constraints: constraints, tolerance: tol)
            }
            diagnosticCounts.append((tol, captured.diagnostics.count))
            if let s = captured.value {
                fingerprints.append((tol, fingerprint(s)))
            } else {
                print("PROBE2926 tol=\(tol) RETURNED NIL")
            }
        }

        for (tol, count) in diagnosticCounts {
            print("PROBE2926 tol=\(tol) diagnostics=\(count)")
        }
        guard let base = fingerprints.first else {
            Issue.record("no G3 deformation succeeded")
            return
        }
        for (tol, fp) in fingerprints.dropFirst() {
            let delta = zip(base.1, fp).map { abs($0 - $1) }.max() ?? 0
            print("PROBE2926 maxDelta(\(base.0) vs \(tol)) = \(delta)")
        }
        #expect(fingerprints.count == 6, "every tolerance should produce a surface")
    }
}
