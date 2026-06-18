#!/bin/bash
#
# Build OpenCASCADE for iOS and macOS
#
# Usage: ./build-occt.sh
#
# This script downloads OCCT source and builds it as static libraries
# for iOS (arm64), iOS Simulator (arm64), and macOS (arm64).
# The result is an XCFramework at Libraries/OCCT.xcframework.
#
# Prerequisites:
#   - Xcode 15+ with Command Line Tools
#   - CMake 3.20+ (brew install cmake)
#   - ~10GB free disk space
#
# Build time: ~30-60 minutes depending on hardware
#

set -e

OCCT_VERSION="8.0.0"
OCCT_RC="p1"
# Pre-release tags use format V8_0_0_rc5 / V8_0_0_beta2; the p1 hot-patch is V8_0_0_p1; GA is V8_0_0.
if [ -n "$OCCT_RC" ]; then
    OCCT_TAG="V${OCCT_VERSION//./_}_${OCCT_RC}"
else
    OCCT_TAG="V${OCCT_VERSION//./_}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"

# Parallelism
JOBS=$(sysctl -n hw.ncpu)

# SDK paths
IOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)
XROS_SDK=$(xcrun --sdk xros --show-sdk-path)
XRSIM_SDK=$(xcrun --sdk xrsimulator --show-sdk-path)
TVOS_SDK=$(xcrun --sdk appletvos --show-sdk-path)
TVSIM_SDK=$(xcrun --sdk appletvsimulator --show-sdk-path)

# Compiler
CC=$(xcrun --find clang)
CXX=$(xcrun --find clang++)

echo "========================================"
echo "Building OCCT $OCCT_VERSION for iOS/macOS"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "Libraries directory: $LIBRARIES_DIR"
echo "Parallel jobs: $JOBS"
echo "iOS SDK: $IOS_SDK"
echo "Simulator SDK: $SIM_SDK"
echo "macOS SDK: $MACOS_SDK"
echo "visionOS SDK: $XROS_SDK"
echo "visionOS Simulator SDK: $XRSIM_SDK"
echo "tvOS SDK: $TVOS_SDK"
echo "tvOS Simulator SDK: $TVSIM_SDK"
echo ""

cd "$LIBRARIES_DIR"

# --------------------
# Download OCCT source
# --------------------

if [ ! -d "occt-src" ]; then
    echo ">>> Downloading OCCT source..."
    git clone --depth 1 --branch "$OCCT_TAG" \
        https://github.com/Open-Cascade-SAS/OCCT.git occt-src
else
    echo ">>> OCCT source already exists, skipping download"
fi

