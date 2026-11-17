import Foundation
import Testing

@testable import OCCTSwift

/// Regression for #3527: `Shape.measure()` read each edge length through `edge(at:)` in a loop.
///
/// Every `edge(at:)` builds the whole sub-shape map to read one entry, so the loop cost one map per
/// edge: quadratic, and on a 3,888-edge shape 1.4 to 2.5 s of a 1.6 to 2.8 s call. The lengths now
/// come from one `edges()` enumeration (#3526), which maps once.
///
/// Two halves, because the first cannot see the defect and the second cannot see a wrong answer:
///
/// 1. **Same answer.** On every shape in the battery `edgeLengths` is, element for element, what
///    the per-index loop gave: the same count, the same order, the same length, and so the same
///    total. A faster `measure()` that reorders, drops or duplicates an entry misreports every
///    edge after it, and the numbers look plausible.
/// 2. **Linear cost.** The per-edge cost of `measure()` does not grow with the edge count. The
///    shape is a compound of separate line edges with no face at all, so the face work
///    (area, centroid and perimeter of every face) is nil and the edge lengths are all the ratio
///    reads. A shape with faces cannot isolate them: a many-edge planar face spends about
///    0.1 ms per edge on its own area and perimeter, which swamps the per-index loop's cost.
@Suite("Shape.measure() reads the edge lengths off one enumeration")
struct ShapeMeasureEdgeLengthsTests {

    // MARK: - Fixtures

    /// The names `battery()` must produce, declared apart from the builder so that a fixture which
    /// stops being built is a failure and not a smaller loop.
    static let batteryNames: Set<String> = [
        "box", "filletedBox", "cylinder", "sphere", "cone", "lBracket", "boxWithItself",
        "splitBoxCompound", "compoundOf20Boxes", "lineCompound", "bareFace", "emptiedSolid",
        "vertex",
    ]

