import Foundation
import simd
import OCCTBridge

/// Filling pole grid result from GeomFill_Coons/Curved
public struct FillingPoleGrid: Sendable {
    public let poles: [SIMD3<Double>]
    public let nbU: Int
    public let nbV: Int
}
