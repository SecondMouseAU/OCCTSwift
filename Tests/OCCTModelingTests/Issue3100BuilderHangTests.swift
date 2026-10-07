import Foundation
import Testing

@testable import OCCTSwift

#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

/// #3100: builders that never returned for a zero, NaN, infinite or overflowing input.
///
/// Two failure shapes, both measured on the released kernel with one input per process and `sample`:
/// the extrusion family and `Shape.fromMesh` return a shape promptly, and the first call that walks it
/// (`isValid`) spins in `Geom_TrimmedCurve::SetTrim` below `BRepCheck_Edge::InContext`; the draft
/// prisms and the revolved feature spin inside the builder (`BRepFill_Evolved::PrepareProfile`,
/// `BRepLib::FindValidRange`), and `BRepSweep_Revol` spins on an infinite angle. Each refusal is the
/// bridge returning nil before OCCT is called.
///
/// Every test that would hang without its guard carries `hangLimit`, which is
/// `.timeLimit(.minutes(1))` on native. A synchronous OCCT loop cannot be interrupted by that trait,
/// so the prove-the-test-fails run kills the process from outside and reports the timeout as the
/// failure. On WASI the trait is not applied: measured on the wasm CI job and again locally, a test
/// body that finished in milliseconds was reported "Time limit was exceeded: 60.000 seconds" and
/// failed after exactly 60 s, for every test carrying the trait and none without it, so there it
/// measures the runner's single-threaded timer and not the code under test. A hang on wasm is
/// caught by the suite's own wall-clock cap in `Scripts/run-wasm-tests.sh`. The controls run valid small inputs, because a
/// guard that refused every input would pass every refusal test.
///
/// Triangle indices are 1-based. An earlier draft of the mesh control used `(0, 1, 2)`, index 0 is
/// outside the node array, and it failed one run in about twenty with nothing else changed.
@Suite("Builder hangs on zero, NaN and overflowing input (#3100)")
struct Issue3100BuilderHangTests {

    private let z = SIMD3<Double>(0, 0, 1)

    private func square() throws -> Wire {
        try #require(Wire.rectangle(width: 4, height: 4))
    }

    private func squareFace() throws -> Shape {
        try #require(Shape.face(from: try square()))
    }

