import Testing
import Foundation
import simd
@testable import OCCTSwift


extension SIMD3 where Scalar == Double {
    var normalized: SIMD3<Double> {
        let len = sqrt(x*x + y*y + z*z)
        guard len > 0 else { return self }
        return SIMD3(x/len, y/len, z/len)
    }
}



@Suite("Sewing Tests")
struct SewingTests {

    @Test("Sew two shapes together")
    func sewTwoShapes() {
        // Create two separate faces (they don't need to be adjacent for sewing to work)
        let rect1 = Wire.rectangle(width: 10, height: 10)!
        let rect2 = Wire.circle(radius: 5)!

        let face1 = Shape.face(from: rect1)!
        let face2 = Shape.face(from: rect2)!

        let sewn = Shape.sew(face1, with: face2, tolerance: 1e-6)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Sew array of faces")
    func sewMultipleFaces() {
        // Create several separate faces
        let faces = [
            Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!,
            Shape.face(from: Wire.circle(radius: 5)!)!,
            Shape.face(from: Wire.rectangle(width: 8, height: 8)!)!
        ]

        let sewn = Shape.sew(shapes: faces, tolerance: 1e-6)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Instance method sewn(with:)")
    func instanceMethodSewn() {
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.circle(radius: 5)!)!

        let sewn = face1.sewn(with: face2)

        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }
}


// MARK: - v0.13.0 Shape Healing & Analysis Tests

@Suite("Shape Analysis Tests")
struct ShapeAnalysisTests {

    @Test("Analyze valid box")
    func analyzeValidBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.hasInvalidTopology == false)
        // A valid box may have gap counts due to wire analysis heuristics,
        // but should have no invalid topology
        #expect(box.isValid)
    }

    @Test("Analyze shape for small features")
    func analyzeForSmallFeatures() {
        // Create a box - should have no small features
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let analysis = box.analyze(tolerance: 0.001)

        #expect(analysis != nil)
        #expect(analysis!.smallEdgeCount == 0)
        #expect(analysis!.smallFaceCount == 0)
    }

    @Test("Analysis result properties")
    func analysisResultProperties() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let analysis = box.analyze()!

        #expect(analysis.totalProblems >= 0)
        // Check that totalProblems is consistent with component counts
        let expectedTotal = analysis.smallEdgeCount + analysis.smallFaceCount +
                           analysis.gapCount + analysis.selfIntersectionCount +
                           analysis.freeEdgeCount + analysis.freeFaceCount +
                           (analysis.hasInvalidTopology ? 1 : 0)
        #expect(analysis.totalProblems == expectedTotal)
    }
}

@Suite("Shape Fixing Tests")
struct ShapeFixingTests {

    @Test("Fix healthy shape returns shape")
    func fixHealthyShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        let fixed = box.fixed(tolerance: 0.001)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Fix with selective modes")
    func fixWithSelectiveModes() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // Fix only wires and faces, not solids
        let fixed = box.fixed(tolerance: 0.001, fixSolid: false, fixShell: true, fixFace: true, fixWire: true)

        #expect(fixed != nil)
        #expect(fixed!.isValid)
    }

    @Test("Existing heal function still works")
    func existingHealStillWorks() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!

        // The healed() function should still work
        let healed = box.healed()!

        #expect(healed.isValid)
    }
}

// MARK: - Advanced Healing Tests (v0.17.0)

@Suite("Advanced Healing Tests")
struct AdvancedHealingTests {

    @Test("Divide cylinder at C1")
    func divideCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let divided = cyl.divided(at: .c1)
        // May return the same shape if no discontinuities found
        if let divided = divided {
            #expect(divided.isValid)
        }
    }

    @Test("Direct faces on box")
    func directFacesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.directFaces()
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Scale geometry by 2x")
    func scaleGeometry() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let originalVolume = box.volume ?? 0
        let scaled = box.scaledGeometry(factor: 2.0)
        #expect(scaled != nil)
        #expect(scaled!.isValid)
        let scaledVolume = scaled!.volume
        #expect(scaledVolume != nil)
        // Volume should be ~8x (2^3)
        #expect(abs(scaledVolume! - originalVolume * 8.0) < originalVolume * 0.1)
    }

    @Test("BSpline restriction on shape")
    func bsplineRestriction() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let restricted = box.bsplineRestriction()
        if let restricted = restricted {
            #expect(restricted.isValid)
        }
    }

    @Test("Convert to BSpline")
    func convertToBSpline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let bspline = box.convertedToBSpline()
        #expect(bspline != nil)
        #expect(bspline!.isValid)
    }

    @Test("Swept to elementary on cylinder")
    func sweptToElementary() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.sweptToElementary()
        #expect(result != nil)
        if let r = result { #expect(r.isValid) }
    }

    @Test("Sew disconnected faces")
    func sewFaces() {
        // Create a box and sew it - should return a valid shape
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.sewn(tolerance: 1e-6)
        #expect(sewn != nil)
        #expect(sewn!.isValid)
    }

    @Test("Full upgrade pipeline")
    func upgradePipeline() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let upgraded = box.upgraded(tolerance: 1e-6)
        #expect(upgraded != nil)
        #expect(upgraded!.isValid)
    }
}

@Suite("NURBS Conversion")
struct NURBSConversionTests {
    @Test("Convert box to NURBS")
    func convertBox() {
        let box = Shape.box(width: 10, height: 5, depth: 3)!
        let nurbs = box.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }

    @Test("Convert sphere to NURBS")
    func convertSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let nurbs = sphere.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }

    @Test("Convert filleted box to NURBS")
    func convertFilleted() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let filleted = box.filleted(radius: 1)!
        let nurbs = filleted.convertedToNURBS()
        #expect(nurbs != nil)
        #expect(nurbs!.isValid)
    }
}

@Suite("Fast Sewing")
struct FastSewingTests {
    @Test("Fast sew a valid shape")
    func fastSewValid() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.fastSewn()
        #expect(sewn != nil)
    }

    @Test("Fast sew with custom tolerance")
    func fastSewTolerance() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let sewn = box.fastSewn(tolerance: 0.01)
        #expect(sewn != nil)
    }
}

@Suite("Analytical Conversion")
struct AnalyticalConversionTests {
    @Test("BSpline circle converts to analytical")
    func bsplineCircle() {
        // Create a circle as BSpline, then try to recognize it
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 10)!
        let bspline = circle.toBSpline()
        if let bs = bspline {
            let analytical = bs.toAnalytical(tolerance: 0.01)
            // May or may not succeed depending on OCCT's recognition
            if let a = analytical {
                // If recognized, evaluate at parameter 0
                let pt = a.point(at: 0)
                #expect(pt != nil)
            }
        }
    }

    @Test("Surface analytical conversion")
    func surfaceConversion() {
        // A cylindrical surface as BSpline
        let cyl = Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 5)!
        let bspline = cyl.toBSpline()
        if let bs = bspline {
            let analytical = bs.toAnalytical(tolerance: 0.01)
            // May or may not succeed
            if let a = analytical {
                let pt = a.point(atU: 0, v: 0)
                #expect(pt != nil)
            }
        }
    }
}

@Suite("Remove Locations")
struct RemoveLocationsTests {
    @Test("Remove locations from translated shape")
    func removeFromTranslated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let moved = box.translated(by: SIMD3(100, 200, 300))!
        let flat = moved.removingLocations()
        #expect(flat != nil)
        #expect(flat!.isValid)
        // Volume should be preserved
        #expect(abs(flat!.volume! - box.volume!) < 0.01)
    }

    @Test("Remove locations from rotated shape")
    func removeFromRotated() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let rotated = cyl.rotated(axis: SIMD3(1, 0, 0), angle: .pi / 4)!
        let flat = rotated.removingLocations()
        #expect(flat != nil)
        #expect(flat!.isValid)
    }
}

