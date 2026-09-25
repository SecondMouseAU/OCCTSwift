import Testing
import simd

@testable import OCCTSwift

@Suite("Make Connected")
struct MakeConnectedTests {
    @Test("Connect two adjacent boxes")
    func connectBoxes() throws {
        let box1 = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let box2 = try #require(
            Shape.box(width: 10, height: 10, depth: 10)?.translated(by: SIMD3(10, 0, 0)))
        let connected = try #require(Shape.makeConnected([box1, box2]))
        // #766: this asserted only `connected != nil`, so any shape passed. Pinned to the kernel
        // (Scripts/repro/766-modeling-make-connected, transcript-evidence-fix.txt):
        // BOPAlgo_MakeConnected on two boxes sharing a face gives a valid compound of 2 solids and
        // 11 faces (12 minus the one shared face, which is stored once), volume 2000.
        #expect(connected.isValid)
        #expect(connected.subShapes(ofType: .solid).count == 2)
        #expect(connected.subShapes(ofType: .face).count == 11)
        let volume = try #require(connected.volume)
        #expect(abs(volume - 2000) < 1e-6)
    }
}
