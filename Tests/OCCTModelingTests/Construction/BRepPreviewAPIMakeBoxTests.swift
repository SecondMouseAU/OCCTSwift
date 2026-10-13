import Testing

@testable import OCCTSwift

// `BRepPreviewAPI_MakeBox` builds the box from a corner at the origin, and for a zero dimension
// hands back the degenerate shape a preview needs rather than failing: a face for one zero, an
// edge for two, a vertex for three. Measured on the pinned kernel (v4.0.0-kernel.6).
@Suite("BRepPreviewAPI MakeBox Tests")
struct BRepPreviewAPIMakeBoxTests {
    // The box's corners, to a 1e-6 slack for the kernel's 1e-7 bounding-box enlargement.
    private func corners(
        of shape: Shape, min lo: SIMD3<Double>, max hi: SIMD3<Double>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let bounds = try #require(shape.boundingBox, sourceLocation: sourceLocation)
        for (got, want) in zip(
            [bounds.min.x, bounds.min.y, bounds.min.z, bounds.max.x, bounds.max.y, bounds.max.z],
            [lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])
        {
            #expect(abs(got - want) < 1e-6, sourceLocation: sourceLocation)
        }
    }

    @Test("normal preview box")
    func normalBox() throws {
        let box = try #require(Shape.previewBox(width: 10, height: 20, depth: 30))
        #expect(box.shapeType == .solid)
        #expect(abs((box.volume ?? -1) - 6000.0) < 1e-6)
        #expect(abs((box.surfaceArea ?? -1) - 2200.0) < 1e-6)
        // Corner at the origin, extending into +x, +y, +z.
        try corners(of: box, min: SIMD3(0, 0, 0), max: SIMD3(10, 20, 30))
    }

    @Test("degenerate face preview")
    func facePreview() throws {
        let face = try #require(Shape.previewBox(width: 10, height: 20, depth: 0))
        #expect(face.shapeType == .face)
        #expect(abs((face.surfaceArea ?? -1) - 200.0) < 1e-6)
        try corners(of: face, min: SIMD3(0, 0, 0), max: SIMD3(10, 20, 0))
    }

    @Test("degenerate edge preview")
    func edgePreview() throws {
        let edge = try #require(Shape.previewBox(width: 10, height: 0, depth: 0))
        #expect(edge.shapeType == .edge)
        try corners(of: edge, min: SIMD3(0, 0, 0), max: SIMD3(10, 0, 0))
    }

    @Test("degenerate vertex preview")
    func vertexPreview() throws {
        let vertex = try #require(Shape.previewBox(width: 0, height: 0, depth: 0))
        #expect(vertex.shapeType == .vertex)
        try corners(of: vertex, min: SIMD3(0, 0, 0), max: SIMD3(0, 0, 0))
    }
}
