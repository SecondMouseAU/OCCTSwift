import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Make Volume")
struct MakeVolumeTests {
    @Test("Make volume from faces")
    func volumeFromFaces() {
        // Create face shapes
        let face1 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        let face2 = Shape.face(from: Wire.rectangle(width: 10, height: 10)!)
        if let f1 = face1, let f2 = face2 {
            // Try make volume - complex operation, just verify it doesn't crash
            let _ = Shape.makeVolume(from: [f1, f2])
        }
    }
}
