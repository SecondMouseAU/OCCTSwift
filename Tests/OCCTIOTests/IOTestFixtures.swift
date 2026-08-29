// IOTestFixtures.swift
// Shared fixtures for OCCTIOTests.
// No @Suite or @Test: only factory functions.

import Foundation
import OCCTSwift
import Testing
import simd

extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x * x + y * y + z * z)
        guard len > 0 else { return self }
        return SIMD3(x / len, y / len, z / len)
    }
}

/// A deterministically invalid `Shape`: a bowtie (self-intersecting) polygon face.
///
/// Same construction as `BREPTests.writeBREPAllowInvalid`, reused here for the export-guard
/// regression tests added for #1226.
func invalidBowtieShape() -> Shape {
    let bowtie = Wire.polygon(
        [SIMD2(0, 0), SIMD2(1, 1), SIMD2(1, 0), SIMD2(0, 1)], closed: true)!
    return Shape.face(from: bowtie)!
}

// MARK: - #1281: robust-import cancellation fixtures

/// A compound of `count` 10x10x10 boxes laid out in a row along X, `count * 30` apart.
///
/// Reimplemented independently across the robust-import cancellation suites (#300/#302/#525)
/// with only the loop count differing: `MultibodyRobustImportTests.tenBoxes()` (N=10),
/// `CancellationReportingTests.igesRobustTransferPhaseCancellationIsCancelled` (N=50), and
/// `RobustImportProgressTests.igesRobustHealCancellation` (N=400) (#1281).
func boxRow(count: Int) -> Shape? {
    let boxes = (0..<count).compactMap { i in
        Shape.box(width: 10, height: 10, depth: 10)?
            .translated(by: SIMD3(Double(i) * 30, 0, 0))
    }
    guard boxes.count == count else { return nil }
    return Shape.compound(boxes)
}

/// A convex `sides`-sided regular polygon of the given `radius`, extruded `height` along +Z.
///
/// Reimplemented independently across the robust-import cancellation suites (#300/#525):
/// `CancellationReportingTests.prismSTEP(named:)` and
/// `RobustImportProgressTests.stepRobustRepairCancellation` built the byte-identical
/// 1200-sided, r=1000, h=50 prism, differing only in whether the result was written to a named
/// STEP file (#1281).
func ngonPrism(sides: Int, radius: Double, height: Double) -> Shape? {
    let points = (0..<sides).map { i -> SIMD2<Double> in
        let a = 2 * Double.pi * Double(i) / Double(sides)
        return SIMD2(radius * cos(a), radius * sin(a))
    }
    guard let profile = Wire.polygon(points) else { return nil }
    return Shape.extrude(profile: profile, direction: SIMD3(0, 0, 1), length: height)
}

// MARK: - #1282: shared ImportProgress recorder

/// Records every `ImportProgress` callback and lets a test drive `shouldCancel()`'s answer.
///
/// `MeshAndExportProgressTests.Recorder` and `ImportProgressTests.ProgressRecorder` reimplemented
/// this identically under two names, differing only in that `Recorder` exposed just
/// `eventCount: Int`, a strict subset of what this type exposes (`events.count` covers it) (#1282).
final class ProgressRecorder: ImportProgress, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [(fraction: Double, step: String)] = []
    private var _cancel: Bool = false

    var events: [(fraction: Double, step: String)] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func setCancel(_ value: Bool) {
        lock.lock()
        _cancel = value
        lock.unlock()
    }

    func progress(fraction: Double, step: String) {
        lock.lock()
        _events.append((fraction, step))
        lock.unlock()
    }

    func shouldCancel() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _cancel
    }
}

// MARK: - #795: exporter drawing-collection consolidation golden output
//
// PDFExporter.primitiveOps()/collectFromDrawing()/collectProjectedEdges() and
// SVGExporter's own copies scored 1.00 containment against each other (#784 duplication
// rescan); DXFExporter shared collectProjectedEdges too and separately reimplemented
// DrawingDispatch.swift's own formatTolerance/TolerancedLabel byte-for-byte, plus its whole
// dimension + annotation dispatch. These are public export FORMATS -- a byte changed here is a
// consumer-visible break, not a refactor detail (see #795). The golden bytes below were
// captured from the pre-consolidation implementation (one independent copy of the
// collection/dispatch pipeline per writer) and must stay byte-for-byte identical once all
// three route through DrawingDispatch.swift's shared `DrawingPrimitiveSink` protocol.
//
// The fixture drawing exercises every `DrawingAnnotation` case (centreline, centermark,
// textLabel, hatch, cuttingPlaneLine, and two balloons -- one with a leader, one without) and
// every `DrawingTolerance` case on a linear dimension, plus one each of
// radial/diameter/angular/ordinate -- the exact surface formatTolerance/emitAnnotation/
// emitDimension cover. All edges come from a plain box's straight sides, so the fixture's
// geometry is immune to any HLR-deflection nondeterminism a curved edge would introduce.

