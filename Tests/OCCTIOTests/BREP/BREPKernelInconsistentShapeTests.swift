import Foundation
import Testing

@testable import OCCTSwift

// `BRepCheck_Edge::InContext` checks an edge against a face. It read the face's surface without
// asking whether the face had one, and, when the edge's reference was a curve on a surface rather
// than a 3D curve, projected "the 3D curve" onto a planar face through a handle that was null. Both
// are uncatchable SIGSEGVs in `isValid`, reached by a shape the readers return:
//
//  - a face whose surface index names no surface in the file (`BRepTools_ShapeSet` skips a
//    reference outside its table, so the face is built without a surface);
//  - an edge whose 3D curve index names no curve in the file, so the edge keeps only its curves on
//    surfaces, on a planar face.
//
// `Shape.isValid` and the other analyzer sites of the bridge refuse both shapes before the analyzer
// sees them (#2750 for the edge, #2789 for the face), which keeps the process alive and hides the
// kernel defect. `Shape.connectedEdges` runs `BRepCheck_Analyzer` on its input unguarded, so it is
// the Swift entry that reaches `InContext` with the shape.
//
// Carried patch `0077` makes `InContext` report `NoCurveOnSurface` for both, which is what it
// already reported for the same edge on a face that was not a plane. They are gated on
// `OCCTSWIFT_LOCAL=1` while the pinned asset lacks `0077`; `kernel-integration.yml` runs them. The
// gate comes off at the repin that pins it.
//
// Every damaged file is a box this test writes with one index changed by an edit that is checked
// to have changed the text. The undamaged box is the control: a check that reported everything
// invalid would pass the rest.
@Suite("BRepCheck copes with a shape that lacks a surface or a 3D curve", .serialized)
struct BREPKernelInconsistentShapeTests {

    private static let isLocalKernel = ProcessInfo.processInfo.environment["OCCTSWIFT_LOCAL"] == "1"

    private static func boxText() -> String? {
        Shape.box(width: 10, height: 20, depth: 30)?.toBREPString()
    }

    /// `text` with the first match of `pattern` replaced, or nil when `pattern` is not there.
    private static func edited(_ text: String, pattern: String, template: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
            let swiftRange = Swift.Range(match.range, in: text)
        else { return nil }
        let replacement = regex.replacementString(
            for: match, in: text, offset: 0, template: template)
        return text.replacingCharacters(in: swiftRange, with: replacement)
    }

    @Test(.enabled(if: BREPKernelInconsistentShapeTests.isLocalKernel))
    func theUndamagedBoxIsValid() throws {
        let text = try #require(Self.boxText())
        let shape = try #require(Shape.fromBREPString(text))
        #expect(shape.isValid)
    }

    /// An edge whose 3D curve index names no curve keeps only its curves on surfaces.
    ///
    /// An edge record is `Ed`, its tolerance and flags, then `1 <curve> <location> <first> <last>`
    /// for the 3D curve. Index 999 is outside the 12 curves of the box, and every face is a plane.
    @Test(.enabled(if: BREPKernelInconsistentShapeTests.isLocalKernel))
    func anEdgeWithoutA3DCurveOnAPlanarFaceIsInvalidNotAFault() throws {
        let text = try #require(Self.boxText())
        let damaged = try #require(
            Self.edited(text, pattern: "(Ed\\n [^\\n]*\\n1 +)\\d+", template: "$1999"))
        #expect(damaged != text)
        let shape = try #require(Shape.fromBREPString(damaged))
        #expect(!shape.isValid)
        #expect(shape.connectedEdges != nil)
    }

    /// A face whose surface index names no surface is built without one.
    ///
    /// A face record is `Fa`, a flag, its tolerance and `<surface> <location>`. Index 999 is
    /// outside the 6 surfaces of the box.
    @Test(.enabled(if: BREPKernelInconsistentShapeTests.isLocalKernel))
    func aFaceWithoutASurfaceIsInvalidNotAFault() throws {
        let text = try #require(Self.boxText())
        let damaged = try #require(
            Self.edited(text, pattern: "(Fa\\n\\d +[^ \\n]+ )\\d+", template: "$1999"))
        #expect(damaged != text)
        let shape = try #require(Shape.fromBREPString(damaged))
        #expect(!shape.isValid)
        #expect(shape.connectedEdges != nil)
    }
}
