import Foundation
import OCCTBridge
import simd

/// Logarithmic sampling utilities.
public enum LogSample {
    /// Compute logarithmically spaced parameter values between a and b.
    ///
    /// - Parameters:
    ///   - a: Lower bound.
    ///   - b: Upper bound.
    ///   - n: A *request* for exactly this many values, honoured in full or not at all:
    ///     outside `1...` ``Sampling/maximumSampleCount`` this returns empty rather than a coarser
    ///     sampling than was asked for (#622). The bridge fills the buffer exactly, so unlike a
    ///     capacity there is nothing here to truncate.
    /// - Returns: Array of logarithmically spaced values.
    public static func sample(from a: Double, to b: Double, count n: Int) -> [Double] {
        guard let n = Sampling.requested(n, atLeast: 1) else { return [] }
        var params = [Double](repeating: 0, count: n)
        OCCTLogSample(a, b, Int32(n), &params)
        return params
    }
}
