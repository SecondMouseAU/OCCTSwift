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

    @Test("FilletBuilder Generated from edge")
    func generated() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if builder.build() != nil {
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    let gen = builder.generated(from: edgeShape)
                    #expect(gen.count > 0)
                }
            }
        }
    }

    @Test("FilletBuilder Modified from face")
    func modified() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if builder.build() != nil {
                let faces = box.subShapes(ofType: .face)
                if !faces.isEmpty {
                    // `mod.count >= 0` can never fail (a count is never negative), so it never
                    // measured anything (#764): any single face may or may not be one the
                    // fillet touches, but at least one of the box's own faces must be, since
                    // the fillet replaces material on both faces adjacent to the filleted edge.
                    let anyModified = faces.contains { builder.modified(from: $0).count > 0 }
                    #expect(anyModified)
                }
            }
        }
    }

    @Test("FilletBuilder IsDeleted for filleted edge")
    func isDeleted() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        guard let builder = FilletBuilder(shape: box) else { return }
        let edges = box.edges()
        guard !edges.isEmpty else { return }
        let added = builder.addEdge(edges[0], radius: 1.0)
        if added {
            if builder.build() != nil {
                if let edgeShape = Shape.fromEdge(edges[0]) {
                    let deleted = builder.isDeleted(edgeShape)
                    #expect(deleted == true)  // The original edge should be replaced
                }
            }
        }
    }
}
