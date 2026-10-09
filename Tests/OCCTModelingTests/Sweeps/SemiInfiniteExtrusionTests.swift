import Testing
import simd

@testable import OCCTSwift

@Suite("Semi-Infinite Extrusion")
struct SemiInfiniteExtrusionTests {
    @Test("Semi-infinite extrusion of face")
    func semiInfiniteExtrusion() {
        let face = Shape.face(from: Wire.rectangle(width: 5, height: 5)!)!
        let result = face.extrudedSemiInfinite(direction: SIMD3(0, 0, 1))
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("Infinite (both directions) extrusion of face")
    func infiniteExtrusion() {
        let face = Shape.face(from: Wire.circle(radius: 3)!)!
        let result = face.extrudedSemiInfinite(direction: SIMD3(1, 0, 0), infinite: true)
        // Infinite prisms are constructed successfully but fail BRepCheck validation
        // (infinite geometry is inherently unbounded). Just verify construction succeeds.
        #expect(result != nil)
    }

    @Test("Semi-infinite extrusion of wire")
    func semiInfiniteWireExtrusion() {
        let wire = Wire.line(from: SIMD3(0, 0, 0), to: SIMD3(10, 0, 0))!
        let wireShape = Shape.fromWire(wire)!
        let result = wireShape.extrudedSemiInfinite(direction: SIMD3(0, 1, 0))
        #expect(result != nil)
    }
}
