import Foundation
import Testing

@testable import OCCTSwift

/// #3464 (upstream OCCT#1600): an arc-join thick solid of a block with blind holes, removing the
/// floor of one hole, came back inside out in a fraction of builds.
///
/// `BRepOffset_MakeLoops::BuildOnContext` splits the cap that closes the opening, and the split
/// was oriented without regard to the offset faces it meets. `BRepTools_Quilt` then decided which
/// side was outside by which face it met first, a function of the allocator's addresses. Carried
/// patch `0066` orients the split against the offset faces, so the result no longer depends on
/// the order. `0053` made that order fixed; without `0066` the fixed order is the bad one for
/// this block, so an arc-join offset that was intermittently wrong became always wrong.
///
/// The block is the reporter's: 57.5 x 40 x 27.5, two d1.5 holes 40 deep along X, offset -1.95,
/// tolerance 1e-3, `GeomAbs_Arc`, the floor of the second hole removed. Measured against the
/// `v4.0.0-kernel.6` kernel, which has `0053` and not `0066`, 100 of 100 builds were invalid with
/// the inside-out volume 106997.78; with `0066` every build is valid with volume 19219.48. On a
/// kernel without `0053` the same input failed in 2 to 10 builds of 100, by allocator luck.
@Suite("Arc-join thick solid keeps the outward orientation when a blind-hole floor is removed")
struct ArcJoinCapOrientationTests {

    /// A freshly built block, every time: the defect is in how the allocator laid the shapes out,
    /// and one block offset again and again does not show it.
    private func drilledBlock() throws -> Shape {
        var block = try #require(
            Shape.box(origin: SIMD3(-28.75, -20, 0), width: 57.5, height: 40, depth: 27.5))
        for (y, z) in [(5.0, 16.25), (10.0, 21.25)] {
            let drill = try #require(
                Shape.cylinder(
                    at: SIMD3(-28.75, y, z), direction: SIMD3(1, 0, 0), radius: 0.75, height: 40))
            block = try #require(block.subtracting(drill))
        }
        return block
    }

    private func floor(of block: Shape, at centre: SIMD3<Double>) throws -> Shape {
        let match = block.faces().filter { face in
            guard let c = face.surfaceInertia.centerOfMass else { return false }
            return abs(c.x - centre.x) + abs(c.y - centre.y) + abs(c.z - centre.z) < 1e-3
        }
        try #require(match.count == 1, "the hole floor at \(centre) must be one face")
        let face = try #require(match.first)
        return try #require(Shape.fromFace(face))
    }

    /// Needs carried patch `0066`, which `v4.0.0-kernel.7` is the first asset to hold. Without it
    /// the kernel answers an inside-out solid in every build. It was gated on `OCCTSWIFT_LOCAL=1`
    /// until that repin (#2983).
    ///
    /// Many fresh blocks rather than one: without `0053` the unpatched result depends on where the
    /// heap put the shapes, and a kernel that has `0053` but not `0066` must not be able to pass
    /// by luck either.
    @Test(
        "Removing the floor of a blind hole gives a valid solid of the same volume every time")
    func floorRemovalIsValidAndOutward() throws {
        var held: [[UInt8]] = []
        var invalid: [Int] = []
        var wrongVolume: [Int] = []
        for run in 0..<100 {
            held.append([UInt8](repeating: 0, count: 16 + 16 * run))
            let block = try drilledBlock()
            let target = try floor(of: block, at: SIMD3(11.25, 10, 21.25))
            let thick = try #require(
                block.thickSolid(
                    facesToRemove: [target], offset: -1.95, tolerance: 1e-3, joinType: .arc),
                "build \(run) returned no shape")
            if !thick.isValid { invalid.append(run) }
            if let volume = thick.volume, abs(volume - 19219.48) > 0.01 {
                wrongVolume.append(run)
            }
        }
        #expect(invalid.isEmpty, "builds \(invalid) of 100 were invalid")
        #expect(
            wrongVolume.isEmpty,
            "builds \(wrongVolume) of 100 had a volume other than 19219.48")
    }
}
