---
title: ThreadFeatures
parent: API Reference
---

# ThreadFeatures

OCCTSwift's thread feature API lives in `Sources/OCCTSwift/ThreadFeatures.swift`. It adds three `Shape` methods (`threadedShaft`, `threadedHole`, `threadedRod`) plus the supporting value types `ThreadSpec`, `ThreadProfile`, `ThreadForm`, `ThreadBuild`, and `RunoutStyle`. OCCT ships no kernel "thread feature"; all thread geometry is composed from already-wrapped OCCT primitives (`Shape.loft`, `Wire.arc`, `Wire.interpolate`, `Shape.sew`) in Swift — the bridge is invoked only for the fallback smooth-helicoid cutter (`OCCTShapeBuildThreadCutter`).

## Topics

- [Threaded features on Shape](#threaded-features-on-shape) · [ThreadSpec](#threadspec) · [ThreadProfile](#threadprofile) · [Enums](#enums)

---

## Threaded features on Shape

### `Shape.threadedShaft(axisOrigin:axisDirection:spec:length:starts:runout:build:)`

Cuts a helical V-profile external thread into a cylindrical shaft.

```swift
public func threadedShaft(axisOrigin: SIMD3<Double>,
                           axisDirection: SIMD3<Double>,
                           spec: ThreadSpec,
                           length: Double? = nil,
                           starts: Int = 1,
                           runout: RunoutStyle = .none,
                           build: ThreadBuild = .auto) -> Shape?
```

When `self` is a plain cylinder coaxial with the axis (the common case) and `starts == 1`, this builds the threaded rod **directly with no boolean** for every build mode (`.boolean` is deprecated and treated as `.auto` since #254): the thread's true cross-section (a "cam": root arc → flank → crest arc → flank) is lofted at closely-spaced z-slices rotated by the helix (`ruled=false`), giving a smooth, BRepCheck-valid solid of a handful of B-spline faces. Any unthreaded margin is closed by pure sewing (shoulder + cylinder + end disk). Because the boolean engine is never invoked, the result is orientation-robust and valid where a cut-the-cutter approach is faceted or fails. For non-cylinder targets, multi-start, or when the direct build fails, the method falls back to the boolean cut path (`applyThreadCut`).

- **Parameters:**
  - `axisOrigin` — a point on the shaft axis (typically the centre of the bottom face).
  - `axisDirection` — unit vector along the shaft axis (normalised internally).
  - `spec` — thread form and dimensions.
  - `length` — threaded length in mm (default: `2 * spec.nominalDiameter`).
  - `starts` — number of thread starts (1 for standard fasteners; >1 for lead screws). Multi-start forces the boolean cut path.
  - `runout` — thread termination style at each end (see `RunoutStyle`).
  - `build` — construction path selector; `.auto` (default) and `.direct` use the smooth direct build for single-start coaxial cylinders. `.boolean` is **deprecated** (#254) and now behaves like `.auto`. See `ThreadBuild`.
- **Returns:** Threaded shape, or `nil` on sweep / boolean failure. Use `boundingBoxOptimal()` (not `bounds`) to measure the true crest radius — the BSpline pole hull overshoots by ~13–21%.
- **OCCT:** Pure-Swift direct path: `Shape.loft`, `Wire.arc`, `Wire.interpolate`, `Wire.join`, `Shape.face(from:)`, `Shape.sew`, `Shape.solidFromShell` — no boolean. Fallback cut path: `OCCTShapeBuildThreadCutter` (bridge: analytic helicoid cutter), `Shape.screwSweptThreadCutter`, `Shape.subtracting`.
- **Example:**
  ```swift
  guard let shank = Shape.cylinder(radius: 6, height: 24) else { return }
  let spec = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
  guard let threaded = shank.threadedShaft(axisOrigin: .zero,
                                            axisDirection: SIMD3(0, 0, 1),
                                            spec: spec, length: 18) else { return }
  // threaded.isValid == true; ~9 faces (smooth), crest at nominal radius (6 mm)
  ```
- **Note:** For a multi-start or left-handed thread the boolean cut path is used automatically (`starts: 2` or `spec.leftHanded == true`). The tapered pipe forms (`.nptTapered`, `.bsptTapered`) always use the cut path since the smooth direct build supports parallel forms only.

---

### `Shape.threadedHole(axisOrigin:axisDirection:spec:depth:starts:runout:)`

Cuts a helical V-profile internal thread into an existing bore.

```swift
public func threadedHole(axisOrigin: SIMD3<Double>,
                          axisDirection: SIMD3<Double>,
                          spec: ThreadSpec,
                          depth: Double? = nil,
                          starts: Int = 1,
                          runout: RunoutStyle = .none) -> Shape?
```

Always uses the boolean cut path (`applyThreadCut` with `apexSign: +1`): a helical cutter is swept into the bore wall and subtracted from `self`. Because the cutter is cut into a thick wall (not a thin shaft), OCCT's boolean handles a smooth (`ruled=false`) helical cutter robustly, so internal threads come out smooth and BRepCheck-valid. `self` must already contain the bore (a cylinder subtracted out, or any through-hole body).

- **Parameters:**
  - `axisOrigin` — point on the bore axis (typically the centre of the entry face).
  - `axisDirection` — unit vector along the bore, pointing into the solid material.
  - `spec` — thread specification.
  - `depth` — axial length of the threaded region in mm (default: `2 * spec.nominalDiameter`).
  - `starts` — number of thread starts.
  - `runout` — thread termination style.
- **Returns:** Shape with the tapped thread cut, or `nil` on boolean failure.
- **OCCT:** `OCCTShapeBuildThreadCutter` (analytic helicoid bridge, ISO-68/Unified only), `Shape.screwSweptThreadCutter` (fallback), `Shape.subtracting`.
- **Example:**
  ```swift
  guard let outer = Shape.cylinder(radius: 12, height: 16),
        let bore  = Shape.cylinder(radius: 6,  height: 16),
        let block = outer.subtracting(bore) else { return }
  let tapped = block.threadedHole(
      axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
      spec: ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75),
      depth: 14)
  // tapped?.isValid == true
  ```
- **Note:** Pass the *solid body with the bore already in it* — `threadedHole` does not drill the hole. The outer surface and outer diameter are unchanged; only the bore wall gains the helical thread form.

---

### `Shape.threadedRod(customProfile:nominalDiameter:pitch:cutDepth:length:axisOrigin:axisDirection:leftHanded:)`

Builds a smooth threaded rod from a custom radial cross-section, directly and with no boolean.

```swift
public static func threadedRod(customProfile: ThreadProfile,
                                nominalDiameter: Double,
                                pitch: Double,
                                cutDepth: Double,
                                length: Double,
                                axisOrigin: SIMD3<Double> = .zero,
                                axisDirection: SIMD3<Double> = SIMD3(0, 0, 1),
                                leftHanded: Bool = false) -> Shape?
```

The entry point for threading a cylinder with a custom tooth shape (worm, screw conveyor, proprietary fastener). Composes the thread region (a `ruled=false` cam-slice loft of the profile swept along the exact helix) with the core cylinder by pure sewing — no boolean is invoked — so the result is BRepCheck-valid and analytic (a small number of B-spline faces, not a faceted multi-MB solid). The cross-section is a `ThreadProfile` in normalised `(axial, depth)` coordinates: `axial` 0…1 spans one pitch, `depth` 0 = crest (at `nominalDiameter / 2`) … 1 = root (at `nominalDiameter / 2 − cutDepth`). The profile must satisfy `ThreadProfile.supportsSmoothRodBuild` (a real crest flat, ≤ 2 flank segments); rounded or many-flank profiles do not satisfy this and return `nil`. For standard named forms (ISO, Unified, ACME, …), prefer `threadedShaft` with a `ThreadForm` spec.

- **Parameters:**
  - `customProfile` — normalised tooth cross-section; must satisfy `supportsSmoothRodBuild`.
  - `nominalDiameter` — outer (crest) diameter in mm.
  - `pitch` — axial advance per turn in mm.
  - `cutDepth` — radial depth crest → root in mm (must be < `nominalDiameter / 2`).
  - `length` — threaded length along the axis in mm.
  - `axisOrigin` — a point on the rod axis at the thread start (default `.zero`).
  - `axisDirection` — rod axis direction (default `SIMD3(0, 0, 1)`).
  - `leftHanded` — helix handedness (default `false` = right-hand).
- **Returns:** A valid, smooth threaded rod, or `nil` if inputs are degenerate, the profile does not satisfy `supportsSmoothRodBuild`, or the direct build cannot produce a valid solid. Does not silently fall back to a boolean result.
- **OCCT:** Pure-Swift composition: `Shape.loft`, `Wire.arc`, `Wire.interpolate`, `Wire.join`, `Shape.face(from:)`, `Shape.sew`, `Shape.solidFromShell` — no boolean, no bridge cutter.
- **Example:**
  ```swift
  guard let tooth = ThreadProfile(vertices: [
      .init(axial: 0.000, depth: 1), .init(axial: 0.125, depth: 1),
      .init(axial: 0.375, depth: 0), .init(axial: 0.625, depth: 0),
      .init(axial: 0.875, depth: 1), .init(axial: 1.000, depth: 1),
  ]),
        let worm = Shape.threadedRod(customProfile: tooth, nominalDiameter: 12,
                                     pitch: 5, cutDepth: 1.8, length: 22) else { return }
  // worm.isValidSolid == true — smooth, analytic (handful of B-spline faces)
  ```
- **Note:** `ThreadProfile.supportsSmoothRodBuild` requires a real crest flat (`hasCrestFlat == true`) and at most two flank segments. Pointed-crest or multi-segment rounded profiles (knuckle, custom sinusoidal) return `nil` here and must use `threadedShaft` with the boolean cut path instead.

---

## ThreadSpec

Full specification of a thread's form, diameter, pitch, and handedness. `Sendable`, `Hashable`, `Codable`.

```swift
public struct ThreadSpec: Sendable, Hashable, Codable
```

### `ThreadSpec.init(form:nominalDiameter:pitch:leftHanded:customProfile:customCutDepth:)`

General-purpose initialiser.

```swift
public init(form: ThreadForm, nominalDiameter: Double, pitch: Double, leftHanded: Bool = false,
            customProfile: ThreadProfile? = nil, customCutDepth: Double? = nil)
```

- **Parameters:**
  - `form` — thread form (see `ThreadForm`).
  - `nominalDiameter` — outer (crest) diameter in mm.
  - `pitch` — axial advance per revolution in mm.
  - `leftHanded` — `true` for left-hand helix (default `false`).
  - `customProfile` — tooth cross-section for `form == .custom`; ignored otherwise.
  - `customCutDepth` — overrides the form's default radial depth (mm); required for `.custom`.

---

### `ThreadSpec.init(customProfile:nominalDiameter:pitch:cutDepth:leftHanded:)`

Convenience initialiser for a fully custom tooth shape — sets `form` to `.custom` and stores `customProfile`/`cutDepth`.

```swift
public init(customProfile: ThreadProfile, nominalDiameter: Double, pitch: Double,
            cutDepth: Double, leftHanded: Bool = false)
```

- **Parameters:** as above; `cutDepth` becomes `customCutDepth`.

---

### `ThreadSpec.parse(_:)`

Parses a standard thread designation string.

```swift
public static func parse(_ text: String) -> ThreadSpec?
```

Recognises metric `M5x0.8` / `M10` (coarse-pitch table); Unified / UNC / UNF `1/4-20 UNC`, `3/8-16`; trapezoidal `Tr40x7` / `Tr40x7LH`; ACME `1.5-4 ACME`; Whitworth `W1/2` / `1/2 BSW`; BSP parallel `G1/2`; BSP taper `R1/2` / `Rc1/2`; NPT `1/2-14 NPT`. Input is trimmed of whitespace before matching.

- **Parameters:** `text` — designation string.
- **Returns:** `ThreadSpec`, or `nil` on unrecognised input.
- **OCCT:** Pure-Swift — no bridge calls.
- **Example:**
  ```swift
  ThreadSpec.parse("M5x0.8")      // .iso68,   Ø5,    pitch 0.8
  ThreadSpec.parse("M10")         // .iso68,   Ø10,   pitch 1.5 (coarse table)
  ThreadSpec.parse("1/4-20 UNC")  // .unified, Ø6.35, pitch 1.27
  ThreadSpec.parse("Tr40x7LH")    // .trapezoidal, Ø40, pitch 7, leftHanded
  ThreadSpec.parse("G1/2")        // .bspParallel, Ø20.955, 14 TPI
  ThreadSpec.parse("1/2-14 NPT")  // .nptTapered
  ```

---

### `ThreadSpec.profile`

The tooth cross-section for this spec's form, or the custom profile.

```swift
public var profile: ThreadProfile { get }
```

Dispatches on `form`: ISO-68 / Unified / NPT → `ThreadProfile.iso60V()`; Whitworth / BSP / BSPT → `.whitworth55`; ACME → `.acme29`; trapezoidal → `.trapezoidalMetric30`; square → `.square`; buttress → `.buttress`; knuckle → `.knuckle`; custom → `customProfile ?? .iso60V()`.

- **Returns:** `ThreadProfile` instance for use by the modeller.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.cutDepth`

Practical radial thread depth (crest → root), form-dependent.

```swift
public var cutDepth: Double { get }
```

`customCutDepth` overrides when set. Standard values: ISO-68 / Unified / NPT = `5H/8`; Whitworth / BSP / BSPT = `0.640327 × pitch`; ACME / trapezoidal / square = `0.5 × pitch`; knuckle (DIN 405) = `0.55 × pitch`; buttress (DIN 513) = `0.86777 × pitch`.

- **Returns:** Radial depth in mm.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.taperRatio`

Diametral taper rate (NPT / BSPT are `1:16`; all parallel forms are `0`). The radius changes by `taperRatio / 2` per unit of axial length.

```swift
public var taperRatio: Double { get }
```

- **Returns:** `1.0 / 16` for `.nptTapered` and `.bsptTapered`; `0` otherwise.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.halfFlankAngle`

Half of the 60° included angle (ISO-68 / Unified).

```swift
public var halfFlankAngle: Double { get }
```

Returns `Double.pi / 6` (30°). Meaningful only for ISO-68 and Unified forms; use `spec.profile` for other forms.

- **Returns:** `π/6`.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.theoreticalDepth`

Theoretical (untruncated) 60° V thread depth — `H = pitch × √3 / 2` per ISO-68.

```swift
public var theoreticalDepth: Double { get }
```

- **Returns:** `pitch * sqrt(3) / 2`.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.crestFlat`

Axial width of the truncated crest flat (ISO-68 external). Equal to `P/8`.

```swift
public var crestFlat: Double { get }
```

- **Returns:** `pitch / 8`.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.rootFlat`

Axial width of the truncated root flat (ISO-68 external). Equal to `P/4`.

```swift
public var rootFlat: Double { get }
```

- **Returns:** `pitch / 4`.
- **OCCT:** Pure-Swift.

---

### `ThreadSpec.minorDiameter`

Minor diameter — the inner diameter at the thread root (external) or crest (internal). Form-dependent via `cutDepth`.

```swift
public var minorDiameter: Double { get }
```

- **Returns:** `nominalDiameter - 2 * cutDepth`.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  let m12 = ThreadSpec(form: .iso68, nominalDiameter: 12, pitch: 1.75)
  m12.theoreticalDepth   // H  ≈ 1.516
  m12.cutDepth           // 5H/8 ≈ 0.947
  m12.minorDiameter      // ≈ 10.106
  ```

---

## ThreadProfile

A thread's tooth cross-section over one pitch, normalised. `Sendable`, `Hashable`, `Codable`.

```swift
public struct ThreadProfile: Sendable, Hashable, Codable
```

`axial` runs `0…1` along the pitch; `depth` runs `0` (crest, at the major radius) … `1` (root, at the minor radius). Vertices are ordered by increasing `axial`; the profile is periodic (`first.axial == 0`, `last.axial == 1`, `first.depth == last.depth`) so consecutive teeth tile. The modeller maps a vertex to 3D as radius `rMajor − depth × cutDepth`, axial position `axial × pitch`, helix angle `θ(z) + handed × axial × 2π`.

---

### `ThreadProfile.Vertex`

A single point in the normalised tooth outline.

```swift
public struct Vertex: Sendable, Hashable, Codable {
    public var axial: Double   // 0…1 along the pitch
    public var depth: Double   // 0 = crest (major R), 1 = root (minor R)
    public init(axial: Double, depth: Double)
}
```

---

### `ThreadProfile.init?(vertices:)`

Validates and creates a custom profile.

```swift
public init?(vertices: [Vertex])
```

Returns `nil` unless the vertices form a well-ordered, periodic, full-depth-spanning tooth outline: at least 3 vertices; `first.axial ≈ 0`, `last.axial ≈ 1`; `first.depth ≈ last.depth`; vertices are monotonically non-decreasing in `axial`; depth spans [0, 1] (must include a crest vertex at `depth ≈ 0` and a root vertex at `depth ≈ 1`).

- **Parameters:** `vertices` — ordered vertex list defining the tooth outline.
- **Returns:** Valid `ThreadProfile`, or `nil` if the outline violates the contract.
- **OCCT:** Pure-Swift.
- **Example:**
  ```swift
  guard let profile = ThreadProfile(vertices: [
      .init(axial: 0.0, depth: 1), .init(axial: 0.1, depth: 1),   // root flat
      .init(axial: 0.5, depth: 0), .init(axial: 0.6, depth: 0),   // crest flat
      .init(axial: 0.9, depth: 1), .init(axial: 1.0, depth: 1),   // root flat
  ]) else { return }
  // profile.supportsSmoothRodBuild == true
  ```

---

### `ThreadProfile.vertices`

The ordered vertex list defining the tooth outline.

```swift
public let vertices: [Vertex]
```

---

### `ThreadProfile.SegmentKind`

Segment classification for the modeller and cutter.

```swift
public enum SegmentKind: Sendable, Hashable {
    case flat   // constant depth → circular arc in 3D
    case wall   // constant axial → radial line (square thread walls)
    case flank  // sloped → sampled spline
}
```

---

### `ThreadProfile.Segment`

A consecutive pair of vertices with its geometric classification.

```swift
public struct Segment: Sendable, Hashable {
    public let a: Vertex, b: Vertex, kind: SegmentKind
}
```

---

### `ThreadProfile.segments`

One segment per consecutive vertex pair, with `SegmentKind` classification.

```swift
public var segments: [Segment] { get }
```

- **Returns:** Array of `Segment` structs; `flat` where `a.depth ≈ b.depth`, `wall` where `a.axial ≈ b.axial`, `flank` otherwise.
- **OCCT:** Pure-Swift.

---

### `ThreadProfile.hasCrestFlat`

`true` if the crest (`depth ≈ 0`) contains a real flat of non-zero axial width.

```swift
public var hasCrestFlat: Bool { get }
```

Pointed-crest profiles (a single vertex at `depth = 0`) return `false` and cannot use the smooth direct rod build path.

- **Returns:** Boolean indicating the presence of a usable crest flat.
- **OCCT:** Pure-Swift.

---

### `ThreadProfile.supportsSmoothRodBuild`

Whether this profile can be built by the smooth, boolean-free direct rod path.

```swift
public var supportsSmoothRodBuild: Bool { get }
```

Requires a real crest flat (`hasCrestFlat == true`) and at most two flank segments. Pointed-crest or many-flank profiles (knuckle, sinusoidal) return `false` and must use the faceted boolean cut path instead. Consumed by `Shape.threadedRod` and the direct branch of `Shape.threadedShaft`.

- **Returns:** `hasCrestFlat && segments.filter { $0.kind == .flank }.count <= 2`.
- **OCCT:** Pure-Swift.

---

### `ThreadProfile.iso60V(crestFlatFraction:rootFlatFraction:)`

ISO-68 / Unified 60° V profile.

```swift
public static func iso60V(crestFlatFraction: Double = 1.0 / 8,
                           rootFlatFraction: Double = 1.0 / 4) -> ThreadProfile
```

Symmetric truncated trapezoid: root half-flats at the ends, crest flat in the middle, straight 30° flanks between. Defaults reproduce the shipped ISO-68 geometry exactly (`crest P/8`, `root P/4`).

- **Parameters:** `crestFlatFraction` — crest flat as a fraction of pitch; `rootFlatFraction` — root flat as a fraction of pitch.
- **Returns:** A valid `ThreadProfile`.
- **OCCT:** Pure-Swift.

---

### `ThreadProfile.whitworth55`

Whitworth / BSW / BSP 55° profile (flat-truncation, `cutDepth = 0.640327 × P`).

```swift
public static let whitworth55: ThreadProfile
```

Crest flat = root flat = `P/6`. The standard rounds the outer/inner sixth of the tooth; this is the flat-truncation of that form, which satisfies `supportsSmoothRodBuild`.

---

### `ThreadProfile.acme29`

ACME 29° general-purpose profile (crest flat = root flat = `0.3707 × P` at `cutDepth = P/2`).

```swift
public static let acme29: ThreadProfile
```

---

### `ThreadProfile.trapezoidalMetric30`

ISO metric trapezoidal "Tr" 30° profile (crest flat = root flat = `0.366 × P` at `cutDepth = P/2`).

```swift
public static let trapezoidalMetric30: ThreadProfile
```

---

### `ThreadProfile.square`

Square thread profile — 0° radial walls, equal land and groove (`cutDepth = P/2`).

```swift
public static let square: ThreadProfile
```

---

### `ThreadProfile.buttress`

Buttress (DIN 513) — asymmetric 3° load flank / 30° clearance flank, `cutDepth = 0.86777 × P`.

```swift
public static let buttress: ThreadProfile
```

The near-radial (3°) load flank rises steeply to the crest; the 30° clearance flank falls back to the root. Verified against the DIN 513 table (e.g. S 10×2 → d3 = 6.528).

---

### `ThreadProfile.knuckle`

Knuckle / round thread (DIN 405): 30°-included (15° per side) flanks with circular-arc rounded crest and root, at standard depth `0.55 × P`.

```swift
public static let knuckle: ThreadProfile
```

Small crest/root lands are kept so the smooth direct build can attach a crest flat. `supportsSmoothRodBuild` is `true` for this profile. Verified against the DIN 405 dimension table (bolt minor `d3 = d − 1.1 × P`).

---

## Enums

### `ThreadForm`

Which standard thread geometry to use. `String`, `Sendable`, `Codable`, `CaseIterable`.

```swift
public enum ThreadForm: String, Sendable, Codable, CaseIterable {
    case iso68          // Metric M-series, 60° V
    case unified        // Unified (UNC / UNF / metric-fine / SAE), 60° V
    case whitworth      // BSW Whitworth, 55°
    case bspParallel    // BSP parallel "G", Whitworth 55° form
    case acme           // ACME general-purpose, 29° trapezoidal
    case trapezoidal    // ISO metric trapezoidal "Tr", 30°
    case square         // square / 0° walls
    case buttress       // asymmetric buttress, 7° load / 45° trailing
    case knuckle        // rounded / sinusoidal (DIN 405)
    case nptTapered     // NPT — 60° V on a 1:16 taper
    case bsptTapered    // BSPT — 55° on a 1:16 taper
    case custom         // arbitrary cross-section (see ThreadSpec.customProfile)
}
```

| Case | Form / standard | Angle | Notes |
|---|---|---|---|
| `.iso68` | Metric M-series | 60° V | ISO 68-1; coarse-pitch table in `ThreadSpec.parse` |
| `.unified` | UNC / UNF / SAE / metric-fine | 60° V | Same form, just a pitch |
| `.whitworth` | BSW / Whitworth | 55° | BS 84; flat-truncated crest/root |
| `.bspParallel` | BSP "G" parallel | 55° | EN ISO 228 / BS 2779 |
| `.acme` | ACME general-purpose | 29° | Power / lead screws |
| `.trapezoidal` | ISO Tr metric | 30° | DIN 103 |
| `.square` | Square | 0° | Equal land and groove |
| `.buttress` | Buttress | 3°/30° | DIN 513 asymmetric |
| `.knuckle` | Knuckle/round | 30° included, rounded | DIN 405 |
| `.nptTapered` | NPT | 60° V on 1:16 taper | ANSI B1.20.1 |
| `.bsptTapered` | BSPT | 55° on 1:16 taper | BS EN 10226 |
| `.custom` | Arbitrary | — | Supply `customProfile` on `ThreadSpec` |

- **OCCT:** Pure-Swift enum; consumed by `ThreadSpec.profile`, `ThreadSpec.cutDepth`, and `ThreadSpec.taperRatio`.
- **Note:** `.acme`, `.trapezoidal`, `.square`, `.buttress`, and `.knuckle` are open for future tolerance-class (2B, 3A, etc.) parameters — those are fit-allowance tables, not form geometry, and are not currently modelled.

---

### `ThreadBuild`

Construction path selector for `Shape.threadedShaft`. `Sendable`, `Hashable`, `Codable`.

```swift
public enum ThreadBuild: Sendable, Hashable, Codable {
    case auto
    case direct
    case boolean
}
```

| Case | Behaviour |
|---|---|
| `.auto` | Smooth boolean-free direct build for single-start coaxial cylinders; falls back to the boolean cut otherwise (multi-start / non-cylinder). The recommended default. |
| `.direct` | Prefer the smooth direct build; fall back to the boolean cut when unavailable (multi-start, non-cylinder, construction failure). Identical to `.auto` for single-start coaxial cylinders. |
| `.boolean` | **Deprecated (#254).** Formerly forced the boolean cut path; now treated exactly like `.auto` (single-start coaxial cylinders take the smooth direct build). Its forced cut path produced a *faceted, frequently disconnected* thread and offered no envelope advantage. Use `.auto` or `.direct`. |

- **Note (#222 / #232 / #254):** the direct build's crest sits **at** the nominal major radius — the earlier "overshoot" report was a `Bnd_Box` control-hull artifact. Measure the true crest with `boundingBoxOptimal()` or mesh vertices (both read nominal); `bounds` over-reads by ~13–21% on the B-spline helicoid. There is no longer a reason to force the cut path for an "exact outer diameter".
- **Known limitation:** multi-start threads (`starts > 1`) and non-cylinder targets still use the faceted boolean cut, which can come out as disconnected notches rather than a continuous helix — a smooth multi-start/internal direct build is a tracked gap.

---

### `RunoutStyle`

How a thread terminates at its ends. `Sendable`, `Hashable`.

```swift
public enum RunoutStyle: Sendable, Hashable {
    case none
    case filleted(radius: Double)
    case tapered(turns: Double)
}
```

| Case | Behaviour |
|---|---|
| `.none` | Hard-stop at each end (no runout). Cheap and exact but manufacturing-unrealistic. Default. |
| `.filleted(radius:)` | Fillet the last turns' worth of helix into the underlying surface — a post-boolean/sew fillet pass of the given radius. |
| `.tapered(turns:)` | Taper the V-profile to zero depth over the last `turns` revolutions using a law-scaled sweep. Currently falls back to `.filleted(radius: spec.pitch * 0.5)` while law-scaling is not yet wrapped (#67). |

- **OCCT:** `.filleted` delegates to `Shape.filleted(radius:)` (bridge: `BRepFilletAPI_MakeFillet`). `.tapered` is a planned law-scaled pipe-shell extension (issue #67); currently approximated by `.filleted`.
- **Example:**
  ```swift
  rod.threadedShaft(axisOrigin: .zero, axisDirection: SIMD3(0, 0, 1),
                    spec: spec, length: 18,
                    runout: .filleted(radius: 0.4))
  ```
