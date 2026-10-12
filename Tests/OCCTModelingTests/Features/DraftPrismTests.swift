import Foundation
import Testing

@testable import OCCTSwift

// #3332: both tests discarded the result (`_ = result`). Their fixture also never reached the
// feature: a 20 x 20 profile at z = 0 on the 100 x 100 x 20 box (z in [-10, 10]) is not ON the
// face, and `addingDraftPrismThruAll` answers nil for it (measured), so the pair asserted nothing
// about a feature that was never built. The profile here lies on the top face (z = 10), as the
// API's own example does, and every answer is pinned (kernel.6):
//   boss, fuse = true, height 5, 5 degrees of draft  +155.029 mm^3: the frustum from a 6 x 6 base
//     that shrinks by 2 * 5 * tan 5 deg = 0.875 over its height, V = h/3 (A1 + A2 + sqrt(A1 A2))
//   the same profile with fuse = false, height 5     nothing: the prism grows AWAY from the body
//   fuse = false, height -5                          -207.249 mm^3 (a pocket; no closed form
//     matched, the closest frustum is 207.52, so this one is a measurement)
//   thru-all, fuse = false                            -1197.411 mm^3 (a measurement)
//   thru-all, fuse = true                             nil: there is nothing to fuse "through all"
// The face index is not significant here: indices 4 and 5 give identical results.
@Suite("Draft Prism Feature")
struct DraftPrismTests {
    private func fixture() throws -> (box: Shape, profile: Wire, volume: Double) {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let profile = try #require(
            Wire.polygon3D([
                SIMD3(-3, -3, 10), SIMD3(3, -3, 10), SIMD3(3, 3, 10), SIMD3(-3, 3, 10),
            ]))
        return (box, profile, 8000)
    }

    @Test("Draft prism boss on box face")
    func draftPrismBoss() throws {
        let (box, profile, base) = try fixture()
        let tangent = tan(5.0 * Double.pi / 180)
        let top = 6.0 - 2 * 5.0 * tangent
        let frustum = 5.0 / 3.0 * (36 + top * top + 6 * top)

        for face in [4, 5] {
            let boss = try #require(
                box.addingDraftPrism(
                    profile: profile, sketchFaceIndex: face, draftAngle: 5.0, height: 5.0,
                    fuse: true))
            #expect(boss.isValid)
            let volume = try #require(boss.volume)
            #expect(abs(volume - (base + frustum)) < 1e-3, "face \(face)")
            let bounds = try #require(boss.bounds)
            #expect(abs(bounds.max.z - 15) < 1e-3)
            #expect(abs(bounds.min.z + 10) < 1e-3)
        }

        // A boss twice as tall adds a larger frustum: the height is what is used.
        let tall = try #require(
            box.addingDraftPrism(
                profile: profile, sketchFaceIndex: 5, draftAngle: 5.0, height: 10.0, fuse: true))
        let tallTop = 6.0 - 2 * 10.0 * tangent
        let tallFrustum = 10.0 / 3.0 * (36 + tallTop * tallTop + 6 * tallTop)
        let tallVolume = try #require(tall.volume)
        #expect(abs(tallVolume - (base + tallFrustum)) < 1e-3)

        // Not fusing, with the prism pointing away from the body, changes nothing.
        let away = try #require(
            box.addingDraftPrism(
                profile: profile, sketchFaceIndex: 5, draftAngle: 5.0, height: 5.0, fuse: false))
        let awayVolume = try #require(away.volume)
        #expect(abs(awayVolume - base) < 1e-6)

        // A pocket: the prism runs into the body (negative height) and takes material away.
        let pocket = try #require(
            box.addingDraftPrism(
                profile: profile, sketchFaceIndex: 5, draftAngle: 5.0, height: -5.0, fuse: false))
        #expect(pocket.isValid)
        let pocketVolume = try #require(pocket.volume)
        #expect(abs(pocketVolume - (base - 207.2485)) < 1e-3)

        // A NaN angle or height is refused (#3100), a finite one at the same call is not.
        #expect(
            box.addingDraftPrism(
                profile: profile, sketchFaceIndex: 5, draftAngle: .nan, height: 5.0) == nil)
        #expect(
            box.addingDraftPrism(
                profile: profile, sketchFaceIndex: 5, draftAngle: 5.0, height: .nan) == nil)
    }

    @Test("Draft prism thru all")
    func draftPrismThruAll() throws {
        let (box, profile, base) = try fixture()

        for face in [4, 5] {
            let hole = try #require(
                box.addingDraftPrismThruAll(
                    profile: profile, sketchFaceIndex: face, draftAngle: 5.0, fuse: false))
            #expect(hole.isValid)
            let volume = try #require(hole.volume)
            #expect(abs(volume - (base - 1197.4108)) < 1e-3, "face \(face)")
            // Cut right through: the bounding box of the body is unchanged.
            let bounds = try #require(hole.bounds)
            #expect(abs(bounds.min.z + 10) < 1e-3 && abs(bounds.max.z - 10) < 1e-3)
        }

        // Fusing "through all" has nothing to add to: refused.
        #expect(
            box.addingDraftPrismThruAll(
                profile: profile, sketchFaceIndex: 5, draftAngle: 5.0, fuse: true) == nil)
        #expect(
            box.addingDraftPrismThruAll(
                profile: profile, sketchFaceIndex: 5, draftAngle: .nan, fuse: false) == nil)
    }
}
