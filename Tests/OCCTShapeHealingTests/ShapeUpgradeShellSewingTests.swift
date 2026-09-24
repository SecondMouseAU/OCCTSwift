import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: before #766 this force-unwrapped the fixture and asserted only non-nil and valid inside
// `if let`. ShapeUpgrade_ShellSewing::ApplySewing on the box at 1e-6 returns a new, valid solid
// with the box's 6 faces and volume 1000 (Scripts/repro/766-healing-shapeupgrade/transcript.txt).

@Suite("ShapeUpgrade ShellSewing Tests")
struct ShapeUpgradeShellSewingTests {

    @Test("Sew shells in box shape")
    func sewBoxShells() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.shellSewing(tolerance: 1e-6))
        #expect(result.isValid)
        #expect(result.shapeType == .solid)
        #expect(result.faces().count == 6)
        #expect(abs((result.volume ?? 0) - 1000) < 1e-6)
    }
}
