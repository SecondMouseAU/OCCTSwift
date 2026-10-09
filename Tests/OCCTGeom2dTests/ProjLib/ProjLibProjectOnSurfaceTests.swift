import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("ProjLib_ProjectOnSurface Tests")
struct ProjLibProjectOnSurfaceTests {
    @Test func projectLineOnCylinder() {
        if let line = Curve3D.line(through: SIMD3(5, 0, 0), direction: SIMD3(0, 1, 1)),
            let cyl = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5.0)
        {
            if let projected = line.projectOnSurface(cyl, range: 0...10) {
                let domain = projected.domain
                #expect(domain.upperBound > domain.lowerBound)
            }
        }
    }
}
