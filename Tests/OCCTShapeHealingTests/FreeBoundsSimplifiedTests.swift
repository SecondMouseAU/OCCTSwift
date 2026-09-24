import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: before this, two of these tests had no assertion at all (`_ = ...`), one asserted
// `count >= 0`, and all four returned early, silently green, if the box failed to build. Every
// value below is ShapeAnalysis_FreeBounds' own answer on the same input, from
// Scripts/repro/766-healing-freebounds-props/probe.mm.
@Suite("ShapeAnalysis_FreeBounds Simplified Tests")
struct FreeBoundsSimplifiedTests {

    @Test func closedCountOnBox() throws {
        // A closed box has no free bounds.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.freeBoundsClosedCount(tolerance: 1e-6) == 0)
    }

    @Test func closedWiresOnBox() throws {
        // The kernel returns an empty compound, not a null shape.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let wires = try #require(box.freeBoundsClosedWires(tolerance: 1e-6))
        #expect(wires.subShapes(ofType: .wire).isEmpty)
    }

    @Test func openWiresOnBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let wires = try #require(box.freeBoundsOpenWires(tolerance: 1e-6))
        #expect(wires.subShapes(ofType: .wire).isEmpty)
    }

    @Test func freeBoundsOnOpenShell() throws {
        // The sewing-based analysis runs over the shape's direct children, so a bare face offers
        // its wire, not itself, and reports 0 (kernel: 0), not the 1 its outline might suggest.
        // The non-sewing ShapeAnalysis_FreeBounds constructor would report 1 here.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let singleFace = try #require(box.subShapes(ofType: .face).first)
        #expect(singleFace.freeBoundsClosedCount(tolerance: 1e-6) == 0)
    }
}
