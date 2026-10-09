import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, PipeShell extensions")
struct PipeShellExtensionsTests {

    // #766: both tests sat behind nested `if let`s, and checked only that the status was one of
    // the four enum values (true for any status) or that simulate returned something. The kernel
    // reports PipeOk for this set-up and returns exactly the five sections asked for. See
    // Scripts/repro/766-pipe-shell/.

    @Test("GetStatus")
    func getStatus() {
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10.0)
        let profile = Wire.circle(origin: .zero, normal: SIMD3(1, 0, 0), radius: 2.0)
        let ps = spine.flatMap { Shape.fromWire($0) }.flatMap { PipeShellBuilder(spine: $0) }
        let pp = profile.flatMap { Shape.fromWire($0) }
        #expect(ps != nil && pp != nil)
        if let ps, let pp {
            ps.add(profile: pp)
            #expect(ps.status == .ok)
        }
    }

    @Test("Simulate sections")
    func simulate() {
        let spine = Wire.rectangle(width: 10, height: 10).flatMap { Shape.fromWire($0) }
        let ps = spine.flatMap { PipeShellBuilder(spine: $0) }
        let pp = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 1.0)
            .flatMap { Shape.fromWire($0) }
        #expect(ps != nil && pp != nil)
        if let ps, let pp {
            ps.setFrenet()
            ps.add(profile: pp)
            let sections = ps.simulate(numberOfSections: 5)
            #expect(sections.count == 5)
        }
    }
}
