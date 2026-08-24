import Testing
import simd

@testable import OCCTSwift

/// Issue #484: `Shape.connectedFaces(tolerance:)` (`ShapeFix_FaceConnect`, via
/// `OCCTShapeFixFaceConnect`) had **zero** test coverage anywhere in `Tests/`, grepping
/// `connectedFaces` repo-wide returned only its own declaration. The stale cross-reference index
/// entry (`ShapeFix_FaceConnect → OCCTShapeFixConnect*`, a symbol family that does not exist) would
/// not have led anyone to it either.
///
/// Writing the coverage surfaced a first-of-N defect of the same family as #439/#442/#443: the
/// bridge took the **first** shell an explorer yielded and dropped every other one, so a two-shell
/// compound came back as a single shell. Now every shell is processed and the results reassembled.
///
/// Review round (PR #511) found the box/cylinder cases above never exercise an actual connection:
/// `BRepPrimAPI_MakeBox`/`MakeCylinder` already share edges between faces, so `ShapeFix_FaceConnect`
/// has nothing to do on either input, the tests confirm no data is lost, not that connecting works.
/// `genuinelyDisconnectedFacesGetConnected` below closes that gap with a shell assembled from two
/// independently-built faces that share a geometric edge but not a topological one (`Shape.shellFromFaces`
/// wraps `BRep_Builder::Add`, no sewing), so there is real work for `connectedFaces` to do.
@Suite("Issue #484, Shape.connectedFaces coverage")
struct Issue484ConnectedFacesTests {

    @Test("connectedFaces on a box shell returns a shape with the same face count")
    func boxShellRoundTrips() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box")
            return
        }
        guard let connected = box.connectedFaces() else {
            Issue.record("connectedFaces returned nil for a box")
            return
        }
        #expect(connected.faces().count == box.faces().count)
    }

    @Test("connectedFaces accepts an explicit tolerance")
    func explicitTolerance() {
        guard let cyl = Shape.cylinder(radius: 4, height: 9) else {
            Issue.record("cylinder")
            return
        }
        for tol in [1e-6, 1e-4, 1e-2] {
            guard let connected = cyl.connectedFaces(tolerance: tol) else {
                Issue.record("connectedFaces returned nil at tolerance \(tol)")
                continue
            }
            #expect(connected.faces().count == cyl.faces().count)
        }
    }

    /// The first-of-N fix: two disjoint solids in one compound carry two shells, and both must
    /// survive. Before the fix the second shell was silently dropped.
    @Test("connectedFaces keeps every shell of a multi-shell compound")
    func multiShellCompoundKeepsEveryShell() {
        guard let a = Shape.box(width: 10, height: 10, depth: 10),
            let b = Shape.box(width: 6, height: 6, depth: 6)?
                .translated(by: SIMD3(40, 0, 0))
        else {
            Issue.record("boxes")
            return
        }
        guard let compound = Shape.compound([a, b]) else {
            Issue.record("compound")
            return
        }
        #expect(compound.faces().count == 12)

        guard let connected = compound.connectedFaces() else {
            Issue.record("connectedFaces returned nil for the compound")
            return
        }
        // 12, not 6: both shells are processed, not just the first the explorer yields.
        #expect(connected.faces().count == 12)
    }

    @Test("connectedFaces returns nil for a shape with no shell")
    func noShellReturnsNil() {
        guard let wire = Wire.rectangle(width: 5, height: 5),
            let face = Shape.face(from: wire)
        else {
            Issue.record("rectangle face")
            return
        }
        // A lone face is not a shell, and ShapeFix_FaceConnect needs one.
        #expect(face.connectedFaces() == nil)
    }

    /// Two abutting unit squares, each built from its own independent `Wire.polygon3D`, same
    /// endpoints where they meet, but no shared `TopoDS_Edge`/`TopoDS_Vertex` between them.
    /// `Shape.shellFromFaces` (`BRep_Builder::Add`, no sewing) wires them into one shell exactly as
    /// found: 8 topologically-independent boundary edges, none shared. Ground-truthed directly
    /// against `ShapeFix_FaceConnect::Add`/`Build` (matching the bridge's own call sequence) before
    /// writing this: the shared boundary sews into one edge and the shell's total unique edge count
    /// drops from 8 to 7, `Shape.edgeCount`'s own method (`TopExp::MapShapes`, deduped).
    @Test("connectedFaces sews a genuinely disconnected shared edge, not just preserves face count")
    func genuinelyDisconnectedFacesGetConnected() {
        let squareA: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0), SIMD3(0, 10, 0),
        ]
        let squareB: [SIMD3<Double>] = [
            SIMD3(10, 0, 0), SIMD3(20, 0, 0), SIMD3(20, 10, 0), SIMD3(10, 10, 0),
        ]
        guard let wireA = Wire.polygon3D(squareA), let wireB = Wire.polygon3D(squareB) else {
            Issue.record("polygon3D")
            return
        }
        guard let faceA = Shape.face(from: wireA), let faceB = Shape.face(from: wireB) else {
            Issue.record("face(from:)")
            return
        }
        guard let shell = Shape.shellFromFaces([faceA, faceB]) else {
            Issue.record("shellFromFaces")
            return
        }
        // Confirms the fixture is what it claims to be: 8 independent boundary edges, not already
        // sewn by construction.
        #expect(shell.edgeCount == 8)

        guard let connected = shell.connectedFaces() else {
            Issue.record("connectedFaces returned nil")
            return
        }
        #expect(connected.faces().count == 2)
        // The real assertion: the two coincident boundary edges merged into one shared edge.
        #expect(connected.edgeCount == 7)
    }
}