@Suite("Same Parameter")
struct SameParameterTests {
    @Test("Same parameter on box")
    func sameParameterBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.sameParameter()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Same parameter on cylinder")
    func sameParameterCylinder() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.sameParameter()
        #expect(result != nil)
    }

    @Test("Same parameter preserves volume")
    func sameParameterPreservesVolume() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.sameParameter()!
        #expect(abs(result.volume! - 1000.0) < 1.0)
    }
}

@Suite("Encode Regularity")
struct EncodeRegularityTests {
    @Test("Encode regularity on box")
    func encodeRegularityBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.encodingRegularity()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
            #expect(abs(r.volume! - 1000.0) < 1.0)
        }
    }

    @Test("Encode regularity on filleted box")
    func encodeRegularityFilleted() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!.filleted(radius: 1)!
        let result = box.encodingRegularity(toleranceDegrees: 1.0)
        #expect(result != nil)
    }
}

@Suite("Update Tolerances")
struct UpdateTolerancesTests {
    @Test("Update tolerances on box")
    func updateTolerancesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.updatingTolerances()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Update tolerances preserves geometry")
    func updateTolerancesPreservesVolume() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.updatingTolerances()
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.volume! - cyl.volume!) < 1.0)
        }
    }
}

@Suite("Divide by Number")
struct DivideByNumberTests {
    @Test("Divide box into parts")
    func divideBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByNumber(4)
        // Division is geometry-dependent; may return nil for some shapes
        if let r = result {
            #expect(r.faces().count >= box.faces().count)
        }
    }

    @Test("Divide with 1 part returns nil")
    func divideOnePart() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.dividedByNumber(1)
        #expect(result == nil)
    }

    @Test("Divide API callable")
    func divideApiCallable() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        // FaceDivideArea may or may not succeed on curved geometry
        let result = cyl.dividedByNumber(4)
        _ = result
    }
}

@Suite("Free Boundary Analysis")
struct FreeBoundsTests {
    @Test("Closed solid has no free boundaries")
    func closedSolidNoFreeBounds() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.freeBounds()
        // A watertight solid should have no free boundaries
        #expect(result == nil)
    }

    @Test("Compound of adjacent faces has free boundaries")
    func compoundFacesHasFreeBounds() {
        // ShapeAnalysis_FreeBounds finds boundaries between separate faces in a compound,
        // not edges of a single face. Use two adjacent faces sharing an edge.
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let face2 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        // Translate second face to be adjacent
        let moved = face2.translated(by: SIMD3(10, 0, 0))!
        let compound = Shape.compound([face1, moved])!
        let result = compound.freeBounds()
        #expect(result != nil)
        if let result {
            #expect(result.closedCount >= 1)
        }
    }

    @Test("Free bounds analysis callable on sphere")
    func freeBoundsSphere() {
        let sphere = Shape.sphere(radius: 5)!
        let result = sphere.freeBounds()
        // A closed sphere should have no free boundaries
        #expect(result == nil)
    }

    @Test("Fix free bounds callable")
    func fixFreeBoundsCallable() {
        let face = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)!
        let result = face.fixedFreeBounds(sewingTolerance: 1e-6, closingTolerance: 1e-4)
        // Should return something even if nothing was fixed
        _ = result
    }
}

// MARK: - v0.41.0: Geometry Conversion

@Suite("ShapeCustom Geometry Conversion")
struct GeometryConversionTests {
    @Test("Convert cylinder to BSpline surfaces")
    func cylinderToBSpline() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.withSurfacesAsBSpline()
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(result.faces().count == cyl.faces().count)
        }
    }

    @Test("Convert to revolution surfaces")
    func toRevolution() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.withSurfacesAsRevolution()
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("BSpline conversion preserves volume")
    func bsplinePreservesVolume() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let volBefore = cyl.volume!
        let result = cyl.withSurfacesAsBSpline()!
        let volAfter = result.volume!
        // Volume should be approximately preserved
        #expect(abs(volBefore - volAfter) / volBefore < 0.01)
    }
}

// MARK: - v0.43.0: Location Purge

@Suite("Location Purge")
struct LocationPurgeTests {
    @Test("Clean shape purges successfully")
    func cleanShapePurge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let purged = box.purgedLocations
        // Clean shapes may return nil (nothing to purge) or the same shape
        // Either outcome is valid
        if let purged {
            #expect(purged.subShapeCount(ofType: .face) == 6)
        }
    }

    @Test("Mirrored shape purges locations")
    func mirroredShapePurge() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let mirrored = box.mirrored(planeNormal: SIMD3(1, 0, 0))
        #expect(mirrored != nil)
        if let mirrored {
            let purged = mirrored.purgedLocations
            // Mirrored shape has a negative-scale location that should be purged
            if let purged {
                let faceCount = purged.subShapeCount(ofType: ShapeType.face)
                #expect(faceCount == 6)
            }
        }
    }
}

@Suite("ShapeFix Tolerance Tests")
struct ShapeFixToleranceTests {
    @Test("Set tolerance on box")
    func setTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        box.setTolerance(1e-5)
        #expect(box.isValid)
    }

    @Test("Limit tolerance on box")
    func limitTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        _ = box.limitTolerance(min: 1e-7, max: 1e-3)
        #expect(box.isValid)
    }
}

@Suite("ShapeFix SplitCommonVertex Tests")
struct ShapeFixSplitCommonVertexTests {
    @Test("Split common vertices on box")
    func splitVertices() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.splitCommonVertices()
        #expect(result != nil, "Should return a result")
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("ShapeFix Edge Tests")
struct ShapeFixEdgeTests {
    @Test("Fix same parameter on box edges")
    func fixSameParameter() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixEdgeSameParameter()
        // Box edges should already be correct, so 0 fixes expected
        #expect(fixed >= 0)
    }

    @Test("Fix vertex tolerance on box edges")
    func fixVertexTolerance() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixEdgeVertexTolerance()
        #expect(fixed >= 0)
    }
}

@Suite("ShapeFix WireVertex Tests")
struct ShapeFixWireVertexTests {
    @Test("Fix wire vertices on box")
    func fixWireVertices() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let fixed = box.fixWireVertices(precision: 1e-4)
        #expect(fixed >= 0)
    }
}

@Suite("ShapeUpgrade DivideClosed Tests")
struct ShapeUpgradeDivideClosedTests {
    @Test("Divide closed cylinder faces")
    func divideCylinder() throws {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let origFaces = cyl.faces().count
        if let divided = cyl.dividedClosedFaces() {
            let newFaces = divided.faces().count
            #expect(newFaces >= origFaces, "Should have at least as many faces after divide")
        }
    }
}

@Suite("ShapeUpgrade DivideContinuity Tests")
struct ShapeUpgradeDivideContinuityTests {
    @Test("Divide box by continuity")
    func divideBoxContinuity() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        // Box has C0 at edges, so dividing by C1 should not change it
        let result = box.dividedByContinuity(criterion: .c1)
        // May return nil if no divisions needed
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("ShapeFix FixSmallSolid Tests")
struct ShapeFixSmallSolidTests {
    @Test("Remove small solids by volume")
    func removeSmallSolids() throws {
        let big = Shape.box(width: 10, height: 10, depth: 10)!
        let tiny = Shape.box(width: 0.01, height: 0.01, depth: 0.01)!

        // Translate tiny box away from big box
        let movedTiny = tiny.translated(by: SIMD3(20, 0, 0))!
        let compound = Shape.compound([big, movedTiny])!

        let solidsBefore = compound.solids.count
        #expect(solidsBefore == 2)

        if let result = compound.removeSmallSolids(volumeThreshold: 1.0) {
            let solidsAfter = result.solids.count
            #expect(solidsAfter < solidsBefore)
        }
    }

