import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.76.0: Geom 3D Entities, ShapeConstruct_Curve, Bisector utilities

@Suite("GeomPoint3D Tests")
struct GeomPoint3DTests {
    @Test("create and read coordinates")
    func createAndRead() {
        let p = GeomPoint3D(x: 1, y: 2, z: 3)
        #expect(abs(p.x - 1) < 1e-10)
        #expect(abs(p.y - 2) < 1e-10)
        #expect(abs(p.z - 3) < 1e-10)
    }

    @Test("create from SIMD3")
    func createFromSIMD() {
        let p = GeomPoint3D(simd: SIMD3(4, 5, 6))
        let c = p.coordinates
        #expect(abs(c.x - 4) < 1e-10)
        #expect(abs(c.y - 5) < 1e-10)
    }

    @Test("setCoordinates")
    func setCoordinates() {
        let p = GeomPoint3D(x: 0, y: 0, z: 0)
        p.setCoordinates(x: 10, y: 20, z: 30)
        #expect(abs(p.x - 10) < 1e-10)
    }

    @Test("distance between points")
    func distance() {
        let p1 = GeomPoint3D(x: 0, y: 0, z: 0)
        let p2 = GeomPoint3D(x: 3, y: 4, z: 0)
        #expect(abs(p1.distance(to: p2) - 5.0) < 1e-10)
    }

    @Test("translate")
    func translate() {
        let p = GeomPoint3D(x: 1, y: 0, z: 0)
        p.translate(dx: 10, dy: 0, dz: 0)
        #expect(abs(p.x - 11) < 1e-10)
    }
}

