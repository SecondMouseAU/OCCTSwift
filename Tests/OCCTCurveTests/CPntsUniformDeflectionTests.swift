import Foundation
import Testing
import simd

@testable import OCCTSwift

// Pinned to CPnts_UniformDeflection on the same edge at the same deflection
// (Scripts/repro/766-curve-comp-conic-deflection/transcript.txt): the r = 10 cap circle, edges[0],
// takes 24 points over [0, 2 pi] at 0.1, and 14 over [0, params[12]]. The earlier versions
// accepted any count above 4, and any ranged count below the full one (#766).
@Suite("CPnts UniformDeflection")
struct CPntsUniformDeflectionTests {
    private static func circleEdge() -> Shape? {
        guard let cyl = Shape.cylinder(radius: 10, height: 5),
            let e = cyl.subShapes(ofType: .edge).first(where: { $0.edgeAdaptorCurveType == 1 })
        else {
            Issue.record("no circular edge on the cylinder")
            return nil
        }
        return e
    }

    @Test("Uniform deflection on circle edge")
    func uniformDeflectionCircle() {
        guard let edge = Self.circleEdge() else { return }
        guard let result = edge.uniformDeflection(0.1) else {
            Issue.record("uniformDeflection returned nil")
            return
        }
        #expect(result.points.count == 24)
        #expect(result.parameters.count == result.points.count)
        #expect(result.parameters.first == 0)
        #expect(abs((result.parameters.last ?? 0) - 2 * .pi) < 1e-12)
        for p in result.points {
            #expect(abs(simd_length(SIMD2(p.x, p.y)) - 10) < 1e-9)
        }
    }

    @Test("Uniform deflection with range")
    func uniformDeflectionRange() {
        guard let edge = Self.circleEdge() else { return }
        guard let full = edge.uniformDeflection(0.1), full.parameters.count == 24 else {
            Issue.record("full sampling is not the kernel's 24 points")
            return
        }
        let range = full.parameters[0]...full.parameters[full.parameters.count / 2]
        guard let ranged = edge.uniformDeflection(0.1, range: range) else {
            Issue.record("ranged uniformDeflection returned nil")
            return
        }
        #expect(ranged.points.count == 14)
        #expect(ranged.parameters.first == range.lowerBound)
        #expect(abs((ranged.parameters.last ?? 0) - 3.2361593398235615) < 1e-12)
    }
}
