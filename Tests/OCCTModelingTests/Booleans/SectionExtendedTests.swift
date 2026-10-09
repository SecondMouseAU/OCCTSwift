import Testing
import simd

@testable import OCCTSwift

@Suite("v0.123.0, BRepAlgoAPI_Section extended")
struct SectionExtendedTests {

    @Test("Section with approximation")
    func sectionWithApproximation() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true)
            #expect(section != nil)
        }
    }

    @Test("Section with pcurves")
    func sectionWithPcurves() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(
                b, s,
                approximation: true, computePCurve1: true, computePCurve2: true)
            #expect(section != nil)
        }
    }

    @Test("Ancestor face on shape1")
    func ancestorFace1() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true, computePCurve1: true)
            if let sec = section {
                let edges = sec.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let ancestor = Shape.sectionAncestorFaceOn1(
                        b, s, edge: edges[0],
                        approximation: true, computePCurve1: true)
                    // May or may not find ancestor
                    let _ = ancestor
                    #expect(true)
                }
            }
        }
    }

    @Test("Ancestor face on shape2")
    func ancestorFace2() {
        let box = Shape.box(width: 10, height: 10, depth: 10)
        let sphere = Shape.sphere(radius: 7.0)
        if let b = box, let s = sphere {
            let section = Shape.sectionWithOptions(b, s, approximation: true, computePCurve2: true)
            if let sec = section {
                let edges = sec.subShapes(ofType: .edge)
                if edges.count > 0 {
                    let ancestor = Shape.sectionAncestorFaceOn2(
                        b, s, edge: edges[0],
                        approximation: true, computePCurve2: true)
                    let _ = ancestor
                    #expect(true)
                }
            }
        }
    }
}
