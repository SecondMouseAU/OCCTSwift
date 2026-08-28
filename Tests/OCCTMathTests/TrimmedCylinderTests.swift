import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GC_MakeTrimmedCylinder")
struct TrimmedCylinderTests {
    @Test("Trimmed cylinder from axis, radius, height")
    func trimmedCylinder() throws {
        let surf = try #require(Surface.trimmedCylinder(radius: 4.0, height: 8.0))
        #expect(surf.handle != nil)
    }
}

