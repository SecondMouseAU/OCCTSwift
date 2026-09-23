#!/bin/bash
#
# Build OpenCASCADE for WebAssembly (WASI)
#
# Usage: ./build-occt-wasm.sh
#
# This script downloads OCCT source and builds it as static libraries
# for wasm32-wasip1 using wasi-sdk.
# The result is a set of static libraries and headers at Libraries/OCCT-wasm/
#
# Prerequisites:
#   - the pinned wasm toolchain: run Scripts/install-wasm-toolchain.sh, which reads every version
#     from Scripts/wasm-toolchain-versions.txt and leaves wasi-sdk under Libraries/
#   - CMake 3.20+
#   - rapidjson (via system package manager or RAPIDJSON_DIR env)
#   - ~10GB free disk space, nearly all of it the OCCT build tree
#
# Build time: ~30-60 minutes depending on hardware
#

set -e

OCCT_VERSION="8.0.1"
OCCT_RC=""
# Pre-release tags use format V8.0.0-rc5 / V8.0.0-beta2 (with dash)
# GA releases use V8.0.1 (with dots)
if [ -n "$OCCT_RC" ]; then
    OCCT_TAG="V${OCCT_VERSION}-${OCCT_RC}"
else
    OCCT_TAG="V${OCCT_VERSION}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"

# Detect architecture and OS for wasi-sdk path
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    darwin) OS="macos" ;;
    linux)  OS="linux" ;;
esac

# --------------------
# Pinned toolchain versions
# --------------------
# Read, never restated: Scripts/wasm-toolchain-versions.txt is the single source of truth for every
# wasm version in the repo, and a literal here would be a copy with no update path. The same file
# is read by Scripts/install-wasm-toolchain.sh, which is what puts wasi-sdk where this script looks.
PINS_FILE="$SCRIPT_DIR/wasm-toolchain-versions.txt"
pin() {
    local key="$1" line
    while IFS= read -r line; do
        case "$line" in
            \#*|"") continue ;;
            "$key="*) printf '%s\n' "${line#*=}"; return 0 ;;
        esac
    done < "$PINS_FILE"
    echo "ERROR: $PINS_FILE has no '$key' line." >&2
    exit 1
}
if [ ! -f "$PINS_FILE" ]; then
    echo "ERROR: pinned versions file not found at '$PINS_FILE'." >&2
    exit 1
fi
WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"

# wasi-sdk location. Libraries/ is gitignored and already holds occt-src, so the toolchain sits
# beside the source it compiles; WASI_SDK_PREFIX overrides for an install kept elsewhere.
WASI_SDK_PREFIX="${WASI_SDK_PREFIX:-$LIBRARIES_DIR/wasi-sdk-${WASI_SDK_VERSION}-${ARCH}-${OS}}"
if [ ! -d "$WASI_SDK_PREFIX" ]; then
    echo "ERROR: wasi-sdk not found at '$WASI_SDK_PREFIX'." >&2
    echo "       Install the pinned toolchain, which puts it there:" >&2
    echo "         Scripts/install-wasm-toolchain.sh" >&2
    echo "       Or set WASI_SDK_PREFIX to an existing wasi-sdk $WASI_SDK_VERSION install." >&2
    exit 1
fi

# Parallelism (cross-platform)
JOBS=$(command -v nproc >/dev/null && nproc || sysctl -n hw.ncpu)

# rapidjson: check common locations (Homebrew, Linux package managers, pkg-config)
RAPIDJSON_DIR="${RAPIDJSON_DIR:-}"
if [ -z "$RAPIDJSON_DIR" ]; then
    if command -v brew >/dev/null 2>&1; then
        RAPIDJSON_DIR="$(brew --prefix rapidjson 2>/dev/null)/include"
    fi
fi
if [ -z "$RAPIDJSON_DIR" ] || [ ! -d "$RAPIDJSON_DIR" ]; then
    # Common Linux paths
    for candidate in \
        /usr/include/rapidjson \
        /usr/local/include/rapidjson \
        /opt/homebrew/include/rapidjson \
        /usr/include \
        /usr/local/include; do
        if [ -f "$candidate/rapidjson.h" ] || [ -f "$candidate/rapidjson/document.h" ]; then
            RAPIDJSON_DIR="$candidate"
            break
        fi
    done
fi
if [ -z "$RAPIDJSON_DIR" ] || [ ! -d "$RAPIDJSON_DIR" ]; then
    echo "ERROR: rapidjson headers not found." >&2
    echo "       Install rapidjson via package manager (brew, apt, dnf, pacman) or set RAPIDJSON_DIR." >&2
    exit 1
fi

# Libraries/ is gitignored in its entirety, so a clean checkout. CI, or anyone's first build,
# does not have it. Create it rather than `cd` into nothing.
mkdir -p "$LIBRARIES_DIR"
cd "$LIBRARIES_DIR"

