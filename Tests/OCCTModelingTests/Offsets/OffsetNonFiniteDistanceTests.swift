import Foundation
import Testing

@testable import OCCTSwift

/// A NaN or infinite offset distance is refused with `nil` on the shape offset and shell
/// entry points.
///
/// #3455: `Shape.offset(by: .nan, joinType: .arc)` never returned for a box and faulted for a
/// cylinder, and the simple `offset(by:)` returned a shape built on NaN geometry. Finite
/// extremes all return, so only the non-finite values are refused.
struct OffsetNonFiniteDistanceTests {
    private static let nonFinite: [Double] = [.nan, .infinity, -.infinity]

    @Test func arcJoinOffsetRefusesNonFiniteDistance() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10),
            let cylinder = Shape.cylinder(radius: 5, height: 10)
        else {
            Issue.record("primitive construction failed")
            return
        }
        for d in Self.nonFinite {
            for shape in [box, cylinder] {
                for join in [Shape.OffsetJoinType.arc, .tangent, .intersection] {
                    #expect(shape.offset(by: d, joinType: join) == nil)
                }
            }
        }
    }

    @Test func nonFiniteToleranceIsRefused() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        #expect(box.offset(by: 1.0, tolerance: .nan, joinType: .arc) == nil)
        #expect(box.offset(by: 1.0, tolerance: .infinity, joinType: .arc) == nil)
    }

    @Test func simpleOffsetAndShellRefuseNonFiniteDistance() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        for d in Self.nonFinite {
            #expect(box.offset(by: d) == nil)
            #expect(box.shelled(thickness: d) == nil)
        }
    }

    @Test func finiteOffsetStillWorks() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        #expect(box.offset(by: 1.0, joinType: .arc) != nil)
        #expect(box.offset(by: 1.0) != nil)
    }
}
