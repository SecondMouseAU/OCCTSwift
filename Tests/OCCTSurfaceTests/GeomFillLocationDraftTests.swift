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
        // #766: nested `if let`s around `matrix.count == 9`, which any matrix passes (an
        // ignored draft angle included). GeomFill_LocationDraft(+Z, pi/12) on the X axis at 5
        // gives this matrix and translation (5, 0, 0), see Scripts/repro/766-geomfill-c/.
        let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))?.trimmed(from: 0, to: 10)
        #expect(path != nil)
        guard let path else { return }
        #expect(loc.setCurve(path))
        let result = loc.evaluate(at: 5.0)
        #expect(result != nil)
        if let result {
            let expected: [Double] = [0, 0, -1, -0.965925826289, -0.258819045103, 0, -0.258819045103, 0.965925826289, 0]
            #expect(result.matrix.count == 9)
            #expect(zip(result.matrix, expected).allSatisfy { abs($0 - $1) < 1e-9 })
            #expect(simd_length(result.translation - SIMD3(5, 0, 0)) < 1e-9)
        }
    }

    @Test("set angle")
    func setAngle() {
        let loc = LocationDraft.create(direction: SIMD3(0, 0, 1), angle: .pi / 6)
        // #766: this was `#expect(Bool(true))`, it could not fail. With a curve set, the angle
        // must reach the kernel: GeomFill_LocationDraft set to pi/4 gives this matrix at 5
        // (pi/6 would give -0.866 / -0.5 in the second row), see Scripts/repro/766-geomfill-c/.
        let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))?.trimmed(from: 0, to: 10)
        #expect(path != nil)
        guard let path else { return }
        #expect(loc.setCurve(path))
        loc.setAngle(.pi / 4)
        let result = loc.evaluate(at: 5.0)
        #expect(result != nil)
        if let result {
            let expected: [Double] = [0, 0, -1, -0.707106781187, -0.707106781187, 0, -0.707106781187, 0.707106781187, 0]
            #expect(zip(result.matrix, expected).allSatisfy { abs($0 - $1) < 1e-9 })
        }
    }
}
