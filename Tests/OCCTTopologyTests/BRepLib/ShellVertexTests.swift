import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("Shell and Vertex Creation")
struct ShellVertexTests {
    @Test("Create shell from surface")
    func shellFromSurface() throws {
        let surf = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let shell = try #require(Shape.shell(from: surf))
        #expect(shell.shapeType == .shell)
        #expect(shell.faces().count == 1)

        // A bounded surface gives a shell with real extent (the plane's is +-1e100).
        let sphere = try #require(Surface.sphere(center: .zero, radius: 5))
        let sphereShell = try #require(Shape.shell(from: sphere))
        #expect(sphereShell.shapeType == .shell)
        #expect(sphereShell.faces().count == 1)
        #expect(abs((sphereShell.surfaceArea ?? 0) - 100 * Double.pi) < 1e-6)
    }

    @Test("Create vertex at point")
    func vertexAtPoint() throws {
        let v = try #require(Shape.vertex(at: SIMD3(5, 10, 15)))
        #expect(v.isValid)
        #expect(v.shapeType == .vertex)
        let points = v.vertices()
        #expect(points.count == 1)
        if points.count == 1 {
            #expect(vectorLength(points[0] - SIMD3(5, 10, 15)) < 1e-12)
        }
    }
}
