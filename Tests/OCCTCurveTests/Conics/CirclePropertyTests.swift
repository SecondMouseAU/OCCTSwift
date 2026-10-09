import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.143 M4: Circle extraction

@Suite("v0.143 Circle property extraction")
struct CirclePropertyTests {
    @Test("Cylindrical face exposes revolutionProperties with correct radius")
    func cylinderRevolutionRadius() {
        guard let cyl = Shape.cylinder(radius: 5, height: 10) else {
            Issue.record("cyl nil")
            return
        }
        for face in cyl.faces() where face.surfaceType == .cylinder {
            if let rp = face.revolutionProperties {
                #expect(abs(rp.radius - 5.0) < 1e-6)
                #expect(rp.axis.kind == .cylinder)
                return
            }
        }
        Issue.record("no cylindrical face found")
    }

    @Test("Circle through three points recovers correct centre and radius")
    func threePointCircle() {
        let p1 = SIMD3<Double>(1, 0, 0)
        let p2 = SIMD3<Double>(0, 1, 0)
        let p3 = SIMD3<Double>(-1, 0, 0)
        guard let circle = circleThroughThreePoints(p1, p2, p3) else {
            Issue.record("collinear")
            return
        }
        #expect(abs(simd_length(circle.center - SIMD3<Double>(0, 0, 0))) < 1e-9)
        #expect(abs(circle.radius - 1.0) < 1e-9)
    }

    @Test("Three collinear points → nil circle")
    func collinearPointsNil() {
        let p1 = SIMD3<Double>(0, 0, 0)
        let p2 = SIMD3<Double>(1, 0, 0)
        let p3 = SIMD3<Double>(2, 0, 0)
        #expect(circleThroughThreePoints(p1, p2, p3) == nil)
    }

    @Test("Edge.circleProperties recovers a full-circle cap edge (#378)")
    func edgeCirclePropertiesFullCircle() {
        guard let cyl = Shape.cylinder(radius: 3, height: 8) else {
            Issue.record("cyl nil")
            return
        }
        var foundCircle = false
        for edge in cyl.edges() where edge.isCircle {
            guard let bounds = edge.parameterBounds else { continue }
            #expect(abs((bounds.last - bounds.first) - 2 * .pi) < 1e-6)
            if let props = edge.circleProperties {
                #expect(abs(props.radius - 3.0) < 1e-6)
                #expect(props.isFullCircle)
                foundCircle = true
            } else {
                Issue.record("circleProperties nil for full-circle edge")
            }
        }
        #expect(foundCircle)
    }
}
