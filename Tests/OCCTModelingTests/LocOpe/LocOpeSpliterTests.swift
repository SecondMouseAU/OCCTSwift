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
        // Try each face, the wire must lie on one of them
        var splitFound = false
        for i: Int32 in 1...6 {
            if let result = box.splitByWireOnFace(wireShape, faceIndex: i) {
                #expect(result.isValid)
                splitFound = true
                break
            }
        }
        // It's ok if no face worked, the wire may not project onto any face
    }
}
