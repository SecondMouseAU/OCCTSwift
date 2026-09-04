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

    // #1512: GeomTools_SurfaceSet::Add dedups by underlying-object identity ("new or existing"
    // index), so two array elements sharing one underlying Geom_Surface used to be silently
    // collapsed to a single stored entry instead of refusing the batch. Passing the same
    // instance twice is the issue's own minimal fixture: both elements alias the identical
    // Geom_Surface handle.
    @Test func duplicateHandleRefusesTheBatch() {
        if let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(Surface.serializeSurfaces([plane, plane]) == nil)
        }
    }
}
