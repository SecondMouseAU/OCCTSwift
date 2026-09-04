import Testing
import simd

@testable import OCCTSwift

/// Both fixtures below deliberately use ``Shape/box(origin:width:height:depth:)`` (corner at
/// `origin`), never the origin-less ``Shape/box(width:height:depth:)``, which is centered on
/// (0,0,0), not corner-at-origin -- using it here would place box1 at `[-5,5]^3`, touching box2 at
/// `[5,15]^3` only at a single boundary point (zero-volume "overlap"), silently turning every
/// assertion below into a check of disjoint-shape behavior instead of the real intersection this
/// suite exists to exercise. (An earlier draft of this suite made exactly that mistake and its
/// volumes came back internally consistent -- 2000/1000 instead of 1875/875 -- which is what made
/// it easy to miss without ground-truthing the fixture itself.)
///
/// box1 `[0,10]^3` (volume 1000) and box2 `[5,15]^3` (volume 1000) overlap in the 5x5x5 cube
/// `[5,10]^3` (volume 125). Ground truth ``BRepAlgoAPI_Fuse``/``BRepAlgoAPI_Cut`` on the identical
/// pair (verified independently via a standalone ground-truth reproducer against the pinned
/// kernel, see #1458): fuse = 1000 + 1000 - 125 = 1875, cut = 1000 - 125 = 875.
@Suite("BRepFeat Builder")
struct BRepFeatBuilderTests {
    private static func overlappingBoxes() -> (Shape, Shape)? {
        guard
            let box1 = Shape.box(
                origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let box2 = Shape.box(
                origin: SIMD3(5, 5, 5), width: 10, height: 10, depth: 10)
        else { return nil }
        return (box1, box2)
    }

    // A box [0,10]^3 (volume 1000) and a sphere of radius 5 centered at (5,5,10) (volume
    // 523.598776) overlap in the sphere's lower hemisphere, [5,10] in Z. Ground truth
    // BRepAlgoAPI_Fuse/Cut on the identical pair, verified via the same standalone reproducer:
    // fuse = 1261.799388, cut = 738.200612.
    private static func boxAndOverlappingSphere() -> (Shape, Shape)? {
        guard
            let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let sphere = Shape.sphere(center: SIMD3(5, 5, 10), radius: 5)
        else { return nil }
        return (box, sphere)
    }

    // #1458: OCCTBRepFeatBuilderFuse never called BRepFeat_Builder::Perform(), so myShape was
    // never populated by the intersection pipeline and PerformResult() built the result from an
    // empty default-constructed shape -- silently returning an empty (zero-volume) compound for
    // every call, while HasErrors() stayed false and the returned handle stayed non-nil. A test
    // asserting only `result != nil` / `result.isValid` cannot see this: an empty compound is
    // trivially valid. Proved against the actual unfixed function (temporarily reverted, not just
    // reasoned about): this test failed with volume 0.0 instead of 1875.0, then passed once the
    // fix was restored.
    @Test("Feature fuse two overlapping boxes produces the real union volume")
    func featFuse() throws {
        let (box1, box2) = try #require(Self.overlappingBoxes())
        let result = try #require(box1.featFuse(with: box2))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 1875.0) < 0.01)
    }

    // #1458: OCCTBRepFeatBuilderCut had the identical missing-Perform() defect, so
    // PerformResult() ran BuildShape() over an unintersected default shape and the function
    // silently returned the caller's own input, byte-for-byte unmodified -- an apparent success
    // that removed nothing. Proved against the actual unfixed function: this test failed with
    // volume 1000.0 (the untouched box1) instead of 875.0, then passed once the fix was restored.
    @Test("Feature cut removes the overlap volume from the base shape")
    func featCut() throws {
        let (box1, box2) = try #require(Self.overlappingBoxes())
        let result = try #require(box1.featCut(with: box2))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        #expect(abs(volume - 875.0) < 0.01)
    }

    // A second, independent fixture (sphere overlapping a box, per #1458's own ground-truth
    // table) so the regression coverage does not depend on box-specific arithmetic alone.
    @Test("Feature fuse of a box and an overlapping sphere matches BRepAlgoAPI_Fuse")
    func featFuseBoxSphere() throws {
        let (box, sphere) = try #require(Self.boxAndOverlappingSphere())
        let result = try #require(box.featFuse(with: sphere))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        // Ground truth: BRepAlgoAPI_Fuse on the identical pair measures 1261.799388.
        #expect(abs(volume - 1261.799388) < 0.01)
    }

    @Test("Feature cut of a sphere from a box matches BRepAlgoAPI_Cut")
    func featCutBoxSphere() throws {
        let (box, sphere) = try #require(Self.boxAndOverlappingSphere())
        let result = try #require(box.featCut(with: sphere))
        #expect(result.isValid)
        let volume = try #require(result.volume)
        // Ground truth: BRepAlgoAPI_Cut on the identical pair measures 738.200612.
        #expect(abs(volume - 738.200612) < 0.01)
    }
}
