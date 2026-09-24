import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_GuideTrihedronAC")
struct GeomFillGuideTrihedronACTests {
    @Test("create with guide and path")
    func createAndSetPath() {
        // #766: this ended in `#expect(Bool(true))` inside two `if let`s, so it could not fail.
        // GeomFill_GuideTrihedronAC accepts the path (SetCurve true) and at 5 gives
        // T (1, 0, 0), N (0, 1, 0) toward the guide, B (0, 0, 1), see Scripts/repro/766-geomfill-c/.
        let guide = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0))?.trimmed(from: 0, to: 10)
        let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0))?.trimmed(from: 0, to: 10)
        #expect(guide != nil && path != nil)
        guard let guide, let path else { return }
        let triAC = GuideTrihedronAC.create(guideCurve: guide)
        #expect(triAC.setCurve(path))
        let frame = triAC.evaluate(at: 5.0)
        #expect(frame != nil)
        if let frame {
            #expect(simd_length(frame.tangent - SIMD3(1, 0, 0)) < 1e-9)
            #expect(simd_length(frame.normal - SIMD3(0, 1, 0)) < 1e-9)
            #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
        }
    }

    @Test("D0 evaluation")
    func d0Evaluation() {
        if let guide = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)),
            let guideTrimmed = guide.trimmed(from: 0, to: 10)
        {
            let triAC = GuideTrihedronAC.create(guideCurve: guideTrimmed)
            if let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
                let pathTrimmed = path.trimmed(from: 0, to: 10)
            {
                triAC.setCurve(pathTrimmed)
                // #766: `|t.x| > 0.3` inside `if let` never read N or B; pinned to the kernel
                // frame, see Scripts/repro/766-geomfill-c/.
                let frame = triAC.evaluate(at: 5.0)
                #expect(frame != nil)
                if let frame {
                    #expect(abs(frame.tangent.x) > 0.3)
                    #expect(simd_length(frame.normal - SIMD3(0, 1, 0)) < 1e-9)
                    #expect(simd_length(frame.binormal - SIMD3(0, 0, 1)) < 1e-9)
                }
            }
        }
    }

    /// `evaluate(at:)`'s three components are only distinguished by the labels
    /// `evaluateGuideTrihedronD0` (`SweepGuideTypes.swift`) attaches at the call site, not by any
    /// difference the type system enforces (#908, following #903/#904). `d0Evaluation()` above
    /// only asserts `tangent.x`, which never reads `normal`/`binormal` at all, so a pairwise swap
    /// among the three would not necessarily fail it. Orthonormality alone is symmetric under a
    /// normal/binormal swap too, so this checks the frame is right-handed
    /// (`binormal == tangent x normal`), which a swap of any two of the three breaks.
    @Test("D0 evaluation returns an orthonormal, right-handed frame (#908)")
    func d0EvaluationIsOrthonormalRightHanded() throws {
        let guide = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))
        let guideTrimmed = try #require(guide.trimmed(from: 0, to: 10))
        let path = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let pathTrimmed = try #require(path.trimmed(from: 0, to: 10))
        let triAC = GuideTrihedronAC.create(guideCurve: guideTrimmed)
        triAC.setCurve(pathTrimmed)
        let frame = try #require(triAC.evaluate(at: 5.0))

        let t = frame.tangent
        let n = frame.normal
        let b = frame.binormal
        #expect(abs(simd_length(t) - 1) < 1e-6)
        #expect(abs(simd_length(n) - 1) < 1e-6)
        #expect(abs(simd_length(b) - 1) < 1e-6)
        #expect(abs(simd_dot(t, n)) < 1e-6)
        #expect(abs(simd_dot(t, b)) < 1e-6)
        #expect(abs(simd_dot(n, b)) < 1e-6)
        #expect(simd_length(simd_cross(t, n) - b) < 1e-6)
    }
}