# --------------------
# Apply local OCCT patches (idempotent)
# --------------------
# Patches in Scripts/patches/ are upstream-bound bug fixes we carry until they
# ship in an OCCT release. Each is applied with -p1 relative to occt-src.
#   (none currently — the BRepFill_CompatibleWires polar-iterator guard, OCCTSwift
#    issue #176, shipped upstream in V8_0_0_p1, so its patch was removed.)
if compgen -G "$SCRIPT_DIR/patches/*.patch" > /dev/null; then
    echo ">>> Applying local OCCT patches..."
    for p in "$SCRIPT_DIR"/patches/*.patch; do
        if git -C occt-src apply --reverse --check "$p" 2>/dev/null; then
            echo "    already applied: $(basename "$p")"
        elif git -C occt-src apply --check "$p" 2>/dev/null; then
            git -C occt-src apply "$p"
            echo "    applied: $(basename "$p")"
        else
            echo "    ERROR: cannot apply $(basename "$p") cleanly" >&2
            exit 1
        fi
    done
fi

# --------------------
# Common CMake options (minimal build for modeling + export)
# --------------------

CMAKE_COMMON_OPTS=(
    -DBUILD_LIBRARY_TYPE=Static
    -DBUILD_MODULE_ApplicationFramework=OFF
    -DBUILD_MODULE_DataExchange=ON
    -DBUILD_MODULE_Draw=OFF
    -DBUILD_MODULE_FoundationClasses=ON
    -DBUILD_MODULE_ModelingAlgorithms=ON
    -DBUILD_MODULE_ModelingData=ON
    -DBUILD_MODULE_Visualization=OFF
    -DBUILD_SAMPLES_QT=OFF
    -DBUILD_DOC_Overview=OFF
    -DBUILD_PATCH=OFF
    -DUSE_FREETYPE=OFF
    -DUSE_FREEIMAGE=OFF
    -DUSE_RAPIDJSON=ON
    -D3RDPARTY_RAPIDJSON_DIR=/opt/homebrew/opt/rapidjson/include
    -DUSE_TBB=OFF
    -DUSE_VTK=OFF
    -DUSE_OPENGL=OFF
    -DUSE_GLES2=OFF
    -DUSE_D3D=OFF
    -DUSE_DRACO=OFF
    -DUSE_FFMPEG=OFF
    -DUSE_OPENVR=OFF
    -DUSE_XLIB=OFF
    -DUSE_TCL=OFF
    -DINSTALL_SAMPLES=OFF
    -DINSTALL_TEST_CASES=OFF
    -DINSTALL_DOC_Overview=OFF
    -DCMAKE_CXX_STANDARD=17
)

# --------------------
# Build for iOS Device using Unix Makefiles
# --------------------

echo ""
echo ">>> Building for iOS (arm64)..."
rm -rf occt-build-ios
mkdir -p occt-build-ios
cd occt-build-ios

# iOS-specific flags
IOS_FLAGS="-arch arm64 -isysroot $IOS_SDK -miphoneos-version-min=15.0 -fembed-bitcode-marker"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$IOS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$IOS_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-ios

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for iOS Simulator
# --------------------

echo ""
echo ">>> Building for iOS Simulator (arm64)..."
rm -rf occt-build-sim
mkdir -p occt-build-sim
cd occt-build-sim

# Simulator-specific flags
SIM_FLAGS="-arch arm64 -isysroot $SIM_SDK -miphonesimulator-version-min=15.0"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SIM_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$SIM_FLAGS" \
    -DCMAKE_CXX_FLAGS="$SIM_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-sim

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for macOS
# --------------------

echo ""
echo ">>> Building for macOS (arm64)..."
rm -rf occt-build-macos
mkdir -p occt-build-macos
cd occt-build-macos

# macOS-specific flags
MACOS_FLAGS="-arch arm64 -isysroot $MACOS_SDK -mmacosx-version-min=12.0"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_OSX_SYSROOT="$MACOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$MACOS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$MACOS_FLAGS" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-macos

# Build libraries (ignore executable link failures - we only need static libs)
cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for visionOS Device
# --------------------

echo ""
echo ">>> Building for visionOS (arm64)..."
rm -rf occt-build-xros
mkdir -p occt-build-xros
cd occt-build-xros

XROS_FLAGS="-arch arm64 -isysroot $XROS_SDK"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=visionOS \
    -DCMAKE_OSX_SYSROOT="$XROS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=1.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$XROS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$XROS_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_SIZEOF_VOID_P=8 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-xros || true

cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for visionOS Simulator
# --------------------

echo ""
echo ">>> Building for visionOS Simulator (arm64)..."
rm -rf occt-build-xrsim
mkdir -p occt-build-xrsim
cd occt-build-xrsim

XRSIM_FLAGS="-arch arm64 -isysroot $XRSIM_SDK"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=visionOS \
    -DCMAKE_OSX_SYSROOT="$XRSIM_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=1.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$XRSIM_FLAGS" \
    -DCMAKE_CXX_FLAGS="$XRSIM_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_SIZEOF_VOID_P=8 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-xrsim || true

cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for tvOS Device
# --------------------

echo ""
echo ">>> Building for tvOS (arm64)..."
rm -rf occt-build-tvos
mkdir -p occt-build-tvos
cd occt-build-tvos

TVOS_FLAGS="-arch arm64 -isysroot $TVOS_SDK"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=tvOS \
    -DCMAKE_OSX_SYSROOT="$TVOS_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$TVOS_FLAGS" \
    -DCMAKE_CXX_FLAGS="$TVOS_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_SIZEOF_VOID_P=8 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-tvos || true

cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Build for tvOS Simulator
# --------------------

echo ""
echo ">>> Building for tvOS Simulator (arm64)..."
rm -rf occt-build-tvsim
mkdir -p occt-build-tvsim
cd occt-build-tvsim

TVSIM_FLAGS="-arch arm64 -isysroot $TVSIM_SDK"

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_SYSTEM_NAME=tvOS \
    -DCMAKE_OSX_SYSROOT="$TVSIM_SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$TVSIM_FLAGS" \
    -DCMAKE_CXX_FLAGS="$TVSIM_FLAGS" \
    -DCMAKE_C_COMPILER_WORKS=TRUE \
    -DCMAKE_CXX_COMPILER_WORKS=TRUE \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_SIZEOF_VOID_P=8 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-tvsim || true

cmake --build . --parallel "$JOBS" || true
cmake --install . || true
cd ..

# --------------------
# Create combined libraries
# --------------------

echo ""
echo ">>> Creating combined static libraries..."

# Find all .a files and combine them
libtool -static -o libOCCT-ios.a occt-install-ios/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-ios.a $(find occt-install-ios -name "*.a")

libtool -static -o libOCCT-sim.a occt-install-sim/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-sim.a $(find occt-install-sim -name "*.a")

libtool -static -o libOCCT-macos.a occt-install-macos/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-macos.a $(find occt-install-macos -name "*.a")

libtool -static -o libOCCT-xros.a occt-install-xros/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-xros.a $(find occt-install-xros -name "*.a" 2>/dev/null) || true

libtool -static -o libOCCT-xrsim.a occt-install-xrsim/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-xrsim.a $(find occt-install-xrsim -name "*.a" 2>/dev/null) || true

libtool -static -o libOCCT-tvos.a occt-install-tvos/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-tvos.a $(find occt-install-tvos -name "*.a" 2>/dev/null) || true

libtool -static -o libOCCT-tvsim.a occt-install-tvsim/lib/*.a 2>/dev/null || \
libtool -static -o libOCCT-tvsim.a $(find occt-install-tvsim -name "*.a" 2>/dev/null) || true

# --------------------
# Prepare headers
# --------------------

echo ""
echo ">>> Preparing headers..."

# Copy headers to a clean location
rm -rf occt-headers
mkdir -p occt-headers
if [ -d "occt-install-ios/include/opencascade" ]; then
    cp -R occt-install-ios/include/opencascade/* occt-headers/
else
    cp -R occt-install-ios/include/* occt-headers/
fi

# --------------------
# Create XCFramework
# --------------------

echo ""
echo ">>> Creating XCFramework..."

rm -rf OCCT.xcframework

# Conditionally include each platform slice — visionOS / tvOS may have failed to build
# (e.g. missing OCCT patches for new SDKs); xcframework will skip absent / empty libs.
XCFW_ARGS=(
    -library libOCCT-ios.a -headers occt-headers
    -library libOCCT-sim.a -headers occt-headers
    -library libOCCT-macos.a -headers occt-headers
)
[ -s libOCCT-xros.a ]  && XCFW_ARGS+=(-library libOCCT-xros.a  -headers occt-headers)
[ -s libOCCT-xrsim.a ] && XCFW_ARGS+=(-library libOCCT-xrsim.a -headers occt-headers)
[ -s libOCCT-tvos.a ]  && XCFW_ARGS+=(-library libOCCT-tvos.a  -headers occt-headers)
[ -s libOCCT-tvsim.a ] && XCFW_ARGS+=(-library libOCCT-tvsim.a -headers occt-headers)

xcodebuild -create-xcframework "${XCFW_ARGS[@]}" -output OCCT.xcframework

# --------------------
# Cleanup
# --------------------

echo ""
echo ">>> Cleaning up temporary files..."

rm -f libOCCT-ios.a libOCCT-sim.a libOCCT-macos.a libOCCT-xros.a libOCCT-xrsim.a libOCCT-tvos.a libOCCT-tvsim.a
rm -rf occt-headers

# Optionally remove build directories (uncomment to save space)
# rm -rf occt-build-ios occt-build-sim occt-build-macos
# rm -rf occt-install-ios occt-install-sim occt-install-macos
# rm -rf occt-src

# --------------------
# Summary
# --------------------

echo ""
echo "========================================"
echo "Build complete!"
echo "========================================"
echo ""
echo "XCFramework created at:"
echo "  $LIBRARIES_DIR/OCCT.xcframework"
echo ""
echo "Contents:"
ls -la OCCT.xcframework/
echo ""
echo "To use in your project:"
echo "  1. Add OCCTSwift as a Swift Package dependency"
echo "  2. Or drag OCCT.xcframework into your Xcode project"
echo ""