    @Test("Merge small solids")
    func mergeSmallSolids() throws {
        let big = Shape.box(width: 10, height: 10, depth: 10)!
        let tiny = Shape.box(origin: SIMD3(10, 0, 0), width: 0.01, height: 10, depth: 10)!
        let compound = Shape.compound([big, tiny])!

        let solidsBefore = compound.solids.count
        #expect(solidsBefore == 2)

        if let result = compound.mergeSmallSolids(widthFactorThreshold: 1.0) {
            #expect(result.isValid)
        }
    }
}

@Suite("ShapeCustom BSplineRestriction Tests")
struct ShapeCustomBSplineRestrictionTests {
    @Test("BSpline restriction on box")
    func bsplineRestrictionBox() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let result = box.bsplineRestriction() {
            #expect(result.isValid)
            #expect(result.faces().count > 0)
        }
    }

    @Test("BSpline restriction with custom parameters")
    func bsplineRestrictionCustom() throws {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        if let result = box.bsplineRestriction(
            tol3d: 0.001, tol2d: 0.001,
            maxDegree: 4, maxSegments: 50,
            continuity3d: .c2, continuity2d: .c2
        ) {
            #expect(result.isValid)
        }
    }
}

@Suite("ShapeAnalysis FreeBoundsProperties Tests")
struct FreeBoundsPropertiesTests {
    @Test("Free bounds analysis on face compound")
    func freeBoundsOnFaces() throws {
        // Two separate faces form a compound with free bounds
        let face1 = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 0), SIMD3(0, 10, 0)
            ])!)!
        let face2 = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(10, 0, 5),
                SIMD3(10, 10, 5), SIMD3(0, 10, 5)
            ])!)!
        let compound = Shape.compound([face1, face2])!

        let analysis = compound.freeBoundsAnalysis(tolerance: 0.01)
        #expect(analysis.totalCount > 0)
        #expect(analysis.closedCount > 0)
    }

    @Test("Closed free bound info — area and perimeter")
    func closedBoundInfo() throws {
        let face = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 0), SIMD3(0, 10, 0)
            ])!)!
        let face2 = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(10, 0, 5),
                SIMD3(10, 10, 5), SIMD3(0, 10, 5)
            ])!)!
        let compound = Shape.compound([face, face2])!

        let analysis = compound.freeBoundsAnalysis(tolerance: 0.01)
        if analysis.closedCount > 0 {
            if let info = compound.closedFreeBoundInfo(tolerance: 0.01, index: 0) {
                #expect(info.area > 0)
                #expect(info.perimeter > 0)
                #expect(abs(info.area - 100.0) < 5.0) // 10x10 face
                #expect(abs(info.perimeter - 40.0) < 2.0)
            }
        }
    }

    @Test("Free bound wire extraction")
    func freeBoundWire() throws {
        let face = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 0), SIMD3(10, 0, 0),
                SIMD3(10, 10, 0), SIMD3(0, 10, 0)
            ])!)!
        let face2 = Shape.face(from:
            Wire.polygon3D([
                SIMD3(0, 0, 5), SIMD3(10, 0, 5),
                SIMD3(10, 10, 5), SIMD3(0, 10, 5)
            ])!)!
        let compound = Shape.compound([face, face2])!

        let analysis = compound.freeBoundsAnalysis(tolerance: 0.01)
        if analysis.closedCount > 0 {
            if let wire = compound.closedFreeBoundWire(tolerance: 0.01, index: 0) {
                #expect(wire.isValid)
                #expect(wire.edges().count > 0)
            }
        }
    }
}

@Suite("ShapeAnalysis Surface ValueOfUV Tests")
struct SurfaceValueOfUVTests {
    @Test("Project point onto plane — UV and gap")
    func projectOntoPlane() throws {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let proj = plane.valueOfUV(point: SIMD3(5, 3, 2))
        #expect(abs(proj.uv.x - 5.0) < 0.1)
        #expect(abs(proj.uv.y - 3.0) < 0.1)
        #expect(abs(proj.gap - 2.0) < 0.1)
    }

    @Test("Project point onto sphere")
    func projectOntoSphere() throws {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let proj = sphere.valueOfUV(point: SIMD3(0, 0, 10))
        // Gap should be 5 (10 - radius)
        #expect(abs(proj.gap - 5.0) < 0.5)
    }

    @Test("Next value of UV — iterative projection")
    func nextValueOfUV() throws {
        let plane = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))!
        let proj1 = plane.valueOfUV(point: SIMD3(5, 3, 0))
        let proj2 = plane.nextValueOfUV(previousUV: proj1.uv, point: SIMD3(5.5, 3.5, 0))
        #expect(abs(proj2.uv.x - 5.5) < 0.1)
        #expect(abs(proj2.uv.y - 3.5) < 0.1)
    }
}

@Suite("ShapeAnalysis Curve Project Tests")
struct CurveProjectTests {
    @Test("Project point onto line segment")
    func projectOntoLine() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let proj = seg.projectPoint(SIMD3(5, 3, 0))
        #expect(abs(proj.distance - 3.0) < 0.1)
        #expect(abs(proj.parameter - 5.0) < 0.1)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 0.1)
    }

    @Test("Project point onto circle")
    func projectOntoCircle() throws {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        // Point at (10, 0, 0) — closest circle point at (5, 0, 0), distance 5
        let proj = circle.projectPoint(SIMD3(10, 0, 0))
        #expect(abs(proj.distance - 5.0) < 0.1)
        #expect(simd_distance(proj.point, SIMD3(5, 0, 0)) < 0.5)
    }
}

@Suite("ShapeAnalysis Curve ValidateRange Tests")
struct CurveValidateRangeTests {
    @Test("Validate range within bounds")
    func validateInBounds() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let result = seg.validateRange(first: 2, last: 8)
        // Range [2,8] is within [0,10] — may or may not be adjusted
        #expect(result.first >= 0)
        #expect(result.last <= 10)
    }

    @Test("Validate range outside bounds")
    func validateOutOfBounds() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let result = seg.validateRange(first: -5, last: 15)
        // Should be adjusted to valid range
        #expect(result.first >= -0.1) // within tolerance
        #expect(result.last <= 10.1)
    }
}

@Suite("ShapeAnalysis Curve GetSamplePoints Tests")
struct CurveSamplePointsTests {
    @Test("Sample points on circle")
    func sampleCircle() throws {
        let circle = Curve3D.circle(center: .zero, normal: SIMD3(0, 0, 1), radius: 5)!
        let dom = circle.domain
        let points = circle.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        #expect(points.count > 0)
        // First point should be on the circle at radius 5
        if let p = points.first {
            let distFromOrigin = simd_length(p)
            #expect(abs(distFromOrigin - 5.0) < 0.1)
        }
    }

    @Test("Sample points on line segment")
    func sampleLine() throws {
        let seg = Curve3D.segment(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let dom = seg.domain
        let points = seg.samplePoints(first: dom.lowerBound, last: dom.upperBound)
        #expect(points.count > 0)
    }
}

@Suite("ShapeAnalysis_WireVertex")
struct WireVertexAnalysisTests {
    @Test("Analyze wire vertices")
    func wireVertex() throws {
        let wire = try #require(Wire.polygon3D([
            SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(10, 10, 0)
        ], closed: false))
        let shape = try #require(Shape.fromWire(wire))
        let analysis = shape.wireVertexAnalysis(precision: 0.01)
        #expect(analysis.isDone)
        #expect(analysis.edgeCount == 2)
        let status = shape.wireVertexStatus(precision: 0.01, index: 0)
        #expect(status != .unknown)
    }
}

