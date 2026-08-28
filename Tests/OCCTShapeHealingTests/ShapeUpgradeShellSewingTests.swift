import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ShapeUpgrade ShellSewing Tests")
struct ShapeUpgradeShellSewingTests {
    @Test("Sew shells in box shape")
    func sewBoxShells() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.shellSewing(tolerance: 1e-6)
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }
}
