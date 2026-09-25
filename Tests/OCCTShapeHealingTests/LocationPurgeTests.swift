import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.43.0: Location Purge

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-locations-nurbs-sameparam/probe.mm (transcript.txt beside it).
// Before #766 both tests asserted only inside `if let purged`, so a nil result passed.
@Suite("Location Purge")
struct LocationPurgeTests {
    @Test("Clean shape purges successfully")
    func cleanShapePurge() throws {
        // Kernel: BRepTools_PurgeLocations is done on a clean box and keeps its 6 faces.
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let purged = try #require(box.purgedLocations)
        #expect(purged.subShapeCount(ofType: .face) == 6)
        #expect(abs((purged.volume ?? 0) - 1000) < 1e-9)
    }

    @Test("Mirrored shape purges locations")
    func mirroredShapePurge() throws {
        // `mirrored(planeNormal:)` transforms with a copy, so its faces carry no location to
        // purge (kernel: 0 located faces before and after); the purge must still succeed and
        // keep the solid (6 faces, volume 1000).
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let mirrored = try #require(box.mirrored(planeNormal: SIMD3(1, 0, 0)))
        let purged = try #require(mirrored.purgedLocations)
        #expect(purged.subShapeCount(ofType: ShapeType.face) == 6)
        #expect(abs((purged.volume ?? 0) - 1000) < 1e-9)
    }
}
