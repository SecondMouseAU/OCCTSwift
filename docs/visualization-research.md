---
nav_exclude: true
search_exclude: true
---

# OCCT visualization → Metal: research findings

Research-only document scoping what it would take to render OCCT geometry on Apple's Metal API, and which of three concrete paths makes the most sense for the OCCTSwift / OCCTSwiftViewport stack.

---

## TL;DR

Three real paths exist; one is already deployed.

- **Path A — Full TKMetal driver port** (replace `TKOpenGl` with a new `Graphic3d_GraphicDriver` subclass). Multi-year effort, high maintenance burden, but full AIS surface fidelity and visionOS-native.
- **Path B — Mesh-extraction + native Metal**, which is what `OCCTSwiftViewport` already does today. Working now on macOS / iOS, no OCCT visualization toolkit dependency. Doesn't give you `AIS_InteractiveContext` semantics (selection→topology, manipulators, dimensions).
- **Path C — AIS-bridge layer on top of Path B**. Keep OCCT visualization off in the xcframework; build the high-value AIS-equivalent functionality (selection-from-topology, manipulator widgets, dimension annotations) as a Swift layer over `OCCTSwiftViewport`'s existing Metal renderer. ~80% of AIS value at ~10% of TKMetal effort.

**Recommendation: don't port TKOpenGl to TKMetal. Extend Path B with Path C.** Visualization stays out of the OCCTSwift xcframework; the Metal rendering surface stays in `OCCTSwiftViewport`; new AIS-equivalent features become Swift code on top.

---

## OCCT visualization architecture today

OCCT's visualization is layered across three toolkits, each in `Sources/Visualization/` of the OCCT tree:

| Toolkit | Layer | Role |
|---|---|---|
| **TKV3d** | High-level | `AIS_InteractiveContext`, `AIS_Shape`, `AIS_Trihedron`, `AIS_Manipulator`, etc. — application-facing object model. |
| **TKService** | Mid-level | Platform-independent primitive arrays (points, segments, triangles, fans), graphic structures, the **abstract `Graphic3d_GraphicDriver` interface**. Also `Aspect_`, `Quantity_`, `PrsMgr_`, `SelectMgr_`, `StdSelect_`, `V3d_`. |
| **TKOpenGl** | Low-level | The **only concrete `Graphic3d_GraphicDriver` implementation** in OCCT. ~50k+ lines of GL/GLES code: shader compilation, texture binding, buffer management, render passes, picking buffers, ray tracing, PBR, shadows, transparency sorting. |

We currently set `BUILD_MODULE_Visualization=OFF` and `USE_OPENGL=OFF / USE_GLES2=OFF` in `Scripts/build-occt.sh`, so the OCCTSwift xcframework ships **none** of these toolkits. OCCTSwift is a pure modeling kernel; visualization is OCCTSwiftViewport's job.

### The driver interface

`Graphic3d_GraphicDriver` is designed to be subclassed. The doc explicitly notes "potential for new Graphic3d_GraphicDriver implementations using other graphic APIs". TKD3DHost is a precedent — but it isn't a standalone driver, it's a **glue layer** that wraps a `TKOpenGl` viewer in a Direct3D9 host surface. The cleanest historical example shows OCCT doesn't ship a fully-parallel driver implementation; the abstraction surface has only ever had one concrete consumer.

### What's hardcoded to OpenGL

Quick spot check inside TKOpenGl: GLSL shaders for Phong + PBR + ray-tracing renderers, fixed-function pipeline state translation, framebuffer object management, multisample depth peeling for transparency, GPU pick buffer, environment cubemaps, shadow maps, FXAA. Every one of those would need a Metal-native equivalent in `TKMetal`.

---

## OCCT roadmap signals

- **No Vulkan, no Metal in active development.** As of OCCT 8.0.0-beta1 (May 2026):
  - Zero open PRs mentioning Vulkan in `Open-Cascade-SAS/OCCT`.
  - Zero issues mentioning Metal renderer.
  - No experimental branches.
