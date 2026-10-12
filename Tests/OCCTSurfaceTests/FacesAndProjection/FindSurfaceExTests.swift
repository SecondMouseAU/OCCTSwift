import Testing

@testable import OCCTSwift

// MARK: - v0.40.0: Find Surface

@Suite("Find Surface Extended")
struct FindSurfaceExTests {
    @Test("Wire on plane finds surface")
    func wireOnPlane() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let surface = wireShape.findSurfaceEx()
        #expect(surface != nil)
        // `Wire.rectangle` lies in z = 0: a point of the plane is 0 from it and (3, 4, 7) is 7.
        if let surface {
            #expect(surface.projectPoint(SIMD3(3, 4, 0))?.distance == 0)
            #expect(abs((surface.projectPoint(SIMD3(3, 4, 7))?.distance ?? -1) - 7) < 1e-9)
        }
    }

    @Test("Plane-only mode works")
    func planeOnlyMode() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let surface = wireShape.findSurfaceEx(onlyPlane: true)
        #expect(surface != nil)
        if let surface {
            #expect(surface.projectPoint(SIMD3(3, 4, 0))?.distance == 0)
            #expect(abs((surface.projectPoint(SIMD3(3, 4, 7))?.distance ?? -1) - 7) < 1e-9)
        }

        // The control, so plane-only is not a flag that always answers a plane: a skew
        // four-point loop lies on no plane, and is refused.
        if let bent = Wire.polygon3D(
            [SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 5)], closed: true),
            let bentShape = Shape.fromWire(bent)
        {
            #expect(bentShape.findSurfaceEx(onlyPlane: true) == nil)
        } else {
            Issue.record("skew wire fixture")
        }
    }
}
