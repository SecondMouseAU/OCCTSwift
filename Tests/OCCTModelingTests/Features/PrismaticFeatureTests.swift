import Testing
import simd

@testable import OCCTSwift

// MARK: - Feature-Based Modeling Tests (v0.12.0)

@Suite("Prismatic Feature Tests")
struct PrismaticFeatureTests {

    @Test("Add boss to box")
    func addBossToBox() {
        // Box is 50x50x10 centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!
        let originalVolume = box.volume ?? 0

        // Create a circular profile and position it at top of box (Z=5)
        let circle = Wire.circle(radius: 5)!
        let bossProfile = circle.offset3D(distance: 5, direction: SIMD3(0, 0, 1))!

        // Add boss on top (extends from Z=5 to Z=10)
        let withBoss = box.withBoss(profile: bossProfile, direction: SIMD3(0, 0, 1), height: 5)

        #expect(withBoss != nil)
        #expect(withBoss!.isValid)

        // Volume should increase
        let newVolume = withBoss!.volume ?? 0
        let bossVolume = Double.pi * 25 * 5  // π * r² * h
        #expect(newVolume > originalVolume)
        #expect(abs(newVolume - (originalVolume + bossVolume)) < 1.0)
    }

    @Test("Create pocket in box")
    func createPocketInBox() {
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Create a rectangular pocket profile
        let pocketProfile = Wire.rectangle(width: 20, height: 20)!

        // Create pocket going down into the box
        let withPocket = box.withPocket(
            profile: pocketProfile, direction: SIMD3(0, 0, -1), depth: 10)

        #expect(withPocket != nil)
        #expect(withPocket!.isValid)

        // Volume should decrease
        let newVolume = withPocket!.volume ?? 0
        let pocketVolume = 20 * 20 * 10  // w * h * d
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - Double(pocketVolume))) < 1.0)
    }
}
