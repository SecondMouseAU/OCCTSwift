import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Sewing_Extras")
struct SewingExtrasTests {
    @Test func multipleEdgeCount() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            #expect(s.multipleEdgeCount >= 0)
        }
    }

    @Test func noMultipleEdgesForBox() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            #expect(s.multipleEdgeCount == 0)
        }
    }

    @Test func multipleEdgeAtInvalidIndex() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            let edge = s.multipleEdge(at: 999)
            #expect(edge == nil)
        }
    }
}
