import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-construct-custom-extend/probe.mm (transcript.txt beside it).
// Before #766 each test asserted only non-nil inside `if let`.
@Suite("ShapeConstruct Curve Tests")
struct ShapeConstructCurveTests {
    @Test("convert 3D line segment to BSpline")
    func convert3DLine() throws {
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let bsp = try #require(line.convertSegmentToBSpline(first: 0, last: 10))
        #expect(bsp.curveType == 6)
        #expect(bsp.degree == 1)
        #expect(simd_distance(bsp.point(at: bsp.domain.lowerBound), SIMD3(0, 0, 0)) < 1e-9)
        #expect(simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD3(10, 0, 0)) < 1e-9)
    }

    @Test("convert 3D circle segment to BSpline")
    func convert3DCircle() throws {
        // Kernel: degree 7, from (5,0,0) to (-5,0,0) over [0, pi], midpoint (0, 4.999934, 0).
        let circle = try #require(Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5))
        let bsp = try #require(circle.convertSegmentToBSpline(first: 0, last: Double.pi, precision: 1e-3))
        #expect(bsp.curveType == 6)
        #expect(simd_distance(bsp.point(at: bsp.domain.lowerBound), SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD3(-5, 0, 0)) < 1e-9)
        let mid = (bsp.domain.lowerBound + bsp.domain.upperBound) / 2
        #expect(simd_distance(bsp.point(at: mid), SIMD3(0, 4.999934, 0)) < 1e-5)
    }

    @Test("convert 2D line to BSpline")
    func convert2DLine() throws {
        let line = try #require(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)))
        let bsp = try #require(line.convertSegmentToBSpline(first: 0, last: 5))
        #expect(simd_distance(bsp.point(at: bsp.domain.lowerBound), SIMD2(0, 0)) < 1e-9)
        #expect(simd_distance(bsp.point(at: bsp.domain.upperBound), SIMD2(5, 0)) < 1e-9)
    }

    @Test("adjust 3D curve endpoints")
    func adjust3D() throws {
        // Kernel: AdjustCurve on a line to its own (0,0,0)-(10,0,0) reports success.
        let line = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        #expect(line.adjustEndpoints(start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0)))
    }
}
