import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.113.0 - WireFixer")
struct WireFixerTests {

    @Test func fixBoxWire() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        let wire = try #require(faces[0].subShapes(ofType: .wire).first)
        let fixer = try #require(WireFixer(wire: wire, face: faces[0]))

        // ShapeFix_Wire reports a reorder pass on this healthy wire and nothing else (measured
        // on kernel.6); no pass changes the outline.
        #expect(fixer.fixReorder())
        #expect(!fixer.fixConnected())
        #expect(!fixer.fixSmall())
        #expect(!fixer.fixDegenerated())
        #expect(!fixer.fixLacking())
        #expect(!fixer.fixClosed())
        #expect(!fixer.fixGaps3d())
        #expect(!fixer.fixEdgeCurves())

        let fixed = try #require(fixer.wire)
        #expect(fixed.isValid)
        let edges = fixed.edges()
        #expect(edges.count == 4)
        for edge in edges { #expect(abs(edge.length - 10) < 1e-9) }
    }
}
