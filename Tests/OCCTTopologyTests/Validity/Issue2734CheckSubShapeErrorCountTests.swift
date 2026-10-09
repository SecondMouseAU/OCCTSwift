import Foundation
import Testing

@testable import OCCTSwift

// #2734: checkEdge(at:), checkWire(at:), checkShell(at:) and checkVertex(at:) share one bridge
// helper, checkSubShape (Sources/OCCTBridge/src/OCCTBridge_Healing_Fix.mm), which walks
// BRepCheck_Edge/Wire/Shell/Vertex's Status() list to set isValid and firstError but never
// incremented errorCount. So an invalid sub-shape reported isValid == false, errorCount == 0,
// firstError == nil: the Swift wrappers in Shape+Topology.swift derive firstError from
// `result.errorCount > 0 ? status : nil`, so the lost count silently dropped firstError too. The
// existing suite (BRepCheckSubShapeTests) only exercises the valid path, so it never caught this.
//
// Measured on the pinned kernel (Scripts/repro/2734-checksubshape-errorcount/probe.mm) before
// picking a fixture: BRepCheck_Wire::Minimum() and BRepCheck_Shell::Minimum() both genuinely fault
// on disconnected/empty input (NotConnected, EmptyShell). The issue's own suggested repro for the
// EDGE case, an edge with its 3D curve removed, does NOT fault BRepCheck_Edge::Minimum() in this
// OCCT build in any variant tried (standalone edge, a live box edge, with GeometricControls(true),
// with a shrunk parameter range, with a mismatched Degenerated flag): Minimum() reported
// BRepCheck_NoError every time, and InContext(), which checkSubShape never calls, crashed
// outright on one variant rather than reporting cleanly. BRepCheck_Vertex is checked the same way:
// its per-vertex faults are raised by InContext(), not Minimum(). So this suite proves the fix
// through WIRE and SHELL, the two entry points measurement showed can actually be faulted through
// the same Minimum()-only path checkSubShape uses; the fix in checkSubShape is common to all four
// callers, not per-type.
@Suite("checkSubShape reports a real errorCount and firstError on an invalid sub-shape (#2734)")
struct Issue2734CheckSubShapeErrorCountTests {

    // A wire built from two edges with no shared vertex. `TopoDS_Builder::Add` (exposed here as
    // `builderAdd`) does none of `BRepBuilderAPI_MakeWire`'s connectivity checks, so this reaches
    // BRepCheck_Wire genuinely disconnected rather than merely built oddly.
    @Test("checkWire(at:) on a disconnected wire")
    func disconnectedWireReportsErrorCount() throws {
        let wire = try #require(Shape.builderMakeWire())
        let e1 = try #require(Shape.edgeFromPoints(SIMD3(0, 0, 0), SIMD3(1, 0, 0)))
        let e2 = try #require(Shape.edgeFromPoints(SIMD3(5, 5, 5), SIMD3(6, 5, 5)))
        #expect(wire.builderAdd(e1))
        #expect(wire.builderAdd(e2))

        // The wire shape is its own sub-shape at index 0 (occtSubShapeAt: "a shape IS its own
        // sub-shape when it is of the requested type").
        let result = wire.checkWire(at: 0)
        #expect(!result.isValid)
        #expect(result.errorCount > 0)
        if let firstError = result.firstError {
            #expect(firstError == .notConnected)
        } else {
            Issue.record("firstError was nil for an invalid wire")
        }
    }

    // An empty shell (no faces). BRepCheck_Shell::Minimum() catches this without needing a
    // context shape, unlike most of its other checks.
    @Test("checkShell(at:) on an empty shell")
    func emptyShellReportsErrorCount() throws {
        let shell = try #require(Shape.builderMakeShell())

        let result = shell.checkShell(at: 0)
        #expect(!result.isValid)
        #expect(result.errorCount > 0)
        if let firstError = result.firstError {
            #expect(firstError == .emptyShell)
        } else {
            Issue.record("firstError was nil for an invalid shell")
        }
    }
}
