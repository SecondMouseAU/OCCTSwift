import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTools_SurfaceSet Tests")
struct GeomToolsSurfaceSetTests {
    @Test func serializeDeserializeSurfaces() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)),
            let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 3.0)
        {
            if let data = Surface.serializeSurfaces([plane, cyl]) {
                #expect(!data.isEmpty)
                if let surfaces = Surface.deserializeSurfaces(data) {
                    #expect(surfaces.count == 2)
                }
            }
        }
    }
}
