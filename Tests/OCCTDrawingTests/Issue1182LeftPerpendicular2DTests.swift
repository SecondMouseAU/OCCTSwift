import Foundation
import Testing
import simd

@testable import OCCTSwift

// #1182 (Pass 4b duplication audit, #386): the 2D left-perpendicular idiom `SIMD2(-d.y, d.x)`
// (equivalently, in trig form, `SIMD2(-sin(θ), cos(θ))` for a unit direction `(cos(θ), sin(θ))`)
// was independently hand-derived at six sites in this module's drawing/annotation layer, with no
// shared helper: `DrawingDispatch.swift`'s `emitLinear`/`emitRadial`/`emitDiameter`,
// `DrawingSymbols.swift`'s `breakLine`, `DrawingThreadAnnotation.swift`'s
// `cosmeticThreadSideView`, and `DrawingStyle.swift`'s `arrowheadBasePoints` (itself already the
// shared home for two more sites, `emitCuttingPlaneLine` and `datumFeature`, since #1173).
//
// No sign flip today, all six computed the mathematically identical rotation. The risk was that a
// future edit to any ONE of the six could silently pick the opposite sign, with nothing marking
// them as copies of each other to prompt a reviewer to check the rest — and the auditor's own scan
// already missed two of the seven originally-cited sites (`emitRadial`/`emitDiameter`) because they
// spell the identity in trig form rather than as `SIMD2(-x.y, x.x)` on a named vector.
//
// Fixed by extracting `leftPerpendicular2D(of:)` (`DrawingStyle.swift`) and routing all six sites
// (plus `arrowheadBasePoints`, so no inline duplicate is left anywhere) through it.
//
// No existing test asserted the actual numeric sign/direction of any of these computations before
// this file (per the issue's own audit of `DrawingSymbolsTests.breakLine`/`.datumFeature`,
// `CosmeticThreadTests.sideViewProducesTwoLines`, and `ToleranceTests`, all of which only assert
// counts). Every expected value below is hand-derived independently of the implementation.
@Suite("#1182: 2D left-perpendicular shared helper")
struct Issue1182LeftPerpendicular2DTests {

    // MARK: - Direct probe of the shared helper

    @Test("leftPerpendicular2D rotates 90 degrees counter-clockwise for the four axis directions")
    func rotatesCCWForAxisDirections() {
        #expect(leftPerpendicular2D(of: SIMD2(1, 0)) == SIMD2(0, 1))
        #expect(leftPerpendicular2D(of: SIMD2(0, 1)) == SIMD2(-1, 0))
        #expect(leftPerpendicular2D(of: SIMD2(-1, 0)) == SIMD2(0, -1))
        #expect(leftPerpendicular2D(of: SIMD2(0, -1)) == SIMD2(1, 0))
    }

    @Test(
        "leftPerpendicular2D of a named-vector direction matches the independent trig-form identity"
    )
    func matchesTrigFormIdentity() {
        // The two spellings this codebase used (`SIMD2(-d.y, d.x)` on a named vector vs.
        // `SIMD2(-sin(θ), cos(θ))` in trig form) must agree for every angle, not just the four
        // axis-aligned cases above -- this is exactly the equivalence that let emitRadial/
        // emitDiameter's trig-spelled duplicates hide from a grep for the named-vector form.
        for degreesStep in stride(from: 0.0, to: 360.0, by: 37.0) {
            let theta = degreesStep * Double.pi / 180
            let namedForm = leftPerpendicular2D(of: SIMD2(cos(theta), sin(theta)))
            let trigForm = SIMD2(-sin(theta), cos(theta))
            #expect(abs(namedForm.x - trigForm.x) < 1e-12)
            #expect(abs(namedForm.y - trigForm.y) < 1e-12)
        }
    }

    // MARK: - breakLine: the sign is load-bearing (kink direction)

    @Test("breakLine's zigzag kinks toward +perp first, then -perp, for a left-to-right segment")
    func breakLineKinksInTheCorrectDirection() {
        let anns = DrawingAnnotation.breakLine(
            from: SIMD2(0, 0), to: SIMD2(10, 0), amplitude: 2.0)
        let lines: [DrawingAnnotation.Centreline] = anns.compactMap {
            if case .centreline(let c) = $0 { return c }
            return nil
        }
        #expect(lines.count == 5)
        guard lines.count == 5 else { return }
        // dir == (1, 0), so perp == leftPerpendicular2D(of: (1,0)) == (0, 1): the first kink (p2)
        // should jut toward +Y, the second (p3) toward -Y. A sign-flipped perp would swap these.
        #expect(abs(lines[1].to.x - 4.0) < 1e-9)
        #expect(abs(lines[1].to.y - 2.0) < 1e-9)
        #expect(abs(lines[2].to.x - 6.0) < 1e-9)
        #expect(abs(lines[2].to.y - (-2.0)) < 1e-9)
    }

    // MARK: - cosmeticThreadSideView: sign decides which line carries which id

