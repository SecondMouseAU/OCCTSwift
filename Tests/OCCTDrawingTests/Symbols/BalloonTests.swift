import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.150 #87: DrawingAnnotation.balloon

@Suite("v0.150 DrawingAnnotation.balloon")
struct BalloonTests {
    @Test("Balloon with leader emits circle + text + leader line")
    func withLeader() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
            let withBalloon = Drawing.frontView(of: box),
            let baseline = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        withBalloon.append(
            .balloon(
                .init(
                    itemNumber: 1,
                    centre: SIMD2(50, 50),
                    radius: 5,
                    leaderTo: SIMD2(30, 30))))
        let wBalloon = DXFWriter()
        wBalloon.collectFromDrawing(withBalloon)
        let wBase = DXFWriter()
        wBase.collectFromDrawing(baseline)
        // Adds: 1 circle + 1 text + 1 leader line.
        #expect(wBalloon.entityCounts.circles == wBase.entityCounts.circles + 1)
        #expect(wBalloon.entityCounts.texts == wBase.entityCounts.texts + 1)
        #expect(wBalloon.entityCounts.lines == wBase.entityCounts.lines + 1)
    }

    @Test("Balloon without leader emits circle + text only")
    func withoutLeader() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        front.append(
            .balloon(
                .init(
                    itemNumber: 2,
                    centre: SIMD2(10, 10),
                    radius: 4)))
        let writerWith = DXFWriter()
        writerWith.collectFromDrawing(front)

        // Compare against a baseline drawing without the balloon.
        guard let baseline = Drawing.frontView(of: box) else {
            Issue.record("baseline nil")
            return
        }
        let writerBase = DXFWriter()
        writerBase.collectFromDrawing(baseline)

        // Circle adds 1, text adds 1, lines add 0 (no leader).
        #expect(writerWith.entityCounts.circles == writerBase.entityCounts.circles + 1)
        #expect(writerWith.entityCounts.texts == writerBase.entityCounts.texts + 1)
        #expect(writerWith.entityCounts.lines == writerBase.entityCounts.lines)
    }

    @Test("Drawing.addBalloon adds a .balloon annotation")
    func addBalloonConvenience() {
        guard let box = Shape.box(width: 1, height: 1, depth: 1),
            let front = Drawing.frontView(of: box)
        else {
            Issue.record("setup nil")
            return
        }
        front.addBalloon(itemNumber: 3, at: SIMD2(5, 5))
        let balloonCount = front.annotations.filter {
            if case .balloon = $0 { return true } else { return false }
        }.count
        #expect(balloonCount == 1)
    }

    @Test("Balloon transforms translate centre, scale radius, and translate leader")
    func balloonTransformed() {
        let ann = DrawingAnnotation.balloon(
            .init(
                itemNumber: 4,
                centre: SIMD2(10, 10),
                radius: 5,
                leaderTo: SIMD2(20, 20)))
        let t = ann.transformed(translate: SIMD2(100, 200), scale: 2)
        if case .balloon(let b) = t {
            #expect(b.centre == SIMD2(120, 220))
            #expect(b.radius == 10)
            #expect(b.leaderTo == SIMD2(140, 240))
        } else {
            Issue.record("expected .balloon case")
        }
    }
}
