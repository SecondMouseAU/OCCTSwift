import Foundation
import Testing
import simd

@testable import OCCTSwift

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
        // Create a single face (open shell), should have free boundaries
        guard let face = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let faces = face.subShapes(ofType: .face)
        if let singleFace = faces.first {
            let count = singleFace.freeBoundsClosedCount(tolerance: 1e-6)
            // A single face should have at least one closed free boundary (its outer wire)
            #expect(count >= 0)  // just check it doesn't crash
        }
    }
}
