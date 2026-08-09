import Foundation
import OCCTBridge

/// An evolution function defining how a scalar value varies along a parameter range.
///
/// Used with `Shape.pipeShellWithLaw()` for variable-section sweeps where the
/// cross-section scales smoothly along the spine path.
public final class LawFunction: @unchecked Sendable {
    internal let handle: OCCTLawFunctionRef

    internal init(handle: OCCTLawFunctionRef) {
        self.handle = handle
    }

    deinit {
        OCCTLawFunctionRelease(handle)
    }

    // MARK: - Evaluation

    /// Evaluate the law function at a given parameter
    public func value(at parameter: Double) -> Double {
        OCCTLawFunctionValue(handle, parameter)
    }

    /// Parameter bounds of the law function
    public var bounds: ClosedRange<Double> {
        var first: Double = 0, last: Double = 0
        OCCTLawFunctionBounds(handle, &first, &last)
        return first...last
    }

    // MARK: - Factory Methods

    /// Create a constant law: the value is uniform over [first, last]
    public static func constant(_ value: Double, from first: Double = 0,
                                to last: Double = 1) -> LawFunction? {
        guard let h = OCCTLawCreateConstant(value, first, last) else { return nil }
        return LawFunction(handle: h)
    }

    /// Create a linear law: value ramps from startValue to endValue
    public static func linear(from startValue: Double, to endValue: Double,
                              parameterRange: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard let h = OCCTLawCreateLinear(parameterRange.lowerBound, startValue,
                                           parameterRange.upperBound, endValue)
        else { return nil }
        return LawFunction(handle: h)
    }

    /// Create an S-curve law: smooth sigmoid transition between start and end values
    public static func sCurve(from startValue: Double, to endValue: Double,
                              parameterRange: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard let h = OCCTLawCreateS(parameterRange.lowerBound, startValue,
                                      parameterRange.upperBound, endValue)
        else { return nil }
        return LawFunction(handle: h)
    }

    /// Create an interpolated law from (parameter, value) pairs
    /// - Parameters:
    ///   - points: Array of (parameter, value) tuples in ascending parameter order
    ///   - periodic: Whether the law is periodic
    public static func interpolate(points: [(parameter: Double, value: Double)],
                                   periodic: Bool = false) -> LawFunction? {
        guard points.count >= 2 else { return nil }
        var flat = [Double]()
        flat.reserveCapacity(points.count * 2)
        for pt in points {
            flat.append(pt.parameter)
            flat.append(pt.value)
        }
        let h = flat.withUnsafeBufferPointer { ptr in
            OCCTLawCreateInterpolate(ptr.baseAddress, Int32(points.count), periodic)
        }
        guard let h = h else { return nil }
        return LawFunction(handle: h)
    }

    /// Create a BSpline law from control poles and knot vector
    /// - Parameters:
    ///   - poles: Control point values (1D)
    ///   - knots: Knot values
    ///   - multiplicities: Knot multiplicities
    ///   - degree: Polynomial degree
    public static func bspline(poles: [Double], knots: [Double],
                               multiplicities: [Int32],
                               degree: Int) -> LawFunction? {
        guard poles.count >= 2, knots.count >= 2 else { return nil }
        let h = poles.withUnsafeBufferPointer { pPtr in
            knots.withUnsafeBufferPointer { kPtr in
                multiplicities.withUnsafeBufferPointer { mPtr in
                    OCCTLawCreateBSpline(pPtr.baseAddress, Int32(poles.count),
                                         kPtr.baseAddress, Int32(knots.count),
                                         mPtr.baseAddress, Int32(degree))
                }
            }
        }
        guard let h = h else { return nil }
        return LawFunction(handle: h)
    }

    // MARK: - v0.68.0: Composite Law and Knot Splitting

    /// Create a composite law by stitching multiple sub-laws together.
    ///
    /// - Parameters:
    ///   - laws: Array of sub-law functions in parameter order
    ///   - range: Overall parametric range
    /// - Returns: Composite law function
    public static func composite(laws: [LawFunction],
                                 range: ClosedRange<Double> = 0...1) -> LawFunction? {
        guard laws.count >= 1 else { return nil }
        let handles = laws.map { $0.handle as OCCTLawFunctionRef }
        return handles.withUnsafeBufferPointer { buf in
            guard let h = OCCTLawComposite(buf.baseAddress!, Int32(laws.count),
                range.lowerBound, range.upperBound) else { return nil as LawFunction? }
            return LawFunction(handle: h)
        }
    }

