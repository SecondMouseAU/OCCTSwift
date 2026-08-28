import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Wire Order Tests")
struct WireOrderTests {
    @Test("Order scrambled square edges")
    func orderSquareEdges() throws {
        // Edges of a square, scrambled
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)

        // Add in scrambled order: 3rd, 1st, 4th, 2nd edges
        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p3, end: p4),  // edge 3
            (start: p1, end: p2),  // edge 1
            (start: p4, end: p1),  // edge 4
            (start: p2, end: p3),  // edge 2
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        if let result {
            #expect(result.orderedEdges.count == 4)
        }
    }

    @Test("Wire order status indicates connectivity")
    func wireOrderStatus() throws {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)

        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p1, end: p2),
            (start: p2, end: p3),
            (start: p3, end: p4),
            (start: p4, end: p1),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        // Closed loop or open chain (depends on algorithm)
        if let result {
            #expect(result.status == .closed || result.status == .open)
        }
    }

    @Test("Wire order with gaps")
    func wireOrderGaps() throws {
        // Disconnected edges
        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0)),
            (start: SIMD3(100, 100, 0), end: SIMD3(200, 100, 0)),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
    }

    @Test("Analyze wire shape")
    func analyzeWireShape() throws {
        let wire = Wire.rectangle(width: 10, height: 10)
        #expect(wire != nil)

        if let wire {
            let result = WireOrder.analyze(wire: wire)
            #expect(result != nil)
            if let result {
                #expect(result.orderedEdges.count == 4)
            }
        }
    }

    // MARK: - #845: analyze(wire:) coverage parity with analyze(edges:)
    //
    // These mirror `wireOrderStatus` and `orderedEdgesValidIndices` above, but drive them
    // through `analyze(wire:)` instead of `analyze(edges:)`, and add coverage neither
    // overload had before: the negative-status nil-return guard inside `decode`. Both
    // overloads now share a single `WireOrder.decode(_:outOrder:)` helper (#845), so these
    // are a regression lock on that shared decode path from the `wire:` call site
    // specifically, not just the `edges:` one.

    @Test("Wire order status is closed for a closed rectangle wire")
    func analyzeWireShapeStatusIsClosed() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let result = try #require(WireOrder.analyze(wire: wire))
        #expect(result.status == .closed)
    }

    @Test("Ordered edges from analyze(wire:) have valid, non-repeating indices")
    func analyzeWireShapeOrderedEdgesValidIndices() throws {
        let wire = try #require(Wire.rectangle(width: 10, height: 10))
        let edgeCount = wire.edges().count
        #expect(edgeCount == 4)

        let result = try #require(WireOrder.analyze(wire: wire))
        #expect(result.orderedEdges.count == edgeCount)

        var seenIndices = Set<Int>()
        for ordered in result.orderedEdges {
            #expect(ordered.originalIndex >= 0)
            #expect(ordered.originalIndex < edgeCount)
            // A freshly-built rectangle's edges are all already walked forward
            // (measured directly against ShapeAnalysis_WireOrder: see
            // analyzeWireShapeReversedEdgeReturnsNil below for the case where
            // that isn't true), so none should be flagged reversed here.
            #expect(!ordered.isReversed)
            seenIndices.insert(ordered.originalIndex)
        }
        // Every original edge should appear exactly once: a genuine permutation of
        // 0..<edgeCount, not just values individually in range.
        #expect(seenIndices == Set(0..<edgeCount))
    }

    @Test("analyze(wire:) returns nil for a wire that needs an edge reversed to close")
    func analyzeWireShapeReversedEdgeReturnsNil() throws {
        // A square walked p1 -> p2 -> p3 -> p4 -> p1. Three edges are built already
        // matching that walk direction; the closing edge's underlying curve is built
        // the opposite way (p1 -> p4 instead of p4 -> p1). OCCTWireOrderAnalyzeWire
        // reads each edge's 3D curve endpoints directly (BRep_Tool::Curve +
        // curve->Value(first/last)), independent of the edge's TopoDS orientation, so
        // this is a genuine "some edges are reversed" case for ShapeAnalysis_WireOrder.
        //
        // Measured directly against the pinned kernel (a standalone
        // ShapeAnalysis_WireOrder probe reproducing this exact point sequence):
        // Status() reports -1 ("some edges are reversed, but no gap remain" per
        // ShapeAnalysis_WireOrder.hxx), not one of the 0/1/2 codes the bridge's own
        // `OCCTWireOrderResult.status` doc comment enumerates. `decode`'s
        // `if result.status < 0 { return nil }` guard treats any negative status as
        // failure, so this reversed-but-connected case surfaces as nil today, not as
        // a `WireOrder` with an `isReversed` entry. That guard was previously
        // untested by every other case in this suite (`emptyEdgesReturnsNil` hits a
        // different, earlier guard in `analyze(edges:)` itself, before the bridge is
        // even called); this is the first test to exercise it, on either overload.
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)
        let p4 = SIMD3<Double>(0, 10, 0)

        let e1 = try #require(Wire.line(from: p1, to: p2)?.edges().first)
        let e2 = try #require(Wire.line(from: p2, to: p3)?.edges().first)
        let e3 = try #require(Wire.line(from: p3, to: p4)?.edges().first)
        let e4Reversed = try #require(Wire.line(from: p1, to: p4)?.edges().first)

        let wire = try #require(Wire.wireFromEdges([e1, e2, e3, e4Reversed]))

        #expect(WireOrder.analyze(wire: wire) == nil)
    }

    @Test("Ordered edges have valid indices")
    func orderedEdgesValidIndices() throws {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(10, 0, 0)
        let p3 = SIMD3<Double>(10, 10, 0)

        let edges: [(start: SIMD3<Double>, end: SIMD3<Double>)] = [
            (start: p1, end: p2),
            (start: p2, end: p3),
            (start: p3, end: p1),
        ]

        let result = WireOrder.analyze(edges: edges)
        #expect(result != nil)
        if let result {
            for ordered in result.orderedEdges {
                #expect(ordered.originalIndex >= 0)
                #expect(ordered.originalIndex < edges.count)
            }
        }
    }

    @Test("Empty edges returns nil")
    func emptyEdgesReturnsNil() throws {
        let result = WireOrder.analyze(edges: [])
        #expect(result == nil)
    }
}
