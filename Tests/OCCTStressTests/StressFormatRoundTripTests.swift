// StressFormatRoundTripTests.swift
// Category 5: Shape × Format round-trip matrix with tolerance verification.

import Foundation
import OCCTSwift
import Testing

// MARK: - STEP Round-Trip

@Suite("Stress: Round-Trip STEP")
struct StressRoundTripSTEPTests {

    private func roundTrip(_ shape: Shape, name: String) throws {
        let origVol = shape.volume ?? 0
        let origArea = shape.surfaceArea ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)

        let url = tempURL("step")
        defer { cleanupTemp(url) }
        try Exporter.writeSTEP(shape: shape, to: url, modelType: .asIs)
        let reimported = try Shape.load(from: url)
        #expect(reimported.isValid, "STEP round-trip failed for \(name)")

        if origVol > 0, let rVol = reimported.volume {
            #expect(
                abs(rVol - origVol) / origVol < 0.01,
                "Volume mismatch for \(name): \(rVol) vs \(origVol)")
        }
        if origArea > 0, let rArea = reimported.surfaceArea {
            #expect(abs(rArea - origArea) / origArea < 0.01, "Area mismatch for \(name)")
        }
        // STEP may merge/split edges during serialization, check faces match, edges approximate
        #expect(
            reimported.subShapeCount(ofType: .face) == origFaces, "Face count mismatch for \(name)")
        let reimEdges = reimported.subShapeCount(ofType: .edge)
        #expect(
            abs(reimEdges - origEdges) <= max(4, origEdges / 5),
            "Edge count too different for \(name): \(reimEdges) vs \(origEdges)")
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone") }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus") }
    @Test func filletedBoxShape() throws { try roundTrip(filletedBox(), name: "filletedBox") }
    @Test func drilledPlateShape() throws {
        try roundTrip(drilledPlate(), name: "drilledPlate")
    }
    @Test func compound() throws { try roundTrip(standardCompound(), name: "compound") }
}

// MARK: - BREP Round-Trip

@Suite("Stress: Round-Trip BREP")
struct StressRoundTripBREPTests {

    private func roundTrip(_ shape: Shape, name: String) throws {
        let origVol = shape.volume ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)
        let origEdges = shape.subShapeCount(ofType: .edge)

        let url = tempURL("brep")
        defer { cleanupTemp(url) }
        try Exporter.writeBREP(shape: shape, to: url)
        let reimported = try Shape.loadBREP(from: url)
        #expect(reimported.isValid, "BREP round-trip failed for \(name)")

        if origVol > 0, let rVol = reimported.volume {
            #expect(abs(rVol - origVol) / origVol < 0.001, "Volume mismatch for \(name)")
        }
        #expect(reimported.subShapeCount(ofType: .face) == origFaces)
        #expect(reimported.subShapeCount(ofType: .edge) == origEdges)
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone") }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus") }
    @Test func filletedBoxShape() throws { try roundTrip(filletedBox(), name: "filletedBox") }
    @Test func drilledPlateShape() throws {
        try roundTrip(drilledPlate(), name: "drilledPlate")
    }
    @Test func compound() throws { try roundTrip(standardCompound(), name: "compound") }
}

// MARK: - BREP String Round-Trip

/// What each standard fixture is.
///
/// A round trip is compared with the fixture's own closed-form
/// figures and not only with what the same shape reported before it was written. #2983: the old
/// check compared the restored shape with the original within 1e-3 relative, which a restore that
/// scaled by 1.0005 passed, and `origVol > 0, let rVol` skipped the comparison for a shape with no
/// volume or one whose volume came back nil. The figures are closed form (box 10^3, cylinder
/// r = 5 h = 10, sphere r = 5, cone r = 5 -> 2 h = 10, torus R = 10 r = 3, the r = 1 rounded box, the
/// 50 x 50 x 5 plate with an r = 3 hole, the box fused with the cylinder, a ruled loft r = 5 -> 3 over
/// h = 10) except the edge counts, which are the kernel's (measured on the pinned kernel).
private struct FixtureFigures {
    let volume: Double?
    let area: Double
    let faces: Int
    let edges: Int
    let type: ShapeType
}

