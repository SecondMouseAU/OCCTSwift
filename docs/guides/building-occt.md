---
title: Building OCCT
nav_order: 8
---

# Building OpenCASCADE for iOS/macOS

This guide explains how to build OCCT as static libraries for use with OCCTSwift.

## Prerequisites

- macOS 13+ (Ventura or later)
- Xcode 15+ with Command Line Tools
- CMake 3.20+ (`brew install cmake`)
- About 10GB free disk space (source + build)

## Quick Start

```bash
cd /path/to/OCCTSwift
./Scripts/build-occt.sh
```

This will:
1. Download OCCT 8.0.0-rc5 source from GitHub tag `V8_0_0_rc5`
2. Build for iOS (arm64) and iOS Simulator (arm64)
3. Build for macOS (arm64)
4. Create `Libraries/OCCT.xcframework` (~568MB with all 3 slices)

## Manual Build Steps

### 1. Download OCCT Source

```bash
cd /path/to/OCCTSwift/Libraries

# Clone from GitHub (recommended for RC releases)
git clone --depth 1 --branch V8_0_0_rc4 \
    https://github.com/Open-Cascade-SAS/OCCT.git occt-src

# Or for stable releases, use the official repo:
# git clone --depth 1 --branch V8_0_0 \
#     https://git.dev.opencascade.org/repos/occt.git occt-src
```

### 2. Configure CMake for iOS

Create a toolchain file `ios.toolchain.cmake`:

```cmake
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_ARCHITECTURES arm64)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)
set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

# Ensure we build static libraries
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# Find the iOS SDK
execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
```

### 3. Build for iOS Device

```bash
mkdir -p occt-build-ios && cd occt-build-ios

cmake ../occt-src \
    -DCMAKE_TOOLCHAIN_FILE=../ios.toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 4. Build for iOS Simulator

```bash
mkdir -p occt-build-sim && cd occt-build-sim

# Modify toolchain for simulator
cmake ../occt-src \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT=$(xcrun --sdk iphonesimulator --show-sdk-path) \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 5. Build for macOS

```bash
mkdir -p occt-build-macos && cd occt-build-macos

cmake ../occt-src \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_MODULE_Draw=OFF \
    -DBUILD_MODULE_Visualization=OFF \
    -DUSE_FREETYPE=OFF \
    -DUSE_FREEIMAGE=OFF \
    -DUSE_RAPIDJSON=OFF \
    -DUSE_TBB=OFF \
    -DUSE_VTK=OFF \
    -DUSE_OPENGL=OFF

cmake --build . --config Release --parallel $(sysctl -n hw.ncpu)
cmake --install .
```

### 6. Create XCFramework

```bash
# Combine all static libraries into single fat library per platform
# (OCCT produces many .a files, we need to combine them)

# For each platform, create combined library:
libtool -static -o libOCCT-ios.a \
    occt-install-ios/lib/*.a

libtool -static -o libOCCT-sim.a \
    occt-install-sim/lib/*.a

libtool -static -o libOCCT-macos.a \
    occt-install-macos/lib/*.a

# Create XCFramework
xcodebuild -create-xcframework \
    -library libOCCT-ios.a -headers occt-install-ios/include \
    -library libOCCT-sim.a -headers occt-install-sim/include \
    -library libOCCT-macos.a -headers occt-install-macos/include \
    -output OCCT.xcframework
```

## Required OCCT Modules

For OCCTSwift, we need these modules:

| Module | Purpose | Required |
|--------|---------|----------|
| TKernel | Core utilities | Yes |
| TKMath | Math primitives | Yes |
| TKG2d | 2D geometry | Yes |
| TKG3d | 3D geometry | Yes |
| TKGeomBase | Geometric entities | Yes |
| TKGeomAlgo | Geometric algorithms | Yes |
| TKBRep | B-Rep structures | Yes |
| TKTopAlgo | Topological algorithms | Yes |
| TKPrim | Primitives | Yes |
| TKShHealing | Shape repair | Yes |
| TKBO | Boolean operations | Yes |
| TKFillet | Fillet/chamfer | Yes |
| TKOffset | Offset/shell | Yes |
| TKMesh | Meshing | Yes |
| TKSTEP | STEP export | Yes |
| TKSTL | STL export | Yes |
| TKBinXCAF | Persistent storage | Optional |
| TKXCAF | Assembly framework | Optional |

## Build Options Explained

```cmake
# Disable modules we don't need
-DBUILD_MODULE_Draw=OFF          # Interactive test harness
-DBUILD_MODULE_Visualization=OFF # OpenGL visualization (using SceneKit instead)

# Disable optional dependencies
-DUSE_FREETYPE=OFF    # Font rendering (not needed)
-DUSE_FREEIMAGE=OFF   # Image loading (not needed)
-DUSE_RAPIDJSON=OFF   # JSON (not needed for core)
-DUSE_TBB=OFF         # Intel threading (iOS has GCD)
-DUSE_VTK=OFF         # VTK visualization (not needed)
-DUSE_OPENGL=OFF      # Direct OpenGL (using SceneKit)
```

