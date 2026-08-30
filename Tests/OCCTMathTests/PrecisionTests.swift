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

    // #815: `.infinite` and `.pConfusion` had no test anywhere in the tree, unlike every other
    // member of this small, otherwise fully-tested type.
    @Test func infinite() {
        // occt-refman@8.0.1, class_precision.html: "a big number that can be considered as
        // infinite"; tied here to the sibling predicate rather than a hardcoded literal, since
        // the refman documents the relationship, not a specific magnitude.
        #expect(OCCTPrecision.infinite > 1e50)
        #expect(OCCTPrecision.isInfinite(OCCTPrecision.infinite))
    }

    @Test func pConfusion() {
        // occt-refman@8.0.1, class_precision.html, Precision::PConfusion() (no-arg overload):
        // "equal to Precision::Confusion() / 100." -- an exact, documented relationship, not an
        // implementation detail.
        #expect(abs(OCCTPrecision.pConfusion - OCCTPrecision.confusion / 100.0) < 1e-15)
    }
}

