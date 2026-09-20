import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeFix_ComposeShell")
struct ShapeFixComposeShellTests {
    @Test("compose shell on planar face")
    func composeShellPlanar() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rect))
        // `if let result { #expect(result.isValid) }` was the whole test until #1638, and it
        // passed on a call that could not split anything and on a nil result alike.
        // Issue1638ComposeShellGridTests carries the grid sweep.
        let result = try #require(face.composeShell())
        #expect(result.isValid)
        #expect(result.subShapes(ofType: .face).count == 1, "the default 1 x 1 grid splits nothing")
    }
}
