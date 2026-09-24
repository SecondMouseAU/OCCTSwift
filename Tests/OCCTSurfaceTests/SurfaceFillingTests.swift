import Testing
import simd

@testable import OCCTSwift

@Suite("Surface Filling Tests")
struct SurfaceFillingTests {

    @Test("Fill from closed wire boundary")
    func fillClosedWireBoundary() {
        // Create a closed rectangular wire as boundary
        guard let boundary = Wire.rectangle(width: 10, height: 10) else {
            Issue.record("Failed to create boundary wire")
            return
        }

        // Note: Surface filling is a complex OCCT operation that may not
        // succeed with all boundary configurations. This tests the API.
        let surface = Shape.fill(
            boundaries: [boundary],
            parameters: FillingParameters(continuity: .g0)
        )

        // #766: this was `if let surface { #expect(surface.isValid) }`, so a nil fill passed.
        // BRepOffsetAPI_MakeFilling builds the flat 10 x 10 square here, valid, area 100
        // (Scripts/repro/766-surface-fill-freeform-grid/).
        #expect(surface != nil)
        if let surface = surface {
            #expect(surface.isValid)
            #expect(abs((surface.surfaceArea ?? 0) - 100) < 1e-9)
        }
    }

    @Test("Fill with polygon boundary")
    func fillPolygonBoundary() {
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

        let surface = Shape.fill(boundaries: [boundary], parameters: params)

        // #766: likewise a nil fill passed; the kernel builds it, area 100.
        #expect(surface != nil)
        if let surface = surface {
            #expect(surface.isValid)
            #expect(abs((surface.surfaceArea ?? 0) - 100) < 1e-9)
        }
    }

    @Test("Fill empty boundaries returns nil")
    func fillEmptyBoundaries() {
        let surface = Shape.fill(boundaries: [])

        #expect(surface == nil)
    }
}
