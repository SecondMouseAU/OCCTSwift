import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.41.0: Geometry Conversion

@Suite("ShapeCustom Geometry Conversion")
struct GeometryConversionTests {
    @Test("Convert cylinder to BSpline surfaces")
    func cylinderToBSpline() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.withSurfacesAsBSpline()
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(result.faces().count == cyl.faces().count)
        }
    }

    @Test("Convert to revolution surfaces")
    func toRevolution() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.withSurfacesAsRevolution()
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
        }
    }

    @Test("BSpline conversion preserves volume")
    func bsplinePreservesVolume() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let volBefore = cyl.volume!
        let result = cyl.withSurfacesAsBSpline()!
        let volAfter = result.volume!
        // Volume should be approximately preserved
        #expect(abs(volBefore - volAfter) / volBefore < 0.01)
    }
}