- **OCCT maintainer Dmitrii Pasukhin on the forum** ([Future of OpenGL on Macs](https://dev.opencascade.org/content/future-opengl-macs)): "OCCT have plans to support Vulkan. It will be not so soon, but on long term plan we plan to support that renderer."
- The OCCT visualization page does say the 3D Viewer "might change considerably in the future with implementation of new features, improvements and adaptations to other graphic libraries like Vulkan" — but with no commitment to a date.
- **CADRays** (sibling Open-Cascade-SAS project) provides a separate GPU ray tracer for OCCT models — it isn't a Metal port either.

If you want OCCT-on-Metal, you build it. Don't expect upstream.

---

## Apple platform reality

| Platform | OpenGL status | Native Metal | Vulkan via MoltenVK |
|---|---|---|---|
| macOS 26 | Deprecated since 10.14 (2018), still works via Apple's GL-on-Metal compat shim | Yes | Yes (production-quality) |
| iOS 26 | GLES deprecated since iOS 12, still works via compat | Yes | Yes |
| **visionOS** | **Not natively supported.** OpenGL ES exists only as the WebGL2 base in Safari. App-level GL apps don't run. | Yes (only path) | MoltenVK 1.3 added visionOS in 2025 (preview-class) |
| tvOS | Same as iOS | Yes | Yes |

**visionOS is the forcing function** for any move beyond OpenGL. OCCT's TKOpenGl currently won't run there at all without a translation layer, and Apple has been clear they won't add native GL for new platforms.

We currently ship `xros-arm64` and `xros-arm64-simulator` slices in OCCT.xcframework (v0.167.0), but those slices contain only the **modeling kernel** because we built with `BUILD_MODULE_Visualization=OFF`. If we wanted `AIS_InteractiveContext` on visionOS, today we have nothing.

---

## Path A — Full TKMetal driver

**Approach:** subclass `Graphic3d_GraphicDriver`, mirror the TKOpenGl public surface in Metal terms.

### Scope of work

- **Shader translation**: every GLSL shader in TKOpenGl becomes MSL. Phong, PBR (metal-roughness), shadow map, post-process, ray-tracing kernels, picking. Either a manual rewrite or an automated path via spirv-cross / Naga.
- **Resource model**: GL buffers/textures → Metal `MTLBuffer`/`MTLTexture` with discrete heap management.
- **Render passes**: GL framebuffers → Metal `MTLRenderPassDescriptor`.
- **Command encoding**: Metal's modern explicit-encoder model has no GL equivalent — large architectural rewrite of the inner render loop.
- **Picking**: GPU-side ID buffer with Metal imageblock memory (Apple TBDR-friendly).
- **Selection BVH**: re-use `SelectMgr_/StdSelect_` from TKService unchanged.
- **Transparency**: depth-peeling implementation in Metal.
- **Ray tracing**: optional. MetalRT exists for hardware ray tracing; mapping from OCCT's `OpenGl_View::raytrace` is non-trivial.
- **Environment maps, FXAA, anisotropic textures, line stipple emulation**: lots of small features each requiring a Metal port.

### Effort estimate

Realistic range: **6–18 person-months** for a usable subset, **multi-year** for production parity with current TKOpenGl. Comparable porting efforts:

- **VTK WebGPU backend** (Kitware, 2024–): ongoing multi-year project, year 1 covered only polydata mappers; composite, glyph, volume, surface-LIC mappers still TBD.
- **Skia Metal backend**: Google has a dedicated team, took years to reach parity with the GL backend.
- **Filament**: ~2-year effort to ship Metal alongside GL/Vulkan, and Filament is a much smaller surface than OCCT's viz layer.

### Maintenance burden

OCCT releases land roughly twice yearly (8.0.0 in May 2026 after 7.9.x). Each release touches `TKOpenGl`. A downstream `TKMetal` would need to track those changes — an ongoing tax, not a one-shot.

### Pros / cons

**Pros**
- Full AIS surface preserved on Apple platforms including visionOS.
- Same OCCT app code runs cross-platform with platform-specific drivers.
- Upstream-friendly — could potentially be contributed back.

**Cons**
- Largest possible scope.
- Highest technical risk (Metal/GL architectural mismatch around resource state, command encoding).
- Locked into OCCT's release cadence for backports.

---

## Path B — Mesh-extraction + native Metal (current)

**Approach:** OCCTSwift extracts triangulation (`Mesh`, `Triangulation`, `Polygon3D`) from B-Rep shapes; OCCTSwiftViewport renders those meshes natively in Metal.

### What OCCTSwiftViewport already provides

From the README of `gsdali/OCCTSwiftViewport`:

- Metal renderer with Blinn-Phong shading, 3-light setup, shadow maps, environment mapping
- Camera systems: arcball / turntable / first-person, with inertia and animation
- ViewCube: 26-region clickable orientation widget
- GPU picking via TBDR imageblock-based pick ID buffer (body and face selection)
- Display modes: wireframe, shaded, shaded-with-edges
- Lighting presets: `.threePoint`, `.studio`, `.architectural`, `.flat`
- Gesture presets: `.default`, `.blender`, `.fusion360`
- Section / clip planes
- Distance, angle, radius measurement overlays
- Adaptive instanced dot grid + RGB axis lines
- Swift 6 `Sendable` conformance, `@MainActor` isolation
- iOS 18+ / macOS 15+

### What it doesn't do

- **No `AIS_InteractiveContext`-equivalent**: app code holds the `(Shape, ViewportBody)` mapping itself. When Metal picking returns a face ID, the app has to look up which `TopoDS_Face` of which `Shape` that came from.
- **No standard OCCT widgets**: `AIS_Trihedron`, `AIS_Manipulator`, `AIS_Plane`, `AIS_Axis`, `AIS_PointCloud`, dimension-annotation primitives — none of these exist as ready-made objects.
- **No ray-tracing renderer**: TKOpenGl has one; OCCTSwiftViewport currently rasterizes only.
- **No PBR material editor surface** (Blinn-Phong + light presets only).
- **No visionOS slice yet** — OCCTSwiftViewport currently builds for macOS 15 / iOS 18.

### Pros / cons

**Pros**
- Already shipped, working, low maintenance.
- Native Metal — clean visionOS path once the slice is added.
- No coupling to OCCT release cadence.
- Renders only what the app cares about; pure Apple stack.

**Cons**
- App code carries the topology-to-pick-id mapping.
- Standard CAD widgets (manipulators, dimensions, trihedrons) don't exist; each is an app-level project.

---

## Path C — AIS-bridge on OCCTSwiftViewport (recommended)

**Approach:** keep OCCT visualization OFF in the xcframework. Build the high-value parts of `AIS_InteractiveContext` as a Swift layer on top of `OCCTSwiftViewport`'s Metal renderer.

### What you'd build

A new product (call it `OCCTSwiftAIS`, sitting alongside `OCCTSwiftTools`):

```
Your App
  ├── OCCTSwift              (geometry kernel)
  ├── OCCTSwiftViewport      (Metal rendering, no OCCT)
  ├── OCCTSwiftTools         (Shape ↔ ViewportBody bridge)
  └── OCCTSwiftAIS           (NEW — AIS-equivalent layer)
        ├── InteractiveContext (selection / hover / highlight, topology-aware)
        ├── ManipulatorWidget  (translate / rotate gizmos in Metal)
        ├── DimensionAnnotation (linear / angular / radial overlays)
        ├── PresentationStyle  (highlighted, hover, dimmed, ghosted)
        └── Trihedron / Plane / Axis / PointCloud standard objects
```

Each of these is **pure Swift logic over already-extracted topology metadata + Metal rendering primitives provided by OCCTSwiftViewport**. The hard parts (vertex pipeline, lighting, shadow mapping, GPU picking) are already done; OCCTSwiftAIS adds the "this pick result is `topoFace[7]` of `shape[3]`, highlight it" semantics.

### Effort estimate

**1–3 person-months** for the headline features:

- `InteractiveContext` and selection-from-topology: 2–3 weeks
- Manipulator widget (translate/rotate, with snap): 2–3 weeks
- Dimension annotations (linear, angular, radial; placement, leader lines, labels): 3–4 weeks
- Standard objects (trihedron, plane, axis, point cloud): 1–2 weeks total
- Hover/highlight/ghost styling: 1 week
- Polish, docs, examples: 2 weeks

### Pros / cons

**Pros**
- Keeps the existing clean architecture (OCCTSwift = kernel, OCCTSwiftViewport = renderer).
- Native Metal everywhere, including visionOS once OCCTSwiftViewport adds the slice.
- Decoupled from OCCT release cadence — when OCCT 8.1 lands we don't have to re-port a Metal driver.
- Each feature is independently shippable; you can prioritise (selection first, manipulator second, dimensions third).

**Cons**
- Not source-compatible with `AIS_InteractiveContext`-using OCCT C++ apps. OK for our stack — we're Swift-first.
- Doesn't get OCCT's ray-tracing renderer for free. (Probably not needed for interactive CAD anyway.)
- Some duplication: the selection BVH logic in `SelectMgr_/StdSelect_` would have to be re-implemented in Swift on top of the topology metadata we already extract.

---

## Other paths considered and rejected

### Path D — MoltenVK + OCCT-Vulkan

Build an OCCT Vulkan backend, run on Apple via MoltenVK.

- **Blocker**: OCCT doesn't have a Vulkan backend. If we wrote one, we'd be doing Path A's effort for Vulkan instead of Metal — same scope, more dependencies.
- MoltenVK on visionOS is preview-class as of late 2025; production risk is high.
- Skip.

### Path E — ANGLE-Metal

Route TKOpenGl's GLES calls through Google's [ANGLE](https://github.com/google/angle) Metal backend.

- ANGLE Metal backend exists and is active (Apple/Google collaboration upstreaming WebKit's branch). MetalANGLE (the standalone fork) is unmaintained as of 2023.
- ANGLE supports GLES 3.0 mostly; **3.1+ not fully**. TKOpenGl uses GLES 3.0+ features.
- **No documented visionOS support** for either ANGLE or MetalANGLE.
- Performance penalty from translation layer.
- Skip unless OCCT picks this up officially — and they haven't.

### Path F — WebGPU (Dawn / wgpu)

Use WebGPU as the cross-platform abstraction (it sits over Metal, Vulkan, D3D12).

- VTK is doing this — multi-year effort. Apple Safari supports WebGPU.
- Same scope as Path A — replace TKOpenGl entirely with TKWebGPU.
- Doesn't avoid the work; just changes which abstraction we target.
- Interesting if we ever needed WebAssembly support; out of scope for an Apple-only Metal goal.
- Skip for now.

---

## Recommendation

| Question | Answer |
|---|---|
| Should we port TKOpenGl to TKMetal? | **No.** Multi-year, high-risk, mostly duplicates OCCTSwiftViewport. |
| Should we ship visionOS visualization support? | **Yes**, via OCCTSwiftViewport. Add the visionOS slice to that repo. |
| What's missing from our current stack vs. OCCT's `AIS_InteractiveContext`? | High-level scene objects, selection-from-topology mapping, manipulator widgets, dimension annotations. |
| What's the cheapest way to fill that gap? | **Path C** — `OCCTSwiftAIS` as a Swift layer on top of `OCCTSwiftViewport`. ~1–3 person-months. |

### Concrete next step (when ready)

When the user wants to start the AIS layer:

1. Create `OCCTSwiftAIS` repo (or a new product inside OCCTSwiftViewport, adjacent to `OCCTSwiftTools`).
2. Start with **selection-from-topology**: an `InteractiveContext` Swift API that takes a `Shape` + extracted `ViewportBody` and exposes `pickFace(at: CGPoint) -> TopoDS_Face?`-style queries via OCCTSwiftViewport's existing GPU picking buffer. This is the single highest-value missing piece.
3. Add **manipulator widget** next — biggest visible win for user-facing CAD apps.
4. Defer dimension annotations and standard-object widgets until there's a concrete consumer (e.g. `Unfolder` or `templotUX`) asking for them.

This path keeps our architecture clean, keeps OCCTSwift's xcframework at modeling-kernel-only (no GL dependency anywhere), and gives us full Apple platform reach including visionOS without a multi-year TKMetal project.

---

## Sources

- [OCCT visualization toolkit (TKV3d / TKService / TKOpenGl) docs](https://dev.opencascade.org/doc/refman/html/class_graphic3d___graphic_driver.html)
- [OCCT Forum — Future of OpenGL on Macs](https://dev.opencascade.org/content/future-opengl-macs) (Pasukhin Vulkan-roadmap quote)
- [OCCT Forum — Ray tracing as alternative rendering method](https://dev.opencascade.org/content/ray-tracing-alternative-rendering-method-occt-visualization-component)
- [OCCT GitHub — Open-Cascade-SAS/OCCT](https://github.com/Open-Cascade-SAS/OCCT) (no Vulkan PRs / Metal issues as of 2026-05-02)
- [Apple — OpenGL deprecation across all OSes (2018)](https://www.anandtech.com/show/12894/apple-deprecates-opengl-across-all-oses)
- [Apple Developer Forums — OpenGL on future iPhones and Macs](https://developer.apple.com/forums/thread/725247)
- [Hacker News — visionOS doesn't support OpenGL](https://news.ycombinator.com/item?id=43768863)
- [MoltenVK — Vulkan-on-Metal translation layer](https://github.com/KhronosGroup/MoltenVK)
- [ANGLE — Google's GL/GLES translation layer](https://github.com/google/angle) (Metal backend in active development with Apple)
- [MetalANGLE — unmaintained since 2023](https://github.com/kakashidinho/metalangle)
- [VTK WebGPU port — multi-year ongoing effort](https://www.kitware.com/vtk-webgpu-on-the-desktop/)
- [OCCTSwiftViewport — current Metal renderer](https://github.com/gsdali/OCCTSwiftViewport)
