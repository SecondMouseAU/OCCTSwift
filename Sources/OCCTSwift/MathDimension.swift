//
//  MathDimension.swift
//  OCCTSwift
//
//  The one validator every problem-dimension argument in MathLibrary.swift and
//  MathSolver.swift is checked against, plus the two shapes that check takes.
//
//  Driver: review of PR #716 (issue #640), finding 9. #634 (issue #622) bounded 21
//  sampling-shaped result buffers and deliberately left this family unfixed: its numbers
//  are problem dimensions that must agree with the caller's OWN arrays, not sampling
//  capacities, so `Sampling.requested`/`capacity` was the wrong tool. #640 then fixed 18
//  call sites by hand, each repeating one of two shapes -- "n is positive and every array
//  n sizes is exactly that long", or "rows and cols are both positive and a flat array is
//  exactly their product" -- with no shared validator: the same "no compiler help across
//  N hand-duplicated sites" gap #634's own ad hoc guards left before it (5 of 20 invisible
//  to review once). This file is that validator.
//
//  It also closes a defect the hand-written guards shared (review finding 8): `n * n` and
//  `rows * cols` are plain `Int` multiplications, and a large enough positive dimension
//  overflows that multiplication before the guard can reject it -- the exact process trap
//  #640 exists to eliminate, reintroduced by the guard meant to prevent it.
//  `Sampling.gridTotal` already carries the overflow-safe idiom
//  (`multipliedReportingOverflow(by:)`); this reuses it rather than inventing another.
//

/// Validates a problem-dimension argument against the arrays it sizes.
///
/// Not `Sampling`: a problem dimension is not a subdivision count. It has no shared
/// ceiling, and clamping one would hand back a garbage-dimension solve rather than
/// truncating a result set. What every site in this family shares instead is the shape of
/// the check, which is what this type factors out.
enum MathDimension {

    /// `n` must be positive, and every array length in `counts` must equal it exactly.
    ///
    /// This is the `startPoint.count == variables` shape: one dimension sizing one or more
    /// flat, `n`-length arrays.
    ///
    /// ```swift
    /// MathDimension.valid(3, matches: 3, 3)   // true
    /// MathDimension.valid(-1, matches: 0)     // false -- not positive
    /// MathDimension.valid(3, matches: 1)      // false -- length mismatch
    /// ```
    static func valid(_ n: Int, matches counts: Int...) -> Bool {
        guard n > 0 else { return false }
        return counts.allSatisfy { $0 == n }
    }

    /// Every array length in `counts` must equal `n` exactly.
    ///
    /// Unlike ``valid(_:matches:)`` this does not also require `n` to be positive, for the
    /// sites where `n` is itself another array's `.count` and can never be negative (#640's
    /// own five "invisible to a trap-shaped census" sites): requiring positivity there would
    /// reject a legitimate empty input the original, unguarded code accepted.
    ///
    /// ```swift
    /// MathDimension.consistent(0, matches: 0)    // true -- two empty arrays agree
    /// MathDimension.consistent(50, matches: 1)   // false -- length mismatch
    /// ```
    static func consistent(_ n: Int, matches counts: Int...) -> Bool {
        counts.allSatisfy { $0 == n }
    }

    /// `n` must be positive, and `count` must equal `n * n` exactly -- checked without
    /// overflowing the multiplication (review finding 8): a large enough positive `n` makes
    /// `n * n` trap before a plain `==` guard ever runs.
    ///
    /// ```swift
    /// MathDimension.validSquare(2, count: 4)      // true
    /// MathDimension.validSquare(.max, count: 1)   // false -- rejected, not trapped
    /// ```
    static func validSquare(_ n: Int, count: Int) -> Bool {
        guard n > 0 else { return false }
        let (product, overflowed) = n.multipliedReportingOverflow(by: n)
        guard !overflowed else { return false }
        return count == product
    }

    /// `rows` and `cols` must both be positive, and `count` must equal `rows * cols`
    /// exactly -- checked without overflowing the multiplication (same reason as
    /// ``validSquare(_:count:)``).
    ///
    /// ```swift
    /// MathDimension.validRectangle(rows: 3, cols: 2, count: 6)          // true
    /// MathDimension.validRectangle(rows: .max, cols: 2, count: 1)       // false -- rejected, not trapped
    /// ```
    static func validRectangle(rows: Int, cols: Int, count: Int) -> Bool {
        guard rows > 0, cols > 0 else { return false }
        let (product, overflowed) = rows.multipliedReportingOverflow(by: cols)
        guard !overflowed else { return false }
        return count == product
    }
}
