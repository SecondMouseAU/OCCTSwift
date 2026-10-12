import Foundation
import Testing

@testable import OCCTSwift

// #3332: the four tests ended in `#expect(section != nil)` or `let _ = ancestor; #expect(true)`
// ("May or may not find ancestor"), under `if let` on every step. Measured on the pinned kernel:
//   * a 10 mm cube against a radius-7 sphere gives a section of 6 circles of radius sqrt(24) that
//     each fit inside a cube face: total edge length 6 * 2 pi sqrt(24) = 184.687 in 7 edges (one
//     circle is split by the sphere's seam), whichever of approximation / pcurve flags is set
//   * `Shape.sectionAncestorFaceOn1/2` return nil for EVERY edge, because the edge they take comes
//     from a different build of the section than the one they look it up in (#3355). The
//     `SectionBuilder` instance API, whose edges come from its own build, resolves them.
@Suite("v0.123.0, BRepAlgoAPI_Section extended")
struct SectionExtendedTests {

    private func edgeTotal(_ shape: Shape) -> (count: Int, total: Double) {
        let lengths = shape.edges().map { $0.length }
        return (lengths.count, lengths.reduce(0, +))
    }

    private let expectedTotal = 6 * 2 * Double.pi * 24.0.squareRoot()

    @Test("Section with approximation")
    func sectionWithApproximation() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 7.0))
        let section = try #require(Shape.sectionWithOptions(box, sphere, approximation: true))
        let (count, total) = edgeTotal(section)
        #expect(count == 7)
        #expect(abs(total - expectedTotal) < 1e-3)
        // The section lies on the sphere, inside the cube's bounding box.
        let bounds = try #require(section.bounds)
        #expect(abs(bounds.min.x + 5) < 1e-3 && abs(bounds.max.x - 5) < 1e-3)

        // Without approximation the same geometry: the flag changes how the curves are
        // represented, not where they are.
        let exact = try #require(Shape.sectionWithOptions(box, sphere, approximation: false))
        #expect(abs(edgeTotal(exact).total - expectedTotal) < 1e-3)

        // A sphere that does not reach the cube's faces has no section: radius 4 sits inside.
        let inside = try #require(Shape.sphere(radius: 4.0))
        let none = try #require(Shape.sectionWithOptions(box, inside, approximation: true))
        #expect(none.edges().isEmpty)
    }

    @Test("Section with pcurves")
    func sectionWithPcurves() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let sphere = try #require(Shape.sphere(radius: 7.0))
        let section = try #require(
            Shape.sectionWithOptions(
                box, sphere, approximation: true, computePCurve1: true, computePCurve2: true))
        let (count, total) = edgeTotal(section)
        #expect(count == 7)
        #expect(abs(total - expectedTotal) < 1e-3)
        // Every section edge lies on the sphere: its sampled points are 7 from the origin.
        for edge in section.edges() {
            let range = try #require(edge.parameterBounds)
            for t in [0.0, 0.5, 1.0] {
                let u = range.first + (range.last - range.first) * t
                let p = try #require(edge.point(at: u))
                let radius = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                #expect(abs(radius - 7) < 1e-4)
            }
        }
    }

    // Two overlapping corner-placed cubes: [0,10]^3 and [5,15] x [5,15] x [0,10]. The section has
    // two 10 mm vertical edges that carry ancestor faces: (10, 5, *) on box1's x = 10 face and
    // (5, 10, *) on box1's y = 10 face.
    private func overlappingCubes() throws -> (Shape, Shape) {
        let box1 = try #require(Shape.box(origin: .zero, width: 10, height: 10, depth: 10))
        let box2 = try #require(Shape.box(origin: SIMD3(5, 5, 0), width: 10, height: 10, depth: 10))
        return (box1, box2)
    }

    @Test("Ancestor face on shape1")
    func ancestorFace1() throws {
        let (box1, box2) = try overlappingCubes()
        let section = try #require(
            Shape.sectionWithOptions(box1, box2, approximation: true, computePCurve1: true))
        let verticals = section.subShapes(ofType: .edge).filter {
            abs(($0.edges().first?.length ?? 0) - 10) < 1e-6
        }
        #expect(verticals.count == 2)

        // The instance API resolves both verticals on the same fixture: the control that the
        // fixture has ancestors to find.
        let builder = try #require(SectionBuilder(shape1: box1, shape2: box2))
        builder.setApproximation(true)
        builder.computePCurveOn1(true)
        let built = try #require(builder.build())
        let builderVerticals = built.subShapes(ofType: .edge).filter {
            abs(($0.edges().first?.length ?? 0) - 10) < 1e-6
        }
        #expect(builderVerticals.count == 2)
        for edge in builderVerticals {
            let face = try #require(builder.ancestorFaceOn1(edge: edge))
            let b = try #require(face.bounds)
            let thinAxis = (0..<3).filter { b.max[$0] - b.min[$0] < 1e-3 }
            #expect(thinAxis.count == 1)
            if let axis = thinAxis.first { #expect(abs(b.min[axis] - 10) < 1e-3) }
        }

        withKnownIssue("#3355: the static ancestor query looks up an edge from another build") {
            for edge in verticals {
                let ancestor = Shape.sectionAncestorFaceOn1(
                    box1, box2, edge: edge, approximation: true, computePCurve1: true)
                #expect(ancestor != nil)
            }
        }
    }

    @Test("Ancestor face on shape2")
    func ancestorFace2() throws {
        let (box1, box2) = try overlappingCubes()
        let section = try #require(
            Shape.sectionWithOptions(box1, box2, approximation: true, computePCurve2: true))
        let verticals = section.subShapes(ofType: .edge).filter {
            abs(($0.edges().first?.length ?? 0) - 10) < 1e-6
        }
        #expect(verticals.count == 2)

        // box2's faces on the two verticals: its y = 5 face and its x = 5 face.
        let builder = try #require(SectionBuilder(shape1: box1, shape2: box2))
        builder.setApproximation(true)
        builder.computePCurveOn2(true)
        let built = try #require(builder.build())
        let builderVerticals = built.subShapes(ofType: .edge).filter {
            abs(($0.edges().first?.length ?? 0) - 10) < 1e-6
        }
        #expect(builderVerticals.count == 2)
        for edge in builderVerticals {
            let face = try #require(builder.ancestorFaceOn2(edge: edge))
            let b = try #require(face.bounds)
            let thinAxis = (0..<3).filter { b.max[$0] - b.min[$0] < 1e-3 }
            #expect(thinAxis.count == 1)
            if let axis = thinAxis.first { #expect(abs(b.min[axis] - 5) < 1e-3) }
        }

        withKnownIssue("#3355: the static ancestor query looks up an edge from another build") {
            for edge in verticals {
                let ancestor = Shape.sectionAncestorFaceOn2(
                    box1, box2, edge: edge, approximation: true, computePCurve2: true)
                #expect(ancestor != nil)
            }
        }
    }
}
