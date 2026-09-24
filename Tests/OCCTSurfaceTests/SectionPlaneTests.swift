import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.127.0: Section ops, BSpline/Bezier completions, BRep_Tool, ColorTool, FilletBuilder history

@Suite("v0.127.0, Section with Plane/Surface")
struct SectionPlaneTests {

    @Test("Section shape with plane produces edges")
    func sectionWithPlane() {
        // #766: the section sat behind `if let` and only `> 0` edges were checked. The centred
        // box's top face is z = 5, and BRepAlgoAPI_Section gives its 4-edge square
        // (Scripts/repro/766-projection-trim-revolution-section/).
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let section = box.sectionWithPlane(normal: SIMD3(0, 0, 1), origin: SIMD3(0, 0, 5))
        #expect(section != nil)
        if let section {
            let edges = section.subShapes(ofType: .edge)
            #expect(edges.count == 4)
        }
    }

    @Test("Section shape with cylindrical surface")
    func sectionWithSurface() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        let surf = Surface.cylindricalSurface(origin: SIMD3(5, 5, 0), direction: SIMD3(0, 0, 1), radius: 3.0)
        #expect(surf != nil)
        if let surf {
            let section = box.sectionWithSurface(surf)
            #expect(section != nil)
            if let section {
                // The cylinder at the box's corner cuts 4 edges (kernel count).
                #expect(section.subShapes(ofType: .edge).count == 4)
            }
        }
    }
}