func makeGolden795Drawing() -> Drawing {
    let box = Shape.box(width: 40, height: 25, depth: 15)!
    let drawing = Drawing.frontView(of: box)!

    drawing.addCentreLine(from: SIMD2(-5, 12.5), to: SIMD2(45, 12.5))
    drawing.addCentermark(centre: SIMD2(20, 12.5), extent: 6)
    drawing.addTextLabel("PART-001", at: SIMD2(0, -10), height: 4, rotation: 0)
    drawing.addHatch(
        boundary: [SIMD2(0, 0), SIMD2(10, 0), SIMD2(10, 10), SIMD2(0, 10)],
        angle: 0, spacing: 5.0)
    _ = drawing.addCuttingPlaneLine(
        label: "A",
        cuttingPlaneOrigin: SIMD3(20, 12.5, 0),
        cuttingPlaneNormal: SIMD3(1, 0, 0),
        sectionViewDirection: SIMD3(0, 1, 0),
        viewDirection: SIMD3(0, 0, 1),
        traceLength: 30)
    drawing.addBalloon(itemNumber: 1, at: SIMD2(45, 20), leaderTo: SIMD2(40, 15))
    drawing.addBalloon(itemNumber: 2, at: SIMD2(-8, 5))

    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -8,
                tolerance: .none)))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -14,
                tolerance: .symmetric(0.05))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -20,
                tolerance: .bilateral(plus: 0.10, minus: 0.05))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -26,
                tolerance: .unilateral(0.10))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -32,
                tolerance: .unilateral(-0.10))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -38,
                tolerance: .fitClass("H7"))))
    drawing.append(
        .linear(
            .init(
                from: SIMD2(0, 0), to: SIMD2(40, 0), offset: -44,
                tolerance: .limits(lower: 19.95, upper: 20.05))))
    drawing.append(
        .radial(
            .init(
                centre: SIMD2(20, 12.5), radius: 8, leaderAngle: .pi / 6,
                tolerance: .symmetric(0.02))))
    drawing.append(
        .diameter(
            .init(
                centre: SIMD2(20, 12.5), radius: 5, leaderAngle: .pi / 3,
                tolerance: .none)))
    drawing.append(
        .angular(
            .init(
                vertex: SIMD2(0, 0), ray1: SIMD2(40, 0), ray2: SIMD2(0, 25),
                arcRadius: 15, tolerance: .bilateral(plus: 0.5, minus: 0.5))))
    drawing.append(
        .ordinate(
            .init(
                origin: SIMD2(0, 0),
                features: [
                    .init(position: SIMD2(40, 0)),
                    .init(position: SIMD2(0, 25)),
                    .init(position: SIMD2(40, 25)),
                ],
                tolerance: .none)))
    return drawing
}

