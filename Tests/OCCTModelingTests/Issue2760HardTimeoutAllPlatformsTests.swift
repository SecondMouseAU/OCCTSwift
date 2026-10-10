import Foundation
import Testing

@testable import OCCTSwift

/// #2760: `Shape.isSelfIntersecting(hardTimeout:)` exists on every platform.
///
/// On Apple it is a hard wall-clock bound (a background thread); on `wasm32-unknown-wasip1` there is
/// no second thread, so it is the cooperative `isSelfIntersecting(timeout:)` under the same name.
/// `Issue208SelfIntersectionTests` covers the Apple semantics and is excluded from the wasm suites,
/// so this file, which is not excluded, is what makes the call site compile and answer correctly on
/// wasm too. Nothing here asserts a hard deadline, because on wasm there is none to assert.
@Suite("Issue #2760, isSelfIntersecting(hardTimeout:) on every platform")
struct Issue2760HardTimeoutAllPlatforms {

    private func overlappingCompound() -> Shape? {
        guard let a = Shape.box(origin: SIMD3(0, 0, 0), width: 10, height: 10, depth: 10),
            let b = Shape.box(origin: SIMD3(5, 0, 0), width: 10, height: 10, depth: 10)
        else { return nil }
        return Shape.compound([a, b])
    }

    @Test("a clean solid answers false")
    func cleanSolidIsClean() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(box.isSelfIntersecting(hardTimeout: 30) == false)
    }

    @Test("overlapping solids in one compound answer true")
    func overlappingCompoundIsSelfIntersecting() throws {
        let compound = try #require(overlappingCompound())
        #expect(compound.isSelfIntersecting(hardTimeout: 30) == true)
    }

    @Test("a nullified shape is indeterminate, never a measurement")
    func nullifiedShapeIsIndeterminate() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(nulled.isSelfIntersecting(hardTimeout: 5) == nil)
    }

    // Measured on Apple: a deadline already in the past returns nil with no conclusive answer, for
    // a conclusive shape of either kind. The wasm body guards `<= 0` to match; without that guard
    // it would inherit `timeout:`'s "non-positive means unbounded" and answer true/false here.
    @Test("a non-positive bound returns nil on every platform, not an unbounded answer")
    func nonPositiveBoundIsNil() throws {
        let compound = try #require(overlappingCompound())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        for t in [0.0, -1.0, -Double.infinity] {
            #expect(compound.isSelfIntersecting(hardTimeout: t) == nil)
            #expect(box.isSelfIntersecting(hardTimeout: t) == nil)
        }
    }

    // NaN is not `<= 0`, so it is deliberately NOT in the loop above. Measured on Apple: a NaN
    // deadline never expires and the check answers. The wasm body falls through to the cooperative
    // call for the same reason. Kilo asked for it in the nil loop on #3229; that would assert the
    // wrong thing, so it has its own test.
    @Test("a NaN bound never expires, so the check answers on every platform")
    func nanBoundAnswers() throws {
        let compound = try #require(overlappingCompound())
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        #expect(compound.isSelfIntersecting(hardTimeout: .nan) == true)
        #expect(box.isSelfIntersecting(hardTimeout: .nan) == false)
    }

    // The expiry path cannot be forced deterministically: OCCT may find the fault before its first
    // checkpoint, so the outcome is `true` or `nil`. What must hold on both platforms is that an
    // expired bound never reads as a clean answer for a shape that does self-intersect.
    @Test("a near-zero bound is indeterminate or conclusive, never a false clean")
    func nearZeroBoundIsNeverFalseClean() throws {
        let compound = try #require(overlappingCompound())
        let r = compound.isSelfIntersecting(hardTimeout: 1e-7)
        #expect(r == nil || r == true)
    }

    #if os(WASI)
        // The documented wasm contract: the same name IS the cooperative variant.
        @Test("on wasm hardTimeout: agrees with timeout:")
        func wasmIsCooperativeVariant() throws {
            let compound = try #require(overlappingCompound())
            #expect(
                compound.isSelfIntersecting(hardTimeout: 30)
                    == compound.isSelfIntersecting(timeout: 30))
        }
    #endif
}
