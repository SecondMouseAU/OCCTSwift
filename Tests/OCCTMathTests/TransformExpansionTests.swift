import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("v0.115.0 - Transform Expansion")
struct TransformExpansionTests {

    @Test func generalTransform() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Identity rotation + translation by (5,0,0)
            let matrix = Matrix12Grouped([
                1, 0, 0,  // row 0 of rotation
                0, 1, 0,  // row 1
                0, 0, 1,  // row 2
                5, 0, 0,  // translation
            ])!
            let result = box.transformed(matrix: matrix)
            #expect(result != nil)
            if let r = result {
                #expect(r.isValid)
            }
        }
    }

    @Test func nonUniformScale() {
        if let box = Shape.box(width: 10, height: 10, depth: 10) {
            // Scale by (2, 1, 0.5) = non-uniform
            let matrix = TransformMatrix3D([
                2, 0, 0, 0,  // row 0: scaleX=2, no translate
                0, 1, 0, 0,  // row 1: scaleY=1
                0, 0, 0.5, 0,  // row 2: scaleZ=0.5
            ])!
            let result = box.gTransformed(matrix: matrix)
            #expect(result != nil)
        }
    }

    /// #835 regression: `transformed(matrix:)` uses a GROUPED layout
    /// (`[r00,r01,r02, r10,r11,r12, r20,r21,r22, tx,ty,tz]`), all nine rotation entries first,
    /// the three translation entries last. Locks in the documented convention against real
    /// bounding-box geometry, not just `result != nil`, so a future edit that accidentally
    /// aligns this method's array shape with `transformed(byMatrix:)`'s INTERLEAVED layout is
    /// caught here. Since #835's PR #864 review, `transformed(matrix:)` takes a
    /// ``Matrix12Grouped`` rather than a raw `[Double]`, so the layouts can no longer be
    /// swapped at a call site at all, this test is now about the GROUPED index mapping inside
    /// that type, not about which method you called.
    @Test func generalTransformGroupedLayoutTranslatesAsDocumented() {
        if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) {
            // Identity rotation, translate by (5, 0, 0). GROUPED: rotation first, then tx,ty,tz.
            let matrix = Matrix12Grouped([
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
                5, 0, 0,
            ])!
            let result = box.transformed(matrix: matrix)
            #expect(result != nil)
            if let r = result, let bb = r.boundingBox {
                #expect(abs(bb.min.x - 5.0) < 1e-6)
                #expect(abs(bb.max.x - 15.0) < 1e-6)
                #expect(abs(bb.min.y - 0.0) < 1e-6)
                #expect(abs(bb.max.y - 10.0) < 1e-6)
                #expect(abs(bb.min.z - 0.0) < 1e-6)
                #expect(abs(bb.max.z - 10.0) < 1e-6)
            }
        }
    }

    /// #835 regression: `gTransformed(matrix:)` uses the same INTERLEAVED row-major layout as
    /// `transformed(byMatrix:)` (`[r00,r01,r02,tx, r10,r11,r12,ty, r20,r21,r22,tz]`), NOT the
    /// GROUPED layout `transformed(matrix:)` uses. Locks in the documented convention against
    /// real bounding-box geometry.
    @Test func nonUniformScaleInterleavedLayoutScalesAsDocumented() {
        // Deliberately non-cubic (10 x 20 x 30): a cube's symmetric extent lets a wrong-layout
        // matrix that only reads column 0 coincidentally reproduce the right bounding box, which
        // would make the prove-the-test-fails injection below pass vacuously. See #835 PR notes.
        if let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 20, depth: 30) {
            // Scale by (2, 1, 0.5), no translation. INTERLEAVED: each row's own tx/ty/tz.
            let matrix = TransformMatrix3D([
                2, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 0.5, 0,
            ])!
            let result = box.gTransformed(matrix: matrix)
            #expect(result != nil)
            if let r = result, let bb = r.boundingBox {
                #expect(abs(bb.min.x - 0.0) < 1e-6)
                #expect(abs(bb.max.x - 20.0) < 1e-6)
                #expect(abs(bb.min.y - 0.0) < 1e-6)
                #expect(abs(bb.max.y - 20.0) < 1e-6)
                #expect(abs(bb.min.z - 0.0) < 1e-6)
                #expect(abs(bb.max.z - 15.0) < 1e-6)
            }
        }
    }

    /// #835 PR #864 review finding 1: the three transform methods used to take a plain
    /// `[Double]` distinguished only by which method you called, so a caller could silently
    /// garble a transform by feeding one method's array shape to another. `Matrix12Grouped` /
    /// `TransformMatrix3D` now make that a compile error. Locks in the *conversion* between the
    /// two layouts, `Matrix12Grouped.interleaved` / `TransformMatrix3D.grouped`, round-trips a
    /// transform correctly, so a caller who has one layout can still reach the method that wants
    /// the other without hand-shuffling indices.
    @Test func groupedInterleavedConversionRoundTripsTheSameTransform() {
        // A matrix with no accidental symmetry in either its rotation or its translation, so a
        // shuffled index would move the box to the wrong place rather than coincidentally the
        // right one.
        let grouped = Matrix12Grouped([
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
            5, 10, 15,
        ])!
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let viaGrouped = box.transformed(matrix: grouped)
        let viaInterleaved = box.transformed(byMatrix: grouped.interleaved)
        #expect(viaGrouped != nil)
        #expect(viaInterleaved != nil)
        if let a = viaGrouped?.boundingBox, let b = viaInterleaved?.boundingBox {
            #expect(abs(a.min.x - b.min.x) < 1e-6)
            #expect(abs(a.min.y - b.min.y) < 1e-6)
            #expect(abs(a.min.z - b.min.z) < 1e-6)
            #expect(abs(a.min.x - 5.0) < 1e-6)
            #expect(abs(a.min.y - 10.0) < 1e-6)
            #expect(abs(a.min.z - 15.0) < 1e-6)
        }
        // And the reverse conversion agrees too.
        #expect(grouped.interleaved.grouped.values == grouped.values)
    }

    /// #835 PR #864 review finding 1, the deprecated-overload half: the old `[Double]`-taking
    /// signatures are kept (marked `@available(*, deprecated)`) so existing external source still
    /// compiles, and still perform the exact same runtime validation they always did, `nil` on
    /// the wrong element count, not a trap. Since the PR #870 aggregate-review fix below
    /// (`typedInitializersReturnNilRatherThanTrapOnWrongCount`), `Matrix12Grouped`/
    /// `TransformMatrix3D`'s own raw-array initializers are `nil`-returning too, so these
    /// deprecated overloads are no longer the *only* path to graceful failure, but they stay,
    /// unchanged, for source compatibility with existing `[Double]` call sites.
    @Test func deprecatedArrayOverloadsStillWork() {
        guard let box = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10) else {
            Issue.record("box construction failed")
            return
        }
        let grouped: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 0]
        let interleaved: [Double] = [1, 0, 0, 5, 0, 1, 0, 10, 0, 0, 1, 15]

        let a = box.transformed(matrix: grouped)
        #expect(a != nil)
        if let bb = a?.boundingBox { #expect(abs(bb.min.x - 5.0) < 1e-6) }

        let b = box.gTransformed(matrix: interleaved)
        #expect(b != nil)
        if let bb = b?.boundingBox { #expect(abs(bb.min.x - 5.0) < 1e-6) }

        let c = box.transformed(byMatrix: interleaved)
        #expect(c != nil)
        if let bb = c?.boundingBox { #expect(abs(bb.min.x - 5.0) < 1e-6) }

        // Wrong element count still returns nil rather than trapping.
        #expect(box.transformed(matrix: [1, 0, 0]) == nil)
        #expect(box.gTransformed(matrix: [1, 0, 0]) == nil)
        #expect(box.transformed(byMatrix: [1, 0, 0]) == nil)
    }

    /// PR #870 aggregate review, correctness finding 1 (`TransformFactory.swift`):
    /// `Matrix12Grouped.init(_:)`/`TransformMatrix3D.init(_:)` used `precondition(values.count
    /// == 12, ...)`, which traps the whole process, debug *and* release, uncatchable
    /// in-process, on a wrong-count array, instead of returning `nil` the way the three
    /// `Shape` transform methods these types replaced always did for any `[Double]` input. A
    /// caller migrating off the deprecated `[Double]`-taking overloads (`deprecatedArrayOverloadsStillWork`
    /// above) onto these typed constructors directly, exactly what the deprecation message
    /// tells them to do, got a crash instead of the graceful `nil` they'd get either from the
    /// pre-#835 `Shape` methods or from the still-deprecated overloads.
    ///
    /// This test cannot literally "prove the crash used to happen and now doesn't": a passing
    /// test process can't also have crashed. What it proves instead is the fix, both
    /// initializers are now `init?`, returning `nil` for 11 and 13 elements (one short, one
    /// long) rather than trapping. Before this fix, `Matrix12Grouped(elevenElements)` and
    /// `TransformMatrix3D(thirteenElements)` would not even type-check as an `Optional`, the
    /// old signature was `init(_ values: [Double])`, non-failable, so this test's very shape
    /// (binding the result as `T?` and expecting `nil`) is itself evidence the initializer
    /// changed; on the pre-fix code this test does not compile, rather than compiling and
    /// failing, which is a stronger signal than a runtime-only check could give here since the
    /// defect being fixed is a process-fatal trap the test process could never observe and
    /// report on regardless.
    ///
    /// Injection actually run (`okf/policies/prove-the-test-fails.md`): reverted
    /// `TransformFactory.swift` to its exact pre-fix content (`git show HEAD:...`, non-failable
    /// `init`s with `precondition`), left this test as written, and ran `swift build --target
    /// OCCTMathTests`. Result: build failure before reaching this test at all, `Shape+Math.swift`
    /// (which this same PR updated to `guard let grouped = Matrix12Grouped(matrix) else {...}`)
    /// fails with "initializer for conditional binding must have Optional type, not
    /// 'Matrix12Grouped'", confirming the whole change (this test included) is genuinely coupled
    /// to the failable initializer, not accidentally passing regardless. Restored the fix
    /// afterwards; `swift test --filter TransformExpansionTests` then passed 7/7, this test
    /// included.
    @Test func typedInitializersReturnNilRatherThanTrapOnWrongCount() {
        let elevenElements = [Double](repeating: 0, count: 11)
        let thirteenElements = [Double](repeating: 0, count: 13)

        #expect(Matrix12Grouped(elevenElements) == nil)
        #expect(Matrix12Grouped(thirteenElements) == nil)
        #expect(TransformMatrix3D(elevenElements) == nil)
        #expect(TransformMatrix3D(thirteenElements) == nil)

        // The exact-12 case still succeeds (the failable init isn't just always nil).
        let twelveElements = [Double](repeating: 0, count: 12)
        #expect(Matrix12Grouped(twelveElements) != nil)
        #expect(TransformMatrix3D(twelveElements) != nil)
    }
}

