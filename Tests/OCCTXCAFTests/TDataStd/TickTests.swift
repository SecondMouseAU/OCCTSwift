import Foundation
import Testing

@testable import OCCTSwift

// MARK: - v0.87.0: TDataStd_Tick/Current, ShapeAnalysis_Shell/CanonicalRecognition, Geom_Transformation/OffsetCurve/RectangularTrimmedSurface

@Suite("TDataStd_Tick Tests")
struct TickTests {
    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        #expect(!doc.hasTick(tag: 500))
        #expect(doc.setTick(tag: 500))
        #expect(doc.hasTick(tag: 500))
    }

    @Test func remove() {
        guard let doc = Document.create() else { return }
        _ = doc.setTick(tag: 501)
        #expect(doc.removeTick(tag: 501))
        #expect(!doc.hasTick(tag: 501))
    }

    @Test func removeNonExistent() {
        guard let doc = Document.create() else { return }
        #expect(!doc.removeTick(tag: 502))
    }
}
