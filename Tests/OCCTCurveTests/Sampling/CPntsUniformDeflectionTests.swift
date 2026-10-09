import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("CPnts UniformDeflection")
struct CPntsUniformDeflectionTests {
    @Test("Uniform deflection on circle edge")
    func uniformDeflectionCircle() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edgeShapes = cyl.subShapes(ofType: .edge)
        // Find a circular edge and test uniform deflection on it
        var found = false
        for edgeShape in edgeShapes {
            let result = edgeShape.uniformDeflection(0.1)
            if let result = result, result.points.count > 4 {
                #expect(result.parameters.count == result.points.count)
                found = true
                break
            }
        }
        #expect(found)
    }

    @Test("Uniform deflection with range")
    func uniformDeflectionRange() {
        guard let cyl = Shape.cylinder(radius: 10, height: 5) else { return }
        let edgeShapes = cyl.subShapes(ofType: .edge)
        var found = false
        for edgeShape in edgeShapes {
            let full = edgeShape.uniformDeflection(0.1)
            if let full = full, full.points.count > 4 {
                let ranged = edgeShape.uniformDeflection(
                    0.1, range: full.parameters[0]...full.parameters[full.parameters.count / 2])
                if let ranged = ranged {
                    #expect(ranged.points.count > 0)
                    #expect(ranged.points.count < full.points.count)
                    found = true
                    break
                }
            }
        }
        #expect(found)
    }
}
