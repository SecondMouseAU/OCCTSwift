import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Cylindrical Projection")
struct CylindricalProjectionTests {
    @Test("Project wire onto box")
    func projectWireOntoBox() {
        // Create a circle wire above a box, project downward onto top face
        let circle = Wire.circle(radius: 3)!
        let circleShape = Shape.fromWire(circle)!.translated(by: SIMD3(5, 5, 20))!
        let box = Shape.box(width: 10, height: 10, depth: 5)!
        let result = Shape.projectWire(circleShape, onto: box, direction: SIMD3(0, 0, -1))
        #expect(result != nil)
    }

    @Test("Project edge onto sphere")
    func projectEdgeOntoSphere() {
        // Line above sphere, project downward onto sphere surface
        guard let line = Wire.line(from: SIMD3(-3, 0, 8), to: SIMD3(3, 0, 8)) else { return }
        let lineShape = Shape.fromWire(line)!
        let sphere = Shape.sphere(radius: 10)!
        let result = Shape.projectWire(lineShape, onto: sphere, direction: SIMD3(0, 0, -1))
        #expect(result != nil)
    }
}
