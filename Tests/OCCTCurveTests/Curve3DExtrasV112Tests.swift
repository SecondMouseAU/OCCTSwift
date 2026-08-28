import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve3D extras v0.112")
struct Curve3DExtrasV112Tests {

    @Test func curveType() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            #expect(line.curveType == 0)  // Line
        }
        if let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5) {
            #expect(circle.curveType == 1)  // Circle
        }
    }

    @Test func nearestParameterOnLine() {
        if let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) {
            let param = line.nearestParameter(to: SIMD3(5, 0, 0))
            #expect(param != nil)
            if let param { #expect(abs(param - 5.0) < 0.1) }
        }
    }
}
