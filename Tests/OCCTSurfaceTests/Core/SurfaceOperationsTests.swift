import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Operations")
struct SurfaceOperationsTests {
    @Test("Trim sphere surface")
    func trimSurface() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let dom = sphere.domain
        let uMid = (dom.uMin + dom.uMax) / 2
        let vMid = (dom.vMin + dom.vMax) / 2
        let trimmed = sphere.trimmed(
            u1: dom.uMin, u2: uMid,
            v1: dom.vMin, v2: vMid)
        #expect(trimmed != nil)
        if let trimmed = trimmed {
            let tDom = trimmed.domain
            #expect(abs(tDom.uMax - uMid) < 1e-10)
            #expect(abs(tDom.vMax - vMid) < 1e-10)
        }
    }

    @Test("Offset surface")
    func offsetSurface() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let offset = sphere.offset(distance: 2)
        #expect(offset != nil)
        if let offset = offset {
            // Point on offset sphere should be at distance 7 from center
            let p = offset.point(atU: 0, v: 0)
            let dist = simd_length(p)
            #expect(abs(dist - 7.0) < 1e-6)
        }
    }

    @Test("Translate surface")
    func translateSurface() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let shifted = sphere.translated(by: SIMD3(10, 0, 0))
        #expect(shifted != nil)
        if let shifted = shifted {
            let p = shifted.point(atU: 0, v: 0)
            let pOrig = sphere.point(atU: 0, v: 0)
            #expect(abs(p.x - pOrig.x - 10.0) < 1e-10)
        }
    }

    @Test("Scale surface")
    func scaleSurface() {
        let sphere = Surface.sphere(center: .zero, radius: 5)!
        let scaled = sphere.scaled(center: .zero, factor: 2)
        #expect(scaled != nil)
        if let scaled = scaled {
            let p = scaled.point(atU: 0, v: 0)
            let dist = simd_length(p)
            #expect(abs(dist - 10.0) < 1e-6)
        }
    }

    @Test("Mirror surface across XY plane")
    func mirrorSurface() {
        let sphere = Surface.sphere(center: SIMD3(0, 0, 5), radius: 2)!
        let mirrored = sphere.mirrored(planeOrigin: .zero, planeNormal: SIMD3(0, 0, 1))
        #expect(mirrored != nil)
        if let mirrored = mirrored {
            // Center should now be at (0, 0, -5)
            // Check a point on the mirrored sphere
            let p = mirrored.point(atU: 0, v: 0)
            // Original point at u=0,v=0 has z≈5+2=7 (on equator)
            // Mirrored should have z≈-7
            let pOrig = sphere.point(atU: 0, v: 0)
            #expect(abs(p.z + pOrig.z) < 1e-6)
        }
    }

    @Test("Rotate surface around an axis")
    func rotateSurface() {
        // No existing test coverage for the copy-returning `rotated(axisOrigin:axisDirection:angle:)`
        // overload prior to #414; verify against the known rotation applied to the *measured*
        // original point rather than assuming the sphere's internal U/V parametrization.
        let sphere = Surface.sphere(center: SIMD3(10, 0, 5), radius: 5)!
        let angle = Double.pi / 2
        let axisOrigin = SIMD3<Double>.zero
        let axisDirection = SIMD3<Double>(0, 0, 1)

        let rotated = sphere.rotated(
            axisOrigin: axisOrigin, axisDirection: axisDirection,
            angle: angle)
        #expect(rotated != nil)
        if let rotated = rotated {
            let pOrig = sphere.point(atU: 0.3, v: 0.2)
            let p = rotated.point(atU: 0.3, v: 0.2)
            // Rotation around Z by `angle`: x' = x*cos - y*sin, y' = x*sin + y*cos, z' unchanged
            let expectedX = pOrig.x * cos(angle) - pOrig.y * sin(angle)
            let expectedY = pOrig.x * sin(angle) + pOrig.y * cos(angle)
            #expect(abs(p.x - expectedX) < 1e-6)
            #expect(abs(p.y - expectedY) < 1e-6)
            #expect(abs(p.z - pOrig.z) < 1e-6)
            // The original surface must be untouched (copy-returning, not in-place)
            let pOrigAfter = sphere.point(atU: 0.3, v: 0.2)
            #expect(abs(pOrigAfter.x - pOrig.x) < 1e-10)
            #expect(abs(pOrigAfter.y - pOrig.y) < 1e-10)
        }
    }

    @Test("Mirror surface across a point")
    func mirrorPointSurfaceCopyReturning() {
        // #414: Surface's copy-returning family was missing mirrored(acrossPoint:)/(acrossAxis:direction:)
        // even though the in-place mirrorPoint(_:)/mirrorAxis(origin:direction:) and the Curve3D/Curve2D
        // copy-returning siblings both already have them.
        let sphere = Surface.sphere(center: SIMD3(0, 0, 5), radius: 2)!
        let mirrorPoint = SIMD3<Double>(1, 2, 3)

        let mirrored = sphere.mirrored(acrossPoint: mirrorPoint)
        #expect(mirrored != nil)
        if let mirrored = mirrored {
            let pOrig = sphere.point(atU: 0.4, v: 0.1)
            let p = mirrored.point(atU: 0.4, v: 0.1)
            // Point reflection through `mirrorPoint`: p' = 2*mirrorPoint - p
            let expectedX = 2 * mirrorPoint.x - pOrig.x
            let expectedY = 2 * mirrorPoint.y - pOrig.y
            let expectedZ = 2 * mirrorPoint.z - pOrig.z
            #expect(abs(p.x - expectedX) < 1e-6)
            #expect(abs(p.y - expectedY) < 1e-6)
            #expect(abs(p.z - expectedZ) < 1e-6)
            // The original surface must be untouched (copy-returning, not in-place)
            let pOrigAfter = sphere.point(atU: 0.4, v: 0.1)
            #expect(abs(pOrigAfter.x - pOrig.x) < 1e-10)
            #expect(abs(pOrigAfter.z - pOrig.z) < 1e-10)
        }
    }

    @Test("Mirror surface across an axis")
    func mirrorAxisSurfaceCopyReturning() {
        // #414: same gap as mirrorPointSurfaceCopyReturning, for the axis (line) overload.
        let sphere = Surface.sphere(center: SIMD3(5, 0, 0), radius: 2)!

        // Mirror through the Z axis (through the origin): (x, y, z) -> (-x, -y, z)
        let mirrored = sphere.mirrored(acrossAxis: .zero, direction: SIMD3(0, 0, 1))
        #expect(mirrored != nil)
        if let mirrored = mirrored {
            let pOrig = sphere.point(atU: .pi / 4, v: .pi / 6)
            let p = mirrored.point(atU: .pi / 4, v: .pi / 6)
            #expect(abs(p.x + pOrig.x) < 1e-6)
            #expect(abs(p.y + pOrig.y) < 1e-6)
            #expect(abs(p.z - pOrig.z) < 1e-6)
            // The original surface must be untouched (copy-returning, not in-place)
            let pOrigAfter = sphere.point(atU: .pi / 4, v: .pi / 6)
            #expect(abs(pOrigAfter.x - pOrig.x) < 1e-10)
        }
    }
}
