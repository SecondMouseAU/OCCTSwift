import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("GeomTransformation Tests")
struct GeomTransformationTests {
    @Test func identity() {
        if let t = GeomTransformation() {
            #expect(abs(t.scaleFactor - 1.0) < 1e-10)
            #expect(!t.isNegative)
        }
    }

    @Test func translation() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            let p = t.apply(x: 0, y: 0, z: 0)
            #expect(abs(p.x - 10) < 1e-10)
            #expect(abs(p.y - 20) < 1e-10)
            #expect(abs(p.z - 30) < 1e-10)
        }
    }

    @Test func rotation() {
        if let t = GeomTransformation() {
            t.setRotation(
                originX: 0, originY: 0, originZ: 0,
                dirX: 0, dirY: 0, dirZ: 1,
                angle: .pi / 2)
            let p = t.apply(x: 1, y: 0, z: 0)
            #expect(abs(p.x) < 1e-10)
            #expect(abs(p.y - 1) < 1e-10)
        }
    }

    @Test func scale() {
        if let t = GeomTransformation() {
            t.setScale(centerX: 0, centerY: 0, centerZ: 0, factor: 2.0)
            #expect(abs(t.scaleFactor - 2.0) < 1e-10)
        }
    }

    @Test func mirror() {
        if let t = GeomTransformation() {
            t.setMirrorPoint(x: 0, y: 0, z: 0)
            #expect(t.isNegative)
        }
    }

    @Test func multiply() {
        if let t1 = GeomTransformation(), let t2 = GeomTransformation() {
            t1.setTranslation(dx: 10, dy: 0, dz: 0)
            t2.setTranslation(dx: 0, dy: 5, dz: 0)
            if let combined = t1.multiplied(by: t2) {
                let p = combined.apply(x: 0, y: 0, z: 0)
                #expect(abs(p.x - 10) < 1e-10)
                #expect(abs(p.y - 5) < 1e-10)
            }
        }
    }

    @Test func invert() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            if let inv = t.inverted() {
                let p = inv.apply(x: 10, y: 20, z: 30)
                #expect(abs(p.x) < 1e-10)
                #expect(abs(p.y) < 1e-10)
                #expect(abs(p.z) < 1e-10)
            }
        }
    }

    @Test func matrixValue() {
        if let t = GeomTransformation() {
            t.setTranslation(dx: 10, dy: 20, dz: 30)
            #expect(abs(t.value(row: 1, col: 4) - 10) < 1e-10)
            #expect(abs(t.value(row: 2, col: 4) - 20) < 1e-10)
        }
    }
}

