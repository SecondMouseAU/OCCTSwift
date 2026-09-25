import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Integration: Geodesic Path Approximation")
struct IntegrationGeodesicPathApproximationTests {

    @Test func sphereUVPathLength() {
        let radius = 30.0
        guard let sphere = Surface.sphere(center: .zero, radius: radius) else {
            #expect(Bool(false), "Failed to create sphere surface")
            return
        }

        let dom = sphere.domain
        // Pick two UV points: "north pole area" and "equator area"
        let u1 = dom.uMin + 0.3 * (dom.uMax - dom.uMin)
        let v1 = dom.vMin + 0.3 * (dom.vMax - dom.vMin)
        let u2 = dom.uMin + 0.7 * (dom.uMax - dom.uMin)
        let v2 = dom.vMin + 0.7 * (dom.vMax - dom.vMin)

        let startPt = sphere.point(atU: u1, v: v1)
        let endPt = sphere.point(atU: u2, v: v2)
        let straightDist = sqrt(
            (endPt.x - startPt.x) * (endPt.x - startPt.x) + (endPt.y - startPt.y)
                * (endPt.y - startPt.y) + (endPt.z - startPt.z) * (endPt.z - startPt.z)
        )

        // Subdivide UV path into N segments and compute polyline length on surface
        let nSegments = 200
        var polyLength = 0.0
        var prevPt = sphere.point(atU: u1, v: v1)
        for i in 1...nSegments {
            let t = Double(i) / Double(nSegments)
            let u = u1 + t * (u2 - u1)
            let v = v1 + t * (v2 - v1)
            let pt = sphere.point(atU: u, v: v)
            let dx = pt.x - prevPt.x
            let dy = pt.y - prevPt.y
            let dz = pt.z - prevPt.z
            polyLength += sqrt(dx * dx + dy * dy + dz * dz)
            prevPt = pt
        }

        // #766: the old bounds (finite, >= chord, < pi*R) held for almost any point(atU:v:) that
        // stayed on a sphere of this size. Both values are Geom_SphericalSurface::Value driven the
        // same way in Scripts/repro/766-curve-integration-extrema-law.
        #expect(abs(straightDist - 58.094750193111253) < 1e-9, "chord \(straightDist)")
        #expect(abs(polyLength - 80.002912490963794) < 1e-9, "polyline \(polyLength)")
        #expect(polyLength > straightDist)
    }
}
