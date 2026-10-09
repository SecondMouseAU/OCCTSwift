import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Display Drawer Tests

@Suite("Display Drawer")
struct DisplayDrawerTests {

    @Test("Default values")
    func defaults() {
        let drawer = DisplayDrawer()
        #expect(drawer.autoTriangulation == true)
        #expect(drawer.wireDraw == true)
        #expect(drawer.faceBoundaryDraw == false)
        #expect(drawer.deflectionType == .relative)
        #expect(drawer.discretisation == 30)
    }

    @Test("Deviation coefficient roundtrip")
    func deviationCoefficient() {
        let drawer = DisplayDrawer()
        drawer.deviationCoefficient = 0.005
        #expect(abs(drawer.deviationCoefficient - 0.005) < 0.0001)
    }

    @Test("Deviation angle roundtrip")
    func deviationAngle() {
        let drawer = DisplayDrawer()
        let angle = 10.0 * .pi / 180.0
        drawer.deviationAngle = angle
        #expect(abs(drawer.deviationAngle - angle) < 0.001)
    }

    @Test("Maximal chordial deviation roundtrip")
    func maxChordialDeviation() {
        let drawer = DisplayDrawer()
        drawer.maximalChordialDeviation = 0.05
        #expect(abs(drawer.maximalChordialDeviation - 0.05) < 0.001)
    }

    @Test("Deflection type toggle")
    func deflectionType() {
        let drawer = DisplayDrawer()
        drawer.deflectionType = .absolute
        #expect(drawer.deflectionType == .absolute)
        drawer.deflectionType = .relative
        #expect(drawer.deflectionType == .relative)
    }

    @Test("Auto-triangulation toggle")
    func autoTriangulation() {
        let drawer = DisplayDrawer()
        drawer.autoTriangulation = false
        #expect(drawer.autoTriangulation == false)
    }

    @Test("Iso on triangulation toggle")
    func isoOnTriangulation() {
        let drawer = DisplayDrawer()
        drawer.isoOnTriangulation = true
        #expect(drawer.isoOnTriangulation == true)
    }

    @Test("Discretisation roundtrip")
    func discretisation() {
        let drawer = DisplayDrawer()
        drawer.discretisation = 50
        #expect(drawer.discretisation == 50)
    }

    @Test("Face boundary draw toggle")
    func faceBoundaryDraw() {
        let drawer = DisplayDrawer()
        drawer.faceBoundaryDraw = true
        #expect(drawer.faceBoundaryDraw == true)
    }

    @Test("Wire draw toggle")
    func wireDraw() {
        let drawer = DisplayDrawer()
        drawer.wireDraw = false
        #expect(drawer.wireDraw == false)
    }
}
