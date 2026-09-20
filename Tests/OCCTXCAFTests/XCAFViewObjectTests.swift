import Foundation
import OCCTBridge
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
            view.setType(.noCamera)
            #expect(view.type == .noCamera)
        }
    }

    /// #1574: `ViewObject.ProjectionType` used to be `central=0, parallel=1`, which does not match
    /// the real `XCAFView_ProjectionType` (`NoCamera=0, Parallel=1, Central=2`). The bridge does a
    /// bare `(XCAFView_ProjectionType)type` cast with no translation, so a raw value written by
    /// another OCCT tool (or read back from one) has to decode against the *real* enum, not
    /// Swift's own (previously wrong but internally self-consistent) mapping. `projectionType()`
    /// above round-trips only through `ViewObject`'s own `setType`/`type`, so it can't catch a
    /// raw-value mismatch: both sides used the same wrong table. This test drives the raw C
    /// bridge functions directly with the three real `XCAFView_ProjectionType` values (straight
    /// from the pinned `XCAFView_ProjectionType.hxx`) and decodes them with the public
    /// `ProjectionType(rawValue:)` initializer, exactly as `ViewObject.type` does internally.
    @Test("all three real XCAFView_ProjectionType raw values decode correctly, including NoCamera")
    func realOCCTProjectionTypeValuesDecodeCorrectly() {
        guard let ref = OCCTViewObjectCreate() else {
            Issue.record("failed to create OCCTViewObjectRef")
            return
        }
        defer { OCCTViewObjectRelease(ref) }

        // XCAFView_ProjectionType_NoCamera = 0, _Parallel = 1, _Central = 2.
        let cases: [(raw: Int32, expected: ViewObject.ProjectionType)] = [
            (0, .noCamera),
            (1, .parallel),
            (2, .central),
        ]

        for (raw, expected) in cases {
            OCCTViewObjectSetType(ref, raw)
            let readBack = OCCTViewObjectGetType(ref)
            #expect(readBack == raw, "bridge round-trip changed the raw XCAFView_ProjectionType value")
            let decoded = ViewObject.ProjectionType(rawValue: readBack)
            #expect(decoded == expected)
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
