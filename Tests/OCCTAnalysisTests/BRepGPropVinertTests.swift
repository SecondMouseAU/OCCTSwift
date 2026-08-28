import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepGProp Vinert Tests")
struct BRepGPropVinertTests {
    @Test("face volume inertia")
    func faceVolumeInertia() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.volumeInertia
            // Just verify no crash, volume contribution from single face may be small
            let _ = inertia.volume
        }
    }

    @Test("face volume inertia with plane")
    func faceVolumeInertiaPlane() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let faces = box.faces()
        if let face = faces.first {
            let inertia = face.volumeInertia(planeNormal: SIMD3(0, 0, 1))
            let _ = inertia.volume
        }
    }
}
