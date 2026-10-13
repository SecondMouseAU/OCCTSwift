import Foundation
import Testing

@testable import OCCTSwift

@Suite("Curve3D Local Properties Tests")
struct Curve3DLocalPropertiesTests {

    @Test("Curvature of circle is 1/r")
    func circleRadius() throws {
        let radius = 5.0
        let circle = try #require(
            Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius))
        let curv = circle.curvature(at: 0)
        if let curv {
            #expect(abs(curv - 1.0 / radius) < 1e-6)
        } else {
            Issue.record("no curvature")
        }
    }

    @Test("Curvature of line is zero")
    func lineCurvature() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let d = seg.domain
        // #595: a straight curve reports 0, an answer -- not the nil a fully degenerate one gives.
        let curv = seg.curvature(at: (d.lowerBound + d.upperBound) / 2)
        if let curv {
            #expect(abs(curv) < 1e-10)
        } else {
            Issue.record("a segment has curvature 0")
        }
    }

    @Test("Tangent of X-axis segment is (1,0,0)")
    func segmentTangent() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0)))
        let d = seg.domain
        let tang = seg.tangentDirection(at: (d.lowerBound + d.upperBound) / 2)
        #expect(tang != nil)
        if let t = tang {
            #expect(abs(t.x - 1) < 1e-6)
            #expect(abs(t.y) < 1e-6)
            #expect(abs(t.z) < 1e-6)
        }
    }

    @Test("Normal of circle points inward")
    func circleNormal() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let n = circle.normal(at: 0)
        #expect(n != nil)
        if let n = n {
            let len = vectorLength(n)
            #expect(abs(len - 1.0) < 1e-6)
        }
    }

    @Test("Center of curvature of circle is at origin")
    func circleCenterOfCurvature() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        let c = circle.centerOfCurvature(at: 0)
        #expect(c != nil)
        if let c = c {
            #expect(abs(c.x) < 0.01)
            #expect(abs(c.y) < 0.01)
        }
    }

    @Test("Torsion of planar circle is zero")
    func circularTorsion() throws {
        let circle = try #require(Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5))
        // #595: a planar curve reports torsion 0, an answer -- a straight one now reports nil.
        let tor = circle.torsion(at: 0.5)
        if let tor { #expect(abs(tor) < 1e-6) } else { Issue.record("a circle has torsion 0") }
    }

    @Test("Bounding box of segment")
    func segmentBoundingBox() throws {
        let seg = try #require(Curve3D.segment(from: SIMD3(1, 2, 3), to: SIMD3(10, 8, 6)))
        let bb = seg.boundingBox
        #expect(bb != nil)
        if let bb = bb {
            #expect(bb.min.x <= 1.01)
            #expect(bb.max.x >= 9.99)
        }
    }
}
