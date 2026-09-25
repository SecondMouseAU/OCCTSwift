import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe_Spliter v71 Tests")
struct LocOpeSpliterV71Tests {
    @Test("split by wire on face")
    func splitByWireOnFace() throws {
        // Use origin-based box so coordinates are predictable
        let b = try #require(Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10))
        let faces = b.subShapes(ofType: .face)
        let origFaceCount = faces.count
        // Edge on top face (Z=10), endpoints on face edges
        let e = try #require(Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10)))
        let w = try #require(Shape.makeWire(from: [e]))
        // #766: this nested every step in `if let`, so a fixture that failed to build skipped the
        // test, took the best count over whichever faces happened to succeed, and asserted only
        // `best > original`. Pinned to the kernel (Scripts/repro/766-modeling-locope-spliter-v71):
        // the edge is bound to each of the six faces in turn and LocOpe_Spliter returns a valid
        // shape for every one of them, six faces for the five it does not lie on and seven for the
        // top face (index 5, z = 10) that it splits. Each face must produce a result, and the
        // counts are exact, so a bridge that split nothing, or returned nil, no longer passes.
        #expect(origFaceCount == 6)
        var faceCounts: [Int] = []
        for face in faces {
            let r = try #require(b.locOpeSplit(wiresOnFaces: [(wire: w, face: face)]))
            faceCounts.append(r.shape.subShapes(ofType: .face).count)
            #expect(r.shape.isValid)
        }
        #expect(faceCounts == [6, 6, 6, 6, 6, 7])
        #expect((faceCounts.max() ?? 0) > origFaceCount)
    }

    @Test("auto split by wires")
    func autoSplit() throws {
        // #766: this nested every step in `if let` and asserted `faces >= 6`, which the unsplit
        // box satisfies, so it passed on nil and on no split. Its edge also sat at z = 10, off
        // this centred box (-5...5). Probed (Scripts/repro/766-modeling-locope-spliter-v71): the
        // off-box wire auto-binds to nothing and leaves 6 faces; a wire across the top face
        // (z = 5) auto-binds and splits it, 7 faces.
        let b = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let onTop = try #require(Shape.edgeFromPoints(SIMD3(-5, 0, 5), SIMD3(5, 0, 5)))
        let onTopWire = try #require(Shape.makeWire(from: [onTop]))
        let offBox = try #require(Shape.edgeFromPoints(SIMD3(0, 5, 10), SIMD3(10, 5, 10)))
        let offBoxWire = try #require(Shape.makeWire(from: [offBox]))
        let split = try #require(b.locOpeSplitAuto(wires: [onTopWire]))
        #expect(split.subShapes(ofType: .face).count == 7)
        #expect(split.isValid)
        let unsplit = try #require(b.locOpeSplitAuto(wires: [offBoxWire]))
        #expect(unsplit.subShapes(ofType: .face).count == 6)
    }
}
