import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-locations-nurbs-sameparam/probe.mm (transcript.txt beside it).
// Before #766 both tests used `translated(by:)`/`rotated(axis:angle:)`, which transform with a
// copy and leave no location on the shape (kernel: 0 located faces), so RemoveLocations had
// nothing to do and a bridge that returned its input passed. The first test now places the box
// with `moved(dx:dy:dz:)`, which carries the translation as a TopLoc_Location, and pins that the
// shape keeps its placement once the location is folded into the geometry.
@Suite("Remove Locations")
struct RemoveLocationsTests {
    @Test("Remove locations from translated shape")
    func removeFromTranslated() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let moved = try #require(box.moved(dx: 100, dy: 200, dz: 300))
        let flat = try #require(moved.removingLocations())
        #expect(flat.isValid)
        #expect(abs((flat.volume ?? 0) - 1000) < 1e-9)
        let b = try #require(flat.bounds)
        #expect(simd_distance(b.min, SIMD3(95, 195, 295)) < 1e-6)
        #expect(simd_distance(b.max, SIMD3(105, 205, 305)) < 1e-6)
    }

    @Test("Remove locations from rotated shape")
    func removeFromRotated() throws {
        // Rotated (baked into the geometry) and then moved (carried as a location): the kernel
        // keeps the rotated cylinder's bounds, shifted +50 in x, once the location is folded in.
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let rotated = try #require(cyl.rotated(axis: SIMD3(1, 0, 0), angle: .pi / 4))
        let placed = try #require(rotated.moved(dx: 50, dy: 0, dz: 0))
        let flat = try #require(placed.removingLocations())
        #expect(flat.isValid)
        #expect(abs((flat.volume ?? 0) - 785.398163) < 1e-5)
        let b = try #require(flat.bounds)
        #expect(simd_distance(b.min, SIMD3(45, -10.6066, -3.5355)) < 1e-3)
        #expect(simd_distance(b.max, SIMD3(55, 3.5355, 10.6066)) < 1e-3)
    }
}