# --------------------
# Download OCCT source
# --------------------

if [ ! -d "occt-src" ]; then
    echo ">>> Downloading OCCT source..."
    git clone --depth 1 --branch "$OCCT_TAG" \
        https://github.com/Open-Cascade-SAS/OCCT.git occt-src
else
    # Reuse the tree only when it is at the tag this script names.
    CURRENT_TAG="$(git -C occt-src describe --tags --exact-match HEAD 2>/dev/null || true)"
    if [ "$CURRENT_TAG" = "$OCCT_TAG" ]; then
        echo ">>> OCCT source already at $OCCT_TAG, skipping download"
    else
        echo "ERROR: $LIBRARIES_DIR/occt-src is at '${CURRENT_TAG:-an untagged commit ($(git -C occt-src rev-parse --short HEAD 2>/dev/null || echo 'not a git repo'))}'," >&2
        echo "       but this script builds $OCCT_TAG. Reusing it would build the wrong kernel." >&2
        echo "" >&2
        echo "       Check for work worth keeping first, anything not touched by a carried patch:" >&2
        echo "         git -C '$LIBRARIES_DIR/occt-src' status --porcelain" >&2
        echo "" >&2
        echo "       Then remove the tree and re-run, so the clone above fetches $OCCT_TAG:" >&2
        echo "         rm -rf '$LIBRARIES_DIR/occt-src'" >&2
        exit 1
    fi
fi

