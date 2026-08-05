import Testing
import Foundation
@testable import OCCTSwift

// #651: `Shape.nbEdges`, `Shape.nbFaces` and `Shape.nbVertices` counted bare `TopExp_Explorer`
// OCCURRENCES (`OCCTShapeNbEdges`/`NbFaces`/`NbVertices`, now deleted), the same gap #613 closed for
// its seven entry points, but this project's own reference docs always documented the DEDUPLICATED
// count instead: `docs/reference/Document-Completions.md` asserted `box.nbEdges // 12` and
// `box.nbVertices // 8`, never the 24 and 48 the implementation actually returned.
//
// Measured on the pinned kernel, a plain 10 mm box:
//
//   nbEdges     24   edgeCount     12
//   nbVertices  48   vertexCount    8
//   nbFaces      6   faceCount      6   (a box shares no face, so these already agreed)
//
// `nbFaces` needs a shape with a shared face to show the same divergence as its siblings, measured
// on a two-solid split compound (the #613/#614 fixture): 12 against 11.
//
// Unlike #613's seven sites, none of the three names an index consumed elsewhere, so there is no
// orientation dimension and no consumer that reads one spelling and not the other. The Cluster A
// census (#664, `Scripts/repro/cluster-a-subshape-enumeration/`) confirmed all three are pure
// occurrence duplicates of `edgeCount`/`faceCount`/`vertexCount` in every fixture it measured, so the
// fix taken here is #536's precedent (retire the duplicate spelling, deprecate-and-forward) rather
// than #613's (repoint the raw value and keep both names): there was nowhere for a second name to
// keep pulling its own weight once the value agreed.
//
// `nbEdges`/`nbFaces`/`nbVertices` are now `@available(*, deprecated, renamed:)` and forward to
// `edgeCount`/`faceCount`/`vertexCount`. `Shape.contents.edges`/`.faces`/`.vertices`
// (`ShapeAnalysis_ShapeContents`, a separate occurrence-counting mechanism, #541/#664) still reports
// the pre-fix occurrence numbers and is used below only to give each test an independent value to
// contrast against. It is explicitly out of scope for this issue and is not itself asserted to
// change.

@Suite("nbEdges/nbFaces/nbVertices forward to the deduplicated counters they duplicated (#651)")
struct Issue651DeprecatedCounterTests {

    // MARK: - Fixtures

    /// The plain box #651's own measurements are taken on.
    static func box() -> Shape? {
        Shape.box(origin: .zero, width: 10, height: 10, depth: 10)
    }

    /// Two solids sharing one cut face, from one ordinary modelling operation, the same
    /// construction `Issue613MeshIndexContractTests`/`Issue614FaceOrientationTests` use. `nbFaces`
    /// needs this: a plain box shares no face, so `nbFaces` and `faceCount` agree there by
    /// construction and the divergence only shows up once a face has two parents.
    ///
    /// Returns nil on any construction failure; every caller `#require`s it, so a kernel that
    /// stopped sharing the wall fails these tests rather than skipping them silently.
    static func splitBoxCompound() -> Shape? {
        guard let block = Shape.box(origin: .zero, width: 20, height: 10, depth: 10),
              let rect = Wire.rectangle(width: 60, height: 60),
              let plate = Shape.face(from: rect),
              let upright = plate.rotated(axis: SIMD3(0, 1, 0), angle: .pi / 2),
              let knife = upright.translated(by: SIMD3(10, 0, 0)),
              let pieces = block.split(by: knife),
              pieces.count == 2,
              let compound = Shape.compound(pieces)
        else { return nil }
        return compound
    }

    // MARK: - nbEdges

    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("nbEdges equals edgeCount, not the edge occurrence count, on a box")
    func nbEdgesMatchesEdgeCount() throws {
        let box = try #require(Self.box())
        #expect(box.edgeCount == 12)
        #expect(box.nbEdges == 12)
        #expect(box.nbEdges == box.edgeCount)
        // Context: an occurrence-based count over the same box is 24, not 12, the value nbEdges
        // used to return. This is not the same OCCT mechanism nbEdges used (ShapeAnalysis_ShapeContents
        // vs. a bare TopExp_Explorer), so it does not itself prove the fix; it only shows the
        // occurrence/distinct gap this box is chosen to exercise is real on this kernel.
        #expect(box.contents.edges == 24)
    }

    // MARK: - nbVertices

    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("nbVertices equals vertexCount, not the vertex occurrence count, on a box")
    func nbVerticesMatchesVertexCount() throws {
        let box = try #require(Self.box())
        #expect(box.vertexCount == 8)
        #expect(box.nbVertices == 8)
        #expect(box.nbVertices == box.vertexCount)
        #expect(box.contents.vertices == 48)
    }

    // MARK: - nbFaces

    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("nbFaces agrees with faceCount on a plain box, where no face is shared")
    func nbFacesMatchesFaceCountOnBox() throws {
        let box = try #require(Self.box())
        #expect(box.faceCount == 6)
        #expect(box.nbFaces == 6)
        #expect(box.nbFaces == box.faceCount)
    }

    @available(*, deprecated, message: "exercises the deprecated spelling on purpose")
    @Test("nbFaces equals faceCount, not the face occurrence count, on a shape with a shared face")
    func nbFacesMatchesFaceCountOnSharedFace() throws {
        let compound = try #require(Self.splitBoxCompound())
        #expect(compound.faceCount == 11)
        #expect(compound.nbFaces == 11)
        #expect(compound.nbFaces == compound.faceCount)
        // Context, as above: the occurrence count over the same compound is 12, not 11.
        #expect(compound.contents.faces == 12)
    }
}

// MARK: - Prove the test fails (okf/policies/prove-the-test-fails.md)
//
// Each of the four tests above was run once with `nbEdges`/`nbFaces`/`nbVertices` reverted to an
// occurrence count, to confirm the assertion that matters actually fires rather than passing
// vacuously. The injection used `Shape.contents.{edges,faces,vertices}` (still-live,
// occurrence-counting code this project keeps for an unrelated reason, #541/#664) in place of the
// forwarding body, since the original `OCCTShapeNbEdges`/`NbFaces`/`NbVertices` bridge functions this
// issue deletes are no longer available to restore without also reverting the bridge changes:
//
//   nbEdges:    `Int(contents.edges)`     instead of `edgeCount`
//   nbFaces:    `Int(contents.faces)`     instead of `faceCount`
//   nbVertices: `Int(contents.vertices)`  instead of `vertexCount`
//
// | Injection             | Result                                                              |
// |------------------------|---------------------------------------------------------------------|
// | nbEdges -> occurrence   | nbEdgesMatchesEdgeCount FAILED: `box.nbEdges == 12` -> 24 != 12      |
// | nbVertices -> occurrence | nbVerticesMatchesVertexCount FAILED: `box.nbVertices == 8` -> 48 != 8 |
// | nbFaces -> occurrence   | nbFacesMatchesFaceCountOnBox PASSED (a box shares no face: 6 either way) |
// | nbFaces -> occurrence   | nbFacesMatchesFaceCountOnSharedFace FAILED: `compound.nbFaces == 11` -> 12 != 11 |
//
// `nbFacesMatchesFaceCountOnBox` passing under the `nbFaces` injection is expected, not a dead
// assertion: it is the same reason #651's own issue text calls out, a plain box shares no face, so
// the two counting rules coincide there regardless of which one runs. It is
// `nbFacesMatchesFaceCountOnSharedFace` that catches this specific regression, which is why both
// tests exist. All four were restored and re-run green before this file was committed.
