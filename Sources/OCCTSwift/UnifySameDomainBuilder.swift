import Foundation
import OCCTBridge
import simd

/// Builder for unifying same-domain faces and edges with advanced control.
public final class UnifySameDomainBuilder: @unchecked Sendable {
    private let ref: OCCTUnifySameDomainRef

    /// Create a UnifySameDomain builder.
    ///
    /// `shape` is **not** modified: the builder works on a private copy, so a caller who discards
    /// the result still holds exactly the shape they passed in (#446 — the underlying OCCT
    /// algorithm rewrites sub-shapes of its input, which used to reach the caller's shape).
    ///
    /// The price of that copy is **identity**: `shape` (the result of ``shape``, that is) shares no
    /// sub-shapes with the input, even where nothing was merged, so `isSame(as:)` and friends answer
    /// `false` for faces that came through untouched. `keepShape(_:)` still takes the input's own
    /// sub-shapes — it maps them across for you.
    ///
    /// ```swift
    /// let unifier = UnifySameDomainBuilder(shape: body, unifyEdges: true, unifyFaces: true)
    /// unifier.setAngularTolerance(10.0 * .pi / 180)
    /// unifier.build()
    /// if let merged = unifier.shape, merged.isValidSolid { body = merged }
    /// // else: body is untouched, and usable
    /// ```
    ///
    /// - Parameters:
    ///   - shape: Input shape to unify (left unchanged)
    ///   - unifyEdges: Whether to unify edges (default true)
    ///   - unifyFaces: Whether to unify faces (default true)
    ///   - concatBSplines: Whether to concatenate adjacent BSplines (default false — note
    ///     ``Shape/unified(unifyEdges:unifyFaces:concatBSplines:)`` defaults this to `true`)
    public init(
        shape: Shape, unifyEdges: Bool = true, unifyFaces: Bool = true, concatBSplines: Bool = false
    ) {
        ref = OCCTUnifySameDomainCreate(shape.handle, unifyEdges, unifyFaces, concatBSplines)
    }

    deinit { OCCTUnifySameDomainRelease(ref) }

    /// Allow or disallow internal edges in unification.
    public func allowInternalEdges(_ allow: Bool) {
        OCCTUnifySameDomainAllowInternalEdges(ref, allow)
    }

    /// Keep a specific shape from being unified.
    ///
    /// Pass a sub-shape of the shape this builder was created with; it is matched to its
    /// counterpart in the builder's private copy for you.
    public func keepShape(_ shape: Shape) {
        OCCTUnifySameDomainKeepShape(ref, shape.handle)
    }

    /// Set OCCT's safe-input mode, which governs how freely the algorithm may rewrite the shape it
    /// is working on.
    ///
    /// This says nothing about *your* shape: the builder always works on a private copy, so the
    /// shape you passed in is never modified either way (#446). OCCT's own default is `true`.
    public func setSafeInputMode(_ safe: Bool) {
        OCCTUnifySameDomainSetSafeInputMode(ref, safe)
    }

    /// Set linear tolerance for unification.
    public func setLinearTolerance(_ tol: Double) {
        OCCTUnifySameDomainSetLinearTolerance(ref, tol)
    }

    /// Set angular tolerance for unification.
    public func setAngularTolerance(_ tol: Double) {
        OCCTUnifySameDomainSetAngularTolerance(ref, tol)
    }

    /// Build (perform unification).
    public func build() {
        OCCTUnifySameDomainBuild(ref)
    }

    /// Get the unified result shape.
    public var shape: Shape? {
        guard let h = OCCTUnifySameDomainShape(ref) else { return nil }
        return Shape(handle: h)
    }
}
