import Testing

@testable import OCCTSwift

@Suite("Find Surface")
struct FindSurfaceTests {
    @Test("Find plane from flat wire")
    func findPlaneFromWire() {
        let rect = Wire.rectangle(width: 10, height: 5)!
        let face = Shape.face(from: rect)!
        let surface = face.findSurface()
        #expect(surface != nil)
    }
}
