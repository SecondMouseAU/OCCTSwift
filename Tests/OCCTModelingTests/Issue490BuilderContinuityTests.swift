import Testing
@testable import OCCTSwift

// #490, the two builder-held continuity arguments.
//
// FilletBuilder.setContinuity was the one continuity argument the bridge did not decode at all, it
// cast the integer straight to GeomAbs_Shape, so `1` asked for G1 and `2` for C1 while the Swift
// entry point documented 0=C0, 1=C1, 2=C2 (and any value >= 7 was outside the enum's own range
// entirely). It now decodes as ParametricContinuity, matching both its own documentation and
// BRepFilletAPI_MakeFillet's ("an continuity Ci (i=0, 1 or 2)").
//
// Both suites below pin a *domain* claim rather than an observable difference, deliberately:
// measured on the pinned kernel, neither builder's continuity argument changes the resulting
// solid's volume at all, it is a surface-quality/parameterisation property these APIs do not
// surface. So what is worth asserting is which values the operation accepts, which is exactly what
// the shared decoder's saturation changes.

@Suite("Issue #490: fillet internal continuity decodes as ParametricContinuity")
struct Issue490FilletContinuityTests {

    private func filletedVolume(continuity: Int) -> Double? {
        guard let box = Shape.box(width: 20, height: 20, depth: 20),
              let builder = FilletBuilder(shape: box),
              let edge = box.edges().first
        else { return nil }
        builder.setContinuity(continuity, angularTolerance: 1e-4)
        guard builder.addEdge(edge, radius: 2.0), let result = builder.build() else { return nil }
        return result.volume
    }

    @Test("every value in the documented C0/C1/C2 domain builds a fillet", arguments: 0...2)
    func documentedDomainBuilds(continuity: Int) throws {
        let volume = try #require(filletedVolume(continuity: continuity),
                                  "continuity \(continuity) should still build a fillet")
        // A fillet on one edge of a 20-cube rounds material away.
        #expect(volume < 8000.0)
        #expect(volume > 7900.0)
    }

    @Test("past the documented domain the fillet still builds, it does not crash or fail",
          arguments: [3, 4, 99, -1])
    func beyondDocumentedDomainStillBuilds(continuity: Int) throws {
        // The shared decoder saturates, so 3 asks for C3 and anything above asks for CN, values
        // BRepFilletAPI_MakeFillet does not document and ChFi3d_Builder::SetContinuity stores
        // without validating, which makes them reachable here for the first time (the old raw cast
        // shifted them, and >= 7 was not a GeomAbs_Shape value at all). Measured, not inferred:
        // each builds the same solid as an in-domain value. Negative input saturates to C0.
        let volume = try #require(filletedVolume(continuity: continuity),
                                  "continuity \(continuity) should still build a fillet")
        let inDomain = try #require(filletedVolume(continuity: 1))
        #expect(abs(volume - inDomain) < 1e-9)
    }
}

@Suite("Issue #490: loft continuity accepts the whole parametric ladder")
struct Issue490ThruSectionsContinuityTests {

    private func loftedVolume(continuity: Int) -> Double? {
        guard let w1 = Wire.circle(origin: SIMD3(0, 0, 0), normal: SIMD3(0, 0, 1), radius: 3),
              let w2 = Wire.circle(origin: SIMD3(0, 0, 4), normal: SIMD3(0, 0, 1), radius: 5),
              let w3 = Wire.circle(origin: SIMD3(0, 0, 8), normal: SIMD3(0, 0, 1), radius: 3),
              let s1 = Shape.fromWire(w1), let s2 = Shape.fromWire(w2), let s3 = Shape.fromWire(w3)
        else { return nil }
        let builder = ThruSectionsBuilder(isSolid: true)
        builder.setContinuity(continuity)
        builder.addWire(s1)
        builder.addWire(s2)
        builder.addWire(s3)
        guard builder.build(), let shape = builder.shape else { return nil }
        return shape.volume
    }

    @Test("BRepOffsetAPI_ThruSections takes every value without failing",
          arguments: [0, 1, 2, 3, 4, 99, -1])
    func everyValueLofts(continuity: Int) throws {
        // ThruSectionsBuilder.setContinuity's doc comment makes exactly this claim, so it gets a
        // test: unlike the Approx* family, which throws above C2, this consumer accepts the whole
        // ladder including the CN that out-of-range input now saturates to. Before #490 only 0 and
        // 1 were read here at all, everything else meant C2, so nothing above 1 was distinct.
        let volume = try #require(loftedVolume(continuity: continuity),
                                  "continuity \(continuity) should still loft")
        #expect(volume > 0)

        let inDomain = try #require(loftedVolume(continuity: 1))
        #expect(abs(volume - inDomain) < 1e-9)
    }
}
