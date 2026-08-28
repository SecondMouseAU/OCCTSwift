import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_PipeShell Tests")
struct PipeShellTests {

    @Test func basicPipeShell() {
        // Spine: a straight wire along Z
        if let spineWire = Wire.rectangle(width: 10, height: 10) {
            let spine = Shape.fromWire(spineWire)
            if let spine = spine {
                // Profile: small circle
                if let profile = Wire.circle(
                    origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 1)
                {
                    let profileShape = Shape.fromWire(profile)
                    if let profileShape = profileShape {
                        if let builder = PipeShellBuilder(spine: spine) {
                            builder.setFrenet()
                            builder.add(profile: profileShape)
                            let built = builder.build()
                            if built {
                                let shape = builder.shape
                                #expect(shape != nil)
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func pipeShellIsReady() {
        if let spineWire = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10) {
            let spine = Shape.fromWire(spineWire)
            if let spine = spine {
                if let builder = PipeShellBuilder(spine: spine) {
                    // Not ready until profile is added
                    #expect(!builder.isReady)
                }
            }
        }
    }
}
