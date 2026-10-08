import Testing
import simd

@testable import OCCTSwift

// MARK: - GeomFill Gordon report + NetworkSurface. OCCT 8.0.0p1

@Suite("GeomFill, Gordon Report & Network Surface")
struct GeomFillGordonReportTests {

    @Test func gordonReportDoneForGoodNetwork() {
        guard let network = makeQuarterCylinderGordonNetwork() else {
            Issue.record("quarter-cylinder network fixture failed to build")
            return
        }
        let result = Surface.gordonReport(
            profiles: network.profiles, guides: network.guides, tolerance: 1e-6)
        #expect(result.status == .done)
        #expect(result.isApproximate == false)
        guard let surface = result.surface else {
            Issue.record("gordonReport surface nil")
            return
        }
        assertMatchesQuarterCylinder(surface)
    }

    @Test func gordonReportInvalidInput() {
        guard let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]) else {
            return
        }
        let result = Surface.gordonReport(profiles: [p1], guides: [p1])
        #expect(result.surface == nil)
        #expect(result.status == .invalidInput)
    }

    @Test func gordonReportApproximateFallbackMode() {
        // With fallback enabled a good network still builds exactly (the fallback never
        // has to engage), and the geometry is unaffected by allowing it.
        guard let network = makeQuarterCylinderGordonNetwork() else {
            Issue.record("quarter-cylinder network fixture failed to build")
            return
        }
        let result = Surface.gordonReport(
            profiles: network.profiles, guides: network.guides,
            tolerance: 1e-6, allowApproximateFallback: true)
        #expect(result.status == .done)
        #expect(result.isApproximate == false)
        guard let surface = result.surface else {
            Issue.record("gordonReport surface nil")
            return
        }
        assertMatchesQuarterCylinder(surface)
    }

    @Test func networkSurfaceBuildsTheQuarterCylinderNetwork() {
        // #689: `OCCTGeomFillNetworkSurface` used to fail EVERY network tried with
        // .knotAlignmentFailed, including the simplest possible bilinear patch (see
        // `networkSurfaceBuildsASimpleBilinearPatch` below), and not because the intersection
        // grid was wrong: the locator parameters it handed GeomFill_NetworkSurface were a
        // caller-invented [0,1] fraction rather than each curve's own raw parameter in
        // the OTHER family's domain, which `alignSurfaces`' `sameKnotRange` check requires to
        // match before it will align anything. Fixed by computing real per-pair contact points
        // and parameters via `GeomAPI_ExtremaCurveCurve` and averaging them the way
        // `GeomFill_Gordon.cxx` does. This fixture is the hardest in the suite, with genuinely
        // rational profile curves (quarter-circle arcs), and now reproduces the reference
        // cylinder despite the intersection grid's weights all being 1.0, because
        // `makeCorrectedProfileSkin`'s rational branch combines the already-rational profile
        // and guide skins independently of that weight.
        guard let network = makeQuarterCylinderGordonNetwork() else {
            Issue.record("quarter-cylinder network fixture failed to build")
            return
        }
        let (surface, status) = Surface.networkSurface(
            profiles: network.profiles, guides: network.guides,
            tolerance: 1e-6)
        #expect(status == .done)
        guard let surface else {
            Issue.record("networkSurface returned nil despite .done")
            return
        }
        assertMatchesQuarterCylinder(surface)
    }

    @Test func networkSurfaceBuildsASimpleBilinearPatch() throws {
        // The issue's own simplest repro: two straight, non-rational lines each direction,
        // forming a flat 10x10 square. Before #689 this failed identically to every other
        // fixture tried, despite being a perfect, error-free network: proof the defect was
        // the parameter DOMAIN, not curve intersection accuracy (the naive uniform-fraction
        // grid this bridge already computed for a bilinear rectangle happens to be exactly
        // right; only the locator parameters handed alongside it were wrong).
        let p1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]))
        let p2 = try #require(Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(10, 10, 0)]))
        let g1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 10, 0)]))
        let g2 = try #require(Curve3D.interpolate(points: [SIMD3(10, 0, 0), SIMD3(10, 10, 0)]))

        let (surface, status) = Surface.networkSurface(
            profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-6)
        #expect(status == .done)
        guard let surface else {
            Issue.record("networkSurface returned nil despite .done")
            return
        }
        let bounds = surface.parameterBounds
        let mid = surface.point(
            atU: (bounds.uMin + bounds.uMax) / 2, v: (bounds.vMin + bounds.vMax) / 2)
        #expect(abs(mid.x - 5) < 1e-9)
        #expect(abs(mid.y - 5) < 1e-9)
        #expect(abs(mid.z - 0) < 1e-9)
    }

    @Test func networkSurfaceParallelCurvesDoNotCrash() throws {
        // A malformed network, a "guide" running parallel to the profiles instead of
        // crossing them, reaches the same `GeomAPI_ExtremaCurveCurve` construction
        // `Curve3D.extrema` uses, which SIGSEGVs on parallel curves with overlapping projected
        // ranges at every capacity (#636: `NbExtrema()` reports 1 but `Points()`/`Parameters()`
        // index an empty sequence, and this Release kernel disables the bounds check that would
        // otherwise throw `Standard_OutOfRange`). Confirmed via a standalone ground-truth
        // binary linked directly against `libOCCT-macos.a` (mirroring PR #730's own
        // verification for #636): the same construction crashes with SIGSEGV when
        // `Points()`/`Parameters()` are called unconditionally, and returns cleanly once gated
        // on `IsParallel()`. This is the regression lock for that guard. It does not
        // reproduce the crash (that would take down the whole test process); it asserts the
        // guarded call keeps returning a real, non-crashing result instead.
        //
        // Every pair here is parallel, so this also pins the #726 fix's status for the
        // fully-degenerate case: reject as `.invalidInput`, not average in a fabricated
        // point. Measured, not assumed: injecting the pre-fix FirstParameter() fallback here
        // still lands on `.invalidInput` too, by the accident of every pair collapsing to the
        // same degenerate value at once and tripping the array's own strictly-increasing
        // check -- this fixture alone would NOT catch that regression. See
        // `networkSurfaceRejectsOneDegeneratePairAmongOtherwiseGoodOnes` below for the fixture
        // (one bad pair, three good ones) where the two fallbacks disagree with the fix.
        let p1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]))
        let p2 = try #require(Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(10, 10, 0)]))
        // Both "guides" run parallel to the profiles (along X, overlapping their projected
        // range) instead of crossing them: not a valid network, but not a crash either.
        let g1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 5, 0), SIMD3(10, 5, 0)]))
        let g2 = try #require(Curve3D.interpolate(points: [SIMD3(0, 6, 0), SIMD3(10, 6, 0)]))

        let (surface, status) = Surface.networkSurface(
            profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-6)
        #expect(status == .invalidInput)
        #expect(surface == nil)
    }

    @Test func networkSurfaceReportsDoneForTheCookbookDomedNetwork() throws {
        // `docs/guides/cookbook/gordon-surfaces.md`'s "lower-level network builder" section
        // used to claim `networkSurface` "is enough" to build the same domed 2x2 network its
        // own opening example builds with `gordon`/`gordonReport` -- a real review finding
        // (neither this PR's stated verification fixtures nor its permanent tests exercised
        // that exact curve set, so the claim was accurate by luck, not by anything checked).
        //
        // Checking it turned up more than an unverified claim: `networkSurface` does report
        // `.done` for this network (and for the plain bilinear rectangle in
        // `networkSurfaceBuildsASimpleBilinearPatch` above), but the resulting surface is
        // wrong at two of its four corners -- confirmed by comparing against `gordon()` on the
        // identical curves, which gets all four right. Filed as #748 rather than fixed here:
        // it is a kernel-level GeomFill_NetworkSurface defect, not a bridge misuse, and out of
        // scope for this PR's three named fixes. The cookbook section was reworded rather than
        // demonstrating a build whose interior is subtly wrong; this test locks in only the
        // narrower, actually-verified claim (`.done`, not full corner fidelity).
        let p1 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(5, 0, 3), SIMD3(10, 0, 0)]))
        let p2 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(5, 10, 3), SIMD3(10, 10, 0)]))
        let g1 = try #require(
            Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(0, 5, 2), SIMD3(0, 10, 0)]))
        let g2 = try #require(
            Curve3D.interpolate(points: [SIMD3(10, 0, 0), SIMD3(10, 5, 2), SIMD3(10, 10, 0)]))

        let (surface, status) = Surface.networkSurface(
            profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-3)
        #expect(status == .done)
        #expect(surface != nil)
    }

    @Test func networkSurfaceTooFewCurves() {
        guard let p1 = Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(10, 0, 0)]) else {
            return
        }
        let (surface, status) = Surface.networkSurface(profiles: [p1], guides: [p1])
        #expect(surface == nil)
        #expect(status == .invalidInput)
    }

    @Test func networkSurfaceRejectsOneDegeneratePairAmongOtherwiseGoodOnes() throws {
        // The review's own scenario: "one degenerate pair inside an otherwise well-formed
        // grid" (#726). p1/p2 and g1/g2 deliberately don't share one common "profile
        // direction" / "guide direction" the way a real network normally would, so that
        // exactly one of the four profile/guide pairs -- p2 x g2, both running along Y at
        // z=3 -- is parallel while the other three (p1 x g1, p1 x g2, p2 x g1) are ordinary
        // skew-line pairs with one real, unambiguous extremum each.
        //
        // Before this PR, the parallel pair fell back to each curve's own FirstParameter()
        // and that fabricated point was averaged in with the three real ones -- silently,
        // with no error, `.done` remained reachable. This network happens to still fail even
        // under that fallback (see the injection below), but only by accident: swapping the
        // fallback to each curve's LastParameter() instead -- an equally fabricated, equally
        // plausible "reasonable default" -- changes the result to `.knotAlignmentFailed`
        // rather than this test's `.invalidInput`, proving the averaging step itself has no
        // opinion on whether a fabricated value should be allowed through at all. The fix
        // rejects before any fallback value, fabricated or not, ever reaches the average.
        let p1 = try #require(Curve3D.interpolate(points: [SIMD3(-5, 0, 0), SIMD3(5, 0, 0)]))
        let p2 = try #require(Curve3D.interpolate(points: [SIMD3(0, -5, 3), SIMD3(0, 5, 3)]))
        let g1 = try #require(Curve3D.interpolate(points: [SIMD3(2, 2, -5), SIMD3(2, 2, 5)]))
        let g2 = try #require(Curve3D.interpolate(points: [SIMD3(4, -5, 3), SIMD3(4, 5, 3)]))

        let (surface, status) = Surface.networkSurface(
            profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-6)
        #expect(status == .invalidInput)
        #expect(surface == nil)
    }

    @Test func networkSurfaceReportsKnotAlignmentFailedWhenGuidesDoNotSpanProfiles() throws {
        // Restores the coverage the base commit's `networkSurfaceReportsKnotAlignmentFailedOn-
        // UnpreparedNetwork` used to give this status, deleted by this PR because its own
        // precondition (the quarter-cylinder network failing outright) no longer holds. Without
        // some other test pinning `.knotAlignmentFailed`, a regression in this PR's own
        // contact-point/averaging logic that silently changed the enum decode, or that made
        // GeomFill_NetworkSurface's real KnotAlignmentFailed stop propagating through
        // `outStatus`, would go unnoticed by CI.
        //
        // This is a genuinely well-formed network under the FIXED algorithm (no parallel pairs,
        // every extremum unambiguous) that still can't align: `alignSurfaces` requires the
        // averaged guide-locator parameters to span the SAME domain as the base profile's own
        // knot range (and the mirror image for profile-locators against the base guide's own
        // range) -- see the comment above `OCCTGeomFillNetworkSurface`. Here the guides only
        // cross the profiles at x=5 and x=15, well short of the profiles' own x=0...20 domain,
        // so the real, correctly-measured contact parameters ([5, 15]) can never match that
        // domain. This is a genuine, documented limitation of the low-level builder (it does not
        // reparametrize the input), not a bug: `gordon`/`gordonReport` handle this same network
        // by reparametrizing first.
        let p1 = try #require(Curve3D.interpolate(points: [SIMD3(0, 0, 0), SIMD3(20, 0, 0)]))
        let p2 = try #require(Curve3D.interpolate(points: [SIMD3(0, 10, 0), SIMD3(20, 10, 0)]))
        let g1 = try #require(Curve3D.interpolate(points: [SIMD3(5, 0, 0), SIMD3(5, 10, 0)]))
        let g2 = try #require(Curve3D.interpolate(points: [SIMD3(15, 0, 0), SIMD3(15, 10, 0)]))

        let (surface, status) = Surface.networkSurface(
            profiles: [p1, p2], guides: [g1, g2], tolerance: 1e-6)
        #expect(status == .knotAlignmentFailed)
        #expect(surface == nil)
    }
}
