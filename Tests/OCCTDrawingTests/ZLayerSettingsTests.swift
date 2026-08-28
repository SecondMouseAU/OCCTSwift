import Foundation
import Testing
import simd

@testable import OCCTSwift

// MARK: - Z-Layer Settings Tests

@Suite("Z-Layer Settings")
struct ZLayerSettingsTests {

    @Test("Default values")
    func defaults() {
        let settings = ZLayerSettings()
        #expect(settings.depthTestEnabled == true)
        #expect(settings.depthWriteEnabled == true)
        #expect(settings.clearDepth == true)
        #expect(settings.isImmediate == false)
        #expect(settings.isRaytracable == true)
        #expect(settings.useEnvironmentTexture == true)
        #expect(settings.renderInDepthPrepass == true)
    }

    @Test("Depth test toggle")
    func depthTest() {
        let settings = ZLayerSettings()
        settings.depthTestEnabled = false
        #expect(settings.depthTestEnabled == false)
        settings.depthTestEnabled = true
        #expect(settings.depthTestEnabled == true)
    }

    @Test("Depth write toggle")
    func depthWrite() {
        let settings = ZLayerSettings()
        settings.depthWriteEnabled = false
        #expect(settings.depthWriteEnabled == false)
    }

    @Test("Clear depth toggle")
    func clearDepthToggle() {
        let settings = ZLayerSettings()
        settings.clearDepth = false
        #expect(settings.clearDepth == false)
    }

    @Test("Polygon offset roundtrip")
    func polygonOffset() {
        let settings = ZLayerSettings()
        settings.polygonOffset = ZLayerSettings.PolygonOffset(
            mode: .fill, factor: 1.5, units: 2.0
        )
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.5) < 0.001)
        #expect(abs(offset.units - 2.0) < 0.001)
    }

    @Test("Depth offset positive convenience")
    func depthOffsetPositive() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetPositive()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - 1.0) < 0.001)
    }

    @Test("Depth offset negative convenience")
    func depthOffsetNegative() {
        let settings = ZLayerSettings()
        settings.setDepthOffsetNegative()
        let offset = settings.polygonOffset
        #expect(offset.mode == .fill)
        #expect(abs(offset.factor - 1.0) < 0.001)
        #expect(abs(offset.units - (-1.0)) < 0.001)
    }

    @Test("Immediate mode toggle")
    func immediateMode() {
        let settings = ZLayerSettings()
        settings.isImmediate = true
        #expect(settings.isImmediate == true)
    }

    @Test("Raytracable toggle")
    func raytracable() {
        let settings = ZLayerSettings()
        settings.isRaytracable = false
        #expect(settings.isRaytracable == false)
    }

    @Test("Culling distance")
    func cullingDistance() {
        let settings = ZLayerSettings()
        settings.cullingDistance = 1000.0
        #expect(abs(settings.cullingDistance - 1000.0) < 0.001)
    }

    @Test("Culling size")
    func cullingSize() {
        let settings = ZLayerSettings()
        settings.cullingSize = 5.0
        #expect(abs(settings.cullingSize - 5.0) < 0.001)
    }

    @Test("Origin roundtrip")
    func origin() {
        let settings = ZLayerSettings()
        settings.origin = SIMD3(100, 200, 300)
        let o = settings.origin
        #expect(abs(o.x - 100) < 0.001)
        #expect(abs(o.y - 200) < 0.001)
        #expect(abs(o.z - 300) < 0.001)
    }

    @Test("Predefined layer IDs")
    func predefinedLayerIds() {
        #expect(ZLayerSettings.bottomOSD == -5)
        #expect(ZLayerSettings.default == 0)
        #expect(ZLayerSettings.top == -2)
        #expect(ZLayerSettings.topmost == -3)
        #expect(ZLayerSettings.topOSD == -4)
    }
}
