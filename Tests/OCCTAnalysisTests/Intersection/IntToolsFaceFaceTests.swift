import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("IntTools_FaceFace Tests")
struct IntToolsFaceFaceTests {
    @Test("Perpendicular box faces produce intersection line")
    func faceFaceIntersection() throws {
        // Two perpendicular square faces through the origin meet in one line, (5, 0, 0) to
        // (-5, 0, 0) (`Scripts/repro/766-intcs-inttools/`). Every fixture and the result are
        // required: the whole body sat under `if let`s, so a nil face or result passed.
        let s1 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let s2 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 1, 0)))
        let face1 = try #require(Shape.face(from: s1, uRange: -5...5, vRange: -5...5))
        let face2 = try #require(Shape.face(from: s2, uRange: -5...5, vRange: -5...5))
        let r = try #require(face1.faceFaceIntersection(with: face2))
        #expect(r.curves.count == 1)
        #expect(!r.isTangent)
    }

    @Test("Coincident planes are tangent")
    func faceFaceTangent() throws {
        // Every fixture and the result are required: a nil result skipped the one assertion.
        let s1 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let s2 = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let face1 = try #require(Shape.face(from: s1, uRange: -5...5, vRange: -5...5))
        let face2 = try #require(Shape.face(from: s2, uRange: -5...5, vRange: -5...5))
        let r = try #require(face1.faceFaceIntersection(with: face2))
        #expect(r.isTangent)
    }
}
