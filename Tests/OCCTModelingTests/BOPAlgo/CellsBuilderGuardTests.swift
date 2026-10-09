import Testing
import simd

@testable import OCCTSwift

@Suite("SEGV Guards, CellsBuilder empty inputs")
struct CellsBuilderGuardTests {

    @Test func emptyArrayReturnsNil() {
        let cb = CellsBuilder(shapes: [])
        #expect(cb == nil)
    }

    @Test func validShapesSucceeds() {
        guard let box1 = Shape.box(width: 10, height: 10, depth: 10),
            let box2 = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        else { return }
        if let cb = CellsBuilder(shapes: [box1, box2]) {
            cb.addAllToResult()
            cb.removeInternalBoundaries()
            if let result = cb.result() {
                #expect(result.isValid)
            }
        }
    }
}
