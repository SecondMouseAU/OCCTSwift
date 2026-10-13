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

    /// A half-infinite surface is refused, not built.
    ///
    /// `BRepLib_MakeShell` builds an edge for each finite parametric boundary of the surface. An
    /// infinite cylinder or cone is bounded in `u` and unbounded in `v`, so it gets seam edges
    /// whose range is +-1e100, and `BRepLib::BuildCurves3d` then recurses in
    /// `AdvApprox_SimpleApprox::Perform` until the stack is gone: the process dies with no Swift
    /// error (#3360, `Scripts/repro/3360/probe.mm`). The bridge refuses a surface unbounded in
    /// exactly one direction. A surface unbounded in both (the plane) gets no edges at all and is
    /// still built.
    @Test("shell(from:) refuses a surface unbounded in one direction instead of crashing")
    func shellFromHalfInfiniteSurface() throws {
        let cyl = try #require(Surface.cylinder(origin: .zero, axis: SIMD3(0, 0, 1), radius: 3))
        #expect(Shape.shell(from: cyl) == nil)

        let cone = try #require(
            Surface.cone(origin: .zero, axis: SIMD3(0, 0, 1), radius: 1, semiAngle: 0.3))
        #expect(Shape.shell(from: cone) == nil)

        // The neighbours that must keep working: fully bounded in v (sphere), unbounded in both
        // (plane).
        let sphere = try #require(Surface.sphere(center: .zero, radius: 5))
        #expect(Shape.shell(from: sphere) != nil)
        let plane = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        #expect(Shape.shell(from: plane) != nil)
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
