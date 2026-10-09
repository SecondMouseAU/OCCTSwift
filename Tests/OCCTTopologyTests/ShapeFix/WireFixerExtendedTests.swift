import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.122.0: WireFixer extended, ShapeFix_Edge, BRepTools/BRepLib statics, History extended, Sewing extended

@Suite("v0.122.0, WireFixer Extended")
struct WireFixerExtendedTests {
    // Helper: get a face and its wire from a box
    private func faceAndWire() -> (face: Shape, wire: Shape)? {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return nil }
        let faces = box.subShapes(ofType: .face)
        guard faces.count > 0 else { return nil }
        let face = faces[0]
        let wires = face.subShapes(ofType: .wire)
        guard wires.count > 0 else { return nil }
        return (face, wires[0])
    }

    @Test("Fix gaps 2D")
    func fixGaps2d() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixGaps2d()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix seam")
    func fixSeam() {
        // Use cylinder which has seam edges
        let cyl = Shape.cylinder(radius: 5, height: 10)
        if let c = cyl {
            let faces = c.subShapes(ofType: .face)
            if faces.count > 0 {
                let face = faces[0]
                let wires = face.subShapes(ofType: .wire)
                if wires.count > 0 {
                    let fixer = WireFixer(wire: wires[0], face: face, precision: 1e-6)
                    if let fix = fixer {
                        let _ = fix.fixSeam(edgeIndex: 1)
                        let result = fix.wire
                        #expect(result != nil)
                    }
                }
            }
        }
    }

    @Test("Fix shifted")
    func fixShifted() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixShifted()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix notched edges")
    func fixNotchedEdges() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                let _ = fix.fixNotchedEdges()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }

    @Test("Fix tails with configuration")
    func fixTailsWithConfig() {
        if let (face, wire) = faceAndWire() {
            let fixer = WireFixer(wire: wire, face: face, precision: 1e-6)
            if let fix = fixer {
                fix.setMaxTailAngle(0.5)
                fix.setMaxTailWidth(0.01)
                let _ = fix.fixTails()
                let result = fix.wire
                #expect(result != nil)
            }
        }
    }
}
