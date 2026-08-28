import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Clip Plane Tests

@Suite("Clip Plane")
struct ClipPlaneTests {

    @Test("Equation roundtrip")
    func equationRoundtrip() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let eq = plane.equation
        #expect(abs(eq.x - 0) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 1) < 1e-10)
        #expect(abs(eq.w - (-5)) < 1e-10)
    }

    @Test("Create from normal and distance")
    func createFromNormal() {
        let plane = ClipPlane(normal: SIMD3(1, 0, 0), distance: -3)
        let eq = plane.equation
        #expect(abs(eq.x - 1) < 1e-10)
        #expect(abs(eq.y - 0) < 1e-10)
        #expect(abs(eq.z - 0) < 1e-10)
        #expect(abs(eq.w - (-3)) < 1e-10)
    }

    @Test("Set equation updates values")
    func setEquation() {
        let plane = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane.equation = SIMD4(0, 1, 0, -2)
        let eq = plane.equation
        #expect(abs(eq.y - 1) < 1e-10)
        #expect(abs(eq.w - (-2)) < 1e-10)
    }

    @Test("Reversed equation is negated")
    func reversedEquation() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, -5))
        let rev = plane.reversedEquation
        #expect(abs(rev.x - 0) < 1e-10)
        #expect(abs(rev.y - 0) < 1e-10)
        #expect(abs(rev.z - (-1)) < 1e-10)
        #expect(abs(rev.w - 5) < 1e-10)
    }

    @Test("Enable and disable")
    func enableDisable() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isOn == true)  // default is on
        plane.isOn = false
        #expect(plane.isOn == false)
        plane.isOn = true
        #expect(plane.isOn == true)
    }

    @Test("Capping on/off")
    func capping() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        #expect(plane.isCapping == false)  // default is off
        plane.isCapping = true
        #expect(plane.isCapping == true)
    }

    @Test("Capping color")
    func cappingColor() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.cappingColor = SIMD3(1.0, 0.0, 0.5)
        let color = plane.cappingColor
        #expect(abs(color.x - 1.0) < 0.01)
        #expect(abs(color.y - 0.0) < 0.01)
        #expect(abs(color.z - 0.5) < 0.01)
    }

    @Test("Hatch style")
    func hatchStyle() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        plane.hatchStyle = .diagonal45
        #expect(plane.hatchStyle == .diagonal45)
        plane.isHatchOn = true
        #expect(plane.isHatchOn == true)
        plane.isHatchOn = false
        #expect(plane.isHatchOn == false)
    }

    @Test("Probe point: inside half-space")
    func probePointInside() {
        // Plane z = 0 (normal pointing +Z): points with z > 0 are "in"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, 5))
        #expect(state == .in)
    }

    @Test("Probe point: outside half-space")
    func probePointOutside() {
        // Plane z = 0 (normal pointing +Z): points with z < 0 are "out"
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(point: SIMD3(0, 0, -5))
        #expect(state == .out)
    }

    @Test("Probe bounding box: fully inside")
    func probeBoxInside() {
        // Plane z = 0 (normal pointing +Z)
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, 1), max: SIMD3(5, 5, 10)))
        #expect(state == .in)
    }

    @Test("Probe bounding box: partially clipped")
    func probeBoxPartial() {
        // Plane z = 0 (normal pointing +Z): box straddles z=0
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(-5, -5, -5), max: SIMD3(5, 5, 5)))
        #expect(state == .on)
    }

    @Test("Probe bounding box: fully outside")
    func probeBoxOutside() {
        let plane = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let state = plane.probe(box: (min: SIMD3(0, 0, -10), max: SIMD3(5, 5, -1)))
        #expect(state == .out)
    }

    @Test("Chain two planes")
    func chainPlanes() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))  // z > 0
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))  // x > 0

        #expect(plane1.chainLength == 1)
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        // Point at (5, 0, 5) satisfies both planes
        let stateIn = plane1.probe(point: SIMD3(5, 0, 5))
        #expect(stateIn == .in)

        // Point at (-5, 0, 5) fails x > 0
        let stateOut = plane1.probe(point: SIMD3(-5, 0, 5))
        #expect(stateOut == .out)
    }

    @Test("Clear chain")
    func clearChain() {
        let plane1 = ClipPlane(equation: SIMD4(0, 0, 1, 0))
        let plane2 = ClipPlane(equation: SIMD4(1, 0, 0, 0))
        plane1.chainNext(plane2)
        #expect(plane1.chainLength == 2)

        plane1.chainNext(nil)
        #expect(plane1.chainLength == 1)
    }
}