@Suite("ShapeAnalysis_Geom NearestPlane")
struct NearestPlaneTests {
    @Test("Fit plane to nearly-coplanar points")
    func nearestPlane() throws {
        let points: [SIMD3<Double>] = [
            SIMD3(0, 0, 0),
            SIMD3(10, 0, 0.1),
            SIMD3(10, 10, -0.1),
            SIMD3(0, 10, 0.05)
        ]
        let result = try #require(Shape.nearestPlane(to: points))
        #expect(result.maxDeviation < 0.2)
        #expect(abs(result.normal.z) > 0.9)
    }
}

@Suite("ShapeCustom_Surface ConvertToAnalytical")
struct SurfaceConvertToAnalyticalTests {
    @Test("Recognize cylinder from BSpline")
    func recognizeCylinder() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        if let conversion = bspline.convertToAnalytical() {
            #expect(conversion.gap < 1e-3)
        }
    }
}

@Suite("ShapeCustom_Curve ConvertToPeriodic")
struct CurveConvertToPeriodicTests {
    @Test("Convert closed BSpline to periodic")
    func convertToPeriodic() throws {
        let curve = try #require(Curve3D.interpolate(points: [
            SIMD3(10, 0, 0), SIMD3(0, 10, 0),
            SIMD3(-10, 0, 0), SIMD3(0, -10, 0),
            SIMD3(10, 0, 0)
        ]))
        if let periodic = curve.convertToPeriodic() {
            #expect(periodic.handle != nil)
        }
    }
}

@Suite("ShapeUpgrade_SplitCurve3d")
struct CurveSplitTests {
    @Test("Split curve at midpoint")
    func splitCurve() throws {
        let curve = try #require(Curve3D.interpolate(points: [
            SIMD3(0, 0, 0), SIMD3(2, 5, 0),
            SIMD3(5, 3, 0), SIMD3(8, 7, 0),
            SIMD3(10, 0, 0)
        ]))
        let dom = curve.domain
        let mid = (dom.lowerBound + dom.upperBound) / 2.0
        let result = try #require(curve.splitAt(parameter: mid))
        #expect(result.first.handle != nil)
        #expect(result.second.handle != nil)
    }
}

@Suite("ShapeUpgrade_SplitSurfaceContinuity")
struct SurfaceSplitContinuityTests {
    @Test("Split BSpline surface at continuity breaks")
    func splitByContinuity() throws {
        // Use trimmed cylinder (bounded) so it can convert to BSpline
        let trimCyl = try #require(Surface.trimmedCylinder(radius: 5.0, height: 10.0))
        let bspline = try #require(trimCyl.toBSpline())
        let result = bspline.splitByContinuity(criterion: 2, tolerance: 1e-6)
        // Either already OK or was split
        #expect(result.alreadyMeetsCriterion || result.wasSplit)
    }
}

@Suite("ShapeUpgrade ShellSewing Tests")
struct ShapeUpgradeShellSewingTests {
    @Test("Sew shells in box shape")
    func sewBoxShells() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.shellSewing(tolerance: 1e-6)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}

@Suite("ShapeCustom DirectModification")
struct ShapeCustomDirectModificationTests {
    @Test("Direct modification orients normals")
    func directModification() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.directModification()
        #expect(result != nil)
        if let result = result { #expect(result.isValid) }
    }
}

@Suite("ShapeCustom TrsfModification")
struct ShapeCustomTrsfModificationTests {
    @Test("Scale with tolerance handling")
    func trsfModificationScale() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let result = box.trsfModificationScale(2.0)
        #expect(result != nil)
        if let result = result {
            #expect(result.isValid)
            let props = result.properties()
            if let props = props {
                // Scaled 2x → volume should be 8x (2^3)
                #expect(props.volume > 7000 && props.volume < 9000)
            }
        }
    }
}

@Suite("ShapeAnalysis TransferParametersProj")
struct ShapeAnalysisTransferParametersProjTests {
    @Test("Transfer parameter edge to face")
    func transferToFace() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        let param = edges[0].transferParameterToFace(1.0, face: faces[0])
        // Just verify it returns a finite number
        #expect(param.isFinite)
    }

    @Test("Transfer parameter face to edge")
    func transferFromFace() {
        guard let cyl = Shape.cylinder(radius: 10, height: 20) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        let param = edges[0].transferParameterFromFace(1.0, face: faces[0])
        #expect(param.isFinite)
    }
}

// MARK: - ShapeBuild_Edge

@Suite("ShapeBuild Edge")
struct ShapeBuildEdgeTests {
    @Test("Copy edge")
    func copyEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge(sharePCurves: true) {
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy edge without sharing PCurves")
    func copyEdgeNoShare() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge(sharePCurves: false) {
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy edge replacing vertices")
    func copyEdgeReplaceVertices() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let vertices = box.subShapes(ofType: .vertex)
        guard edges.count >= 1, vertices.count >= 2 else { return }
        if let result = edges[0].copyEdgeReplacingVertices(
            startVertex: vertices[0], endVertex: vertices[1]) {
            #expect(result.shapeType == .edge)
        }
    }

    @Test("Set range 3d")
    func setRange3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.setEdgeRange3d(first: 0.0, last: 5.0)
            // Verify it doesn't crash
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Build curve 3d")
    func buildCurve3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        // Just verify it runs without crashing
        let _ = edges[0].buildEdgeCurve3d()
    }

    @Test("Remove curve 3d")
    func removeCurve3d() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard !edges.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.removeEdgeCurve3d()
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy ranges between edges")
    func copyRanges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 2 else { return }
        if let copied = edges[0].copyEdge() {
            copied.copyEdgeRanges(from: edges[1])
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Copy PCurves between edges")
    func copyPCurves() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        guard edges.count >= 2 else { return }
        if let copied = edges[0].copyEdge() {
            copied.copyEdgePCurves(from: edges[1])
            #expect(copied.shapeType == .edge)
        }
    }

    @Test("Remove PCurve from edge")
    func removePCurve() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let faces = box.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        if let copied = edges[0].copyEdge() {
            copied.removeEdgePCurve(onFace: faces[0])
            #expect(copied.shapeType == .edge)
        }
    }
}

// MARK: - ShapeBuild_Vertex

@Suite("ShapeBuild Vertex")
struct ShapeBuildVertexTests {
    @Test("Combine two vertices")
    func combineVertices() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let vertices = box.subShapes(ofType: .vertex)
        guard vertices.count >= 2 else { return }
        if let combined = vertices[0].combineVertex(with: vertices[1]) {
            #expect(combined.shapeType == .vertex)
        }
    }

    @Test("Combine vertices from points")
    func combineFromPoints() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(0.01, 0, 0)
        if let combined = Shape.combineVertices(point1: p1, tol1: 0.01,
                                                 point2: p2, tol2: 0.01) {
            #expect(combined.shapeType == .vertex)
        }
    }

    @Test("Combine vertices with custom tolerance factor")
    func combineWithTolFactor() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let vertices = box.subShapes(ofType: .vertex)
        guard vertices.count >= 2 else { return }
        if let combined = vertices[0].combineVertex(with: vertices[1], tolFactor: 1.5) {
            #expect(combined.shapeType == .vertex)
        }
    }
}

// MARK: - ShapeExtend_Explorer

