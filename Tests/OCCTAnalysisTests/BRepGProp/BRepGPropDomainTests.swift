import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Domain Tests")
struct BRepGPropDomainTests {

    /// A box face's domain has four edges.
    ///
    /// #1900: this asserted `count >= 3` under a `guard ... else { return }`, so a missing box
    /// passed, and so did a domain that counted one edge too few or any number too many. Every
    /// face of the box is bounded by four edges, which is what BRepGProp_Domain iterates
    /// (`Scripts/repro/766-brepgprop-domain/`).
    @Test func faceEdgeCount() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let count = box.faceDomainEdgeCount(faceIndex: 0)
        #expect(count == 4)
    }
}
