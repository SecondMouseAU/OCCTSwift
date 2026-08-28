import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Camera Aspect Getter Test

@Suite("Camera, Aspect Round-Trip")
struct CameraAspectTests {
    @Test("Camera aspect getter returns set value")
    func aspectRoundTrip() {
        let cam = Camera()
        cam.aspect = 1.5
        let aspect = cam.aspect
        #expect(abs(aspect - 1.5) < 0.001)
    }
}
