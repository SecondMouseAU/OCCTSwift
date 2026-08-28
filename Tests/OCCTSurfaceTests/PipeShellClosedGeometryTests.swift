import Testing
import simd

@testable import OCCTSwift

// MARK: - Fix #53: PipeShell closed spine+profile segfault

@Suite("PipeShell Closed Geometry Fix")
struct PipeShellClosedGeometryTests {
    @Test func circularSpineCircularProfile() {
        // This combination previously caused SEGV in BuildHistory
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 15)
        if let spine = spine {
            let spineShape = Shape.fromWire(spine)
            if let spineShape = spineShape {
                if let builder = PipeShellBuilder(spine: spineShape) {
                    let profile = Wire.circle(
                        origin: SIMD3(15, 0, 0), normal: SIMD3(0, 1, 0), radius: 3)
                    if let profile = profile {
                        let profileShape = Shape.fromWire(profile)
                        if let profileShape = profileShape {
                            builder.setFrenet(true)
                            builder.add(profile: profileShape)
                            // This should NOT crash (history disabled by default)
                            let ok = builder.build()
                            #expect(ok)
                            if let shape = builder.shape {
                                #expect(shape.isValid)
                                if let vol = shape.volume {
                                    // Torus volume ~ 2*pi^2*R*r^2 ~ 2*pi^2*15*9 ~ 2664
                                    #expect(vol > 1000)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func highLevelPipeShellClosed() {
        // Test the high-level Shape.sweep with closed wires
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10)
        let profile = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(0, 1, 0), radius: 2)
        if let spine = spine, let profile = profile {
            let result = Shape.sweep(profile: profile, along: spine)
            // May or may not succeed depending on sweep mode, but should NOT crash
            if let r = result {
                #expect(r.isValid)
            }
        }
    }
}
