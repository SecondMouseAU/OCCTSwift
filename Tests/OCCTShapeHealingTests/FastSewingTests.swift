import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Fast Sewing")
struct FastSewingTests {
    @Test("Fast sew a valid shape")
    func fastSewValid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.fastSewn()
        #expect(sewn != nil)
    }

    @Test("Fast sew with custom tolerance")
    func fastSewTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.fastSewn(tolerance: 0.01)
        #expect(sewn != nil)
    }
}
