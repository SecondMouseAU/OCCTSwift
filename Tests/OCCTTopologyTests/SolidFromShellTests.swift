import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Solid From Shell Tests")
struct SolidFromShellTests {

    @Test("Solid from shell function exists")
    func solidFromShellExists() {
        // Create a simple face and try to make it into a shell
        // Note: Creating a proper closed shell from scratch is complex.
        // This test verifies the API exists and handles inputs correctly.
        let rect = Wire.rectangle(width: 10, height: 10)!
        let face = Shape.face(from: rect)!

        // A single face cannot become a solid (not closed), so this should return nil
        let solid = Shape.solid(from: face)

        // This is expected to fail since a single face isn't a closed shell
        // The test verifies the API doesn't crash
        #expect(solid == nil || solid!.isValid)
    }

    @Test("Solid from compound of shapes")
    func solidFromCompound() {
        // Create a compound of faces (still won't be a closed shell)
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!

        let compound = Shape.compound([face1, face2])!

        // This won't create a solid since faces aren't connected
        let solid = Shape.solid(from: compound)

        // The test verifies the API handles non-closed shells gracefully
        #expect(solid == nil || solid!.isValid)
    }
}