    /// Every shape `measure()` is compared on.
    ///
    /// Each is built with `#require`, so a fixture that stops being buildable fails here rather
    /// than shortening the battery.
    static func battery() throws -> [(name: String, shape: Shape)] {
        let box = try #require(Shape.box(width: 2, height: 3, depth: 5))
        var shapes: [(name: String, shape: Shape)] = []

        shapes.append(("box", box))
        shapes.append(("filletedBox", try #require(box.filleted(radius: 0.5))))
        shapes.append(("cylinder", try #require(Shape.cylinder(radius: 5, height: 10))))
        shapes.append(("sphere", try #require(Shape.sphere(radius: 5))))
        shapes.append(
            ("cone", try #require(Shape.cone(bottomRadius: 5, topRadius: 0, height: 10))))

        // Two fused boxes: faces meet along edges that belong to both, and one edge is concave.
        let plate = try #require(Shape.box(width: 40, height: 40, depth: 10))
        let wall = try #require(Shape.box(width: 10, height: 40, depth: 40))
        shapes.append(("lBracket", try #require(plate.union(wall))))

        // One TShape reached twice, and two solids sharing a cut face: edges reachable from more
        // than one parent, which the enumeration lists once.
        shapes.append(("boxWithItself", try #require(Shape.compound([box, box]))))
        let halves = try #require(box.split(atPlane: SIMD3(0, 0, 1), normal: SIMD3(0, 0, 1)))
        shapes.append(("splitBoxCompound", try #require(Shape.compound(halves))))

        let row = try (0..<20).map { i in
            try #require(box.translated(by: SIMD3(Double(i) * 20, 0, 0)))
        }
        shapes.append(("compoundOf20Boxes", try #require(Shape.compound(row))))

        // Edges and no face: nothing for the face measurements to do.
        shapes.append(("lineCompound", try lineCompound(count: 30)))

        let firstFace = try #require(box.face(at: 0))
        shapes.append(("bareFace", try #require(Shape.fromFace(firstFace))))

        // No edge to measure, two different ways of having none.
        shapes.append(("emptiedSolid", try #require(box.emptied)))
        shapes.append(("vertex", try #require(Shape.vertex(at: SIMD3(1, 2, 3)))))

        return shapes
    }

    /// `count` separate straight edges of length 1 and no face: `count` edges, nothing else.
    static func lineCompound(count: Int) throws -> Shape {
        let lines = try (0..<count).map { i -> Shape in
            let wire = try #require(
                Wire.line(from: SIMD3(Double(i) * 2, 0, 0), to: SIMD3(Double(i) * 2 + 1, 0, 0)))
            return try #require(Shape.fromWire(wire))
        }
        return try #require(Shape.compound(lines))
    }

    /// One planar face bounded by a regular `sides`-gon of the given circumradius: `sides` edges,
    /// one face, so the work that is not the edge enumeration stays small.
    static func polygonFace(sides: Int, radius: Double = 100) throws -> Shape {
        let points = (0..<sides).map { i -> SIMD2<Double> in
            let angle = 2 * Double.pi * Double(i) / Double(sides)
            return SIMD2(radius * cos(angle), radius * sin(angle))
        }
        let wire = try #require(Wire.polygon(points, closed: true))
        return try #require(Shape.face(from: wire))
    }

    /// What `measure()` computed before #3527: one `edge(at:)` per edge, a missing edge reading 0.
    static func perIndexLengths(_ shape: Shape) -> [Double] {
        (0..<shape.edgeCount).map { shape.edge(at: $0)?.length ?? 0 }
    }

    // MARK: - The fixtures mean their names

    @Test("The battery holds exactly the shapes it declares")
    func batteryMembership() throws {
        let built = try Self.battery()
        #expect(Set(built.map { $0.name }) == Self.batteryNames)
        #expect(built.count == Self.batteryNames.count, "a name was built twice")
    }

    /// A fixture that has stopped being what its name says proves nothing about the measurement.
    ///
    /// The operation fixtures must have changed the topology (a fillet that silently did nothing
    /// leaves the plain box, which the first fixture already is), and the two with sharing must
    /// still share: counted one solid at a time the split halves hold more edges than the compound.
    @Test("The fixtures really have the edges their names claim")
    func fixturesMeanTheirNames() throws {
        let byName = Dictionary(
            uniqueKeysWithValues: try Self.battery().map { ($0.name, $0.shape) })
        func edges(_ name: String) throws -> Int {
            try #require(byName[name], "no fixture named \(name)").edgeCount
        }

        #expect(try edges("box") == 12)
        #expect(try edges("filletedBox") > 12, "the fillet should have added edges")
        #expect(try edges("cylinder") == 3)
        // One TShape handed in twice: the walk visits every edge twice as often as a lone box's,
        // and the map still holds 12.
        let doubled = try #require(byName["boxWithItself"])
        let single = try #require(byName["box"])
        #expect(try edges("boxWithItself") == 12, "the same TShape twice is still 12 edges")
        #expect(
            doubled.contents.edges == 2 * single.contents.edges,
            "boxWithItself no longer reaches the same box twice")
        #expect(try edges("lineCompound") == 30)
        #expect(
            try #require(byName["lineCompound"]).faceCount == 0, "the lines should bound no face")
        #expect(try edges("compoundOf20Boxes") == 240)
        #expect(try edges("lBracket") > 12, "the fuse should leave more edges than one box")

        let split = try #require(byName["splitBoxCompound"])
        let solids = split.solids
        #expect(solids.count == 2, "the split should leave two solids")
        #expect(
            solids.map { $0.edgeCount }.reduce(0, +) > split.edgeCount,
            "the two halves share no edge, so the fixture no longer exercises sharing")

        for name in ["emptiedSolid", "vertex"] {
            #expect(try edges(name) == 0, "\(name) should have no edge")
        }
    }

    // MARK: - Same answer as the per-index loop

    /// `measure().edgeLengths` against the loop it replaced, element for element.
    static func expectSameAsPerIndex(_ name: String, _ shape: Shape) {
        let measured = shape.measure().edgeLengths
        let perIndex = perIndexLengths(shape)

        #expect(
            measured.count == perIndex.count,
            "\(name): measure() reports \(measured.count) lengths, the loop \(perIndex.count)")
        #expect(measured.count == shape.edgeCount, "\(name): not one length per edge")
        for (k, pair) in zip(measured, perIndex).enumerated() {
            #expect(
                abs(pair.0 - pair.1) <= 1e-12,
                "\(name): edgeLengths[\(k)] is \(pair.0), edge(at: \(k)).length is \(pair.1)")
        }
        #expect(
            abs(measured.reduce(0, +) - perIndex.reduce(0, +)) <= 1e-9,
            "\(name): totalEdgeLength moved")
    }

    @Test("measure() edge lengths are the per-index loop's, element for element, on every fixture")
    func measureEqualsThePerIndexLoop() throws {
        for (name, shape) in try Self.battery() {
            Self.expectSameAsPerIndex(name, shape)
        }
    }

    @Test("measure() totalEdgeLength is unchanged for the known fixtures")
    func totalsAreTheKnownValues() throws {
        let box = try #require(Shape.box(width: 2, height: 3, depth: 5))
        #expect(abs(box.measure().totalEdgeLength - 40.0) < 1e-6)

        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(abs(cylinder.measure().totalEdgeLength - (20 * Double.pi + 10)) < 1e-6)

        // Twenty disjoint boxes, each 4 * (2 + 3 + 5) = 40 of edge.
        let row = try (0..<20).map { i in
            try #require(box.translated(by: SIMD3(Double(i) * 20, 0, 0)))
        }
        let compound = try #require(Shape.compound(row))
        #expect(abs(compound.measure().totalEdgeLength - 800.0) < 1e-6)
    }

    /// The same comparison on a shape with thousands of edges, against an oracle that involves no
    /// edge enumeration at all: a regular n-gon of circumradius R has perimeter 2 n R sin(pi / n).
    @Test("measure() on a 2,000-edge polygon matches the loop and the closed-form perimeter")
    func measureOnAManyEdgeFace() throws {
        let sides = 2_000
        let radius = 100.0
        let face = try Self.polygonFace(sides: sides, radius: radius)
        #expect(face.edgeCount == sides, "the polygon should have one edge per side")

        Self.expectSameAsPerIndex("polygon2000", face)

        let perimeter = 2 * Double(sides) * radius * sin(Double.pi / Double(sides))
        let total = face.measure().totalEdgeLength
        #expect(abs(total - perimeter) < 1e-6, "total \(total), closed form \(perimeter)")
    }

    @Test("An edgeless shape measures no edge lengths")
    func edgelessShapesMeasureNoEdges() throws {
        let byName = Dictionary(
            uniqueKeysWithValues: try Self.battery().map { ($0.name, $0.shape) })
        for name in ["emptiedSolid", "vertex"] {
            let shape = try #require(byName[name], "no fixture named \(name)")
            let measured = shape.measure()
            #expect(measured.edgeLengths.isEmpty, "\(name) has no edges to measure")
            #expect(measured.totalEdgeLength == 0)
        }
    }

    // MARK: - Linear cost

    /// The per-edge cost of `measure()` at one size.
    ///
    /// Complexity class, not wall clock: a ratio of two measurements taken in the same process,
    /// the arrangement the `edges()` and `allEdgePolylines` guards use for the same defect (#3526,
    /// #275). Each size is timed as repeated passes until the clock can see them, and the smallest
    /// of three such batches is kept, so one descheduled slice does not read as growth.
    static func perEdgeCost(lines: Int) throws -> (cost: Double, edges: Int) {
        let shape = try lineCompound(count: lines)
        let edgeCount = shape.edgeCount

        let floor = 0.010
        var smallest = Double.infinity
        for _ in 0..<3 {
            var passes = 0
            var elapsed = 0.0
            let start = Date()
            while elapsed < floor {
                #expect(shape.measure().edgeLengths.count == edgeCount)
                passes += 1
                elapsed = Date().timeIntervalSince(start)
            }
            smallest = min(smallest, elapsed / Double(edgeCount * passes))
        }
        return (smallest, edgeCount)
    }

    @Test("measure() per-edge cost does not grow with the number of edges")
    func measureScalesLinearly() throws {
        let small = try Self.perEdgeCost(lines: 100)
        let large = try Self.perEdgeCost(lines: 4_000)

        // The comparison means nothing unless the large shape is far larger than the small one.
        #expect(large.edges >= small.edges * 40)

        // Linear: the per-edge cost stays roughly constant. The per-index loop rebuilt the whole
        // map for every edge, so its per-edge cost grew with the edge count.
        #expect(
            large.cost < small.cost * 8,
            "per-edge cost grew \(large.cost / small.cost)x from \(small.edges) to \(large.edges) edges, measure() looks quadratic again"
        )
    }
}
