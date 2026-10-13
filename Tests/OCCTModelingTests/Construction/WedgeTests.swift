import Testing

@testable import OCCTSwift

// MARK: - v0.29.0 New Features

@Suite("Wedge Primitive")
struct WedgeTests {
    @Test("Create basic wedge")
    func basicWedge() throws {
        let wedge = try #require(Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 4))
        #expect(wedge.isValid)
        // A trapezoid of parallel sides 10 and 4 over dz = 8, extruded dy = 5:
        // 5 * 8 * (10 + 4) / 2 = 280, with six faces and 284.4819... of surface (kernel.6).
        #expect(abs((wedge.volume ?? -1) - 280.0) < 1e-6)
        #expect(abs((wedge.surfaceArea ?? -1) - 284.48199740725323) < 1e-6)
        #expect(wedge.faces().count == 6)
    }

    @Test("Wedge with zero ltx is a pyramid")
    func pyramidWedge() throws {
        let pyramid = try #require(Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 0))
        #expect(pyramid.isValid)
        // The top edge collapses to a point: a triangle of base 10 and height 8, depth 5, so
        // 5 * 8 * 10 / 2 = 200 and one face fewer than the full wedge (kernel.6: 5 faces).
        #expect(abs((pyramid.volume ?? -1) - 200.0) < 1e-6)
        #expect(pyramid.faces().count == 5)
    }

    @Test("Wedge with ltx=dx is a box")
    func boxWedge() throws {
        let box = try #require(Shape.wedge(dx: 10, dy: 5, dz: 8, ltx: 10))
        #expect(box.isValid)
        // ltx = dx is the plain 10 x 5 x 8 box: volume 400, area 2 * (50 + 80 + 40) = 340.
        #expect(abs((box.volume ?? -1) - 400.0) < 1e-6)
        #expect(abs((box.surfaceArea ?? -1) - 340.0) < 1e-6)
        #expect(box.faces().count == 6)
    }

    @Test("Advanced wedge with custom top bounds")
    func advancedWedge() throws {
        let wedge = try #require(
            Shape.wedge(dx: 10, dy: 5, dz: 8, xmin: 2, zmin: 1, xmax: 8, zmax: 6))
        #expect(wedge.isValid)
        // Linear interpolation from the 10 x 8 base to the 6 x 5 top over dy = 5 is a prismatoid:
        // h / 6 * (A1 + 4 * Amid + A2), Amid = 8 x 6.5 = 52, so 5 / 6 * (80 + 208 + 30) = 265.
        let expected = 5.0 / 6.0 * (80.0 + 4.0 * 52.0 + 30.0)
        #expect(abs((wedge.volume ?? -1) - expected) < 1e-6)
        #expect(abs((wedge.surfaceArea ?? -1) - 263.8806170585669) < 1e-6)
        #expect(wedge.faces().count == 6)
    }

    @Test("Invalid parameters return nil")
    func invalidWedge() {
        #expect(Shape.wedge(dx: 0, dy: 5, dz: 8, ltx: 4) == nil)
        #expect(Shape.wedge(dx: 10, dy: -1, dz: 8, ltx: 4) == nil)
    }
}
