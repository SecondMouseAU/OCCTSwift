import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are the kernel's own answers to the same calls, from
// Scripts/repro/766-healing-locations-nurbs-sameparam/probe.mm (transcript.txt beside it).
// Before #766 two of these asserted only non-nil (one inside `if let`) and the third
// force-unwrapped `result!.volume!`.
@Suite("Same Parameter")
struct SameParameterTests {
    @Test("Same parameter on box")
    func sameParameterBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(box.sameParameter())
        #expect(r.isValid)
        #expect(r.faces().count == 6)
    }

    @Test("Same parameter on cylinder")
    func sameParameterCylinder() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let r = try #require(cyl.sameParameter())
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 785.398163397) < 1e-6)
    }

    @Test("Same parameter preserves volume")
    func sameParameterPreservesVolume() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let result = try #require(box.sameParameter())
        #expect(abs((result.volume ?? 0) - 1000.0) < 1e-9)
    }
}
