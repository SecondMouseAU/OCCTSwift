import Testing

@testable import OCCTSwift

// MARK: - v0.40.0: Find Surface

@Suite("Find Surface Extended")
struct FindSurfaceExTests {

    // #766: both tests asserted only non-nil, so any surface passed. BRepLib_FindSurface finds
    // the plane z = 0 through the centred square in both modes, see
    // Scripts/repro/766-convert-check-evolved-revol/.
    private func isPlaneZ0(_ s: Surface) -> Bool {
        (s.projectPoint(SIMD3(1, 2, 0))?.distance ?? -1) < 1e-12
            && abs((s.projectPoint(SIMD3(1, 2, 7))?.distance ?? -1) - 7) < 1e-12
    }
    @Test("Wire on plane finds surface")
    func wireOnPlane() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let surface = wireShape.findSurfaceEx()
        #expect(surface != nil)
        if let surface { #expect(isPlaneZ0(surface)) }
    }

    @Test("Plane-only mode works")
    func planeOnlyMode() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let surface = wireShape.findSurfaceEx(onlyPlane: true)
        #expect(surface != nil)
        if let surface { #expect(isPlaneZ0(surface)) }
    }
}
