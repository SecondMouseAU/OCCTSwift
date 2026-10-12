import Testing

@testable import OCCTSwift

@Suite("GeomFill DegeneratedBound")
struct GeomFillDegeneratedBoundTests {
    @Test func degeneratedBoundaryValue() {
        let val = Surface.degeneratedBoundaryValue(
            point: SIMD3(1, 2, 3), parameter: 0.5)
        #expect(abs(val.x - 1.0) < 1e-6)
        #expect(abs(val.y - 2.0) < 1e-6)
        #expect(abs(val.z - 3.0) < 1e-6)
    }

    @Test func isDegenerated() {
        let result = Surface.isDegeneratedBoundary(point: SIMD3(1, 2, 3))
        #expect(result)
        // A degenerated bound is a point bound whichever point it is built on, and the value
        // along it is that point at every parameter.
        for p in [SIMD3(0.0, 0.0, 0.0), SIMD3(-4.5, 7.25, 1e3)] {
            #expect(Surface.isDegeneratedBoundary(point: p))
            for t in [0.0, 0.5, 1.0] {
                let v = Surface.degeneratedBoundaryValue(point: p, parameter: t)
                #expect(abs(v.x - p.x) < 1e-6 && abs(v.y - p.y) < 1e-6 && abs(v.z - p.z) < 1e-6)
            }
        }
    }
}
