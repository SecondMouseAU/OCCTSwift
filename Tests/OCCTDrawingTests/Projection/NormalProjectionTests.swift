import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Normal Projection")
struct NormalProjectionTests {
    @Test("Project line onto sphere near surface")
    func projectOnSphere() {
        let sphere = Shape.sphere(radius: 10)!
        // Line near the sphere surface (x=8, within radius 10)
        // Normal projection projects along surface normals, works when
        // the wire is near or outside the surface, not deep inside
        let line = Shape.fromWire(Wire.line(from: SIMD3(8, -2, 0), to: SIMD3(8, 2, 0))!)
        #expect(line != nil)
        let projected = sphere.normalProjection(of: line!)
        #expect(projected != nil)
        if let projected {
            #expect(projected.isValid)
        }
    }

    @Test("Project line outside sphere")
    func projectOutsideSphere() {
        let sphere = Shape.sphere(radius: 10)!
        // Line fully outside the sphere
        let line = Shape.fromWire(Wire.line(from: SIMD3(15, -5, 0), to: SIMD3(15, 5, 0))!)
        #expect(line != nil)
        let projected = sphere.normalProjection(of: line!)
        #expect(projected != nil)
    }
}
