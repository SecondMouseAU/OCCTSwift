// StressShapeCustomSurfacelessFaceGuardTests.swift
//
// #2790: every shipped Swift entry point that reaches one of the three `ShapeCustom` converters
// which take the process down on a face with no surface, plus the three that do not and are
// deliberately left unguarded.
//
// `BRepTools_Modifier::FillNewSurfaceInfo` (`BRepTools_Modifier.cxx:705-723`) calls `NewSurface` on
// every face of the shape with no test of anything, and three of the five `ShapeCustom`
// `BRepTools_Modification` subclasses dereference the handle they have just fetched:
//
//   `ShapeCustom_SweptToElementary.cxx:59`     `S->IsKind(STANDARD_TYPE(Geom_SweptSurface))`
//   `ShapeCustom_ConvertToRevolution.cxx:54`   `S->IsKind(STANDARD_TYPE(Geom_RectangularTrimmed...))`
//   `ShapeCustom_ConvertToBSpline.cxx:104`     `S->Bounds(U1, U2, V1, V2)`
//
// Three files, three lines, none of them `ShapeCustom_DirectModification.cxx:55`, which is #2777's.
//
// **The predicate is the surface clause alone**, measured per site rather than inherited from
// #2777: all three faults hit the surface-less face that carries a wire exactly as hard as the
// edgeless one, so `occtShapeHasSurfacelessFace` is right here too and #2773's
// `occtShapeHasSurfacelessEdgelessFace` would leave half the input space faulting. The injection
// table in `Scripts/repro/2790-shapecustom-surfaceless-face/README.md` records that the narrowed
// predicate crashes this suite, so the choice is under test here and not only in the tables.
//
// **The two that do not fault are asserted too**, at the bottom, because a guard pasted across the
// whole family would be a regression: `ShapeCustom::ScaleShape` and `ShapeCustom::BSplineRestriction`
// reach subclasses that hold their own null test
// (`BRepTools_TrsfModification.cxx:73`, `ShapeCustom_BSplineRestriction.cxx:430`), which is also the
// evidence for what the upstream fix should be. Those wrappers must keep answering for the input,
// not refusing it.
//
// The fixtures are `.brep` files, not shapes built here, because the state is not constructible
// through the public Swift API: it needs `BRep_Builder::MakeFace` with no surface. All three are
// already committed, written by #2773's and #2777's `run.sh`; this issue needed no new one.
//
// The healthy control in each test is what proves the guard is not simply refusing everything.

import Foundation
import Testing

@testable import OCCTSwift

@Suite("Stress: ShapeCustom converter surface-less face guard (#2790)")
struct StressShapeCustomSurfacelessFaceGuardTests {

    /// A compound holding one face with no surface that DOES carry a wire.
    ///
    /// The fixture that decides
    /// the predicate: `occtShapeHasSurfacelessEdgelessFace` answers false for this shape and all
    /// three converters fault on it anyway.
    static func withWireFixture() throws -> Shape {
        try load("surfaceless-face-with-wire.brep")
    }

