import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: kept as written. It already asserted the kernel's answer unconditionally:
// ShapeUpgrade_ShapeDivideClosed with 1 split point turns the cylinder's 3 faces into 4, volume
// unchanged (Scripts/repro/766-healing-shapeupgrade/transcript.txt).
@Suite("ShapeUpgrade DivideClosed Tests")
struct ShapeUpgradeDivideClosedTests {
    @Test("Divide closed cylinder faces")
    func divideCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        #expect(cyl.faces().count == 3)
        // `>= origFaces` was the assertion until #1640, and a divide that divided nothing would
        // have passed it. Issue1640DuplicateSplittersTests sweeps splitPoints 1, 2 and 3.
        let divided = try #require(cyl.dividedClosedFaces())
        #expect(divided.faces().count == 4, "the closed lateral face becomes two")
    }
}