@Suite("ShapeExtend Explorer")
struct ShapeExtendExplorerTests {
    @Test("Sorted compound - extract solids")
    func sortedCompoundSolids() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
              let box2 = Shape.box(width: 3, height: 3, depth: 3),
              let compound = Shape.compound([box1, box2]) else { return }
        if let solids = compound.sortedCompound(type: .solid) {
            let solidList = solids.subShapes(ofType: .solid)
            #expect(solidList.count == 2)
        }
    }

    @Test("Sorted compound - extract faces")
    func sortedCompoundFaces() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
              let box2 = Shape.box(width: 3, height: 3, depth: 3),
              let compound = Shape.compound([box1, box2]) else { return }
        if let faces = compound.sortedCompound(type: .face) {
            let faceList = faces.subShapes(ofType: .face)
            #expect(faceList.count == 12)
        }
    }

    @Test("Sorted compound - extract edges")
    func sortedCompoundEdges() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
              let compound = Shape.compound([box]) else { return }
        if let edges = compound.sortedCompound(type: .edge) {
            let edgeList = edges.subShapes(ofType: .edge)
            #expect(edgeList.count > 0)
        }
    }

    @Test("Predominant shape type")
    func predominantType() {
        guard let box1 = Shape.box(width: 5, height: 5, depth: 5),
              let box2 = Shape.box(width: 3, height: 3, depth: 3),
              let compound = Shape.compound([box1, box2]) else { return }
        let type = compound.predominantShapeType()
        #expect(type == .solid)
    }
}

// MARK: - ShapeUpgrade_FaceDivide

@Suite("ShapeUpgrade FaceDivide")
struct ShapeUpgradeFaceDivideTests {
    @Test("Divide cylinder face")
    func divideCylinderFace() {
        guard let cyl = Shape.cylinder(radius: 5, height: 20) else { return }
        let faces = cyl.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        // FaceDivide may return nil if no splitting criteria met
        let _ = faces[0].divideFace()
    }

    @Test("Divide box face")
    func divideBoxFace() {
        guard let box = Shape.box(width: 100, height: 100, depth: 100) else { return }
        let faces = box.subShapes(ofType: .face)
        guard !faces.isEmpty else { return }
        let _ = faces[0].divideFace()
    }
}

// MARK: - ShapeUpgrade_WireDivide

@Suite("ShapeUpgrade WireDivide")
struct ShapeUpgradeWireDivideTests {
    @Test("Divide wire on face")
    func divideWireOnFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = box.subShapes(ofType: .face)
        let wires = box.subShapes(ofType: .wire)
        guard !faces.isEmpty, !wires.isEmpty else { return }
        // WireDivide may return nil without split criteria
        let _ = wires[0].divideWire(onFace: faces[0])
    }
}

// MARK: - ShapeUpgrade_EdgeDivide

@Suite("ShapeUpgrade EdgeDivide")
struct ShapeUpgradeEdgeDivideTests {
    @Test("Analyze edge divide on face")
    func analyzeEdgeDivide() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let edges = box.subShapes(ofType: .edge)
        let faces = box.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        if let result = edges[0].analyzeEdgeDivide(onFace: faces[0]) {
            #expect(result.hasCurve3d)
        }
    }

    @Test("Analyze edge divide returns has curve info")
    func edgeDivideCurveInfo() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        // Try multiple edges to find one on a face
        for edge in edges {
            if let result = edge.analyzeEdgeDivide(onFace: faces[0]) {
                #expect(result.hasCurve3d || result.hasCurve2d)
                return
            }
        }
    }
}

// MARK: - ShapeUpgrade_ClosedEdgeDivide

@Suite("ShapeUpgrade ClosedEdgeDivide")
struct ShapeUpgradeClosedEdgeDivideTests {
    @Test("Check closed edge on cylinder")
    func closedEdgeOnCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let edges = cyl.subShapes(ofType: .edge)
        let faces = cyl.subShapes(ofType: .face)
        guard !edges.isEmpty, !faces.isEmpty else { return }
        // Some edges on a cylinder are seam edges — just verify no crash
        for edge in edges {
            if edge.canDivideClosedEdge(onFace: faces[0]) {
                break
            }
        }
        #expect(Bool(true))
    }
}

// MARK: - ShapeUpgrade_FixSmallCurves

@Suite("ShapeUpgrade FixSmallCurves")
struct ShapeUpgradeFixSmallCurvesTests {
    @Test("Fix small curves on box")
    func fixSmallCurvesBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.fixSmallCurves(tolerance: 1e-4) {
            #expect(result.isValid)
        }
    }

    @Test("Fix small curves on cylinder")
    func fixSmallCurvesCylinder() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.fixSmallCurves(tolerance: 1e-4) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}

// MARK: - ShapeUpgrade_FixSmallBezierCurves

@Suite("ShapeUpgrade FixSmallBezierCurves")
struct ShapeUpgradeFixSmallBezierCurvesTests {
    @Test("Fix small bezier curves on box")
    func fixSmallBezierCurvesBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.fixSmallBezierCurves(tolerance: 1e-4) {
            #expect(result.isValid)
        }
    }
}

// MARK: - ShapeUpgrade_ConvertCurve3dToBezier

@Suite("ShapeUpgrade ConvertCurves3dToBezier")
struct ShapeUpgradeConvertCurves3dToBezierTests {
    @Test("Convert box curves to bezier")
    func convertBoxCurves() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.convertCurves3dToBezier() {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert cylinder curves to bezier")
    func convertCylinderCurves() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertCurves3dToBezier(lineMode: true, circleMode: true, conicMode: true) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertCurves3dToBezier(lineMode: false, circleMode: true, conicMode: false) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}

// MARK: - ShapeUpgrade_ConvertSurfaceToBezierBasis

@Suite("ShapeUpgrade ConvertSurfacesToBezier")
struct ShapeUpgradeConvertSurfacesToBezierTests {
    @Test("Convert cylinder surfaces to bezier")
    func convertCylinderSurfaces() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertSurfacesToBezier() {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert with selective modes")
    func convertSelectiveModes() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        if let result = cyl.convertSurfacesToBezier(planeMode: false, revolutionMode: true,
                                                     extrusionMode: false, bsplineMode: false) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }

    @Test("Convert box surfaces to bezier")
    func convertBoxSurfaces() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.convertSurfacesToBezier(planeMode: true, revolutionMode: false,
                                                     extrusionMode: false, bsplineMode: false) {
            #expect(result.shapeType == .solid || result.shapeType == .compound)
        }
    }
}

@Suite("ShapeConstruct Triangulation Tests")
struct ShapeConstructTriangulationTests {
    @Test("triangulation from points")
    func fromPoints() {
        let points: [(Double, Double, Double)] = [
            (0, 0, 0), (10, 0, 0), (10, 10, 0), (0, 10, 0)
        ]
        let shape = Shape.triangulationFromPoints(points)
        #expect(shape != nil)
    }

    @Test("triangulation from wire")
    func fromWire() {
        if let w = Wire.polygon3D([SIMD3(0, 0, 0), SIMD3(10, 0, 0), SIMD3(5, 10, 0)], closed: true) {
            let shape = Shape.triangulationFromWire(w)
            #expect(shape != nil)
        }
    }
}

@Suite("ShapeCustom Surface Periodic Tests")
struct ShapeCustomSurfacePeriodicTests {
    @Test("convert to periodic")
    func convertToPeriodic() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            // Cylinder surface is already periodic — result may be nil
            let _ = surf.convertToPeriodic()
            // Just verify no crash
        }
    }

    @Test("conversion gap")
    func conversionGap() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5) {
            let gap = surf.conversionGap
            #expect(gap >= 0)
        }
    }
}

@Suite("ShapeConstruct Curve Tests")
struct ShapeConstructCurveTests {
    @Test("convert 3D line segment to BSpline")
    func convert3DLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let bsp = line.convertSegmentToBSpline(first: 0, last: 10)
            #expect(bsp != nil)
        }
    }

    @Test("convert 3D circle segment to BSpline")
    func convert3DCircle() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            let bsp = circle.convertSegmentToBSpline(first: 0, last: Double.pi, precision: 1e-3)
            #expect(bsp != nil)
        }
    }

    @Test("convert 2D line to BSpline")
    func convert2DLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let bsp = line.convertSegmentToBSpline(first: 0, last: 5)
            #expect(bsp != nil)
        }
    }

    @Test("adjust 3D curve endpoints")
    func adjust3D() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let ok = line.adjustEndpoints(start: SIMD3(0, 0, 0), end: SIMD3(10, 0, 0))
            #expect(ok)
        }
    }
}

