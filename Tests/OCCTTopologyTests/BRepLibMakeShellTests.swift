import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib MakeShell")
struct BRepLibMakeShellTests {
    @Test("Shell from plane surface")
    func shellFromPlane() {
        let shell = Shape.shellFromPlane(
            origin: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            uRange: 0...10,
            vRange: 0...10
        )
        #expect(shell != nil)
        if let shell = shell { #expect(shell.isValid) }
    }
}
