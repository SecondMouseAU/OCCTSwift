import Foundation
import OCCTBridge

/// PBR (Physically Based Rendering) material for XDE document support.
///
/// This struct represents material properties compatible with glTF and modern rendering pipelines.
public struct Material: Sendable, Equatable {
    /// Base color (albedo) of the material.
    public var baseColor: Color

    /// Metallic factor (0.0 = dielectric, 1.0 = metal).
    public var metallic: Double

    /// Roughness factor (0.0 = smooth/glossy, 1.0 = rough/matte).
    public var roughness: Double

    /// Emissive color (light emitted by the material).
    public var emissive: Color?

    /// Transparency (0.0 = opaque, 1.0 = fully transparent).
    public var transparency: Double

    /// Create a PBR material.
    ///
    /// - Parameters:
    ///   - baseColor: The base color (albedo) of the material
    ///   - metallic: Metallic factor, 0.0-1.0 (default 0.0 for non-metals)
    ///   - roughness: Roughness factor, 0.0-1.0 (default 0.5)
    ///   - emissive: Optional emissive color for glowing materials
    ///   - transparency: Transparency factor, 0.0-1.0 (default 0.0 for opaque)
    public init(
        baseColor: Color,
        metallic: Double = 0.0,
        roughness: Double = 0.5,
        emissive: Color? = nil,
        transparency: Double = 0.0
    ) {
        self.baseColor = baseColor
        self.metallic = max(0, min(1, metallic))
        self.roughness = max(0, min(1, roughness))
        self.emissive = emissive
        self.transparency = max(0, min(1, transparency))
    }

    // MARK: - Common Materials

    /// Default material (white, non-metallic, medium roughness).
    public static let `default` = Material(baseColor: .white)

    /// Polished metal (highly metallic, low roughness).
    public static let polishedMetal = Material(
        baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
        metallic: 1.0,
        roughness: 0.1
    )

    /// Brushed metal (metallic with medium roughness).
    public static let brushedMetal = Material(
        baseColor: Color(red: 0.7, green: 0.7, blue: 0.7),
        metallic: 1.0,
        roughness: 0.4
    )

    /// Plastic (non-metallic, medium roughness).
    public static let plastic = Material(
        baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
        metallic: 0.0,
        roughness: 0.4
    )

    /// Rubber (non-metallic, high roughness).
    public static let rubber = Material(
        baseColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        metallic: 0.0,
        roughness: 0.9
    )

    /// Glass (transparent, smooth).
    public static let glass = Material(
        baseColor: Color(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1),
        metallic: 0.0,
        roughness: 0.0,
        transparency: 0.9
    )

    // MARK: - OCCT Material Operations (Graphic3d_MaterialAspect / Graphic3d_PBRMaterial)

    /// Full material properties from OCCT predefined material.
    public struct PredefinedMaterial: Sendable, Equatable {
        public var ambientColor: Color
        public var diffuseColor: Color
        public var specularColor: Color
        public var emissiveColor: Color
        public var transparency: Float
        public var shininess: Float
        public var refractionIndex: Float
        public var isPhysic: Bool
        public var pbrMetallic: Float
        public var pbrRoughness: Float
        public var pbrIOR: Float
        public var pbrAlpha: Float
        public var pbrEmission: (r: Float, g: Float, b: Float)

        // Equatable conformance for tuple field
        public static func == (lhs: PredefinedMaterial, rhs: PredefinedMaterial) -> Bool {
            lhs.ambientColor == rhs.ambientColor && lhs.diffuseColor == rhs.diffuseColor
                && lhs.specularColor == rhs.specularColor && lhs.emissiveColor == rhs.emissiveColor
                && lhs.transparency == rhs.transparency && lhs.shininess == rhs.shininess
                && lhs.refractionIndex == rhs.refractionIndex && lhs.isPhysic == rhs.isPhysic
                && lhs.pbrMetallic == rhs.pbrMetallic && lhs.pbrRoughness == rhs.pbrRoughness
                && lhs.pbrIOR == rhs.pbrIOR && lhs.pbrAlpha == rhs.pbrAlpha
                && lhs.pbrEmission.r == rhs.pbrEmission.r && lhs.pbrEmission.g == rhs.pbrEmission.g
                && lhs.pbrEmission.b == rhs.pbrEmission.b
        }
    }

    /// Number of predefined OCCT materials.
    public static var predefinedMaterialCount: Int {
        Int(OCCTMaterialNumberOfMaterials())
    }

    /// Get name of predefined material by 1-based index.
    public static func predefinedMaterialName(at index: Int) -> String? {
        guard let cStr = OCCTMaterialName(Int32(index)) else { return nil }
        let result = String(cString: cStr)
        OCCTGeomToolsFreeString(UnsafeMutablePointer(mutating: cStr))
        return result
    }

    /// Get full properties of a predefined OCCT material by name (e.g., "Brass", "Gold", "Copper").
    public static func predefinedMaterial(named name: String) -> PredefinedMaterial? {
        var props = OCCTMaterialProperties()
        guard OCCTMaterialFromName(name, &props) else { return nil }
        return convertProps(props)
    }

    /// Get full properties of a predefined OCCT material by 1-based index.
    public static func predefinedMaterial(at index: Int) -> PredefinedMaterial? {
        var props = OCCTMaterialProperties()
        guard OCCTMaterialFromIndex(Int32(index), &props) else { return nil }
        return convertProps(props)
    }

    /// Minimum PBR roughness value.
    public static var minRoughness: Float {
        OCCTMaterialMinRoughness()
    }

    /// Compute PBR roughness from specular color and shininess.
    public static func roughnessFromSpecular(color: Color, shininess: Double) -> Float {
        OCCTMaterialRoughnessFromSpecular(color.red, color.green, color.blue, shininess)
    }

    /// Compute PBR metallic factor from specular color.
    public static func metallicFromSpecular(color: Color) -> Float {
        OCCTMaterialMetallicFromSpecular(color.red, color.green, color.blue)
    }

    private static func convertProps(_ props: OCCTMaterialProperties) -> PredefinedMaterial {
        PredefinedMaterial(
            ambientColor: Color(red: props.ambientR, green: props.ambientG, blue: props.ambientB),
            diffuseColor: Color(red: props.diffuseR, green: props.diffuseG, blue: props.diffuseB),
            specularColor: Color(
                red: props.specularR, green: props.specularG, blue: props.specularB),
            emissiveColor: Color(
                red: props.emissiveR, green: props.emissiveG, blue: props.emissiveB),
            transparency: props.transparency,
            shininess: props.shininess,
            refractionIndex: props.refractionIndex,
            isPhysic: props.isPhysic,
            pbrMetallic: props.pbrMetallic,
            pbrRoughness: props.pbrRoughness,
            pbrIOR: props.pbrIOR,
            pbrAlpha: props.pbrAlpha,
            pbrEmission: (props.pbrEmissionR, props.pbrEmissionG, props.pbrEmissionB)
        )
    }
}
