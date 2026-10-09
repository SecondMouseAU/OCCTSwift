import Foundation
import Testing
import simd

@testable import OCCTSwift

// #766: every test used to open with `if let t = GeomTransformation()`, so a failing
// OCCTGeomTransformCreate (or Multiplied / Inverted) skipped every assertion and passed. They now
// use `try #require`; the assertions themselves are unchanged and match
// Scripts/repro/766-math-geom-point-transformation/transcript.txt.
@Suite("GeomTransformation Tests")
struct GeomTransformationTests {
    @Test func identity() throws {
        let t = try #require(GeomTransformation())
        #expect(abs(t.scaleFactor - 1.0) < 1e-10)
        #expect(!t.isNegative)
    }

    @Test func translation() throws {
        let t = try #require(GeomTransformation())
        t.setTranslation(dx: 10, dy: 20, dz: 30)
        let p = t.apply(x: 0, y: 0, z: 0)
        #expect(abs(p.x - 10) < 1e-10)
        #expect(abs(p.y - 20) < 1e-10)
        #expect(abs(p.z - 30) < 1e-10)
    }

    @Test func rotation() throws {
        let t = try #require(GeomTransformation())
        t.setRotation(
            originX: 0, originY: 0, originZ: 0,
            dirX: 0, dirY: 0, dirZ: 1,
            angle: .pi / 2)
        let p = t.apply(x: 1, y: 0, z: 0)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y - 1) < 1e-10)
    }

    @Test func scale() throws {
        let t = try #require(GeomTransformation())
        t.setScale(centerX: 0, centerY: 0, centerZ: 0, factor: 2.0)
        #expect(abs(t.scaleFactor - 2.0) < 1e-10)
    }

    @Test func mirror() throws {
        let t = try #require(GeomTransformation())
        t.setMirrorPoint(x: 0, y: 0, z: 0)
        #expect(t.isNegative)
    }

    @Test func multiply() throws {
        let t1 = try #require(GeomTransformation())
        let t2 = try #require(GeomTransformation())
        t1.setTranslation(dx: 10, dy: 0, dz: 0)
        t2.setTranslation(dx: 0, dy: 5, dz: 0)
        let combined = try #require(t1.multiplied(by: t2))
        let p = combined.apply(x: 0, y: 0, z: 0)
        #expect(abs(p.x - 10) < 1e-10)
        #expect(abs(p.y - 5) < 1e-10)
    }

    @Test func invert() throws {
        let t = try #require(GeomTransformation())
        t.setTranslation(dx: 10, dy: 20, dz: 30)
        let inv = try #require(t.inverted())
        let p = inv.apply(x: 10, y: 20, z: 30)
        #expect(abs(p.x) < 1e-10)
        #expect(abs(p.y) < 1e-10)
        #expect(abs(p.z) < 1e-10)
    }

    @Test func matrixValue() throws {
        let t = try #require(GeomTransformation())
        t.setTranslation(dx: 10, dy: 20, dz: 30)
        #expect(abs(t.value(row: 1, col: 4) - 10) < 1e-10)
        #expect(abs(t.value(row: 2, col: 4) - 20) < 1e-10)
    }
}
