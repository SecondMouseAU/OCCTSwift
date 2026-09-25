import Foundation
import Testing
import simd

@testable import OCCTSwift

// Each fixture is required rather than `if let`-bound: an `if let` with no `else` passed with no
// assertion run at all when construction failed (#766).
@Suite("Geom_ToroidalSurface Properties")
struct GeomTorus3DTests {
    private func makeTorus() throws -> Surface {
        try #require(
            Surface.torus(origin: .zero, axis: SIMD3(0, 0, 1), majorRadius: 10, minorRadius: 2))
    }

    @Test func torusRadii() throws {
        let t = try makeTorus()
        #expect(abs(t.torusProperties.majorRadius - 10) < 1e-6)
        #expect(abs(t.torusProperties.minorRadius - 2) < 1e-6)
    }

    @Test func torusSetRadii() throws {
        let t = try makeTorus()
        #expect(t.torusProperties.setMajorRadius(15))
        #expect(abs(t.torusProperties.majorRadius - 15) < 1e-6)
        #expect(t.torusProperties.setMinorRadius(3))
        #expect(abs(t.torusProperties.minorRadius - 3) < 1e-6)
    }

    @Test func torusArea() throws {
        let t = try makeTorus()
        let area = t.torusProperties.area
        // 4 pi^2 R r = 789.5683520871487; the kernel returns it to the last digit
        // (Scripts/repro/766-geom-swept-torus/transcript.txt), and 1.0 let a 0.1 percent error by.
        #expect(abs(area - 4 * Double.pi * Double.pi * 10 * 2) < 1e-9)
    }

    @Test func torusVolume() throws {
        let t = try makeTorus()
        let vol = t.torusProperties.volume
        // 2 pi^2 R r^2 = 789.5683520871487; the kernel is within 1.2e-13 of it (same transcript).
        #expect(abs(vol - 2 * Double.pi * Double.pi * 10 * 4) < 1e-9)
    }
}
