import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.51.0 Tests

@Suite("BRepLib_MakeSolid")
struct MakeSolidFromShellTests {
    @Test("Create solid from box shell")
    func solidFromBoxShell() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let shellList = box.shells
        #expect(!shellList.isEmpty)
        if let shell = shellList.first {
            let solid = Shape.solidFromShell(shell)
            #expect(solid != nil)
            if let s = solid {
                #expect(s.isValid)
            }
        }
    }
}
