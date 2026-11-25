import Testing

@testable import OCCTSwift

/// `split(atPlane:normal:)` cuts a shape wherever the plane crosses it, and
/// `splitWithFullHistory(atPlane:normal:)` returns the same pieces with the splitter's history
/// (#3559).
///
/// A sub-shape is named by its bounds, never by an enumeration index, and every expected record is
/// the one OCCT's `BOPAlgo_Builder::PrepareHistory` writes, measured on these fixtures.
@Suite("split(atPlane:normal:) centring and history (#3559)")
struct SplitAtPlaneHistoryTests {

    // MARK: - Helpers

    static func close(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ t: Double = 1e-6) -> Bool {
        abs(a.x - b.x) <= t && abs(a.y - b.y) <= t && abs(a.z - b.z) <= t
    }

    /// The shapes among `shapes` whose bounds are `min`...`max`.
    static func matching(_ shapes: [Shape], min: SIMD3<Double>, max: SIMD3<Double>) -> [Shape] {
        shapes.filter { s in
            guard let b = s.bounds else { return false }
            return close(b.min, min) && close(b.max, max)
        }
    }

    /// The one sub-shape of `shape` of `type` whose bounds are `min`...`max`.
    static func unique(
        _ type: ShapeType, of shape: Shape, min: SIMD3<Double>, max: SIMD3<Double>
    ) throws -> Shape {
        let found = matching(shape.subShapes(ofType: type), min: min, max: max)
        try #require(found.count == 1, "exactly one \(type) of bounds \(min)...\(max)")
        return found[0]
    }

    /// The indices of the pieces holding a sub-shape that `isSame(as:)` `s`.
    static func owners(of s: Shape, in pieces: [Shape]) -> [Int] {
        pieces.indices.filter { i in
            pieces[i].subShapes(ofType: s.shapeType).contains { $0.isSame(as: s) }
        }
    }

    /// The origin-centred 10 mm box cut at z = 1, so the two pieces are told apart by height:
    /// z in [1, 5] (400 mm^3) and z in [-5, 1] (600 mm^3).
    static func cutBox() throws -> (
        box: Shape, pieces: [Shape], history: ShapeHistoryRef, cuttingFace: Shape
    ) {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(
            box.splitWithFullHistory(atPlane: SIMD3(0, 0, 1), normal: SIMD3(0, 0, 1)),
            "the split")
        try #require(r.pieces.count == 2, "the plane z = 1 crosses the box")
        return (box, r.pieces, r.history, r.cuttingFace)
    }

    // MARK: - The cutting face covers the shape wherever the point is

    /// The issue's own case.
    ///
    /// The cutting face was centred on the point passed in and reached twice the shape's diagonal
    /// (13.9 mm here), so this box 100 mm away came back as one piece.
    @Test("a box far from the plane's point is cut")
    func farBoxIsCut() throws {
        // x in [98, 102], y and z in [-2, 2]: the plane z = 0.5 leaves 4 x 4 x 2.5 above it and
        // 4 x 4 x 1.5 below.
        let box = try #require(
            Shape.box(origin: SIMD3(98, -2, -2), width: 4, height: 4, depth: 4))
        let point = SIMD3<Double>(0, 0, 0.5)
        let up = SIMD3<Double>(0, 0, 1)
        let plain = try #require(box.split(atPlane: point, normal: up))
        let kept = try #require(box.splitWithFullHistory(atPlane: point, normal: up))

        for pieces in [plain, kept.pieces] {
            try #require(pieces.count == 2, "the plane crosses the box")
            let volumes = try pieces.map { try #require($0.volume) }.sorted()
            #expect(abs(volumes[0] - 24) < 1e-6)
            #expect(abs(volumes[1] - 40) < 1e-6)
            for piece in pieces {
                let b = try #require(piece.bounds)
                #expect(abs(b.min.x - 98) < 1e-6 && abs(b.max.x - 102) < 1e-6)
                #expect(abs(b.max.z - 0.5) < 1e-6 || abs(b.min.z - 0.5) < 1e-6)
            }
        }
    }

