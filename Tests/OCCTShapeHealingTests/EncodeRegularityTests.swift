import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Encode Regularity")
struct EncodeRegularityTests {
    @Test("Encode regularity on box")
    func encodeRegularityBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.encodingRegularity()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(abs(r.volume! - 1000.0) < 1.0)
        }
    }

    @Test("Encode regularity on filleted box")
    func encodeRegularityFilleted() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!.filleted(radius: 1)!
        let result = box.encodingRegularity(toleranceDegrees: 1.0)
        #expect(result != nil)
    }

    // MARK: - #1545: default mirrors OCCT's own BRepLib::EncodeRegularity default (in radians)

    /// A two-face shell, hand-built (not sewn) so `BRep_Tool::HasContinuity` starts unset, sharing
    /// exactly one edge, tilted out of plane by `thetaRadians`. `BRepLib::ContinuityOfFaces`
    /// compares the two faces' cross-edge derivative directions against the angular tolerance it is
    /// given, so this edge's "how non-planar is the join" measurement *is* `thetaRadians`, by
    /// construction: verified directly (a binary search over `Shape.continuityClassOfFaces`'s own
    /// `tolerance:` parameter, against this exact fixture) to give a continuity flip threshold
    /// matching `thetaRadians` to within float rounding, for values spanning 1e-4 down to 1e-11 rad.
    ///
    /// Building this by hand (rather than via `Shape.sewn`) matters: `BRepBuilderAPI_Sewing` runs
    /// its own internal `BRepLib::EncodeRegularity` pass as part of assembling its result, using its
    /// own (much looser) sewing tolerance, so a sewn shape already has continuity encoded before
    /// `encodingRegularity()` is ever called, and `BRepLib::EncodeRegularity`'s per-edge overload
    /// (`if (BRep_Tool::Continuity(...) <= GeomAbs_C0) ...`) is documented to do nothing once an
    /// edge already carries *any* code — including a prior C0 the caller's own tolerance never
    /// touches. Sharing the two faces in a bare `TopoDS_Compound` doesn't work either:
    /// `BRepLib::EncodeRegularity`'s compound case recurses into each child individually rather than
    /// pairing edges across siblings, so two loose compound faces never see each other. A
    /// `TopoDS_Shell` (`Shape.shellFromFaces`) is the shape this bridge function is meant to run on.
    private func nearTangentShell(thetaRadians: Double) -> Shape? {
        let W = 10.0
        let H = 1.0e7  // far corner deviation H*theta must clear any incidental welding tolerance
        let p0 = SIMD3<Double>(0, 0, 0)
        let p1 = SIMD3<Double>(W, 0, 0)
        let y2 = -H * cos(thetaRadians)
        let z2 = H * sin(thetaRadians)

        // Face 1: the z=0 plane, spanning y in [0, H] away from the shared edge (p0 -> p1).
        guard
            let sharedEdgeShape = Shape.edgeFromPoints(p0, p1),
            let sharedEdge = Edge(sharedEdgeShape),
            let e1b = Shape.edgeFromPoints(p1, SIMD3(W, H, 0)),
            let e1bEdge = Edge(e1b),
            let e1c = Shape.edgeFromPoints(SIMD3(W, H, 0), SIMD3(0, H, 0)),
            let e1cEdge = Edge(e1c),
            let e1d = Shape.edgeFromPoints(SIMD3(0, H, 0), p0),
            let e1dEdge = Edge(e1d),
            let wire1 = Wire.wireFromEdges([sharedEdge, e1bEdge, e1cEdge, e1dEdge]),
            let face1 = Shape.face(from: wire1, planar: true)
        else { return nil }

        // Face 2: a near-flat CONTINUATION spanning y in [-H, 0] (the opposite side of the shared
        // edge from face 1), tilted +Z by thetaRadians — dihedral ~180 degrees minus theta, i.e. a
        // near-tangent join, not a folded-back one. Reusing `sharedEdge` (not a geometrically
        // coincident copy) is what makes this topologically one shared edge rather than two.
        //
        // Traversed p1 -> p0 -> far2 -> far1 -> p1, the OPPOSITE cyclic direction from face 1's
        // p0 -> p1 -> far1 -> far2 -> p0: `BRepBuilderAPI_MakeFace`'s auto-computed plane normal
        // follows a wire's traversal sense (right-hand rule), and two faces meeting at a shared
        // edge need *opposite* traversal direction around that edge for their outward normals to
        // land on the same side (a flat continuation) rather than opposite sides (folded back on
        // itself, which reads as a sharp, non-smooth join regardless of how small thetaRadians is
        // — measured directly: building face 2 in the SAME cyclic direction as face 1 stayed C0
        // even at theta=1e-4 against a 0.01 rad tolerance loose enough to accept nearly anything).
        guard
            let e2b = Shape.edgeFromPoints(p1, SIMD3(W, y2, z2)),
            let e2bEdge = Edge(e2b),
            let e2c = Shape.edgeFromPoints(SIMD3(W, y2, z2), SIMD3(0, y2, z2)),
            let e2cEdge = Edge(e2c),
            let e2d = Shape.edgeFromPoints(SIMD3(0, y2, z2), p0),
            let e2dEdge = Edge(e2d),
            let sharedEdgeRev = reversed(sharedEdge),
            let e2dRev = reversed(e2dEdge),
            let e2cRev = reversed(e2cEdge),
            let e2bRev = reversed(e2bEdge),
            let wire2 = Wire.wireFromEdges([sharedEdgeRev, e2dRev, e2cRev, e2bRev]),
            let face2 = Shape.face(from: wire2, planar: true)
        else { return nil }

        return Shape.shellFromFaces([face1, face2])
    }

    /// The topological reverse of `edge`'s orientation (`TopoDS_Shape::Reversed()`), still an
    /// `Edge` sharing the same underlying curve — used to force a wire's traversal direction
    /// rather than reordering points, since `Wire.wireFromEdges` connects edges as given.
    private func reversed(_ edge: Edge) -> Edge? {
        Shape.fromEdge(edge)?.reversed.flatMap { Edge($0) }
    }

    /// The (edge, face1, face2) triple for the fixture's one shared edge, re-located in `shape`
    /// (which may be a post-`encodingRegularity()` copy, with fresh sub-shape identity).
    private func sharedTriple(in shape: Shape) -> (Shape, Shape, Shape)? {
        let faces = shape.subShapes(ofType: .face)
        for edge in shape.subShapes(ofType: .edge) {
            let adjacent = shape.adjacentFaces(forEdge: edge)
            if adjacent.count == 2,
                let a = adjacent.first, let b = adjacent.last,
                a >= 0, a < faces.count, b >= 0, b < faces.count
            {
                return (edge, faces[a], faces[b])
            }
        }
        return nil
    }

    @Test("fixture starts with no continuity encoded on its shared edge")
    func fixtureStartsUnencoded() throws {
        let shape = try #require(nearTangentShell(thetaRadians: 1e-11))
        let (edge, f1, f2) = try #require(sharedTriple(in: shape))
        #expect(!Shape.hasContinuity(edge: edge, face1: f1, face2: f2))
    }

    @Test(
        "the OCCT-native default (1.0e-10 rad, expressed in degrees) marks a near-tangent edge regular"
    )
    func defaultToleranceMarksNearTangentEdgeRegular() throws {
        // thetaRadians sits an order of magnitude inside both the old buggy default
        // (1e-10 degrees ~= 1.745e-12 rad) and the corrected default (1.0e-10 rad, matching OCCT's
        // own BRepLib::EncodeRegularity default): 10x looser than the old ceiling, 10x tighter than
        // the new one.
        let shape = try #require(nearTangentShell(thetaRadians: 1e-11))

        // No explicit toleranceDegrees: this is the exact call a caller relying on "the default"
        // makes, and the one #1545 found ~172x stricter than OCCT's own default.
        let result = try #require(shape.encodingRegularity())
        let (edge, f1, f2) = try #require(sharedTriple(in: result))

        #expect(Shape.hasContinuity(edge: edge, face1: f1, face2: f2))
        let continuity = Shape.continuity(edge: edge, face1: f1, face2: f2)
        #expect(
            continuity != ContinuityClass.c0.rawValue,
            "the default should mirror OCCT's own 1.0e-10 rad default and mark this near-tangent join regular"
        )
    }

    @Test("the pre-#1545 buggy default (1e-10 degrees) fails to mark the same edge regular")
    func oldBuggyDefaultStillDoesNotMarkRegular() throws {
        let shape = try #require(nearTangentShell(thetaRadians: 1e-11))

        // Passed explicitly here (rather than relying on the default) so this test keeps pinning
        // the old, pre-fix literal's behavior regardless of what the default becomes later: this is
        // the boundary case that shows the fixture is genuinely borderline, not just loose.
        let result = try #require(shape.encodingRegularity(toleranceDegrees: 1e-10))
        let (edge, f1, f2) = try #require(sharedTriple(in: result))

        #expect(Shape.hasContinuity(edge: edge, face1: f1, face2: f2))
        let continuity = Shape.continuity(edge: edge, face1: f1, face2: f2)
        #expect(continuity == ContinuityClass.c0.rawValue)
    }
}
