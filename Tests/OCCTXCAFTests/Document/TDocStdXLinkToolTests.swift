import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDocStd XLinkTool Tests")
struct TDocStdXLinkToolTests {

    @Test func xlinkCopy() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let src = doc.createLabel(), let tgt = doc.createLabel() else { return }
        src.setInteger(77)
        src.setName("XLinkSource")
        let ok = doc.xlinkCopy(targetLabelId: tgt.labelId, sourceLabelId: src.labelId)
        doc.commitTransaction()
        #expect(ok)
        // Unconditional: inside `if let`, a copy that carried nothing across passed (#766).
        #expect(tgt.integer == 77)
    }

    @Test func xlinkCopyWithLink() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let src = doc.createLabel(), let tgt = doc.createLabel() else { return }
        src.setInteger(88)
        let ok = doc.xlinkCopyWithLink(targetLabelId: tgt.labelId, sourceLabelId: src.labelId)
        doc.commitTransaction()
        // XLinkTool::CopyWithLink copies the source's attributes onto the target. The answer and the
        // effect are both asserted here; the version on v5 discarded both (#766).
        #expect(ok)
        #expect(tgt.integer == 88)
    }
}