    /// Find knot indices where a BSpline law drops below given continuity.
    ///
    /// Only works on BSpline-based law functions. Returns raw indices into the underlying
    /// `Law_BSpline`'s own knot table -- not directly usable against `value(at:)` or
    /// `bounds`, since this API exposes no way to read that knot table back. See
    /// `knotSplitParameters(continuityOrder:)` for the actual parameter values (#403).
    ///
    /// ```swift
    /// let indices = law.knotSplitting(continuityOrder: .c2)
    /// let params  = law.knotSplitParameters(continuityOrder: .c2)
    /// // Same analyzer over the same law: indices[i] is the knot-table index of params[i],
    /// // so the two always agree on count, however many splits the law has (#481).
    /// ```
    ///
    /// - Parameter continuityOrder: Minimum continuity to require of each arc. This is a
    ///   derivative order, and `Law_BSplineKnotSplitting` splits a knot only when
    ///   `degree - multiplicity < continuityOrder`, so the meaningful range is 0...degree and it
    ///   saturates there: a cubic law with simple interior knots is already C2 at every
    ///   interior knot, and only ``ParametricContinuity/c3`` reports them (#480).
    /// - Returns: Array of knot indices where continuity breaks, or empty array
    public func knotSplitting(continuityOrder: ParametricContinuity = .c1) -> [Int] {
        // Same retry-on-truncation pattern as knotSplitParameters below: the bridge always
        // reports the true split count even when it writes fewer, so one retry sized to
        // that count is always enough. #481: this used to keep whatever fitted in a fixed
        // 100-entry buffer, so a law with more splits than that reported exactly 100 and
        // disagreed with its sibling about how many splits the law has.
        func read(capacity: Int32) -> (count: Int32, indices: [Int32]) {
            var indices = [Int32](repeating: 0, count: Int(capacity))
            let count = OCCTLawBSplineKnotSplitting(handle, continuityOrder.rawValue, &indices, capacity)
            return (count, indices)
        }

        var (count, indices) = read(capacity: 100)
        guard count >= 0 else { return [] }
        if count > 100 {
            (count, indices) = read(capacity: count)
            guard count >= 0 else { return [] }
        }
        return indices.prefix(Int(count)).map(Int.init)
    }

    /// Parameter values (not raw knot indices) at which continuity drops below `continuityOrder`.
    ///
    /// The law-function analogue of `Curve3D.continuityBreaks`: a law's discontinuities,
    /// like a curve's, are inherently 1D, so parameter values (directly usable with
    /// `value(at:)`, and bounded by `bounds`) are the natural shape here too -- unlike
    /// `knotSplitting(continuityOrder:)`'s raw indices, which the public API otherwise
    /// exposes no way to interpret. Added alongside `Surface.knotSplitting`'s new parameter
    /// fields in #403: same "cheap to compute, previously dropped" gap.
    ///
    /// ```swift
    /// // A cubic law with simple interior knots is already C2 there, so .c3 is the order
    /// // that reports its interior knots; anything below returns just the two end knots.
    /// let breaks = law.knotSplitParameters(continuityOrder: .c3)
    /// // breaks are real parameters within law.bounds, usable e.g. as sweep split points
    /// ```
    ///
    /// - Parameter continuityOrder: Minimum continuity to require of each arc, same derivative
    ///   order contract as `knotSplitting(continuityOrder:)` (#480)
    /// - Returns: Split parameters in ascending order, or empty array if not a BSpline-based law
    public func knotSplitParameters(continuityOrder: ParametricContinuity = .c1) -> [Double] {
        // Same retry-on-truncation pattern as Curve3D.continuityBreaks: the bridge always
        // reports the true split count even when it writes fewer, so one retry sized to
        // that count is always enough.
        func read(capacity: Int32) -> (count: Int32, params: [Double]) {
            var params = [Double](repeating: 0, count: Int(capacity))
            let count = OCCTLawBSplineKnotSplitParams(handle, continuityOrder.rawValue, &params, capacity)
            return (count, params)
        }

        var (count, params) = read(capacity: 100)
        guard count >= 0 else { return [] }
        if count > 100 {
            (count, params) = read(capacity: count)
            guard count >= 0 else { return [] }
        }
        return Array(params.prefix(Int(count)))
    }
}

extension LawFunction {
    /// Create an interpolated law function from values.
    public static func interpolated(values: [Double], parameters: [Double]? = nil, periodic: Bool = false) -> LawFunction? {
        let ref: OCCTLawFunctionRef?
        if let params = parameters {
            ref = params.withUnsafeBufferPointer { paramBuf in
                values.withUnsafeBufferPointer { valBuf in
                    OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), paramBuf.baseAddress!, periodic)
                }
            }
        } else {
            ref = values.withUnsafeBufferPointer { valBuf in
                OCCTLawInterpolate(valBuf.baseAddress!, Int32(values.count), nil, periodic)
            }
        }
        guard let r = ref else { return nil }
        return LawFunction(handle: r)
    }
}
