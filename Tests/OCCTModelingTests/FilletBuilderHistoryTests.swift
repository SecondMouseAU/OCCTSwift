import Testing
import simd

@testable import OCCTSwift

@Suite("v0.127.0, FilletBuilder History Queries")
struct FilletBuilderHistoryTests {

    @Test("FilletBuilder GetBounds for evolving radius")
    func getBoundsForEvolvingRadius() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(FilletBuilder(shape: box))
        let edges = box.edges()
        let edge = try #require(edges.first)
        // An evolving radius, because a constant one has no law to bound (#505).
        #expect(builder.addEdge(edge, radius1: 0.5, radius2: 2.0))
        #expect(builder.build() != nil)
        let bounds = try #require(builder.getBounds(contour: 1, edge: edge))
        #expect(bounds.first < bounds.last)
        // #766: pinned to the kernel's GetBounds for the same input (probe 766-modeling-fillet-builder-history).
        #expect(abs(bounds.first - -5.0) < 1e-9)
        #expect(abs(bounds.last - 15.0) < 1e-9)
    }

    @Test("FilletBuilder GetLaw for evolving radius")
    func getLawForEvolvingRadius() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(FilletBuilder(shape: box))
        let edges = box.edges()
        let edge = try #require(edges.first)
        #expect(builder.addEdge(edge, radius1: 0.5, radius2: 2.0))
        #expect(builder.build() != nil)
        #expect(builder.getLaw(contour: 1, edge: edge) != nil)
    }

    // #766: the three tests below used to return silently when the box, the builder or the edge
    // list was missing, and nested their assertions inside `if added` and `if builder.build() !=
    // nil`, so an addEdge or a build that failed skipped every assertion and passed. The fixtures
    // are now required, and each count is pinned to the kernel's answer for the same input
    // (Scripts/repro/766-modeling-fillet-builder-history): the filleted edge generates one face,
    // four of the box's six faces are modified, and the edge is deleted.

    @Test("FilletBuilder Generated from edge")
    func generated() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 1.0))
        #expect(builder.build() != nil)
        let edgeShape = try #require(Shape.fromEdge(edge))
        #expect(builder.generated(from: edgeShape).count == 1)
    }

    @Test("FilletBuilder Modified from face")
    func modified() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 1.0))
        #expect(builder.build() != nil)
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        // `mod.count >= 0` can never fail (a count is never negative), so it never measured
        // anything (#764). The fillet trims both faces adjacent to the edge and both end faces it
        // runs into: four modified faces.
        #expect(faces.filter { builder.modified(from: $0).count > 0 }.count == 4)
    }

    @Test("FilletBuilder IsDeleted for filleted edge")
    func isDeleted() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let builder = try #require(FilletBuilder(shape: box))
        let edge = try #require(box.edges().first)
        #expect(builder.addEdge(edge, radius: 1.0))
        #expect(builder.build() != nil)
        let edgeShape = try #require(Shape.fromEdge(edge))
        #expect(builder.isDeleted(edgeShape))  // The original edge is replaced by the fillet
    }
}
