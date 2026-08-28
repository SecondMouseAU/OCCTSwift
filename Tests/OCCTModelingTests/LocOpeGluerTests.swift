import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.72.0: TKFeat remainder + TKFillet

@Suite("LocOpe_Gluer Tests")
struct LocOpeGluerTests {
    @Test("glue two boxes by face")
    func glueByFace() {
        let box1 = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(10, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            let faces1 = b1.subShapes(ofType: .face)
            let faces2 = b2.subShapes(ofType: .face)
            for f1 in faces1 {
                for f2 in faces2 {
                    let result = b1.locOpeGlue(b2, facePairs: [(base: f1, glued: f2)])
                    if let r = result {
                        let rFaces = r.subShapes(ofType: .face)
                        #expect(rFaces.count < faces1.count + faces2.count)
                        return
                    }
                }
            }
        }
    }
}
