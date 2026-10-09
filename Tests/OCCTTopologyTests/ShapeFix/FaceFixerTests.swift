import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - FaceFixer")
struct FaceFixerTests {

    @Test func fixBoxFace() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                if let fixer = FaceFixer(face: faces[0]) {
                    fixer.perform()
                    fixer.fixOrientation()
                    fixer.fixAddNaturalBound()
                    fixer.fixMissingSeam()
                    fixer.fixSmallAreaWire()
                    let f = fixer.face
                    #expect(f != nil)
                }
            }
        }
    }
}
