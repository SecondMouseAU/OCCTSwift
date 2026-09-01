import Foundation
import Testing
import simd

@testable import OCCTSwift

/// #1440 finding 2: `OCCTPolyPolygon3DParameter` (`Sources/OCCTBridge/src/OCCTBridge_Mesh.mm`,
/// backing `Polygon3D.parameter(at:)`) called `p->polygon->Parameters()(index + 1)` with no null
/// check. `Poly_Polygon3D::Parameters()` is `return myParameters->Array1();` -- no guard of its
/// own (`Poly_Polygon3D.hxx`) -- unlike the sibling `Poly_PolygonOnTriangulation::Parameter()`,
/// which OCCT itself guards with `Standard_NullObject_Raise_if` (a catchable exception). A
/// `Polygon3D` built via the no-params constructor (`Polygon3D.create(points:)`, wrapping
/// `OCCTPolyPolygon3DCreate`) has a null `myParameters` Handle, so calling `.parameter(at:)` on
/// one dereferenced a null Handle: an uncatchable SIGSEGV `catch (...)` cannot stop, reachable
/// from the ordinary public Swift API with no caller-visible signal that it was dangerous (the
/// safe sibling `PolygonOnTriangulation.parameter(at:)` has a byte-identical doc comment).
///
/// Fixed by guarding with `HasParameters()` first, matching the idiom
/// `OCCTPolyPolygonOnTriSetParameters` already used elsewhere in the same file.
@Suite("Issue #1440: Polygon3D.parameter(at:) null-Handle guard")
struct Issue1440Polygon3DParameterGuardTests {

    @Test("a no-params polygon's parameter(at:) is safe, not a crash")
    func noParametersPolygonParameterIsSafe() throws {
        let polygon = try #require(
            Polygon3D.create(points: [
                SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0),
            ]))

        #expect(polygon.hasParameters == false)

        // Pre-fix, this call segfaults the process uncatchably. Post-fix, it returns the
        // guard's fallback. See the PR notes for the "prove the test fails" transcript: this
        // exact case was run against the reverted fix and observed to crash the test process
        // with signal 11 (SIGSEGV), matching the precedent in
        // Tests/OCCTAnalysisTests/Issue1424BndLibFaceNullGuardTests.swift.
        #expect(polygon.parameter(at: 0) == 0)
        #expect(polygon.parameter(at: 1) == 0)
        #expect(polygon.parameter(at: 2) == 0)
    }

    @Test("a with-parameters polygon still returns its real stored values")
    func withParametersPolygonReturnsStoredValue() throws {
        let params: [Double] = [0.0, 0.5, 1.0]
        let polygon = try #require(
            Polygon3D.create(
                points: [
                    SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(1, 1, 0),
                ],
                parameters: params))

        #expect(polygon.hasParameters == true)
        for (i, expected) in params.enumerated() {
            #expect(polygon.parameter(at: i) == expected)
        }
    }
}
