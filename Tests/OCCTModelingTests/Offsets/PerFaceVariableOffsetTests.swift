import Testing

@testable import OCCTSwift

// MARK: - Per-Face Variable Offset Tests (v0.38.0)

// BRepOffset_MakeOffset::UpdateFaceOffset gives an entry's offset to every face connected to its
// face by a tangent edge and, for the Arc join, by an edge of the offset direction's own
// concavity (convex for a positive default offset). On a convex solid that is every face, so an
// Arc-join entry is a uniform offset (#3365). The tests pin that as the contract, pin the
// join/sign combinations where entries stay per face, and pin the refusal of entries the kernel
// would merge while disagreeing (it applied them in a per-process hash order).
@Suite("Per-Face Variable Offset")
struct PerFaceVariableOffsetTests {

    private func cube() throws -> Shape {
        try #require(Shape.box(width: 10, height: 10, depth: 10))
    }

    @Test("Uniform per-face offset matches default offset")
    func uniformPerFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:])
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(r.volume! > 1000.0)
        }
    }

    // Face 1 of the cube is x = +5. At 2 against the default 1 it should reach x = 7 while every
    // other face reaches 6: x in [-6, 7], volume 13 * 12 * 12 = 1872 with the intersection join.
    @Test("Variable offset on specific faces")
    func variableOffset() throws {
        let box = try cube()

        let sharp = try #require(
            box.offsetPerFace(
                defaultOffset: 1.0, faceOffsets: [1: 2.0], joinType: .intersection))
        #expect(sharp.isValid)
        let bounds = try #require(sharp.boundingBox)
        #expect(abs(bounds.min.x + 6.0) < 1e-5 && abs(bounds.max.x - 7.0) < 1e-5)
        #expect(abs(bounds.min.y + 6.0) < 1e-5 && abs(bounds.max.y - 6.0) < 1e-5)
        #expect(abs(bounds.min.z + 6.0) < 1e-5 && abs(bounds.max.z - 6.0) < 1e-5)
        // 13 x 12 x 12; the 1728 uniform-1 cube plus the slab the one face moved.
        #expect(abs((sharp.volume ?? -1) - 13.0 * 12.0 * 12.0) < 1e-6)
    }

    // The Arc join, the default: the one entry reaches every convex-connected face, so the whole
    // cube is offset by that entry (7, not the default 6), whatever face it names, and the
    // default is not used at all. Same shape as the uniform offset of that distance.
    @Test("Arc join applies one entry to every convex-connected face")
    func arcEntryIsUniform() throws {
        let box = try cube()
        let uniform2 = try #require(box.offsetPerFace(defaultOffset: 2.0, faceOffsets: [:]))
        let uniform2Volume = try #require(uniform2.volume)
        #expect(abs(uniform2Volume - 2610.5014) < 1e-3)

        for face in 0..<6 {
            let entry = try #require(
                box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [face: 2.0]),
                "face \(face)")
            let bounds = try #require(entry.boundingBox)
            for (low, high) in [
                (bounds.min.x, bounds.max.x), (bounds.min.y, bounds.max.y),
                (bounds.min.z, bounds.max.z),
            ] {
                #expect(abs(low + 7.0) < 1e-5 && abs(high - 7.0) < 1e-5, "face \(face)")
            }
            #expect(abs((entry.volume ?? -1) - uniform2Volume) < 1e-6, "face \(face)")
        }

        // The default is not used when an entry reaches every face.
        let ignoredDefault = try #require(
            box.offsetPerFace(defaultOffset: 5.0, faceOffsets: [0: 2.0]))
        #expect(abs((ignoredDefault.volume ?? -1) - uniform2Volume) < 1e-6)

        // A smaller entry shrinks every face, not just its own.
        let smaller = try #require(box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [0: 0.5]))
        let uniformHalf = try #require(box.offsetPerFace(defaultOffset: 0.5, faceOffsets: [:]))
        #expect(abs((smaller.volume ?? -1) - (uniformHalf.volume ?? -2)) < 1e-6)
    }

    // Entries in one propagation group that agree are the same offset and are accepted. Entries
    // that disagree used to give one of the two, which one changing from process to process, and
    // are refused. In-process the result is stable either way; the refusal is what is testable.
    @Test("Conflicting entries in one propagation group are refused")
    func conflictingEntriesAreRefused() throws {
        let box = try cube()
        let uniform2 = try #require(box.offsetPerFace(defaultOffset: 2.0, faceOffsets: [:]))

        let agreeing = try #require(
            box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [0: 2.0, 1: 2.0]))
        #expect(abs((agreeing.volume ?? -1) - (uniform2.volume ?? -2)) < 1e-6)

        #expect(box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [0: 2.0, 1: 3.0]) == nil)
        #expect(box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [2: 0.5, 4: 2.0]) == nil)

        // The same two faces under the intersection join are not connected by an entry's offset,
        // so different distances are per face: x in [-7, 8], volume 15 * 12 * 12 = 2160.
        let split = try #require(
            box.offsetPerFace(
                defaultOffset: 1.0, faceOffsets: [0: 2.0, 1: 3.0], joinType: .intersection))
        let bounds = try #require(split.boundingBox)
        #expect(abs(bounds.min.x + 7.0) < 1e-5 && abs(bounds.max.x - 8.0) < 1e-5)
        #expect(abs((split.volume ?? -1) - 15.0 * 12.0 * 12.0) < 1e-6)
    }

    // A negative offset with the Arc join propagates over concave edges only, and a convex cube
    // has none, so each entry stays on its own face: face 0 (x = -5) moves 2 in, face 1 (x = +5)
    // 3 in, the rest 1 in.
    @Test("Negative Arc offset keeps entries on their own faces")
    func negativeArcIsPerFace() throws {
        let box = try cube()
        let result = try #require(
            box.offsetPerFace(defaultOffset: -1.0, faceOffsets: [0: -2.0, 1: -3.0]))
        let bounds = try #require(result.boundingBox)
        #expect(abs(bounds.min.x + 3.0) < 1e-5 && abs(bounds.max.x - 2.0) < 1e-5)
        #expect(abs(bounds.min.y + 4.0) < 1e-5 && abs(bounds.max.y - 4.0) < 1e-5)
        #expect(abs(bounds.min.z + 4.0) < 1e-5 && abs(bounds.max.z - 4.0) < 1e-5)
        #expect(abs((result.volume ?? -1) - 5.0 * 8.0 * 8.0) < 1e-6)
    }

    // OCCT builds no offset for the tangent join (BRepOffset_MakeOffset.cxx:919-927 branches on
    // Arc and Intersection only), so it is nil for every input, not only per-face ones.
    @Test("Tangent join is not built by OCCT")
    func tangentJoinReturnsNil() throws {
        let box = try cube()
        #expect(box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:], joinType: .tangent) == nil)
        #expect(
            box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [0: 2.0], joinType: .tangent) == nil)
    }

    // The lateral face (face 0) of a r = 5, h = 10 cylinder at 2 against the default 1, with the
    // intersection join: radius 7, the caps 1 out, so pi * 49 * 12 = 1847.2565 (the cap faces
    // alone would give pi * 36 * 14 = 1583.4, so the lateral entry is the one that took). The
    // uniform default offset of 1 is the control (1341.5898 with the Arc join).
    @Test("Per-face offset on cylinder")
    func cylinderPerFace() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))

        let uniform = try #require(cyl.offsetPerFace(defaultOffset: 1.0, faceOffsets: [:]))
        #expect(uniform.isValid)
        #expect(abs((uniform.volume ?? -1) - 1341.589800182048) < 1e-4)
        #expect(uniform.faces().count == 5)

        let lateral = try #require(
            cyl.offsetPerFace(
                defaultOffset: 1.0, faceOffsets: [0: 2.0], joinType: .intersection))
        #expect(lateral.isValid)
        #expect(abs((lateral.volume ?? -1) - Double.pi * 49.0 * 12.0) < 1e-6)
        let bounds = try #require(lateral.boundingBox)
        #expect(abs(bounds.max.x - 7.0) < 1e-5)
        #expect(abs(bounds.min.z + 1.0) < 1e-5 && abs(bounds.max.z - 11.0) < 1e-5)

        // With the Arc join the lateral entry reaches the caps too: the uniform offset 2.
        let arc = try #require(cyl.offsetPerFace(defaultOffset: 1.0, faceOffsets: [0: 2.0]))
        let uniform2 = try #require(cyl.offsetPerFace(defaultOffset: 2.0, faceOffsets: [:]))
        #expect(abs((arc.volume ?? -1) - (uniform2.volume ?? -2)) < 1e-6)
    }
}
