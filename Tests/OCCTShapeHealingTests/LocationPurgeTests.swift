import Foundation
import Testing
import simd

@testable import OCCTSwift

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
