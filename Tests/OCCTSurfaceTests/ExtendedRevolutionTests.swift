import Testing
import simd

@testable import OCCTSwift

@Suite("Extended Revolution")
struct ExtendedRevolutionTests {
    @Test func revolveFaceFull() {
        // Revolve a face around an axis to create a solid of revolution
        let wire = Wire.rectangle(width: 2, height: 5)
        if let wire {
            let face = Shape.face(from: wire)
            if let face {
                let moved = face.translated(by: SIMD3(10, 0, 0))
                if let moved {
                    let revolved = moved.revolved(
                        axisOrigin: SIMD3(0, 0, 0),
                        axisDirection: SIMD3(0, 0, 1))
                    #expect(revolved != nil)
                }
            }
        }
    }

    @Test func revolveFacePartial() {
        let wire = Wire.rectangle(width: 2, height: 5)
        if let wire {
            let face = Shape.face(from: wire)
            if let face {
                let moved = face.translated(by: SIMD3(10, 0, 0))
                if let moved {
                    let half = moved.revolved(
                        axisOrigin: SIMD3(0, 0, 0),
                        axisDirection: SIMD3(0, 0, 1),
                        angle: .pi)
                    #expect(half != nil)
                }
            }
        }
    }
}
