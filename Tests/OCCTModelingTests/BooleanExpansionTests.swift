import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Boolean Expansion")
struct BooleanExpansionTests {

    // #766: sectionWithTolerance, splitMulti and cutWithHistory nested every assertion inside an
    // `if let` on their fixture boxes, so a box that failed to build skipped the test and it
    // passed; the fixtures come from here now, through try #require. Fixtures are corner-based
    // (Shape.box(width:height:depth:) is centred), and every boolean gets its own boxes: a fuzzy
    // boolean raises the tolerance of its arguments' sub-shapes in place, so a second operation on
    // boxes a first one used is not measured on the boxes the kernel probe uses.
    // Kernel values: Scripts/repro/766-modeling-boolean-expansion/probe-evidence-fix.mm.
    private func makeBox(
        _ origin: SIMD3<Double>, size: SIMD3<Double> = SIMD3(repeating: 10)
    ) throws -> Shape {
        try #require(
            Shape.box(origin: origin, width: size.x, height: size.y, depth: size.z),
            "fixture box at \(origin) failed")
    }

    // The 20 mm cube (-10..10) that splitMulti and cutWithHistory work on.
    private func makeBigCube() throws -> Shape {
        try makeBox(SIMD3(-10, -10, -10), size: SIMD3(repeating: 20))
    }

    @Test func sectionWithTolerance() throws {
        // Two 10 mm cubes 0.001 apart on coincident planes (x 0..10 and 10.001..20.001). This
        // used to be a corner-touch (one vertex, no edge) that asserted only a non-nil result.
        let origin1 = SIMD3<Double>(0, 0, 0)
        let origin2 = SIMD3<Double>(10.001, 0, 0)

        // Control: no fuzzy value, so the gap stands and the section is empty.
        let strictBox1 = try makeBox(origin1)
        let strictBox2 = try makeBox(origin2)
        let strict = try #require(strictBox1.section(with: strictBox2, tolerance: 0))
        #expect(strict.subShapes(ofType: .edge).isEmpty)
        #expect(strict.subShapes(ofType: .vertex).isEmpty)

        // Fuzzy 0.01 is larger than the gap: the two facing faces count as touching, and their
        // shared outline is the section, a square of 4 edges and 4 vertices.
        let box1 = try makeBox(origin1)
        let box2 = try makeBox(origin2)
        let section = try #require(box1.section(with: box2, tolerance: 0.01))
        #expect(section.subShapes(ofType: .edge).count == 4)
        #expect(section.subShapes(ofType: .vertex).count == 4)
    }

    @Test func splitMulti() throws {
        // The 20 mm cube and a 10 mm tool cube at (5,5,5) overlapping its corner in a
        // 5 x 5 x 5 block: the split leaves that block and the rest of the cube, two solids.
        // This used to assert only that the result was non-nil.
        let box = try makeBigCube()
        let tool = try makeBox(SIMD3(5, 5, 5))
        let split = try #require(box.split(tools: [tool]))
        let solids = split.subShapes(ofType: .solid)
        try #require(solids.count == 2)
        let volumes = solids.compactMap(\.volume).sorted()
        try #require(volumes.count == 2)
        #expect(abs(volumes[0] - 125) < 1e-6)
        #expect(abs(volumes[1] - 7875) < 1e-6)
    }

    // The 20 mm cube cut by a tool cube, with the history flags BRepAlgoAPI_Cut reports.
    private func cutBigCubeWithHistory(
        tool origin: SIMD3<Double>, size: SIMD3<Double> = SIMD3(repeating: 10)
    ) throws -> Shape.BooleanHistoryResult {
        let cube = try makeBigCube()
        let tool = try makeBox(origin, size: size)
        return try #require(cube.subtractedWithHistory(tool), "cut with history returned nil")
    }

    @Test func cutWithHistory() throws {
        // The three history flags used to be read into `let _` and dropped, and the one fixture
        // (a corner overlap) sets all three, so a bridge that reported true for everything would
        // have passed. Three tools separate them: a corner overlap (deleted, modified and
        // generated), a tool clear of the cube (the tool is deleted, nothing of the cube is
        // modified or generated) and a tool buried inside it (the cube's faces are modified, no
        // face is generated).
        let overlap = try cutBigCubeWithHistory(tool: SIMD3(5, 5, 5))
        #expect(overlap.shape.isValid)
        let overlapVolume = try #require(overlap.shape.volume)
        #expect(abs(overlapVolume - 7875) < 1e-6)
        #expect(overlap.hasDeleted)
        #expect(overlap.hasModified)
        #expect(overlap.hasGenerated)

        let clear = try cutBigCubeWithHistory(tool: SIMD3(100, 0, 0))
        #expect(clear.shape.isValid)
        let clearVolume = try #require(clear.shape.volume)
        #expect(abs(clearVolume - 8000) < 1e-6)
        #expect(clear.hasDeleted)
        #expect(!clear.hasModified)
        #expect(!clear.hasGenerated)

        let buried = try cutBigCubeWithHistory(tool: SIMD3(-2, -2, -2), size: SIMD3(repeating: 4))
        #expect(buried.shape.isValid)
        let buriedVolume = try #require(buried.shape.volume)
        #expect(abs(buriedVolume - 7936) < 1e-6)
        #expect(buried.hasDeleted)
        #expect(buried.hasModified)
        #expect(!buried.hasGenerated)
    }

    // The tolerance argument this test used to pass is gone: BRepAlgoAPI_Defeaturing never read
    // it, so the overload that took one is deprecated. Issue497DefeaturingTests covers that. #497
    @Test func defeature() throws {
        // #766: every assertion here used to sit inside `if let` of the fillet, of `faces.count > 6`
        // and of the defeature result ("may or may not succeed"), so a defeature that returned nil
        // passed. The kernel does succeed (Scripts/repro/766-modeling-boolean-expansion): the r=2
        // filleted 20mm box has 26 faces, BRepAlgoAPI_Defeaturing removes ordinals 6 and 7 and
        // returns a valid solid of 25 faces whose volume grows by 1.791585.
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20), "fixture box failed")
        let f = try #require(box.filleted(radius: 2.0), "filleting the fixture box failed")
        let faces = f.subShapes(ofType: .face)
        #expect(faces.count == 26)
        try #require(faces.count > 7)
        let filletFaces = Array(faces[6...7])
        let r = try #require(
            f.defeature(faces: filletFaces), "defeaturing two fillet faces returned nil")
        #expect(r.isValid)
        #expect(r.subShapes(ofType: .face).count == 25)
        let before = try #require(f.volume, "volume of the filleted box failed")
        let after = try #require(r.volume, "volume of the defeatured box failed")
        // Removing fillet faces can only add material back.
        #expect(abs((after - before) - 1.791585) < 1e-4)
    }
}
