import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_PipeShell Extension Tests")
struct PipeShellExtensionTests {

    @Test func pipeShellMaxDegreeAndSegments() {
        // Create a simple spine wire and add a profile so it's ready
        if let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10),
            let profile = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0), radius: 1)
        {
            if let sw = Shape.fromWire(spine), let pw = Shape.fromWire(profile) {
                if let psb = PipeShellBuilder(spine: sw) {
                    psb.setMaxDegree(6)
                    psb.setMaxSegments(100)
                    psb.setForceApproxC1(true)
                    psb.setFrenet()
                    psb.add(profile: pw)
                    #expect(psb.isReady)
                }
            }
        }
    }

    @Test func pipeShellErrorAndShapes() {
        // Build a simple pipe shell
        if let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10),
            let profile = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0), radius: 1)
        {
            if let sw = Shape.fromWire(spine), let pw = Shape.fromWire(profile) {
                if let psb = PipeShellBuilder(spine: sw) {
                    psb.setFrenet()
                    psb.add(profile: pw)
                    psb.setMaxDegree(8)
                    if psb.build() {
                        let err = psb.errorOnSurface
                        #expect(err >= 0)
                        // first/last shapes may be nil for closed pipes
                        let _ = psb.firstShape
                        let _ = psb.lastShape
                    }
                }
            }
        }
    }
}
