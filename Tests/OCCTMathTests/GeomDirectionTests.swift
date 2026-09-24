import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomDirection Tests")
struct GeomDirectionTests {
    @Test("create unit direction")
    func create() {
        let d = GeomDirection(x: 0, y: 0, z: 1)
        let c = d.coordinates
        #expect(abs(c.z - 1) < 1e-10)
    }

    @Test("auto-normalizes")
    func normalizes() {
        let d = GeomDirection(x: 3, y: 4, z: 0)
        let c = d.coordinates
        let mag = sqrt(c.x * c.x + c.y * c.y + c.z * c.z)
        #expect(abs(mag - 1.0) < 1e-10)
        // Unit length held for any permutation of the components. Pin them: (3, 4, 0) / 5
        // (kernel value from Scripts/repro/766-math-gc-ellipse-trimmed-direction/transcript.txt).
        #expect(abs(c.x - 0.6) < 1e-12)
        #expect(abs(c.y - 0.8) < 1e-12)
        #expect(abs(c.z) < 1e-12)
    }

    @Test("crossed product")
    func crossed() {
        let dx = GeomDirection(x: 1, y: 0, z: 0)
        let dy = GeomDirection(x: 0, y: 1, z: 0)
        if let cross = dx.crossed(with: dy) {
            #expect(abs(cross.coordinates.z - 1.0) < 1e-10)
        }
    }

    @Test("setCoordinates")
    func setCoordinates() {
        let d = GeomDirection(x: 1, y: 0, z: 0)
        d.setCoordinates(x: 0, y: 1, z: 0)
        #expect(abs(d.coordinates.y - 1.0) < 1e-10)
    }
}