## Troubleshooting

### "No CMAKE_CXX_COMPILER could be found"

Install Xcode Command Line Tools:
```bash
xcode-select --install
```

### Undefined symbols for architecture arm64

Make sure all libraries are built for the same architecture:
```bash
lipo -info libTKernel.a  # Should show: arm64
```

### Build fails with C++17 errors

Ensure CMake uses C++17:
```cmake
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
```

### Library too large

The full OCCT build can be 500MB+. To reduce size:

1. Build only required modules (see table above)
2. Strip debug symbols: `strip -S libOCCT.a`
3. Use `-Os` optimization: `-DCMAKE_CXX_FLAGS="-Os"`

### Simulator build fails

Ensure you're using the correct SDK:
```bash
xcrun --sdk iphonesimulator --show-sdk-path
```

## Verifying the Build

### Check library contents

```bash
# List symbols
nm -g OCCT.xcframework/ios-arm64/libOCCT.a | grep BRepPrimAPI

# Check architectures
lipo -info OCCT.xcframework/ios-arm64/libOCCT.a
```

### Test in Xcode

1. Create new iOS app project
2. Drag OCCT.xcframework into project
3. Add simple test code:

```objc
// In a .mm file
#include <BRepPrimAPI_MakeBox.hxx>

void testOCCT() {
    BRepPrimAPI_MakeBox box(10, 20, 30);
    TopoDS_Shape shape = box.Shape();
    // If this compiles and runs, OCCT is working
}
```

## Automated Build Script

The actual build script is at `Scripts/build-occt.sh`. It handles:

- Downloading OCCT source (GitHub for RCs, official repo for stable releases)
- Building for all 3 platforms with proper cross-compilation flags
- Combining 48 static libraries per platform into a single fat library
- Creating the XCFramework with 7,005 headers

To update the OCCT version, edit the variables at the top of the script:

```bash
OCCT_VERSION="8.0.1"
OCCT_RC=""          # Pre-release suffix (rc4, beta2, p1); empty for a GA tag like V8_0_1
```

Then **delete `Libraries/occt-src`**. The script reuses an existing tree only when its `HEAD` is at
the tag these variables name, and aborts otherwise. Editing the version without removing the tree
used to build the previous kernel silently and package it under the new version's number.

Make executable:
```bash
chmod +x Scripts/build-occt.sh
```

## Shipping a rebuild

A rebuild is normally triggered by a new patch in `Scripts/patches/`, and those are inert until the
xcframework is rebuilt from source, so "patch merged" and "patch shipped" are two separate events
(see `Scripts/patches/README.md`). The steps below are the second one.

**1. Confirm the patch set the build actually used.** The script prints one line per patch
(`applied` / `already applied` / `ERROR`); an `ERROR` aborts the build, and `already applied` is
normal whenever `occt-src` was patched by an earlier run or an override-link probe. Before trusting
it, check `occt-src` is *only* the pinned tag plus the carried patches, since a leftover diagnostic probe
from an investigation would otherwise be compiled into a release binary:

```bash
git -C Libraries/occt-src status --porcelain          # every path must be one a patch touches
for p in Scripts/patches/*.patch; do                 # absolute path: git -C resolves it relative to -C
  git -C Libraries/occt-src apply --reverse --check "$(pwd)/$p" \
    && echo "ok  $(basename "$p")" || echo "NOT APPLIED  $(basename "$p")"
done
```

**2. Confirm the objects are genuinely newer than the patched sources.** Each slice's build dir is
`rm -rf`'d and re-configured per run, so a normal run cannot go stale, but a *resumed* build can
(`CMakeCache.txt` bakes in the configuring checkout's absolute path, and the script's `|| true`
swallows the failure a mismatched path produces, leaving a fresh-timestamped but stale artifact).
Never trust the exit code alone:

```bash
stat -f '%Sm %N' Libraries/occt-src/src/.../ThePatchedFile.cxx
find Libraries/occt-build-macos -name 'ThePatchedFile.cxx.o' -exec stat -f '%Sm %N' {} \;
```

If a build is interrupted, resume the interrupted slice with `cmake --build <that build dir>`
followed by `cmake --install <that build dir>` **from the same checkout that configured it**. Do
not re-run `build-occt.sh`, which `rm -rf`s each slice's build dir before starting it.

