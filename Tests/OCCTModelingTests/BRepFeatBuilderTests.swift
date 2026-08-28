import Testing
import simd

@testable import OCCTSwift

@Suite("BRepFeat Builder")
struct BRepFeatBuilderTests {
    @Test("Feature fuse two boxes")
    func featFuse() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        else { return }
        let result = box1.featFuse(with: box2)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }

    @Test("Feature cut box from box")
    func featCut() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        else { return }
        let result = box1.featCut(with: box2)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
        }
    }
}