# --------------------
# Apply local OCCT patches (idempotent)
# --------------------
# TWO directories, and the split is deliberate.
#
# Scripts/patches/ holds the NNNN- numbered, upstream-bound bug fixes every platform carries.
# Scripts/patches-wasi/ holds WASI-only source changes, and ONLY this script applies them.
#
# They must not share a directory. build-occt.sh globs patches/*.patch with no filter, so a WASI
# patch left there is applied to the macOS, iOS and ThreadSanitizer kernels as well. Whether that
# fails loudly or lands silently depends on whether the patch happens to apply to the pinned
# source, which nothing measures, so treat it as silent.
# check-inventory-prose.py also parses each filename's first four characters as
# the patch number and raises on a non-numeric name, and both the kernel cache key and the TSan
# stamp hash patches/*.patch, so a WASI-only change would move them for no native-kernel reason.
apply_patch_dir() {
    local dir="$1" label="$2"
    [ -d "$dir" ] && ls "$dir"/*.patch >/dev/null 2>&1 || return 0
    echo ">>> Applying $label..."
    local p
    for p in "$dir"/*.patch; do
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
}

apply_patch_dir "$SCRIPT_DIR/patches" "carried OCCT patches"
apply_patch_dir "$SCRIPT_DIR/patches-wasi" "WASI-only OCCT patches"

# --------------------
# Clean stale install prefixes
# --------------------
rm -rf occt-install-wasm occt-build-wasm

# --------------------
# The std threading shim (#2170)
# --------------------
# The pinned SDK's libc++ is built with _LIBCPP_HAS_THREADS 0, which removes std::mutex,
# std::recursive_mutex, std::shared_mutex, std::shared_lock, std::condition_variable,
# std::this_thread::yield, std::cv_status and std::lock. 75 files across the four modules this
# script builds use them, fifteen of them files Scripts/patches/ already modifies.
#
# One -include supplies all of it, and NO OCCT source is patched for this class. A patch in
# Scripts/patches-wasi/ that touches any of those names is wrong by construction; edit the shim.
# The reasoning, the measurement and what the previous attempt cost are in
# docs/WASI_GUARD_SITES.md.
#
# It is force-included rather than reached through libc++'s own _LIBCPP_HAS_THREAD_API_EXTERNAL
# extension point because that one needs __config_site edited, and the sysroot's include/c++/v1 is
# searched ahead of any -I we could pass, so it cannot be shadowed from here.
WASI_THREADING_SHIM="$SCRIPT_DIR/wasm-shims/wasi-std-threading.hpp"
if [ ! -f "$WASI_THREADING_SHIM" ]; then
    echo "ERROR: the std threading shim is missing at '$WASI_THREADING_SHIM'." >&2
    echo "       Without it the build fails at the first std::mutex it meets, in one of 75 files." >&2
    echo "       See docs/WASI_GUARD_SITES.md; do not answer this by writing a patch." >&2
    exit 1
fi

# --------------------
# Common CMake options (minimal build for modeling + export)
# Same as build-occt.sh but for WASI
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
    -D3RDPARTY_RAPIDJSON_DIR="$RAPIDJSON_DIR"
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
    # Quoted inside the flag value so a checkout path containing a space still reaches the
    # compiler as one argument. CMake inserts this string into the build command verbatim.
    "-DCMAKE_CXX_FLAGS=-include \"$WASI_THREADING_SHIM\""
)

# --------------------
# Build for WASI (wasm32-wasip1)
# --------------------

echo ""
echo "========================================"
echo "Building OCCT $OCCT_VERSION for WASI (wasm32-wasip1)"
echo "========================================"
echo "Project directory: $PROJECT_DIR"
echo "Libraries directory: $LIBRARIES_DIR"
echo "Parallel jobs: $JOBS"
echo "wasi-sdk: $WASI_SDK_PREFIX"
echo ""

rm -rf occt-build-wasm
mkdir -p occt-build-wasm
cd occt-build-wasm

# wasi-sdk ships the CMake toolchain file for this target, one per WASI preview; p1 is ours.
# An earlier version of this script preferred a swift-wasi-sdk.cmake inside the prefix and treated
# wasi-sdk's own file as a fallback. No such file exists in either the wasi-sdk tarball or the
# Swift SDK's WASI.sdk, so that branch could never be taken.
WASI_TOOLCHAIN="$WASI_SDK_PREFIX/share/cmake/wasi-sdk-p1.cmake"
if [ ! -f "$WASI_TOOLCHAIN" ]; then
    echo "ERROR: no WASI CMake toolchain file at '$WASI_TOOLCHAIN'." >&2
    echo "       '$WASI_SDK_PREFIX' does not look like a wasi-sdk $WASI_SDK_VERSION install." >&2
    exit 1
fi

# Exception handling is not settled here. OCCT throws Standard_Failure pervasively, and the
# exception-enabled C++ runtime lives in $WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasip1/eh,
# not in the Swift SDK's sysroot; the compile flags that make it usable under the pinned runtime
# are WASM_CXX_EH_FLAGS in Scripts/wasm-toolchain-versions.txt. Which of those OCCT's own build
# needs is #2171's spike, so nothing is asserted in CMAKE_COMMON_OPTS above. See
# Scripts/repro/2169/README.md for what has actually been measured.

# --------------------
# Preflight: does the threading shim match the libc++ this toolchain selects? (#2170)
# --------------------
# The shim asserts _LIBCPP_HAS_THREADS == 0 and adds names to namespace std, so it is only
# defensible against a libc++ that really is missing them. That is a property of the SYSROOT, and
# the two sysroots in play disagree:
#
#   * the Swift SDK's WASI.sdk sets _LIBCPP_HAS_THREADS 0, which is what #2170 measured and what
#     the shim exists for;
#   * wasi-sdk 34.0's own wasm32-wasip1 sysroot sets it to 1, in both the eh and noeh flavours,
#     and supplies all eight names itself.
#
# Which one this build uses is decided by the toolchain file above and is #2172's open question.
# Without this check the mismatch surfaces as CMake's "the C++ compiler is not able to compile a
# simple test program", with the shim's own explanation buried in CMakeError.log.
# Read the compiler, triple and sysroot straight out of the toolchain file CMake is about to use,
# so the preflight asks the same libc++ the build will.
toolchain_setting() {
    local value
    value="$(sed -n "s/^[[:space:]]*set($1[[:space:]]\{1,\}\([^)]*\))[[:space:]]*\$/\1/p" "$WASI_TOOLCHAIN" | head -1)"
    value="${value%\"}"
    value="${value#\"}"
    value="${value//\$\{WASI_SDK_PREFIX\}/$WASI_SDK_PREFIX}"
    value="${value//\$\{WASI_HOST_EXE_SUFFIX\}/}"
    printf '%s' "$value"
}

PREFLIGHT_CXX=""
PREFLIGHT_TRIPLE=""
PREFLIGHT_SYSROOT=""
if [ -f "$WASI_TOOLCHAIN" ]; then
    PREFLIGHT_CXX="$(toolchain_setting CMAKE_CXX_COMPILER)"
    PREFLIGHT_TRIPLE="$(toolchain_setting triple)"
    PREFLIGHT_SYSROOT="$(toolchain_setting CMAKE_SYSROOT)"
fi
if [ -n "$PREFLIGHT_CXX" ] && [ -x "$PREFLIGHT_CXX" ]; then
    PREFLIGHT_SRC="$(mktemp -t occt-wasm-shim-preflight).cpp"
    printf '#include <version>\nint main() { return 0; }\n' > "$PREFLIGHT_SRC"
    PREFLIGHT_TARGET_OPT=()
    [ -n "$PREFLIGHT_TRIPLE" ] && PREFLIGHT_TARGET_OPT+=(--target="$PREFLIGHT_TRIPLE")
    [ -n "$PREFLIGHT_SYSROOT" ] && PREFLIGHT_TARGET_OPT+=(--sysroot="$PREFLIGHT_SYSROOT")
    if ! PREFLIGHT_OUT="$("$PREFLIGHT_CXX" "${PREFLIGHT_TARGET_OPT[@]}" -std=c++17 -fsyntax-only \
            -include "$WASI_THREADING_SHIM" "$PREFLIGHT_SRC" 2>&1)"; then
        rm -f "$PREFLIGHT_SRC"
        echo "ERROR: the std threading shim does not apply to the libc++ this toolchain selects." >&2
        echo "" >&2
        echo "  toolchain file: $WASI_TOOLCHAIN" >&2
        echo "  compiler:       $PREFLIGHT_CXX" >&2
        echo "" >&2
        printf '%s\n' "$PREFLIGHT_OUT" >&2
        echo "" >&2
        echo "       Two causes, and they want opposite fixes." >&2
        echo "" >&2
        echo "       1. This sysroot's libc++ HAS threads, so the eight names are already there and" >&2
        echo "          the shim is not merely unnecessary, it is a redefinition. wasi-sdk's own" >&2
        echo "          wasm32-wasip1 sysroot is in this category. Building OCCT against it while" >&2
        echo "          the Swift side links the Swift SDK's threadless libc++ is the mismatch" >&2
        echo "          #2172 exists to settle; do not paper over it by dropping the shim." >&2
        echo "" >&2
        echo "       2. The pinned Swift SDK itself gained threads. Then the shim has served its" >&2
        echo "          purpose: remove this preflight and the -include, and delete" >&2
        echo "          Scripts/wasm-shims/ and Scripts/repro/2170/." >&2
        exit 1
    fi
    rm -f "$PREFLIGHT_SRC"
    echo ">>> Threading shim preflight passed: $(basename "$WASI_THREADING_SHIM")"
else
    echo ">>> Threading shim preflight skipped: no CMAKE_CXX_COMPILER found in $WASI_TOOLCHAIN." >&2
    echo "    CMake will still apply the shim, and a mismatch will surface as a failed compiler" >&2
    echo "    check with the detail in CMakeError.log." >&2
fi

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_TOOLCHAIN_FILE="$WASI_TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-wasm

# Build libraries (fail on compilation errors)
cmake --build . --parallel "$JOBS"

# Install headers and static libraries
cmake --install .
cd ..

# --------------------
# Create combined libraries
# --------------------

echo ""
echo ">>> Creating combined static libraries..."

# Find all .a files (portable, handles spaces in paths)
static_libs=()
while IFS= read -r -d '' lib; do
    static_libs+=("$lib")
done < <(find occt-install-wasm -name "*.a" -print0 2>/dev/null)

if [ ${#static_libs[@]} -eq 0 ]; then
    echo "ERROR: No static libraries found in occt-install-wasm" >&2
    exit 1
fi

# Use llvm-ar from wasi-sdk (cross-platform)
AR_TOOL="$WASI_SDK_PREFIX/bin/llvm-ar"
if [ ! -x "$AR_TOOL" ]; then
    AR_TOOL="$(command -v llvm-ar || command -v ar)"
fi

# Build combined library incrementally to avoid ARG_MAX and overwriting issues
rm -f libOCCT-wasm.a
for lib in "${static_libs[@]}"; do
    "$AR_TOOL" rcs libOCCT-wasm.a "$lib"
done

if [ ! -f libOCCT-wasm.a ] || [ ! -s libOCCT-wasm.a ]; then
    echo "ERROR: Failed to create combined static library" >&2
    exit 1
fi

# --------------------
# Prepare headers
# --------------------

echo ""
echo ">>> Preparing headers..."

# Copy all headers (handles .h, .hxx, .inl) to a clean location
rm -rf occt-headers-wasm
mkdir -p occt-headers-wasm

while IFS= read -r -d '' header; do
    rel="${header#occt-install-wasm/}"
    dest="occt-headers-wasm/${rel}"
    mkdir -p "$(dirname "$dest")"
    cp "$header" "$dest"
done < <(find occt-install-wasm -type f \( -name "*.h" -o -name "*.hxx" -o -name "*.inl" \) -print0 2>/dev/null)

# Verify headers were copied
if [ -z "$(find occt-headers-wasm -type f \( -name "*.h" -o -name "*.hxx" -o -name "*.inl" \) 2>/dev/null | head -1)" ]; then
    echo "ERROR: No headers found in occt-headers-wasm after copy" >&2
    exit 1
fi

# --------------------
# Summary
# --------------------

echo ""
echo "========================================"
echo "WASI build complete!"
echo "========================================"
echo ""
echo "Static library created at:"
echo "  $LIBRARIES_DIR/libOCCT-wasm.a"
echo ""
echo "Headers at:"
echo "  $LIBRARIES_DIR/occt-headers-wasm/"
echo ""
echo "To use with SwiftPM for Wasm, add linker settings pointing to these artifacts."
echo ""

# Optionally clean up build directories to save space
# rm -rf occt-build-wasm occt-install-wasm occt-src