import Testing

@testable import OCCTSwift

@Suite("BRepLib_FindSurface Tests")
struct BRepLibFindSurfaceTests {

    @Test func findSurfaceFromBoxFaceWire() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let surface = wire.findSurface(onlyPlane: true)
                    #expect(surface != nil)
                }
            }
        }
    }

    @Test func findSurfaceToleranceReturnsValue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let tol = wire.findSurfaceTolerance(onlyPlane: true)
                    #expect(tol != nil)
                }
            }
        }
    }

    @Test func findSurfaceExistedTrue() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            let faces = box.subShapes(ofType: .face)
            if let face = faces.first {
                let wires = face.subShapes(ofType: .wire)
                if let wire = wires.first {
                    let existed = wire.findSurfaceExisted(onlyPlane: true)
                    #expect(existed)
                }
            }
        }
    }
}
