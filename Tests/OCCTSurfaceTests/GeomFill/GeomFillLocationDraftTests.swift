import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_LocationDraft")
struct GeomFillLocationDraftTests {
    @Test("create with direction and angle")
    func createLocationDraft() {
        let loc = LocationDraft.create(direction: SIMD3(0, 0, 1), angle: .pi / 6)
        let dir = loc.direction
        #expect(abs(dir.z - 1.0) < 1e-6)
    }

    @Test("set curve and evaluate")
    func setCurveAndEvaluate() {
        let loc = LocationDraft.create(direction: SIMD3(0, 0, 1), angle: .pi / 12)
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let path = line.trimmed(from: 0, to: 10)
        {
            loc.setCurve(path)
            if let result = loc.evaluate(at: 5.0) {
                #expect(result.matrix.count == 9)
            }
        }
    }

    @Test("set angle")
    func setAngle() {
        let loc = LocationDraft.create(direction: SIMD3(0, 0, 1), angle: .pi / 6)
        loc.setAngle(.pi / 4)
        // Just verify no crash
        #expect(Bool(true))
    }
}
