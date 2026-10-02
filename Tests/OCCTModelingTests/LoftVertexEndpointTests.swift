import Testing
import simd

@testable import OCCTSwift

@Suite("Loft Vertex Endpoints")
struct LoftVertexEndpointTests {
    @Test("Cone: circle lofted to vertex point")
    func coneFromCircle() throws {
        let circle = try #require(Wire.circle(radius: 5))
        let cone = try #require(
            Shape.loft(
                profiles: [circle], solid: true, ruled: true,
                lastVertex: SIMD3(0, 0, 10)))
        #expect(cone.isValid)
        let volume = try #require(cone.volume)
        #expect(volume > 0)
        // #766: `volume > 0` holds for any solid. Pinned to the kernel
        // (Scripts/repro/766-modeling-loft-vertex-endpoint, transcript-evidence-fix.txt): the
        // loft is a solid of 2 faces whose volume is the analytic cone, pi * 5^2 * 10 / 3.
        #expect(cone.faceCount == 2)
        #expect(abs(volume - Double.pi * 25 * 10 / 3) < 1e-6)
    }

    @Test("Bicone: vertex-circle-vertex")
    func bicone() throws {
        let circle = try #require(Wire.circle(radius: 10))
        let bicone = try #require(
            Shape.loft(
                profiles: [circle], solid: true, ruled: true,
                firstVertex: SIMD3(0, 0, -20),
                lastVertex: SIMD3(0, 0, 20)))
        // #766: this asserted only `bicone != nil`. Pinned to the kernel
        // (Scripts/repro/766-modeling-loft-vertex-endpoint, transcript-evidence-fix.txt): a valid
        // solid of 2 faces with the analytic bicone volume, 2 * pi * 10^2 * 20 / 3.
        #expect(bicone.isValid)
        #expect(bicone.faceCount == 2)
        let volume = try #require(bicone.volume)
        #expect(abs(volume - 2 * Double.pi * 100 * 20 / 3) < 1e-6)
    }

    @Test("Smooth cone tapering to point")
    func smoothCone() throws {
        let circle = try #require(Wire.circle(radius: 5))
        let shape = try #require(
            Shape.loft(
                profiles: [circle], solid: true, ruled: false,
                lastVertex: SIMD3(0, 0, 10)))
        // #766: this asserted only `shape != nil`. Pinned to the kernel
        // (Scripts/repro/766-modeling-loft-vertex-endpoint, transcript-evidence-fix.txt): the
        // smooth loft of one circle to an apex is the same valid 2-face cone as the ruled one.
        #expect(shape.isValid)
        #expect(shape.faceCount == 2)
        let volume = try #require(shape.volume)
        #expect(abs(volume - Double.pi * 25 * 10 / 3) < 1e-6)
    }
}
