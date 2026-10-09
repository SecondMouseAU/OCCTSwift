import Testing
import simd

@testable import OCCTSwift

// MARK: - Sweep & Distance Gap Fixes

@Suite("Extended Extrusion")
struct ExtendedExtrusionTests {
    @Test func extrudeFaceByVector() {
        // Extrude a face (not a solid) to create a solid
        let wire = Wire.rectangle(width: 10, height: 10)
        if let wire {
            let face = Shape.face(from: wire)
            if let face {
                let extruded = face.extruded(by: SIMD3(0, 0, 20))
                #expect(extruded != nil)
                if let extruded { #expect(extruded.isValid) }
            }
        }
    }

    @Test func extrudeEdgeByVector() {
        // #204: the previous body wrapped a Wire's handle in a Shape
        // (`Shape(handle: wire.handle)`), double-owning the C++ handle, both the
        // Wire and the Shape freed it on scope exit → double-free → SIGSEGV. That
        // block was dead code (the resulting `face` was never used). Removed.
        let rect = Wire.rectangle(width: 5, height: 5)
        if let rect {
            let face = Shape.face(from: rect)
            if let face {
                let semi = face.extrudedInfinite(direction: SIMD3(0, 0, 1), infinite: false)
                #expect(semi != nil)
            }
        }
    }
}
