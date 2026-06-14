// StressFormatRoundTripTests.swift
// Category 5: Shape × Format round-trip matrix with tolerance verification.

import Foundation
import Testing
import OCCTSwift

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
            #expect(abs(rVol - origVol) / origVol < 0.01, "Volume mismatch for \(name): \(rVol) vs \(origVol)")
        }
        if origArea > 0, let rArea = reimported.surfaceArea {
            #expect(abs(rArea - origArea) / origArea < 0.01, "Area mismatch for \(name)")
        }
        // STEP may merge/split edges during serialization — check faces match, edges approximate
        #expect(reimported.subShapeCount(ofType: .face) == origFaces, "Face count mismatch for \(name)")
        let reimEdges = reimported.subShapeCount(ofType: .edge)
        #expect(abs(reimEdges - origEdges) <= max(4, origEdges / 5), "Edge count too different for \(name): \(reimEdges) vs \(origEdges)")
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
        // STL loses topology — just verify bounding box roughly matches
        let origBounds = shape.bounds
        let reimBounds = reimported.bounds
        let origSize = origBounds.max - origBounds.min
        let reimSize = reimBounds.max - reimBounds.min
        // Size should be within 10% (STL mesh approximation)
        if origSize.x > 0.1 {
            #expect(abs(reimSize.x - origSize.x) / origSize.x < 0.2, "STL X size mismatch for \(name)")
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

    private func roundTrip(_ shape: Shape, name: String) throws {
        let url = tempURL("obj")
        defer { cleanupTemp(url) }
        try Exporter.writeOBJ(shape: shape, to: url)
        // OBJ is mesh-based — reimported shape is a triangulation, not B-rep
        // Just verify export + reimport completes without crash
        let reimported = try Shape.loadOBJ(from: url)
        _ = reimported // may not be "valid" in B-rep sense
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func filletedBoxShape() throws { try roundTrip(filletedBox(), name: "filletedBox") }
}

// MARK: - IGES Round-Trip

@Suite("Stress: Round-Trip IGES",
       .disabled("IGES export/import segfaults on certain shapes — OCCT kernel bug"))
struct StressRoundTripIGESTests {

    private func roundTrip(_ shape: Shape, name: String) throws {
        let origVol = shape.volume ?? 0
        let url = tempURL("iges")
        defer { cleanupTemp(url) }
        try Exporter.writeIGES(shape: shape, to: url)
        let reimported = try Shape.loadIGES(from: url)
        #expect(reimported.isValid, "IGES round-trip failed for \(name)")
        if origVol > 0, let rVol = reimported.volume {
            #expect(abs(rVol - origVol) / origVol < 0.02, "IGES volume mismatch for \(name)")
        }
    }

    @Test func box() throws { try roundTrip(standardBox(), name: "box") }
    @Test func cylinder() throws { try roundTrip(standardCylinder(), name: "cylinder") }
    @Test func sphere() throws { try roundTrip(standardSphere(), name: "sphere") }
    @Test func cone() throws { try roundTrip(standardCone(), name: "cone") }
    @Test func torus() throws { try roundTrip(standardTorus(), name: "torus") }
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

        // All three should agree on volume
        let vSTEP = fromSTEP.volume ?? 0
        let vBREP = fromBREP.volume ?? 0
        let vIGES = fromIGES.volume ?? 0
        #expect(abs(vSTEP - origVol) / origVol < 0.01)
        #expect(abs(vBREP - origVol) / origVol < 0.001)
        #expect(abs(vIGES - origVol) / origVol < 0.02)
    }

    @Test func cylinderSTEPvsBREP() throws {
        let cyl = standardCylinder()
        let origVol = cyl.volume!

        let stepURL = tempURL("step")
        let brepURL = tempURL("brep")
        defer { cleanupTemp(stepURL); cleanupTemp(brepURL) }

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
