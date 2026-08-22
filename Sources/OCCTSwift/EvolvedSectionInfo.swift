import Foundation
import OCCTBridge
import simd

/// Evolved section shape info
public struct EvolvedSectionInfo: Sendable {
    public let nbPoles: Int
    public let nbKnots: Int
    public let degree: Int
    public let isRational: Bool
}
