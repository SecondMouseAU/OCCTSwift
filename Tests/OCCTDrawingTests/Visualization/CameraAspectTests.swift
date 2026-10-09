import Foundation
import OCCTBridge
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

    @Test("Camera scale getter returns set value")
    func scaleRoundTrip() {
        let cam = Camera()
        cam.scale = 250.0
        #expect(abs(cam.scale - 250.0) < 0.001)
    }

    @Test("Camera scale null-handle fallback matches OCCT's own default (#1417)")
    func scaleNullFallbackMatchesOCCTDefault() {
        // Graphic3d_Camera's own default constructor is myScale(1000.0)
        // (Graphic3d_Camera.cxx:76-99); a null OCCTCameraRef used to fall back to 1.0, off by a
        // factor of 1000, breaking this file's own established pattern (OCCTCameraGetFOV/
        // OCCTCameraGetAspect null fallbacks already mirror OCCT's real defaults).
        #expect(abs(OCCTCameraGetScale(nil) - 1000.0) < 0.001)
    }
}
