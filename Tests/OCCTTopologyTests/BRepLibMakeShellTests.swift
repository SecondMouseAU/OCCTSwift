import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib MakeShell")
struct BRepLibMakeShellTests {
    /// Before #1981 this asserted only non-nil and `isValid`, so a shell over the wrong UV range
    /// passed. BRepLib_MakeShell gives one face of area 100 here
    /// (Scripts/repro/766-topology-breplib-builders/transcript.txt).
    @Test("Shell from plane surface")
    func shellFromPlane() throws {
        let shell = try #require(
            Shape.shellFromPlane(
                origin: SIMD3(0, 0, 0),
                normal: SIMD3(0, 0, 1),
                uRange: 0...10,
                vRange: 0...10
            ))
        #expect(shell.isValid)
        #expect(shell.shapeType == .shell)
        #expect(shell.faces().count == 1)
        let area = try #require(shell.surfaceArea)
        #expect(abs(area - 100) < 1e-9, "area \(area)")
    }
}
