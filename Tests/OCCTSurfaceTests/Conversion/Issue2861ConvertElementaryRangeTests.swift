import Testing
import simd

@testable import OCCTSwift

/// #2861: `Convert_CylinderToBSplineSurface` and `Convert_ConeToBSplineSurface` state their only
/// precondition, `|V2 - V1| > |Epsilon(V1)| && 0 <= U2 - U1 <= 2*pi`, as a
/// `Standard_DomainError_Raise_if` in the `.cxx`, which the pinned Release kernel compiles to
/// nothing. Their pole and knot arrays are fixed at 9 and 5 by the base-class constructor before
/// they derive the real extent from the range they were handed, so:
///
/// - `u2 - u1 <= -5*pi/3` (which `u1: 2*pi, u2: 0` is inside) stored at index <= 0 of a 1-based
///   array and resized to a negative length: an uncatchable SIGSEGV from swapping two adjacent
///   arguments.
/// - `u2 - u1 >= 10.472` wrote about 3.4 KB past a 432-byte allocation and then returned nil, so the
///   corruption had no visible signal at all.
/// - `2*pi < u2 - u1 < 10.472` returned a non-nil surface whose poles sat 11.7 to 12.7 from the axis
///   of a radius-5 cylinder.
///
/// The assertions are on the refusal value, `nil`, and on the in-range conversion still working.
/// `Convert_CircleToBSplineCurve` is the control: it writes the same precondition as a literal
/// `throw`, which no macro gates, so `Curve2D.fromCircleArc` has always refused the same input.
@Suite("#2861: cylinder and cone converter parameter range")
struct Issue2861ConvertElementaryRangeTests {

    @Test("fromCylinder converts an in-range patch and refuses every out-of-range one")
    func cylinderRange() {
        // In range: a half turn, and the full turn the docs use as their worked example.
        #expect(
            Surface.fromCylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: 5,
                u1: 0, u2: .pi, v1: 0, v2: 10) != nil)
        #expect(
            Surface.fromCylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: 5,
                u1: 0, u2: 2 * .pi, v1: 0, v2: 10) != nil)
        // Written as one test walking a list rather than @Test(arguments:), because an argument
        // element pairing a reference-counted member with a 32-byte builtin vector cannot be written
        // at all (swiftlang/swift#91639, see CLAUDE.md).
        let badU: [(Double, Double)] = [
            (2 * .pi, 0),  // the swapped-argument SIGSEGV
            (0, -2 * .pi),  // same delta, reached the other way
            (1, 0.5),  // the -5*pi/3 < delta < 0 band, which used to survive by luck
            (0, 8),  // fabricated self-overlapping surface
            (0, 100),  // the silent heap write
            (0, .nan),  // trunc() of a NaN delta is undefined behaviour
        ]
        for (u1, u2) in badU {
            #expect(
                Surface.fromCylinder(
                    origin: .zero, axis: SIMD3(0, 0, 1), radius: 5,
                    u1: u1, u2: u2, v1: 0, v2: 10) == nil,
                "fromCylinder(u1: \(u1), u2: \(u2)) returned a surface")
        }
        // A degenerate V range is the other half of the same kernel condition.
        #expect(
            Surface.fromCylinder(
                origin: .zero, axis: SIMD3(0, 0, 1), radius: 5,
                u1: 0, u2: .pi, v1: 3, v2: 3) == nil)
    }

    @Test("fromCone converts an in-range patch and refuses every out-of-range one")
    func coneRange() {
        #expect(
            Surface.fromCone(
                origin: .zero, axis: SIMD3(0, 0, 1), semiAngle: .pi / 6, refRadius: 5,
                u1: 0, u2: .pi, v1: 0, v2: 10) != nil)
        let badU: [(Double, Double)] = [(2 * .pi, 0), (1, 0.5), (0, 8), (0, 100), (0, .nan)]
        for (u1, u2) in badU {
            #expect(
                Surface.fromCone(
                    origin: .zero, axis: SIMD3(0, 0, 1), semiAngle: .pi / 6, refRadius: 5,
                    u1: u1, u2: u2, v1: 0, v2: 10) == nil,
                "fromCone(u1: \(u1), u2: \(u2)) returned a surface")
        }
        #expect(
            Surface.fromCone(
                origin: .zero, axis: SIMD3(0, 0, 1), semiAngle: .pi / 6, refRadius: 5,
                u1: 0, u2: .pi, v1: 3, v2: 3) == nil)
    }

    @Test("the indirect route through rectangularTrimmed stays reachable, and so does the control")
    func indirectRouteAndControl() {
        // Geom_RectangularTrimmedSurface::SetTrim normalises U1 > U2 and throws literally on
        // U1 == U2, so GeomConvert never reaches the converters with a reversed range. The guard
        // added here must not have closed that path off.
        if let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5) {
            let trimmed = Surface.rectangularTrimmed(
                basis: cyl, u1: 2 * .pi, u2: 0, v1: 0, v2: 10)
            #expect(trimmed != nil)
        }
        // The control: the same precondition spelled as a literal throw, which always refused.
        #expect(
            Curve2D.fromCircleArc(centerX: 0, centerY: 0, radius: 5, u1: 0, u2: 100) == nil)
    }
}
