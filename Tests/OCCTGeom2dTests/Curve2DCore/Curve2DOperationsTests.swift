import Foundation
import Testing

@testable import OCCTSwift

@Suite("Curve2D Operations Tests")
struct Curve2DOperationsTests {

    @Test("Trim circle to quarter arc")
    func trimCircle() throws {
        let circle = try #require(Curve2D.circle(center: .zero, radius: 5))
        do {
            let arc = try #require(circle.trimmed(from: 0, to: .pi / 2))
            #expect(!arc.isClosed)
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 5) < 1e-10)
            #expect(abs(end.y - 5) < 1e-10)
        }
    }

    @Test("Offset segment")
    func offsetSegment() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        // #1979: `!= nil` passed an offset to either side or of any size. Geom2d_OffsetCurve puts
        // +2 on the right of +x: the segment (0, -2)-(10, -2)
        // (Scripts/repro/766-geom2d-localprops-operations/).
        let offset = try #require(seg.offset(by: 2.0))
        #expect(vectorDistance(offset.startPoint, SIMD2(0, -2)) < 1e-9)
        #expect(vectorDistance(offset.endPoint, SIMD2(10, -2)) < 1e-9)
    }

    @Test("Reverse segment swaps endpoints")
    func reverseSegment() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 5)))
        let rev = try #require(seg.reversed())
        let revStart = rev.startPoint
        let revEnd = rev.endPoint
        #expect(abs(revStart.x - 10) < 1e-10)
        #expect(abs(revStart.y - 5) < 1e-10)
        #expect(abs(revEnd.x - 0) < 1e-10)
        #expect(abs(revEnd.y - 0) < 1e-10)
    }

    @Test("Translate segment")
    func translateSegment() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(10, 0)))
        let moved = try #require(seg.translated(by: SIMD2(5, 5)))
        let start = moved.startPoint
        #expect(abs(start.x - 5) < 1e-10)
        #expect(abs(start.y - 5) < 1e-10)
    }

    @Test("Rotate quarter turn")
    func rotateQuarterTurn() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(2, 0)))
        let rotated = try #require(seg.rotated(around: .zero, angle: .pi / 2))
        let start = rotated.startPoint
        #expect(abs(start.x - 0) < 1e-10)
        #expect(abs(start.y - 1) < 1e-10)
    }

    @Test("Scale by 2x")
    func scaleTwice() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(1, 0), to: SIMD2(3, 0)))
        let scaled = try #require(seg.scaled(from: .zero, factor: 2))
        let start = scaled.startPoint
        let end = scaled.endPoint
        #expect(abs(start.x - 2) < 1e-10)
        #expect(abs(end.x - 6) < 1e-10)
    }

    @Test("Mirror across X axis")
    func mirrorAcrossXAxis() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 1), to: SIMD2(10, 1)))
        let mirrored = try #require(seg.mirrored(acrossLine: .zero, direction: SIMD2(1, 0)))
        let start = mirrored.startPoint
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Mirror across point")
    func mirrorAcrossPoint() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(1, 1), to: SIMD2(2, 1)))
        let mirrored = try #require(seg.mirrored(acrossPoint: .zero))
        let start = mirrored.startPoint
        #expect(abs(start.x - (-1)) < 1e-10)
        #expect(abs(start.y - (-1)) < 1e-10)
    }

    @Test("Circle length approximately 2*pi*r")
    func circleLength() throws {
        let r = 5.0
        let circle = try #require(Curve2D.circle(center: .zero, radius: r))
        let len = try #require(circle.length)
        #expect(abs(len - 2 * .pi * r) < 1e-6)
    }

    @Test("Segment length approximately Euclidean distance")
    func segmentLength() throws {
        let seg = try #require(Curve2D.segment(from: SIMD2(0, 0), to: SIMD2(3, 4)))
        let len = try #require(seg.length)
        #expect(abs(len - 5) < 1e-10)
    }
}