private let fixtureFigures: [String: FixtureFigures] = [
    "box": .init(volume: 1000, area: 600, faces: 6, edges: 12, type: .solid),
    "cylinder": .init(volume: 250 * .pi, area: 150 * .pi, faces: 3, edges: 3, type: .solid),
    "sphere": .init(volume: 500.0 / 3.0 * .pi, area: 100 * .pi, faces: 1, edges: 3, type: .solid),
    // pi h / 3 (R^2 + R r + r^2) = 130 pi; area pi R^2 + pi r^2 + pi (R + r) slant, slant = sqrt(109).
    "cone": .init(
        volume: 130 * .pi, area: .pi * (29 + 7 * 109.0.squareRoot()), faces: 3, edges: 3,
        type: .solid),
    // V = 2 pi^2 R r^2, A = 4 pi^2 R r.
    "torus": .init(
        volume: 180 * .pi * .pi, area: 120 * .pi * .pi, faces: 1, edges: 2, type: .solid),
    // (a - 2r)^3 + 6 (a - 2r)^2 r + 3 pi r^2 (a - 2r) + 4/3 pi r^3 and 6 (a - 2r)^2 +
    // 12 (pi/2) r (a - 2r) + 4 pi r^2, at a = 10, r = 1. The result is a compound on this kernel.
    "filletedBox": .init(
        volume: 896 + 24 * .pi + 4.0 / 3.0 * .pi, area: 384 + 48 * .pi + 4 * .pi, faces: 26,
        edges: 56, type: .compound),
    // 12500 - pi 9 5, and 2 * 2500 + 4 * 250 + 2 pi 3 5 - 2 pi 9.
    "drilledPlate": .init(
        volume: 12500 - 45 * .pi, area: 6000 + 30 * .pi - 18 * .pi, faces: 7, edges: 15,
        type: .compound),
    // The cylinder (z from 0 to 10) is inside the box (z from -5 to 5) for its lower half:
    // 1000 + 250 pi - 125 pi, and 600 - 25 pi + 50 pi + 25 pi.
    "compound": .init(
        volume: 1000 + 125 * .pi, area: 600 + 50 * .pi, faces: 11, edges: 26, type: .compound),
    // Five of the box's six faces: no volume by design (#605/#609).
    "openShell": .init(volume: nil, area: 500, faces: 5, edges: 12, type: .shell),
    // pi h / 3 (R^2 + R r + r^2) = 490 pi / 3; A = pi R^2 + pi r^2 + pi (R + r) sqrt(h^2 + (R - r)^2).
    "loftedSolid": .init(
        volume: 490 * .pi / 3, area: .pi * (34 + 8 * 104.0.squareRoot()), faces: 3, edges: 3,
        type: .solid),
]

/// Pin a fixture and its restored copy against the fixture's closed-form figures.
///
/// Both halves matter: the original has to be what the table says (or the comparison is between
/// two copies of the same wrong shape), and the restored one has to match the original to rounding.
private func expectFigures(
    _ shape: Shape, restored: Shape, name: String, volumeTolerance: Double = 1e-9
) throws {
    let expected = try #require(fixtureFigures[name], "no figures for fixture \(name)")
    for (label, s) in [("original", shape), ("restored", restored)] {
        #expect(s.isValid, "\(label) \(name) not valid")
        #expect(s.shapeType == expected.type, "\(label) \(name) type \(s.shapeType)")
        #expect(s.subShapeCount(ofType: .face) == expected.faces, "\(label) \(name) faces")
        #expect(s.subShapeCount(ofType: .edge) == expected.edges, "\(label) \(name) edges")
        if let volume = expected.volume {
            let measured = s.volume ?? .nan
            #expect(
                abs(measured - volume) <= volumeTolerance * volume,
                "\(label) \(name) volume \(measured), expected \(volume)")
        } else {
            #expect(s.volume == nil, "\(label) \(name) must report no volume")
        }
        let area = s.surfaceArea ?? .nan
        #expect(
            abs(area - expected.area) <= volumeTolerance * expected.area,
            "\(label) \(name) area \(area), expected \(expected.area)")
    }
    // Where it is: the figures above are translation-invariant, so a restore that moved the shape
    // passes all of them. BREP text carries full-precision coordinates, so the boxes agree to
    // rounding (the 1e-9 is above the measured difference, which is below 1e-12).
    let before = try #require(shape.bounds, "original \(name) has no bounds")
    let after = try #require(restored.bounds, "restored \(name) has no bounds")
    let dMin = before.min - after.min
    let dMax = before.max - after.max
    #expect((dMin * dMin).sum() < 1e-18, "\(name) min corner moved: \(before.min) -> \(after.min)")
    #expect((dMax * dMax).sum() < 1e-18, "\(name) max corner moved: \(before.max) -> \(after.max)")
}

@Suite("Stress: Round-Trip BREP String")
struct StressRoundTripBREPStringTests {

