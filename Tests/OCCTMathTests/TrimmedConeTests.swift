import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCone")
struct TrimmedConeTests {
    @Test("Trimmed cone from endpoints and radii")
    func trimmedCone() throws {
        let surf = try #require(
            Surface.trimmedCone(
                point1: SIMD3(0, 0, 0), point2: SIMD3(0, 0, 10),
                r1: 5.0, r2: 2.0))
        #expect(surf.handle != nil)
    }
}

