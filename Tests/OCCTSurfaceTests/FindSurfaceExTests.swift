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
    }

    @Test("Plane-only mode works")
    func planeOnlyMode() {
        let wire = Wire.rectangle(width: 10, height: 10)!
        let wireShape = Shape.fromWire(wire)!
        let surface = wireShape.findSurfaceEx(onlyPlane: true)
        #expect(surface != nil)
    }
}
