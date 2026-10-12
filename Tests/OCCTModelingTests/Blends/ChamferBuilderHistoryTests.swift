import Testing

@testable import OCCTSwift

// MARK: - v0.128.0: ChamferBuilder history, SectionBuilder, BRep_Tool extras, Curve/Surface Transform

@Suite("ChamferBuilder History")
struct ChamferBuilderHistoryTests {

    // Chamfer of edge 0 of a 10 mm cube at d = 1, measured on the pinned kernel (v4.0.0-kernel.6):
    // volume 1000 - 0.5 * 1 * 1 * 10 = 995, the chamfer face is 1 by sqrt(2) by 10 = 14.142135...,
    // and the four faces that meet the chamfered edge are the only modified ones (two lose a
    // 10 x 1 strip, two lose a half-unit corner triangle).
    @Test("ChamferBuilder generated/modified/isDeleted")
    func chamferHistory() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.edges().first)
        let builder = try #require(ChamferBuilder(shape: box))
        #expect(builder.addEdge(edge, distance: 1.0))

        let result = try #require(builder.build())
        #expect(result.isValid)
        #expect(abs((result.volume ?? -1) - 995.0) < 1e-6)

        // Modified: exactly four of the six faces, once each, with the measured areas.
        let faces = box.subShapes(ofType: .face)
        #expect(faces.count == 6)
        var modifiedAreas: [Double] = []
        for face in faces {
            let modified = builder.modified(from: face)
            #expect(modified.count <= 1)
            if let m = modified.first { modifiedAreas.append(m.surfaceArea ?? -1) }
            // The chamfer does not generate anything from a face.
            #expect(builder.generated(from: face).isEmpty)
            #expect(!builder.isDeleted(face))
        }
        modifiedAreas.sort()
        #expect(modifiedAreas.count == 4)
        if modifiedAreas.count == 4 {
            #expect(abs(modifiedAreas[0] - 90.0) < 1e-6)
            #expect(abs(modifiedAreas[1] - 90.0) < 1e-6)
            #expect(abs(modifiedAreas[2] - 99.5) < 1e-6)
            #expect(abs(modifiedAreas[3] - 99.5) < 1e-6)
        }

        // The chamfered edge is gone and generated one face, the chamfer strip.
        let edgeShape = try #require(Shape.fromEdge(edge))
        #expect(builder.isDeleted(edgeShape))
        let generated = builder.generated(from: edgeShape)
        #expect(generated.count == 1)
        if let strip = generated.first {
            #expect(strip.shapeType == .face)
            #expect(abs((strip.surfaceArea ?? -1) - 10.0 * 2.0.squareRoot()) < 1e-9)
        }
    }

    // An edge that shares no vertex with the chamfered edge survives in the result untouched, so
    // it must not read as deleted. It does: `IsDeleted` only knows faces, and answers true for
    // every surviving edge and vertex (#3347, OCCT#1036).
    @Test("An untouched edge is not reported deleted (#3347)")
    func chamferSurvivingEdgeIsNotDeleted() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edges = box.edges()
        let chamfered = try #require(edges.first)
        let (a, b) = chamfered.endpoints
        func near(_ p: SIMD3<Double>, _ q: SIMD3<Double>) -> Bool {
            let d = p - q
            return (d.x * d.x + d.y * d.y + d.z * d.z).squareRoot() < 1e-6
        }
        // A distant edge: neither endpoint is an endpoint of the chamfered one.
        let distant = try #require(
            edges.first {
                let (s, e) = $0.endpoints
                return !near(s, a) && !near(s, b) && !near(e, a) && !near(e, b)
            })

        let builder = try #require(ChamferBuilder(shape: box))
        #expect(builder.addEdge(chamfered, distance: 1.0))
        _ = try #require(builder.build())

        let distantShape = try #require(Shape.fromEdge(distant))
        // It was not touched, so nothing was generated or modified from it either.
        #expect(builder.generated(from: distantShape).isEmpty)
        #expect(builder.modified(from: distantShape).isEmpty)
        withKnownIssue("#3347: IsDeleted answers true for an edge that survives unchanged") {
            #expect(!builder.isDeleted(distantShape))
        }
    }

    // `ChamferMode` selects how the single distance is read. Classic takes it as the leg of the
    // chamfer triangle (area d^2 / 2); constant throat takes it as the throat, so the legs are
    // d * sqrt(2) and the triangle has area d^2. Measured on a 10 mm cube, edge 0, distance 1:
    // 995 against 990. The penetration mode declines this single-distance chamfer on the pinned
    // kernel, so it is exercised for not crashing but its answer is not pinned.
    @Test("ChamferBuilder setMode")
    func chamferSetMode() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.edges().first)

        func volume(_ mode: ChamferBuilder.ChamferMode) throws -> Double? {
            let builder = try #require(ChamferBuilder(shape: box))
            builder.setMode(mode)
            #expect(builder.addEdge(edge, distance: 1.0))
            return builder.build()?.volume
        }

        let classic = try #require(try volume(.classic))
        let throat = try #require(try volume(.constThroat))
        #expect(abs(classic - 995.0) < 1e-6)
        #expect(abs(throat - 990.0) < 1e-6)

        // No assertion on the answer: only that selecting the mode and building returns.
        _ = try volume(.constThroatWithPenetration)
    }

    @Test("ChamferBuilder simulate and surface count")
    func chamferSimulate() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let edge = try #require(box.edges().first)
        let builder = try #require(ChamferBuilder(shape: box))
        #expect(builder.addEdge(edge, distance: 1.0))
        #expect(builder.contourCount == 1)
        #expect(abs(builder.length(contour: 1) - 10.0) < 1e-9)

        // Required rather than expected: reading the surface count before a simulation crashes
        // the process, so a failed simulation must stop the test here.
        try #require(builder.simulate(contour: 1))
        // One chamfer face on a one-edge contour.
        #expect(builder.simulatedSurfaceCount(contour: 1) == 1)
    }
}
