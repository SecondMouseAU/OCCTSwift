import Foundation
import Testing
import simd

@testable import OCCTSwift

/// `pointInside`/`pointOutside` used to live here, duplicating the exact same fixture and
/// assertions `Issue840ClassifyPoint2dToleranceTests.wellInsideUnaffected`/`.wellOutsideUnaffected`
/// already cover (plus an additional `Face.classify` cross-check that suite has and this one
/// didn't), removed as a strict subset, see #1257. `isHoleCheck` has no equivalent elsewhere and
/// stays.
@Suite("IntTools_FClass2d Tests")
struct IntToolsFClass2dTests {
    @Test("IsHole check")
    func isHoleCheck() throws {
        // #1979: two nested `if let`s let a nil plane or face pass; now required.
        let s = try #require(Surface.plane(origin: .zero, normal: SIMD3(0, 0, 1)))
        let f = try #require(Shape.face(from: s, uRange: 0...10, vRange: 0...10))
        #expect(!f.isHole())
    }
}
