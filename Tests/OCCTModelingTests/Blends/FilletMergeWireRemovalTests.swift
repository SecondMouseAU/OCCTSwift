import Foundation
import Testing

@testable import OCCTSwift

/// #3335 (OCCT#1619): `CorrectUnclosedWire` in `TopOpeBRepBuild_Merge.cxx` removed edges from a
/// wire while a `TopoDS_Iterator` stood on the node it freed, so a fillet whose ends meet in the
/// merge read freed memory and the process died with an uncatchable SIGSEGV (20 of 20 runs).
///
/// The model is `Fixtures/fillet-merge-unclosed-wire.brep`, the reporter's file. Edge numbers are
/// DRAW's 1-based `explode` indices, so 26 and 35 are indices 25 and 34 here.
@Suite("Fillet merge removes edges from a wire without a use-after-free")
struct FilletMergeWireRemovalTests {

    private func model() throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/fillet-merge-unclosed-wire.brep")
        return try Shape.loadBREP(from: url)
    }

    /// Needs carried patch `0064`, which `v4.0.0-kernel.7` is the first asset to hold.
    ///
    /// On a kernel without it this call is a SIGSEGV that takes the whole test process down. It was
    /// gated on `OCCTSWIFT_LOCAL=1` until that repin (#2983).
    @Test(
        "Two fillets whose ends meet in the merge return instead of crashing")
    func crashingPair() throws {
        let m = try model()
        let edges = m.edges()
        try #require(edges.count > 34)
        // Before the fix this call killed the test process.
        let result = m.filleted(edges: [edges[25], edges[34]], radius: 1.25)
        // Measured: nil after the fix (the merge is not done or the result is invalid). A shape
        // is also acceptable, but never an invalid one.
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("The control radius keeps its valid result")
    func controlRadius() throws {
        let m = try model()
        let edges = m.edges()
        try #require(edges.count > 34)
        let result = try #require(m.filleted(edges: [edges[25], edges[34]], radius: 1.0))
        #expect(result.isValid)
        #expect(result.faces().count == 32)
    }
}
