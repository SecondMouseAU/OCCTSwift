import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.113.0 - WireFixer")
struct WireFixerTests {

    @Test func fixBoxWire() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if faces.count > 0 {
                let wires = faces[0].subShapes(ofType: .wire)
                if wires.count > 0 {
                    if let fixer = WireFixer(wire: wires[0], face: faces[0]) {
                        fixer.fixReorder()
                        fixer.fixConnected()
                        fixer.fixSmall()
                        fixer.fixDegenerated()
                        fixer.fixLacking()
                        fixer.fixClosed()
                        fixer.fixGaps3d()
                        fixer.fixEdgeCurves()
                        let w = fixer.wire
                        #expect(w != nil)
                    }
                }
            }
        }
    }
}