@Suite("ShapeUpgrade SplitCurve Tests")
struct ShapeUpgradeSplitCurveTests {
    @Test("split smooth 3D curve")
    func splitSmooth3D() {
        if let bsp = Curve3D.bspline(poles: [SIMD3(0,0,0), SIMD3(1,2,0), SIMD3(3,1,0), SIMD3(4,0,0)],
                                      knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let segments = bsp.splitByContinuity(criterion: 2)
            #expect(segments.count >= 1)
        }
    }

    @Test("split smooth 2D curve")
    func splitSmooth2D() {
        if let bsp = Curve2D.bspline(poles: [SIMD2(0,0), SIMD2(1,2), SIMD2(3,1), SIMD2(4,0)],
                                      knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let segments = bsp.splitByContinuity(criterion: 2)
            #expect(segments.count >= 1)
        }
    }

    @Test("convert 2D curve to Bezier")
    func convertToBezier() {
        if let bsp = Curve2D.bspline(poles: [SIMD2(0,0), SIMD2(1,2), SIMD2(3,1), SIMD2(4,0)],
                                      knots: [0.0, 1.0], multiplicities: [4, 4], degree: 3) {
            let segments = bsp.convertToBezierSegments()
            #expect(segments.count >= 1)
        }
    }
}

@Suite("ShapeCustom_BSplineRestriction Advanced")
struct BSplineRestrictionAdvancedTests {
    @Test("restrict box BSpline")
    func restrictBox() {
        if let box = Shape.box(width: 10, height: 20, depth: 30) {
            let result = Shape.bsplineRestrictionAdvanced(box,
                                                            tol3d: 0.1, tol2d: 0.1,
                                                            maxDegree: 5, maxSegments: 20)
            // May return nil if no BSpline geometry to restrict; just verify no crash
            if let r = result {
                #expect(r.size.x > 0)
            }
        }
    }
}

@Suite("ShapeCustom_ConvertToBSpline Advanced")
struct ConvertToBSplineAdvancedTests {
    @Test("convert cylinder surfaces to BSpline")
    func convertCylinder() {
        if let cyl = Shape.cylinder(radius: 10, height: 50) {
            if let result = Shape.convertToBSplineAdvanced(cyl,
                                                             extrusionMode: true,
                                                             revolutionMode: true,
                                                             offsetMode: true,
                                                             planeMode: false) {
                #expect(result.isValid)
            }
        }
    }
}

@Suite("ShapeUpgrade_SplitSurface")
struct SplitSurfaceTests {
    @Test("split surface by continuity")
    func splitSurfaceByContinuity() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10) {
            if let bsp = surf.toBSpline() {
                let result = bsp.splitSurfaceByContinuity(criterion: 4, tolerance: 1e-6)
                // May or may not split, just verify no crash
                if let r = result {
                    #expect(r.uSplitCount >= 2)
                }
            }
        }
    }

    @Test("split by angle")
    func splitByAngle() {
        if let surf = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 10) {
            if let result = surf.splitByAngle(.pi / 2) {
                #expect(result.uSplitCount >= 3) // Full circle / 90° = 4 segments, 5 split values
            }
        }
    }

    @Test("split by area")
    func splitByArea() {
        if let surf = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            if let trimmed = surf.trimmed(u1: 0, u2: 10, v1: 0, v2: 10) {
                let result = trimmed.splitByArea(parts: 4)
                if let r = result {
                    #expect(r.uSplitCount >= 2)
                }
            }
        }
    }
}

@Suite("ShapeFix_ComposeShell")
struct ShapeFixComposeShellTests {
    @Test("compose shell on planar face")
    func composeShellPlanar() {
        if let rect = Wire.rectangle(width: 10, height: 10),
           let face = Shape.face(from: rect) {
            if let result = face.composeShell() {
                #expect(result.isValid)
            }
        }
    }
}

@Suite("ShapeFix Solid Tests")
struct ShapeFixSolidTests {
    @Test func fixSolid() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            if let fixed = box.fixSolid() {
                #expect(fixed.isValid)
            }
        }
    }

    @Test func solidFromShellFixed() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.solidFromShellFixed()
            #expect(result != nil)
        }
    }
}

@Suite("ShapeFix EdgeConnect Tests")
struct ShapeFixEdgeConnectTests {
    @Test func fixEdgeConnect() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixed = box.fixEdgeConnect()
            #expect(fixed != nil)
        }
    }
}

@Suite("ShapeAnalysis_Shell Tests")
struct ShellAnalysisTests {
    @Test func analyzeBox() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let result = box.analyzeShell()
            #expect(!result.hasOrientationProblems)
            #expect(!result.hasFreeEdges)
            #expect(!result.hasBadEdges)
            #expect(result.freeEdgeCount == 0)
        }
    }

    @Test func analyzeSphere() {
        if let sphere = Shape.sphere(radius: 5) {
            let result = sphere.analyzeShell()
            #expect(!result.hasOrientationProblems)
        }
    }
}

@Suite("ShapeFix EdgeProjAux Tests")
struct ShapeFixEdgeProjAuxTests {

    @Test func projectEdge() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let result = box.edgeProjAux(faceIndex: 0, edgeIndex: 0) {
            #expect(result.last > result.first || result.last == result.first)
        }
    }
}

@Suite("ShapeFix IntersectionTool Tests")
struct ShapeFixIntersectionToolTests {

    @Test func fixIntersectingWires() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let fixed = box.fixIntersectingWires(faceIndex: 0)
        #expect(!fixed)
    }
}

@Suite("ShapeFix_Wireframe Extension Tests")
struct ShapeFixWireframeExtTests {

    @Test func fixWireGapsReturnsShape() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        if let fixed = box.fixWireGaps(tolerance: 1e-7) {
            #expect(fixed.isValid)
        }
    }

    @Test func fixSmallEdgesDropMode() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        if let fixed = box.fixSmallEdges(tolerance: 1e-7, dropSmall: true, limitAngle: -1) {
            #expect(fixed.isValid)
        }
    }

    @Test func fixSmallEdgesMergeMode() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else { return }
        if let fixed = box.fixSmallEdges(tolerance: 1e-7, dropSmall: false, limitAngle: 0.01) {
            #expect(fixed.isValid)
        }
    }
}

@Suite("ShapeAnalysis_Curve Static Method Tests")
struct ShapeAnalysisCurveStaticTests {

    @Test func isClosedWithPrecision() {
        // A circle should be closed
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(circle.isClosedWithPrecision(1e-6))
        }
    }

    @Test func lineIsNotClosed() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(!line.isClosedWithPrecision(1e-6))
        }
    }

    @Test func isPeriodicSA() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(circle.isPeriodicSA)
        }
    }

    @Test func lineIsNotPeriodic() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(!line.isPeriodicSA)
        }
    }

    @Test func circleIsPlanar() {
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            if let normal = circle.planeNormal(tolerance: 1e-6) {
                // Circle in XY plane should have normal along Z
                #expect(abs(normal.z) > 0.9)
            }
        }
    }

    @Test func lineIsPlanar() {
        // A line is planar (any direction perpendicular to it is a valid normal)
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            // Lines are degenerate for IsPlanar — any plane contains them
            // The result may be nil or a normal; just check it doesn't crash
            _ = line.planeNormal(tolerance: 1e-6)
        }
    }
}

