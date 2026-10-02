import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// PROBE, not a regression test: #2929's one decisive measurement, which is reading the
// SameParameter flag back after clearing it. It separates the two readings the issue could not:
// a flag write that does not take effect (bridge or handle sharing) from a BRepCheck_Analyzer
// that does not fault the mismatch (kernel behaviour). Delete once #2929 is answered.
@Suite("Probe 2929, SameParameter write visibility")
struct Probe2929SameParameter {

    /// Reads the flag through a fresh `Shape` built from an edge handle, so the read goes through
    /// `OCCTEdgeSameParameter` the way `Shape.edgeSameParameter` does.
    private func flag(of edge: Edge) -> Bool? {
        guard let ref = OCCTShapeFromEdge(edge.handle) else { return nil }
        return Shape(handle: ref).edgeSameParameter
    }

    @Test("Read the SameParameter flag back after clearing it")
    func flagWriteIsVisible() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        try #require(edges.count == 12)

        let before = flag(of: edges[0])
        let validBefore = box.isValid

        let setter = OCCTDiagnostics.capturing {
            OCCTEdgeSetSameParameter(edges[0].handle, false)
        }

        // Through the SAME Edge object the setter was handed.
        let afterSameEdge = flag(of: edges[0])
        // Through a FRESH walk of the box, which shares the TShape only if the mutation landed
        // on the shape the box owns rather than on a copy.
        let afterFreshWalk = flag(of: box.edges()[0])
        let validAfter = box.isValid

        print("PROBE2929 before=\(String(describing: before)) validBefore=\(validBefore)")
        print("PROBE2929 afterSameEdge=\(String(describing: afterSameEdge))")
        print("PROBE2929 afterFreshWalk=\(String(describing: afterFreshWalk))")
        print("PROBE2929 validAfter=\(validAfter) setterDiagnostics=\(setter.diagnostics.count)")

        // The probe records rather than asserts, so it reports on both platforms instead of
        // failing on one. The flag read-back is the finding.
        #expect(before == true, "a fresh box edge should carry SameParameter")
    }
}

// The probe above behaves correctly on wasm while `BRepLibExtendedTests."Same parameter all"`
// fails there, so the divergence is sequence-dependent rather than a broken flag write. These
// three variants differ ONLY in what is called before the mutation, which is the whole delta
// between the two.
@Suite("Probe 2929b, which prior call changes the outcome")
struct Probe2929Sequence {

    private func box() throws -> (Shape, [Edge]) {
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let e = b.edges()
        try #require(e.count == 12)
        return (b, e)
    }

    @Test("Variant A: the failing test's exact sequence, nothing called first")
    func variantBare() throws {
        let (b, edges) = try box()
        OCCTEdgeSetSameParameter(edges[0].handle, false)
        print("PROBE2929B variantA validAfter=\(b.isValid)")
    }

    @Test("Variant B: isValid called once before the mutation")
    func variantPriorIsValid() throws {
        let (b, edges) = try box()
        let priming = b.isValid
        OCCTEdgeSetSameParameter(edges[0].handle, false)
        print("PROBE2929B variantB priming=\(priming) validAfter=\(b.isValid)")
    }

    @Test("Variant C: the flag read once before the mutation, no isValid")
    func variantPriorFlagRead() throws {
        let (b, edges) = try box()
        var read: Bool?
        if let ref = OCCTShapeFromEdge(edges[0].handle) {
            read = Shape(handle: ref).edgeSameParameter
        }
        OCCTEdgeSetSameParameter(edges[0].handle, false)
        print("PROBE2929B variantC read=\(String(describing: read)) validAfter=\(b.isValid)")
    }
    // Variants A to C are all WRONG on wasm while the first probe in this file is RIGHT, and the
    // only thing it does that they do not is run the setter inside OCCTDiagnostics.capturing.
    // D isolates that one call; E is the combination without it.
    @Test("Variant D: bare, but the setter runs inside a diagnostics capture")
    func variantCapturingOnly() throws {
        let (b, edges) = try box()
        let captured = OCCTDiagnostics.capturing {
            OCCTEdgeSetSameParameter(edges[0].handle, false)
        }
        print("PROBE2929B variantD records=\(captured.diagnostics.count) validAfter=\(b.isValid)")
    }

    @Test("Variant E: flag read AND isValid first, no diagnostics capture")
    func variantBothPriorCalls() throws {
        let (b, edges) = try box()
        var read: Bool?
        if let ref = OCCTShapeFromEdge(edges[0].handle) {
            read = Shape(handle: ref).edgeSameParameter
        }
        let priming = b.isValid
        OCCTEdgeSetSameParameter(edges[0].handle, false)
        print(
            "PROBE2929B variantE read=\(String(describing: read)) priming=\(priming) "
                + "validAfter=\(b.isValid)")
    }
}
