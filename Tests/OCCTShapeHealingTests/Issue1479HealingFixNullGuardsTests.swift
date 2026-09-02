import Foundation
import OCCTBridge
import Testing
import simd

@testable import OCCTSwift

/// #1479: two null-guard gaps in `OCCTBridge_Healing_Fix.mm`.
///
/// **Finding 1, `OCCTShapeFixComposeShell`**: had no guard at all, not even a raw-pointer null
/// check, and reached OCCT via `*(const TopoDS_Shape*)faceRef`, a raw pointer cast rather than
/// this bridge's usual `shape->shape` field access -- which is why `check-null-handle-guards.py`
/// reported the file clean, its pattern-matcher expects the field-access form. Reachable from the
/// public (deprecated) `Shape.nullified` -> `Shape.composeShell(precision:)`: a non-null
/// `OCCTShapeRef` wrapping a null `TopoDS_Shape`. `TopoDS::Face()` passes a null shape through
/// without throwing, and `BRep_Tool::Surface(const TopoDS_Face&)` then dereferences a null `TF`
/// unconditionally, an OS signal (SIGSEGV), not a C++ exception, so the enclosing `try/catch (...)`
/// cannot stop it -- uncatchable in-process, so it cannot be reproduced inside this test suite.
/// Validated instead with a standalone before/after reproducer,
/// `Scripts/repro/1479-healing-fix-null-guards/repro_1479.mm`: the pre-fix body SIGSEGVs (exit
/// 139) on exactly this input, the post-fix body (an `occtShapeIsPresent(faceRef)` guard, added
/// at the top) returns `nullptr` cleanly. `composeShellOnNullifiedShapeReturnsNil` below proves the
/// guard's own condition is reached and taken -- that a nullified `Shape` now yields `nil` -- which
/// is the half of the fix `swift test` *can* observe directly.
///
/// **Finding 2, `OCCTShapeFixEdgeConnect`**: missing the plain `if (!shape) return nullptr;` its
/// sibling `OCCTShapeConnectEdges` (same file) already has. A genuinely-null `OCCTShapeRef`
/// pointer dereferences at `shape->shape`, also uncatchable. `Shape.handle` is non-optional, so
/// this path isn't reachable through the public Swift API (a `Shape` never wraps a nil handle);
/// `unsafeBitCast` synthesizes a zero-bit-pattern `OCCTShapeRef` that type-checks as non-optional
/// but is a genuine null pointer at the ABI level, matching Issue #1424's / #900's precedent. This
/// half *is* directly testable, since the guard's fallback (`nullptr`) is an ordinary return value,
/// not a crash recovery.
@Suite("Issue #1479: Healing_Fix.mm null guards")
struct Issue1479HealingFixNullGuardsTests {

    // MARK: - Finding 1: OCCTShapeFixComposeShell

    @Test("a nullified shape's composeShell(precision:) now returns nil, not a crash")
    func composeShellOnNullifiedShapeReturnsNil() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let nulled = try #require(box.nullified)
        #expect(nulled.composeShell() == nil)
    }

    @Test("a genuinely-null OCCTShapeRef passed to OCCTShapeFixComposeShell returns nil, not a crash")
    func composeShellNullRawPointerReturnsNil() {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)
        let result = OCCTShapeFixComposeShell(nullShape, 1e-6)
        #expect(result == nil)
    }

    @Test("an ordinary face's composeShell(precision:) is unaffected")
    func composeShellOrdinaryFaceUnaffected() throws {
        let rect = try #require(Wire.rectangle(width: 10, height: 10))
        let face = try #require(Shape.face(from: rect))
        let result = face.composeShell()
        #expect(result != nil)
        if let result {
            #expect(result.isValid)
        }
    }

    // MARK: - Finding 2: OCCTShapeFixEdgeConnect

    @Test("a genuinely-null OCCTShapeRef passed to OCCTShapeFixEdgeConnect returns nil, not a crash")
    func edgeConnectNullRawPointerReturnsNil() {
        let nullShape: OCCTShapeRef = unsafeBitCast(UInt(0), to: OCCTShapeRef.self)
        let result = OCCTShapeFixEdgeConnect(nullShape)
        #expect(result == nil)
    }

    @Test("an ordinary box's fixEdgeConnect() is unaffected")
    func edgeConnectOrdinaryShapeUnaffected() throws {
        let box = try #require(Shape.box(width: 10, height: 10, depth: 10))
        let fixed = box.fixEdgeConnect()
        #expect(fixed != nil)
    }
}
