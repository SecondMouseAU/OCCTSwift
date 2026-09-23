import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_ShapeTolerance")
struct ShapeToleranceTests {
    // #766: the eight tests below were nested in `if let` (silently green on a failed box) and
    // asserted `> 0`, `<=` orderings or `count > 0`. ShapeAnalysis_ShapeTolerance's own answers on
    // the same box (Scripts/repro/766-healing-shapetolerance/probe.mm): every sub-shape at 1e-7,
    // nothing over 1e-3, 30 in [0, 1e-3].
    private func box() throws -> Shape {
        try #require(Shape.box(width: 10, height: 20, depth: 30))
    }

    @Test func averageTolerance() throws {
        #expect(abs(try box().toleranceValue(mode: .average) - 1e-7) < 1e-15)
    }

    @Test func maximumTolerance() throws {
        #expect(abs(try box().toleranceValue(mode: .maximum) - 1e-7) < 1e-15)
    }

    @Test func minimumTolerance() throws {
        #expect(abs(try box().toleranceValue(mode: .minimum) - 1e-7) < 1e-15)
    }

    @Test func toleranceOrdering() throws {
        let b = try box()
        let minT = b.toleranceValue(mode: .minimum)
        let avgT = b.toleranceValue(mode: .average)
        let maxT = b.toleranceValue(mode: .maximum)
        #expect(minT <= avgT)
        #expect(avgT <= maxT)
    }

    @Test func overToleranceCount() throws {
        #expect(try box().toleranceOverCount(value: 1e-3) == 0)
    }

    @Test func inToleranceRangeCount() throws {
        #expect(try box().toleranceInRangeCount(min: 0, max: 1e-3) == 30)
    }

    @Test func vertexTolerance() throws {
        #expect(abs(try box().toleranceValue(mode: .average, subShapeType: 7) - 1e-7) < 1e-15)  // VERTEX
    }

    @Test func edgeTolerance() throws {
        #expect(abs(try box().toleranceValue(mode: .average, subShapeType: 6) - 1e-7) < 1e-15)  // EDGE
    }

    // #1438: OCCTShapeToleranceValue/OverCount/InRangeCount had no pointer guard at all (unlike
    // every sibling in the file, e.g. OCCTShapeMaxTolerance), so a null OCCTShapeRef pointer would
    // dereference unconditionally. That pointer is never null through the public Swift API
    // (Shape.handle is always valid) -- a `.nullified` shape is still a non-null wrapper POINTER
    // around a null TopoDS_Shape, and TopExp_Explorer (which ShapeAnalysis_ShapeTolerance uses
    // internally) already handles a null TopoDS_Shape safely -- so these are hardening/consistency
    // regressions for a direct C/Obj-C++ caller, not Swift-reachable crash fixes; they document the
    // now-guarded, safe fallback on the reachable (nullified) half of that null-shape space.
    @Test func toleranceValueOnNullifiedShapeReturnsZero() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        #expect(nullShape.toleranceValue(mode: .average) == 0.0)
    }

    @Test func toleranceOverCountOnNullifiedShapeReturnsZero() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        #expect(nullShape.toleranceOverCount(value: 1e-3) == 0)
    }

    @Test func toleranceInRangeCountOnNullifiedShapeReturnsZero() {
        guard let box = Shape.box(width: 10, height: 20, depth: 30), let nullShape = box.nullified
        else {
            Issue.record("failed to build box / nullified shape")
            return
        }
        #expect(nullShape.toleranceInRangeCount(min: 0, max: 1e-3) == 0)
    }
}
