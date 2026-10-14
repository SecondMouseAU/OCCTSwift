import Foundation
import Testing

@testable import OCCTSwift

#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

/// #3109: revolve builders that never returned for a finite but absurd angle.
///
/// Every revolve builder runs for a time proportional to the angle. Measured one process per input
/// (`Scripts/repro/3109/`): `Shape.revolve`, `revolved(angle:)` and the `localRevolution` forms never
/// return from 1e10 radians, `Shape.revolution(meridian:)` from about 1e6 (the OS kills it), and the
/// revolved feature, which takes degrees, from 1e12. The bridge refuses a magnitude above
/// `occtMaxRevolveAngle`, 1e4 radians. The refusal tests carry `hangLimit` as in
/// `Issue3100BuilderHangTests`, which explains the WASI condition. The controls run the angles a
/// caller means, so a guard that refused everything would still fail them.
@Suite("Revolve builders on finite absurd angles (#3109)")
struct Issue3109RevolveAngleTests {

    private let z = SIMD3<Double>(0, 0, 1)

    /// The smallest absurd angle first, then ones that hung in the measurement, then the extremes.
    private let absurd: [Double] = [
        1.0001e4, 1e5, 1e9, 1e12, 1e15, 1e100, 1e300, .greatestFiniteMagnitude,
        -1.0001e4, -1e9, -1e12, -1e300,
    ]
    private let sensible: [Double] = [0, 1e-12, -1, .pi, 2 * .pi, 20 * .pi, -2 * .pi, 1e4, -1e4]

    private func profile() throws -> Wire {
        try #require(
            Wire.polygon3D([SIMD3(2, 0, 0), SIMD3(4, 0, 0), SIMD3(4, 0, 5), SIMD3(2, 0, 5)]))
    }

    private func face() throws -> Shape {
        let wire = try #require(Wire.rectangle(width: 2, height: 2))
        return try #require(Shape.face(from: wire))
    }

    private let farAxis = SIMD3<Double>(30, 0, 0)

    // The cases are walked in one test per builder rather than `@Test(arguments:)`, so a failure
    // names the angle.

    @Test("Shape.revolve refuses an absurd angle", hangLimit)
    func revolveRefusesAbsurdAngle() throws {
        let wire = try profile()
        for angle in absurd {
            #expect(
                Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: z, angle: angle)
                    == nil, "angle \(angle)")
        }
    }

    @Test("Shape.revolve still revolves the angles a caller means")
    func revolveControls() throws {
        let wire = try profile()
        for angle in sensible {
            #expect(
                Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: z, angle: angle)
                    != nil, "angle \(angle)")
        }
        let full = try #require(Shape.revolve(profile: wire, axisOrigin: .zero, axisDirection: z))
        #expect(full.isValid)
        #expect(abs((full.volume ?? 0) - 188.49555921538757) < 1e-6)
    }

    @Test("revolved(angle:) refuses an absurd angle", hangLimit)
    func revolvedRefusesAbsurdAngle() throws {
        let f = try face()
        for angle in absurd {
            #expect(
                f.revolved(axisOrigin: farAxis, axisDirection: z, angle: angle) == nil,
                "angle \(angle)")
        }
    }

    @Test("revolved(angle:) still revolves the angles a caller means")
    func revolvedControls() throws {
        let f = try face()
        for angle in sensible {
            #expect(
                f.revolved(axisOrigin: farAxis, axisDirection: z, angle: angle) != nil,
                "angle \(angle)")
        }
    }

    @Test("Shape.revolution(meridian:) refuses an absurd angle", hangLimit)
    func revolutionRefusesAbsurdAngle() throws {
        let line = try #require(Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)))
        for angle in absurd {
            #expect(Shape.revolution(meridian: line, angle: angle) == nil, "angle \(angle)")
        }
    }

    @Test("Shape.revolution(meridian:) still revolves the angles a caller means")
    func revolutionControls() throws {
        let line = try #require(Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)))
        for angle in sensible {
            #expect(Shape.revolution(meridian: line, angle: angle) != nil, "angle \(angle)")
        }
        let full = try #require(Shape.revolution(meridian: line))
        #expect(full.isValid)
        #expect(abs((full.volume ?? 0) - 785.3981633974482) < 1e-6)
    }

    @Test("addingRevolvedFeature refuses an absurd angle in degrees", hangLimit)
    func revolvedFeatureRefusesAbsurdAngle() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let rib = try #require(
            Wire.polygon3D([SIMD3(3, 0, 10), SIMD3(6, 0, 10), SIMD3(6, 0, 12), SIMD3(3, 0, 12)]))
        // 1e4 radians is 572957.795 degrees: just over it is refused, just under it is not.
        for degrees in [572_958.0, 1e7, 1e11, 1e12, 1e15, 1e300, -572_958.0, -1e12] {
            #expect(
                base.addingRevolvedFeature(
                    profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                    axisDirection: z, angle: degrees) == nil, "degrees \(degrees)")
        }
    }

    @Test("addingRevolvedFeature still revolves the angles a caller means")
    func revolvedFeatureControls() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let rib = try #require(
            Wire.polygon3D([SIMD3(3, 0, 10), SIMD3(6, 0, 10), SIMD3(6, 0, 12), SIMD3(3, 0, 12)]))
        for degrees in [0, 1e-12, -1, 90, 180, 360, 3600, -360, 572_957.0] {
            #expect(
                base.addingRevolvedFeature(
                    profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                    axisDirection: z, angle: degrees) != nil, "degrees \(degrees)")
        }
    }

    @Test(
        "localRevolution, with and without an offset, and localRevolutionForm refuse an absurd angle",
        hangLimit)
    func localRevolutionsRefuseAbsurdAngle() throws {
        let f = try face()
        for angle in absurd {
            #expect(
                f.localRevolution(axisOrigin: farAxis, axisDirection: z, angle: angle) == nil,
                "localRevolution angle \(angle)")
            #expect(
                f.localRevolution(
                    axisOrigin: farAxis, axisDirection: z, angle: angle, angularOffset: 0.1)
                    == nil, "localRevolution offset angle \(angle)")
            #expect(
                f.localRevolutionForm(axisOrigin: farAxis, axisDirection: z, angle: angle) == nil,
                "localRevolutionForm angle \(angle)")
        }
    }

    @Test("localRevolution and localRevolutionForm still answer the angles a caller means")
    func localRevolutionControls() throws {
        let f = try face()
        for angle in sensible {
            #expect(
                f.localRevolution(axisOrigin: farAxis, axisDirection: z, angle: angle) != nil,
                "localRevolution angle \(angle)")
            #expect(
                f.localRevolution(
                    axisOrigin: farAxis, axisDirection: z, angle: angle, angularOffset: 0.1)
                    != nil, "localRevolution offset angle \(angle)")
            #expect(
                f.localRevolutionForm(axisOrigin: farAxis, axisDirection: z, angle: angle) != nil,
                "localRevolutionForm angle \(angle)")
        }
    }
}
