import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-locations-nurbs-sameparam/probe.mm (transcript.txt beside it).
// Before #766 these asserted non-nil and `nurbs!.isValid`, a force-unwrap inside `#expect`, and
// an unconverted input passed both. They now pin that every face is a BSpline afterwards.
private func bsplineFaceCount(_ shape: Shape) -> Int {
    shape.faces().filter { $0.surfaceType == .bsplineSurface }.count
}

@Suite("NURBS Conversion")
struct NURBSConversionTests {
    @Test("Convert box to NURBS")
    func convertBox() throws {
        let box = try #require(Shape.box(width: 10, height: 5, depth: 3))
        let nurbs = try #require(box.convertedToNURBS())
        #expect(nurbs.isValid)
        #expect(bsplineFaceCount(nurbs) == 6)
        #expect(abs((nurbs.volume ?? 0) - 150) < 1e-9)
    }

    @Test("Convert sphere to NURBS")
    func convertSphere() throws {
        // Kernel: 1 BSpline face; the approximation moves the volume from 523.598776 to 523.369781.
        let sphere = try #require(Shape.sphere(radius: 5))
        let nurbs = try #require(sphere.convertedToNURBS())
        #expect(nurbs.isValid)
        #expect(bsplineFaceCount(nurbs) == 1)
        #expect(abs((nurbs.volume ?? 0) - 523.369781) < 1e-5)
    }

    @Test("Convert filleted box to NURBS")
    func convertFilleted() throws {
        let filleted = try #require(Shape.box(width: 10, height: 10, depth: 10)?.filleted(radius: 1))
        let nurbs = try #require(filleted.convertedToNURBS())
        #expect(nurbs.isValid)
        #expect(bsplineFaceCount(nurbs) == 26)
        #expect(abs((nurbs.volume ?? 0) - 975.587014) < 1e-5)
    }
}
