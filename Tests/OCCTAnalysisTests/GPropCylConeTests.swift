import Foundation
import Testing
import simd

@testable import OCCTSwift

/// Analytic cylinder and cone properties, measured against closed forms rather than against the
/// kernel's own answer.
///
/// `gp_Cone`'s `v` parameter runs along the **generatrix**, so the `height` these entry points
/// take is a slant length, not an axial one. With that fixed, every value below is closed form:
///
/// | quantity | closed form | at `r = 5`, `h = 10`, `a = pi/6` |
/// |---|---|---|
/// | cylinder lateral area | `2 pi r h` | `314.15926535897933` |
/// | cylinder volume | `pi r^2 h` | `785.39816339744823` |
/// | cone lateral area | `2 pi (R h + h^2 sin a / 2)` | `471.23889803846896` |
/// | cone frustum volume | `pi H / 3 (R^2 + R R2 + R2^2)`, `H = h cos a`, `R2 = R + h sin a` | `1587.0744437049404` |
///
/// The kernel agrees on the cylinder to the last bit and **disagrees on both cone values**
/// ([#2992](https://github.com/SecondMouseAU/OCCTSwift/issues/2992)): `GProp_SelGProps` returns
/// `cos(a)` times the area and `GProp_VelGProps` returns a quantity that goes to zero rather than
/// to the cylinder as `a` does. The cone tests therefore pin the kernel's current answer exactly,
/// as a regression pin, and hold the correct value in a `withKnownIssue` so a fix turns the test
/// red and asks for an update instead of leaving a wrong number endorsed.
///
/// Before #766 the two cone tests asserted only `> 0`, which a half-revolution, a swapped radius,
/// a slant-versus-axial mix-up and the two kernel defects all satisfy; the two cylinder tests
/// carried tolerances of `0.1` and `1.0` on values the kernel reproduces to within `1.2e-13`.
/// Measured by `Scripts/repro/766-gpropcylcone/probe.mm` (transcript alongside it).
@Suite("GProp Cylinder/Cone Tests")
struct GPropCylConeTests {

    /// The lateral area of a cylinder is `2 pi r h`, and the kernel returns it exactly.
    ///
    /// #1811: the tolerance was `0.1`, which accepts a radius out by 1 part in 3000. The kernel's
    /// `GProp_SelGProps::Perform(gp_Cylinder)` is `dim = R (Z2 - Z1) (Alpha2 - Alpha1)`, the same
    /// product in the same order, so the two agree bit for bit and `1e-12` is not tight.
    @Test func cylinderSurfaceArea() {
        let area = GeometryProperties.cylinderSurfaceArea(radius: 5, height: 10)
        let expected = 2 * Double.pi * 5 * 10
        #expect(abs(area - expected) < 1e-12, "expected \(expected), got \(area)")
    }

    /// The volume of a cylinder is `pi r^2 h`.
    ///
    /// #1812: the tolerance was `1.0`, which accepts a volume out by 1 part in 785. The kernel
    /// computes `(Alpha2 - Alpha1) R^2 (Z2 - Z1) / 2`, a different association of the same
    /// factors, so it lands 1.1e-13 away from `pi * 25 * 10` and `1e-9` is the honest bound.
    @Test func cylinderVolume() {
        let vol = GeometryProperties.cylinderVolume(radius: 5, height: 10)
        let expected = Double.pi * 25 * 10
        #expect(abs(vol - expected) < 1e-9, "expected \(expected), got \(vol)")
    }

    /// The lateral area of a cone patch is `2 pi (R h + h^2 sin a / 2)`.
    ///
    /// #1813. For `u in [0, 2 pi]`, `v in [0, 10]` that is `471.23889803846896`, because
    /// `|dP/du x dP/dv| = R + v sin a` on `gp_Cone`'s generatrix parametrisation.
    ///
    /// The kernel returns `408.10485695269909`, which is that area times `cos(a)` to 16 digits
    /// (`GProp_SelGProps.cxx:125` multiplies by `Cnt`). The first expectation is the regression
    /// pin on what the wrapper does today; the second is the arithmetic, held as a known issue
    /// against #2992.
    @Test func coneSurfaceArea() {
        let semiAngle = Double.pi / 6
        let area = GeometryProperties.coneSurfaceArea(
            semiAngle: semiAngle, refRadius: 5, height: 10)
        #expect(abs(area - 408.10485695269909) < 1e-9, "got \(area)")

        let trueArea = 2 * Double.pi * (5 * 10 + 100 * sin(semiAngle) / 2)
        // The defect is exactly a factor of cos(semiAngle), not an approximation error.
        #expect(abs(area - trueArea * cos(semiAngle)) < 1e-9, "got \(area)")

        withKnownIssue(
            "#2992: GProp_SelGProps::Perform(gp_Cone) returns cos(semiAngle) times the area"
        ) {
            #expect(abs(area - trueArea) < 1e-9, "expected \(trueArea), got \(area)")
        }
    }

    /// The cone patch bounds a frustum, whose volume is `pi H / 3 (R1^2 + R1 R2 + R2^2)`.
    ///
    /// #1814. For `u in [0, 2 pi]`, `v in [0, 10]` the axial height is `h cos a` and the radii
    /// are `R` and `R + h sin a`, so the volume is `1587.0744437049404`. That is the convention
    /// the cylinder and sphere overloads of `GProp_VelGProps` both use.
    ///
    /// The kernel returns `2040.524284763495`, and the decisive evidence that this is wrong rather
    /// than a different convention is the cylinder limit: `GProp_VelGProps.cxx:171` carries a
    /// factor of `sin a`, so the reported volume goes to **zero** as the cone becomes the cylinder
    /// whose volume the same class gets right.
    @Test func coneVolume() {
        let semiAngle = Double.pi / 6
        let vol = GeometryProperties.coneVolume(semiAngle: semiAngle, refRadius: 5, height: 10)
        #expect(abs(vol - 2040.524284763495) < 1e-9, "got \(vol)")

        let axialHeight = 10 * cos(semiAngle)
        let farRadius = 5 + 10 * sin(semiAngle)
        let frustum =
            Double.pi * axialHeight / 3 * (25 + 5 * farRadius + farRadius * farRadius)
        withKnownIssue("#2992: GProp_VelGProps::Perform(gp_Cone) does not return the volume") {
            #expect(abs(vol - frustum) < 1e-9, "expected \(frustum), got \(vol)")
        }

        // gp_Cone refuses semiAngle 0, so the limit is approached rather than taken.
        let nearCylinder = GeometryProperties.coneVolume(
            semiAngle: 1e-6, refRadius: 5, height: 10)
        let cylinder = GeometryProperties.cylinderVolume(radius: 5, height: 10)
        withKnownIssue("#2992: the cone volume collapses to 0 instead of to the cylinder's") {
            #expect(abs(nearCylinder - cylinder) < 1e-3, "got \(nearCylinder), want \(cylinder)")
        }
    }
}
