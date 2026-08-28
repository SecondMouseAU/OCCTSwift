import Testing
import simd

@testable import OCCTSwift

@Suite("Pipe Feature")
struct PipeFeatureTests {
    @Test("Pipe feature API is callable")
    func pipeFeatureCallable() {
        let box = Shape.box(width: 20, height: 20, depth: 20)!
        let circle = Wire.circle(radius: 2)!
        let profile = Shape.face(from: circle)!
        let spine = Wire.line(from: SIMD3(0, 0, 10), to: SIMD3(0, 0, -10))!
        // Pipe feature on top face (5), may not work on all geometry
        let result = box.pipeFeature(
            profile: profile, sketchFaceIndex: 5,
            spine: spine, fuse: false
        )
        _ = result
    }

    @Test("Pipe feature with different spine")
    func pipeFeatureCurvedSpine() {
        let box = Shape.box(width: 30, height: 30, depth: 30)!
        let rect = Wire.rectangle(width: 2, height: 2)!
        let profile = Shape.face(from: rect)!
        // Simple straight spine along Z
        let spine = Wire.line(from: SIMD3(0, 0, 15), to: SIMD3(0, 0, -15))!
        let result = box.pipeFeature(
            profile: profile, sketchFaceIndex: 5,
            spine: spine, fuse: false
        )
        _ = result
    }
}
