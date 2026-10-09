import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("Shell and Vertex Creation")
struct ShellVertexTests {
    @Test("Create shell from surface")
    func shellFromSurface() {
        let surf = Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1))
        #expect(surf != nil)
        if let s = surf {
            let shell = Shape.shell(from: s)
            #expect(shell != nil)
        }
    }

    @Test("Create vertex at point")
    func vertexAtPoint() {
        let v = Shape.vertex(at: SIMD3(5, 10, 15))
        #expect(v != nil)
        #expect(v!.isValid)
    }
}
