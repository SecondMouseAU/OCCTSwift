import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - #263: self-intersecting-profile crash guard

/// A self-intersecting ("bowtie") outline, extruded into a prism and then healed by OCCT's
/// `ShapeFix_Shape`, corrupts the heap and aborts the process with an uncatchable OS signal
/// (#263, upstream OCCT; backtrace `ShapeFix_Face::FixOrientation` → `BRep_Tool::Curve` →
/// `BRep_TEdge::EmptyCopy`). Since `OCC_CATCH_SIGNALS` is inert in this build, the bridge cannot
/// recover from the signal, so the prism/heal wrappers detect the `BRepCheck_SelfIntersectingWire`
/// status and refuse the input, returning `nil` instead of crashing. A self-intersecting profile can
/// never form a valid extruded solid, so refusing it loses nothing. These tests would abort the
/// whole test process (not just fail) prior to the guard.
@Suite("Self-Intersecting Profile Crash Guard (#263)")
struct SelfIntersectingProfileGuard263 {
    /// Bowtie quad: (0,0)→(1,1)→(1,0)→(0,1)→close, the two diagonals cross, so the wire
    /// self-intersects. `BRepCheck` flags it `SelfIntersectingWire` / `UnorientableShape`.
    static func bowtieWire() -> Wire? {
        Wire.polygon3D(
            [
                SIMD3(0, 0, 0), SIMD3(1, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0),
            ], closed: true)
    }

    @Test("extrude refuses a self-intersecting profile (returns nil, never crashes)")
    func extrudeRefusesSelfIntersecting() {
        guard let wire = Self.bowtieWire() else { return }
        let solid = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 1)
        #expect(solid == nil)
    }

    @Test("heal refuses a self-intersecting shape (returns nil, never crashes)")
    func healRefusesSelfIntersecting() {
        guard let wire = Self.bowtieWire(), let face = Shape.face(from: wire, planar: true) else {
            return
        }
        let healed = face.healed()
        #expect(healed == nil)
    }

    @Test("a clean convex profile still extrudes and heals")
    func cleanProfileStillWorks() {
        guard
            let wire = Wire.polygon3D(
                [
                    SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0), SIMD3(0, 1, 0),
                ], closed: true)
        else { return }
        let solid = Shape.extrude(profile: wire, direction: SIMD3(0, 0, 1), length: 1)
        #expect(solid != nil)
        if let s = solid {
            #expect(s.isValidSolid)
            #expect(s.healed() != nil)  // healing a valid solid is unaffected by the guard
        }
    }
}
