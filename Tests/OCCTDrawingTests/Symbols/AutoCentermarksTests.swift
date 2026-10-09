import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.147 #79: Drawing.addAutoCentermarks

@Suite("v0.147 Drawing.addAutoCentermarks")
struct AutoCentermarksTests {
    @Test("Cylinder top view produces one centermark")
    func cylinderTopViewMark() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let top = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = top.addAutoCentermarks(from: cyl, viewDirection: SIMD3(0, 0, 1))
        // Top view has two circular edges (top + bottom); both face the view,
        // so both should produce centermarks.
        #expect(result.added.count == 2)
    }

    @Test("Cylinder side view skips edge-on circles")
    func cylinderSideViewSkipped() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let front = Drawing.frontView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = front.addAutoCentermarks(from: cyl, viewDirection: SIMD3(0, 1, 0))
        // Side view: both circular edges are edge-on → both skipped.
        #expect(result.added.isEmpty)
        #expect(result.skipped.count >= 1)
    }

    @Test("minRadius filters small holes")
    func minRadiusFilter() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20),
            let top = Drawing.topView(of: cyl)
        else {
            Issue.record("setup nil")
            return
        }
        let result = top.addAutoCentermarks(
            from: cyl, viewDirection: SIMD3(0, 0, 1),
            minRadius: 100)
        #expect(result.added.isEmpty)
    }
}
