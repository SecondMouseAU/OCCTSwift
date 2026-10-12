import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.52.0: BRepFill, LocOpe, Healing Utilities, 2D Curve Tools

// #3332: the two ruled-shell tests asserted `shell != nil` (and validity for one). The wires in
// both were COPLANAR (`Wire.circle(radius:)` and `Wire.rectangle` both lie in z = 0), so the ruled
// shell between them is a flat annulus or frame, which no height-dependent mistake could change.
// Pinned: the planar case by its closed-form area, and an axial variant (the second wire moved
// 10 up) by the lateral area of the cone frustum / pyramid frustum it ruled.
@Suite("BRepFill Generator Tests")
struct BRepFillGeneratorTests {
    @Test("Ruled shell from two circular wires")
    func twoCircleWires() throws {
        let outer = try #require(Wire.circle(radius: 10))
        let inner = try #require(Wire.circle(radius: 5))
        let shell = try #require(Shape.ruledShell(from: [outer, inner]))
        #expect(shell.isValid)
        #expect(shell.shapeType == .shell)
        #expect(shell.faceCount == 1)
        // Coplanar: the annulus between r = 5 and r = 10.
        let area = try #require(shell.surfaceArea)
        #expect(abs(area - Double.pi * (100 - 25)) < 1e-6)

        // Axial: r = 5 at z = 0 and r = 3 at z = 10 is a cone frustum of lateral area
        // pi (r1 + r2) sqrt(h^2 + (r1 - r2)^2).
        let bottom = try #require(Wire.circle(radius: 5))
        let top = try #require(
            Wire.circle(origin: SIMD3(0, 0, 10), normal: SIMD3(0, 0, 1), radius: 3))
        let frustum = try #require(Shape.ruledShell(from: [bottom, top]))
        #expect(frustum.isValid)
        let frustumArea = try #require(frustum.surfaceArea)
        #expect(abs(frustumArea - Double.pi * 8 * (100.0 + 4.0).squareRoot()) < 1e-6)
        let bounds = try #require(frustum.bounds)
        #expect(abs(bounds.max.z - 10) < 1e-3)
    }

    @Test("Ruled shell from two rectangular wires")
    func twoRectWires() throws {
        let inner = try #require(Wire.rectangle(width: 10, height: 10))
        let outer = try #require(Wire.rectangle(width: 15, height: 15))
        let shell = try #require(Shape.ruledShell(from: [inner, outer]))
        #expect(shell.isValid)
        // Coplanar: the frame between the 10 and 15 squares, four faces, 225 - 100.
        #expect(shell.faceCount == 4)
        let area = try #require(shell.surfaceArea)
        #expect(abs(area - 125) < 1e-6)

        // Axial: the 15 square lifted to z = 10 is a pyramid frustum of four trapezoids, each
        // (10 + 15) / 2 wide-averaged over the slant sqrt(10^2 + 2.5^2).
        let lifted = try #require(
            Wire.polygon3D(
                [
                    SIMD3(-7.5, -7.5, 10), SIMD3(7.5, -7.5, 10), SIMD3(7.5, 7.5, 10),
                    SIMD3(-7.5, 7.5, 10),
                ], closed: true))
        let frustum = try #require(Shape.ruledShell(from: [inner, lifted]))
        #expect(frustum.faceCount == 4)
        let frustumArea = try #require(frustum.surfaceArea)
        let slant = (100.0 + 2.5 * 2.5).squareRoot()
        #expect(abs(frustumArea - 4 * (10.0 + 15.0) / 2 * slant) < 1e-6)
    }

    @Test("Returns nil with fewer than 2 wires")
    func needsAtLeastTwo() {
        let w1 = Wire.rectangle(width: 10, height: 10)!
        let result = Shape.ruledShell(from: [w1])
        #expect(result == nil)
    }
}
