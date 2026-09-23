import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe_Spliter v71 Tests")
struct LocOpeSpliterV71Tests {
    @Test("split by wire on face")
    func splitByWireOnFace() {
        // Use origin-based box so coordinates are predictable
        let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10)
        if let b = box {
            let origFaceCount = b.subShapes(ofType: .face).count
            let faces = b.subShapes(ofType: .face)
            // Edge on top face (Z=10), endpoints on face edges
            let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
            if let e = edge {
                let wire = Shape.makeWire(from: [e])
                if let w = wire {
                    var bestFaceCount = origFaceCount
                    for face in faces {
                        let result = b.locOpeSplit(wiresOnFaces: [(wire: w, face: face)])
                        if let r = result {
                            let newFaces = r.shape.subShapes(ofType: .face).count
                            if newFaces > bestFaceCount {
                                bestFaceCount = newFaces
                            }
                        }
                    }
                    #expect(bestFaceCount > origFaceCount)
                }
            }
        }
    }

    @Test("auto split by wires")
    func autoSplit() {
        // #766: this nested every step in `if let` and asserted `faces >= 6`, which the unsplit
        // box satisfies, so it passed on nil and on no split. Its edge also sat at z = 10, off
        // this centred box (-5...5). Probed (Scripts/repro/766-modeling-locope-spliter-v71): the
        // off-box wire auto-binds to nothing and leaves 6 faces; a wire across the top face
        // (z = 5) auto-binds and splits it, 7 faces.
        guard let b = Shape.box(width: 10, height: 10, depth: 10),
            let onTop = Shape.edgeFromPoints(SIMD3(-5, 0, 5), SIMD3(5, 0, 5)),
            let onTopWire = Shape.makeWire(from: [onTop]),
            let offBox = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10)),
            let offBoxWire = Shape.makeWire(from: [offBox])
        else {
            Issue.record("fixture construction failed")
            return
        }
        guard let split = b.locOpeSplitAuto(wires: [onTopWire]) else {
            Issue.record("locOpeSplitAuto returned nil for a wire across the top face")
            return
        }
        #expect(split.subShapes(ofType: .face).count == 7)
        #expect(split.isValid)
        if let unsplit = b.locOpeSplitAuto(wires: [offBoxWire]) {
            #expect(unsplit.subShapes(ofType: .face).count == 6)
        } else {
            Issue.record("locOpeSplitAuto returned nil for the off-box wire")
        }
    }
}
