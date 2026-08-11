//
//  Sampling.swift
//  OCCTSwift
//
//  The one ceiling every sampling entry point measures a caller-supplied count
//  against, plus the three decisions that ceiling can drive.
//
//  Driver: issue #558 (split out of #479). A sampling count arrives from the
//  caller, sizes a Swift allocation, and is then cast to the `int32_t` the
//  bridge takes its count in. Both ends abort the process rather than failing:
//  `[Double](repeating:count:)` traps on a negative, and `Int32(_:)` traps past
//  `Int32.max`. #479 bounded two such entry points and declared the ceiling on
//  `ArcLengthCurveAdaptor`; measuring the rest of the family found 28, so the
//  ceiling moves here where all of them can see it.
//

/// The shared bound on how many samples any one call to this library will produce.
public enum Sampling {
    /// The largest sample count any sampling entry point will produce: 10 million points.
    ///
    /// Measured, not round (#479): sampling costs about 4.5 µs per point, and one sample costs
    /// 24 bytes in the bridge's packed `(x,y,z)` buffer plus 32 in the returned array, so the
    /// ceiling itself is already about 625 MB resident and 45 seconds of work. It is also two
    /// orders of magnitude below the `int32_t` the bridge takes its count in, which is where the
    /// process used to abort instead.
    ///
    /// Since #622 the same ceiling also bounds result buffers whose element is not a point, so
    /// "10 million points / ~625 MB" is the floor of its memory cost, not the whole of it: a
    /// ray hit is 88 bytes (about 880 MB at the ceiling) and a hatch segment is four doubles.
    /// The ceiling is deliberately *not* per-element-size — it is a count, and the `int32_t`
    /// conversion it keeps callers away from traps identically whatever the element weighs.
    ///
    /// ```swift
    /// let curve = Curve3D.segment(from: .zero, to: SIMD3(10, 0, 0))!
    /// curve.drawUniform(pointCount: Sampling.maximumSampleCount + 1).isEmpty   // true
    /// curve.drawAdaptive(maxPoints: Sampling.maximumSampleCount + 1)           // clamped, not empty
    /// ```
    public static let maximumSampleCount = 10_000_000

    /// A caller's *request* for exactly this many samples: honoured in full or not at all.
    ///
    /// Returns `nil` when the count is below `minimum` or above ``maximumSampleCount``, which
    /// every caller turns into its own documented empty value. There is no clamping: a request
    /// the ceiling cannot honour has to fail visibly, because coming back silently coarser than
    /// what was asked for is the defect #501 found in the one sampler that did clamp a request.
    ///
    /// - Parameters:
    ///   - count: The caller's requested sample count.
    ///   - minimum: The entry point's own documented lower bound, usually OCCT's `>= 2` (which a
    ///     Release kernel compiles its precondition out of, #501) and occasionally `>= 1`.
    internal static func requested(_ count: Int, atLeast minimum: Int = 2) -> Int? {
        guard count >= minimum, count <= maximumSampleCount else { return nil }
        return count
    }

    /// The sample count implied by dividing `length` into steps of `spacing`: `round(length /
    /// spacing) + 1`, floored at 2 (`GCPnts_UniformAbscissa`'s own minimum, #501). `nil` when
    /// `spacing` or `length` isn't positive, or the implied count exceeds ``maximumSampleCount``.
    ///
    /// One derivation shared by every caller that turns a spacing into a bounded point count —
    /// `ArcLengthCurveAdaptor.points(spacing:)` established it first (#479); `Shape.uniformAbscissa(distance:)`
    /// and its `u1:u2:` sibling mirror it (#853) — so a future correction to the formula lands in
    /// one place instead of three unlinked copies (#862).
    ///
    /// Stays in `Double` for the derivation: `Int(_:)` on a `Double` past `Int.max` is a trap, not
    /// an error, and both `length` and `spacing` are caller-supplied. Anything the ceiling cannot
    /// honour is rejected here, so the conversion to `Int` below is always in range.
    internal static func impliedCount(length: Double, spacing: Double) -> Int? {
        guard spacing > 0, length > 0 else { return nil }
        let implied = (length / spacing).rounded() + 1
        guard implied <= Double(maximumSampleCount) else { return nil }
        return max(2, Int(implied))
    }

    /// A caller's *capacity* for at most this many samples: clamped into `0...`
    /// ``maximumSampleCount``.
    ///
    /// Unlike ``requested(_:atLeast:)`` this clamps rather than rejects, because a capacity does
    /// not decide the answer. An adaptive sampler picks its own point count from a deflection
    /// tolerance and uses the capacity only to truncate, so lowering an unservable capacity to
    /// the ceiling returns the *same* points the caller would have got — there is nothing to
    /// coarsen. A capacity below zero is not a smaller capacity, it is no capacity: it clamps to
    /// 0, and every caller returns its documented empty value rather than calling the bridge with
    /// a zero-length buffer.
    internal static func capacity(_ maxPoints: Int) -> Int {
        min(max(maxPoints, 0), maximumSampleCount)
    }

    /// A grid *request* of `factors` samples per direction: bounds the **product**, and each
    /// factor on its own.
    ///
    /// Returns the total sample count, or `nil` if any factor is below `minimum` or the product
    /// exceeds ``maximumSampleCount``. Checking the factors individually is not redundant with
    /// checking the product: two negative factors multiply to a perfectly plausible positive
    /// total, which is exactly why `Surface.drawMesh(uCount: -1, vCount: -1)` used to look
    /// well-behaved while `drawMesh(uCount: -1, vCount: 3)` aborted the process (#558). The
    /// multiplication is overflow-checked for the same reason: `Int` wraps into a trap of its own
    /// well before the ceiling is reached.
    internal static func gridTotal(_ factors: Int..., atLeast minimum: Int = 1) -> Int? {
        var total = 1
        for factor in factors {
            guard factor >= minimum else { return nil }
            let (product, overflowed) = total.multipliedReportingOverflow(by: factor)
            guard !overflowed else { return nil }
            total = product
        }
        guard total <= maximumSampleCount else { return nil }
        return total
    }
}
