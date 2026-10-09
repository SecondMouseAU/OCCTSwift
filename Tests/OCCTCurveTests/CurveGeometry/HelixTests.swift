import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.28.0 New Features

@Suite("Helix Curves")
struct HelixTests {

    @Test("Create basic helix")
    func basicHelix() {
        let helix = Wire.helix(radius: 5, pitch: 2, turns: 3)
        #expect(helix != nil)
    }

    @Test("Helix with custom origin and axis")
    func helixCustomAxis() {
        let helix = Wire.helix(
            origin: SIMD3(10, 20, 30),
            axis: SIMD3(0, 0, 1),
            radius: 10,
            pitch: 5,
            turns: 2
        )
        #expect(helix != nil)
    }

    @Test("Helix clockwise vs counter-clockwise")
    func helixDirection() {
        let ccw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: false)
        let cw = Wire.helix(radius: 5, pitch: 2, turns: 1, clockwise: true)
        #expect(ccw != nil)
        #expect(cw != nil)
    }

    @Test("Invalid helix parameters return nil")
    func invalidHelix() {
        #expect(Wire.helix(radius: 0, pitch: 2, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 0, turns: 1) == nil)
        #expect(Wire.helix(radius: 5, pitch: 2, turns: 0) == nil)
        #expect(Wire.helix(radius: -1, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix can be used as sweep path")
    func helixSweep() {
        let helix = Wire.helix(radius: 10, pitch: 5, turns: 3)!
        let profile = Wire.circle(radius: 0.5)!
        let spring = Shape.sweep(profile: profile, along: helix)
        #expect(spring != nil)
        #expect(spring!.isValid)
    }

    @Test("Create tapered helix")
    func taperedHelix() {
        let helix = Wire.helixTapered(
            startRadius: 10,
            endRadius: 3,
            pitch: 4,
            turns: 4
        )
        #expect(helix != nil)
    }

    @Test("Invalid tapered helix returns nil")
    func invalidTaperedHelix() {
        #expect(Wire.helixTapered(startRadius: 0, endRadius: 5, pitch: 2, turns: 1) == nil)
        #expect(Wire.helixTapered(startRadius: 5, endRadius: 0, pitch: 2, turns: 1) == nil)
    }

    @Test("Helix with fractional turns")
    func fractionalTurns() {
        let helix = Wire.helix(radius: 5, pitch: 10, turns: 0.5)
        #expect(helix != nil)
    }

    @Test("Helix with many turns")
    func manyTurns() {
        let helix = Wire.helix(radius: 5, pitch: 1, turns: 20)
        #expect(helix != nil)
    }
}
