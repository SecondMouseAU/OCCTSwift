import Testing

@testable import OCCTSwift

@Suite("Drilling Tests")
struct DrillingTests {

    @Test("Drill hole into box")
    func drillHoleIntoBox() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill from slightly above top surface (Z=10), at center (X=0, Y=0)
        let drilled = box.drilled(
            at: SIMD3(0, 0, 11), direction: SIMD3(0, 0, -1), radius: 5, depth: 11)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by cylinder volume
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 10  // π * r² * h (only 10mm inside the box)
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)  // Allow some tolerance
    }

    @Test("Drill through hole")
    func drillThroughHole() {
        // Box is centered at origin: X[-25,25], Y[-25,25], Z[-10,10]
        let box = Shape.box(width: 50, height: 50, depth: 20)!
        let originalVolume = box.volume ?? 0

        // Drill through (depth = 0 means through) starting above top surface
        let drilled = box.drilled(
            at: SIMD3(0, 0, 15), direction: SIMD3(0, 0, -1), radius: 5, depth: 0)

        #expect(drilled != nil)
        #expect(drilled!.isValid)

        // Volume should decrease by full cylinder volume through the box
        let newVolume = drilled!.volume ?? 0
        let holeVolume = Double.pi * 25 * 20  // π * r² * box_depth
        #expect(newVolume < originalVolume)
        #expect(abs(newVolume - (originalVolume - holeVolume)) < 2.0)
    }

    @Test("Multiple holes")
    func multipleHoles() throws {
        // Box 50x50x10 is centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = try #require(Shape.box(width: 50, height: 50, depth: 10))
        // pi r^2 h for one through hole of radius 3 in a 10 deep plate
        let hole = Double.pi * 9 * 10

        // Drill multiple holes from above top surface (Z=5) along Y centerline.
        // #3332: the old test asserted only `r3.isValid` after three drills. Each drill removes
        // exactly one cylinder (volume and face count move by one hole at a time: a through hole
        // adds one cylindrical wall to the six faces of the plate).
        let first = try #require(
            box.drilled(at: SIMD3(-15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0))
        let second = try #require(
            first.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0))
        let third = try #require(
            second.drilled(at: SIMD3(15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0))
        #expect(third.isValid)

        let plate = 50.0 * 50 * 10
        for (n, shape) in [first, second, third].enumerated() {
            let volume = try #require(shape.volume)
            #expect(abs(volume - (plate - Double(n + 1) * hole)) < 1e-3, "after hole \(n + 1)")
            #expect(shape.faceCount == 7 + n, "after hole \(n + 1)")
            #expect(shape.isValid)
        }
    }
}