    /// A 20 mm cube centred on the origin, so face 4 is the top at z = 10, and a profile on it.
    private func baseAndTopProfile() throws -> (Shape, Wire) {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let profile = try #require(
            Wire.polygon3D([
                SIMD3(-3, -3, 10), SIMD3(3, -3, 10), SIMD3(3, 3, 10), SIMD3(-3, 3, 10),
            ]))
        return (base, profile)
    }

    private func revolveProfile() throws -> Wire {
        try #require(
            Wire.polygon3D([SIMD3(2, 0, 0), SIMD3(4, 0, 0), SIMD3(4, 0, 5), SIMD3(2, 0, 5)]))
    }

    // MARK: - Extrusion

    @Test(
        "Shape.extrude refuses a zero, NaN or infinite length and a NaN, infinite or overflowing direction",
        hangLimit)
    func extrudeRefusesDegenerateLengthAndDirection() throws {
        let rectangle = try square()
        let collinear = try #require(
            Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(2, 0, 0)]))
        // A list walked in one test rather than `@Test(arguments:)`, so a failure names the case.
        let lengths: [Double] = [0, -0.0, .nan, .infinity, -.infinity, 1e-300]
        for wire in [rectangle, collinear] {
            for length in lengths {
                #expect(
                    Shape.extrude(profile: wire, direction: z, length: length) == nil,
                    "length \(length)")
            }
        }
        let directions: [SIMD3<Double>] = [
            SIMD3(.nan, 0, 1), SIMD3(0, 0, .infinity), SIMD3(0, 0, 1e155), SIMD3(0, 0, 1e200),
            SIMD3(0, 0, 0),
        ]
        for direction in directions {
            #expect(
                Shape.extrude(profile: rectangle, direction: direction, length: 5) == nil,
                "direction \(direction)")
        }
    }

    @Test("Shape.extrude still extrudes a small finite length and a tiny direction")
    func extrudeControls() throws {
        let rectangle = try square()
        let one = try #require(Shape.extrude(profile: rectangle, direction: z, length: 1e-6))
        #expect(one.isValid)
        // Below the confusion tolerance OCCT answers a solid it then calls invalid. That is today's
        // behaviour and the guard leaves it alone; only the shape's existence is asserted.
        for length in [1e-9, 1e-12, 1e-100, -5.0] {
            #expect(
                Shape.extrude(profile: rectangle, direction: z, length: length) != nil,
                "length \(length)")
        }
        let tinyDirection = try #require(
            Shape.extrude(profile: rectangle, direction: SIMD3(0, 0, 1e-9), length: 5))
        #expect(tinyDirection.isValid)
        let hugeDirection = try #require(
            Shape.extrude(profile: rectangle, direction: SIMD3(0, 0, 1e150), length: 5))
        #expect(hugeDirection.isValid)
    }

    @Test(
        "extruded(by:) refuses a zero, NaN, infinite or under/overflowing vector",
        hangLimit)
    func extrudedByRefusesDegenerateVector() throws {
        let face = try squareFace()
        let vectors: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(.nan, 0, 0), SIMD3(0, .nan, 0), SIMD3(0, 0, .infinity),
            SIMD3(0, 0, -.infinity), SIMD3(0, 0, 1e-300), SIMD3(0, 0, 1e-200),
        ]
        for vector in vectors {
            #expect(face.extruded(by: vector) == nil, "vector \(vector)")
        }
    }

    @Test("extruded(by:) still extrudes a small finite vector")
    func extrudedByControls() throws {
        let face = try squareFace()
        let small = try #require(face.extruded(by: SIMD3(0, 0, 1e-6)))
        #expect(small.isValid)
        for z in [1e-9, 1e-12, 1e-100, 1e-160] {
            #expect(face.extruded(by: SIMD3(0, 0, z)) != nil, "z \(z)")
        }
        let ordinary = try #require(face.extruded(by: SIMD3(0, 0, 5)))
        #expect(ordinary.isValid)
    }

    @Test(
        "extrudedInfinite and extrudedSemiInfinite refuse a zero, NaN, infinite or overflowing direction",
        hangLimit)
    func infiniteExtrusionRefusesDegenerateDirection() throws {
        let face = try squareFace()
        let directions: [SIMD3<Double>] = [
            SIMD3(0, 0, 0), SIMD3(.nan, 0, 0), SIMD3(0, 0, .nan), SIMD3(0, 0, .infinity),
            SIMD3(0, 0, -.infinity), SIMD3(0, 0, 1e300), SIMD3(0, 0, 1e155),
            SIMD3(0, 0, 1e-300),
        ]
        for direction in directions {
            for both in [true, false] {
                #expect(
                    face.extrudedInfinite(direction: direction, infinite: both) == nil,
                    "extrudedInfinite \(direction) infinite \(both)")
                #expect(
                    face.extrudedSemiInfinite(direction: direction, infinite: both) == nil,
                    "extrudedSemiInfinite \(direction) infinite \(both)")
            }
        }
    }

    @Test("The infinite extrusions still accept a tiny or a large finite direction")
    func infiniteExtrusionControls() throws {
        let face = try squareFace()
        let semi = try #require(face.extrudedSemiInfinite(direction: z))
        #expect(semi.isValid)
        // Direction length is irrelevant to a prism, so scaled directions are the same extrusion.
        for scale in [1e-6, 1e-100, 1e150] {
            let direction = z * scale
            #expect(face.extrudedInfinite(direction: direction) != nil, "scale \(scale)")
            #expect(
                try #require(face.extrudedSemiInfinite(direction: direction)).isValid,
                "scale \(scale)")
        }
    }

    // MARK: - Angles

    @Test(
        "The draft prisms refuse a NaN or infinite draft angle, from either face and either fuse",
        hangLimit)
    func draftPrismRefusesNonFiniteAngle() throws {
        let (base, top) = try baseAndTopProfile()
        let bottom = try #require(
            Wire.polygon3D([
                SIMD3(-3, -3, -10), SIMD3(3, -3, -10), SIMD3(3, 3, -10), SIMD3(-3, 3, -10),
            ]))
        for angle in [Double.nan, .infinity, -.infinity] {
            for fuse in [true, false] {
                #expect(
                    base.addingDraftPrism(
                        profile: top, sketchFaceIndex: 4, draftAngle: angle, height: 5, fuse: fuse)
                        == nil, "addingDraftPrism \(angle) fuse \(fuse)")
                #expect(
                    base.addingDraftPrismThruAll(
                        profile: top, sketchFaceIndex: 4, draftAngle: angle, fuse: fuse) == nil,
                    "thru all, top, \(angle) fuse \(fuse)")
                #expect(
                    base.addingDraftPrismThruAll(
                        profile: bottom, sketchFaceIndex: 5, draftAngle: angle, fuse: fuse) == nil,
                    "thru all, bottom, \(angle) fuse \(fuse)")
            }
        }
    }

    @Test("The draft prisms still accept a zero, a small and an ordinary angle")
    func draftPrismControls() throws {
        let (base, top) = try baseAndTopProfile()
        for angle in [0.0, 1e-9, 5.0] {
            let boss = try #require(
                base.addingDraftPrism(
                    profile: top, sketchFaceIndex: 4, draftAngle: angle, height: 5, fuse: true),
                "angle \(angle)")
            #expect(boss.isValid)
            let pocket = try #require(
                base.addingDraftPrismThruAll(
                    profile: top, sketchFaceIndex: 4, draftAngle: angle, fuse: false),
                "thru all angle \(angle)")
            #expect(pocket.isValid)
        }
    }

    @Test(
        "addingRevolvedFeature refuses a NaN or infinite angle for both fuse values",
        hangLimit)
    func revolvedFeatureRefusesNonFiniteAngle() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let rib = try #require(
            Wire.polygon3D([
                SIMD3(3, 0, 10), SIMD3(6, 0, 10), SIMD3(6, 0, 12), SIMD3(3, 0, 12),
            ]))
        for angle in [Double.nan, .infinity, -.infinity] {
            for fuse in [true, false] {
                #expect(
                    base.addingRevolvedFeature(
                        profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                        axisDirection: z, angle: angle, fuse: fuse) == nil,
                    "angle \(angle) fuse \(fuse)")
            }
        }
        for angle in [360.0, 90.0, -90.0, 0.0] {
            #expect(
                base.addingRevolvedFeature(
                    profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                    axisDirection: z, angle: angle, fuse: true) != nil, "control \(angle)")
        }
    }

    @Test(
        "The revolutions refuse a NaN or infinite angle and keep a zero angle and a full turn",
        hangLimit)
    func revolutionsRefuseNonFiniteAngle() throws {
        let profile = try revolveProfile()
        let face = try #require(Shape.face(from: profile))
        let meridian = try #require(Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(5, 0, 10)))
        for angle in [Double.nan, .infinity, -.infinity] {
            #expect(
                Shape.revolve(
                    profile: profile, axisOrigin: .zero, axisDirection: z, angle: angle) == nil,
                "revolve \(angle)")
            #expect(
                face.revolved(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle) == nil,
                "revolved \(angle)")
            #expect(
                Shape.revolution(meridian: meridian, angle: angle) == nil, "revolution \(angle)")
        }
        // Controls: the angles a caller means, a zero and a full turn among them, still build.
        for angle in [0.0, 1e-12, .pi, 2 * .pi, -1.0] {
            #expect(
                Shape.revolve(profile: profile, axisOrigin: .zero, axisDirection: z, angle: angle)
                    != nil, "revolve control \(angle)")
            #expect(
                face.revolved(axisOrigin: SIMD3(30, 0, 0), axisDirection: z, angle: angle) != nil,
                "revolved control \(angle)")
            #expect(
                Shape.revolution(meridian: meridian, angle: angle) != nil,
                "revolution control \(angle)")
        }
        let full = try #require(
            Shape.revolve(profile: profile, axisOrigin: .zero, axisDirection: z, angle: 2 * .pi))
        #expect(full.isValid)
    }

    // MARK: - Siblings reaching the same classes

    @Test(
        "The local prisms, the linear form and withPrism refuse a NaN, infinite or zero vector",
        hangLimit)
    func prismSiblingsRefuseDegenerateVector() throws {
        let face = try squareFace()
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let profile = try baseAndTopProfile().1
        let vectors: [SIMD3<Double>] = [SIMD3(.nan, 0, 1), SIMD3(0, 0, 0), SIMD3(0, 0, .infinity)]
        for v in vectors {
            #expect(face.localPrism(direction: v) == nil, "localPrism \(v)")
            #expect(
                face.localPrism(direction: v, translation: SIMD3(0, 0, 0.1)) == nil,
                "localPrism with translation \(v)")
            #expect(
                face.localLinearForm(direction: v, from: .zero, to: SIMD3(1, 0, 0)) == nil,
                "localLinearForm \(v)")
            #expect(
                base.withPrism(profile: profile, direction: v, height: 5, fuse: true) == nil,
                "withPrism direction \(v)")
        }
        for height in [Double.nan, .infinity, 0] {
            #expect(
                base.withPrism(profile: profile, direction: z, height: height, fuse: true) == nil,
                "withPrism height \(height)")
        }
        #expect(
            base.withPrism(profile: profile, direction: SIMD3(0, 0, 1e155), height: 5, fuse: true)
                == nil)
    }

    @Test("The local prisms and withPrism still build for an ordinary vector")
    func prismSiblingControls() throws {
        let face = try squareFace()
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let profile = try baseAndTopProfile().1
        #expect(face.localPrism(direction: SIMD3(0, 0, 5)) != nil)
        #expect(face.localPrism(direction: SIMD3(0, 0, 5), translation: .zero) != nil)
        #expect(face.localLinearForm(direction: z, from: .zero, to: SIMD3(1, 0, 0)) != nil)
        let boss = try #require(
            base.withPrism(profile: profile, direction: z, height: 5, fuse: true))
        #expect(boss.isValid)
    }

    @Test(
        "The local revolutions, the partial revolve and the face draft prisms refuse a NaN or infinite angle, axis or height",
        hangLimit)
    func revolveAndDraftSiblingsRefuseNonFinite() throws {
        let face = try squareFace()
        let origin = SIMD3<Double>(30, 0, 0)
        for axis in [SIMD3<Double>(.nan, 0, 1), SIMD3(0, 0, .infinity)] {
            #expect(face.revolved(axisOrigin: origin, axisDirection: axis, angle: 1) == nil)
            #expect(face.localRevolution(axisOrigin: origin, axisDirection: axis, angle: 1) == nil)
            #expect(
                face.localRevolutionForm(axisOrigin: origin, axisDirection: axis, angle: 1) == nil)
        }
        for angle in [Double.infinity, -.infinity] {
            #expect(face.localRevolution(axisOrigin: origin, axisDirection: z, angle: angle) == nil)
            #expect(
                face.localRevolution(
                    axisOrigin: origin, axisDirection: z, angle: angle, angularOffset: 0.1) == nil)
            #expect(
                face.localRevolutionForm(axisOrigin: origin, axisDirection: z, angle: angle) == nil)
        }
        #expect(
            face.localRevolution(
                axisOrigin: origin, axisDirection: z, angle: 1, angularOffset: .infinity) == nil)
        let profileFace = try #require(face.faces().first)
        for value in [Double.nan, .infinity] {
            #expect(profileFace.draftPrism(height1: 1, height2: 1, angle: value) == nil)
            #expect(profileFace.draftPrism(height: 1, angle: value) == nil)
            #expect(profileFace.draftPrism(height: value, angle: 0.1) == nil)
            #expect(profileFace.draftPrism(height1: value, height2: 1, angle: 0.1) == nil)
        }
        let (base, top) = try baseAndTopProfile()
        for height in [Double.nan, .infinity] {
            #expect(
                base.addingDraftPrism(
                    profile: top, sketchFaceIndex: 4, draftAngle: 5, height: height) == nil,
                "addingDraftPrism height \(height)")
        }
    }

    @Test(
        "The partial revolve, local revolutions and face draft prisms still build for ordinary input"
    )
    func revolveAndDraftSiblingControls() throws {
        let face = try squareFace()
        let origin = SIMD3<Double>(30, 0, 0)
        #expect(face.revolved(axisOrigin: origin, axisDirection: z, angle: 1) != nil)
        #expect(face.localRevolution(axisOrigin: origin, axisDirection: z, angle: 1) != nil)
        #expect(
            face.localRevolution(
                axisOrigin: origin, axisDirection: z, angle: 1, angularOffset: 0.1) != nil)
        #expect(face.localRevolutionForm(axisOrigin: origin, axisDirection: z, angle: 1) != nil)
        let profileFace = try #require(face.faces().first)
        #expect(profileFace.draftPrism(height1: 1, height2: 1, angle: 0.1) != nil)
        #expect(profileFace.draftPrism(height: 1, angle: 0.1) != nil)
        let (base, top) = try baseAndTopProfile()
        let boss = try #require(
            base.addingDraftPrism(profile: top, sketchFaceIndex: 4, draftAngle: 5, height: 5))
        #expect(boss.isValid)
    }

    /// The thru-all revolved feature takes an axis and no angle, and answers a bad axis.
    ///
    /// A review asked for an angle guard on `OCCTShapeRevolFeatureThruAll` and for this test to
    /// expect `nil`. The function has no angle, and on the released kernel a NaN, infinite or
    /// overflowing axis does not hang it and does not make it fail: measured one process per input,
    /// each answers a non-nil compound that `isValid` accepts (the cut is simply not applied). That
    /// is a quirk of the kernel, not a refusal this PR makes, so the test pins what happens: it
    /// returns, answers a shape, and the shape is valid. `isValid` is the call that spun for the
    /// extrusions, and it is safe here only because the probe showed these shapes valid; the
    /// `hangLimit` trait bounds it on native.
    @Test(
        "addingRevolvedFeatureThruAll answers a valid shape for a NaN, infinite or overflowing axis",
        hangLimit)
    func revolvedFeatureThruAllAxisAnswers() throws {
        let base = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let rib = try #require(
            Wire.polygon3D([
                SIMD3(3, 0, 10), SIMD3(6, 0, 10), SIMD3(6, 0, 12), SIMD3(3, 0, 12),
            ]))
        for axis in [SIMD3<Double>(.nan, 0, 1), SIMD3(0, 0, .infinity), SIMD3(0, 0, 1e155)] {
            let result = try #require(
                base.addingRevolvedFeatureThruAll(
                    profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                    axisDirection: axis, fuse: false),
                "axis \(axis)")
            #expect(result.isValid, "axis \(axis)")
        }
        let ok = try #require(
            base.addingRevolvedFeatureThruAll(
                profile: rib, sketchFaceIndex: 4, axisOrigin: SIMD3(0, 0, 10),
                axisDirection: z, fuse: false))
        #expect(ok.isValid)
    }

    // MARK: - Mesh

    @Test(
        "Shape.fromMesh refuses a NaN or infinite coordinate anywhere in the points",
        hangLimit)
    func fromMeshRefusesNonFiniteCoordinate() {
        let triangle: [(Int32, Int32, Int32)] = [(1, 2, 3)]
        let bad: [[SIMD3<Double>]] = [
            [SIMD3(.nan, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(0, 0, 0), SIMD3(1, .nan, 0), SIMD3(0, 1, 0)],
            [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, .nan)],
            [SIMD3(.infinity, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)],
            [SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, .nan)],
        ]
        for points in bad {
            #expect(Shape.fromMesh(points: points, triangles: triangle) == nil, "\(points)")
        }
    }

    @Test("Shape.fromMesh still builds a mesh with ordinary and small coordinates")
    func fromMeshControls() throws {
        let triangle: [(Int32, Int32, Int32)] = [(1, 2, 3)]
        for scale in [1.0, 1e-3] {
            let points: [SIMD3<Double>] = [
                SIMD3(0, 0, 0), SIMD3(scale, 0, 0), SIMD3(0, scale, 0),
            ]
            let shape = try #require(Shape.fromMesh(points: points, triangles: triangle))
            #expect(shape.isValid)
        }
    }
}
