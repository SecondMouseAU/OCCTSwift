import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepClass FClassifier Tests")
struct BRepClassFClassifierTests {

    /// #1284: this test's own name promised `.inside` coverage and never exercised it. Both
    /// `classifyPoint2D` tests in this file asserted `.outside` — u:1000/v:1000 here and
    /// u:100/v:100 in `classifyPoint2DOutside` — so a regression that made `classifyPoint2D` always
    /// answer `.outside` would have passed this suite silently.
    ///
    /// Fixed by classifying the midpoint of the face's own trimmed UV bounds (`BRepTools::UVBounds`
    /// via `Face.uvBounds`), which is inside the face by construction for a box's planar,
    /// rectangular-in-UV faces, rather than a hardcoded literal.
    @Test func classifyPoint2DInside() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let face = box.face(at: 0),
            let bounds = face.uvBounds
        else {
            Issue.record("could not build the box or read face 0's UV bounds")
            return
        }
        let uMid = (bounds.uMin + bounds.uMax) / 2
        let vMid = (bounds.vMin + bounds.vMax) / 2
        let state = box.classifyPoint2D(faceIndex: 0, u: uMid, v: vMid)
        #expect(state == .inside)
    }

    @Test func classifyPoint2DOutside() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            return
        }
        let state = box.classifyPoint2D(faceIndex: 0, u: 100, v: 100)
        #expect(state == .outside)
    }
}
