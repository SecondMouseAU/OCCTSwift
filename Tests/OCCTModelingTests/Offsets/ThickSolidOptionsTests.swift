import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

@Suite("v0.114.0 - ThickSolid Options")
struct ThickSolidOptionsTests {

    // Removing face 0 of a 20 mm cube and thickening inward by 2 leaves a cup with walls of 2
    // and the removed side open: 20^3 - 16 * 16 * 18 = 3392, eleven faces (five outer, five
    // inner, one rim). The planar faces make Arc and Intersection joins identical here.
    @Test func thickSolidWithOptions() throws {
        let box = try #require(Shape.box(width: 20, height: 20, depth: 20))
        let faces = box.subShapes(ofType: .face)
        let removed = try #require(faces.first)
        for joinType in [Shape.OffsetJoinType.arc, .intersection] {
            let result = try #require(
                box.thickSolid(
                    facesToRemove: [removed],
                    offset: -2.0,
                    tolerance: 1e-3,
                    joinType: joinType))
            #expect(result.isValid)
            #expect(abs((result.volume ?? -1) - 3392.0) < 1e-6, "\(joinType)")
            #expect(result.faces().count == 11, "\(joinType)")
        }
    }
}
