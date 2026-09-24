import Foundation
import Testing
import simd

@testable import OCCTSwift

// The earlier versions sat inside `if let`, and nearestParameterOnLine allowed 0.1 of slack
// (#766). GeomAdaptor_Curve::GetType and the projection of (5, 0, 0) onto the X axis
// (Scripts/repro/766-curve-extras-interp/transcript.txt) give the values pinned here.
@Suite("Curve3D extras v0.112")
struct Curve3DExtrasV112Tests {
    @Test func curveType() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)),
            let circle = Curve3D.circle(center: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 5)
        else {
            Issue.record("line or circle not built")
            return
        }
        #expect(line.curveType == 0)  // Line
        #expect(circle.curveType == 1)  // Circle
    }

    @Test func nearestParameterOnLine() {
        guard let line = Curve3D.line(through: SIMD3(0, 0, 0), direction: SIMD3(1, 0, 0)) else {
            Issue.record("line not built")
            return
        }
        guard let param = line.nearestParameter(to: SIMD3(5, 0, 0)) else {
            Issue.record("nearestParameter returned nil")
            return
        }
        #expect(abs(param - 5.0) < 1e-9)
    }
}
