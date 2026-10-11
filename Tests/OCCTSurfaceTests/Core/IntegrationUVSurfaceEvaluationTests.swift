import Foundation
import Testing

@testable import OCCTSwift

@Suite("Integration: UV Surface Evaluation")
struct IntegrationUVSurfaceEvaluationTests {

    @Test func cylinderPointsAtConstantRadius() throws {
        let radius = 25.0
        let cyl = try #require(
            Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius),
            "Failed to create cylinder surface")

        // #2983: a constant radius is also true of a point that sits at the wrong angle or the
        // wrong height, so the parametrisation is pinned: u is the angle and v is the height.
        for u in [0.0, 1.0, 2.5, 4.0] {
            for v in [-7.0, 0.0, 2.5] {
                let want = SIMD3(radius * cos(u), radius * sin(u), v)
                #expect(vectorLength(cyl.point(atU: u, v: v) - want) < 1e-9)
            }
        }

        // Evaluate points on a grid of (u, v) parameters
        // For a cylinder: u is angular (0..2pi), v is along axis
        let dom = cyl.domain
        let uSteps = 8
        let vSteps = 4

        for ui in 0..<uSteps {
            let u = dom.uMin + (dom.uMax - dom.uMin) * Double(ui) / Double(uSteps)
            for vi in 0..<vSteps {
                let v = dom.vMin + (dom.vMax - dom.vMin) * Double(vi) / Double(vSteps)
                let pt = cyl.point(atU: u, v: v)
                // Distance from Z-axis should equal radius
                let distFromAxis = sqrt(pt.x * pt.x + pt.y * pt.y)
                #expect(
                    abs(distFromAxis - radius) < 1e-6,
                    "Point at u=\(u), v=\(v) should be at radius \(radius), got \(distFromAxis)")
            }
        }

        // Check arc length along one v-slice (full circle = 2*pi*R)
        // Sample many points along u at fixed v, compute polyline length
        let fixedV = (dom.vMin + dom.vMax) / 2.0
        let nSamples = 100
        var arcLength = 0.0
        var prevPt = cyl.point(atU: dom.uMin, v: fixedV)
        for i in 1...nSamples {
            let u = dom.uMin + (dom.uMax - dom.uMin) * Double(i) / Double(nSamples)
            let pt = cyl.point(atU: u, v: fixedV)
            let dx = pt.x - prevPt.x
            let dy = pt.y - prevPt.y
            let dz = pt.z - prevPt.z
            arcLength += sqrt(dx * dx + dy * dy + dz * dz)
            prevPt = pt
        }
        // The inscribed 100-gon has perimeter 100 * 2 R sin(pi / 100) = 157.0537953906..., which
        // is 0.0258 short of the circumference 2 pi R; the old 0.1 window accepted both, and a
        // polyline that was 0.07 off. The polyline is pinned to the exact value, and the
        // circumference is checked as the bound it approximates from below.
        let expectedPolygon = 100.0 * 2.0 * radius * sin(Double.pi / 100.0)
        #expect(
            abs(arcLength - expectedPolygon) < 1e-9,
            "Arc length \(arcLength) should equal the inscribed polygon \(expectedPolygon)")
        let expectedCircumference = 2.0 * .pi * radius
        #expect(arcLength < expectedCircumference)
        #expect(expectedCircumference - arcLength < 0.03)
    }
}
