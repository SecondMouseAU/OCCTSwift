import Testing
import simd

@testable import OCCTSwift

/// #1502 finding 1: `Shape.darbouxTrihedron(onFace:at:)` (`OCCTGeomFillDarbouxTrihedron`) used to
/// hand `GeomFill_Darboux::SetCurve` a plain `BRepAdaptor_Curve` instead of a real
/// `Adaptor3d_CurveOnSurface` built from the edge's pcurve on `face`. `GeomFill_Darboux::D0`
/// unconditionally `static_cast`s the handle it was given to `Adaptor3d_CurveOnSurface*`, an
/// uncatchable bus error against any other `Adaptor3d_Curve` subclass. That crash cannot be
/// reproduced inside this process (it would take the whole `swift test` run down with it); it was
/// validated closed with a standalone reproducer instead -- see
/// `Scripts/repro/1502-surface-adaptor-defects/` for the before/after transcript. This suite
/// exercises the fixed code path through the public API.
@Suite("Issue #1502: Darboux trihedron on a real curve-on-surface")
struct Issue1502DarbouxTrihedronTests {
    @Test func darbouxOnCircleEdgeOnFace() throws {
        // The issue's own fixture: a circular edge belting a planar disc face -- the simplest
        // shape with a genuine pcurve on a real face.
        let wire = try #require(Wire.circle(radius: 5))
        let face = try #require(Shape.face(from: wire))
        let edges = face.subShapes(ofType: .edge)
        let edge = try #require(edges.first)

        let frame = try #require(edge.darbouxTrihedron(onFace: face, at: 0.1))

        // A real curve-on-surface gives GeomFill_Darboux both the curve's tangent AND a binormal
        // derived from the surface's own normal; a bare 3D-curve adaptor (the pre-fix code, had
        // it not crashed outright) has no surface to derive one from at all. Assert the frame is
        // a genuine orthonormal trihedron whose binormal matches the disc's own planar normal,
        // not merely "some non-crashing triple of numbers".
        #expect(abs(simd_length(frame.tangent) - 1.0) < 1e-6)
        #expect(abs(simd_length(frame.normal) - 1.0) < 1e-6)
        #expect(abs(simd_length(frame.binormal) - 1.0) < 1e-6)
        #expect(abs(simd_dot(frame.tangent, frame.normal)) < 1e-6)
        #expect(abs(simd_dot(frame.tangent, frame.binormal)) < 1e-6)
        #expect(abs(abs(frame.binormal.z) - 1.0) < 1e-6)
    }

    @Test func darbouxOnMultipleParameters() throws {
        // Same fixture, several parameters along the circle: the fix must hold across the whole
        // curve, not just the one value the reproducer happened to probe.
        let wire = try #require(Wire.circle(radius: 3))
        let face = try #require(Shape.face(from: wire))
        let edges = face.subShapes(ofType: .edge)
        let edge = try #require(edges.first)

        for param: Double in [0.0, 0.5, 1.5, 3.0, 5.0] {
            let frame = try #require(edge.darbouxTrihedron(onFace: face, at: param))
            #expect(abs(simd_length(frame.tangent) - 1.0) < 1e-6)
            #expect(abs(simd_dot(frame.tangent, frame.normal)) < 1e-6)
        }
    }
}
