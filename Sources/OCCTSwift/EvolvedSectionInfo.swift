import Foundation
import simd
import OCCTBridge

/// Evolved section shape info
public struct EvolvedSectionInfo: Sendable {
    public let nbPoles: Int
    public let nbKnots: Int
    public let degree: Int
    public let isRational: Bool
}
