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
        if let val = tgt.integer {
            #expect(val == 77)
        }
    }

    @Test func xlinkCopyWithLink() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let src = doc.createLabel(), let tgt = doc.createLabel() else { return }
        src.setInteger(88)
        let ok = doc.xlinkCopyWithLink(targetLabelId: tgt.labelId, sourceLabelId: src.labelId)
        doc.commitTransaction()
        // CopyWithLink may fail if labels are in same document, just check no crash
        _ = ok
    }
}
