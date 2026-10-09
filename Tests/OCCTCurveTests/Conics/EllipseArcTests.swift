import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Ellipse Arc Tests")
struct EllipseArcTests {

    @Test("Arc of ellipse from angles")
    func arcFromAngles() {
        // Ellipse with major radius 10, minor radius 5 in XY plane
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
        if let arc {
            // Start point should be on major axis: (10, 0, 0)
            let start = arc.startPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(start.y) < 0.1)
            // End point should be on minor axis: (0, 5, 0)
            let end = arc.endPoint
            #expect(abs(end.x) < 0.1)
            #expect(abs(end.y - 5.0) < 0.1)
        }
    }

    @Test("Arc of ellipse between two points")
    func arcBetweenPoints() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            from: SIMD3(10, 0, 0),
            to: SIMD3(-10, 0, 0)
        )
        #expect(arc != nil)
        if let arc {
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(end.x + 10.0) < 0.1)
        }
    }

    @Test("Full semi-ellipse arc")
    func semiEllipse() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi
        )
        #expect(arc != nil)
        if let arc {
            // Start at (10,0,0), end at (-10,0,0)
            let start = arc.startPoint
            let end = arc.endPoint
            #expect(abs(start.x - 10.0) < 0.1)
            #expect(abs(end.x + 10.0) < 0.1)
        }
    }

    @Test("Ellipse arc properties")
    func arcProperties() {
        let arc = Curve3D.arcOfEllipse(
            center: SIMD3(0, 0, 0),
            normal: SIMD3(0, 0, 1),
            majorRadius: 10,
            minorRadius: 5,
            startAngle: 0,
            endAngle: .pi / 2
        )
        #expect(arc != nil)
        if let arc {
            #expect(!arc.isClosed)
            let start = arc.startPoint
            let end = arc.endPoint
            // Length of quarter-ellipse arc should be reasonable
            #expect(start.x > 9.0)
            #expect(end.y > 4.0)
        }
    }
}
