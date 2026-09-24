import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: expected values are BRepLib::UpdateTolerances's own answers on a copy of the same shapes,
// from Scripts/repro/766-healing-small-files/probe.mm. Before #766 these asserted non-nil, then
// validity or volume inside `if let`, with a force-unwrap and a volume tolerance of 1.0. The
// kernel raises the maximum tolerance from 1e-7 to 1.00000002e-6, which an untouched
// copy would not show.
@Suite("Update Tolerances")
struct UpdateTolerancesTests {
    @Test("Update tolerances on box")
    func updateTolerancesBox() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let r = try #require(box.updatingTolerances())
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 1000) < 1e-9)
        #expect(abs(r.toleranceValue(mode: .maximum) - 1.00000002e-6) < 1e-12)
        #expect(abs(box.toleranceValue(mode: .maximum) - 1e-7) < 1e-15)  // the input keeps its own 1e-7
    }

    @Test("Update tolerances preserves geometry")
    func updateTolerancesPreservesVolume() throws {
        let cyl = try #require(Shape.cylinder(radius: 5, height: 10))
        let r = try #require(cyl.updatingTolerances())
        #expect(r.isValid)
        #expect(abs((r.volume ?? 0) - 785.398163397) < 1e-6)
        #expect(abs(r.toleranceValue(mode: .maximum) - 1.00000002e-6) < 1e-12)
    }
}
