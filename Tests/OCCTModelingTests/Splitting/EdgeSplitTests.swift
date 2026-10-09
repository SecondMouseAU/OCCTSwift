import Testing
import simd

@testable import OCCTSwift

@Suite("Edge Split Tests")
struct EdgeSplitTests {
    @Test("Split edge at midpoint")
    func splitAtMidpoint() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let edges = box.edges()
        // Find a line edge and split it
        for edge in edges {
            if edge.isLine {
                if let bounds = edge.parameterBounds {
                    let midParam = (bounds.first + bounds.last) / 2.0
                    if let midPt = edge.point(at: midParam) {
                        let result = edge.split(at: midParam, vertex: midPt)
                        if let (e1, e2) = result {
                            #expect(e1.length > 0)
                            #expect(e2.length > 0)
                        }
                        break
                    }
                }
            }
        }
    }
}
