import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GProp Cylinder/Cone Tests")
struct GPropCylConeTests {

    @Test func cylinderSurfaceArea() {
        let area = GeometryProperties.cylinderSurfaceArea(radius: 5, height: 10)
        let expected = 2 * Double.pi * 5 * 10
        #expect(abs(area - expected) < 0.1)
    }

    @Test func cylinderVolume() {
        let vol = GeometryProperties.cylinderVolume(radius: 5, height: 10)
        let expected = Double.pi * 25 * 10
        #expect(abs(vol - expected) < 1.0)
    }

    // #766: the two cone tests asserted only `> 0`, which a half-revolution, a swapped radius or
    // an axial-versus-slant mix-up all satisfy. The values are pinned to what
    // `GProp_SelGProps` / `GProp_VelGProps` return for `gp_Cone(semiAngle: pi/6, refRadius: 5)`
    // over u in [0, 2 pi], v in [0, 10], probed in Scripts/repro/766-gpropcylcone.
    //
    // They are the kernel's closed forms, not a textbook's: `v` runs along the generatrix, and
    // the lateral area of that patch, 2 pi (R L + L^2 sin(a) / 2) = 471.24, is not what
    // `GProp_SelGProps` returns (its `dim` carries an extra cos(a), giving 408.10). The
    // volume, 2040.52, matches neither a frustum of slant 10 (1587.07) nor one of axial
    // height 10 (2041.36). These tests pin the wrapper to the kernel; they do not vouch for the
    // kernel's formula.
    @Test func coneSurfaceArea() {
        let area = GeometryProperties.coneSurfaceArea(semiAngle: .pi / 6, refRadius: 5, height: 10)
        #expect(abs(area - 408.10485695269909) < 1e-9)
    }

    @Test func coneVolume() {
        let vol = GeometryProperties.coneVolume(semiAngle: .pi / 6, refRadius: 5, height: 10)
        #expect(abs(vol - 2040.524284763495) < 1e-9)
    }
}
