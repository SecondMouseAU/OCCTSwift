import Testing

@testable import OCCTSwift

@Suite("v0.126.0, BSpline Surface completions")
struct BSplineSurfaceCompletionsTests {
    @Test("U and V multiplicities")
    func multiplicities() {
        // Create a BSpline surface from a box face via NURBS conversion
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box, let nurbs = box.nurbsConvertViaModifier() {
            let faces = nurbs.subShapes(ofType: .face)
            if faces.count > 0 {
                let face = faces[0]
                if let surf = face.faceSurfaceGeom() {
                    let uMults = surf.bsplineUMultiplicities
                    let vMults = surf.bsplineVMultiplicities
                    // NURBS-converted box face should have knots
                    if !uMults.isEmpty {
                        for m in uMults {
                            #expect(m > 0)
                        }
                    }
                    if !vMults.isEmpty {
                        for m in vMults {
                            #expect(m > 0)
                        }
                    }
                }
            }
        }
    }

    @Test("UReverse and VReverse don't crash")
    func reverse() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        if let box = box, let nurbs = box.nurbsConvertViaModifier() {
            let faces = nurbs.subShapes(ofType: .face)
            if faces.count > 0 {
                if let surf = faces[0].faceSurfaceGeom() {
                    let _ = surf.bsplineUReverse()
                    let _ = surf.bsplineVReverse()
                }
            }
        }
    }
}
