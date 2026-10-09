import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe BuildShape Tests")
struct LocOpeBuildShapeTests {
    @Test("Build shape from box faces")
    func buildFromFaces() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.builtFromFaces()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}
