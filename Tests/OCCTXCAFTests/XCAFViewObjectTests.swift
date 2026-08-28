import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFView_Object Tests")
struct XCAFViewObjectTests {
    @Test func create() {
        let view = ViewObject()
        #expect(view != nil)
    }

    @Test func projectionType() {
        if let view = ViewObject() {
            view.setType(.central)
            #expect(view.type == .central)
            view.setType(.parallel)
            #expect(view.type == .parallel)
        }
    }

    @Test func viewDirection() {
        if let view = ViewObject() {
            view.setViewDirection(x: 1, y: 0, z: 0)
            let dir = view.viewDirection
            #expect(abs(dir.x - 1.0) < 1e-6)
        }
    }

    @Test func upDirection() {
        if let view = ViewObject() {
            view.setUpDirection(x: 0, y: 0, z: 1)
            let up = view.upDirection
            #expect(abs(up.z - 1.0) < 1e-6)
        }
    }

    @Test func windowSize() {
        if let view = ViewObject() {
            view.setWindowHorizontalSize(800)
            view.setWindowVerticalSize(600)
            #expect(abs(view.windowHorizontalSize - 800) < 1e-6)
            #expect(abs(view.windowVerticalSize - 600) < 1e-6)
        }
    }

    @Test func clippingPlanes() {
        if let view = ViewObject() {
            view.setFrontPlaneDistance(1.0)
            view.setBackPlaneDistance(1000.0)
            #expect(view.hasFrontPlaneClipping)
            #expect(view.hasBackPlaneClipping)
            #expect(abs(view.frontPlaneDistance - 1.0) < 1e-6)
            #expect(abs(view.backPlaneDistance - 1000.0) < 1e-6)
            view.unsetFrontPlaneClipping()
            #expect(!view.hasFrontPlaneClipping)
        }
    }

    @Test func name() {
        if let view = ViewObject() {
            view.setName("TopView")
            #expect(view.name == "TopView")
        }
    }
}
