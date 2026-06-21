---
title: Color & Material
parent: API Reference
---

# Color & Material

`Color` is an RGBA value type used to set or query colors on XDE document labels and shapes. `Material` is a PBR (Physically Based Rendering) value type compatible with glTF export, carrying base color, metallic, roughness, emissive, and transparency. Both types expose the full `Quantity_Color` / `Quantity_ColorRGBA` / `Graphic3d_MaterialAspect` / `Graphic3d_PBRMaterial` OCCT surface through a clean Swift API.

## Topics

- [Color — Initializers](#color--initializers) · [Color — Predefined Colors](#color--predefined-colors) · [Color — OCCT Color Operations](#color--occt-color-operations) · [Material — Initializer & Properties](#material--initializer--properties) · [Material — Common Materials](#material--common-materials) · [Material — OCCT Material Operations](#material--occt-material-operations)

---

## Color — Initializers

### `Color.init(red:green:blue:alpha:)`

Creates a `Color` from floating-point RGBA components.

```swift
public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0)
```

Components are stored as-is (linear RGB, 0.0–1.0). No clamping is performed in this initializer.

- **Parameters:** `red`, `green`, `blue` — linear RGB channels in \[0, 1\]; `alpha` — opacity in \[0, 1\] (default `1.0` = fully opaque).
- **Example:**
  ```swift
  let coral = Color(red: 1.0, green: 0.4, blue: 0.3)
  let semiTransparent = Color(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.5)
  ```

---

### `Color.init(red255:green255:blue255:alpha255:)`

Creates a `Color` from 8-bit integer RGBA components (0–255 range).

```swift
public init(red255: Int, green255: Int, blue255: Int, alpha255: Int = 255)
```

Each channel is divided by 255.0 to produce the internal `Double` representation.

- **Parameters:** `red255`, `green255`, `blue255` — integer channel values 0–255; `alpha255` — integer alpha 0–255 (default `255`).
- **Example:**
  ```swift
  let steelBlue = Color(red255: 70, green255: 130, blue255: 180)
  ```

---

### `Color.init?(_ cgColor:)` *(macOS/iOS only)*

Creates a `Color` from a `CGColor`.

```swift
public init?(_ cgColor: CGColor)
```

Available only when `CoreGraphics` is importable. Reads the first three components as R, G, B and the fourth (if present) as alpha.

- **Parameters:** `cgColor` — a `CGColor` with at least three components.
- **Returns:** `nil` if `cgColor.components` is nil or has fewer than three elements.
- **Example:**
  ```swift
  import CoreGraphics
  let cg = CGColor(red: 1, green: 0.5, blue: 0, alpha: 1)
  if let c = Color(cg) {
      print(c.red, c.green, c.blue)
  }
  ```

---

## Color — Properties

### `red`

Red component in linear RGB (0.0–1.0).

```swift
public var red: Double
```

---

### `green`

Green component in linear RGB (0.0–1.0).

```swift
public var green: Double
```

---

### `blue`

Blue component in linear RGB (0.0–1.0).

```swift
public var blue: Double
```

---

### `alpha`

Alpha (opacity) component (0.0 = fully transparent, 1.0 = fully opaque).

```swift
public var alpha: Double
```

---

### `cgColor` *(macOS/iOS only)*

Converts this `Color` to a `CGColor`.

```swift
public var cgColor: CGColor { get }
```

Available only when `CoreGraphics` is importable. Pure-Swift; no bridge call.

- **Returns:** A `CGColor` with the same RGBA components.
- **Example:**
  ```swift
  let layer = CALayer()
  layer.backgroundColor = Color.red.cgColor
  ```

---

## Color — Predefined Colors

Static constants covering the most common colors. All use `alpha = 1.0` except `clear`.

### `Color.black`

```swift
public static let black = Color(red: 0, green: 0, blue: 0)
```

---

### `Color.white`

```swift
public static let white = Color(red: 1, green: 1, blue: 1)
```

---

### `Color.red`

```swift
public static let red = Color(red: 1, green: 0, blue: 0)
```

---

### `Color.green`

```swift
public static let green = Color(red: 0, green: 1, blue: 0)
```

---

### `Color.blue`

```swift
public static let blue = Color(red: 0, green: 0, blue: 1)
```

---

### `Color.gray`

50% gray.

```swift
public static let gray = Color(red: 0.5, green: 0.5, blue: 0.5)
```

---

### `Color.clear`

Fully transparent black.

```swift
public static let clear = Color(red: 0, green: 0, blue: 0, alpha: 0)
```

---

## Color — OCCT Color Operations

### `HLS`

HLS (Hue-Lightness-Saturation) color components.

```swift
public struct HLS: Sendable, Equatable {
    public var hue: Double
    public var lightness: Double
    public var saturation: Double
}
```

Returned by `Color.hls`. Corresponds to `Quantity_Color` component values when queried in `Quantity_TOC_HLS` mode.

---

### `Lab`

CIE Lab color components.

```swift
public struct Lab: Sendable, Equatable {
    public var l: Double
    public var a: Double
    public var b: Double
}
```

Returned by `Color.lab`. Represents perceptually uniform Lab coordinates where `l` = lightness, `a` = green–red axis, `b` = blue–yellow axis.

---

### `Color.fromName(_:)`

Creates a `Color` from an OCCT named color string (e.g. `"RED"`, `"GOLD"`, `"BLUE"`).

```swift
public static func fromName(_ name: String) -> Color?
```

- **Parameters:** `name` — uppercase OCCT color name as recognized by `Quantity_Color::ColorFromName`.
- **Returns:** `Color` with `alpha = 1.0`, or `nil` if the name is not recognized.
- **OCCT:** `Quantity_Color::ColorFromName`.
- **Example:**
  ```swift
  if let gold = Color.fromName("GOLD") {
      print(gold.red, gold.green, gold.blue)
  }
  ```

---

### `Color.fromHex(_:)`

Creates a `Color` from a 6-digit hex string (e.g. `"#FF0000"`).

```swift
public static func fromHex(_ hex: String) -> Color?
```

- **Parameters:** `hex` — hex color string with optional `#` prefix; parses RGB only (alpha defaults to `1.0`).
- **Returns:** `Color` with `alpha = 1.0`, or `nil` if parsing fails.
- **OCCT:** `Quantity_Color::ColorFromHex`.
- **Example:**
  ```swift
  if let c = Color.fromHex("#4A90E2") {
      print(c.red)  // ≈ 0.29
  }
  ```

---

### `Color.fromHexRGBA(_:)`

Creates a `Color` from an 8-digit hex string that includes alpha (e.g. `"#FF000080"`).

```swift
public static func fromHexRGBA(_ hex: String) -> Color?
```

- **Parameters:** `hex` — 8-digit RGBA hex string with optional `#` prefix.
- **Returns:** `Color` with all four components, or `nil` if parsing fails.
- **OCCT:** `Quantity_ColorRGBA::ColorFromHex`.
- **Example:**
  ```swift
  if let semi = Color.fromHexRGBA("#FF000080") {
      print(semi.alpha)  // ≈ 0.502
  }
  ```

---

### `toHex(sRGB:)`

Converts this color to a 6-digit hex string.

```swift
public func toHex(sRGB: Bool = false) -> String?
```

- **Parameters:** `sRGB` — when `true`, converts to sRGB before formatting; when `false` (default), formats linear RGB directly.
- **Returns:** Hex string (e.g. `"FF0000"`), or `nil` on error.
- **OCCT:** `Quantity_Color::ColorToHex`.
- **Example:**
  ```swift
  let hex = Color.red.toHex()      // "FF0000"
  let hexS = Color.red.toHex(sRGB: true)
  ```

---

### `toHexRGBA(sRGB:)`

Converts this color to an 8-digit RGBA hex string.

```swift
public func toHexRGBA(sRGB: Bool = false) -> String?
```

- **Parameters:** `sRGB` — when `true`, converts to sRGB before formatting.
- **Returns:** 8-digit hex string (RRGGBBAA), or `nil` on error.
- **OCCT:** `Quantity_ColorRGBA::ColorToHex`.
- **Example:**
  ```swift
  let semi = Color(red: 1, green: 0, blue: 0, alpha: 0.5)
  let hex = semi.toHexRGBA()  // "FF00007F" or similar
  ```

---

### `distance(to:)`

Euclidean distance to another color in linear RGB space.

```swift
public func distance(to other: Color) -> Double
```

Computes `sqrt((r1-r2)² + (g1-g2)² + (b1-b2)²)`.

- **Parameters:** `other` — the color to measure against.
- **Returns:** Euclidean distance in linear RGB (range 0–√3 ≈ 1.732).
- **OCCT:** `Quantity_Color::Distance`.
- **Example:**
  ```swift
  let d = Color.red.distance(to: Color.blue)  // ≈ 1.414
  ```

---

### `squareDistance(to:)`

Square of the Euclidean distance to another color in linear RGB space.

```swift
public func squareDistance(to other: Color) -> Double
```

Cheaper than `distance(to:)` when you only need to compare distances.

- **Parameters:** `other` — the color to compare against.
- **Returns:** Squared Euclidean distance (range 0–3.0).
- **OCCT:** `Quantity_Color::SquareDistance`.
- **Example:**
  ```swift
  let sq = Color.white.squareDistance(to: Color.black)  // 3.0
  ```

---

### `deltaE2000(to:)`

CIE DeltaE 2000 perceptual color difference.

```swift
public func deltaE2000(to other: Color) -> Double
```

DeltaE 2000 is a perceptually uniform metric: values below ~1.0 are imperceptible to most observers, values above ~3.0 are clearly distinct.

- **Parameters:** `other` — the color to compare against.
- **Returns:** DeltaE 2000 value (non-negative).
- **OCCT:** `Quantity_Color::DeltaE2000`.
- **Example:**
  ```swift
  let diff = Color.fromName("RED")!.deltaE2000(to: Color.fromName("ORANGE")!)
  ```

---

### `hls`

HLS (Hue-Lightness-Saturation) representation of this color.

```swift
public var hls: HLS { get }
```

- **Returns:** `HLS` struct with `hue` (0–360 °), `lightness` (0–1), `saturation` (0–1) as returned by OCCT.
- **OCCT:** `Quantity_Color::Hue`, `Light`, `Saturation` (queried in `Quantity_TOC_HLS`).
- **Example:**
  ```swift
  let h = Color.red.hls
  print(h.hue, h.lightness, h.saturation)  // 0.0, 0.5, 1.0
  ```

---

### `Color.fromHLS(hue:lightness:saturation:)`

Creates a `Color` from HLS values.

```swift
public static func fromHLS(hue: Double, lightness: Double, saturation: Double) -> Color
```

- **Parameters:** `hue` — hue in degrees (0–360); `lightness` — 0.0–1.0; `saturation` — 0.0–1.0.
- **Returns:** `Color` with `alpha = 1.0`.
- **OCCT:** `Quantity_Color` constructor with `Quantity_TOC_HLS`.
- **Example:**
  ```swift
  let teal = Color.fromHLS(hue: 180, lightness: 0.5, saturation: 0.8)
  ```

---

### `withIntensityChanged(by:)`

Returns a new color with modified lightness.

```swift
public func withIntensityChanged(by delta: Double) -> Color
```

Adds `delta` to the HLS lightness, then converts back to RGB. The alpha is preserved.

- **Parameters:** `delta` — lightness delta (positive = brighter, negative = darker).
- **Returns:** A new `Color` with adjusted intensity and the same `alpha`.
- **OCCT:** `Quantity_Color::ChangeIntensity`.
- **Example:**
  ```swift
  let lighter = Color.blue.withIntensityChanged(by: 0.2)
  ```

---

### `withContrastChanged(by:)`

Returns a new color with modified saturation.

```swift
public func withContrastChanged(by delta: Double) -> Color
```

Adds `delta` to the HLS saturation percentage, then converts back to RGB. The alpha is preserved.

- **Parameters:** `delta` — saturation percentage delta.
- **Returns:** A new `Color` with adjusted contrast and the same `alpha`.
- **OCCT:** `Quantity_Color::ChangeContrast`.
- **Example:**
  ```swift
  let desaturated = Color.green.withContrastChanged(by: -0.5)
  ```

---

### `sRGB`

Converts this color from linear RGB to sRGB.

```swift
public var sRGB: Color { get }
```

sRGB gamma-encodes the RGB channels. The alpha is preserved.

- **Returns:** A new `Color` with sRGB-encoded channels.
- **OCCT:** `Quantity_Color::Convert_LinearRGB_To_sRGB`.
- **Example:**
  ```swift
  let linearRed = Color.red
  let sRGBRed = linearRed.sRGB
  ```

---

### `linearRGB`

Converts this color from sRGB to linear RGB.

```swift
public var linearRGB: Color { get }
```

Inverse of `sRGB`. Gamma-decodes the channels. The alpha is preserved.

- **Returns:** A new `Color` with linearized channels.
- **OCCT:** `Quantity_Color::Convert_sRGB_To_LinearRGB`.
- **Example:**
  ```swift
  let fromPhotoshop = Color(red255: 128, green255: 0, blue255: 0)
  let linear = fromPhotoshop.linearRGB
  ```

---

### `lab`

Converts this color to CIE Lab color space.

```swift
public var lab: Lab { get }
```

- **Returns:** `Lab` struct with `l` (lightness 0–100), `a` (green–red), `b` (blue–yellow).
- **OCCT:** `Quantity_Color::Convert_LinearRGB_To_Lab`.
- **Example:**
  ```swift
  let labWhite = Color.white.lab
  print(labWhite.l)  // ≈ 100.0
  ```

---

### `Color.namedColorName(at:)`

Gets the string name of a predefined OCCT color by 0-based index.

```swift
public static func namedColorName(at index: Int) -> String? 
```

Iterating from `0` upward (returning `nil` once out of range) enumerates all `Quantity_NameOfColor` entries.

- **Parameters:** `index` — 0-based index into `Quantity_NameOfColor`.
- **Returns:** String name (e.g. `"RED"`, `"GOLD"`), or `nil` if index is out of range.
- **OCCT:** `Quantity_Color::StringName`.
- **Example:**
  ```swift
  var i = 0
  while let name = Color.namedColorName(at: i) {
      print(i, name)
      i += 1
  }
  ```

---

### `Color.epsilon`

Color comparison epsilon used by OCCT for `Quantity_Color` equality.

```swift
public static var epsilon: Double { get }
```

- **Returns:** The threshold below which two color distances are considered equal in OCCT's internal comparisons.
- **OCCT:** `Quantity_Color::Epsilon`.
- **Example:**
  ```swift
  print(Color.epsilon)  // typically a small value like 0.0001
  ```

---

## Material — Initializer & Properties

### `Material.init(baseColor:metallic:roughness:emissive:transparency:)`

Creates a PBR material.

```swift
public init(
    baseColor: Color,
    metallic: Double = 0.0,
    roughness: Double = 0.5,
    emissive: Color? = nil,
    transparency: Double = 0.0
)
```

`metallic`, `roughness`, and `transparency` are clamped to \[0, 1\] by the initializer.

- **Parameters:**
  - `baseColor` — albedo color (the primary reflective color).
  - `metallic` — 0.0 = dielectric (plastic/paint), 1.0 = metal (default `0.0`).
  - `roughness` — 0.0 = mirror-smooth, 1.0 = fully matte (default `0.5`).
  - `emissive` — optional self-emission color for glowing materials.
  - `transparency` — 0.0 = opaque, 1.0 = fully transparent (default `0.0`).
- **Example:**
  ```swift
  let mat = Material(
      baseColor: Color(red: 0.9, green: 0.7, blue: 0.1),
      metallic: 1.0,
      roughness: 0.2
  )
  ```

---

### `baseColor`

The base color (albedo) of the material.

```swift
public var baseColor: Color
```

---

### `metallic`

Metallic factor (0.0 = dielectric, 1.0 = metal).

```swift
public var metallic: Double
```

---

### `roughness`

Roughness factor (0.0 = smooth/glossy, 1.0 = rough/matte).

```swift
public var roughness: Double
```

---

### `emissive`

Emissive color for light emitted by the material.

```swift
public var emissive: Color?
```

`nil` means no emission. Set to a non-nil `Color` for glowing effects.

---

### `transparency`

Transparency factor (0.0 = opaque, 1.0 = fully transparent).

```swift
public var transparency: Double
```

---

## Material — Common Materials

Predefined static constants for common real-world materials.

### `Material.default`

White, non-metallic, medium roughness (metallic `0.0`, roughness `0.5`).

```swift
public static let `default` = Material(baseColor: .white)
```

---

### `Material.polishedMetal`

Highly metallic, low roughness (metallic `1.0`, roughness `0.1`).

```swift
public static let polishedMetal = Material(
    baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
    metallic: 1.0,
    roughness: 0.1
)
```

---

### `Material.brushedMetal`

Metallic with medium roughness (metallic `1.0`, roughness `0.4`).

```swift
public static let brushedMetal = Material(
    baseColor: Color(red: 0.7, green: 0.7, blue: 0.7),
    metallic: 1.0,
    roughness: 0.4
)
```

---

### `Material.plastic`

Non-metallic, medium roughness (metallic `0.0`, roughness `0.4`).

```swift
public static let plastic = Material(
    baseColor: Color(red: 0.8, green: 0.8, blue: 0.8),
    metallic: 0.0,
    roughness: 0.4
)
```

---

### `Material.rubber`

Dark, non-metallic, high roughness (metallic `0.0`, roughness `0.9`).

```swift
public static let rubber = Material(
    baseColor: Color(red: 0.1, green: 0.1, blue: 0.1),
    metallic: 0.0,
    roughness: 0.9
)
```

---

### `Material.glass`

Nearly transparent, smooth surface (metallic `0.0`, roughness `0.0`, transparency `0.9`).

```swift
public static let glass = Material(
    baseColor: Color(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.1),
    metallic: 0.0,
    roughness: 0.0,
    transparency: 0.9
)
```

---

## Material — OCCT Material Operations

### `PredefinedMaterial`

Full Phong + PBR properties of an OCCT predefined material.

```swift
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
}
```

Wraps `Graphic3d_MaterialAspect` Phong properties (ambient, diffuse, specular, emissive, shininess, refraction, transparency, material type) and the embedded `Graphic3d_PBRMaterial` fields (metallic, roughness, IOR, alpha, emission). `isPhysic` is `true` when the material type is `Graphic3d_MATERIAL_PHYSIC`.

---

### `Material.predefinedMaterialCount`

The number of predefined OCCT materials.

```swift
public static var predefinedMaterialCount: Int { get }
```

- **Returns:** Total count of entries in `Graphic3d_NameOfMaterial`.
- **OCCT:** `Graphic3d_MaterialAspect::NumberOfMaterials`.
- **Example:**
  ```swift
  print(Material.predefinedMaterialCount)  // e.g. 20
  ```

---

### `Material.predefinedMaterialName(at:)`

Gets the name of a predefined OCCT material by 1-based index.

```swift
public static func predefinedMaterialName(at index: Int) -> String?
```

- **Parameters:** `index` — 1-based index (1 … `predefinedMaterialCount`).
- **Returns:** Material name string (e.g. `"Brass"`, `"Gold"`), or `nil` if index is out of range.
- **OCCT:** `Graphic3d_MaterialAspect::MaterialName`.
- **Example:**
  ```swift
  for i in 1...Material.predefinedMaterialCount {
      if let name = Material.predefinedMaterialName(at: i) {
          print(i, name)
      }
  }
  ```

---

### `Material.predefinedMaterial(named:)`

Gets full Phong + PBR properties of a predefined OCCT material by name.

```swift
public static func predefinedMaterial(named name: String) -> PredefinedMaterial?
```

- **Parameters:** `name` — material name string (e.g. `"Brass"`, `"Gold"`, `"Copper"`); case-sensitive as per OCCT.
- **Returns:** `PredefinedMaterial` struct with all properties, or `nil` if the name is not recognized.
- **OCCT:** `Graphic3d_MaterialAspect::MaterialFromName` → `Graphic3d_MaterialAspect` constructor.
- **Example:**
  ```swift
  if let brass = Material.predefinedMaterial(named: "Brass") {
      print(brass.pbrMetallic, brass.pbrRoughness)
  }
  ```

---

### `Material.predefinedMaterial(at:)`

Gets full Phong + PBR properties of a predefined OCCT material by 1-based index.

```swift
public static func predefinedMaterial(at index: Int) -> PredefinedMaterial?
```

- **Parameters:** `index` — 1-based index (1 … `predefinedMaterialCount`).
- **Returns:** `PredefinedMaterial` struct, or `nil` if index is out of range.
- **OCCT:** `Graphic3d_MaterialAspect` constructor from `Graphic3d_NameOfMaterial`.
- **Example:**
  ```swift
  if let mat = Material.predefinedMaterial(at: 1) {
      print(mat.ambientColor, mat.shininess)
  }
  ```

---

### `Material.minRoughness`

Minimum PBR roughness value enforced by OCCT.

```swift
public static var minRoughness: Float { get }
```

Values below this threshold are clamped internally by `Graphic3d_PBRMaterial`. Use this to validate inputs before building materials.

- **Returns:** The minimum valid PBR roughness (`Graphic3d_PBRMaterial::MinRoughness()`).
- **OCCT:** `Graphic3d_PBRMaterial::MinRoughness`.
- **Example:**
  ```swift
  let safeRoughness = max(Double(Material.minRoughness), userInput)
  ```

---

### `Material.roughnessFromSpecular(color:shininess:)`

Computes an approximate PBR roughness value from a Phong specular color and shininess.

```swift
public static func roughnessFromSpecular(color: Color, shininess: Double) -> Float
```

Useful for converting legacy Phong materials (e.g. from STEP files) into PBR parameters.

- **Parameters:** `color` — Phong specular color; `shininess` — Phong shininess exponent.
- **Returns:** PBR roughness in \[0, 1\].
- **OCCT:** `Graphic3d_PBRMaterial::RoughnessFromSpecular`.
- **Example:**
  ```swift
  let r = Material.roughnessFromSpecular(color: Color(red: 0.8, green: 0.8, blue: 0.8), shininess: 50)
  ```

---

### `Material.metallicFromSpecular(color:)`

Computes an approximate PBR metallic factor from a Phong specular color.

```swift
public static func metallicFromSpecular(color: Color) -> Float
```

Bright/achromatic specular colors produce higher metallic values; colored specular indicates metal.

- **Parameters:** `color` — Phong specular color.
- **Returns:** PBR metallic factor in \[0, 1\].
- **OCCT:** `Graphic3d_PBRMaterial::MetallicFromSpecular`.
- **Example:**
  ```swift
  let m = Material.metallicFromSpecular(color: Color(red: 0.95, green: 0.93, blue: 0.88))
  ```
