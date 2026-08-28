import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Hatch Builder Tests")
struct HatchBuilderTests {

    @Test func createHatcher() {
        let hatcher = HatchBuilder(tolerance: 1e-6)
        #expect(hatcher != nil)
    }

    @Test func addLinesAndCount() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addXLine(0.0)
            hatcher.addXLine(5.0)
            hatcher.addXLine(10.0)
            #expect(hatcher.nbLines == 3)
        }
    }

    @Test func addYLines() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addYLine(0.0)
            hatcher.addYLine(5.0)
            #expect(hatcher.nbLines == 2)
        }
    }

    @Test func trimAndIntervals() {
        if let hatcher = HatchBuilder(tolerance: 1e-6) {
            hatcher.addXLine(0.0)
            hatcher.addXLine(5.0)
            hatcher.addXLine(10.0)
            hatcher.trim(x1: -1, y1: -1, x2: 11, y2: 11)
            if hatcher.nbLines > 0 {
                let nInt = hatcher.nbIntervals(lineIndex: 1)
                #expect(nInt >= 0)
            }
        }
    }
}
