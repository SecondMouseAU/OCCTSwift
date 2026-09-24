import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, Surface queries")
struct SurfaceQueriesV123Tests {

    @Test("Cylinder U period")
    func cylinderUPeriod() {
        // #766: two nested `if let`s let a nil cylinder or a nil period pass.
        let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5.0)
        #expect(cyl != nil)
        if let s = cyl {
            let uPeriod = s.uPeriod
            #expect(uPeriod != nil)
            if let p = uPeriod {
                #expect(abs(p - 2.0 * .pi) < 1e-10)
            }
        }
    }

    @Test("Plane has no period")
    func planePeriod() {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(plane != nil)
        if let s = plane {
            let uPeriod = s.uPeriod
            let vPeriod = s.vPeriod
            // Plane is not periodic
            #expect(uPeriod == nil || uPeriod == 0.0)
            #expect(vPeriod == nil || vPeriod == 0.0)
        }
    }
}
