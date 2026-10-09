import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepTools Modifier")
struct BRepToolsModifierTests {
    @Test("NURBS convert via Modifier")
    func nurbsConvertViaModifier() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else { return }
        let result = cyl.nurbsConvertViaModifier()
        #expect(result != nil)
        if let result = result { #expect(result.isValid) }
    }
}
