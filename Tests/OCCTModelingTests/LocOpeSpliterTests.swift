import Testing
import simd

@testable import OCCTSwift

@Suite("LocOpe Spliter")
struct LocOpeSpliterTests {
    @Test("Split shape by wire on face")
    func splitByWireOnFace() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        // Create a wire that crosses a face as Shape
        guard let wire = Wire.line(from: SIMD3(-6, 0, 5), to: SIMD3(6, 0, 5)),
            let wireShape = Shape.fromWire(wire)
        else { return }
        // #766: this tried face indices 1...6, stopped at the first non-nil result and asserted
        // only its validity, then accepted "no face worked" outright, so it passed whether or not
        // anything was split. Probed (Scripts/repro/766-modeling-locope-spliter): index 1 (a side
        // face the line does not lie on) already succeeds with the box unsplit, 6 faces, which is
        // where the loop stopped. The line lies on the top face, index 5 (z = 5), and splitting
        // there gives 7 faces; a face it does not lie on leaves the box's 6.
        guard let top = box.splitByWireOnFace(wireShape, faceIndex: 5) else {
            Issue.record("splitByWireOnFace(faceIndex: 5) returned nil")
            return
        }
        #expect(top.isValid)
        #expect(top.faceCount == 7)
        if let side = box.splitByWireOnFace(wireShape, faceIndex: 1) {
            #expect(side.faceCount == 6)
        } else {
            Issue.record("splitByWireOnFace(faceIndex: 1) returned nil")
        }
        #expect(box.splitByWireOnFace(wireShape, faceIndex: 6) == nil)
    }
}