    @Test("cosmeticThreadSideView's top line sits on the +perp side of the axis")
    func cosmeticThreadSideViewTopLineOnPositiveSide() {
        let anns = DrawingAnnotation.cosmeticThreadSideView(
            axisStart: SIMD2(0, 0), axisEnd: SIMD2(10, 0),
            majorDiameter: 10, pitch: 1.5)
        let lines: [DrawingAnnotation.Centreline] = anns.compactMap {
            if case .centreline(let c) = $0 { return c }
            return nil
        }
        guard let top = lines.first(where: { $0.id == "cosmetic-thread-top" }),
            let bottom = lines.first(where: { $0.id == "cosmetic-thread-bottom" })
        else {
            Issue.record("expected both cosmetic-thread-top and cosmetic-thread-bottom")
            return
        }
        // dir == (1, 0), so perp == (0, 1): "top" (positive perp) must be at +Y, "bottom" at -Y.
        let halfMinor = DrawingAnnotation.minorDiameter(majorDiameter: 10, pitch: 1.5) / 2
        #expect(abs(top.from.y - halfMinor) < 1e-9)
        #expect(abs(bottom.from.y - (-halfMinor)) < 1e-9)
    }

    // MARK: - Toleranced dimension text stacking: the sign decides upper-vs-lower

    /// Reaches `emitLinear`/`emitDimension` directly (both `internal`/`private func`, visible
    /// through `@testable import`) with a recording `DrawingPrimitiveOps`, rather than going
    /// through a `DXFWriter` and parsing formatted output -- a direct, exact probe of the
    /// `stackOffset` sign `emitTolerancedText` applies.
    @Test("emitLinear stacks the upper tolerance value toward +perp, lower toward -perp")
    func emitLinearStacksToleranceInTheCorrectDirection() {
        let sink = RecordingPrimitiveSink()
        emitDimension(
            .linear(
                .init(
                    from: SIMD2(0, 0), to: SIMD2(10, 0), offset: 10,
                    tolerance: .bilateral(plus: 0.1, minus: 0.05))),
            into: sink.ops())
        // dir == (1, 0), perp == (0, 1): from2/to2 sit at y=10, text mid at y=12, stackOffset (0,2).
        #expect(sink.texts.count == 3)
        guard sink.texts.count == 3 else { return }
        #expect(sink.texts[0].text == "10.00")
        #expect(pointsEqual(sink.texts[0].position, SIMD2(5, 12)))
        #expect(sink.texts[1].text == "+0.100")
        #expect(pointsEqual(sink.texts[1].position, SIMD2(5, 14)))
        #expect(sink.texts[2].text == "-0.050")
        #expect(pointsEqual(sink.texts[2].position, SIMD2(5, 10)))
    }

    @Test("emitRadial stacks the upper tolerance value toward +perp, lower toward -perp")
    func emitRadialStacksToleranceInTheCorrectDirection() {
        let sink = RecordingPrimitiveSink()
        emitDimension(
            .radial(
                .init(
                    centre: SIMD2(0, 0), radius: 5, leaderAngle: 0,
                    tolerance: .bilateral(plus: 0.1, minus: 0.05))),
            into: sink.ops())
        // leaderAngle == 0, so direction == (1, 0), perp == (0, 1), leaderTip == (15, 0).
        #expect(sink.texts.count == 3)
        guard sink.texts.count == 3 else { return }
        #expect(sink.texts[0].text == "R5.00")
        #expect(pointsEqual(sink.texts[0].position, SIMD2(15, 0)))
        #expect(sink.texts[1].text == "+0.100")
        #expect(pointsEqual(sink.texts[1].position, SIMD2(15, 2)))
        #expect(sink.texts[2].text == "-0.050")
        #expect(pointsEqual(sink.texts[2].position, SIMD2(15, -2)))
    }

    @Test("emitDiameter stacks the upper tolerance value toward +perp, lower toward -perp")
    func emitDiameterStacksToleranceInTheCorrectDirection() {
        let sink = RecordingPrimitiveSink()
        emitDimension(
            .diameter(
                .init(
                    centre: SIMD2(0, 0), radius: 5, leaderAngle: 0,
                    tolerance: .bilateral(plus: 0.1, minus: 0.05))),
            into: sink.ops())
        // leaderAngle == 0, so (cos, sin) == (1, 0), perp == (0, 1), tip == (10, 0).
        #expect(sink.texts.count == 3)
        guard sink.texts.count == 3 else { return }
        #expect(sink.texts[0].text == "⌀10.00")
        #expect(pointsEqual(sink.texts[0].position, SIMD2(10, 0)))
        #expect(sink.texts[1].text == "+0.100")
        #expect(pointsEqual(sink.texts[1].position, SIMD2(10, 2)))
        #expect(sink.texts[2].text == "-0.050")
        #expect(pointsEqual(sink.texts[2].position, SIMD2(10, -2)))
    }
}

private func pointsEqual(_ a: SIMD2<Double>, _ b: SIMD2<Double>, tolerance: Double = 1e-9) -> Bool {
    abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
}

/// A `DrawingPrimitiveOps` backing store that records every `addText` call, so a test can assert
/// the exact positions `emitDimension`/`emitTolerancedText` compute without going through a
/// writer's formatted output.
private final class RecordingPrimitiveSink {
    struct TextCall {
        let text: String
        let position: SIMD2<Double>
    }
    private(set) var texts: [TextCall] = []

    func ops() -> DrawingPrimitiveOps {
        DrawingPrimitiveOps(
            addLine: { _, _, _ in },
            addPolyline: { _, _, _ in },
            addCircle: { _, _, _ in },
            addArc: { _, _, _, _, _ in },
            addText: { [self] text, position, _, _, _ in
                texts.append(TextCall(text: text, position: position))
            })
    }
}
