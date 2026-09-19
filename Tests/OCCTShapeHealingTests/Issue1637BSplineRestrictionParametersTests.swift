import Foundation
import OCCTBridge
import Testing

@testable import OCCTSwift

/// #1637: both `ShapeCustom::BSplineRestriction` entry points built a default
/// `ShapeCustom_RestrictionParameters` and passed it straight through, so a caller asking to
/// "restrict this to BSplines" got its planes, cylinders, cones, spheres, tori and Bezier surfaces
/// back untouched, with no diagnostic and no way to ask otherwise.
///
/// The assertion that catches that is a count of `Geom_BSplineSurface` faces, not "the call
/// returned a valid shape with three faces": the unconverted result is a valid shape with three
/// faces, which is exactly why nothing noticed.
@Suite("Issue #1637: BSplineRestriction's per-surface-kind switches are reachable")
struct Issue1637BSplineRestrictionParametersTests {

    private func surfaceKinds(_ shape: Shape) -> [String] {
        shape.subShapes(ofType: .face).compactMap { $0.extractFaceSurface()?.typeName }
    }

    private func bsplineFaceCount(_ shape: Shape) -> Int {
        surfaceKinds(shape).filter { $0 == "Geom_BSplineSurface" }.count
    }

    @Test("the Swift defaults are the kernel's own, field by field")
    func defaultsMatchTheKernel() {
        let kernel = occtDefaultBSplineRestrictionParameters()
        let swift = Shape.BSplineRestrictionParameters.occtDefaults.bridgeValue

        #expect(swift.convertPlane == kernel.convertPlane)
        #expect(swift.convertBezierSurf == kernel.convertBezierSurf)
        #expect(swift.convertRevolutionSurf == kernel.convertRevolutionSurf)
        #expect(swift.convertExtrusionSurf == kernel.convertExtrusionSurf)
        #expect(swift.convertOffsetSurf == kernel.convertOffsetSurf)
        #expect(swift.convertCylindricalSurf == kernel.convertCylindricalSurf)
        #expect(swift.convertConicalSurf == kernel.convertConicalSurf)
        #expect(swift.convertToroidalSurf == kernel.convertToroidalSurf)
        #expect(swift.convertSphericalSurf == kernel.convertSphericalSurf)
        #expect(swift.segmentSurfaceMode == kernel.segmentSurfaceMode)
        #expect(swift.convertCurve3d == kernel.convertCurve3d)
        #expect(swift.convertOffsetCurv3d == kernel.convertOffsetCurv3d)
        #expect(swift.convertCurve2d == kernel.convertCurve2d)
        #expect(swift.convertOffsetCurv2d == kernel.convertOffsetCurv2d)
    }

    @Test("the default parameters leave a cylinder entirely elementary, as they always did")
    func occtDefaultsConvertNothingOnACylinder() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let restricted = try #require(cylinder.bsplineRestriction(tol3d: 0.01, tol2d: 0.01))

        #expect(restricted.subShapes(ofType: .face).count == 3)
        #expect(
            bsplineFaceCount(restricted) == 0,
            "ConvertPlane and ConvertCylindricalSurf both default to false")
        #expect(surfaceKinds(restricted).sorted() == ["Geom_CylindricalSurface", "Geom_Plane", "Geom_Plane"])
    }

    @Test("allSurfaceTypes converts every face of a cylinder, a sphere and a torus")
    func allSurfaceTypesConvertsEverything() throws {
        let cases: [(String, Shape, Int)] = [
            ("cylinder", try #require(Shape.cylinder(radius: 5, height: 10)), 3),
            ("sphere", try #require(Shape.sphere(radius: 5)), 1),
            ("torus", try #require(Shape.torus(majorRadius: 10, minorRadius: 3)), 1),
        ]
        for (label, shape, faceCount) in cases {
            #expect(shape.subShapes(ofType: .face).count == faceCount, "\(label) fixture")
            let restricted = try #require(
                shape.bsplineRestriction(tol3d: 0.01, tol2d: 0.01, parameters: .allSurfaceTypes),
                "\(label)")
            #expect(bsplineFaceCount(restricted) == faceCount, "\(label): every face converted")
            #expect(restricted.subShapes(ofType: .face).count == faceCount, "\(label)")
        }
    }

    @Test("one switch at a time converts exactly the kind it names")
    func perKindSwitchesActIndependently() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))

        var cylindricalOnly = Shape.BSplineRestrictionParameters.occtDefaults
        cylindricalOnly.convertCylindricalSurface = true
        let wall = try #require(
            cylinder.bsplineRestriction(tol3d: 0.01, tol2d: 0.01, parameters: cylindricalOnly))
        #expect(bsplineFaceCount(wall) == 1, "the lateral face only")
        #expect(surfaceKinds(wall).filter { $0 == "Geom_Plane" }.count == 2, "both caps untouched")

        var planesOnly = Shape.BSplineRestrictionParameters.occtDefaults
        planesOnly.convertPlane = true
        let caps = try #require(
            cylinder.bsplineRestriction(tol3d: 0.01, tol2d: 0.01, parameters: planesOnly))
        #expect(bsplineFaceCount(caps) == 2, "the two caps only")
        #expect(
            surfaceKinds(caps).filter { $0 == "Geom_CylindricalSurface" }.count == 1,
            "the lateral face untouched")
    }

    @Test("converting every surface kind still preserves the solid")
    func conversionPreservesTheSolid() throws {
        let cylinder = try #require(Shape.cylinder(radius: 5, height: 10))
        let before = try #require(cylinder.volume)
        let restricted = try #require(
            cylinder.bsplineRestriction(tol3d: 0.001, tol2d: 0.001, parameters: .allSurfaceTypes))
        let after = try #require(restricted.volume)
        #expect(abs(after - before) / before < 0.01)
    }
}
