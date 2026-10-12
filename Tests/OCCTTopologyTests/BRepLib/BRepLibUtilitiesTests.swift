import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.114.0 - BRepLib Utilities")
struct BRepLibUtilitiesTests {

    /// A forward shell is already outward, so the call is a no-op that answers `true`; a REVERSED
    /// shell makes an inward solid (signed volume -1000), which the call should flip.
    ///
    /// Measured on kernel.6: the call answers `true` for both and the inward solid stays at -1000,
    /// because the bridge reverses a local copy of the solid (the orientation lives in the
    /// `TopoDS_Shape` value, not the shared TShape) and drops it. #3357.
    @Test func orientClosedSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shell = try #require(box.subShapes(ofType: .shell).first)

        let outward = try #require(Shape.builderMakeSolid())
        outward.builderAdd(shell)
        #expect(abs(outward.signedVolume - 1000) < 1e-6)
        #expect(outward.orientClosedSolid())
        #expect(abs(outward.signedVolume - 1000) < 1e-6)

        let inwardShell = try #require(shell.oriented(1))
        let inward = try #require(Shape.builderMakeSolid())
        inward.builderAdd(inwardShell)
        // The fixture really is inward before the call, so the check below is about the call.
        #expect(abs(inward.signedVolume + 1000) < 1e-6)
        #expect(inward.orientClosedSolid())
        withKnownIssue("orientClosedSolid reverses a local copy and never writes it back (#3357)") {
            #expect(abs(inward.signedVolume - 1000) < 1e-6)
        }
    }

    /// A box's edges all have 3D curves already, so this is the early-return path: OCCT returns
    /// true without computing anything, and the tolerance is never read.
    ///
    /// Asserting that (rather
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