**3. Prove the fix reached the binary.** Run the patch's own reproducer against the rebuilt
xcframework with **no** override-linked TUs, and re-check whatever "no behaviour change" evidence
the patch's `Scripts/repro/<issue>/README.md` recorded. Then a full `swift test`.

Pushing a commit that touches `Scripts/patches/**` also triggers `.github/workflows/
kernel-integration.yml` (#585), which rebuilds from source in CI and runs `swift test` against
that binary.

`ci.yml`'s macOS check resolves whatever `Package.swift` pins, so a patch newer than the pinned
asset makes that patch's own regression tests fail there. **Do not leave it in that state for a
whole release.** Reading `kernel-integration.yml` instead works for one PR, but the red accumulates:
during v2.0.0 seven suites were red at once for this reason, `build-and-test` was excluded from the
required checks because of it, and every reviewer had to merge on parity with the base branch rather
than on green. Publish a kernel pre-release and bump the pin instead.

**4. Package and pin.** The zip is the release asset; its checksum is what SwiftPM verifies.

```bash
cd Libraries && rm -f OCCT.xcframework.zip
zip -r -y -q OCCT.xcframework.zip OCCT.xcframework      # -y: keep symlinks as symlinks
swift package compute-checksum OCCT.xcframework.zip     # or: shasum -a 256
```

Then, in the release commit:

- `Package.swift`: bump **both** the OCCT `url:` (to the new tag) **and** `checksum:`, and extend
  the carried-patch comment above them to name the new patch. Missing either half leaves
  URL-resolving consumers on the old kernel while checkouts with a local `Libraries/` get the new
  one, silently.
- `docs/CHANGELOG.md`: add the new patch's issue number to the kernel-patch list on the
  `## Current:` line.
- Attach `OCCT.xcframework.zip` to the release for that tag, so the pinned `url:` resolves. The
  Release-verification workflow (`.github/workflows/release.yml`) runs on release *publish* and
  fails loudly on a 404 or checksum mismatch; re-run it via `workflow_dispatch` if the asset is
  replaced after publishing.

Between the rebuild and the release the two consumer paths diverge on purpose: this checkout and
every sibling repo path-depending on its `Libraries/OCCT.xcframework` get the new kernel
immediately, while anything resolving the remote `url:` stays on the previously released one.

### Mid-release: publish a `vX.Y.Z-kernel.N` pre-release

The divergence above is fine for a day. It is **not** fine for a whole release, because CI resolves
the remote `url:`, so every regression test asserting the new patch's fix fails there until the
release ships. During v2.0.0 that reached seven simultaneously red suites, got `build-and-test`
excluded from the required checks, and forced every reviewer to merge on parity with the base branch
instead of on green (#585).

So when a patch lands mid-release, do not wait for the release commit and do not tell people to read
`kernel-integration.yml` instead. Publish the kernel on its own:

```bash
gh release create vX.Y.Z-kernel.N --target <branch-head-sha> --prerelease \
    --title "vX.Y.Z-kernel.N: OCCT <tag> + N carried patches (kernel pre-release)" \
    --notes-file <notes>
gh release upload vX.Y.Z-kernel.N Libraries/OCCT.xcframework.zip
```

Then bump `url:`/`checksum:` on the branch, exactly as the release commit will later do again.

Three things this needs:

- **Verify provenance before publishing**, using steps 1 to 3 above. A local build directory is not
  evidence on its own: `occt-src` must be at exactly the pinned tag, every carried patch must
  reverse-apply, and `git -C Libraries/occt-src status --porcelain` must list *only* files a patch
  touches, or an investigation probe ships inside a public binary.
- **`release.yml` must not run on it.** It checks out the tag and builds, but a kernel pre-release is
  published *before* the commit that pins it, by construction, so the tag still carries the old pin
  and the run fails for a reason unrelated to the artifact. The workflow is gated on
  `!github.event.release.prerelease` for this reason.
- **Do not delete the pre-release afterwards.** Every commit in the release window pins it, so
  deleting it takes its asset with it and makes those commits unbuildable from a clean checkout,
  which breaks `git bisect` and any historical re-measurement. Release storage is cheap; the
  bisectability is not.

## Alternative: Pre-built Binaries

If you don't want to build OCCT yourself:

1. **This package's own release asset**: the normal path, and the one that carries our patches.
   `OCCT.xcframework.zip` is attached to each release that rebuilt the kernel, and `Package.swift`
   resolves it by `url:`/`checksum:` automatically on any checkout with no local `Libraries/`. The
   rebuild itself is the manual local run documented above; `kernel-integration.yml` (#585) builds
   from source too, but only to validate a carried patch in CI before release, not to produce the
   shipped release asset.
2. **Open Cascade Commercial**: Contact sales@opencascade.com for pre-built iOS libraries
3. **Community Builds**: Check OCCT forum for community-provided builds
