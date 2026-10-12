import Testing

@testable import OCCTSwift

// #3099: `BRepOffsetAPI_ThruSections` needs two sections. One smooth section ends the process with
// SIGSEGV and one ruled section returns an invalid shape, so `loft(profiles:solid:ruled:)` refuses
// fewer than two sections (a vertex counts as one) with nil before the kernel runs. The `thrusections`
// DRAW command (BRepTest_SweepCommands.cxx) takes at least two shapes for the same reason.
@Suite("Loft Too Few Sections")
struct LoftTooFewSectionsTests {
    private func square(z: Double) -> Wire? {
        Wire.polygon3D([
            SIMD3(-2, -2, z), SIMD3(2, -2, z), SIMD3(2, 2, z), SIMD3(-2, 2, z),
        ])
    }

    @Test("One profile and no vertex is refused for every solid and ruled combination")
    func singleProfileRefused() {
        guard let w = square(z: 0) else {
            Issue.record("could not build the profile")
            return
        }
        for solid in [true, false] {
            for ruled in [true, false] {
                #expect(
                    Shape.loft(profiles: [w], solid: solid, ruled: ruled) == nil,
                    "solid: \(solid), ruled: \(ruled)")
            }
        }
    }

    @Test("No profile and no vertex is refused")
    func noProfileRefused() {
        #expect(Shape.loft(profiles: [], solid: true, ruled: false) == nil)
        #expect(Shape.loft(profiles: [], solid: false, ruled: true) == nil)
    }

    // #3332: the old bodies asserted `shape != nil` and `isValid` for every combination, under
    // `if let`. The shapes are closed forms (the profile is a 4 x 4 square):
    //   one vertex 3 mm off the centre of the square: a pyramid, V = 4 * 4 * 3 / 3 = 16 and
    //     lateral + base area 16 + 4 * (1/2 * 4 * sqrt(2^2 + 3^2)) = 16 + 8 sqrt(13)
    //   a vertex at each end, ruled: two pyramids, a shell of V = 32 and area 16 sqrt(13)
    // The smooth loft with a vertex at BOTH ends is not a closed form (the smoothing overshoots,
    // 4 faces, measured), so its volume is a measurement.
    @Test("A vertex counts as the second section, so one profile plus a vertex still lofts")
    func profilePlusVertexStillLofts() throws {
        let w = try #require(square(z: 0))
        let pyramidArea = 16 + 8 * 13.0.squareRoot()
        for ruled in [true, false] {
            let first = try #require(
                Shape.loft(profiles: [w], solid: true, ruled: ruled, firstVertex: SIMD3(0, 0, -3)))
            let last = try #require(
                Shape.loft(profiles: [w], solid: true, ruled: ruled, lastVertex: SIMD3(0, 0, 3)))
            for (label, shape) in [("first", first), ("last", last)] {
                #expect(shape.isValid, "\(label), ruled: \(ruled)")
                #expect(shape.shapeType == .solid, "\(label), ruled: \(ruled)")
                #expect(shape.faceCount == 5, "\(label), ruled: \(ruled)")
                let volume = try #require(shape.volume)
                #expect(abs(volume - 16) < 1e-6, "\(label), ruled: \(ruled)")
                let area = try #require(shape.surfaceArea)
                #expect(abs(area - pyramidArea) < 1e-6, "\(label), ruled: \(ruled)")
            }
            let apexZ = try #require(first.bounds).min.z
            #expect(abs(apexZ + 3) < 1e-3, "the first vertex is below the profile")
            let lastApexZ = try #require(last.bounds).max.z
            #expect(abs(lastApexZ - 3) < 1e-3, "the last vertex is above the profile")

            let both = try #require(
                Shape.loft(
                    profiles: [w], solid: false, ruled: ruled,
                    firstVertex: SIMD3(0, 0, -3), lastVertex: SIMD3(0, 0, 3)))
            #expect(both.isValid, "ruled: \(ruled)")
            #expect(both.shapeType == .shell, "ruled: \(ruled)")
            let volume = try #require(both.volume)
            if ruled {
                #expect(both.faceCount == 8)
                #expect(abs(volume - 32) < 1e-6)
                let area = try #require(both.surfaceArea)
                #expect(abs(area - 16 * 13.0.squareRoot()) < 1e-6)
            } else {
                #expect(both.faceCount == 4)
                #expect(abs(volume - 51.2) < 1e-3)
            }
        }
    }

    // #3332: n = 2 and n = 3 sections of a 4 x 4 square at heights 0, 3, (6): the solid is a
    // straight prism (V = 48, 96) whether ruled or smooth; its faces are 6 for two sections and
    // 6 smooth / 10 ruled for three (ruled makes a lateral face per gap); the shell is the
    // lateral area alone (48, 96) with 4 faces for the smooth three-section loft and 8 ruled.
    @Test("Two and three profiles loft unchanged, ruled and smooth, solid and shell")
    func twoAndThreeProfilesStillLoft() throws {
        let a = try #require(square(z: 0))
        let b = try #require(square(z: 3))
        let c = try #require(square(z: 6))
        for profiles in [[a, b], [a, b, c]] {
            let n = profiles.count
            let height = Double(3 * (n - 1))
            for solid in [true, false] {
                for ruled in [true, false] {
                    let label = "n: \(n), solid: \(solid), ruled: \(ruled)"
                    let shape = try #require(
                        Shape.loft(profiles: profiles, solid: solid, ruled: ruled))
                    #expect(shape.isValid, Comment(rawValue: label))
                    #expect(shape.shapeType == (solid ? .solid : .shell), Comment(rawValue: label))
                    let bounds = try #require(shape.bounds)
                    #expect(abs(bounds.max.z - height) < 1e-3, Comment(rawValue: label))
                    let faces = shape.faceCount
                    if solid {
                        let volume = try #require(shape.volume)
                        #expect(abs(volume - 16 * height) < 1e-6, Comment(rawValue: label))
                        #expect(
                            faces == (n == 2 || !ruled ? 6 : 10), Comment(rawValue: label))
                    } else {
                        let area = try #require(shape.surfaceArea)
                        #expect(abs(area - 16 * height) < 1e-6, Comment(rawValue: label))
                        #expect(faces == (n == 2 || !ruled ? 4 : 8), Comment(rawValue: label))
                    }
                }
            }
        }
    }
}
