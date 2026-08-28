import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.47.0 Tests

@Suite("Local Revolution Tests")
struct LocalRevolutionTests {
    @Test("Revolve face around Z axis")
    func revolveAroundZ() throws {
        // Create a small face to revolve
        let face = Shape.box(width: 3, height: 3, depth: 0.1)!
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2
        )
        #expect(result != nil)
    }

    @Test("Revolve face produces solid-like shape")
    func revolveProducesSolid() throws {
        let face = Shape.box(width: 2, height: 2, depth: 0.1)!
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 4
        )
        #expect(result != nil)
        if let result {
            #expect(result.faceCount > 0)
        }
    }

    @Test("Revolve with angular offset")
    func revolveWithOffset() throws {
        let face = Shape.box(width: 2, height: 2, depth: 0.1)!
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2,
            angularOffset: .pi / 4
        )
        #expect(result != nil)
    }

    @Test("Full revolution")
    func fullRevolution() throws {
        let face = Shape.box(width: 2, height: 2, depth: 0.1)!
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: 2 * .pi
        )
        #expect(result != nil)
    }
}
