---
nav_exclude: true
search_exclude: true
---

# Platform expansion review

This doc captures the analysis of expanding OCCTSwift beyond Apple platforms (Linux, Windows, Android). Written for v0.166.1 to inform the v1.0+ platform decision; not a commitment.

## Current state

OCCTSwift ships as a Swift package whose `OCCT` target is a `binaryTarget` pointing at `Libraries/OCCT.xcframework`. The xcframework today contains three slices:

- `macos-arm64` (macOS 12+, Apple Silicon)
- `ios-arm64` (iOS 15+ device)
- `ios-arm64-simulator` (iOS 15+ Simulator on Apple Silicon hosts)

The Swift Package Manager `binaryTarget` mechanism is **Apple-only**. There is no equivalent for Linux/Windows/Android binaries. Adding any of those three platforms requires both (a) a different distribution mechanism and (b) source-level changes to the OCCTBridge target.

## Engineering blockers (apply equally to all three)

### 1. OCCTBridge is Objective-C++, not pure C++

`Sources/OCCTBridge/src/OCCTBridge.mm` (~57k lines) uses the `.mm` extension. The Swift toolchains for Linux, Windows, and Android **do not compile Objective-C++**. To ship on any non-Apple platform, the bridge needs to be either:

- Renamed `.cpp` and audited for Objective-C-isms (NSString, `@try/@catch`, `NSObject`, etc.), or
- Conditionally compiled with `#ifdef __APPLE__` / `__OBJC__` guards.

A spot check (grep for `NSString`, `NSObject`, `@try`, `@selector`) suggests the file is mostly pure C++ that just happens to live in a `.mm` — promising but not free. Estimated effort: 3–5 days of audit + targeted edits.

### 2. Build pipeline is macOS-only

`Scripts/build-occt.sh` uses `xcrun`, `xcodebuild --create-xcframework`, and `sysctl`. It does not work on Linux/Windows/Android. Each new platform needs its own build script (or a unified CMake setup with platform detection):

- **Linux**: `cmake + gcc/clang` against the OS toolchain. OCCT has first-class Linux support, so this is the easiest of the three.
- **Windows**: `cmake + MSVC` (or clang-cl). OCCT has first-class Windows support but the Swift package needs to talk to MSVC-built static libraries, which means matching the Swift/Windows ABI carefully.
- **Android**: `cmake + Android NDK`. OCCT does not officially support Android but the codebase compiles for it with NDK r21+ in practice; expect to patch a small number of files.

### 3. SPM doesn't `binaryTarget` non-Apple binaries

A working OCCTSwift on Linux needs the Linux `.a` and headers exposed to the Swift compiler. SPM offers `systemLibrary` (uses pkg-config) and source-built C/C++ targets — neither matches our "ship a pre-built binary as a release asset" pattern for Apple. Options per platform:

- **Linux**: vendored sources OR pre-built `.a` checked into a release asset that downstream consumers download via a build-time script. Not idiomatic; downstream friction.
- **Windows**: same as Linux; expect more friction because Swift Windows tooling is younger.
- **Android**: more complex; Android Swift packaging is itself in flux (still preview-class as of late 2025/early 2026, even with Apple's official support push). Distribution would likely require a Gradle wrapper.

### 4. Test infrastructure

Today's 1,176 test suites run only on macOS. Each new platform needs:

- A CI matrix entry (GitHub Actions Linux / Windows / macOS-with-Android-NDK).
- A path that can run `swift test` on that platform (Android tests need an emulator or device).
- Acceptance that some tests will be macOS-only (anything that touches `Foundation` features missing on `swift-corelibs-foundation`).

## Per-platform assessment

### Linux

**Risk: low.** Best candidate.

- Swift on Linux is officially supported, mature.
- OCCT itself is most-tested on Linux.
- `swift-corelibs-foundation` covers most of what we need; gaps are in date formatting, regex, and rare URL APIs — none of which OCCTSwift uses heavily.
- Use cases: headless server-side CAD processing (STEP/IGES conversion pipelines, GLTF exports for web), CI for downstream apps that target Linux servers.
- Effort: ~1–2 weeks for first green CI run, mostly bridge audit + Linux build script + GitHub Actions wiring.

### Windows

**Risk: medium.** Tractable but fiddlier.

- Swift on Windows is officially supported (swift.org distributes installers) but ecosystem packages don't all build cleanly; expect some patching.
- OCCT builds and ships on Windows in commercial use.
- The Swift–MSVC ABI bridge is the main concern: linking a static library compiled with MSVC into a Swift executable requires care around C++ ABI (libc++ vs MSVC STL).
- Use cases: CAD desktop apps that want a Swift backend, integration with Windows-native engineering tooling.
- Effort: ~2–3 weeks. The blocker risk is debugging linker issues that don't reproduce on macOS.

### Android

**Risk: high.** Don't commit until Apple's official Swift-on-Android support stabilizes.

- Swift on Android is in active development with Apple's official Android Working Group push (2025+), but as of writing it's still preview-class. Tooling, packaging conventions, and the standard library surface on Android are all in flux.
- OCCT on Android is unofficial but works with NDK r21+ patches.
- Distribution is the hardest piece: Android consumers expect AAR/JAR-style packaging, which doesn't map naturally to SwiftPM. A practical answer is a Gradle wrapper that pulls in Swift via a custom toolchain — that's its own engineering project.
- Use cases: mobile CAD/AR apps. Niche but growing.
- Effort: ~4+ weeks of speculative work, plus ongoing churn while Swift-on-Android stabilizes.

## Recommendation

For OCCTSwift v1.0.0–v1.x:

1. **Ship Apple-only.** macOS arm64 + iOS device + iOS sim + visionOS device + visionOS sim is a clean v1.0.0 surface.
2. **Linux is the strongest non-Apple candidate.** If we add any non-Apple platform, do Linux first — server-side CAD processing has real demand and Linux is the lowest-risk port. Target a v1.1 or v1.2.
3. **Windows is a v1.x candidate** if a downstream user (or one of the gsdali sibling repos) actually needs it. Don't speculatively port.
4. **Android: revisit in 12 months.** Wait for Swift-on-Android packaging to settle before committing engineering time.

The realistic blast radius of a Linux port alone (build script, bridge audit, CI matrix entry, distribution shim) is ~2 weeks of focused work that delivers genuine value. Windows and Android are 2–4× that with much higher uncertainty — better deferred until a concrete consumer materializes.

## Prerequisite that lands first

Whichever non-Apple platform we pursue first, the first concrete step is the **OCCTBridge .mm → .cpp audit**. That's a self-contained, low-risk task whose result is independently useful (the bridge becomes more portable even if we never ship beyond Apple). It can be done as a pre-1.0 patch release without committing to any specific port.
