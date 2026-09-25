import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntAna PlanePlane Tests")
struct IntAnaPlanePlaneTests {

    /// Same planes as `planePlaneLine` below, read as an intersection rather than as a line. This
    /// used to assert `r.count >= 1` alone, which any line, and any number of them, satisfies; it
    /// now asserts the one line the kernel reports (`Scripts/repro/766-intana-planes-quadrics/`):
    /// through the origin along -X.
    @Test func planePlaneIntersection() throws {
        let r = IntAna.planePlane(
            p1Origin: SIMD3(0, 0, 0), p1Normal: SIMD3(0, 0, 1),
            p2Origin: SIMD3(0, 0, 0), p2Normal: SIMD3(0, 1, 0))
        try #require(r.count == 1)
        let line = try #require(r.lines.first)
        #expect(simd_length(line.origin) < 1e-12)
        #expect(abs(line.direction.x + 1) < 1e-12)
        #expect(abs(line.direction.y) < 1e-12)
        #expect(abs(line.direction.z) < 1e-12)
    }

    /// The planes z = 0 and y = 0 meet in the X axis. `IntAna_QuadQuadGeo` reports it as one line
    /// through the origin with direction (-1, 0, 0), the cross product of the two normals.
    ///
    /// This used to skip every check when no line came back, and then check only that the
    /// direction had unit length, which any axis does.
    @Test func planePlaneLine() throws {
        let r = IntAna.planePlane(
            p1Origin: SIMD3(0, 0, 0), p1Normal: SIMD3(0, 0, 1),
            p2Origin: SIMD3(0, 0, 0), p2Normal: SIMD3(0, 1, 0))
        try #require(r.count == 1)
        let line = try #require(r.lines.first)
        #expect(simd_length(line.origin) < 1e-12)
        #expect(abs(line.direction.x + 1) < 1e-12)
        #expect(abs(line.direction.y) < 1e-12)
        #expect(abs(line.direction.z) < 1e-12)
    }
}
