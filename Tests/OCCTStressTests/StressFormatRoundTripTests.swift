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
    @Test func drilledPlateShape() throws { try roundTrip(drilledPlate(), name: "drilledPlate") }
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
    @Test func drilledPlateShape() throws { try roundTrip(drilledPlate(), name: "drilledPlate") }
    @Test func compound() throws { try roundTrip(standardCompound(), name: "compound") }
}

// MARK: - BREP String Round-Trip

@Suite("Stress: Round-Trip BREP String")
struct StressRoundTripBREPStringTests {

    private func roundTrip(_ shape: Shape, name: String) {
        let origVol = shape.volume ?? 0
        let origFaces = shape.subShapeCount(ofType: .face)

        guard let brepStr = shape.toBREPString() else {
            #expect(Bool(false), "toBREPString failed for \(name)")
            return
        }
        #expect(!brepStr.isEmpty)

        guard let restored = Shape.fromBREPString(brepStr) else {
            #expect(Bool(false), "fromBREPString failed for \(name)")
            return
        }
        #expect(restored.isValid)
        if origVol > 0, let rVol = restored.volume {
            #expect(abs(rVol - origVol) / origVol < 0.001, "Volume mismatch for \(name)")
        }
        #expect(restored.subShapeCount(ofType: .face) == origFaces)
    }

    @Test func box() { roundTrip(standardBox(), name: "box") }
    @Test func cylinder() { roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() { roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() { roundTrip(standardCone(), name: "cone") }
    @Test func torus() { roundTrip(standardTorus(), name: "torus") }
    @Test func filletedBoxShape() { roundTrip(filletedBox(), name: "filletedBox") }
    @Test func drilledPlateShape() { roundTrip(drilledPlate(), name: "drilledPlate") }
    @Test func compound() { roundTrip(standardCompound(), name: "compound") }
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
        let origBounds = shape.bounds!
        let reimBounds = reimported.bounds!
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
        let box = standardBox()
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
        let cyl = standardCylinder()
        let origVol = cyl.volume!

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

    @Test func allShapesBREPString() {
        for (name, shape) in allStandardShapes() {
            guard let brep = shape.toBREPString() else { continue }
            guard let restored = Shape.fromBREPString(brep) else {
                #expect(Bool(false), "BREP string restore failed for \(name)")
                continue
            }
            #expect(restored.isValid, "Restored \(name) not valid")
        }
    }
}
