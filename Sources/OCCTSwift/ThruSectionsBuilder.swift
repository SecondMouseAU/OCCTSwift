import Foundation
import OCCTBridge
import simd

/// Builder for lofted shapes through multiple wire sections.
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

    /// Enable/disable smoothing.
    public func setSmoothing(_ smoothing: Bool) {
        OCCTThruSectionsSetSmoothing(ref, smoothing)
    }

    /// Set the maximum BSpline degree.
    public func setMaxDegree(_ maxDeg: Int) {
        OCCTThruSectionsSetMaxDegree(ref, Int32(maxDeg))
    }

    /// Set the continuity criterion for the lofted surface.
    ///
    /// A ``ParametricContinuity`` raw value (0=C0, 1=C1, 2=C2, 3=C3; anything above asks for CN).
    /// `BRepOffsetAPI_ThruSections` accepts every value without failing. This used to read only
    /// 0 and 1, mapping everything else to C2 (#490).
    public func setContinuity(_ continuity: Int) {
        OCCTThruSectionsSetContinuity(ref, Int32(continuity))
    }

    /// Build the lofted shape.
    @discardableResult
    public func build() -> Bool {
        OCCTThruSectionsBuild(ref)
    }

    /// Get the result shape, or `nil` if the most recent ``build()`` call did not succeed.
    public var shape: Shape? {
        guard let h = OCCTThruSectionsShape(ref) else { return nil }
        return Shape(handle: h)
    }
}

extension ThruSectionsBuilder {
    /// Enable/disable wire compatibility checking (reorders wires to avoid twists).
    public func checkCompatibility(_ check: Bool = true) {
        OCCTThruSectionsCheckCompatibility(ref, check)
    }

    /// Set parameterization type.
    /// - Parameter type: 0=ChordLength, 1=Centripetal, 2=IsoParametric
    public func setParType(_ type: Int) {
        OCCTThruSectionsSetParType(ref, Int32(type))
    }

    /// Set criterium weights for the approximation algorithm.
    public func setCriteriumWeight(w1: Double, w2: Double, w3: Double) {
        OCCTThruSectionsSetCriteriumWeight(ref, w1, w2, w3)
    }

    /// Get the face generated from a profile edge after the loft is built.
    ///
    /// Returns `nil` if `edge` isn't a profile edge the build used, or if the most recent
    /// ``build()`` call on this instance did not succeed. This is checked explicitly on every
    /// call, including on a reused builder: OCCT's own internal state does not reset itself
    /// between builds, so without this check a failed rebuild could otherwise return an earlier
    /// successful build's geometry instead of `nil`.
    public func generatedFace(from edge: Shape) -> Shape? {
        guard let h = OCCTThruSectionsGeneratedFace(ref, edge.handle) else { return nil }
        return Shape(handle: h)
    }
}
