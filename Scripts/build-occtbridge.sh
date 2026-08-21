#!/bin/bash
#
# Build a prebuilt OCCTBridge.xcframework (the compiled Objective-C++ bridge)
# beside OCCT.xcframework.
#
# Usage: ./build-occtbridge.sh
#
# Why this exists (#339): OCCTBridge is 16 .mm files / ~62K lines of
# Objective-C++, each including the OCCT header tree. SwiftPM recompiles all
# 16 from source on every consumer that depends on OCCTSwift by path (the
# ecosystem's shared-xcframework setup, see Scripts/build-occt.sh), measured
# at 51.6s wall / 186.5s CPU per rebuild in one consumer worktree. This script
# compiles the bridge once per platform slice and packages it exactly like
# OCCT.xcframework, so Package.swift can offer a prebuilt OCCTBridge binaryTarget
# as an opt-in alternative to compiling from source.
#
# Prerequisites:
#   - Libraries/OCCT.xcframework already built (Scripts/build-occt.sh), this
#     script links against its headers, it does not build OCCT itself.
#   - Xcode 15+ with Command Line Tools
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"
BRIDGE_SRC_DIR="$PROJECT_DIR/Sources/OCCTBridge/src"
BRIDGE_INCLUDE_DIR="$PROJECT_DIR/Sources/OCCTBridge/include"
OCCT_XCFRAMEWORK="$LIBRARIES_DIR/OCCT.xcframework"

if [ ! -d "$OCCT_XCFRAMEWORK" ]; then
    echo "ERROR: $OCCT_XCFRAMEWORK not found, run Scripts/build-occt.sh first." >&2
    exit 1
fi

# Same slice-selection convention as build-occt.sh: core slices (macOS, iOS
# device, iOS simulator) by default; BUILD_ALL_PLATFORMS=1 also builds
# visionOS / tvOS if OCCT.xcframework has those slices' headers.
BUILD_ALL_PLATFORMS="${BUILD_ALL_PLATFORMS:-0}"

CC=$(xcrun --find clang)
JOBS=$(sysctl -n hw.ncpu)

MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
XROS_SDK=$(xcrun --sdk xros --show-sdk-path 2>/dev/null || true)
XRSIM_SDK=$(xcrun --sdk xrsimulator --show-sdk-path 2>/dev/null || true)
TVOS_SDK=$(xcrun --sdk appletvos --show-sdk-path 2>/dev/null || true)
TVSIM_SDK=$(xcrun --sdk appletvsimulator --show-sdk-path 2>/dev/null || true)

echo "========================================"
echo "Building OCCTBridge.xcframework"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "Parallel jobs: $JOBS"
echo ""

cd "$LIBRARIES_DIR"
rm -rf occtbridge-build
mkdir -p occtbridge-build
cd occtbridge-build

# Each row: <slice dir under OCCT.xcframework> <clang -target triple> <sysroot> <output lib name>
SLICES=(
    "macos-arm64|arm64-apple-macosx12.0|$MACOS_SDK|libOCCTBridge-macos.a"
    "ios-arm64|arm64-apple-ios15.0|$IOS_SDK|libOCCTBridge-ios.a"
    "ios-arm64-simulator|arm64-apple-ios15.0-simulator|$SIM_SDK|libOCCTBridge-sim.a"
)
if [ "$BUILD_ALL_PLATFORMS" = "1" ]; then
    SLICES+=(
        "xros-arm64|arm64-apple-xros1.0|$XROS_SDK|libOCCTBridge-xros.a"
        "xros-arm64-simulator|arm64-apple-xros1.0-simulator|$XRSIM_SDK|libOCCTBridge-xrsim.a"
        "tvos-arm64|arm64-apple-tvos15.0|$TVOS_SDK|libOCCTBridge-tvos.a"
        "tvos-arm64-simulator|arm64-apple-tvos15.0-simulator|$TVSIM_SDK|libOCCTBridge-tvsim.a"
    )
