import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomVector3D Tests")
struct GeomVector3DTests {
    @Test("magnitude")
    func magnitude() {
        let v = GeomVector3D(x: 3, y: 4, z: 0)
        #expect(abs(v.magnitude - 5.0) < 1e-10)
    }

    @Test("from two points")
    func fromPoints() {
        let v = GeomVector3D(from: SIMD3(1, 1, 1), to: SIMD3(4, 5, 1))
        #expect(abs(v.magnitude - 5.0) < 1e-10)
    }

    @Test("dot product")
    func dot() {
        let v1 = GeomVector3D(x: 1, y: 2, z: 3)
        let v2 = GeomVector3D(x: 4, y: 5, z: 6)
        #expect(abs(v1.dot(v2) - 32.0) < 1e-10)
    }

    @Test("added")
    func added() {
        let v1 = GeomVector3D(x: 1, y: 0, z: 0)
        let v2 = GeomVector3D(x: 0, y: 1, z: 0)
        let sum = v1.added(v2)
        let c = sum.coordinates
        #expect(abs(c.x - 1) < 1e-10 && abs(c.y - 1) < 1e-10)
    }

    @Test("multiplied")
    func multiplied() {
        let v = GeomVector3D(x: 1, y: 2, z: 3)
        let m = v.multiplied(by: 2.0)
        #expect(abs(m.coordinates.x - 2) < 1e-10)
    }

    @Test("normalized")
    func normalized() {
        let v = GeomVector3D(x: 0, y: 0, z: 10)
        if let n = v.normalized() {
            #expect(abs(n.magnitude - 1.0) < 1e-10)
        }
    }

    @Test("crossed")
    func crossed() {
        let v1 = GeomVector3D(x: 1, y: 0, z: 0)
        let v2 = GeomVector3D(x: 0, y: 1, z: 0)
        let cross = v1.crossed(v2)
        #expect(abs(cross.coordinates.z - 1.0) < 1e-10)
    }
}

