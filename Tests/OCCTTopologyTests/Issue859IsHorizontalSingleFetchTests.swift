import Testing
import Foundation
@testable import OCCTSwift

// #859 (review of #843): `isHorizontal(tolerance:)` was rewritten as
// `isUpwardFacing(tolerance:) || isDownwardFacing(tolerance:)`, a real algebraic identity, but
// `||` only short-circuits its second operand when the first is true, so every non-upward-facing
// face paid for a SECOND `Face.normal` fetch (a fresh `BRepLProp_SLProps` construction/solve
// through the bridge, not a cached read) to evaluate `isDownwardFacing`. Hot per-face loops
// (`Shape.horizontalFaces()`, `facesByZLevel()`, `AAG.buildGraph()`) doubled their normal-fetch
// cost for every downward-facing or vertical face.
//
// The fix inlines the same "fetch once, test the value" shape `normalZTest` already gives
// `isUpwardFacing`/`isDownwardFacing`/`isVertical`, comparing `abs(n.z)` against `cos(tolerance)`
// in one fetch instead of delegating to the two public predicates. A Swift-level call-count
// assertion isn't practical here, the bridge call is opaque C, not something a Swift test can
// instrument without its own hook, so this instead pins that the algebraic identity the
// single-fetch rewrite depends on still holds, value for value, across the same fixtures #843's
// own investigation already covered (Issue614FaceOrientationTests' degenerate-tolerance case
// included), by comparing `isHorizontal(tolerance:)` directly against
// `isUpwardFacing(tolerance:) || isDownwardFacing(tolerance:)` computed independently.
@Suite("isHorizontal(tolerance:) matches isUpwardFacing || isDownwardFacing at one fetch (#859)")
struct Issue859IsHorizontalSingleFetchTests {

    /// Every planar-primitive face, at both the default tolerance and the degenerate
    /// `tolerance >= pi/2` regime `Issue614FaceOrientationTests` already exercises for
    /// `upwardFaces(tolerance:)`, agrees with the two-call composition.
    @Test("isHorizontal agrees with isUpwardFacing || isDownwardFacing on primitives")
    func agreesOnPrimitives() {
        let solids: [(String, Shape?)] = [
            ("box", Shape.box(width: 10, height: 20, depth: 30)),
            ("cylinder", Shape.cylinder(radius: 5, height: 20)),
            ("cone", Shape.cone(bottomRadius: 5, topRadius: 0, height: 12)),
            ("sphere", Shape.sphere(radius: 7)),
        ]
        let tolerances: [Double] = [0.01, 0.001, 0.1, .pi / 2, 1.6, .pi]

        var checked = 0
        for (name, solid) in solids {
            guard let solid else {
                Issue.record("\(name) returned nil")
                continue
            }
            for face in solid.faces() {
                for tolerance in tolerances {
                    let composed = face.isUpwardFacing(tolerance: tolerance)
                        || face.isDownwardFacing(tolerance: tolerance)
                    #expect(face.isHorizontal(tolerance: tolerance) == composed,
                            "\(name) face \(face.index) at tolerance \(tolerance)")
                    checked += 1
                }
            }
        }
        // Without this the loop passes vacuously if every solid failed to build.
        #expect(checked > 0)
    }

    /// The shared-wall fixture from #614: a vertical face reached with two opposite orientations,
    /// including through the degenerate tolerance where `upwardFaces`/`downwardFaces` start
    /// admitting faces that do not point up/down at all.
    @Test("isHorizontal agrees on the split-box compound's shared wall, both orientations")
    func agreesOnSharedWall() {
        guard let compound = Issue614FaceOrientationTests.splitBoxCompound() else {
            Issue.record("could not build the split-box compound")
            return
        }
        let tolerances: [Double] = [0.01, .pi / 2, 1.6]

        var checked = 0
        for face in compound.orientedFaces() {
            for tolerance in tolerances {
                let composed = face.isUpwardFacing(tolerance: tolerance)
                    || face.isDownwardFacing(tolerance: tolerance)
                #expect(face.isHorizontal(tolerance: tolerance) == composed,
                        "face \(face.index) (\(face.orientation)) at tolerance \(tolerance)")
                checked += 1
            }
        }
        #expect(checked > 0)
    }
}
