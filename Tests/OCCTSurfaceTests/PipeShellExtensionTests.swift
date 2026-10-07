import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFill_PipeShell Extension Tests")
struct PipeShellExtensionTests {

    // #766: both tests sat behind three `if let`s, and the second behind `if psb.build()`, so a
    // build that failed passed; it checked `err >= 0` and discarded first/last shape. The kernel
    // builds this set-up, reports ErrorOnSurface 0, gives a first and a last section, and sweeps
    // a shell of area 254.095 (the profile plane contains the spine tangent, so the shell encloses
    // no volume). See Scripts/repro/766-pipe-shell/.
    private func parts() -> (spine: Shape, profile: Shape)? {
        let sw = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10).flatMap { Shape.fromWire($0) }
        let pw = Wire.circle(origin: SIMD3(10, 0, 0), normal: SIMD3(1, 0, 0), radius: 1)
            .flatMap { Shape.fromWire($0) }
        #expect(sw != nil && pw != nil)
        guard let sw, let pw else { return nil }
        return (sw, pw)
    }

    @Test func pipeShellMaxDegreeAndSegments() {
        guard let p = parts() else { return }
        let psb = PipeShellBuilder(spine: p.spine)
        #expect(psb != nil)
        if let psb {
            psb.setMaxDegree(6)
            psb.setMaxSegments(100)
            psb.setForceApproxC1(true)
            psb.setFrenet()
            psb.add(profile: p.profile)
            #expect(psb.isReady)
        }
    }

    @Test func pipeShellErrorAndShapes() {
        guard let p = parts() else { return }
        let psb = PipeShellBuilder(spine: p.spine)
        #expect(psb != nil)
        if let psb {
            psb.setFrenet()
            psb.add(profile: p.profile)
            psb.setMaxDegree(8)
            #expect(psb.build())
            #expect(psb.errorOnSurface == 0)
            #expect(psb.firstShape != nil)
            #expect(psb.lastShape != nil)
            #expect(abs((psb.shape?.surfaceArea ?? 0) - 254.09525268599498) < 1e-6)
        }
    }
}
