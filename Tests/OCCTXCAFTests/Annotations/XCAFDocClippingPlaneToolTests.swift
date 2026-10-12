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

    @Test func remove() throws {
        let doc = try #require(Document.create())
        let clip = try #require(
            doc.clippingPlaneToolAdd(
                originX: 0, originY: 0, originZ: 0,
                normalX: 1, normalY: 0, normalZ: 0,
                name: "XClip", capping: false))
        // Before: a clipping plane that reads back what was added.
        #expect(doc.clippingPlaneToolIsClipPlane(clip))
        let plane = try #require(doc.clippingPlaneToolGet(clip))
        #expect(plane.normalX == 1)
        #expect(!plane.capping)

        #expect(doc.clippingPlaneToolRemove(clip))

        // After: it is no longer a clipping plane and reads back as nothing, and a second removal
        // has nothing left to remove.
        #expect(!doc.clippingPlaneToolIsClipPlane(clip))
        #expect(doc.clippingPlaneToolGet(clip) == nil)
        #expect(!doc.clippingPlaneToolRemove(clip))
    }
}
