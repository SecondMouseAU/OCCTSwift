import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D Operations Tests")
struct Curve3DOperationsTests {

    @Test("Trim circle to quarter arc")
    func trimCircle() {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let arc = circle.trimmed(from: 0, to: .pi / 2)
        #expect(arc != nil)
        if let arc = arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 5) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
        }
    }

    @Test("Reverse segment swaps endpoints")
    func reverseSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 5, 3))!
        let rev = seg.reversed()!
        let revStart = rev.startPoint
        let revEnd = rev.endPoint
        #expect(abs(revStart.x - 10) < 1e-10)
        #expect(abs(revEnd.x) < 1e-10)
    }

    @Test("Translate segment")
    func translateSegment() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let moved = seg.translated(by: SIMD3(5, 5, 5))!
        let start = moved.startPoint
        #expect(abs(start.x - 5) < 1e-10)
        #expect(abs(start.y - 5) < 1e-10)
        #expect(abs(start.z - 5) < 1e-10)
    }

    @Test("Rotate segment around Z axis")
    func rotateSegment() {
        let seg = Curve3D.segment(from: SIMD3(5, 0, 0), to: SIMD3(10, 0, 0))!
        let rotated = seg.rotated(around: .zero, direction: SIMD3(0, 0, 1), angle: .pi / 2)!
        let start = rotated.startPoint
        #expect(abs(start.x) < 0.01)
        #expect(abs(start.y - 5) < 0.01)
    }

    @Test("Scale segment")
    func scaleSegment() {
        let seg = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 0, 0))!
        let scaled = seg.scaled(from: .zero, factor: 3)!
        let start = scaled.startPoint
        let end = scaled.endPoint
        #expect(abs(start.x - 3) < 1e-10)
        #expect(abs(end.x - 6) < 1e-10)
    }

    @Test("Mirror across XY plane")
    func mirrorPlane() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 1), to: SIMD3(10, 0, 1))!
        let mirrored = seg.mirrored(acrossPlane: .zero, normal: SIMD3(0, 0, 1))!
        let start = mirrored.startPoint
        #expect(abs(start.z + 1) < 1e-10)
    }

    // #416: mirrored(acrossPoint:) had zero test coverage anywhere in Tests/.
    @Test("Mirror across a point")
    func mirrorAcrossPoint() {
        let seg = Curve3D.segment(from: SIMD3(1, 0, 0), to: SIMD3(2, 0, 0))!
        let mirrored = seg.mirrored(acrossPoint: .zero)
        #expect(mirrored != nil)
        if let mirrored = mirrored {
            let start = mirrored.startPoint
            let end = mirrored.endPoint
            // Point mirror through the origin negates every coordinate.
            #expect(abs(start.x + 1) < 1e-10)
            #expect(abs(end.x + 2) < 1e-10)
        }
    }

    // #416: mirrored(acrossAxis:direction:) had zero test coverage anywhere in Tests/.
    @Test("Mirror across an axis")
    func mirrorAcrossAxis() {
        let seg = Curve3D.segment(from: SIMD3(1, 1, 0), to: SIMD3(2, 1, 0))!
        let mirrored = seg.mirrored(acrossAxis: .zero, direction: SIMD3(1, 0, 0))
        #expect(mirrored != nil)
        if let mirrored = mirrored {
            let start = mirrored.startPoint
            let end = mirrored.endPoint
            // Mirroring across the X axis negates y (and z) but leaves x unchanged.
            #expect(abs(start.x - 1) < 1e-10)
            #expect(abs(start.y + 1) < 1e-10)
            #expect(abs(end.x - 2) < 1e-10)
            #expect(abs(end.y + 1) < 1e-10)
        }
    }

    @Test("Length of segment")
    func segmentLength() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(3, 4, 0))!
        let len = seg.length
        #expect(len != nil)
        if let l = len {
            #expect(abs(l - 5.0) < 0.01)
        }
    }

    @Test("Length of circle")
    func circleLength() {
        let radius = 5.0
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: radius)!
        let len = circle.length
        #expect(len != nil)
        if let l = len {
            #expect(abs(l - 2 * .pi * radius) < 0.01)
        }
    }

    @Test("Partial length")
    func partialLength() {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let d = seg.domain
        let halfLen = seg.length(from: d.lowerBound, to: (d.lowerBound + d.upperBound) / 2)
        #expect(halfLen != nil)
        if let h = halfLen {
            #expect(abs(h - 5.0) < 0.01)
        }
    }
}
