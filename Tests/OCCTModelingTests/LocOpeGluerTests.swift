import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.72.0: TKFeat remainder + TKFillet

@Suite("LocOpe_Gluer Tests")
struct LocOpeGluerTests {
    @Test("glue two boxes by face")
    func glueByFace() {
        // #766: this used `tryGlueAllFacePairs`, which keeps the FIRST pair LocOpe_Gluer accepts,
        // and returned silently when none did, so a glue that always failed passed. Probed
        // (Scripts/repro/766-modeling-locope-gluer), LocOpe_Gluer reports IsDone for all 36 pairs,
        // including pair (0, 0), box1's x=0 face against box2's x=10 face, which do not touch: its
        // result is invalid with volume -333.3. That pair is what the helper kept, and the only
        // assertion, 11 faces < 12, holds for every pair. Bind the pair that is actually
        // coincident, box1's x=10 face (index 1) against box2's x=10 face (index 0), and pin the
        // kernel's answer for it: a valid result of 11 faces.
        guard let b1 = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        else {
            Issue.record("box fixtures failed")
            return
        }
        let faces1 = b1.subShapes(ofType: .face)
        let faces2 = b2.subShapes(ofType: .face)
        #expect(faces1.count == 6 && faces2.count == 6)
        guard faces1.count == 6, faces2.count == 6 else { return }
        guard let result = b1.locOpeGlue(b2, facePairs: [(base: faces1[1], glued: faces2[0])])
        else {
            Issue.record("locOpeGlue returned nil for the coincident face pair")
            return
        }
        #expect(result.subShapes(ofType: .face).count == 11)
        #expect(result.isValid)
    }
}
