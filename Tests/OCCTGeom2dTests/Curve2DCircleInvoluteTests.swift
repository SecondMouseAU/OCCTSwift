import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Curve2D — Circle Involute")
struct Curve2DCircleInvoluteTests {

    @Test func createCircleInvolute() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0)
        #expect(curve != nil)
        #expect(curve?.isPeriodic == false)  // Involute is not periodic
        #expect(curve?.isClosed == false)  // Involute is not closed
    }

    @Test func createCircleInvoluteRejectsZeroRadius() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 0)
        #expect(curve == nil)
    }

    @Test func createCircleInvoluteRejectsNegativeRadius() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: -1.0)
        #expect(curve == nil)
    }

    @Test func circleInvolutePointAtZero() {
        guard let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0)
        else {
            #expect(Bool(false), "Failed to create circle involute")
            return
        }
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // At first parameter (0), C(0) = R*(1, 0) = (2, 0)
        #expect(abs(p.x - 2.0) < 1e-10)
        #expect(abs(p.y) < 1e-10)
    }

    @Test func circleInvoluteTranslated() {
        guard
            let curve = Curve2D.circleInvolute(
                origin: SIMD2(10, 20), direction: SIMD2(1, 0), radius: 2.0)
        else {
            #expect(Bool(false), "Failed to create circle involute")
            return
        }
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // C(0) = (10, 20) + 2*(1, 0) = (12, 20)
        #expect(abs(p.x - 12.0) < 1e-10)
        #expect(abs(p.y - 20.0) < 1e-10)
    }

    @Test func circleInvoluteRotated() {
        let angle = Double.pi / 2
        let dir = SIMD2(cos(angle), sin(angle))
        guard let curve = Curve2D.circleInvolute(origin: .zero, direction: dir, radius: 2.0) else {
            #expect(Bool(false), "Failed to create circle involute")
            return
        }
        let first = curve.domain.lowerBound
        let p = curve.point(at: first)
        // C(0) = O + R*(0, 1) = (0, 2)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 2.0) < 1e-10)
    }

    @Test func circleInvoluteMirroredFlank() {
        // A mirrored flank uses a negated X direction (direction = (-1, 0) gives YDir = (0, -1))
        let standardCurve = Curve2D.circleInvolute(
            origin: .zero, direction: SIMD2(1, 0), radius: 2.0)
        let mirroredCurve = Curve2D.circleInvolute(
            origin: .zero, direction: SIMD2(-1, 0), radius: 2.0)
        #expect(standardCurve != nil)
        #expect(mirroredCurve != nil)
        // Verify the curves produce different geometry at the same parameter
        let first = standardCurve!.domain.lowerBound
        let pStandard = standardCurve!.point(at: first)
        let pMirrored = mirroredCurve!.point(at: first)
        // Standard: YDir = (0, 1) -> C(0) = (2, 0)
        // Mirrored: YDir = (0, -1) -> C(0) = (2, 0) (same at u=0)
        // At u > 0 they differ in Y direction
        let u = 1.0
        let pStandardU = standardCurve!.point(at: u)
        let pMirroredU = mirroredCurve!.point(at: u)
        // At u=1, Y values should have opposite signs
        #expect(pStandardU.y > 0)  // Standard flank goes positive Y
        #expect(pMirroredU.y < 0)  // Mirrored flank goes negative Y
    }

    @Test func circleInvoluteCanBuildEdge() {
        guard let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(1, 0), radius: 2.0)
        else {
            #expect(Bool(false), "Failed to create circle involute")
            return
        }
        // Build an edge from the curve
        let first = curve.domain.lowerBound
        let last = curve.domain.upperBound
        // Use a reasonable parameter range
        let u1 = first
        let u2 = min(first + 2.0, last)
        let edge = Shape.edge2dFromCurve(curve, u1: u1, u2: u2)
        #expect(edge != nil)
        // Verify the edge contains the expected sub-shape
        if let e = edge {
            let edges = e.edges()
            #expect(edges.count == 1)
        }
    }

    @Test func createCircleInvoluteRejectsZeroLengthDirection() {
        let curve = Curve2D.circleInvolute(origin: .zero, direction: SIMD2(0, 0), radius: 2.0)
        #expect(curve == nil)
    }

    @Test func createCircleInvoluteRejectsNearZeroLengthDirection() {
        let curve = Curve2D.circleInvolute(
            origin: .zero, direction: SIMD2(1e-15, 1e-15), radius: 2.0)
        #expect(curve == nil)
    }

    @Test func circleInvoluteD0WithPlacementRejectsZeroLengthDirection() {
        let p = Geom2dEval.circleInvoluteD0(
            origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0)
        #expect(p.x == 0.0 && p.y == 0.0)
    }

    @Test func circleInvoluteD1WithPlacementRejectsZeroLengthDirection() {
        let r = Geom2dEval.circleInvoluteD1(
            origin: .zero, direction: SIMD2(0, 0), radius: 2.0, u: 1.0)
        #expect(r.point.x == 0.0 && r.point.y == 0.0)
        #expect(r.d1.x == 0.0 && r.d1.y == 0.0)
    }
}
