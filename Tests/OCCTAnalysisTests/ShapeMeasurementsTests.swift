import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeMeasurements")
struct ShapeMeasurementsTests {

    @Test func boxFaceAreasMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 6 faces. Total surface area = 2*(2*3 + 3*5 + 2*5) = 2*31 = 62.
        #expect(m.faceAreas.count == 6)
        #expect(
            abs(m.totalFaceArea - 62.0) < 1e-6,
            "expected 62.0, got \(m.totalFaceArea)")
        // Areas should occur in 3 pairs (front/back, top/bottom, left/right).
        let sorted = m.faceAreas.sorted()
        #expect(abs(sorted[0] - sorted[1]) < 1e-6)
        #expect(abs(sorted[2] - sorted[3]) < 1e-6)
        #expect(abs(sorted[4] - sorted[5]) < 1e-6)
    }

    @Test func boxEdgeLengthsMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        // Box has 12 edges: 4 of length 2, 4 of length 3, 4 of length 5.
        // Total = 4*(2+3+5) = 40.
        #expect(m.edgeLengths.count == 12)
        #expect(
            abs(m.totalEdgeLength - 40.0) < 1e-6,
            "expected 40.0, got \(m.totalEdgeLength)")
    }

    @Test func cylinderTotalsAreFinite() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        let m = cyl.measure()
        #expect(m.faceAreas.count >= 3)
        #expect(m.totalFaceArea > 0)
        #expect(m.totalFaceArea.isFinite)
        #expect(m.totalEdgeLength > 0)
        #expect(m.totalEdgeLength.isFinite)
    }

    @Test func boxFaceCentroidsLieInsideFaceBounds() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(
            m.faceCentroids.count == 6,
            "one centroid per face, parallel to faceAreas")
        let faceList = box.faces()
        for (i, maybeC) in m.faceCentroids.enumerated() {
            guard let c = maybeC else {
                Issue.record("face \(i) of a box has an area, so it has a centroid")
                continue
            }
            let b = faceList[i].bounds!
            #expect(
                c.x >= b.min.x - 1e-6 && c.x <= b.max.x + 1e-6,
                "face \(i) centroid X=\(c.x) outside [\(b.min.x), \(b.max.x)]")
            #expect(
                c.y >= b.min.y - 1e-6 && c.y <= b.max.y + 1e-6,
                "face \(i) centroid Y=\(c.y) outside [\(b.min.y), \(b.max.y)]")
            #expect(
                c.z >= b.min.z - 1e-6 && c.z <= b.max.z + 1e-6,
                "face \(i) centroid Z=\(c.z) outside [\(b.min.z), \(b.max.z)]")
        }
    }

    @Test func boxFacePerimetersMatchExpectedTotals() {
        guard let box = Shape.box(width: 2, height: 3, depth: 5) else {
            Issue.record("Shape.box returned nil")
            return
        }
        let m = box.measure()
        #expect(m.facePerimeters.count == 6)
        // 2x3 face perimeter 10 (×2), 3x5 perimeter 16 (×2), 2x5 perimeter 14 (×2).
        // Total = 20 + 32 + 28 = 80.
        #expect(
            abs(m.totalFacePerimeter - 80.0) < 1e-6,
            "expected 80.0 total face perimeter, got \(m.totalFacePerimeter)")
        #expect(
            m.facePerimeters.allSatisfy { $0 != nil },
            "all box faces have a closed outer wire")
    }

    @Test func cylinderTopBottomCentroidsAreOnAxis() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("Shape.cylinder returned nil")
            return
        }
        // Find the two circular cap faces by area: pi*r^2 = pi*25 ≈ 78.54.
        // Their centroids should lie on the cylinder axis (X=Y=0 in OCCT's
        // default cylinder placement, which puts the axis on Z).
        let m = cyl.measure()
        let capArea = .pi * 25.0
        var capCount = 0
        for (i, area) in m.faceAreas.enumerated() {
            if abs(area - capArea) < 1e-3 {
                capCount += 1
                guard let c = m.faceCentroids[i] else {
                    Issue.record("cap \(i) has an area, so it has a centroid")
                    continue
                }
                #expect(abs(c.x) < 1e-6, "cap \(i) centroid X=\(c.x), expected 0")
                #expect(abs(c.y) < 1e-6, "cap \(i) centroid Y=\(c.y), expected 0")
            }
        }
        #expect(capCount == 2, "cylinder has 2 circular caps, found \(capCount)")
    }
}
