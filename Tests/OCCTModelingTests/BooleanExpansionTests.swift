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
        if let box = Shape.box(width: 20, height: 20, depth: 20) {
            let filleted = box.filleted(radius: 2.0)
            if let f = filleted {
                // Try to remove fillet faces (defeaturing)
                let faces = f.subShapes(ofType: .face)
                if faces.count > 6 {
                    // Pick the extra faces (fillets)
                    let filletFaces = Array(faces.suffix(from: 6).prefix(2))
                    let result = f.defeature(faces: filletFaces)
                    // Defeaturing may or may not succeed on filleted box
                    if let r = result {
                        #expect(r.isValid)
                        // Removing fillet faces can only add material back.
                        if let before = f.volume, let after = r.volume {
                            #expect(after >= before - 1e-9)
                        }
                    }
                }
            }
        }
    }
}
