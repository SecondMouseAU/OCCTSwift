import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Update Tolerances")
struct UpdateTolerancesTests {
    @Test("Update tolerances on box")
    func updateTolerancesBox() {
        let box = Shape.box(width: 10, height: 10, depth: 10)!
        let result = box.updatingTolerances()
        #expect(result != nil)
        if let r = result {
            #expect(r.isValid)
        }
    }

    @Test("Update tolerances preserves geometry")
    func updateTolerancesPreservesVolume() {
        let cyl = Shape.cylinder(radius: 5, height: 10)!
        let result = cyl.updatingTolerances()
        #expect(result != nil)
        if let r = result {
            #expect(abs(r.volume! - cyl.volume!) < 1.0)
        }
    }
}
