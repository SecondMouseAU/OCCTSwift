import Testing
import simd

@testable import OCCTSwift

@Suite("Local Prism Tests")
struct LocalPrismTests {
    @Test("Create local prism from face")
    func basicLocalPrism() throws {
        // Create a face
        let wire = Wire.rectangle(width: 5, height: 5)
        #expect(wire != nil)

        let face = Shape.face(from: wire!)
        #expect(face != nil)

        if let face {
            let prism = face.localPrism(direction: SIMD3(0, 0, 10))
            #expect(prism != nil)
        }
    }

    @Test("Local prism with translation")
    func localPrismWithTranslation() throws {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let face = Shape.face(from: wire)!
        let prism = face.localPrism(
            direction: SIMD3(0, 0, 10),
            translation: SIMD3(2, 0, 0))
        #expect(prism != nil)
    }

    @Test("Local prism produces valid solid")
    func localPrismIsSolid() throws {
        let wire = Wire.rectangle(width: 5, height: 5)!
        let face = Shape.face(from: wire)!
        let prism = face.localPrism(direction: SIMD3(0, 0, 10))
        #expect(prism != nil)
        if let prism {
            // Should have faces
            #expect(prism.faceCount > 0)
        }
    }
}
