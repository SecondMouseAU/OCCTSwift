import Testing
import simd

@testable import OCCTSwift

// MARK: - v0.47.0 Tests

@Suite("Local Revolution Tests")
struct LocalRevolutionTests {

    // #766: these tests revolved `Shape.box(width:height:depth: 0.1)`, a centred solid straddling
    // the axis, and asserted only `result != nil` (one added `faceCount > 0`). LocOpe_Revol is
    // meant for a profile face, and on that box it returns an EMPTY compound for pi/2 and for the
    // offset case, which `!= nil` accepted. The profile is now a 2 x 5 face standing in the XZ
    // plane at x = 9..11, so the Z axis lies in its plane, and each test pins the kernel's solid
    // of revolution: volume (angle) * 10 * (2 * 5). Values are LocOpe_Revol's own, see
    // Scripts/repro/766-join-local-loft/.
    private func profile() -> Shape? {
        let wire = Wire.path(
            [SIMD3(9, 0, -2.5), SIMD3(11, 0, -2.5), SIMD3(11, 0, 2.5), SIMD3(9, 0, 2.5)], closed: true)
        let face = wire.flatMap { Shape.face(from: $0) }
        #expect(face != nil, "XZ profile face")
        return face
    }

    private func check(_ result: Shape?, volume: Double, faces: Int) {
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
            #expect(result.faceCount == faces)
            #expect(abs((result.volume ?? 0) - volume) < 1e-6)
        }
    }

    @Test("Revolve face around Z axis")
    func revolveAroundZ() throws {
        guard let face = profile() else { return }
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2
        )
        check(result, volume: 157.07963267948972, faces: 6)
    }

    @Test("Revolve face produces solid-like shape")
    func revolveProducesSolid() throws {
        guard let face = profile() else { return }
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 4
        )
        check(result, volume: 78.539816339744817, faces: 6)
    }

    @Test("Revolve with angular offset")
    func revolveWithOffset() throws {
        guard let face = profile() else { return }
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: .pi / 2,
            angularOffset: .pi / 4
        )
        // Same quarter-turn volume as without the offset, but the sweep is turned by pi/4: it runs
        // from pi/4 to 3 pi/4, so y stays above 11 sin(pi/4) - 3.2 = 6.36 and x reaches -7.78,
        // where the unoffset quarter turn spans y from 0 and x from 0 (kernel bounding boxes).
        check(result, volume: 157.07963267948972, faces: 6)
        if let result, let box = result.bounds {
            #expect(box.min.y > 6.3)
            #expect(box.min.x < -7.7)
        }
    }

    @Test("Full revolution")
    func fullRevolution() throws {
        guard let face = profile() else { return }
        let result = face.localRevolution(
            axisOrigin: SIMD3(0, 0, 0),
            axisDirection: SIMD3(0, 0, 1),
            angle: 2 * .pi
        )
        check(result, volume: 628.31853071795877, faces: 4)
    }
}
