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

    @Test("A vertex counts as the second section, so one profile plus a vertex still lofts")
    func profilePlusVertexStillLofts() {
        guard let w = square(z: 0) else {
            Issue.record("could not build the profile")
            return
        }
        for ruled in [true, false] {
            let first = Shape.loft(
                profiles: [w], solid: true, ruled: ruled, firstVertex: SIMD3(0, 0, -3))
            let last = Shape.loft(
                profiles: [w], solid: true, ruled: ruled, lastVertex: SIMD3(0, 0, 3))
            let both = Shape.loft(
                profiles: [w], solid: false, ruled: ruled,
                firstVertex: SIMD3(0, 0, -3), lastVertex: SIMD3(0, 0, 3))
            for shape in [first, last, both] {
                #expect(shape != nil, "ruled: \(ruled)")
                if let s = shape { #expect(s.isValid, "ruled: \(ruled)") }
            }
        }
    }

    @Test("Two and three profiles loft unchanged, ruled and smooth, solid and shell")
    func twoAndThreeProfilesStillLoft() {
        guard let a = square(z: 0), let b = square(z: 3), let c = square(z: 6) else {
            Issue.record("could not build the profiles")
            return
        }
        for profiles in [[a, b], [a, b, c]] {
            for solid in [true, false] {
                for ruled in [true, false] {
                    let shape = Shape.loft(profiles: profiles, solid: solid, ruled: ruled)
                    #expect(shape != nil, "n: \(profiles.count), solid: \(solid), ruled: \(ruled)")
                    if let s = shape {
                        #expect(s.isValid, "n: \(profiles.count), solid: \(solid), ruled: \(ruled)")
                    }
                }
            }
        }
    }
}