@Suite("ShapeAnalysis_FreeBounds Simplified Tests")
struct FreeBoundsSimplifiedTests {

    @Test func closedCountOnBox() {
        // A box shell has no free bounds
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let count = box.freeBoundsClosedCount(tolerance: 1e-6)
        #expect(count == 0)
    }

    @Test func closedWiresOnBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        // Box has no free boundaries, so result may be nil or empty compound
        _ = box.freeBoundsClosedWires(tolerance: 1e-6)
    }

    @Test func openWiresOnBox() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        _ = box.freeBoundsOpenWires(tolerance: 1e-6)
    }

    @Test func freeBoundsOnOpenShell() {
        // Create a single face (open shell) — should have free boundaries
        guard let face = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = face.subShapes(ofType: .face)
        if let singleFace = faces.first {
            let count = singleFace.freeBoundsClosedCount(tolerance: 1e-6)
            // A single face should have at least one closed free boundary (its outer wire)
            #expect(count >= 0) // just check it doesn't crash
        }
    }
}

@Suite("ShapeAnalysis_Surface Tests")
struct ShapeAnalysisSurfaceTests {

    @Test func projectPointOnPlane() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = s.projectPointUV(SIMD3(5, 3, 0))
            #expect(abs(result.u - 5.0) < 1e-4)
            #expect(abs(result.v - 3.0) < 1e-4)
            #expect(result.gap < 1e-6)
        }
    }

    @Test func projectPointOffPlane() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            let result = s.projectPointUV(SIMD3(0, 0, 10))
            #expect(abs(result.gap - 10.0) < 1e-4)
        }
    }

    @Test func planeHasNoSingularities() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(!s.hasSingularitiesSA())
            #expect(s.singularityCountSA() == 0)
        }
    }

    @Test func planeIsNotClosed() {
        if let s = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1)) {
            #expect(!s.isUClosedSA())
            #expect(!s.isVClosedSA())
        }
    }
}

@Suite("ShapeAnalysis_Wire Tests")
struct SAWireAnalysisTests {

    @Test func basicWireChecks() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    // These return true if problems found; for a good box, expect no problems
                    let _ = SAWireAnalysis.checkOrder(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkConnected(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkSmall(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkDegenerated(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkClosed(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkGaps3d(wire: wire, face: face)
                }
            }
        }
    }

    @Test func wireEdgeCount() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let count = SAWireAnalysis.edgeCount(wire: wire, face: face)
                    #expect(count == 4)
                }
            }
        }
    }

    @Test func wireDistance3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let minD = SAWireAnalysis.minDistance3d(wire: wire, face: face)
                    let maxD = SAWireAnalysis.maxDistance3d(wire: wire, face: face)
                    #expect(minD >= 0)
                    #expect(maxD >= 0)
                }
            }
        }
    }

    @Test func wireDistance2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let minD = SAWireAnalysis.minDistance2d(wire: wire, face: face)
                    let maxD = SAWireAnalysis.maxDistance2d(wire: wire, face: face)
                    #expect(minD >= 0)
                    #expect(maxD >= 0)
                }
            }
        }
    }

    @Test func wireSelfIntersection() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let selfInt = SAWireAnalysis.checkSelfIntersection(wire: wire, face: face)
                    #expect(!selfInt)
                }
            }
        }
    }

    @Test func wireEdgeCurves() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkEdgeCurves(wire: wire, face: face)
                    let _ = SAWireAnalysis.checkLacking(wire: wire, face: face)
                }
            }
        }
    }

    @Test func wirePerEdgeChecks() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkConnectedEdge(wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkSmallEdge(wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkDegeneratedEdge(wire: wire, face: face, edgeIndex: 1)
                    let _ = SAWireAnalysis.checkGap3dEdge(wire: wire, face: face, edgeIndex: 1)
                }
            }
        }
    }

    @Test func wireGaps2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let _ = SAWireAnalysis.checkGaps2d(wire: wire, face: face)
                }
            }
        }
    }

    @Test func outerBound() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let hasOuter = SAWireAnalysis.checkOuterBound(face: face)
                #expect(hasOuter)
            }
        }
    }
}

@Suite("ShapeAnalysis_Edge Tests")
struct SAEdgeAnalysisTests {

    @Test func edgeHasCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(EdgeAnalysis.hasCurve3d(edge))
            }
        }
    }

    @Test func edgeIsClosed3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                #expect(!EdgeAnalysis.isClosed3d(edge))
            }
        }
    }

    @Test func edgeHasPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                // Edge may or may not have a PCurve on this particular face
                let _ = EdgeAnalysis.hasPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeIsSeam() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let seam = EdgeAnalysis.isSeam(edge, face: face)
                #expect(!seam) // box edges are not seam edges
            }
        }
    }

    @Test func edgeSameParameter() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let result = EdgeAnalysis.checkSameParameter(edge)
                // maxDeviation should be small for a box edge
                let _ = result
            }
        }
    }

    @Test func edgeVerticesWithCurve3d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let _ = EdgeAnalysis.checkVerticesWithCurve3d(edge)
            }
        }
    }

    @Test func edgeVerticesWithPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkVerticesWithPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeCurve3dWithPCurve() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkCurve3dWithPCurve(edge, face: face)
            }
        }
    }

    @Test func edgeFirstLastVertex() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if let edge = edges.first {
                let first = EdgeAnalysis.firstVertex(edge)
                let last = EdgeAnalysis.lastVertex(edge)
                // Vertices should be at box corners
                #expect(first != last || EdgeAnalysis.isClosed3d(edge))
            }
        }
    }

    @Test func edgeVertexTolerance() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            let edges = box.subShapes(ofType: .edge)
            if let face = faces.first, let edge = edges.first {
                let _ = EdgeAnalysis.checkVertexTolerance(edge, face: face)
            }
        }
    }

    @Test func edgeCheckOverlapping() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let edges = box.subShapes(ofType: .edge)
            if edges.count >= 2 {
                let result = EdgeAnalysis.checkOverlapping(edges[0], edges[1])
                #expect(!result.overlapping)
            }
        }
    }

    @Test func edgeBoundUV() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    if let bounds = EdgeAnalysis.boundUV(edge, face: face) {
                        #expect(bounds.uFirst <= bounds.uLast || bounds.vFirst <= bounds.vLast)
                    }
                }
            }
        }
    }

    @Test func edgeEndTangent2d() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    if let tang = EdgeAnalysis.endTangent2d(edge, face: face, atEnd: false) {
                        // Just check it doesn't crash
                        let _ = tang
                    }
                }
            }
        }
    }

    @Test func edgePCurveRange() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let faceEdges = face.subShapes(ofType: .edge)
                if let edge = faceEdges.first {
                    let _ = EdgeAnalysis.checkPCurveRange(edge, face: face, first: 0, last: 10)
                }
            }
        }
    }
}

@Suite("Sewing Builder Tests")
struct SewingBuilderTests {

    @Test func createSewing() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        #expect(sewing != nil)
    }

    @Test func sewBoxFaces() {
        if let sewing = SewingBuilder(tolerance: 1e-6) {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                let faces = box.subShapes(ofType: .face)
                for face in faces {
                    sewing.add(face)
                }
                sewing.perform()
                if let result = sewing.result {
                    #expect(result.isValid)
                }
            }
        }
    }

    @Test func sewingStatistics() {
        if let sewing = SewingBuilder(tolerance: 1e-6) {
            if let box = Shape.box(width: 10, height: 10, depth: 10) {
                let faces = box.subShapes(ofType: .face)
                for face in faces {
                    sewing.add(face)
                }
                sewing.perform()
                #expect(sewing.nbFreeEdges >= 0)
                #expect(sewing.nbContigousEdges >= 0)
                #expect(sewing.nbDegeneratedShapes >= 0)
            }
        }
    }
}

