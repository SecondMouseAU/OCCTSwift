import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.127.0: Section ops, BSpline/Bezier completions, BRep_Tool, ColorTool, FilletBuilder history

@Suite("v0.127.0, Section with Plane/Surface")
struct SectionPlaneTests {

    @Test("Section shape with plane produces edges")
    func sectionWithPlane() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let section = box.sectionWithPlane(normal: SIMD3(0, 0, 1), origin: SIMD3(0, 0, 5)) {
            let edges = section.subShapes(ofType: .edge)
            #expect(edges.count > 0)
        }
    }

    @Test("Section shape with cylindrical surface")
    func sectionWithSurface() {
        guard let box = Shape.box(width: 10, height: 10, depth: 10) else { return }
        if let surf = Surface.cylindricalSurface(
            origin: SIMD3(5, 5, 0), direction: SIMD3(0, 0, 1), radius: 3.0)
        {
            if let section = box.sectionWithSurface(surf) {
                let edges = section.subShapes(ofType: .edge)
                #expect(edges.count > 0)
            }
        }
    }
}
