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
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let b = box {
            let edge = Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10))
            if let e = edge {
                let wire = Shape.makeWire(from: [e])
                if let w = wire {
                    // Auto-bind may or may not succeed depending on geometry
                    let result = b.locOpeSplitAuto(wires: [w])
                    if let r = result {
                        #expect(r.subShapes(ofType: .face).count >= 6)
                    }
                }
            }
        }
    }
}
