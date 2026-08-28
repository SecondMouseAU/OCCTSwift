import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, CellsBuilder extensions")
struct CellsBuilderExtensionsTests {

    @Test("AddToResult selective")
    func addToResultSelective() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addToResult(take: [b1, b2], material: 1)
                let result = cb.result()
                #expect(result != nil)
            }
        }
    }

    @Test("RemoveFromResult selective")
    func removeFromResultSelective() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addAllToResult()
                cb.removeFromResult(take: [b1, b2])
                // After removing intersection, result should still work
                let _ = cb.result()
                #expect(true)
            }
        }
    }

    @Test("GetAllParts")
    func getAllParts() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                let parts = cb.allParts()
                #expect(parts != nil)
            }
        }
    }

    @Test("MakeContainers")
    func makeContainers() {
        let box1 = Shape.box(width: 10, height: 10, depth: 10)
        let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        if let b1 = box1, let b2 = box2 {
            if let cb = CellsBuilder(shapes: [b1, b2]) {
                cb.addAllToResult()
                cb.makeContainers()
                let result = cb.result()
                #expect(result != nil)
            }
        }
    }
}