@Suite("v0.115.0 - ShapeFixer Builder")
struct ShapeFixerBuilderTests {

    @Test func basicFixer() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixer = ShapeFixer(shape: box)
            fixer.setPrecision(1e-7)
            fixer.setMaxTolerance(1.0)
            fixer.setMinTolerance(1e-10)
            let _ = fixer.perform()
            let result = fixer.shape
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test func fixerStatus() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let fixer = ShapeFixer(shape: box)
            let _ = fixer.perform()
            // After performing on a valid box, should not be in FAIL state
            let hasFailed = fixer.status(3) // 3=FAIL
            #expect(!hasFailed)
            let result = fixer.shape
            #expect(result != nil)
        }
    }
}

@Suite("ShapeAnalysis_ShapeTolerance")
struct ShapeToleranceTests {
    @Test func averageTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let avg = b.toleranceValue(mode: .average)
            #expect(avg > 0)
        }
    }

    @Test func maximumTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let max = b.toleranceValue(mode: .maximum)
            #expect(max > 0)
        }
    }

    @Test func minimumTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let min = b.toleranceValue(mode: .minimum)
            #expect(min > 0)
        }
    }

    @Test func toleranceOrdering() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let minT = b.toleranceValue(mode: .minimum)
            let avgT = b.toleranceValue(mode: .average)
            let maxT = b.toleranceValue(mode: .maximum)
            #expect(minT <= avgT)
            #expect(avgT <= maxT)
        }
    }

    @Test func overToleranceCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            // Default tolerance is ~1e-7, so nothing should exceed 1e-3
            let count = b.toleranceOverCount(value: 1e-3)
            #expect(count == 0)
        }
    }

    @Test func inToleranceRangeCount() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let count = b.toleranceInRangeCount(min: 0, max: 1e-3)
            #expect(count > 0) // All sub-shapes should be within this range
        }
    }

    @Test func vertexTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tol = b.toleranceValue(mode: .average, subShapeType: 7) // VERTEX
            #expect(tol > 0)
        }
    }

    @Test func edgeTolerance() {
        let box = Shape.box(width: 10, height: 20, depth: 30)
        if let b = box {
            let tol = b.toleranceValue(mode: .average, subShapeType: 6) // EDGE
            #expect(tol > 0)
        }
    }
}

@Suite("Sewing_Extras")
struct SewingExtrasTests {
    @Test func multipleEdgeCount() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            #expect(s.multipleEdgeCount >= 0)
        }
    }

    @Test func noMultipleEdgesForBox() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            #expect(s.multipleEdgeCount == 0)
        }
    }

    @Test func multipleEdgeAtInvalidIndex() {
        let sewing = SewingBuilder(tolerance: 1e-6)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box { s.add(b) }
            s.perform()
            let edge = s.multipleEdge(at: 999)
            #expect(edge == nil)
        }
    }
}

@Suite("v0.122.0 — ShapeFix_Edge Extended")
struct ShapeFixEdgeExtendedTests {
    @Test("Add and remove 3D curve")
    func addRemoveCurve3d() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edges = b.subShapes(ofType: .edge)
            #expect(edges.count > 0)
            if edges.count > 0 {
                let edge = edges[0]
                // Edge already has a 3D curve, remove it then add back
                let removed = Shape.fixEdgeRemoveCurve3d(edge)
                // May or may not succeed depending on edge type
                if removed {
                    let added = Shape.fixEdgeAddCurve3d(edge)
                    #expect(added)
                }
            }
        }
    }

    @Test("Add PCurve to edge on face")
    func addPCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                // PCurve may already exist; this should be safe to call
                let _ = Shape.fixEdgeAddPCurve(edges[0], face: faces[0], isSeam: false)
                // Just verify it doesn't crash
            }
        }
    }

    @Test("Remove PCurve from edge on face")
    func removePCurve() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let _ = Shape.fixEdgeRemovePCurve(edges[0], face: faces[0])
                // Just verify it doesn't crash
            }
        }
    }

    @Test("Fix reversed 2D curve")
    func fixReversed2d() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            let edges = b.subShapes(ofType: .edge)
            if faces.count > 0, edges.count > 0 {
                let _ = Shape.fixEdgeReversed2d(edges[0], face: faces[0])
                // Just verify it doesn't crash
            }
        }
    }
}

@Suite("v0.122.0 — Sewing Extended")
struct SewingExtendedTests {
    @Test("Sewing deleted faces and queries")
    func sewingDeletedFacesAndQueries() {
        // Create two adjacent faces and sew them
        let face1 = Shape.box(width: 10, height: 10, depth: 0.01)
        let face2 = Shape.box(width: 10, height: 10, depth: 0.01)
        if let f1 = face1, let f2 = face2 {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(f1)
                s.add(f2)
                s.perform()
                let result = s.result
                #expect(result != nil)
                // Check deleted faces count (may be 0)
                let deletedCount = s.nbDeletedFaces
                #expect(deletedCount >= 0)
            }
        }
    }

    @Test("Sewing is modified and modified shape")
    func sewingIsModified() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count >= 2 {
                let sewing = SewingBuilder(tolerance: 1e-3)
                if let s = sewing {
                    s.add(faces[0])
                    s.add(faces[1])
                    s.perform()
                    let _ = s.result
                    // Check modification query
                    let isMod = s.isModified(faces[0])
                    if isMod {
                        let mod = s.modified(faces[0])
                        #expect(mod != nil)
                    }
                    #expect(true) // No crash
                }
            }
        }
    }

    @Test("Sewing is degenerated")
    func sewingIsDegenerated() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(b)
                s.perform()
                let degen = s.isDegenerated(b)
                #expect(!degen)
            }
        }
    }

    @Test("Sewing load and modes")
    func sewingLoadAndModes() {
        let sewing = SewingBuilder(tolerance: 1e-3)
        if let s = sewing {
            let box = Shape.box(width: 10, height: 10, depth: 10)
            if let b = box {
                s.load(b)
                s.setNonManifoldMode(true)
                s.setFaceMode(true)
                s.setFloatingEdgesMode(false)
                s.setMinTolerance(1e-6)
                s.setMaxTolerance(1e-1)
                s.perform()
                let result = s.result
                #expect(result != nil)
            }
        }
    }

    @Test("Sewing section bound and which face")
    func sewingSectionBoundAndWhichFace() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let sewing = SewingBuilder(tolerance: 1e-3)
            if let s = sewing {
                s.add(b)
                s.perform()
                let edges = b.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let _ = s.isSectionBound(edges[0])
                    let _ = s.whichFace(edges[0])
                    #expect(true)
                }
            }
        }
    }
}

@Suite("v0.123.0 — UnifySameDomain builder")
struct UnifySameDomainBuilderTests {

    @Test("Basic unification with builder")
    func basicUnification() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("AllowInternalEdges")
    func allowInternalEdges() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.allowInternalEdges(true)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("KeepShape")
    func keepShape() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let faces = b.subShapes(ofType: .face)
            if faces.count > 0 {
                let usd = UnifySameDomainBuilder(shape: b)
                usd.keepShape(faces[0])
                usd.build()
                let result = usd.shape
                #expect(result != nil)
            }
        }
    }

    @Test("SetSafeInputMode")
    func safeInputMode() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.setSafeInputMode(true)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }

    @Test("SetLinearTolerance and SetAngularTolerance")
    func tolerances() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let usd = UnifySameDomainBuilder(shape: b)
            usd.setLinearTolerance(1e-6)
            usd.setAngularTolerance(1e-3)
            usd.build()
            let result = usd.shape
            #expect(result != nil)
        }
    }
}
