---
title: GProps
parent: API Reference
---

# GProps

`GProps` is the global properties of a bounded patch of an analytic surface, or of the solid it
sweeps: mass, centre of mass, matrix of inertia, static moments, moments of inertia and radii of
gyration about an axis, and the principal properties. It wraps `GProp_SelGProps` (the patch itself,
`Kind.surface`) and `GProp_VelGProps` (the swept solid, `Kind.volume`), whose results are
`GProp_GProps`, and `GProp_PrincipalProps` for the principal properties. You get one from the four
factories, one per `gp` surface: `cylinder`, `cone`, `sphere` and `torus`.

The whole-shape accessors (`Shape.volume`, `Shape.surfaceArea`, `Shape.properties`) go through
`BRepGProp` and do not take a partial range; `GProps` is the way to measure a partial turn or a part
of a surface directly. The older `GeometryProperties.cylinderVolume` family reads `Mass()` of the
full range only.

## Topics

- [Surface or volume](#surface-or-volume) · [Frame](#gpropsframe) · [Factories](#factories) · [Interrogation](#interrogation) · [PrincipalProperties](#gpropsprincipalproperties) · [Composition](#composition) · [Patch dependence](#patch-dependence)

---

## Surface or volume

```swift
public enum Kind: Sendable { case surface, volume }
```

- `surface`: `GProp_SelGProps`, the patch itself. `mass` is its area.
- `volume`: `GProp_VelGProps`, the solid swept between the axis and the patch. The axis for a
  cylinder or cone, the centre for a sphere, and the circle through the centres of the tube for a
  torus. `mass` is its volume.

## GProps.Frame

```swift
public struct Frame: Sendable, Equatable {
    public var origin: SIMD3<Double>
    public var axis: SIMD3<Double>
    public var xDirection: SIMD3<Double>?
    public init(origin: SIMD3<Double> = .zero, axis: SIMD3<Double> = SIMD3(0, 0, 1), xDirection: SIMD3<Double>? = nil)
}
```

The placement of the surface, `gp_Ax3`. `axis` is the main direction and `xDirection` is where the
angle starts; with nil, OCCT picks one. OCCT orthogonalises `xDirection` against `axis`.

- **OCCT:** `gp_Ax3(const gp_Pnt&, const gp_Dir& N, const gp_Dir& Vx)` and `gp_Ax3(const gp_Pnt&, const gp_Dir&)`.

## Factories

All four return nil when OCCT rejects the input (a negative radius, a cone half angle at or beyond
a right angle, a zero axis, an `xDirection` along the axis), when a range is empty, reversed or not
finite, or when the result is not finite. A measurement that is not a number is refused and never
reported.

```swift
public static func cylinder(_ kind: Kind, frame: Frame = Frame(), radius: Double, alpha1: Double, alpha2: Double, z1: Double, z2: Double) -> GProps?
public static func cone(_ kind: Kind, frame: Frame = Frame(), semiAngle: Double, refRadius: Double, alpha1: Double, alpha2: Double, z1: Double, z2: Double) -> GProps?
public static func sphere(_ kind: Kind, frame: Frame = Frame(), radius: Double, teta1: Double, teta2: Double, alpha1: Double, alpha2: Double) -> GProps?
public static func torus(_ kind: Kind, frame: Frame = Frame(), majorRadius: Double, minorRadius: Double, teta1: Double, teta2: Double, alpha1: Double, alpha2: Double) -> GProps?
```

- **OCCT:** `GProp_SelGProps::Perform` and `GProp_VelGProps::Perform`, overloads for `gp_Cylinder`,
  `gp_Cone`, `gp_Sphere` and `gp_Torus`. The parameter names are OCCT's: `alpha` is the angle about
  the axis (cylinder, cone) or the latitude (sphere) or the angle about the tube (torus), `teta` is
  the longitude or the angle about the axis, `z` is the height (cylinder) or the distance along
  the generatrix (cone).
- **The reference point is the origin and is not a parameter.** OCCT's `SLocation` is left out
  on purpose: `Perform` stores the centre of mass in global coordinates, where `CentreOfMass()` and
  `MatrixOfInertia()` read it relative to `SLocation`, so both are right only at the origin. Place
  the patch with `frame`.
- **Sphere latitude** outside `-pi/2 ... pi/2` is not a patch of the sphere; OCCT's closed form
  integrates a signed element there and the ranges are used as given.
- **Torus volume** over part of the tube is the solid swept by the segment from the circle
  through the centres of the tube to the patch. OCCT does not say what it means, and a full turn
  about the tube is the whole torus, `2 pi^2 R r^2`, either way.
- **Example:**
  ```swift
  // A quarter of a cylinder wall, and the wedge it bounds.
  if let wall = GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10),
      let wedge = GProps.cylinder(.volume, radius: 5, alpha1: 0, alpha2: .pi / 2, z1: 0, z2: 10)
  {
      print(wall.mass, wedge.mass)   // 78.54 and 196.35
      print(wall.centreOfMass)       // (3.18, 3.18, 5)
  }
  ```

## Interrogation

```swift
public var mass: Double
public var centreOfMass: SIMD3<Double>
public var matrixOfInertia: simd_double3x3
public var staticMoments: SIMD3<Double>
public func momentOfInertia(about origin: SIMD3<Double>, direction: SIMD3<Double>) -> Double?
public func radiusOfGyration(about origin: SIMD3<Double>, direction: SIMD3<Double>) -> Double?
public var principalProperties: PrincipalProperties?
public func symmetry(tolerance: Double) -> (hasAxis: Bool, hasPoint: Bool)?
```

- **OCCT:** `GProp_GProps::Mass`, `CentreOfMass`, `MatrixOfInertia`, `StaticMoments`,
  `MomentOfInertia(gp_Ax1)`, `RadiusOfGyration(gp_Ax1)`, `PrincipalProperties`, and
  `GProp_PrincipalProps::HasSymmetryAxis(double)` and `HasSymmetryPoint(double)`.
- `matrixOfInertia` is about the centre of mass, in axes parallel to the global ones.
- `momentOfInertia` and `radiusOfGyration` return nil for a zero or non-finite direction, which
  OCCT rejects when it builds the `gp_Dir`. `radiusOfGyration` also returns nil where OCCT's answer
  is not a number, which is a system of no mass.
- `symmetry(tolerance:)` returns nil for a negative or non-finite relative tolerance.
- **Example:**
  ```swift
  // The issue's number: the full cylinder wall, radius 5, height 10, about its axis.
  let wall = GProps.cylinder(.surface, radius: 5, alpha1: 0, alpha2: 2 * .pi, z1: 0, z2: 10)
  wall?.momentOfInertia(about: .zero, direction: SIMD3(0, 0, 1))   // 7853.98, 2 pi R^3 H
  ```

## GProps.PrincipalProperties

```swift
public struct PrincipalProperties: Sendable, Equatable {
    public var moments: SIMD3<Double>
    public var radiiOfGyration: SIMD3<Double>
    public var firstAxis: SIMD3<Double>
    public var secondAxis: SIMD3<Double>
    public var thirdAxis: SIMD3<Double>
    public var hasSymmetryAxis: Bool
    public var hasSymmetryPoint: Bool
}
```

The three principal moments and their eigenvectors, as `GProp_GProps::PrincipalProperties` returns
them, with the two symmetry flags at `GProp_PrincipalProps`'s default relative tolerance of 1e-10.
With a symmetry axis the two axes of inertia that match are any pair in their plane, and with a
symmetry point all three are arbitrary; OCCT returns the eigenvectors the Jacobi solver produced.

## Composition

```swift
@discardableResult
public func add(_ item: GProps, density: Double = 1) -> Bool
```

- **OCCT:** `GProp_GProps::Add(const GProp_GProps&, const double Density)`.
- Composes `item` into this system with a density, so `mass` becomes this mass plus
  `item.mass * density`. Returns false, and leaves this system as it was, for a density at or below
  OCCT's resolution (OCCT throws `Standard_DomainError`) or a result that is not a number.
- `GProps` is a class and is not `Sendable`, because `add` mutates it.

## Patch dependence

The matrix of inertia, `principalProperties`, the moments and radii about an axis, and the centre of
mass of a volume over a partial turn are right only on a kernel carrying the carried patches
`0050`, `0051` and `0055` (for the cone) and `0057` (for the cylinder, sphere and torus),
[`Scripts/patches/README.md`](https://github.com/SecondMouseAU/OCCTSwift/blob/main/Scripts/patches/README.md).
The release asset `Package.swift` pins predates them, so against it those values are wrong while
`mass` of a cylinder or sphere and the centre of a cylinder or sphere surface are right. The
tests that prove the values run in `kernel-integration.yml`, which builds the patches from source.
