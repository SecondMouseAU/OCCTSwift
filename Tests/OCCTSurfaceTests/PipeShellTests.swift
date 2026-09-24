import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_PipeShell Tests")
struct PipeShellTests {

    // #766: `basicPipeShell` nested its only expectation four `if`s deep, the last `if built`, so
    // a build that failed passed; it now requires the build and pins the swept shell's area
    // (206.143, from BRepFill_PipeShell on the same wires, Scripts/repro/766-pipe-shell/).

    @Test func basicPipeShell() {
        let spine = Wire.rectangle(width: 10, height: 10).flatMap { Shape.fromWire($0) }
        let profileShape = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 1)
            .flatMap { Shape.fromWire($0) }
        let builder = spine.flatMap { PipeShellBuilder(spine: $0) }
        #expect(builder != nil && profileShape != nil)
        guard let builder, let profileShape else { return }
        builder.setFrenet()
        builder.add(profile: profileShape)
        #expect(builder.build())
        let shape = builder.shape
        #expect(shape != nil)
        if let shape {
            #expect(abs((shape.surfaceArea ?? 0) - 206.14333993362635) < 1e-6)
        }
    }

    @Test func pipeShellIsReady() {
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10).flatMap { Shape.fromWire($0) }
        let builder = spine.flatMap { PipeShellBuilder(spine: $0) }
        #expect(builder != nil)
        if let builder {
            // Not ready until profile is added
            #expect(!builder.isReady)
        }
    }
}