fi

BUILT_LIBS=()

for entry in "${SLICES[@]}"; do
    IFS='|' read -r SLICE_DIR TARGET_TRIPLE SDK OUT_LIB <<< "$entry"
    OCCT_HEADERS="$OCCT_XCFRAMEWORK/$SLICE_DIR/Headers"

    if [ -z "$SDK" ] || [ ! -d "$OCCT_HEADERS" ]; then
        echo ">>> Skipping $SLICE_DIR (SDK or OCCT headers not available)"
        continue
    fi

    echo ""
    echo ">>> Compiling OCCTBridge for $SLICE_DIR ($TARGET_TRIPLE)..."
    OBJ_DIR="obj-$SLICE_DIR"
    rm -rf "$OBJ_DIR"
    mkdir -p "$OBJ_DIR"

    # Flags mirror SwiftPM's own OCCTBridge target invocation exactly (captured via
    # `swift build -c release --target OCCTBridge -v`): ARC on, C++17, the same
    # header search paths and OCCT_AVAILABLE / OCCT_NO_DEPRECATED defines as
    # Package.swift's cxxSettings.
    # 16 source files, small enough to launch all at once (no need for a job cap;
    # the macOS default /bin/bash is 3.2 and has no `wait -n`, so exit codes are
    # collected per-PID instead of via `wait` with no args, which would swallow
    # a failed compile under `set -e`).
    PIDS=()
    for src in "$BRIDGE_SRC_DIR"/*.mm; do
        base=$(basename "$src" .mm)
        "$CC" \
            -fobjc-arc -fblocks -fPIC \
            -target "$TARGET_TRIPLE" \
            -isysroot "$SDK" \
            -O2 -std=c++17 \
            -I "$BRIDGE_INCLUDE_DIR" \
            -I "$OCCT_HEADERS" \
            -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED \
            -c "$src" -o "$OBJ_DIR/$base.o" &
        PIDS+=($!)
    done
    FAILED=0
    for pid in "${PIDS[@]}"; do
        wait "$pid" || FAILED=1
    done
    if [ "$FAILED" -ne 0 ]; then
        echo "ERROR: one or more OCCTBridge sources failed to compile for $SLICE_DIR" >&2
        exit 1
    fi

    echo ">>> Archiving $OUT_LIB..."
    libtool -static -o "$OUT_LIB" "$OBJ_DIR"/*.o
    BUILT_LIBS+=("$OUT_LIB")
done

if [ ${#BUILT_LIBS[@]} -eq 0 ]; then
    echo "ERROR: no OCCTBridge slices were built." >&2
    exit 1
fi

# --------------------
# Headers (platform-agnostic, same public header for every slice)
# --------------------
rm -rf bridge-headers
mkdir -p bridge-headers
cp "$BRIDGE_INCLUDE_DIR"/OCCTBridge.h "$BRIDGE_INCLUDE_DIR"/module.modulemap bridge-headers/

# --------------------
# Create XCFramework
# --------------------
echo ""
echo ">>> Creating XCFramework..."
rm -rf "$LIBRARIES_DIR/OCCTBridge.xcframework"

XCFW_ARGS=()
for lib in "${BUILT_LIBS[@]}"; do
    XCFW_ARGS+=(-library "$lib" -headers bridge-headers)
done

xcodebuild -create-xcframework "${XCFW_ARGS[@]}" -output "$LIBRARIES_DIR/OCCTBridge.xcframework"

cd "$LIBRARIES_DIR"
rm -rf occtbridge-build

echo ""
echo "========================================"
echo "Build complete!"
echo "========================================"
echo ""
echo "XCFramework created at:"
echo "  $LIBRARIES_DIR/OCCTBridge.xcframework"
echo ""
echo "Contents:"
ls -la OCCTBridge.xcframework/
echo ""
echo "To use it, build with OCCTSWIFT_BRIDGE_PREBUILT=1 (see Package.swift)."