    /// The same defect from the other side: the shape at the origin, the point far along the
    /// plane in a direction that is not an axis of it.
    @Test("a point far along the plane still cuts the shape")
    func farPointCuts() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let pieces = try #require(
            box.split(atPlane: SIMD3(1000, -700, 1), normal: SIMD3(0, 0, 1)))
        try #require(pieces.count == 2, "the plane z = 1 crosses the box")
        let volumes = try pieces.map { try #require($0.volume) }.sorted()
        #expect(abs(volumes[0] - 400) < 1e-6)
        #expect(abs(volumes[1] - 600) < 1e-6)
    }

    // MARK: - The history variant returns the plain split's pieces

    /// The history variant returns the plain split's pieces, in its order.
    ///
    /// The cases are where the two could part: a cut; a plane that misses, where the splitter's
    /// result is the solid itself rather than a compound of it, so the result's children would be
    /// its shells; a plane on a face; a shell; a lone face; a compound of two solids; the far box;
    /// a tilted cut.
    ///
    /// One test walking a list, not `@Test(arguments:)`: an argument pairing a `String` with a
    /// `SIMD3<Double>` corrupts the Swift task allocator in a debug build, whatever the test body
    /// does (#1057, swiftlang/swift#91639).
    @Test("the history variant returns the plain split's pieces, in order")
    func historyMatchesPlainSplit() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shell = try #require(box.shells.first)
        let top = try Self.unique(.face, of: box, min: SIMD3(-5, -5, 5), max: SIMD3(5, 5, 5))
        let other = try #require(box.translated(by: SIMD3(20, 0, 0)))
        let pair = try #require(Shape.compound([box, other]))
        let far = try #require(
            Shape.box(origin: SIMD3(98, -2, -2), width: 4, height: 4, depth: 4))
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let up = SIMD3<Double>(0, 0, 1)
        let tilt = SIMD3<Double>(0.2, 0.3, 1)
        let cases:
            [(name: String, shape: Shape, point: SIMD3<Double>, normal: SIMD3<Double>, count: Int)] =
                [
                    ("cut", box, SIMD3(0, 0, 1), up, 2),
                    ("missed", box, SIMD3(0, 0, 20), up, 1),
                    ("onFace", box, SIMD3(0, 0, 5), up, 1),
                    ("shell", shell, SIMD3(0, 0, 1), up, 1),
                    ("loneFace", top, .zero, SIMD3(0, 1, 0), 1),
                    ("pair", pair, SIMD3(0, 0, 1), up, 4),
                    ("far", far, SIMD3(0, 0, 0.5), up, 2),
                    ("tiltedCylinder", cylinder, SIMD3(1, 1, 4), tilt, 2),
                ]
        // The list is a literal over required fixtures, so no row can go missing; the names pin it.
        #expect(
            cases.map(\.name) == [
                "cut", "missed", "onFace", "shell", "loneFace", "pair", "far", "tiltedCylinder",
            ])

        for c in cases {
            let plain = try #require(c.shape.split(atPlane: c.point, normal: c.normal), "\(c.name)")
            let kept = try #require(
                c.shape.splitWithFullHistory(atPlane: c.point, normal: c.normal), "\(c.name)")
            #expect(plain.count == c.count, "\(c.name): the plain split's piece count")
            try #require(kept.pieces.count == plain.count, "\(c.name): the same number of pieces")
            for (i, (a, b)) in zip(plain, kept.pieces).enumerated() {
                let label = "\(c.name) piece \(i)"
                #expect(a.shapeType == b.shapeType, "\(label): type")
                #expect(a.faceCount == b.faceCount, "\(label): faces")
                #expect(
                    a.subShapes(ofType: .edge).count == b.subShapes(ofType: .edge).count,
                    "\(label): edges")
                #expect(abs((a.volume ?? 0) - (b.volume ?? 0)) < 1e-9, "\(label): volume")
                #expect(
                    abs((a.surfaceArea ?? 0) - (b.surfaceArea ?? 0)) < 1e-9, "\(label): area")
                let ba = try #require(a.bounds, "\(label)")
                let bb = try #require(b.bounds, "\(label)")
                #expect(
                    Self.close(ba.min, bb.min, 1e-9) && Self.close(ba.max, bb.max, 1e-9),
                    "\(label): bounds")
            }
        }
    }

    /// A plane that misses a solid returns the solid itself.
    ///
    /// This is the trap a wrapped `splitWithFullHistory(by:)` hit downstream
    /// (OCCTSwiftInteraction#83), where the same split came back as the solid's shells. The
    /// cutting face, in no piece, is deleted.
    @Test("a plane that misses a solid returns the solid itself")
    func missedSolidIsTheSolid() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(
            box.splitWithFullHistory(atPlane: SIMD3(0, 0, 20), normal: SIMD3(0, 0, 1)))
        try #require(r.pieces.count == 1)
        #expect(r.pieces[0].shapeType == .solid)
        #expect(r.pieces[0].isSame(as: box))
        let tool = r.history.record(of: r.cuttingFace)
        #expect(tool.isDeleted)
        #expect(tool.modified.isEmpty && tool.generated.isEmpty)
    }

    // MARK: - What the history records

    /// A face the plane misses is in exactly one piece, unchanged, with an empty record.
    ///
    /// The side face in the same history is the control: the plane split it, so it is in no
    /// piece.
    @Test("a face the plane misses maps to itself")
    func untouchedFaceMapsToItself() throws {
        let (box, pieces, history, _) = try Self.cutBox()
        let top = try Self.unique(.face, of: box, min: SIMD3(-5, -5, 5), max: SIMD3(5, 5, 5))
        let bottom = try Self.unique(
            .face, of: box, min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, -5))
        let above = try #require(pieces.firstIndex { ($0.bounds?.min.z ?? 0) > 0 })
        let below = try #require(pieces.firstIndex { ($0.bounds?.max.z ?? 0) < 2 })
        for (face, piece) in [(top, above), (bottom, below)] {
            let r = history.record(of: face)
            #expect(r.modified.isEmpty)
            #expect(r.generated.isEmpty)
            #expect(!r.isDeleted)
            #expect(Self.owners(of: face, in: pieces) == [piece])
        }

        let side = try Self.unique(.face, of: box, min: SIMD3(5, -5, -5), max: SIMD3(5, 5, 5))
        #expect(Self.owners(of: side, in: pieces).isEmpty)
        #expect(history.record(of: side).modified.count == 2)
    }

    /// A face the plane crosses is modified into its two pieces and generates its section edge.
    ///
    /// The two pieces lie one in each piece of the box. A vertical edge likewise: two pieces and
    /// the section vertex.
    @Test("a face the plane crosses maps to its pieces")
    func cutFaceMapsToItsPieces() throws {
        let (box, pieces, history, _) = try Self.cutBox()
        let side = try Self.unique(.face, of: box, min: SIMD3(5, -5, -5), max: SIMD3(5, 5, 5))
        let r = history.record(of: side)
        #expect(!r.isDeleted)
        try #require(r.modified.count == 2)
        let upper = Self.matching(r.modified, min: SIMD3(5, -5, 1), max: SIMD3(5, 5, 5))
        let lower = Self.matching(r.modified, min: SIMD3(5, -5, -5), max: SIMD3(5, 5, 1))
        #expect(upper.count == 1 && lower.count == 1)
        let areas = try r.modified.map { try #require($0.surfaceArea) }.sorted()
        #expect(abs(areas[0] - 40) < 1e-6 && abs(areas[1] - 60) < 1e-6)
        let owners = r.modified.map { Self.owners(of: $0, in: pieces) }
        #expect(owners.allSatisfy { $0.count == 1 })
        #expect(Set(owners.flatMap { $0 }) == [0, 1])

        // Its section edge: the line z = 1 across it.
        let sectionEdges = r.generated.filter { $0.shapeType == .edge }
        try #require(sectionEdges.count == 1)
        let eb = try #require(sectionEdges[0].bounds)
        #expect(Self.close(eb.min, SIMD3(5, -5, 1)) && Self.close(eb.max, SIMD3(5, 5, 1)))

        let corner = try Self.unique(.edge, of: box, min: SIMD3(5, 5, -5), max: SIMD3(5, 5, 5))
        let e = history.record(of: corner)
        #expect(!e.isDeleted)
        #expect(e.modified.count == 2)
        let vertices = e.generated.filter { $0.shapeType == .vertex }
        try #require(vertices.count == 1)
        let vb = try #require(vertices[0].bounds)
        #expect(Self.close(vb.min, SIMD3(5, 5, 1)) && Self.close(vb.max, SIMD3(5, 5, 1)))
    }

    /// The cutting face's record holds the cap face and the section edges.
    ///
    /// Its `modified` is the cap face: what is left of the tool face inside the box, one face both
    /// pieces share. Its `generated` is the section edges and their vertices. The cap face is not
    /// in `generated`: OCCT generates only edges and vertices from a face
    /// (`BOPAlgo_Builder::LocGenerated`), and the cap is a split of the tool face.
    @Test("the cutting face records the cap face and the section edges")
    func cuttingFaceRecordsCapAndSection() throws {
        let (box, pieces, history, cuttingFace) = try Self.cutBox()
        #expect(cuttingFace.shapeType == .face)
        let r = history.record(of: cuttingFace)
        #expect(!r.isDeleted)

        try #require(r.modified.count == 1)
        let cap = r.modified[0]
        #expect(cap.shapeType == .face)
        let cb = try #require(cap.bounds)
        #expect(Self.close(cb.min, SIMD3(-5, -5, 1)) && Self.close(cb.max, SIMD3(5, 5, 1)))
        #expect(abs((cap.surfaceArea ?? 0) - 100) < 1e-6)
        #expect(Self.owners(of: cap, in: pieces) == [0, 1])
        #expect(!box.subShapes(ofType: .face).contains { $0.isSame(as: cap) })

        let edges = r.generated.filter { $0.shapeType == .edge }
        let vertices = r.generated.filter { $0.shapeType == .vertex }
        #expect(r.generated.count == edges.count + vertices.count)
        #expect(!r.generated.contains { $0.isSame(as: cap) })
        try #require(edges.count == 4)
        #expect(vertices.count == 4)
        let capEdges = cap.subShapes(ofType: .edge)
        for edge in edges {
            let b = try #require(edge.bounds)
            #expect(abs(b.min.z - 1) < 1e-6 && abs(b.max.z - 1) < 1e-6)
            #expect(capEdges.contains { $0.isSame(as: edge) })
            #expect(Self.owners(of: edge, in: pieces) == [0, 1])
        }
        // Each is also generated by the side face it lies on.
        let sides = box.subShapes(ofType: .face).filter { f in
            guard let b = f.bounds else { return false }
            return b.max.z - b.min.z > 1
        }
        try #require(sides.count == 4)
        for side in sides {
            let fromSide = history.record(of: side).generated.filter { $0.shapeType == .edge }
            try #require(fromSide.count == 1)
            #expect(edges.contains { $0.isSame(as: fromSide[0]) })
        }
    }
}
