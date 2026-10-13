import Foundation
import Testing

@testable import OCCTSwift

// A call that never returned is a failure no assertion can report, so the tests that would hang
// without their guard carry a time limit; a synchronous OCCT loop cannot be interrupted by it, so
// the prove-the-test-fails run kills the process from outside and reports the timeout. On WASI the
// trait measures the runner's single-threaded timer and not the code (see Issue3100BuilderHang).
#if os(WASI)
    private let hangLimit: ConditionTrait = .enabled(if: true)
#else
    private let hangLimit: TimeLimitTrait = .timeLimit(.minutes(1))
#endif

// MARK: - v0.33.0. OCCT Test Suite Audit Round 2

@Suite("Evolved Advanced")
struct EvolvedAdvancedTests {
    private func rectangleWire(_ side: Double = 20) throws -> Wire {
        try #require(Wire.rectangle(width: side, height: side))
    }

    private func segment(x: Double = 0, height: Double = 3) throws -> Wire {
        try #require(
            Wire.polygon3D([SIMD3(x, 0, 0), SIMD3(x, 0, height)], closed: false))
    }

    // The old fixture was a box solid for a spine and a profile in the spine's own plane, which
    // returns nil, and the result was discarded. A planar 20 x 20 face spine with a vertical
    // 3 mm segment is the 20 x 20 x 3 slab with `solid: true` (volume 1200, area 1040, six
    // faces) and the four 20 x 3 walls (area 240) with `solid: false` (kernel.6).
    @Test("Evolved advanced with arc join")
    func evolvedAdvancedArc() throws {
        let spine = try #require(Shape.face(from: try rectangleWire()))
        let profile = try segment()

        let slab = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: profile,
                joinType: .arc, axeProf: true, solid: true))
        #expect(slab.isValid)
        #expect(slab.shapeType == .solid)
        #expect(slab.faces().count == 6)
        #expect(abs((slab.volume ?? -1) - 1200.0) < 1e-6)
        #expect(abs((slab.surfaceArea ?? -1) - 1040.0) < 1e-6)

        let walls = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: profile,
                joinType: .arc, axeProf: true, solid: false))
        #expect(walls.faces().count == 4)
        #expect(abs((walls.surfaceArea ?? -1) - 240.0) < 1e-6)
    }

    // OCCT implements only the Arc join for an evolved shape: BRepFill_Evolved::PrivatePerform
    // opens with `if (myJoinType > GeomAbs_Arc) throw Standard_NotImplemented()`, and the class
    // header says "At present, this is the only construction type implemented". So the tangent
    // and intersection joins are nil for the face spine and the wire spine, solid or not, on an
    // input the arc join builds (#3368). The arc join on the same input is the control that the
    // fixture itself is good.
    @Test("Evolved advanced only builds the arc join")
    func evolvedAdvancedIntersection() throws {
        let wire = try rectangleWire(10)
        let profile = try segment()

        for spine in [try #require(Shape.fromWire(wire)), try #require(Shape.face(from: wire))] {
            let arc = try #require(
                Shape.evolvedAdvanced(
                    spine: spine, profile: profile, joinType: .arc, solid: false))
            #expect(abs((arc.surfaceArea ?? -1) - 120.0) < 1e-6)

            for joinType in [Shape.OffsetJoinType.tangent, .intersection] {
                for solid in [true, false] {
                    #expect(
                        Shape.evolvedAdvanced(
                            spine: spine, profile: profile, joinType: joinType, solid: solid)
                            == nil,
                        "join \(joinType), solid \(solid)")
                }
            }
        }
    }

    // `axeProf: false` computes the profile's frame with `BRepFill::Axe`: the origin is the point
    // of the spine nearest the profile, X the spine's tangent there, Z the spine plane's normal.
    // A vertical profile through the centre of a circular spine has no nearest point (every point
    // of the circle is equally near), `Axe` leaves the frame NaN and the call never returned
    // (#3368, spinning in `Geom_TrimmedCurve::SetTrim`). It is refused. The same profile with
    // `axeProf: true`, and a profile that is on or beside the circle with `axeProf: false`, are
    // the controls that the refusal is not a blanket one.
    @Test("Circle spine with a profile through its centre and axeProf false is refused", hangLimit)
    func circleSpineProfileThroughCentre() throws {
        let circle = try #require(Wire.circle(radius: 20))
        let spine = try #require(Shape.fromWire(circle))

        #expect(
            Shape.evolvedAdvanced(
                spine: spine, profile: try segment(), axeProf: false, solid: false) == nil)

        // Control: global frame. Three faces, area 2 pi 20 3.
        let global = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: try segment(), axeProf: true, solid: false))
        #expect(global.faces().count == 3)
        #expect(abs((global.surfaceArea ?? -1) - 2.0 * Double.pi * 20.0 * 3.0) < 1e-6)

        // Control: the profile stands on the circle, so the local frame is the global one.
        let onSpine = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: try segment(x: 20), axeProf: false, solid: false))
        #expect(onSpine.faces().count == 3)
        #expect(abs((onSpine.surfaceArea ?? -1) - 2.0 * Double.pi * 20.0 * 3.0) < 1e-6)

        // Control: 2 outside the circle, so the walls sit on radius 22.
        let outside = try #require(
            Shape.evolvedAdvanced(
                spine: spine, profile: try segment(x: 22), axeProf: false, solid: false))
        #expect(abs((outside.surfaceArea ?? -1) - 2.0 * Double.pi * 22.0 * 3.0) < 1e-6)
    }

    // A profile at the spine's inradius offsets it to nothing. OCCT is done with an empty
    // compound, which `isValid` accepts and which has no face to measure: refused, the same as a
    // failed build. The segment at the middle of an edge, which the local frame puts on the
    // spine, is the control.
    @Test("A profile offsetting the spine to nothing is refused")
    func collapsedOffsetIsRefused() throws {
        let wire = try rectangleWire()
        let spineWire = try #require(Shape.fromWire(wire))
        let spineFace = try #require(Shape.face(from: wire))
        // (0, 0, 0) is the centre of the 20 x 20 rectangle: 10, its inradius, from every edge.
        for spine in [spineWire, spineFace] {
            #expect(
                Shape.evolvedAdvanced(
                    spine: spine, profile: try segment(), axeProf: false, solid: false) == nil)
            #expect(
                Shape.evolvedAdvanced(
                    spine: spine, profile: try segment(), axeProf: false, solid: true) == nil)
        }

        let onEdge = try #require(
            Shape.evolvedAdvanced(
                spine: spineWire, profile: try segment(x: 10), axeProf: false, solid: false))
        #expect(onEdge.faces().count == 4)
        #expect(abs((onEdge.surfaceArea ?? -1) - 240.0) < 1e-6)
    }

    // The profile is placed in the frame R and projected onto its YOZ plane: Y is the lateral
    // offset from the spine in the spine's plane (positive to the left of the spine's direction,
    // which is the inside of a counter-clockwise rectangle), Z the height above it, and X, along
    // the spine, is dropped. An L whose legs run in Y and Z is swept; the same L drawn in the
    // XZ plane projects onto the Z axis, where its flat legs are points and its vertical legs
    // overlap, and nothing is built (the "L, square and triangle" nils of #3368 were this).
    @Test("Profile placement: lateral offset in Y, height in Z, X is dropped")
    func profilePlacement() throws {
        let spine = try #require(Shape.fromWire(try rectangleWire()))

        let inYZ = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(0, 2, 0), SIMD3(0, 2, 2), SIMD3(0, 0, 2)], closed: false))
        let swept = try #require(
            Shape.evolvedAdvanced(spine: spine, profile: inYZ, axeProf: true, solid: false))
        #expect(swept.isValid)
        // Inward by 2: the two 20 x 20 to 16 x 16 bands (144 each) and the 64 x 2 wall.
        #expect(swept.faces().count == 6)
        #expect(abs((swept.surfaceArea ?? -1) - 416.0) < 1e-6)
        let bounds = try #require(swept.boundingBox)
        #expect(abs(bounds.max.x - 10.0) < 1e-5 && abs(bounds.min.x + 10.0) < 1e-5)
        #expect(abs(bounds.min.z) < 1e-5 && abs(bounds.max.z - 2.0) < 1e-5)

        let inXZ = try #require(
            Wire.polygon3D(
                [SIMD3(0, 0, 0), SIMD3(2, 0, 0), SIMD3(2, 0, 2), SIMD3(0, 0, 2)], closed: false))
        #expect(
            Shape.evolvedAdvanced(spine: spine, profile: inXZ, axeProf: true, solid: false) == nil)
    }
}
