import Foundation
import simd
import OCCTBridge

/// Phong material properties (diffuse, ambient, specular, emissive, shininess, transparency).
public struct VisMaterialCommon: Sendable {
    public var diffuseColor: (red: Double, green: Double, blue: Double)
    public var ambientColor: (red: Double, green: Double, blue: Double)
    public var specularColor: (red: Double, green: Double, blue: Double)
    public var emissiveColor: (red: Double, green: Double, blue: Double)
    public var shininess: Float
    public var transparency: Float
    public var isDefined: Bool

    /// Create with default values (from OCCT defaults).
    public init() {
        let d = OCCTVisMaterialCommonDefault()
        self.diffuseColor = (d.diffuseR, d.diffuseG, d.diffuseB)
        self.ambientColor = (d.ambientR, d.ambientG, d.ambientB)
        self.specularColor = (d.specularR, d.specularG, d.specularB)
        self.emissiveColor = (d.emissiveR, d.emissiveG, d.emissiveB)
        self.shininess = d.shininess
        self.transparency = d.transparency
        self.isDefined = d.isDefined
    }

    /// Check equality with another VisMaterialCommon.
    public func isEqual(to other: VisMaterialCommon) -> Bool {
        var a = toOCCT()
        var b = other.toOCCT()
        return OCCTVisMaterialCommonIsEqual(&a, &b)
    }

    private func toOCCT() -> OCCTVisMaterialCommon {
        var m = OCCTVisMaterialCommon()
        m.diffuseR = diffuseColor.red; m.diffuseG = diffuseColor.green; m.diffuseB = diffuseColor.blue
        m.ambientR = ambientColor.red; m.ambientG = ambientColor.green; m.ambientB = ambientColor.blue
        m.specularR = specularColor.red; m.specularG = specularColor.green; m.specularB = specularColor.blue
        m.emissiveR = emissiveColor.red; m.emissiveG = emissiveColor.green; m.emissiveB = emissiveColor.blue
        m.shininess = shininess
        m.transparency = transparency
        m.isDefined = isDefined
        return m
    }
}

/// PBR material properties (base color, metallic, roughness, IOR, emission).
public struct VisMaterialPBR: Sendable {
    public var baseColor: (red: Double, green: Double, blue: Double)
    public var baseColorAlpha: Float
    public var metallic: Float
    public var roughness: Float
    public var refractionIndex: Float
    public var emissionColor: (red: Double, green: Double, blue: Double)
    public var isDefined: Bool

    /// Create with default values (from OCCT defaults).
    public init() {
        let d = OCCTVisMaterialPBRDefault()
        self.baseColor = (d.baseColorR, d.baseColorG, d.baseColorB)
        self.baseColorAlpha = d.baseColorAlpha
        self.metallic = d.metallic
        self.roughness = d.roughness
        self.refractionIndex = d.refractionIndex
        self.emissionColor = (d.emissionR, d.emissionG, d.emissionB)
        self.isDefined = d.isDefined
    }

    /// Check equality with another VisMaterialPBR.
    public func isEqual(to other: VisMaterialPBR) -> Bool {
        var a = toOCCT()
        var b = other.toOCCT()
        return OCCTVisMaterialPBRIsEqual(&a, &b)
    }

    private func toOCCT() -> OCCTVisMaterialPBR {
        var m = OCCTVisMaterialPBR()
        m.baseColorR = baseColor.red; m.baseColorG = baseColor.green; m.baseColorB = baseColor.blue
        m.baseColorAlpha = baseColorAlpha
        m.metallic = metallic
        m.roughness = roughness
        m.refractionIndex = refractionIndex
        m.emissionR = emissionColor.red; m.emissionG = emissionColor.green; m.emissionB = emissionColor.blue
        m.isDefined = isDefined
        return m
    }
}
