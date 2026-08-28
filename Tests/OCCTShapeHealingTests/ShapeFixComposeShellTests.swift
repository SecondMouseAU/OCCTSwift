import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix_ComposeShell")
struct ShapeFixComposeShellTests {
    @Test("compose shell on planar face")
    func composeShellPlanar() {
        if let rect = Wire.rectangle(width: 10, height: 10),
            let face = Shape.face(from: rect)
        {
            if let result = face.composeShell() {
                #expect(result.isValid)
            }
        }
    }
}
