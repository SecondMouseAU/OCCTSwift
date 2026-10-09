import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - ThickSolid Options")
struct ThickSolidOptionsTests {

    @Test func thickSolidWithOptions() {
        if let box = Shape.box(width: 20, height: 20, depth: 20) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let result = box.thickSolid(
                    facesToRemove: [faces[0]],
                    offset: -2.0,
                    tolerance: 1e-3,
                    joinType: .arc)
                #expect(result != nil)
                if let r = result {
                    #expect(r.isValid)
                    if let vol = r.volume {
                        #expect(vol > 0)
                    }
                }
            }
        }
    }
}
