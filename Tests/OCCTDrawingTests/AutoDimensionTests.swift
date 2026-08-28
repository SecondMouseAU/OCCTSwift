import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.149 #83: Drawing.addAutoDimensions

@Suite("v0.149 Drawing.addAutoDimensions")
struct AutoDimensionTests {
    @Test("Box front view produces two linear dimensions")
    func boxLinearExtents() {
        guard let box = Shape.box(width: 10, height: 5, depth: 3),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        let result = front.addAutoDimensions(from: box, viewDirection: SIMD3(0, 1, 0))
        let linearCount = result.added.filter {
            if case .linear = $0 { return true } else { return false }
        }.count
        #expect(linearCount == 2)
    }

    @Test("Cylinder top view produces diameter + linear extents")
    func cylinderTopViewHasDiameters() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let top = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = top.addAutoDimensions(from: cyl, viewDirection: SIMD3(0, 0, 1))
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        let linearCount = result.added.filter {
            if case .linear = $0 { return true } else { return false }
        }.count
        #expect(diaCount >= 1)
        #expect(linearCount == 2)
    }

    @Test("Cylinder side view skips edge-on circles")
    func cylinderSideViewEdgeOn() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let front = Drawing.frontView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = front.addAutoDimensions(from: cyl, viewDirection: SIMD3(0, 1, 0))
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        #expect(diaCount == 0)
    }

    @Test("minRadius filters small circles")
    func minRadiusFilters() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let top = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = top.addAutoDimensions(
            from: cyl,
            viewDirection: SIMD3(0, 0, 1),
            minRadius: 100)
        let diaCount = result.added.filter {
            if case .diameter = $0 { return true } else { return false }
        }.count
        #expect(diaCount == 0)
    }
}
