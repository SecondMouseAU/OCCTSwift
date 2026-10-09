import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D Operations Tests")
struct Curve2DOperationsTests {

    @Test("Trim circle to quarter arc")
    func trimCircle() {
        let circle = Curve2D.circle(center: .zero, radius: 5)!
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

    @Test("Offset segment")
    func offsetSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let offset = seg.offset(by: 2.0)
        #expect(offset != nil)
    }

    @Test("Reverse segment swaps endpoints")
    func reverseSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5))!
        let rev = seg.reversed()!
        let revStart = rev.startPoint
        let revEnd = rev.endPoint
        #expect(abs(revStart.x - 10) < 1e-10)
        #expect(abs(revStart.y - 5) < 1e-10)
        #expect(abs(revEnd.x - 0) < 1e-10)
        #expect(abs(revEnd.y - 0) < 1e-10)
    }

    @Test("Translate segment")
    func translateSegment() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0))!
        let moved = seg.translated(by: SIMD2(5, 5))!
        let start = moved.startPoint
        #expect(abs(start.x - 5) < 1e-10)
        #expect(abs(start.y - 5) < 1e-10)
    }

    @Test("Rotate quarter turn")
    func rotateQuarterTurn() {
        let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 0))!
        let rotated = seg.rotated(around: .zero, angle: .pi / 2)!
        let start = rotated.startPoint
        #expect(abs(start.x - 0) < 1e-10)
        #expect(abs(start.y - 1) < 1e-10)
    }

    @Test("Scale by 2x")
    func scaleTwice() {
        let seg = Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(3, 0))!
        let scaled = seg.scaled(from: .zero, factor: 2)!
        let start = scaled.startPoint
        let end = scaled.endPoint
        #expect(abs(start.x - 2) < 1e-10)
        #expect(abs(end.x - 6) < 1e-10)
    }

    @Test("Mirror across X axis")
    func mirrorAcrossXAxis() {
        let seg = Curve2D.segment(from: SIMD2(0, 1), to: SIMD2(10, 1))!
        let mirrored = seg.mirrored(acrossLine: .zero, direction: SIMD2(1, 0))!
        let start = mirrored.startPoint
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Mirror across point")
    func mirrorAcrossPoint() {
        let seg = Curve2D.segment(from: SIMD2(1, 1), to: SIMD2(2, 1))!
        let mirrored = seg.mirrored(acrossPoint: .zero)!
        let start = mirrored.startPoint
        #expect(abs(start.x - (-1)) < 1e-10)
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Circle length approximately 2*pi*r")
    func circleLength() {
        let r = 5.0
        let circle = Curve2D.circle(center: .zero, radius: r)!
        let len = circle.length!
        #expect(abs(len - 2 * .pi * r) < 1e-6)
    }

    @Test("Segment length approximately Euclidean distance")
    func segmentLength() {
        let seg = Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(3, 4))!
        let len = seg.length!
        #expect(abs(len - 5) < 1e-10)
    }
}
