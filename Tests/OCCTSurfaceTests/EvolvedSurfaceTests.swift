import Testing
import simd

@testable import OCCTSwift

@Suite("Evolved Surface Tests")
struct EvolvedSurfaceTests {

    @Test("Simple evolved shape")
    func simpleEvolved() {
        // Create a simple spine (quarter circle)
        let spine = Wire.arc(center: SIMD3(0, 0, 0), radius: 20, startAngle: 0, endAngle: .pi / 2)!

        // Create a small profile
        let profile = Wire.rectangle(width: 2, height: 2)!

        let evolved = Shape.evolved(spine: spine, profile: profile)
        // #766: this was `if let evolved { #expect(evolved.isValid) }`, and for this input the
        // kernel always refuses: BRepOffsetAPI_MakeEvolved throws "Geom_TrimmedCurve::U1 == U2" on
        // an open arc spine with a profile in the spine's own plane, so the body never ran. The
        // refusal is pinned, and a case the kernel does build is added below.
        #expect(evolved == nil)

        // A closed 20 x 20 square spine with a profile in its local XZ frame: a 2-long segment
        // rising at 45 degrees. The kernel builds a valid shell of area 160 (a frustum band).
        // Values from Scripts/repro/766-convert-check-evolved-revol/.
        let square = Wire.rectangle(width: 20, height: 20)
        let segment = Wire.path([SIMD3(0, 0, 0), SIMD3(2, 0, 2)])
        #expect(square != nil && segment != nil)
        if let square, let segment {
            let band = Shape.evolved(spine: square, profile: segment)
            #expect(band != nil)
            if let band {
                #expect(band.isValid)
                #expect(abs((band.surfaceArea ?? 0) - 160) < 1e-9)
            }
        }
    }
}
