import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGraph SameDomain")
struct BRepGraphSameDomainTests {
    @Test func boxNoSameDomain() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box {
            let graph = BRepGraph(shape: box)
            if let graph {
                // Box faces are all distinct, no same-domain
                let sd = graph.sameDomainFaces(of: 0)
                #expect(sd.isEmpty)
            }
        }
    }
}
