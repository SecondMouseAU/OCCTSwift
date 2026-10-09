import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_ClippingPlaneTool Tests")
struct XCAFDocClippingPlaneToolTests {
    @Test func addAndGet() {
        if let doc = Document.create() {
            if let clip = doc.clippingPlaneToolAdd(
                originX: 0, originY: 0, originZ: 5,
                normalX: 0, normalY: 0, normalZ: 1,
                name: "ZClip", capping: true)
            {
                #expect(doc.clippingPlaneToolIsClipPlane(clip))
                if let plane = doc.clippingPlaneToolGet(clip) {
                    #expect(abs(plane.originZ - 5.0) < 1e-6)
                    #expect(abs(plane.normalZ - 1.0) < 1e-6)
                    #expect(plane.capping)
                }
            }
        }
    }

    @Test func remove() {
        if let doc = Document.create() {
            if let clip = doc.clippingPlaneToolAdd(
                originX: 0, originY: 0, originZ: 0,
                normalX: 1, normalY: 0, normalZ: 0,
                name: "XClip", capping: false)
            {
                #expect(doc.clippingPlaneToolRemove(clip))
            }
        }
    }
}
