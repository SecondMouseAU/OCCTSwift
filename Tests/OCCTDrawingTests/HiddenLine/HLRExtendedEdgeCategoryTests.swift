import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

// MARK: - v0.73.0: TKHlr Tests

@Suite("HLR Extended Edge Categories Tests")
struct HLRExtendedEdgeCategoryTests {
    /// Total projected length of every edge in an HLR result.
    ///
    /// Measured on the pinned kernel: the length is what the geometry fixes, while the edge count
    /// is the kernel's splitting of a line into pieces (exact HLR returns 99 pieces for the 9
    /// visible edges of a cube viewed along (1, 1, 1), the polyhedral HLR returns the 9). Counts
    /// are pinned only where the kernel's answer is the geometry's.
    private func totalLength(_ s: Shape) -> Double {
        s.edges().map { $0.length }.reduce(0, +)
    }

    private func box() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    private func cylinder() throws -> Shape {
        try #require(Shape.cylinder(radius: 5, height: 20))
    }

    /// A cube edge of length 10 viewed along (1, 1, 1) projects to 10 sqrt(2/3).
    private let projectedEdge = 10.0 * (2.0 / 3.0).squareRoot()

    @Test("exact HLR visible sharp edges on box")
    func exactVisibleSharp() throws {
        let e = try #require(
            try box().hlrEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp))
        // Nine of the cube's twelve edges are visible from a corner.
        #expect(abs(totalLength(e) - 9 * projectedEdge) < 1e-6, "got \(totalLength(e))")
        let b = try #require(e.bounds)
        #expect(abs(b.max.x - 5 * 2.0.squareRoot()) < 1e-5)
        #expect(abs(b.max.y - projectedEdge) < 1e-5, "y max \(b.max.y)")
    }

    @Test("exact HLR hidden sharp edges on box")
    func exactHiddenSharp() throws {
        let e = try #require(
            try box().hlrEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp))
        // The other three.
        #expect(abs(totalLength(e) - 3 * projectedEdge) < 1e-6, "got \(totalLength(e))")
    }

    @Test("exact HLR cylinder outlines")
    func cylinderOutlines() throws {
        let o = try #require(
            try cylinder().hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleOutline))
        // Viewed along +X the silhouette is the two generators, 20 long each, 10 apart.
        #expect(abs(totalLength(o) - 40) < 1e-6, "got \(totalLength(o))")
        let b = try #require(o.bounds)
        #expect(abs(b.min.y + 5) < 1e-5 && abs(b.max.y - 5) < 1e-5, "y \(b.min.y)...\(b.max.y)")
        #expect(abs(b.max.x - b.min.x - 20) < 1e-5, "x extent \(b.max.x - b.min.x)")
    }

    @Test("poly HLR visible sharp edges on box")
    func polyVisibleSharp() throws {
        let e = try #require(
            try box().hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .visibleSharp))
        #expect(e.subShapes(ofType: .edge).count == 9)
        #expect(abs(totalLength(e) - 9 * projectedEdge) < 1e-6, "got \(totalLength(e))")
    }

    @Test("poly HLR hidden sharp edges on box")
    func polyHiddenSharp() throws {
        let e = try #require(
            try box().hlrPolyEdges(direction: SIMD3(1, 1, 1), category: .hiddenSharp))
        #expect(e.subShapes(ofType: .edge).count == 3)
        #expect(abs(totalLength(e) - 3 * projectedEdge) < 1e-6, "got \(totalLength(e))")
    }

    @Test("compound of edges generic API")
    func compoundOfEdges() throws {
        // `in3d: true` leaves the edges in model space, so the lengths are the cube's own:
        // nine visible edges of 10 and three hidden ones.
        let visible = try #require(
            try box().hlrCompoundOfEdges(
                direction: SIMD3(1, 1, 1), edgeType: .sharp, visible: true, in3d: true))
        #expect(abs(totalLength(visible) - 90) < 1e-6, "got \(totalLength(visible))")
        let hidden = try #require(
            try box().hlrCompoundOfEdges(
                direction: SIMD3(1, 1, 1), edgeType: .sharp, visible: false, in3d: true))
        #expect(abs(totalLength(hidden) - 30) < 1e-6, "got \(totalLength(hidden))")
    }

    // MARK: - #1500: visibleIso/hiddenIso/isoLine used to always return nil

    // `algo->Add(shape, nbIso)`'s `nbIso` used to be omitted entirely (defaulting to 0 in OCCT),
    // which gates isoline computation off for every shape, so `.visibleIso`/`.hiddenIso` (via
    // `hlrEdges`) and `.isoLine` (via `hlrCompoundOfEdges`) always returned `nil`, contradicting
    // the bridge's own "exact HLR only" docs, which implied they worked for exact HLR. Fixture is
    // the issue's own repro: a cylinder viewed from the side, where isoparametric lines run the
    // length of the visible/hidden halves of the curved surface.
    //
    // Measured on the pinned kernel at the default isoline count: the projected lengths below.

    @Test("exact HLR visible iso lines on cylinder viewed from side (#1500)")
    func cylinderVisibleIso() throws {
        let e = try #require(
            try cylinder().hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleIso))
        #expect(abs(totalLength(e) - 180) < 1e-3, "got \(totalLength(e))")
        // Iso lines of the visible half run along the 20 unit length of the cylinder.
        let b = try #require(e.bounds)
        #expect(abs(b.max.x - b.min.x - 20) < 1e-5)
    }

    @Test("exact HLR hidden iso lines on cylinder viewed from side (#1500)")
    func cylinderHiddenIso() throws {
        let e = try #require(
            try cylinder().hlrEdges(direction: SIMD3(1, 0, 0), category: .hiddenIso))
        #expect(abs(totalLength(e) - 338.5994) < 1e-3, "got \(totalLength(e))")
        #expect(e.subShapes(ofType: .edge).count > 0)
    }

    @Test("compound of edges isoLine type on cylinder viewed from side (#1500)")
    func cylinderCompoundOfEdgesIsoLine() throws {
        let visible = try #require(
            try cylinder().hlrCompoundOfEdges(
                direction: SIMD3(1, 0, 0), edgeType: .isoLine, visible: true, in3d: true))
        #expect(abs(totalLength(visible) - 237.0796) < 1e-3, "got \(totalLength(visible))")
        let hidden = try #require(
            try cylinder().hlrCompoundOfEdges(
                direction: SIMD3(1, 0, 0), edgeType: .isoLine, visible: false, in3d: true))
        #expect(abs(totalLength(hidden) - 395.6790) < 1e-3, "got \(totalLength(hidden))")
    }

    @Test("nbIso: 0 still disables isoline computation, matching OCCT's own default (#1500)")
    func nbIsoZeroStillReturnsNil() {
        let cyl = Shape.cylinder(radius: 5, height: 20)
        if let c = cyl {
            let edges = c.hlrEdges(direction: SIMD3(1, 0, 0), category: .visibleIso, nbIso: 0)
            #expect(edges == nil)
        }
    }
}
