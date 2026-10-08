import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, PipeShell extensions")
struct PipeShellExtensionsTests {

    @Test("GetStatus")
    func getStatus() {
        let spine = Wire.circle(origin: .zero, normal: SIMD3(0, 0, 1), radius: 10.0)
        if let s = spine, let ss = Shape.fromWire(s) {
            if let ps = PipeShellBuilder(spine: ss) {
                let profile = Wire.circle(origin: .zero, normal: SIMD3(1, 0, 0), radius: 2.0)
                if let p = profile, let pp = Shape.fromWire(p) {
                    ps.add(profile: pp)
                    let status = ps.status
                    // Status should be a valid enum value
                    #expect(status.rawValue >= 0 && status.rawValue <= 3)
                }
            }
        }
    }

    @Test("Simulate sections")
    func simulate() {
        if let spineWire = Wire.rectangle(width: 10, height: 10),
            let spine = Shape.fromWire(spineWire)
        {
            if let ps = PipeShellBuilder(spine: spine) {
                let profile = Wire.circle(
                    origin: SIMD3(0, 0, 0), normal: SIMD3(1, 0, 0), radius: 1.0)
                if let p = profile, let pp = Shape.fromWire(p) {
                    ps.setFrenet()
                    ps.add(profile: pp)
                    let sections = ps.simulate(numberOfSections: 5)
                    #expect(sections.count > 0)
                }
            }
        }
    }
}