let golden795SVG = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="-20.0000 -49.0000 75.0000 93.5000" width="75.0000mm" height="93.5000mm">
    <g transform="translate(0,44.5000) scale(1,-1)">
    <g id="VISIBLE" stroke="black" stroke-width="0.5000" fill="none">
    <line x1="-7.5000" y1="-20.0000" x2="7.5000" y2="-20.0000"/>
    <line x1="-7.5000" y1="20.0000" x2="7.5000" y2="20.0000"/>
    <line x1="-7.5000" y1="-20.0000" x2="-7.5000" y2="20.0000"/>
    <line x1="7.5000" y1="-20.0000" x2="7.5000" y2="20.0000"/>
    </g>
    <g id="HIDDEN" stroke="black" stroke-width="0.2500" fill="none" stroke-dasharray="3,2">
    <line x1="-7.5000" y1="-20.0000" x2="7.5000" y2="-20.0000"/>
    <line x1="-7.5000" y1="20.0000" x2="7.5000" y2="20.0000"/>
    <line x1="-7.5000" y1="-20.0000" x2="-7.5000" y2="20.0000"/>
    <line x1="7.5000" y1="-20.0000" x2="7.5000" y2="20.0000"/>
    </g>
    <g id="CENTER" stroke="black" stroke-width="0.2500" fill="none" stroke-dasharray="8,2,2,2">
    <line x1="-5.0000" y1="12.5000" x2="45.0000" y2="12.5000"/>
    <line x1="17.0000" y1="12.5000" x2="23.0000" y2="12.5000"/>
    <line x1="20.0000" y1="9.5000" x2="20.0000" y2="15.5000"/>
    <line x1="20.0000" y1="27.5000" x2="20.0000" y2="21.5000"/>
    <line x1="20.0000" y1="3.5000" x2="20.0000" y2="-2.5000"/>
    <line x1="20.0000" y1="21.5000" x2="20.0000" y2="3.5000"/>
    </g>
    <g id="DIMENSION" stroke="black" stroke-width="0.2500" fill="none">
    <line x1="41.4645" y1="16.4645" x2="40.0000" y2="15.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-8.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-8.0000"/>
    <line x1="0.0000" y1="-8.0000" x2="40.0000" y2="-8.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-14.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-14.0000"/>
    <line x1="0.0000" y1="-14.0000" x2="40.0000" y2="-14.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-20.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-20.0000"/>
    <line x1="0.0000" y1="-20.0000" x2="40.0000" y2="-20.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-26.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-26.0000"/>
    <line x1="0.0000" y1="-26.0000" x2="40.0000" y2="-26.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-32.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-32.0000"/>
    <line x1="0.0000" y1="-32.0000" x2="40.0000" y2="-32.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-38.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-38.0000"/>
    <line x1="0.0000" y1="-38.0000" x2="40.0000" y2="-38.0000"/>
    <line x1="0.0000" y1="0.0000" x2="0.0000" y2="-44.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="-44.0000"/>
    <line x1="0.0000" y1="-44.0000" x2="40.0000" y2="-44.0000"/>
    <line x1="26.9282" y1="16.5000" x2="35.5885" y2="21.5000"/>
    <line x1="17.5000" y1="8.1699" x2="22.5000" y2="16.8301"/>
    <line x1="-3.0000" y1="0.0000" x2="3.0000" y2="0.0000"/>
    <line x1="0.0000" y1="-3.0000" x2="0.0000" y2="3.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="0.0000"/>
    <line x1="40.0000" y1="-2.0000" x2="40.0000" y2="2.0000"/>
    <line x1="0.0000" y1="25.0000" x2="0.0000" y2="25.0000"/>
    <line x1="-2.0000" y1="25.0000" x2="2.0000" y2="25.0000"/>
    <line x1="40.0000" y1="0.0000" x2="40.0000" y2="25.0000"/>
    <line x1="40.0000" y1="-2.0000" x2="40.0000" y2="2.0000"/>
    <line x1="0.0000" y1="25.0000" x2="40.0000" y2="25.0000"/>
    <line x1="-2.0000" y1="25.0000" x2="2.0000" y2="25.0000"/>
    <circle cx="45.0000" cy="20.0000" r="5.0000"/>
    <circle cx="-8.0000" cy="5.0000" r="5.0000"/>
    <circle cx="20.0000" cy="12.5000" r="8.0000"/>
    <path d="M 15.0000 0.0000 A 15.0000 15.0000 0 0 1 0.0000 15.0000"/>
    </g>
    <g id="HATCH" stroke="black" stroke-width="0.1800" fill="none">
    <line x1="-0.0000" y1="5.0000" x2="10.0000" y2="5.0000"/>
    <line x1="-0.0000" y1="10.0000" x2="10.0000" y2="10.0000"/>
    </g>
    <g id="TEXT" stroke="black" stroke-width="0.2500" fill="none">
    <line x1="20.0000" y1="27.5000" x2="20.0000" y2="35.5000"/>
    <line x1="20.0000" y1="35.5000" x2="18.5000" y2="32.3000"/>
    <line x1="20.0000" y1="35.5000" x2="21.5000" y2="32.3000"/>
    <line x1="20.0000" y1="-2.5000" x2="20.0000" y2="5.5000"/>
    <line x1="20.0000" y1="5.5000" x2="18.5000" y2="2.3000"/>
    <line x1="20.0000" y1="5.5000" x2="21.5000" y2="2.3000"/>
    <text x="0.0000" y="-10.0000" font-family="Helvetica" font-size="4.0000" transform="matrix(1,0,0,-1,0,0) translate(0.0000,10.0000) rotate(-0.0000) translate(-0.0000,-10.0000)" fill="black" stroke="none">PART-001</text>
    <text x="20.0000" y="39.5000" font-family="Helvetica" font-size="5.0000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,-39.5000) rotate(-0.0000) translate(-20.0000,39.5000)" fill="black" stroke="none">A</text>
    <text x="20.0000" y="9.5000" font-family="Helvetica" font-size="5.0000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,-9.5000) rotate(-0.0000) translate(-20.0000,9.5000)" fill="black" stroke="none">A</text>
    <text x="45.0000" y="20.0000" font-family="Helvetica" font-size="4.5000" transform="matrix(1,0,0,-1,0,0) translate(45.0000,-20.0000) rotate(-0.0000) translate(-45.0000,20.0000)" fill="black" stroke="none">1</text>
    <text x="-8.0000" y="5.0000" font-family="Helvetica" font-size="4.5000" transform="matrix(1,0,0,-1,0,0) translate(-8.0000,-5.0000) rotate(-0.0000) translate(8.0000,5.0000)" fill="black" stroke="none">2</text>
    <text x="20.0000" y="-6.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,6.0000) rotate(-0.0000) translate(-20.0000,-6.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-12.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,12.0000) rotate(-0.0000) translate(-20.0000,-12.0000)" fill="black" stroke="none">40.00 ±0.050</text>
    <text x="20.0000" y="-18.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,18.0000) rotate(-0.0000) translate(-20.0000,-18.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-16.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,16.0000) rotate(-0.0000) translate(-20.0000,-16.0000)" fill="black" stroke="none">+0.100</text>
    <text x="20.0000" y="-20.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,20.0000) rotate(-0.0000) translate(-20.0000,-20.0000)" fill="black" stroke="none">-0.050</text>
    <text x="20.0000" y="-24.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,24.0000) rotate(-0.0000) translate(-20.0000,-24.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-22.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,22.0000) rotate(-0.0000) translate(-20.0000,-22.0000)" fill="black" stroke="none">+0.100</text>
    <text x="20.0000" y="-26.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,26.0000) rotate(-0.0000) translate(-20.0000,-26.0000)" fill="black" stroke="none">0</text>
    <text x="20.0000" y="-30.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,30.0000) rotate(-0.0000) translate(-20.0000,-30.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-28.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,28.0000) rotate(-0.0000) translate(-20.0000,-28.0000)" fill="black" stroke="none">0</text>
    <text x="20.0000" y="-32.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,32.0000) rotate(-0.0000) translate(-20.0000,-32.0000)" fill="black" stroke="none">-0.100</text>
    <text x="20.0000" y="-36.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,36.0000) rotate(-0.0000) translate(-20.0000,-36.0000)" fill="black" stroke="none">40.00 H7</text>
    <text x="20.0000" y="-42.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(20.0000,42.0000) rotate(-0.0000) translate(-20.0000,-42.0000)" fill="black" stroke="none">40.00</text>
    <text x="20.0000" y="-40.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,40.0000) rotate(-0.0000) translate(-20.0000,-40.0000)" fill="black" stroke="none">20.050</text>
    <text x="20.0000" y="-44.0000" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(20.0000,44.0000) rotate(-0.0000) translate(-20.0000,-44.0000)" fill="black" stroke="none">19.950</text>
    <text x="35.5885" y="21.5000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(35.5885,-21.5000) rotate(-0.0000) translate(-35.5885,21.5000)" fill="black" stroke="none">R8.00 ±0.020</text>
    <text x="25.0000" y="21.1603" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(25.0000,-21.1603) rotate(-0.0000) translate(-25.0000,21.1603)" fill="black" stroke="none">⌀10.00</text>
    <text x="12.7279" y="12.7279" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(12.7279,-12.7279) rotate(-0.0000) translate(-12.7279,12.7279)" fill="black" stroke="none">90.0°</text>
    <text x="14.1421" y="14.1421" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(14.1421,-14.1421) rotate(-0.0000) translate(-14.1421,14.1421)" fill="black" stroke="none">+0.500</text>
    <text x="11.3137" y="11.3137" font-family="Helvetica" font-size="1.9250" transform="matrix(1,0,0,-1,0,0) translate(11.3137,-11.3137) rotate(-0.0000) translate(-11.3137,11.3137)" fill="black" stroke="none">-0.500</text>
    <text x="40.0000" y="-5.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(40.0000,5.0000) rotate(-90.0000) translate(-40.0000,-5.0000)" fill="black" stroke="none">40.00</text>
    <text x="-5.0000" y="25.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(-5.0000,-25.0000) rotate(-0.0000) translate(5.0000,25.0000)" fill="black" stroke="none">25.00</text>
    <text x="40.0000" y="-5.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(40.0000,5.0000) rotate(-90.0000) translate(-40.0000,-5.0000)" fill="black" stroke="none">40.00</text>
    <text x="-5.0000" y="25.0000" font-family="Helvetica" font-size="3.5000" transform="matrix(1,0,0,-1,0,0) translate(-5.0000,-25.0000) rotate(-0.0000) translate(5.0000,25.0000)" fill="black" stroke="none">25.00</text>
    </g>
    </g>
    </svg>

    """#
let golden795DXF = #"""
    0
    SECTION
    2
    HEADER
    9
    $ACADVER
    1
    AC1009
    9
    $INSUNITS
    70
    4
    0
    ENDSEC
    0
    SECTION
    2
    TABLES
    0
    TABLE
    2
    LTYPE
    70
    4
    0
    LTYPE
    2
    CONTINUOUS
    70
    0
    3
    Solid line
    72
    65
    73
    0
    40
    0.000000
    0
    LTYPE
    2
    DASHED
    70
    0
    3
    Dashed ____ ____ ____
    72
    65
    73
    2
    40
    7.500000
    49
    5.000000
    49
    -2.500000
    0
    LTYPE
    2
    CHAIN
    70
    0
    3
    Chain ____ _ ____ _
    72
    65
    73
    4
    40
    15.000000
    49
    10.000000
    49
    -2.500000
    49
    0.000000
    49
    -2.500000
    0
    ENDTAB
    0
    TABLE
    2
    LAYER
    70
    11
    0
    LAYER
    2
    0
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    VISIBLE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    HIDDEN
    70
    0
    62
    8
    6
    DASHED
    0
    LAYER
    2
    OUTLINE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    CENTER
    70
    0
    62
    1
    6
    CHAIN
    0
    LAYER
    2
    DIMENSION
    70
    0
    62
    5
    6
    CONTINUOUS
    0
    LAYER
    2
    TEXT
    70
    0
    62
    3
    6
    CONTINUOUS
    0
    LAYER
    2
    HATCH
    70
    0
    62
    9
    6
    CONTINUOUS
    0
    LAYER
    2
    SECTION
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    BORDER
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    LAYER
    2
    TITLE
    70
    0
    62
    7
    6
    CONTINUOUS
    0
    ENDTAB
    0
    TABLE
    2
    STYLE
    70
    1
    0
    STYLE
    2
    STANDARD
    70
    0
    40
    0.000000
    41
    1.000000
    50
    0.000000
    71
    0
    42
    2.500000
    3
    txt
    4

    0
    ENDTAB
    0
    ENDSEC
    0
    SECTION
    2
    BLOCKS
    0
    ENDSEC
    0
    SECTION
    2
    ENTITIES
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    -7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    VISIBLE
    10
    7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    -7.500000
    20
    -20.000000
    30
    0.000000
    11
    -7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    HIDDEN
    10
    7.500000
    20
    -20.000000
    30
    0.000000
    11
    7.500000
    21
    20.000000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    -5.000000
    20
    12.500000
    30
    0.000000
    11
    45.000000
    21
    12.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    17.000000
    20
    12.500000
    30
    0.000000
    11
    23.000000
    21
    12.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    9.500000
    30
    0.000000
    11
    20.000000
    21
    15.500000
    31
    0.000000
    0
    LINE
    8
    HATCH
    10
    -0.000000
    20
    5.000000
    30
    0.000000
    11
    10.000000
    21
    5.000000
    31
    0.000000
    0
    LINE
    8
    HATCH
    10
    -0.000000
    20
    10.000000
    30
    0.000000
    11
    10.000000
    21
    10.000000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    27.500000
    30
    0.000000
    11
    20.000000
    21
    21.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    3.500000
    30
    0.000000
    11
    20.000000
    21
    -2.500000
    31
    0.000000
    0
    LINE
    8
    CENTER
    10
    20.000000
    20
    21.500000
    30
    0.000000
    11
    20.000000
    21
    3.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    27.500000
    30
    0.000000
    11
    20.000000
    21
    35.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    35.500000
    30
    0.000000
    11
    18.500000
    21
    32.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    35.500000
    30
    0.000000
    11
    21.500000
    21
    32.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    -2.500000
    30
    0.000000
    11
    20.000000
    21
    5.500000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    5.500000
    30
    0.000000
    11
    18.500000
    21
    2.300000
    31
    0.000000
    0
    LINE
    8
    TEXT
    10
    20.000000
    20
    5.500000
    30
    0.000000
    11
    21.500000
    21
    2.300000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    41.464466
    20
    16.464466
    30
    0.000000
    11
    40.000000
    21
    15.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -8.000000
    30
    0.000000
    11
    40.000000
    21
    -8.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -14.000000
    30
    0.000000
    11
    40.000000
    21
    -14.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -20.000000
    30
    0.000000
    11
    40.000000
    21
    -20.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -26.000000
    30
    0.000000
    11
    40.000000
    21
    -26.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -32.000000
    30
    0.000000
    11
    40.000000
    21
    -32.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -38.000000
    30
    0.000000
    11
    40.000000
    21
    -38.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    11
    0.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -44.000000
    30
    0.000000
    11
    40.000000
    21
    -44.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    26.928203
    20
    16.500000
    30
    0.000000
    11
    35.588457
    21
    21.500000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    17.500000
    20
    8.169873
    30
    0.000000
    11
    22.500000
    21
    16.830127
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -3.000000
    20
    0.000000
    30
    0.000000
    11
    3.000000
    21
    0.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    -3.000000
    30
    0.000000
    11
    0.000000
    21
    3.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    0.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    -2.000000
    30
    0.000000
    11
    40.000000
    21
    2.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    25.000000
    30
    0.000000
    11
    0.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -2.000000
    20
    25.000000
    30
    0.000000
    11
    2.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    0.000000
    30
    0.000000
    11
    40.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    40.000000
    20
    -2.000000
    30
    0.000000
    11
    40.000000
    21
    2.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    0.000000
    20
    25.000000
    30
    0.000000
    11
    40.000000
    21
    25.000000
    31
    0.000000
    0
    LINE
    8
    DIMENSION
    10
    -2.000000
    20
    25.000000
    30
    0.000000
    11
    2.000000
    21
    25.000000
    31
    0.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    45.000000
    20
    20.000000
    30
    0.000000
    40
    5.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    -8.000000
    20
    5.000000
    30
    0.000000
    40
    5.000000
    0
    CIRCLE
    8
    DIMENSION
    10
    20.000000
    20
    12.500000
    30
    0.000000
    40
    8.000000
    0
    ARC
    8
    DIMENSION
    10
    0.000000
    20
    0.000000
    30
    0.000000
    40
    15.000000
    50
    0.000000
    51
    90.000000
    0
    TEXT
    8
    TEXT
    10
    0.000000
    20
    -10.000000
    30
    0.000000
    40
    4.000000
    1
    PART-001
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    39.500000
    30
    0.000000
    40
    5.000000
    1
    A
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    9.500000
    30
    0.000000
    40
    5.000000
    1
    A
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    45.000000
    20
    20.000000
    30
    0.000000
    40
    4.500000
    1
    1
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    -8.000000
    20
    5.000000
    30
    0.000000
    40
    4.500000
    1
    2
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -6.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -12.000000
    30
    0.000000
    40
    3.500000
    1
    40.00 ±0.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -18.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -16.000000
    30
    0.000000
    40
    1.925000
    1
    +0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -20.000000
    30
    0.000000
    40
    1.925000
    1
    -0.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -24.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -22.000000
    30
    0.000000
    40
    1.925000
    1
    +0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -26.000000
    30
    0.000000
    40
    1.925000
    1
    0
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -30.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -28.000000
    30
    0.000000
    40
    1.925000
    1
    0
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -32.000000
    30
    0.000000
    40
    1.925000
    1
    -0.100
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -36.000000
    30
    0.000000
    40
    3.500000
    1
    40.00 H7
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -42.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -40.000000
    30
    0.000000
    40
    1.925000
    1
    20.050
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    20.000000
    20
    -44.000000
    30
    0.000000
    40
    1.925000
    1
    19.950
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    35.588457
    20
    21.500000
    30
    0.000000
    40
    3.500000
    1
    R8.00 ±0.020
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    25.000000
    20
    21.160254
    30
    0.000000
    40
    3.500000
    1
    ⌀10.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    12.727922
    20
    12.727922
    30
    0.000000
    40
    3.500000
    1
    90.0°
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    14.142136
    20
    14.142136
    30
    0.000000
    40
    1.925000
    1
    +0.500
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    11.313708
    20
    11.313708
    30
    0.000000
    40
    1.925000
    1
    -0.500
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    40.000000
    20
    -5.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    90.000000
    0
    TEXT
    8
    TEXT
    10
    -5.000000
    20
    25.000000
    30
    0.000000
    40
    3.500000
    1
    25.00
    50
    0.000000
    0
    TEXT
    8
    TEXT
    10
    40.000000
    20
    -5.000000
    30
    0.000000
    40
    3.500000
    1
    40.00
    50
    90.000000
    0
    TEXT
    8
    TEXT
    10
    -5.000000
    20
    25.000000
    30
    0.000000
    40
    3.500000
    1
    25.00
    50
    0.000000
    0
    ENDSEC
    0
    EOF

    """#

let golden795PDFBase64 = """
    JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwg
    L1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVu
    dCAyIDAgUiAvTWVkaWFCb3ggWzAgMCA4NDEuMDAwMCA1OTUuMDAwMF0gL0NvbnRlbnRzIDQgMCBSIC9SZXNvdXJjZXMgPDwgL0Zv
    bnQgPDwgL0YxIDUgMCBSID4+ID4+ID4+CmVuZG9iago0IDAgb2JqCjw8IC9MZW5ndGggNTA0NiA+PgpzdHJlYW0KcQoyLjgzNDYg
    MCAwIDIuODM0NiAwIDAgY20KMCAwIDAgUkcKMC41MDAwIHcKW10gMCBkCi03LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgLTIwLjAw
    MDAgbCBTCi03LjUwMDAgMjAuMDAwMCBtIDcuNTAwMCAyMC4wMDAwIGwgUwotNy41MDAwIC0yMC4wMDAwIG0gLTcuNTAwMCAyMC4w
    MDAwIGwgUwo3LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgMjAuMDAwMCBsIFMKMC4yNTAwIHcKWzMgMl0gMCBkCi03LjUwMDAgLTIw
    LjAwMDAgbSA3LjUwMDAgLTIwLjAwMDAgbCBTCi03LjUwMDAgMjAuMDAwMCBtIDcuNTAwMCAyMC4wMDAwIGwgUwotNy41MDAwIC0y
    MC4wMDAwIG0gLTcuNTAwMCAyMC4wMDAwIGwgUwo3LjUwMDAgLTIwLjAwMDAgbSA3LjUwMDAgMjAuMDAwMCBsIFMKMC4yNTAwIHcK
    WzggMiAyIDJdIDAgZAotNS4wMDAwIDEyLjUwMDAgbSA0NS4wMDAwIDEyLjUwMDAgbCBTCjE3LjAwMDAgMTIuNTAwMCBtIDIzLjAw
    MDAgMTIuNTAwMCBsIFMKMjAuMDAwMCA5LjUwMDAgbSAyMC4wMDAwIDE1LjUwMDAgbCBTCjIwLjAwMDAgMjcuNTAwMCBtIDIwLjAw
    MDAgMjEuNTAwMCBsIFMKMjAuMDAwMCAzLjUwMDAgbSAyMC4wMDAwIC0yLjUwMDAgbCBTCjIwLjAwMDAgMjEuNTAwMCBtIDIwLjAw
    MDAgMy41MDAwIGwgUwowLjI1MDAgdwpbXSAwIGQKNDEuNDY0NSAxNi40NjQ1IG0gNDAuMDAwMCAxNS4wMDAwIGwgUwowLjAwMDAg
    MC4wMDAwIG0gMC4wMDAwIC04LjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAtOC4wMDAwIGwgUwowLjAwMDAgLTgu
    MDAwMCBtIDQwLjAwMDAgLTguMDAwMCBsIFMKMC4wMDAwIDAuMDAwMCBtIDAuMDAwMCAtMTQuMDAwMCBsIFMKNDAuMDAwMCAwLjAw
    MDAgbSA0MC4wMDAwIC0xNC4wMDAwIGwgUwowLjAwMDAgLTE0LjAwMDAgbSA0MC4wMDAwIC0xNC4wMDAwIGwgUwowLjAwMDAgMC4w
    MDAwIG0gMC4wMDAwIC0yMC4wMDAwIGwgUwo0MC4wMDAwIDAuMDAwMCBtIDQwLjAwMDAgLTIwLjAwMDAgbCBTCjAuMDAwMCAtMjAu
    MDAwMCBtIDQwLjAwMDAgLTIwLjAwMDAgbCBTCjAuMDAwMCAwLjAwMDAgbSAwLjAwMDAgLTI2LjAwMDAgbCBTCjQwLjAwMDAgMC4w
    MDAwIG0gNDAuMDAwMCAtMjYuMDAwMCBsIFMKMC4wMDAwIC0yNi4wMDAwIG0gNDAuMDAwMCAtMjYuMDAwMCBsIFMKMC4wMDAwIDAu
    MDAwMCBtIDAuMDAwMCAtMzIuMDAwMCBsIFMKNDAuMDAwMCAwLjAwMDAgbSA0MC4wMDAwIC0zMi4wMDAwIGwgUwowLjAwMDAgLTMy
    LjAwMDAgbSA0MC4wMDAwIC0zMi4wMDAwIGwgUwowLjAwMDAgMC4wMDAwIG0gMC4wMDAwIC0zOC4wMDAwIGwgUwo0MC4wMDAwIDAu
    MDAwMCBtIDQwLjAwMDAgLTM4LjAwMDAgbCBTCjAuMDAwMCAtMzguMDAwMCBtIDQwLjAwMDAgLTM4LjAwMDAgbCBTCjAuMDAwMCAw
    LjAwMDAgbSAwLjAwMDAgLTQ0LjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAtNDQuMDAwMCBsIFMKMC4wMDAwIC00
    NC4wMDAwIG0gNDAuMDAwMCAtNDQuMDAwMCBsIFMKMjYuOTI4MiAxNi41MDAwIG0gMzUuNTg4NSAyMS41MDAwIGwgUwoxNy41MDAw
    IDguMTY5OSBtIDIyLjUwMDAgMTYuODMwMSBsIFMKLTMuMDAwMCAwLjAwMDAgbSAzLjAwMDAgMC4wMDAwIGwgUwowLjAwMDAgLTMu
    MDAwMCBtIDAuMDAwMCAzLjAwMDAgbCBTCjQwLjAwMDAgMC4wMDAwIG0gNDAuMDAwMCAwLjAwMDAgbCBTCjQwLjAwMDAgLTIuMDAw
    MCBtIDQwLjAwMDAgMi4wMDAwIGwgUwowLjAwMDAgMjUuMDAwMCBtIDAuMDAwMCAyNS4wMDAwIGwgUwotMi4wMDAwIDI1LjAwMDAg
    bSAyLjAwMDAgMjUuMDAwMCBsIFMKNDAuMDAwMCAwLjAwMDAgbSA0MC4wMDAwIDI1LjAwMDAgbCBTCjQwLjAwMDAgLTIuMDAwMCBt
    IDQwLjAwMDAgMi4wMDAwIGwgUwowLjAwMDAgMjUuMDAwMCBtIDQwLjAwMDAgMjUuMDAwMCBsIFMKLTIuMDAwMCAyNS4wMDAwIG0g
    Mi4wMDAwIDI1LjAwMDAgbCBTCjUwLjAwMDAgMjAuMDAwMCBtCjUwLjAwMDAgMjIuNzYxNCA0Ny43NjE0IDI1LjAwMDAgNDUuMDAw
    MCAyNS4wMDAwIGMKNDIuMjM4NiAyNS4wMDAwIDQwLjAwMDAgMjIuNzYxNCA0MC4wMDAwIDIwLjAwMDAgYwo0MC4wMDAwIDE3LjIz
    ODYgNDIuMjM4NiAxNS4wMDAwIDQ1LjAwMDAgMTUuMDAwMCBjCjQ3Ljc2MTQgMTUuMDAwMCA1MC4wMDAwIDE3LjIzODYgNTAuMDAw
    MCAyMC4wMDAwIGMKaCBTCi0zLjAwMDAgNS4wMDAwIG0KLTMuMDAwMCA3Ljc2MTQgLTUuMjM4NiAxMC4wMDAwIC04LjAwMDAgMTAu
    MDAwMCBjCi0xMC43NjE0IDEwLjAwMDAgLTEzLjAwMDAgNy43NjE0IC0xMy4wMDAwIDUuMDAwMCBjCi0xMy4wMDAwIDIuMjM4NiAt
    MTAuNzYxNCAwLjAwMDAgLTguMDAwMCAwLjAwMDAgYwotNS4yMzg2IDAuMDAwMCAtMy4wMDAwIDIuMjM4NiAtMy4wMDAwIDUuMDAw
    MCBjCmggUwoyOC4wMDAwIDEyLjUwMDAgbQoyOC4wMDAwIDE2LjkxODMgMjQuNDE4MyAyMC41MDAwIDIwLjAwMDAgMjAuNTAwMCBj
    CjE1LjU4MTcgMjAuNTAwMCAxMi4wMDAwIDE2LjkxODMgMTIuMDAwMCAxMi41MDAwIGMKMTIuMDAwMCA4LjA4MTcgMTUuNTgxNyA0
    LjUwMDAgMjAuMDAwMCA0LjUwMDAgYwoyNC40MTgzIDQuNTAwMCAyOC4wMDAwIDguMDgxNyAyOC4wMDAwIDEyLjUwMDAgYwpoIFMK
    MTUuMDAwMCAwLjAwMDAgbQoxNS4wMDAwIDguMjg0MyA4LjI4NDMgMTUuMDAwMCAwLjAwMDAgMTUuMDAwMCBjClMKMC4xODAwIHcK
    W10gMCBkCi0wLjAwMDAgNS4wMDAwIG0gMTAuMDAwMCA1LjAwMDAgbCBTCi0wLjAwMDAgMTAuMDAwMCBtIDEwLjAwMDAgMTAuMDAw
    MCBsIFMKMC4yNTAwIHcKW10gMCBkCkJUCi9GMSA0LjAwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAwLjAwMDAg
    LTEwLjAwMDAgVG0KKFBBUlQtMDAxKSBUagpFVApCVAovRjEgNS4wMDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCAzOS41MDAwIFRtCihBKSBUagpFVApCVAovRjEgNS4wMDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCA5LjUwMDAgVG0KKEEpIFRqCkVUCkJUCi9GMSA0LjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCA0
    NS4wMDAwIDIwLjAwMDAgVG0KKDEpIFRqCkVUCkJUCi9GMSA0LjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAt
    OC4wMDAwIDUuMDAwMCBUbQooMikgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIw
    LjAwMDAgLTYuMDAwMCBUbQooNDAuMDApIFRqCkVUCkJUCi9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAw
    MCAyMC4wMDAwIC0xMi4wMDAwIFRtCig0MC4wMCDCsTAuMDUwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAwMDAg
    LTAuMDAwMCAxLjAwMDAgMjAuMDAwMCAtMTguMDAwMCBUbQooNDAuMDApIFRqCkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4wMDAwIDAu
    MDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0xNi4wMDAwIFRtCigrMC4xMDApIFRqCkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4w
    MDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0yMC4wMDAwIFRtCigtMC4wNTApIFRqCkVUCkJUCi9GMSAzLjUwMDAg
    VGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0yNC4wMDAwIFRtCig0MC4wMCkgVGoKRVQKQlQKL0YxIDEu
    OTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTIyLjAwMDAgVG0KKCswLjEwMCkgVGoKRVQKQlQK
    L0YxIDEuOTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTI2LjAwMDAgVG0KKDApIFRqCkVUCkJU
    Ci9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zMC4wMDAwIFRtCig0MC4wMCkgVGoK
    RVQKQlQKL0YxIDEuOTI1MCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTI4LjAwMDAgVG0KKDApIFRq
    CkVUCkJUCi9GMSAxLjkyNTAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zMi4wMDAwIFRtCigtMC4x
    MDApIFRqCkVUCkJUCi9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAyMC4wMDAwIC0zNi4wMDAwIFRt
    Cig0MC4wMCBINykgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDIwLjAwMDAgLTQy
    LjAwMDAgVG0KKDQwLjAwKSBUagpFVApCVAovRjEgMS45MjUwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAgMjAuMDAw
    MCAtNDAuMDAwMCBUbQooMjAuMDUwKSBUagpFVApCVAovRjEgMS45MjUwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAg
    MjAuMDAwMCAtNDQuMDAwMCBUbQooMTkuOTUwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAx
    LjAwMDAgMzUuNTg4NSAyMS41MDAwIFRtCihSOC4wMCDCsTAuMDIwKSBUagpFVApCVAovRjEgMy41MDAwIFRmCjEuMDAwMCAwLjAw
    MDAgLTAuMDAwMCAxLjAwMDAgMjUuMDAwMCAyMS4xNjAzIFRtCijijIAxMC4wMCkgVGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAw
    MDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIDEyLjcyNzkgMTIuNzI3OSBUbQooOTAuMMKwKSBUagpFVApCVAovRjEgMS45MjUwIFRm
    CjEuMDAwMCAwLjAwMDAgLTAuMDAwMCAxLjAwMDAgMTQuMTQyMSAxNC4xNDIxIFRtCigrMC41MDApIFRqCkVUCkJUCi9GMSAxLjky
    NTAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAxMS4zMTM3IDExLjMxMzcgVG0KKC0wLjUwMCkgVGoKRVQKQlQKL0Yx
    IDMuNTAwMCBUZgowLjAwMDAgMS4wMDAwIC0xLjAwMDAgMC4wMDAwIDQwLjAwMDAgLTUuMDAwMCBUbQooNDAuMDApIFRqCkVUCkJU
    Ci9GMSAzLjUwMDAgVGYKMS4wMDAwIDAuMDAwMCAtMC4wMDAwIDEuMDAwMCAtNS4wMDAwIDI1LjAwMDAgVG0KKDI1LjAwKSBUagpF
    VApCVAovRjEgMy41MDAwIFRmCjAuMDAwMCAxLjAwMDAgLTEuMDAwMCAwLjAwMDAgNDAuMDAwMCAtNS4wMDAwIFRtCig0MC4wMCkg
    VGoKRVQKQlQKL0YxIDMuNTAwMCBUZgoxLjAwMDAgMC4wMDAwIC0wLjAwMDAgMS4wMDAwIC01LjAwMDAgMjUuMDAwMCBUbQooMjUu
    MDApIFRqCkVUClEKCmVuZHN0cmVhbQplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAvRm9udCAvU3VidHlwZSAvVHlwZTEgL0Jhc2VG
    b250IC9IZWx2ZXRpY2EgL0VuY29kaW5nIC9XaW5BbnNpRW5jb2RpbmcgPj4KZW5kb2JqCnhyZWYKMCA2CjAwMDAwMDAwMDAgNjU1
    MzUgZiAKMDAwMDAwMDAxNSAwMDAwMCBuIAowMDAwMDAwMDY0IDAwMDAwIG4gCjAwMDAwMDAxMjEgMDAwMDAgbiAKMDAwMDAwMDI1
    NyAwMDAwMCBuIAowMDAwMDA1MzU1IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNiAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYK
    NTQ1MgolJUVPRgo=
    """