    private func roundTrip(_ shape: Shape, name: String) throws {
        let brepStr = try #require(shape.toBREPString(), "toBREPString failed for \(name)")
        #expect(!brepStr.isEmpty)
        let restored = try #require(
            Shape.fromBREPString(brepStr), "fromBREPString failed for \(name)")
        try expectFigures(shape, restored: restored, name: name)
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone") }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus") }
    @Test func filletedBoxShape() throws { try roundTrip(try filletedBox(), name: "filletedBox") }
    @Test func drilledPlateShape() throws {
        try roundTrip(try drilledPlate(), name: "drilledPlate")
    }
    @Test func compound() throws { try roundTrip(try standardCompound(), name: "compound") }

    /// A different fixture is a different string.
    ///
    /// Without this, a `toBREPString` that always wrote the first shape it was given would fail
    /// only through the other fixtures' figures, never by saying that the strings coincide.
    @Test func distinctShapesWriteDistinctStrings() throws {
        let fixtures: [(String, Shape)] = [
            ("box", try standardBox()), ("cylinder", try standardCylinder()),
            ("sphere", try standardSphere()), ("cone", try standardCone()),
            ("torus", try standardTorus()), ("filletedBox", try filletedBox()),
            ("drilledPlate", try drilledPlate()), ("compound", try standardCompound()),
        ]
        var strings: [String] = []
        for (name, shape) in fixtures {
            strings.append(try #require(shape.toBREPString(), "toBREPString failed for \(name)"))
        }
        #expect(Set(strings).count == fixtures.count, "two fixtures wrote the same BREP string")
        // The box and the cylinder also differ in length, so equal strings cannot hide behind a
        // set that happened to collapse for another reason.
        #expect(strings[0].count != strings[1].count)
    }
}

// MARK: - STL Round-Trip

@Suite("Stress: Round-Trip STL")
struct StressRoundTripSTLTests {

    private func roundTrip(_ shape: Shape, name: String) throws {
        let url = tempURL("stl")
        defer { cleanupTemp(url) }
        try Exporter.writeSTL(shape: shape, to: url)
        let reimported = try Shape.loadSTL(from: url)
        #expect(reimported.isValid, "STL round-trip failed for \(name)")
        // STL loses topology, just verify bounding box roughly matches
        let origBounds = try #require(shape.bounds)
        let reimBounds = try #require(reimported.bounds)
        let origSize = origBounds.max - origBounds.min
        let reimSize = reimBounds.max - reimBounds.min
        // Size should be within 10% (STL mesh approximation)
        if origSize.x > 0.1 {
            #expect(
                abs(reimSize.x - origSize.x) / origSize.x < 0.2, "STL X size mismatch for \(name)")
        }
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone") }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus") }
    @Test func filletedBoxShape() throws { try roundTrip(filletedBox(), name: "filletedBox") }
}

// MARK: - OBJ Round-Trip

@Suite("Stress: Round-Trip OBJ")
struct StressRoundTripOBJTests {

    private func roundTrip(_ shape: Shape, name: String, expectedSize: SIMD3<Double>) throws {
        let url = tempURL("obj")
        defer { cleanupTemp(url) }
        try Exporter.writeOBJ(shape: shape, to: url)
        // OBJ is mesh-based, reimported shape is a triangulation, not B-rep
        // Just verify export + reimport completes without crash
        let reimported = try Shape.loadOBJ(from: url)
        // Epic #766: the reimported shape was discarded, so only a throw could fail this.
        // RWObj_CafReader returns the whole mesh as one triangulated face, and its triangulated
        // bounds are the exported mesh's (Scripts/repro/766-stress-format-round-trip/).
        #expect(reimported.subShapeCount(ofType: .face) == 1, "OBJ face count for \(name)")
        let b = try #require(reimported.bounds)
        let size = b.max - b.min
        #expect(abs(size.x - expectedSize.x) < 1e-4, "OBJ X size for \(name)")
        #expect(abs(size.y - expectedSize.y) < 1e-4, "OBJ Y size for \(name)")
        #expect(abs(size.z - expectedSize.z) < 1e-4, "OBJ Z size for \(name)")
    }

    @Test func box() throws {
        try roundTrip(standardBox(), name: "box", expectedSize: SIMD3(10, 10, 10))
    }
    @Test func cylinder() throws {
        try roundTrip(standardCylinder(), name: "cylinder", expectedSize: SIMD3(10, 9.92709, 10))
    }
    @Test func sphere() throws {
        try roundTrip(standardSphere(), name: "sphere", expectedSize: SIMD3(9.91697, 9.97669, 10))
    }
    @Test func filletedBoxShape() throws {
        try roundTrip(filletedBox(), name: "filletedBox", expectedSize: SIMD3(10, 10, 10))
    }
}

// MARK: - IGES Round-Trip

// Epic #766: this suite was `.disabled("IGES export/import segfaults on certain shapes, OCCT kernel
// bug")`, so none of its five tests ran. Against the pinned OCCT 8.0.1 kernel it does not segfault:
// it was re-enabled and run 20 times in a row clean, and the IGES round trip of the same five
// fixtures runs clean in Scripts/repro/766-stress-format-round-trip/probe.mm. The old body only
// checked `isValid` plus a volume that IGES never yields (it imports faces, not solids), so it now
// pins what IGESControl_Reader::OneShape gives back instead: every face, and no solid.
@Suite("Stress: Round-Trip IGES")
struct StressRoundTripIGESTests {

