import Foundation
import Testing
import simd

@testable import OCCTSwift

@Suite("Precision Tests")
struct PrecisionTests {

    @Test func confusion() {
        #expect(abs(OCCTPrecision.confusion - 1e-7) < 1e-15)
    }

    @Test func angular() {
        #expect(abs(OCCTPrecision.angular - 1e-12) < 1e-20)
    }

    @Test func isInfinite() {
        #expect(OCCTPrecision.isInfinite(3e100))
        #expect(!OCCTPrecision.isInfinite(1.0))
    }

    @Test func ordering() {
        #expect(OCCTPrecision.intersection < OCCTPrecision.confusion)
        #expect(OCCTPrecision.approximation > OCCTPrecision.confusion)
    }
}

