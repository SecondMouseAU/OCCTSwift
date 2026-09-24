import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Values are the pinned kernel's `BRepGProp_Vinert`, read by
/// `Scripts/repro/766-asymchamfer-cinert-vinert/` on the same face the same way.
@Suite("BRepGProp Vinert Tests")
struct BRepGPropVinertTests {
    /// Face 0 of the centred 10-cube is the x = -5 wall. Against the origin it bounds a pyramid of
    /// base 100 and height 5, volume 500/3, whose centroid sits a quarter of the way in from the
    /// base, at x = -3.75.
    @Test("face volume inertia")
    func faceVolumeInertia() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.faces().first)
        let inertia = face.volumeInertia
        #expect(abs(inertia.volume - 500.0 / 3.0) < 1e-9, "volume \(inertia.volume)")
        let c = try #require(inertia.centerOfMass)
        #expect(simd_distance(c, SIMD3(-3.75, 0, 0)) < 1e-9, "centre \(c)")
    }

    /// The plane-referenced overload `BRepGProp_Vinert(face, gp_Pln, location)` reports 0 on the
    /// pinned kernel. For this face that is the geometric answer (a vertical wall bounds no volume
    /// against z = 0), but the probe measured 0 for every face of the cube and for a whole sphere
    /// against z = -10 too, where the analytic value is not 0; that is recorded as a kernel finding
    /// in the #766 evidence rather than asserted here. This pins the bridge to the kernel.
    @Test("face volume inertia with plane")
    func faceVolumeInertiaPlane() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let face = try #require(box.faces().first)
        let inertia = face.volumeInertia(planeNormal: SIMD3(0, 0, 1))
        #expect(inertia.volume == 0, "volume \(inertia.volume)")
        #expect(inertia.centerOfMass == nil)
    }
}
