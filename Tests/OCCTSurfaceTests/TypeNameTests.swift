import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Curve/Surface Type Names")
struct TypeNameTests {

    @Test func lineTypeName() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let name = line.typeName
            #expect(name != nil)
            if let n = name {
                #expect(n.contains("Line"))
            }
        }
    }

    @Test func bsplineTypeName() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0)]
        if let curve = Curve3D.fit(points: points) {
            let name = curve.typeName
            #expect(name != nil)
            if let n = name {
                #expect(n.contains("BSpline"))
            }
        }
    }

    @Test func line2dTypeName() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let name = line.typeName
            #expect(name != nil)
            if let n = name {
                #expect(n.contains("Line"))
            }
        }
    }

    @Test func sphereTypeName() {
        if let sphere = Surface.sphere(center: SIMD3(0, 0, 0), radius: 5) {
            let name = sphere.typeName
            #expect(name != nil)
            if let n = name {
                #expect(n.contains("Spherical"))
            }
        }
    }

    @Test func planeTypeName() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let name = plane.typeName
            #expect(name != nil)
            if let n = name {
                #expect(n.contains("Plane"))
            }
        }
    }
}
