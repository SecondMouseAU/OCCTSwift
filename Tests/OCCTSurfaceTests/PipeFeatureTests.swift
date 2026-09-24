import Testing
import simd

@testable import OCCTSwift

@Suite("Pipe Feature")
struct PipeFeatureTests {

    // #766: both tests ended in `_ = result`, so they asserted nothing and could not fail. With
    // fuse: false, BRepFeat_MakePipe cuts the profile swept along the spine through the centred
    // box: the kernel's valid results have volume 20^3 - pi * 2^2 * 20 and 30^3 - 2 * 2 * 30. See
    // Scripts/repro/766-pipe-shell/.

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
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 7748.6725877128156) < 1e-6)
        }
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
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(abs((result.volume ?? 0) - 26880) < 1e-6)
        }
    }
}
