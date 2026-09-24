import Testing
import simd

@testable import OCCTSwift

// MARK: - Fix #53: PipeShell closed spine+profile segfault

@Suite("PipeShell Closed Geometry Fix")
struct PipeShellClosedGeometryTests {

    // #766: both tests nested every expectation behind `if let`s (four levels in the first), and
    // the second's only check was `isValid` on an optional result. The kernel builds both: a torus
    // of volume 2 pi^2 * 15 * 3^2 = 2664.79 through BRepFill_PipeShell, and through
    // BRepOffsetAPI_MakePipe a valid closed shell of area 4 pi^2 * 10 * 2 = 789.57. See
    // Scripts/repro/766-pipe-shell/.

    @Test func circularSpineCircularProfile() {
        // This combination previously caused SEGV in BuildHistory
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 15)
        let profile = Wire.circle(origin: SIMD3(15, 0, 0), normal: SIMD3(0, 1, 0), radius: 3)
        let spineShape = spine.flatMap { Shape.fromWire($0) }
        let profileShape = profile.flatMap { Shape.fromWire($0) }
        let builder = spineShape.flatMap { PipeShellBuilder(spine: $0) }
        #expect(builder != nil && profileShape != nil)
        guard let builder, let profileShape else { return }
        builder.setFrenet(true)
        builder.add(profile: profileShape)
        // This should NOT crash (history disabled by default)
        let ok = builder.build()
        #expect(ok)
        let shape = builder.shape
        #expect(shape != nil)
        if let shape {
            #expect(shape.isValid)
            // Torus volume 2 pi^2 R r^2 = 2664.79; was `> 1000`.
            #expect(abs((shape.volume ?? 0) - 2664.793188294127) < 1e-6)
        }
    }

    @Test func highLevelPipeShellClosed() {
        // Test the high-level Shape.sweep with closed wires
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10)
        let profile = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 2)
        #expect(spine != nil && profile != nil)
        if let spine = spine, let profile = profile {
            let result = Shape.sweep(profile: profile, along: spine)
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
                #expect(abs((r.surfaceArea ?? 0) - 789.56835208714881) < 1e-6)
            }
        }
    }
}
