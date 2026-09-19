import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeAnalysis_ShapeTolerance")
struct ShapeToleranceTests {
    @Test func averageTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let avg = b.toleranceValue(mode: .average)
            #expect(avg > 0)
        }
    }

    @Test func maximumTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let max = b.toleranceValue(mode: .maximum)
            #expect(max > 0)
        }
    }

    @Test func minimumTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let min = b.toleranceValue(mode: .minimum)
            #expect(min > 0)
        }
    }

    @Test func toleranceOrdering() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let minT = b.toleranceValue(mode: .minimum)
            let avgT = b.toleranceValue(mode: .average)
            let maxT = b.toleranceValue(mode: .maximum)
            #expect(minT <= avgT)
            #expect(avgT <= maxT)
        }
    }

    @Test func overToleranceCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            // Default tolerance is ~1e-7, so nothing should exceed 1e-3
            let count = b.toleranceOverCount(value: 1e-3)
            #expect(count == 0)
        }
    }

    @Test func inToleranceRangeCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let count = b.toleranceInRangeCount(min: 0, max: 1e-3)
            #expect(count > 0)  // All sub-shapes should be within this range
        }
    }

    @Test func vertexTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tol = b.toleranceValue(mode: .average, subShapeType: 7)  // VERTEX
            #expect(tol > 0)
        }
    }

    @Test func edgeTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tol = b.toleranceValue(mode: .average, subShapeType: 6)  // EDGE
            #expect(tol > 0)
        }
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
