import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTools_SurfaceSet Tests")
struct GeomToolsSurfaceSetTests {
    @Test func serializeDeserializeSurfaces() {
        // #766: three nested `if let`s, so a nil at any stage passed, and the count alone passed
        // surfaces read back in the wrong order. GeomTools_SurfaceSet round-trips both, in
        // order, see Scripts/repro/766-offset-plate-helix/.
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 3.0)
        #expect(plane != nil && cyl != nil)
        guard let plane, let cyl else { return }
        let data = Surface.serializeSurfaces([plane, cyl])
        #expect(data != nil)
        guard let data else { return }
        #expect(!data.isEmpty)
        let surfaces = Surface.deserializeSurfaces(data)
        #expect(surfaces?.count == 2)
        if let surfaces, surfaces.count == 2 {
            #expect(simd_length(surfaces[0].point(atU: 1, v: 2) - SIMD3(1, 2, 0)) < 1e-12)
            #expect(simd_length(surfaces[1].point(atU: 0, v: 5) - SIMD3(3, 0, 5)) < 1e-12)
        }
    }

    // #1512: GeomTools_SurfaceSet::Add dedups by underlying-object identity ("new or existing"
    // index), so two array elements sharing one underlying Geom_Surface used to be silently
    // collapsed to a single stored entry instead of refusing the batch. Passing the same
    // instance twice is the issue's own minimal fixture: both elements alias the identical
    // Geom_Surface handle.
    @Test func duplicateHandleRefusesTheBatch() {
        let plane = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))
        #expect(plane != nil)  // #766: a nil plane used to pass
        if let plane {
            #expect(Surface.serializeSurfaces([plane, plane]) == nil)
        }
    }
}
