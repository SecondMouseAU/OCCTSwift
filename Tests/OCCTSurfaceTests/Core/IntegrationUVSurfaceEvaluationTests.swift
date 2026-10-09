import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: UV Surface Evaluation")
struct IntegrationUVSurfaceEvaluationTests {

    @Test func cylinderPointsAtConstantRadius() {
        let radius = 25.0
        guard let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: radius) else {
            #expect(Bool(false), "Failed to create cylinder surface")
            return
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
        let expectedCircumference = 2.0 * .pi * radius
        #expect(
            abs(arcLength - expectedCircumference) < 0.1,
            "Arc length \(arcLength) should approximate circumference \(expectedCircumference)")
    }
}
