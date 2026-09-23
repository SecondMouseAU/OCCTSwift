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
        #expect(abs(area - 4 * Double.pi * Double.pi * 10 * 2) < 1.0)
    }

    @Test func torusVolume() throws {
        let t = try makeTorus()
        let vol = t.torusProperties.volume
        #expect(abs(vol - 2 * Double.pi * Double.pi * 10 * 4) < 1.0)
    }
}
