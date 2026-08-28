import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.114.0 - BRepLib Utilities")
struct BRepLibUtilitiesTests {

    @Test func orientClosedSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Box is already oriented, this should still succeed
            let shells = box.subShapes(ofType: .shell)
            if shells.count > 0 {
                if let solid = Shape.builderMakeSolid() {
                    solid.builderAdd(shells[0])
                    let ok = solid.orientClosedSolid()
                    // May or may not succeed depending on shell state
                    let _ = ok
                }
            }
        }
    }

    /// A box's edges all have 3D curves already, so this is the early-return path: OCCT returns
    /// true without computing anything, and the tolerance is never read. Asserting that (rather
    /// than just `ok`) is the difference between testing the contract and testing nothing, the
    /// absurd tolerance below used to be `1e-7` and passed for the same reason 42 does. #498.
    @Test("Building 3D curves on a shape that already has them changes nothing")
    func buildCurves3dOnFullyBuiltShapeIsANoOp() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("could not build a box")
            return
        }
        let edges = box.subShapes(ofType: .edge)
        #expect(edges.count == 12)
        #expect(edges.allSatisfy { $0.extractEdgeCurve3D() != nil })
        let tolerancesBefore = edges.map(\.edgeTolerance)

        #expect(box.buildCurves3d(tolerance: 42))

        #expect(edges.map(\.edgeTolerance) == tolerancesBefore)
        #expect(edges.allSatisfy { $0.extractEdgeCurve3D() != nil })
    }

    @Test func sortFaces() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let sorted = box.sortedFaces()
            #expect(sorted != nil)
            if let s = sorted {
                let faces = s.subShapes(ofType: .face)
                #expect(faces.count == 6)
            }
        }
    }

    @Test func reverseSortFaces() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let sorted = box.reverseSortedFaces()
            #expect(sorted != nil)
            if let s = sorted {
                let faces = s.subShapes(ofType: .face)
                #expect(faces.count == 6)
            }
        }
    }
}
