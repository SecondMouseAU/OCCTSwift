import Testing
import simd

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
    func multipleHoles() {
        // Box 50x50x10 is centered at origin: X[-25,25], Y[-25,25], Z[-5,5]
        let box = Shape.box(width: 50, height: 50, depth: 10)!

        // Drill multiple holes from above top surface (Z=5) along Y centerline
        guard
            var r = box.drilled(
                at: SIMD3(-15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            #expect(false, "First drill failed")
            return
        }
        guard
            let r2 = r.drilled(at: SIMD3(0, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            #expect(false, "Second drill failed")
            return
        }
        guard
            let r3 = r2.drilled(
                at: SIMD3(15, 0, 8), direction: SIMD3(0, 0, -1), radius: 3, depth: 0)
        else {
            #expect(false, "Third drill failed")
            return
        }
        #expect(r3.isValid)
    }
}
