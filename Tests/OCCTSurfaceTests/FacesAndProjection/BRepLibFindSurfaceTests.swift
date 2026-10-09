import Testing
import simd

@testable import OCCTSwift

@Suite("BRepLib_FindSurface Tests")
struct BRepLibFindSurfaceTests {

    // #766: each test nested its assertion three `if let`s deep, so an empty box, face list or
    // wire list passed. Shape.box is centred on the origin, so the first face's wire is the
    // x = -5 square; BRepLib_FindSurface finds the plane x = -5 there with ToleranceReached 0 and Existed true, see
    // Scripts/repro/766-pipe-findsurface-bspline/.
    private func firstFaceWire() -> Shape? {
        Shape.box(width: 10, height: 10, depth: 10)?
            .subShapes(ofType: .face).first?
            .subShapes(ofType: .wire).first
    }

    @Test func findSurfaceFromBoxFaceWire() throws {
        let wire = firstFaceWire()
        #expect(wire != nil)
        if let wire {
            let surface = wire.findSurface(onlyPlane: true)
            #expect(surface != nil)
            if let surface {
                // On the plane x = -5: a point of it projects at distance 0, (5, 5, 5) at 10.
                // `#require`, not `?? -1`: with a nil projection the fallback gave -1 < 1e-12,
                // which passes.
                let onPlane = try #require(surface.projectPoint(SIMD3(-5, 3, -2)))
                #expect(onPlane.distance < 1e-12)
                #expect(abs((surface.projectPoint(SIMD3(5, 5, 5))?.distance ?? -1) - 10) < 1e-12)
            }
        }
    }

    @Test func findSurfaceToleranceReturnsValue() {
        let wire = firstFaceWire()
        #expect(wire != nil)
        if let wire {
            let tol = wire.findSurfaceTolerance(onlyPlane: true)
            #expect(tol == 0)
        }
    }

    @Test func findSurfaceExistedTrue() {
        let wire = firstFaceWire()
        #expect(wire != nil)
        if let wire {
            let existed = wire.findSurfaceExisted(onlyPlane: true)
            #expect(existed)
        }
    }
}
