import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - Curve/Surface Type Names")
struct TypeNameTests {

    // #766: each test sat inside `if let` and matched a substring. The names are the kernel's own
    // DynamicType()->Name() for the classes these factories build, so they are now pinned exactly.

    @Test func lineTypeName() {
        let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))
        #expect(line?.typeName == "Geom_Line")
    }

    @Test func bsplineTypeName() {
        let points = [SIMD3(0.0, 0.0, 0.0), SIMD3(1.0, 1.0, 0.0), SIMD3(2.0, 0.0, 0.0)]
        #expect(Curve3D.fit(points: points)?.typeName == "Geom_BSplineCurve")
    }

    @Test func line2dTypeName() {
        #expect(Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0))?.typeName == "Geom2d_Line")
    }

    @Test func sphereTypeName() {
        #expect(Surface.sphere(center: SIMD3(0, 0, 0), radius: 5)?.typeName == "Geom_SphericalSurface")
    }

    @Test func planeTypeName() {
        #expect(Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))?.typeName == "Geom_Plane")
    }
}
