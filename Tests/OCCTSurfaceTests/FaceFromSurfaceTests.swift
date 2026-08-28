import Testing
import simd

@testable import OCCTSwift

@Suite("Face from Surface")
struct FaceFromSurfaceTests {
    @Test("Face from plane surface with full domain")
    func faceFromPlane() {
        let surface = Surface.plane(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1))!
        // Plane has infinite domain; trim to a finite region
        let face = Shape.face(from: surface, uRange: -5.0...5.0, vRange: -5.0...5.0)
        #expect(face != nil)
        if let f = face {
            #expect(f.surfaceArea! > 0)
            // 10x10 plane => area ~100
            #expect(abs(f.surfaceArea! - 100.0) < 1e-6)
        }
    }

    @Test("Face from cylindrical surface with UV bounds")
    func faceFromCylinder() {
        let surface = Surface.cylinder(origin: SIMD3(0, 0, 0), axis: SIMD3(0, 0, 1), radius: 5)!
        // U = angle [0, 2π], V = height along axis
        let face = Shape.face(
            from: surface,
            uRange: 0.0...(Double.pi),
            vRange: 0.0...10.0)
        #expect(face != nil)
        if let f = face {
            // Half-cylinder: area = π*r*h = π*5*10 ≈ 157.08
            #expect(abs(f.surfaceArea! - Double.pi * 5 * 10) < 0.1)
        }
    }

    @Test("Surface toFace convenience")
    func surfaceToFace() {
        let surface = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3)!
        let face = surface.toFace()
        #expect(face != nil)
        if let f = face {
            // Full sphere surface area = 4πr² = 4π*9 ≈ 113.1
            #expect(abs(f.surfaceArea! - 4 * Double.pi * 9) < 0.5)
        }
    }

    @Test("Surface toFace with trimmed UV range")
    func surfaceToFaceTrimmed() {
        let surface = Surface.sphere(center: SIMD3(0, 0, 0), radius: 3)!
        // Trim to upper hemisphere
        let face = surface.toFace(uRange: 0.0...(2 * Double.pi), vRange: 0.0...(Double.pi / 2))
        #expect(face != nil)
        if let f = face {
            // Upper hemisphere: 2πr² = 2π*9 ≈ 56.5
            #expect(abs(f.surfaceArea! - 2 * Double.pi * 9) < 0.5)
        }
    }
}
