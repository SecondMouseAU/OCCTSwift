import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCylinder Tests")
struct GCMakeTrimmedCylinderTests {

    // Each was `if let ... { #expect(s.continuity >= 0) }`, which cannot fail. They now require
    // the surface and pin its trimmed ends to the kernel values in
    // Scripts/repro/766-math-gc-ellipse-trimmed-direction/transcript.txt.
    @Test func trimmedCylinderCircle() throws {
        let s = try #require(
            Surface.gcTrimmedCylinderCircle(
                center: .zero, normal: SIMD3(0, 0, 1),
                radius: 5, height: 10))
        let d = s.domain
        #expect(abs(d.vMax - d.vMin - 10) < 1e-12)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMin) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMax) - SIMD3(5, 0, 10)) < 1e-9)
    }

    @Test func trimmedCylinderAxis() throws {
        let s = try #require(
            Surface.gcTrimmedCylinderAxis(
                point: .zero, direction: SIMD3(0, 0, 1),
                radius: 5, height: 10))
        let d = s.domain
        #expect(abs(d.vMax - d.vMin - 10) < 1e-12)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMin) - SIMD3(5, 0, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMax) - SIMD3(5, 0, 10)) < 1e-9)
    }

    @Test func trimmedCylinder3Pts() throws {
        let s = try #require(
            Surface.gcTrimmedCylinder3Pts(
                p1: SIMD3(5, 0, 0), p2: SIMD3(5, 0, 10), p3: SIMD3(0, 5, 0)))
        let d = s.domain
        #expect(abs(d.vMax - d.vMin - 10) < 1e-12)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMin) - SIMD3(12.0710678119, 0, 0)) < 1e-9)
        #expect(simd_length(s.point(atU: d.uMin, v: d.vMax) - SIMD3(12.0710678119, 0, 10)) < 1e-9)
    }
}

