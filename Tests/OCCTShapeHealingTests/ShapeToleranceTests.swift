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
}
