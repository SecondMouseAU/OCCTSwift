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
        // #766: was non-nil only. The plane found is z = 0 (BRepLib_FindSurface, see
        // Scripts/repro/766-convert-check-evolved-revol/).
        if let surface {
            #expect((surface.projectPoint(SIMD3(1, 2, 0))?.distance ?? -1) < 1e-12)
            #expect(abs((surface.projectPoint(SIMD3(1, 2, 7))?.distance ?? -1) - 7) < 1e-12)
        }
    }
}