    /// A compound holding one face with no surface and no edges, #2773's fixture.
    static func edgelessFixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-face.brep")
    }

    /// The same edgeless face on its own, so each guard is exercised on a `TopAbs_FACE` as well as
    /// on a compound.
    static func bareEdgelessFixture() throws -> Shape {
        try load("shapedivide-surfaceless-edgeless-bare-face.brep")
    }

    static func allFixtures() throws -> [Shape] {
        [try withWireFixture(), try edgelessFixture(), try bareEdgelessFixture()]
    }

    static func load(_ name: String) throws -> Shape {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        return try Shape.loadBREP(from: url)
    }

    /// A box, whose six planar faces all carry a surface.
    ///
    /// Every guarded entry point must still
    /// answer for it, which is what makes a guard that refuses everything fail this suite.
    static func control() throws -> Shape {
        try #require(Shape.box(width: 10, height: 20, depth: 30))
    }

    /// A cylinder, so at least one control has a face `ShapeCustom::ConvertToRevolution` genuinely
    /// converts rather than passing through.
    static func revolutionControl() throws -> Shape {
        try #require(Shape.cylinder(radius: 5, height: 10))
    }

    /// The surface index each face carries in BREP's own face record: a `Fa` line followed by
    /// `<naturalRestriction> <tolerance> <surfaceIndex> <location>`, where `0` means the face has no
    /// surface at all.
    ///
    /// This is how "the face has no surface" is observable from Swift without asking
    /// any accessor to dereference the handle that is missing. Lifted from #2777's suite, which
    /// explains why the whole-file `Surfaces 0` shortcut #2773 used does not work for the with-wire
    /// fixture.
    static func faceSurfaceIndices(_ shape: Shape) throws -> [Int] {
        let lines = try #require(shape.toBREPString()).components(separatedBy: "\n")
        var indices: [Int] = []
        for (i, line) in lines.enumerated()
        where line.trimmingCharacters(in: .whitespaces) == "Fa" && i + 1 < lines.count {
            let tokens = lines[i + 1].split(separator: " ", omittingEmptySubsequences: true)
            if tokens.count >= 3, let index = Int(tokens[2]) {
                indices.append(index)
            }
        }
        return indices
    }

    // MARK: - The fixtures still mean their names

    @Test("every fixture carries a surface-less face, and only the with-wire one has edges")
    func fixturesStillMeanTheirNames() throws {
        for shape in try Self.allFixtures() {
            #expect(try Self.faceSurfaceIndices(shape) == [0])
        }
        // The clause that separates the two candidate predicates. If this ever flips, the with-wire
        // fixture has stopped being the input that decided the predicate and every table in
        // Scripts/repro/2790-shapecustom-surfaceless-face/README.md is describing something else.
        #expect(try Self.withWireFixture().subShapes(ofType: .edge).isEmpty == false)
        #expect(try Self.edgelessFixture().subShapes(ofType: .edge).isEmpty)
        #expect(try Self.bareEdgelessFixture().subShapes(ofType: .edge).isEmpty)
        // And the controls are on the other side of the predicate.
        #expect(try Self.faceSurfaceIndices(Self.control()).allSatisfy { $0 != 0 })
        #expect(try Self.faceSurfaceIndices(Self.revolutionControl()).allSatisfy { $0 != 0 })
    }

    // MARK: - ShapeCustom::SweptToElementary

    @Test("sweptToElementary refuses instead of crashing")
    func sweptToElementaryRefuses() throws {
        // ShapeCustom_SweptToElementary.cxx:59, reached through IsToConvert from NewSurface:98.
        for shape in try Self.allFixtures() {
            #expect(shape.sweptToElementary() == nil)
        }
        #expect(try Self.control().sweptToElementary() != nil)
        #expect(try Self.revolutionControl().sweptToElementary() != nil)
    }

    // MARK: - ShapeCustom::ConvertToRevolution

    @Test("withSurfacesAsRevolution refuses instead of crashing")
    func withSurfacesAsRevolutionRefuses() throws {
        // ShapeCustom_ConvertToRevolution.cxx:54. The occ::down_cast at :51 is a dynamic_cast and
        // survives the null handle, so :52 takes the IsNull branch and :54 dereferences it.
        for shape in try Self.allFixtures() {
            #expect(shape.withSurfacesAsRevolution() == nil)
        }
        #expect(try Self.control().withSurfacesAsRevolution() != nil)
        // The cylinder's lateral face genuinely converts, so this control asserts the operation is
        // still doing its job and not merely returning something.
        let converted = try #require(Self.revolutionControl().withSurfacesAsRevolution())
        let kinds = converted.subShapes(ofType: .face).compactMap {
            $0.extractFaceSurface()?.typeName
        }
        #expect(kinds.contains("Geom_SurfaceOfRevolution"))
    }

    // MARK: - ShapeCustom::ConvertToBSpline, all three spellings

    @Test("convertedToBSpline refuses instead of crashing")
    func convertedToBSplineRefuses() throws {
        // ShapeCustom_ConvertToBSpline.cxx:104, S->Bounds(...) two statements after the untested
        // read. This entry point hardcodes (true, true, true, false).
        for shape in try Self.allFixtures() {
            #expect(shape.convertedToBSpline() == nil)
        }
        #expect(try Self.control().convertedToBSpline() != nil)
        #expect(try Self.revolutionControl().convertedToBSpline() != nil)
    }

    @Test("withSurfacesAsBSpline refuses instead of crashing, at any flag setting")
    func withSurfacesAsBSplineRefuses() throws {
        // The same OCCT overload with the four flags taken from the caller. The fault sits ahead of
        // IsToConvert, so no flag setting avoids it: both extremes are driven here.
        for shape in try Self.allFixtures() {
            #expect(shape.withSurfacesAsBSpline() == nil)
            #expect(
                shape.withSurfacesAsBSpline(
                    extrusion: false, revolution: false, offset: false, plane: false) == nil)
            #expect(
                shape.withSurfacesAsBSpline(
                    extrusion: true, revolution: true, offset: true, plane: true) == nil)
        }
        #expect(try Self.control().withSurfacesAsBSpline() != nil)
        // planeMode true is the setting that actually converts a box's faces, measured: six
        // Geom_Plane become six Geom_BSplineSurface. The default leaves them alone.
        let converted = try #require(Self.control().withSurfacesAsBSpline(plane: true))
        let kinds = converted.subShapes(ofType: .face).compactMap {
            $0.extractFaceSurface()?.typeName
        }
        #expect(kinds.allSatisfy { $0 == "Geom_BSplineSurface" })
    }

    @Test("convertToBSplineAdvanced refuses instead of crashing")
    func convertToBSplineAdvancedRefuses() throws {
        // The third spelling, and the one no derivation in #2777 or #2790's issue body contained:
        // it constructs ShapeCustom_ConvertToBSpline and drives BRepTools_Modifier itself rather
        // than calling ShapeCustom::ConvertToBSpline, so a search for the free function misses it.
        // Same faulting line, measured to exit 139 on all four probe fixtures.
        for shape in try Self.allFixtures() {
            #expect(Shape.convertToBSplineAdvanced(shape) == nil)
        }
        #expect(try Shape.convertToBSplineAdvanced(Self.control()) != nil)
        let converted = try #require(
            Shape.convertToBSplineAdvanced(Self.control(), planeMode: true))
        let kinds = converted.subShapes(ofType: .face).compactMap {
            $0.extractFaceSurface()?.typeName
        }
        #expect(kinds.allSatisfy { $0 == "Geom_BSplineSurface" })
    }

    // MARK: - #2777's own line, reached a way #2777 did not derive

    @Test("directModification refuses instead of crashing")
    func directModificationRefuses() throws {
        // ShapeCustom_DirectModification.cxx:55, #2777's line. Shape.directFaces() was guarded
        // there and this method was not, because it constructs the modification subclass and drives
        // BRepTools_Modifier itself. Measured to exit 139 on all four probe fixtures with the
        // modifier driven directly, which is the same frame FillNewSurfaceInfo provides either way.
        for shape in try Self.allFixtures() {
            #expect(shape.directModification() == nil)
        }
        #expect(try Self.control().directModification() != nil)
    }

    // MARK: - The two operations that need no guard, and must not acquire one

    @Test("scaledGeometry still answers for a surface-less face, and is deliberately unguarded")
    func scaleGeometryIsNotGuarded() throws {
        // ShapeCustom::ScaleShape reaches ShapeCustom_TrsfModification::NewSurface, which delegates
        // to BRepTools_TrsfModification.cxx:72-77, where OCCT tests the handle and names the case in
        // a comment: "processing cases when there is no geometry". Measured clean on every fixture,
        // so refusing here would be a regression, and the kernel holding this test is the argument
        // for the three that do not.
        for shape in try Self.allFixtures() {
            #expect(shape.scaledGeometry(factor: 2.0) != nil)
        }
        #expect(try Self.control().scaledGeometry(factor: 2.0) != nil)
    }

    @Test("trsfModificationScale still answers for a surface-less face, and is unguarded")
    func trsfModificationScaleIsNotGuarded() throws {
        // The same subclass driven through BRepTools_Modifier directly, so this is the negative
        // sibling of directModification above: identical shape of bridge function, opposite verdict,
        // and the difference is entirely whether the subclass tests its own handle.
        for shape in try Self.allFixtures() {
            #expect(shape.trsfModificationScale(2.0) != nil)
        }
        #expect(try Self.control().trsfModificationScale(2.0) != nil)
    }

    @Test("bsplineRestriction does not fault on a surface-less face, and is unguarded")
    func bsplineRestrictionIsNotGuarded() throws {
        // ShapeCustom_BSplineRestriction.cxx:430 returns false for a null surface, so no face is
        // rebuilt. Measured on the two edgeless fixtures: clean, one face out. On the with-wire
        // fixture the modifier goes on to load an adaptor further down and raises a CATCHABLE
        // Standard_NullObject from GeomAdaptor_Surface::Load, which each wrapper's catch (...)
        // already turns into the nil it documents. So the assertion here is per fixture rather than
        // uniform, and reaching the next line at all is the part that matters.
        #expect(try Self.edgelessFixture().bsplineRestriction() != nil)
        #expect(try Self.bareEdgelessFixture().bsplineRestriction() != nil)
        _ = try Self.withWireFixture().bsplineRestriction()
        for shape in try Self.allFixtures() {
            _ = shape.bsplineRestriction(tol3d: 0.01, tol2d: 0.01)
        }
        #expect(try Self.control().bsplineRestriction() != nil)
        #expect(try Self.control().bsplineRestriction(tol3d: 0.01, tol2d: 0.01) != nil)
    }

    // MARK: - The duplicate pair the issue asked about

    @Test("convertedToBSpline is withSurfacesAsBSpline at its own default flags")
    func theThreeBSplineSpellingsAgree() throws {
        // #2790 asks whether OCCTShapeConvertToBSpline and OCCTShapeCustomConvertToBSpline are
        // duplicates. They are not identical: the first hardcodes (true, true, true, false) and the
        // second takes all four from the caller, so the first is the second at one argument setting,
        // which happens to be exactly the second's Swift defaults. Measured here rather than argued
        // from the sources, and C++-side in Scripts/repro/2790-shapecustom-surfaceless-face/, where
        // the ShapeCustom::ApplyModifier and bare-BRepTools_Modifier routes also agree on a cylinder,
        // a box and a compound of two cylinders.
        //
        // Nothing is deleted here: removing a public bridge symbol moves the derived operation count
        // and docs/API_REFERENCE.md, which is an API decision, per #2771's precedent.
        for input in [try Self.control(), try Self.revolutionControl()] {
            let viaFixedFlags = try #require(input.convertedToBSpline())
            let viaDefaults = try #require(input.withSurfacesAsBSpline())
            let viaAdvanced = try #require(Shape.convertToBSplineAdvanced(input))
            let signature: (Shape) -> [String] = { shape in
                shape.subShapes(ofType: .face).compactMap { $0.extractFaceSurface()?.typeName }
                    .sorted()
            }
            #expect(signature(viaFixedFlags) == signature(viaDefaults))
            #expect(signature(viaFixedFlags) == signature(viaAdvanced))
            #expect(signature(viaFixedFlags) == signature(input))
        }
    }
}
