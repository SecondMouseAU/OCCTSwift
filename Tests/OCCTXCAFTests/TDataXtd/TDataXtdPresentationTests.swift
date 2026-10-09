import Foundation
import Testing

@testable import OCCTSwift

@Suite("TDataXtd Presentation Tests")
struct TDataXtdPresentationTests {

    @Test func setAndHas() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(
            labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.commitTransaction()
        #expect(doc.hasPresentation(labelId: node.labelId))
    }

    @Test func colorAndTransparency() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(
            labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetColor(labelId: node.labelId, colorIndex: 12)  // RED
        doc.presentationSetTransparency(labelId: node.labelId, value: 0.5)
        doc.commitTransaction()

        if let color = doc.presentationGetColor(labelId: node.labelId) {
            #expect(color == 12)
        }
        if let transparency = doc.presentationGetTransparency(labelId: node.labelId) {
            #expect(abs(transparency - 0.5) < 1e-6)
        }
    }

    @Test func widthAndMode() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(
            labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetWidth(labelId: node.labelId, width: 2.0)
        doc.presentationSetMode(labelId: node.labelId, mode: 1)
        doc.commitTransaction()

        if let width = doc.presentationGetWidth(labelId: node.labelId) {
            #expect(abs(width - 2.0) < 1e-6)
        }
        if let mode = doc.presentationGetMode(labelId: node.labelId) {
            #expect(mode == 1)
        }
    }

    @Test func displayState() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(
            labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.presentationSetDisplayed(labelId: node.labelId, displayed: true)
        doc.commitTransaction()
        #expect(doc.presentationIsDisplayed(labelId: node.labelId))
    }

    @Test func unsetPresentation() {
        guard let doc = Document.create() else { return }
        doc.openTransaction()
        guard let node = doc.createLabel() else { return }
        doc.setPresentation(
            labelId: node.labelId, driverGUID: "12345678-1234-1234-1234-123456789abc")
        doc.unsetPresentation(labelId: node.labelId)
        doc.commitTransaction()
        #expect(!doc.hasPresentation(labelId: node.labelId))
    }
}
