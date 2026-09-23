import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Boolean Expansion")
struct BooleanExpansionTests {

    @Test func sectionWithTolerance() {
        if let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let sec = box1.section(with: box2, tolerance: 0.001)
            #expect(sec != nil)
        }
    }

    @Test func splitMulti() {
        if let box = Shape.box(width: 20, height: 20, depth: 20),
            let tool = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let split = box.split(tools: [tool])
            #expect(split != nil)
        }
    }

    @Test func cutWithHistory() {
        if let box1 = Shape.box(width: 20, height: 20, depth: 20),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        {
            let result = box1.subtractedWithHistory(box2)
            #expect(result != nil)
            if let r = result {
                #expect(r.shape.isValid)
                // History tracking should report modifications
                let _ = r.hasDeleted
                let _ = r.hasModified
                let _ = r.hasGenerated
            }
        }
    }

    // The tolerance argument this test used to pass is gone: BRepAlgoAPI_Defeaturing never read
    // it, so the overload that took one is deprecated. Issue497DefeaturingTests covers that. #497
    @Test func defeature() {
        // #766: every assertion here used to sit inside `if let` of the fillet, of `faces.count > 6`
        // and of the defeature result ("may or may not succeed"), so a defeature that returned nil
        // passed. The kernel does succeed (Scripts/repro/766-modeling-boolean-expansion): the r=2
        // filleted 20mm box has 26 faces, BRepAlgoAPI_Defeaturing removes ordinals 6 and 7 and
        // returns a valid solid of 25 faces whose volume grows by 1.791585.
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
            let f = box.filleted(radius: 2.0)
        else {
            Issue.record("fixture failed")
            return
        }
        let faces = f.subShapes(ofType: .face)
        #expect(faces.count == 26)
        guard faces.count > 7 else { return }
        let filletFaces = Array(faces[6...7])
        guard let r = f.defeature(faces: filletFaces) else {
            Issue.record("defeaturing two fillet faces returned nil")
            return
        }
        #expect(r.isValid)
        #expect(r.subShapes(ofType: .face).count == 25)
        guard let before = f.volume, let after = r.volume else {
            Issue.record("volume computation failed")
            return
        }
        // Removing fillet faces can only add material back.
        #expect(abs((after - before) - 1.791585) < 1e-4)
    }
}
