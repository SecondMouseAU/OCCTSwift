# #1419: `fillMaterialProps` reads `Graphic3d_PBRMaterial::Roughness()` instead of `NormalizedRoughness()`

## What this probes

`fillMaterialProps` (duplicated across all four `OCCTBridge_Visualization_*.mm` split files, live
only in `_Appearance.mm`) filled `props->pbrRoughness` from `pbr.Roughness()`. Per
`Graphic3d_PBRMaterial.hxx`, `Roughness()` is `Roughness(myRoughness)`, a static remap
`theNormalizedRoughness * (1.f - MinRoughness()) + MinRoughness()` — internal calculation-space,
never the authored `[0,1]` value. `NormalizedRoughness()` returns `myRoughness` verbatim, the real
authored value (e.g. what a glTF `roughnessFactor` round-trip needs).

`roughness_survey.mm` iterates every predefined `Graphic3d_MaterialAspect` and prints both
accessors side by side, confirming the remap is live (not just present in the header) for every
one of OCCT's 24 predefined materials, and picking concrete numbers to pin in
`Tests/OCCTFoundationTests/OCCTFoundationTests.swift`'s
`predefinedMaterialRoughnessIsAuthoredValueNotRemap` /
`predefinedMaterialRoughnessMatchesNormalizedNotRemappedMetallic`:

- `Water`/`Glass`/`Diamond`/`Neon`/`Ionized`: authored (normalized) roughness is exactly `0.0`
  (`Graphic3d_PBRMaterial::SetBSDF`'s dielectric-glass branch calls `SetRoughness(0.f)` directly);
  the wrong accessor reads back exactly `MinRoughness()` (`0.01`), which is *never* the authored
  value for a material whose real roughness is genuinely zero, and Roughness() can never go below
  `MinRoughness()` for **any** material, by construction.
- `Brass`/`Bronze`/`Copper`/`Gold`/`Silver`/`Steel`/`Metalized`/`Chrome`/`Aluminium` (all
  `metallic=1`): authored roughness `0.212132` (`sqrt(0.045)`, `Graphic3d_BSDF::CreateMetallic`'s
  roughness parameter propagated through `Graphic3d_Fresnel`), remapped `0.220011` — close enough
  that a loose test tolerance would pass either way, so the Swift test asserts the value is close
  to the authored one and *not* close to the remapped one.

## Reproduce

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/1419-pbr-roughness-accessor/roughness_survey.mm \
  -o /tmp/occt_1419_roughness_survey
/tmp/occt_1419_roughness_survey
```

`transcript.txt` is the captured output (V8_0_1 + carried patches, macOS arm64).
