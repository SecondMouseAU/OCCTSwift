# Prebuilt OCCTBridge (opt-in)

> **Disabled on the v2.0.0 line.** `Package.swift` currently forces the source build and ignores
> `OCCTSWIFT_BRIDGE_PREBUILT` entirely. Nearly every issue in the 2.0.0 queue edits
> `Sources/OCCTBridge/src/*.mm`, and a prebuilt that predates the edit links silently and reports a
> pass for code that was never compiled. The OCCT 8.0.1 absorb hit exactly that. Everything below
> describes the mechanism and applies again once the switch is restored in the release commit.

`OCCTBridge` is 16 Objective-C++ files, ~62K lines, wrapping the OCCT header tree. By default
SwiftPM compiles it from source on every consumer build. Since every `.mm` translation unit
includes a large slice of OCCT's ~1,700 headers, this dominates rebuild time in any consumer
that depends on OCCTSwift by local path (the ecosystem's [shared-xcframework
setup](sharing-the-xcframework.md)) — measured at 51.6s wall / 186.5s CPU per rebuild in one
consumer worktree (#339).

`Scripts/build-occtbridge.sh` compiles the bridge once per platform slice and packages it as
`OCCTBridge.xcframework`, exactly like `OCCT.xcframework`. Set **`OCCTSWIFT_BRIDGE_PREBUILT=1`**
to have `Package.swift` link the prebuilt binary instead of compiling from source.

## Quick start

```bash
# Build OCCTBridge.xcframework locally (requires Libraries/OCCT.xcframework already built)
./Scripts/build-occtbridge.sh

# Build OCCTSwift against it
OCCTSWIFT_BRIDGE_PREBUILT=1 swift build
```

Without the local `Libraries/OCCTBridge.xcframework`, setting the env var falls back to the
matching release asset (`OCCTBridge.xcframework.zip`, same tag as the pinned `OCCT.xcframework`
URL in `Package.swift`) — no local build step needed for a plain consumer.

## Why the default stays source

Every OCCTSwift release edits `Sources/OCCTBridge/src/*.mm` directly (new bridge functions), then
runs `swift build` / `swift test` against those edits (see the Release Process in `CLAUDE.md`). A
prebuilt binary that silently doesn't reflect those edits would be a correctness trap — `swift
build` would succeed against stale code with no warning. So **source remains the default**; the
prebuilt path is strictly opt-in, for consumers who aren't editing the bridge.

## Coverage

The prebuilt xcframework covers the same **core slices** as `OCCT.xcframework`: macOS
(arm64), iOS device (arm64), iOS simulator (arm64). visionOS / tvOS consumers should leave
`OCCTSWIFT_BRIDGE_PREBUILT` unset (source build), or rebuild the prebuilt locally with
`BUILD_ALL_PLATFORMS=1 ./Scripts/build-occtbridge.sh` (requires `OCCT.xcframework` to also have
been built with `BUILD_ALL_PLATFORMS=1`).

## Publishing a new prebuilt bridge

Whenever `Sources/OCCTBridge/src/*.mm` or `Sources/OCCTBridge/include/*` changes and you want the
prebuilt asset to track it:

1. `./Scripts/build-occtbridge.sh` — regenerates `Libraries/OCCTBridge.xcframework`.
2. `cd Libraries && rm -f OCCTBridge.xcframework.zip && zip -rq OCCTBridge.xcframework.zip OCCTBridge.xcframework`
3. `swift package compute-checksum /tmp/OCCTBridge.xcframework.zip` (copy to `/tmp` first — SPM
   requires the checksummed file to be outside the package directory).
4. Update the `url` (tag) and `checksum` in `Package.swift`'s `occtBridgeTarget`.
5. Attach `OCCTBridge.xcframework.zip` to the matching GitHub release (same tag as the URL).

This mirrors the existing `OCCT.xcframework` release workflow — see
[Sharing the xcframework](sharing-the-xcframework.md) and `docs/CHANGELOG.md` for the
`OCCT.xcframework` version of the same steps.
