import Testing
import simd

@testable import OCCTSwift

@Suite("GeomFill_GuideTrihedronPlan")
struct GeomFillGuideTrihedronPlanTests {
    @Test("create and evaluate")
    func createAndEvaluate() {
        if let guide = Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)),
            let guideTrimmed = guide.trimmed(from: 0, to: 10)
        {
            let triPlan = GuideTrihedronPlan.create(guideCurve: guideTrimmed)
            if let path = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
                let pathTrimmed = path.trimmed(from: 0, to: 10)
            {
                triPlan.setCurve(pathTrimmed)
                let frame = triPlan.evaluate(at: 5.0)
                #expect(frame != nil)
            }
        }
    }

    /// `createAndEvaluate()` above only checks non-nil, so it could not catch a pairwise swap
    /// among `tangent`/`normal`/`binormal` at all (#908, following #903/#904). Same reasoning and
    /// same right-handedness check as `GeomFillGuideTrihedronACTests`'s sibling test.
    @Test("evaluate(at:) returns an orthonormal, right-handed frame (#908)")
    func evaluateIsOrthonormalRightHanded() throws {
        let guide = try #require(Curve3D.line(through: SIMD3(0, 5, 0), direction: SIMD3(1, 0, 0)))
        let guideTrimmed = try #require(guide.trimmed(from: 0, to: 10))
        let path = try #require(Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)))
        let pathTrimmed = try #require(path.trimmed(from: 0, to: 10))
        let triPlan = GuideTrihedronPlan.create(guideCurve: guideTrimmed)
        triPlan.setCurve(pathTrimmed)
        let frame = try #require(triPlan.evaluate(at: 5.0))

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