    private func roundTrip(_ shape: Shape, name: String, faces: Int) throws {
        let url = tempURL("iges")
        defer { cleanupTemp(url) }
        try Exporter.writeIGES(shape: shape, to: url)
        let reimported = try Shape.loadIGES(from: url)
        #expect(reimported.isValid, "IGES round-trip failed for \(name)")
        #expect(reimported.subShapeCount(ofType: .face) == faces, "IGES face count for \(name)")
        #expect(reimported.solidCount == 0, "IGES imports faces, not solids (\(name))")
        #expect(reimported.volume == nil, "unsewn faces enclose no volume (\(name))")
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box", faces: 6) }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder", faces: 3) }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere", faces: 1) }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone", faces: 3) }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus", faces: 1) }
}

// MARK: - Cross-Format Consistency

@Suite("Stress: Cross-Format Consistency")
struct StressCrossFormatConsistencyTests {

    @Test func boxAllBRepFormats() throws {
        let box = try standardBox()
        let origVol = box.volume ?? 0

        // STEP
        let stepURL = tempURL("step")
        defer { cleanupTemp(stepURL) }
        try Exporter.writeSTEP(shape: box, to: stepURL, modelType: .asIs)
        let fromSTEP = try Shape.load(from: stepURL)

        // BREP
        let brepURL = tempURL("brep")
        defer { cleanupTemp(brepURL) }
        try Exporter.writeBREP(shape: box, to: brepURL)
        let fromBREP = try Shape.loadBREP(from: brepURL)

        // IGES
        let igesURL = tempURL("iges")
        defer { cleanupTemp(igesURL) }
        try Exporter.writeIGES(shape: box, to: igesURL)
        let fromIGES = try Shape.loadIGES(from: igesURL)

        // All three should agree on volume. IGES has no solid concept, so its import comes back as
        // a compound of six loose faces with no shell at all: sewing is what turns those into a
        // closed volume. Before #609 it answered 3000 anyway, because the divergence integral runs
        // over whatever faces it is given and happens to be right when they form a consistently
        // oriented closed surface. That was luck, not a measurement, so the sew is now explicit.
        #expect(fromIGES.solidCount == 0, "IGES imports faces, not solids")
        #expect(fromIGES.volume == nil, "unsewn faces are not a closed shell")
        let sewnIGES = try #require(
            Shape.sew(shapes: fromIGES.faces().compactMap { Shape.fromFace($0) }, tolerance: 1e-6))

        let vSTEP = fromSTEP.volume ?? 0
        let vBREP = fromBREP.volume ?? 0
        let vIGES = sewnIGES.volume ?? 0
        #expect(abs(vSTEP - origVol) / origVol < 0.01)
        #expect(abs(vBREP - origVol) / origVol < 0.001)
        #expect(abs(vIGES - origVol) / origVol < 0.02)
    }

    @Test func cylinderSTEPvsBREP() throws {
        let cyl = try standardCylinder()
        let origVol = try #require(cyl.volume)

        let stepURL = tempURL("step")
        let brepURL = tempURL("brep")
        defer {
            cleanupTemp(stepURL)
            cleanupTemp(brepURL)
        }

        try Exporter.writeSTEP(shape: cyl, to: stepURL, modelType: .asIs)
        try Exporter.writeBREP(shape: cyl, to: brepURL)

        let fromSTEP = try Shape.load(from: stepURL)
        let fromBREP = try Shape.loadBREP(from: brepURL)

        let vSTEP = fromSTEP.volume ?? 0
        let vBREP = fromBREP.volume ?? 0
        // Both should be close to original
        #expect(abs(vSTEP - origVol) / origVol < 0.01)
        #expect(abs(vBREP - origVol) / origVol < 0.001)
        // And close to each other
        #expect(abs(vSTEP - vBREP) / origVol < 0.01)
    }

    /// #2830: the export used to `continue` on nil, so a shape whose BREP string could not be
    /// produced at all left no trace, and the matrix itself was one row short because
    /// `allStandardShapes()` dropped `"openShell"` in silence.
    ///
    /// Both halves now fail.
    @Test func allShapesBREPString() throws {
        // `allStandardShapes()` asserts its own membership against `standardShapeNames`; the
        // figures table is checked against the same names here, in both directions, so a fixture
        // added to one and not the other fails by name.
        let shapes = try allStandardShapes()
        #expect(Set(shapes.map(\.0)) == Set(fixtureFigures.keys))
        for (name, shape) in shapes {
            let brep = try #require(shape.toBREPString(), "BREP string export failed for \(name)")
            let restored = try #require(
                Shape.fromBREPString(brep), "BREP string restore failed for \(name)")
            try expectFigures(shape, restored: restored, name: name)
        }
    }
}
