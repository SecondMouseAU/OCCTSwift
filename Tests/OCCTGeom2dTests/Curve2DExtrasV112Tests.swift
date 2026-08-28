import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D extras v0.112")
struct Curve2DExtrasV112Tests {

    @Test func curveType() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            #expect(line.curveType == 0)  // Line
        }
        if let circle = Curve2D.circle(center: SIMD2(0, 0), radius: 5) {
            #expect(circle.curveType == 1)  // Circle
        }
    }

    @Test func nearestParameterOnLine() {
        if let line = Curve2D.line(through: SIMD2(0, 0), direction: SIMD2(1, 0)) {
            let param = line.nearestParameter(to: SIMD2(5, 0))
            #expect(param != nil)
            if let param { #expect(abs(param - 5.0) < 0.1) }
        }
    }
}
