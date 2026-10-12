import Testing

@testable import OCCTSwift

// MARK: - Per-Face Variable Offset Tests (v0.38.0)

@Suite("Per-Face Variable Offset")
struct PerFaceVariableOffsetTests {

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
    // other face reaches 6: x in [-6, 7], volume 13 * 12 * 12 = 1872 with the intersection
    // join. The default Arc join returns the uniform offset of that one entry, so the whole cube
    // is +-7 (#3365), and that is the known issue.
    @Test("Variable offset on specific faces")
    func variableOffset() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))

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

        let rounded = try #require(box.offsetPerFace(defaultOffset: 1.0, faceOffsets: [1: 2.0]))
        #expect(rounded.isValid)
        withKnownIssue("#3365: the Arc join applies one entry to every convex-connected face") {
            let roundedBounds = try #require(rounded.boundingBox)
            #expect(abs(roundedBounds.min.x + 6.0) < 1e-5)
            #expect(abs(roundedBounds.max.x - 7.0) < 1e-5)
        }
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
    }
}
