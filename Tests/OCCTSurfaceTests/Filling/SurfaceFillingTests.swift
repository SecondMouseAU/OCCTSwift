import Testing

@testable import OCCTSwift

@Suite("Surface Filling Tests")
struct SurfaceFillingTests {

    @Test("Fill from closed wire boundary")
    func fillClosedWireBoundary() throws {
        // Create a closed rectangular wire as boundary
        let boundary = try #require(
            Wire.rectangle(width: 10, height: 10), "Failed to create boundary wire")

        // Note: Surface filling is a complex OCCT operation that may not
        // succeed with all boundary configurations. This tests the API.
        let surfaceOpt = Shape.fill(
            boundaries: [boundary],
            parameters: FillingParameters(continuity: .g0)
        )

        // #766: this was `if let surface { #expect(surface.isValid) }`, so a nil fill passed.
        // BRepOffsetAPI_MakeFilling builds the flat 10 x 10 square here, valid, area 100
        // (Scripts/repro/766-surface-fill-freeform-grid/).
        let surface = try #require(surfaceOpt)
        #expect(surface.isValid)
        #expect(abs((surface.surfaceArea ?? 0) - 100) < 1e-9)
    }

    @Test("Fill with polygon boundary")
    func fillPolygonBoundary() throws {
        guard
            let boundary = Wire.polygon(
                [
                    SIMD2(0, 0),
                    SIMD2(10, 0),
                    SIMD2(10, 10),
                    SIMD2(0, 10),
                ], closed: true)
        else {
            Issue.record("Failed to create polygon boundary")
            return
        }

        let params = FillingParameters(
            continuity: .g0,
            tolerance: 1e-3,
            maxDegree: 8,
            maxSegments: 9
        )

        let surfaceOpt = Shape.fill(boundaries: [boundary], parameters: params)

        // #766: likewise a nil fill passed; the kernel builds it, area 100.
        let surface = try #require(surfaceOpt)
        #expect(surface.isValid)
        #expect(abs((surface.surfaceArea ?? 0) - 100) < 1e-9)
    }

    @Test("Fill empty boundaries returns nil")
    func fillEmptyBoundaries() {
        let surface = Shape.fill(boundaries: [])

        #expect(surface == nil)
    }
}
