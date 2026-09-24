import Testing
import simd

@testable import OCCTSwift

/// Issue #233: build a face from a surface trimmed to a non-rectangular region, a UV-space
/// boundary polygon (`Surface.toFace(uvBoundary:)`) or a 3D boundary wire (`Shape.face(from:boundary:)`).
@Suite("Issue #233, face from surface bounded by a wire")
struct Issue233FaceFromSurfaceWireTests {

    @Test("UV-polygon trims a cylinder to a non-rectangular footprint")
    func uvPolygonTrimsCylinder() {
        guard let cyl = Surface.cylindricalSurface(radius: 5) else {
            Issue.record("surface")
            return
        }
        // A non-rectangular region in (u = angle, v = height).
        let region: [SIMD2<Double>] = [SIMD2(0.2, 0), SIMD2(2.0, 1), SIMD2(1.5, 6), SIMD2(0.0, 4)]
        guard let face = cyl.toFace(uvBoundary: region) else {
            Issue.record("toFace(uvBoundary:)")
            return
        }
        #expect(face.isValid)
        guard let trimmedArea = face.surfaceArea else {
            Issue.record("area")
            return
        }
        #expect(trimmedArea > 0)
        // #766: the kernel's area for this UV quadrilateral, r x its UV area 7.95. `> 0` and the
        // 0.4 to 1.0 band against the 60 of the rectangle passed a polygon scaled in u by 0.9.
        // #766: kernel values from Scripts/repro/766-issue233-244-266-317/.
        #expect(abs(trimmedArea - 39.75) < 1e-6)

        // The rectangular UV patch over the polygon's bounding box (u 0…2, v 0…6) is strictly larger
        //, confirming the face follows the polygon, not the box.
        if let rect = cyl.toFace(uRange: 0...2, vRange: 0...6), let rectArea = rect.surfaceArea {
            #expect(trimmedArea < rectArea)  // non-rectangular trim removed area
            #expect(trimmedArea > rectArea * 0.4)  // …but it's a real region, not collapsed
        }
    }

    @Test("UV-polygon needs at least 3 points")
    func uvPolygonTooFew() {
        guard let cyl = Surface.cylindricalSurface(radius: 5) else {
            Issue.record("surface")
            return
        }
        #expect(cyl.toFace(uvBoundary: [SIMD2(0, 0), SIMD2(1, 1)]) == nil)
    }

    @Test("3D wire on the surface trims it (face(from:boundary:))")
    func wireBoundaryTrimsCylinder() {
        guard let cyl = Surface.cylindricalSurface(radius: 5) else {
            Issue.record("surface")
            return
        }
        // A closed 3D wire whose vertices lie on the cylinder (radius 5, axis Z).
        let pts: [SIMD3<Double>] = [(0.2, 0.0), (2.0, 1.0), (1.5, 6.0), (0.0, 4.0)].map { (a, h) in
            SIMD3(5 * cos(a), 5 * sin(a), h)
        }
        guard let wire = Wire.polygon3D(pts, closed: true) else {
            Issue.record("wire")
            return
        }
        // The straight chords don't lie on the cylinder, so the exact path declines, but the
        // projection fallback (project ordered points → UV → trim) builds a valid trimmed face.
        guard let face = Shape.face(from: cyl, boundary: wire) else {
            Issue.record("face(from:boundary:) returned nil")
            return
        }
        #expect(face.isValid)
        // #766: `if let a { a > 0 }` passed a face that ignored its boundary. The healed face
        // spans the same 39.75 as the UV-polygon test.
        // #766: kernel values from Scripts/repro/766-issue233-244-266-317/.
        #expect(abs((face.surfaceArea ?? 0) - 39.75) < 1e-6)
    }
}
