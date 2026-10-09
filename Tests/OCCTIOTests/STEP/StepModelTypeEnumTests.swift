import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - STEP Model Type Enum Tests (v0.58.0)

@Suite("StepModelType Enum")
struct StepModelTypeEnumTests {

    @Test("StepModelType raw values")
    func rawValues() {
        #expect(StepModelType.asIs.rawValue == 0)
        #expect(StepModelType.manifoldSolidBrep.rawValue == 1)
        #expect(StepModelType.brepWithVoids.rawValue == 2)
        #expect(StepModelType.facetedBrep.rawValue == 3)
        #expect(StepModelType.facetedBrepAndBrepWithVoids.rawValue == 4)
        #expect(StepModelType.shellBasedSurfaceModel.rawValue == 5)
        #expect(StepModelType.geometricCurveSet.rawValue == 6)
    }

    @Test("StepModelType init from raw value")
    func initFromRaw() {
        #expect(StepModelType(rawValue: 0) == .asIs)
        #expect(StepModelType(rawValue: 1) == .manifoldSolidBrep)
        #expect(StepModelType(rawValue: 5) == .shellBasedSurfaceModel)
        #expect(StepModelType(rawValue: 99) == nil)
    }
}
