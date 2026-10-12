import Foundation
import Testing

@testable import OCCTSwift

@Suite("Draft Modification Tests")
struct DraftModificationTests {

    // Face 0 of the cube is a side wall, pulled along +z with the neutral plane at z = 0. A
    // 10 degree draft tilts the wall about its base, so the 10 mm wall leans out by
    // 10 * tan(10 deg) at the top and the solid loses a wedge of 0.5 * 10 * 10 * tan(10 deg)
    // = 88.16 (analytic 911.8365..., measured 911.8365096457674 on kernel.6).
    @Test func draftFace() throws {
        let box = try #require(
            Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let result = try #require(
            box.draftModification(
                faceIndex: 0, direction: SIMD3(0, 0, 1),
                angle: .pi / 18,
                neutralPlaneOrigin: SIMD3(0, 0, 0),
                neutralPlaneNormal: SIMD3(0, 0, 1)))
        #expect(result.isValid)
        let expected = 1000.0 - 0.5 * 10.0 * 10.0 * tan(Double.pi / 18) * 10.0
        #expect(abs((result.volume ?? -1) - expected) < 1e-6)
        #expect(result.faces().count == 6)

        // A face parallel to the neutral plane (face 4, the z = 0 face) cannot be drafted about
        // it, and the call says so rather than returning the input.
        #expect(
            box.draftModification(
                faceIndex: 4, direction: SIMD3(0, 0, 1),
                angle: .pi / 18,
                neutralPlaneOrigin: SIMD3(0, 0, 0),
                neutralPlaneNormal: SIMD3(0, 0, 1)) == nil)
    }
}
