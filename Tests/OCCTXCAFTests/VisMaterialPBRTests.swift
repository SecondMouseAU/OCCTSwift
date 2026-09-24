import Foundation
import Testing

@testable import OCCTSwift

@Suite("XCAFDoc_VisMaterialPBR Tests")
struct VisMaterialPBRTests {
    @Test func defaultValues() {
        let pbr = VisMaterialPBR()
        #expect(pbr.isDefined)
        #expect(abs(pbr.metallic - 1.0) < 1e-6)
        #expect(abs(pbr.roughness - 1.0) < 1e-6)
        #expect(abs(pbr.refractionIndex - 1.5) < 1e-6)
    }

    @Test func setProperties() {
        var pbr = VisMaterialPBR()
        pbr.metallic = 0.0
        pbr.roughness = 0.5
        pbr.baseColor = (0.8, 0.2, 0.1)
        #expect(abs(pbr.metallic) < 1e-6)
        #expect(abs(pbr.roughness - 0.5) < 1e-6)
        // Reading stored properties back could not fail (#766); a different roughness has to
        // reach the kernel material and make it compare unequal.
        var other = pbr
        other.roughness = 0.6
        #expect(!pbr.isEqual(to: other))
    }

    @Test func equality() {
        var p1 = VisMaterialPBR()
        p1.metallic = 0.0
        p1.roughness = 0.5
        p1.baseColor = (0.8, 0.2, 0.1)
        var p2 = VisMaterialPBR()
        p2.metallic = 0.0
        p2.roughness = 0.5
        p2.baseColor = (0.8, 0.2, 0.1)
        #expect(p1.isEqual(to: p2))
    }
}
