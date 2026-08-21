import Foundation
import OCCTBridge
import simd

/// Builder for lofted shapes through multiple wire sections.
///
/// A builder can be reused across multiple `build()` calls, but every accessor answers `nil`
/// unless `build()` has succeeded *since* the most recent section or setting change, see
/// ``shape``'s doc comment for the full list of what invalidates it:
///
/// ```swift
/// let loft = ThruSectionsBuilder(isSolid: true)
/// loft.addWire(bottomProfile)
/// loft.addWire(topProfile)
/// if loft.build() {
///     print(loft.shape != nil) // true
/// }
///
/// loft.addWire(anotherProfile) // invalidates the successful build above
/// print(loft.shape) // nil, build() hasn't run since the new section was added
/// _ = loft.build() // re-arms shape/generatedFace(from:) for the new section set
/// ```
///
/// `@unchecked Sendable` reflects that a single instance's `ref` is a plain bridge handle, not
/// that concurrent use of one instance from multiple threads is safe, it isn't (no internal
/// synchronization, same as every other builder wrapper in this package). Serialize access to a
/// shared instance with `OCCTSerial.withLock { }`; see `docs/thread-safety.md`.
public final class ThruSectionsBuilder: @unchecked Sendable {
    internal let ref: OCCTThruSectionsRef

    /// Create a ThruSections builder.
    /// - Parameters:
    ///   - isSolid: Whether to create a solid (true) or shell (false)
    ///   - isRuled: Whether to use ruled surfaces
    ///   - precision: 3D tolerance
    public init(isSolid: Bool = true, isRuled: Bool = false, precision: Double = 1e-6) {
        ref = OCCTThruSectionsCreate(isSolid, isRuled, precision)
    }

    deinit {
        OCCTThruSectionsRelease(ref)
    }

    /// Add a wire profile.
    public func addWire(_ wire: Shape) {
        OCCTThruSectionsAddWire(ref, wire.handle)
    }

    /// Add a vertex (point) as a degenerate section.
    public func addVertex(_ vertex: Shape) {
        OCCTThruSectionsAddVertex(ref, vertex.handle)
    }

    /// Enable/disable smoothing. Invalidates ``shape``/``generatedFace(from:)`` until the next
    /// successful ``build()``, see ``shape``'s doc comment.
    public func setSmoothing(_ smoothing: Bool) {
        OCCTThruSectionsSetSmoothing(ref, smoothing)
    }

    /// Set the maximum BSpline degree. Invalidates ``shape``/``generatedFace(from:)`` until the
    /// next successful ``build()``, see ``shape``'s doc comment.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTThruSectionsSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set the continuity criterion for the lofted surface.
    ///
    /// A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3; anything above asks for CN).
    /// `BRepOffsetAPI_ThruSections` accepts every value without failing. This used to read only
    /// 0 and 1, mapping everything else to C2 (#490). Invalidates ``shape``/``generatedFace(from:)``
    /// until the next successful ``build()``, see ``shape``'s doc comment.
    public func setContinuity(_ continuity: Int) {
        OCCTThruSectionsSetContinuity(ref, Int32(continuity))
    }

    /// Build the lofted shape.
    @discardableResult
    public func build() -> Bool {
        OCCTThruSectionsBuild(ref)
    }

    /// The result shape from the most recent successful build, or `nil`.
    ///
    /// `nil` unless a ``build()`` call has succeeded *since* the most recent change to this
    /// builder's sections (``addWire(_:)``/``addVertex(_:)``) or settings (``setSmoothing(_:)``,
    /// ``setMaxDegree(_:)``, ``setContinuity(_:)``, ``checkCompatibility(_:)``,
    /// ``setParType(_:)``, ``setCriteriumWeight(w1:w2:w3:)``). Every one of those calls
    /// invalidates the previous build's result the same way, so this never answers with geometry
    /// that predates a change the caller has since made, including on a builder reused across
    /// multiple `build()` calls, where OCCT's own internal state does not reset itself between
    /// builds.
    public var shape: Shape? {
        guard let h = OCCTThruSectionsShape(ref) else { return nil }
        return Shape(handle: h)
    }
}

extension ThruSectionsBuilder {
    /// Enable/disable wire compatibility checking (reorders wires to avoid twists). Invalidates
    /// ``shape``/``generatedFace(from:)`` until the next successful ``build()``, see ``shape``'s
    /// doc comment.
    public func checkCompatibility(_ check: Bool = true) {
        OCCTThruSectionsCheckCompatibility(ref, check)
    }

    /// Set parameterization type. Invalidates ``shape``/``generatedFace(from:)`` until the next
    /// successful ``build()``, see ``shape``'s doc comment.
    /// - Parameter type: 0=ChordLength, 1=Centripetal, 2=IsoParametric
    public func setParType(_ type: Int) {
        OCCTThruSectionsSetParType(ref, Int32(type))
    }

    /// Set criterium weights for the approximation algorithm. Invalidates
    /// ``shape``/``generatedFace(from:)`` until the next successful ``build()``, see ``shape``'s
    /// doc comment. Returns `true` if all weights are non-negative; returns `false` and does not
    /// update the builder if any weight is negative (OCCT silently ignores negative weights and
    /// `Build()` erases the failure status, making the rejection unobservable otherwise).
    @discardableResult
    public func setCriteriumWeight(w1: Double, w2: Double, w3: Double) -> Bool {
        OCCTThruSectionsSetCriteriumWeight(ref, w1, w2, w3)
    }

    /// Get the face generated from a profile edge after the loft is built.
    ///
    /// - Parameter edge: A profile edge from one of the input wires.
    /// - Returns: The generated face, or `nil` if `edge` isn't a profile edge of the current
    ///   build, if ``shape`` itself would be `nil` right now (see its doc comment for the full
    ///   invalidation list), or, on a builder reused across a success → failure → success
    ///   sequence, if `edge`'s bound face is a leftover from an *earlier* successful build that
    ///   the current one never overwrote. OCCT's `myEdgeFace` map is never cleared between
    ///   builds, so a reconciliation (``checkCompatibility(_:)``) can rebuild every section's
    ///   edges and leave a stale edge → face binding queryable through an edge the caller
    ///   obtained before the failed build in between; this is checked by confirming the returned
    ///   face is actually part of the current ``shape``, not just present in the map, before
    ///   returning it (#910 review round 2).
    ///
    /// ```swift
    /// let loft = ThruSectionsBuilder(isSolid: true)
    /// loft.addWire(bottom)
    /// loft.addWire(top)
    /// guard loft.build(), let edge = bottom.subShapes(ofType: .edge).first else { return }
    /// let face = loft.generatedFace(from: edge)  // the side face swept from `edge`
    ///
    /// loft.addWire(mismatchedSection)
    /// _ = loft.build()                    // false
    /// loft.generatedFace(from: edge)      // nil, not the previous build's face
    /// ```
    public func generatedFace(from edge: Shape) -> Shape? {
        guard let h = OCCTThruSectionsGeneratedFace(ref, edge.handle) else { return nil }
        return Shape(handle: h)
    }
}
