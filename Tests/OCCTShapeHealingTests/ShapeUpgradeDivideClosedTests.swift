import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeUpgrade DivideClosed Tests")
struct ShapeUpgradeDivideClosedTests {
    @Test("Divide closed cylinder faces")
    func divideCylinder() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let origFaces = cyl.faces().count
        if let divided = cyl.dividedClosedFaces() {
            let newFaces = divided.faces().count
            #expect(newFaces >= origFaces, "Should have at least as many faces after divide")
        }
    }
}
