#!/bin/bash
#
# Build OpenCASCADE for WebAssembly (WASI)
#
# Usage: ./build-occt-wasm.sh [--toolkit NAME] [--require-complete]
#
#   --toolkit NAME   Build and archive ONE OCCT toolkit instead of everything, e.g.
#                    `--toolkit TKernel`. The configure step is unchanged, so the narrow loop and
#                    the full build share a build tree and a cache; only the build target and the
#                    packaging step differ. This exists because the full build is 30-60 minutes and
#                    a platform-porting loop that long gets tested by guessing. It also builds with
#                    `-k`, so one pass reports EVERY file that fails rather than stopping at the
#                    first, which is the difference between a complete guard-site list and a list
#                    discovered one error at a time (#2172).
#
#   --require-complete  Fail unless EVERY source file of that toolkit compiled. Requires
#                    --toolkit, because the full build has no `-k` and stops at the first error
#                    already, and per #2098 a check that examines nothing must fail rather than
#                    pass. Without it the count below is printed and not checked, and the exit
#                    status is whatever the build tool returned: that was the right behaviour
#                    while eight failures were the expected result of #2172, and the wrong one
#                    from #2173 onwards, when a regression would hand a reader the same status a
#                    complete build does. Turn it on wherever the build is expected to be
#                    complete; Scripts/repro/2173/run.sh does.
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

# --------------------
# Arguments
# --------------------
BUILD_TOOLKIT=""
REQUIRE_COMPLETE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --require-complete)
            REQUIRE_COMPLETE="1"
            shift
            ;;
        --toolkit)
            [ $# -ge 2 ] || { echo "ERROR: --toolkit needs a toolkit name, e.g. --toolkit TKernel." >&2; exit 1; }
            BUILD_TOOLKIT="$2"
            shift 2
            ;;
        --toolkit=*)
            BUILD_TOOLKIT="${1#--toolkit=}"
            shift
            ;;
        -h|--help)
            sed -n '2,38p' "$0"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument '$1'. Usage: $0 [--toolkit NAME] [--require-complete]" >&2
            exit 1
            ;;
    esac
done

if [ -n "$REQUIRE_COMPLETE" ] && [ -z "$BUILD_TOOLKIT" ]; then
    echo "ERROR: --require-complete needs --toolkit." >&2
    echo "       The full build runs without \`-k\` under \`set -e\`, so it already stops at the" >&2
    echo "       first file that does not compile and there is no partial state for this flag to" >&2
    echo "       reject. Accepting it here would be a check that examines nothing (#2098)." >&2
    exit 1
fi

OCCT_VERSION="8.0.1"
OCCT_RC=""
# Underscores, not dots, matching Scripts/build-occt.sh. Upstream carries BOTH V8.0.1 and V8_0_1
# and they are the same commit, so the clone worked either way; `git describe --tags
# --exact-match` resolves the underscore spelling, so the dotted form here made the reuse check
# below reject every tree this script had itself cloned, on every second run. The two scripts
# building the same kernel must also name it the same way.
if [ -n "$OCCT_RC" ]; then
    OCCT_TAG="V${OCCT_VERSION//./_}_${OCCT_RC}"
else
    OCCT_TAG="V${OCCT_VERSION//./_}"
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
SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
WASM_CXX_EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"

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

# --------------------
# The Swift toolchain and the Swift SDK's WASI sysroot (#2172)
# --------------------
# OCCT is compiled against the SWIFT SDK's WASI.sdk, with the swift.org toolchain's clang, and
# wasi-sdk contributes exactly one thing: the exception-enabled libc++abi and libunwind in its
# lib/wasm32-wasip1/eh directory. Why, and what was measured, is in Scripts/cmake/wasi-swift-sdk.cmake
# and docs/wasm-feasibility.md. The short form: the two sysroots disagree about _LIBCPP_HAS_THREADS
# and are two libc++ major versions apart, and the Swift side links WASI.sdk's copy either way.
SWIFT_TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-${SWIFT_TOOLCHAIN_VERSION}.xctoolchain/usr/bin}"
if [ ! -x "$SWIFT_TOOLCHAIN_BIN/clang++" ]; then
    echo "ERROR: no swift.org toolchain clang++ at '$SWIFT_TOOLCHAIN_BIN/clang++'." >&2
    echo "       Install Swift $SWIFT_TOOLCHAIN_VERSION from swift.org, or set SWIFT_TOOLCHAIN_BIN." >&2
    echo "       Xcode's toolchain is not a substitute: it has no wasm-ld." >&2
    exit 1
fi

# The Swift SDK is installed with `swift sdk install`, which unpacks the artifact bundle under
# ~/.swiftpm/swift-sdks (or SWIFTPM_HOME). `swift sdk configure --show-configuration` reports paths
# only for SDKs that have been reconfigured, so the layout is resolved directly.
SWIFT_SDKS_DIR="${SWIFT_SDKS_DIR:-$HOME/.swiftpm/swift-sdks}"
SWIFT_WASI_SYSROOT="${SWIFT_WASI_SYSROOT:-$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}/WASI.sdk}"
if [ ! -f "$SWIFT_WASI_SYSROOT/include/c++/v1/__config_site" ]; then
    echo "ERROR: the Swift wasm SDK's WASI sysroot is not at '$SWIFT_WASI_SYSROOT'." >&2
    echo "       Install the pinned SDK, which puts it there:" >&2
    echo "         Scripts/install-wasm-toolchain.sh" >&2
    echo "       Or set SWIFT_WASI_SYSROOT to an existing $SWIFT_WASM_SDK_ID install." >&2
    exit 1
fi

# wasi-sdk's exception-enabled C++ runtime. Not used to compile anything; it is where the link step
# (#2174) gets __cxa_throw, which WASI.sdk's libc++abi.a does not define.
WASI_SDK_EH_LIBDIR="$WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasip1/eh"
if [ ! -f "$WASI_SDK_EH_LIBDIR/libc++abi.a" ]; then
    echo "ERROR: wasi-sdk's exception-enabled runtime is not at '$WASI_SDK_EH_LIBDIR'." >&2
    echo "       This build needs its libc++abi.a and libunwind.a; the Swift SDK ships neither." >&2
    exit 1
fi

# The wasm32 compiler-rt builtins ship inside the Swift SDK bundle rather than in the swift.org
# toolchain, so the link step has to be told where they are. Compiling and archiving does not need
# them, which is why a missing directory is a note and not an error.
WASI_SWIFT_BUILTINS_DIR="${WASI_SWIFT_BUILTINS_DIR:-$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}/swift.xctoolchain/usr/lib/clang/lib/wasip1}"
if [ ! -d "$WASI_SWIFT_BUILTINS_DIR" ]; then
    echo ">>> Note: no wasm32 compiler-rt builtins at '$WASI_SWIFT_BUILTINS_DIR'." >&2
    echo "    Compiling and archiving is unaffected; linking a module will need them." >&2
    WASI_SWIFT_BUILTINS_DIR=""
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
# A --toolkit run keeps the build tree, because a narrow loop that reconfigures from scratch every
# time is not a narrow loop. Delete occt-build-wasm by hand to force a fresh configure.
if [ -z "$BUILD_TOOLKIT" ]; then
    rm -rf occt-install-wasm occt-build-wasm
fi

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
    # Three things, and every one of them has to reach EVERY translation unit.
    #
    # -include <shim>        the std threading stand-ins (#2170). See the block above.
    #
    # $WASM_CXX_EH_FLAGS     -fwasm-exceptions plus -mllvm -wasm-use-legacy-eh=false, from
    #                        Scripts/wasm-toolchain-versions.txt. #2171 measured that a TU compiled
    #                        WITHOUT these still lets an exception propagate through it, but its
    #                        stack cleanup never runs and a try/catch written inside it silently
    #                        never fires, with no diagnostic at compile or link time. OCCT catches
    #                        Standard_Failure internally to set IsDone() == false, so an OCCT built
    #                        without them has IsDone() quietly stop working. That is why this is a
    #                        whole-build flag and not the bridge's alone.
    #
    # -mllvm -wasm-enable-sjlj  setjmp is a separate mechanism and a separate flag. On wasip1
    #                        setjmp/longjmp are not libc functions; libsetjmp.a defines
    #                        __wasm_setjmp/__wasm_setjmp_test/__wasm_longjmp and only this flag
    #                        lowers a setjmp pair into them. Without it the compile is silent and
    #                        the LINK fails on undefined `setjmp`/`longjmp`, so -lsetjmp goes on the
    #                        link line too (#2174's, not this script's, while it only archives).
    #                        #2047's claim that -fwasm-exceptions covers setjmp is wrong; #2171
    #                        measured both halves.
    #
    # Quoted inside the flag value so a checkout path containing a space still reaches the
    # compiler as one argument. CMake inserts this string into the build command verbatim.
    "-DCMAKE_CXX_FLAGS=-include \"$WASI_THREADING_SHIM\" $WASM_CXX_EH_FLAGS -mllvm -wasm-enable-sjlj"
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

[ -z "$BUILD_TOOLKIT" ] && rm -rf occt-build-wasm
mkdir -p occt-build-wasm
cd occt-build-wasm

# --------------------
# The CMake toolchain file (#2172)
# --------------------
# This repo's own, not wasi-sdk's. An earlier version of this script preferred a
# `swift-wasi-sdk.cmake` inside the wasi-sdk prefix and treated `wasi-sdk-p1.cmake` as a fallback.
# No such file exists in either the wasi-sdk tarball or the Swift SDK's artifact bundle, so the
# fallback was what always ran, which silently compiled OCCT with wasi-sdk's clang against
# wasi-sdk's sysroot: a libc++ two major versions from the one the Swift side links, and one that
# sets _LIBCPP_HAS_THREADS to 1 where the Swift SDK sets it to 0. Scripts/cmake/wasi-swift-sdk.cmake
# holds the measurements and the reasoning.
WASI_TOOLCHAIN="$SCRIPT_DIR/cmake/wasi-swift-sdk.cmake"
if [ ! -f "$WASI_TOOLCHAIN" ]; then
    echo "ERROR: no WASI CMake toolchain file at '$WASI_TOOLCHAIN'." >&2
    exit 1
fi

# --------------------
# Preflight: does the threading shim match the libc++ this toolchain selects? (#2170)
# --------------------
# The shim asserts _LIBCPP_HAS_THREADS == 0 and adds names to namespace std, so it is only
# defensible against a libc++ that really is missing them. That is a property of the SYSROOT, and
# the two sysroots in play disagree:
#
#   * the Swift SDK's WASI.sdk sets _LIBCPP_HAS_THREADS 0, which is what #2170 measured, what the
#     shim exists for, and what this script now selects;
#   * wasi-sdk 34.0's own wasm32-wasip1 sysroot sets it to 1, in both the eh and noeh flavours,
#     and supplies all eight names itself.
#
# Without this check a mismatch surfaces as CMake's "the C++ compiler is not able to compile a
# simple test program", with the shim's own explanation buried in CMakeError.log. It asks exactly
# the compiler, triple and sysroot the toolchain file above sets, so it cannot drift from the build.
PREFLIGHT_CXX="$SWIFT_TOOLCHAIN_BIN/clang++"
PREFLIGHT_SRC="$(mktemp -t occt-wasm-shim-preflight).cpp"
printf '#include <version>\nint main() { return 0; }\n' > "$PREFLIGHT_SRC"
if ! PREFLIGHT_OUT="$("$PREFLIGHT_CXX" --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
        -std=c++17 -fsyntax-only -include "$WASI_THREADING_SHIM" "$PREFLIGHT_SRC" 2>&1)"; then
    rm -f "$PREFLIGHT_SRC"
    echo "ERROR: the std threading shim does not apply to the libc++ this toolchain selects." >&2
    echo "" >&2
    echo "  toolchain file: $WASI_TOOLCHAIN" >&2
    echo "  compiler:       $PREFLIGHT_CXX" >&2
    echo "  sysroot:        $SWIFT_WASI_SYSROOT" >&2
    echo "" >&2
    printf '%s\n' "$PREFLIGHT_OUT" >&2
    echo "" >&2
    echo "       Two causes, and they want opposite fixes." >&2
    echo "" >&2
    echo "       1. SWIFT_WASI_SYSROOT has been pointed at a sysroot whose libc++ HAS threads, so" >&2
    echo "          the eight names are already there and the shim is not merely unnecessary, it is" >&2
    echo "          a redefinition. wasi-sdk's own wasm32-wasip1 sysroot is in this category, and" >&2
    echo "          #2172 settled that OCCT is NOT built against it. Point it back." >&2
    echo "" >&2
    echo "       2. The pinned Swift SDK itself gained threads. Then the shim has served its" >&2
    echo "          purpose: remove this preflight and the -include, and delete" >&2
    echo "          Scripts/wasm-shims/ and Scripts/repro/2170/." >&2
    exit 1
fi
rm -f "$PREFLIGHT_SRC"
echo ">>> Threading shim preflight passed: $(basename "$WASI_THREADING_SHIM")"

# --------------------
# Preflight: do the exception flags actually produce a landing pad? (#2171, #2172)
# --------------------
# #2171's finding is that WASM_CXX_EH_FLAGS failing to reach a translation unit is SILENT: no
# error, no warning, and the only symptom is that a try/catch inside that unit never fires. A flag
# whose absence is silent needs an assertion, so this compiles a catch and reads the object back.
#
# The observable is the undefined symbol __cxa_begin_catch, which a compiled handler must call.
# Measured 2026-09-23 with the pinned toolchain on this exact source: WITH the flags the object
# references __cxa_begin_catch, __cxa_end_catch and __cxa_throw; WITHOUT them clang emits no
# handler at all and the only __cxa_* reference left is __cxa_throw. So the check distinguishes
# the two states rather than merely confirming the compiler runs.
EH_PREFLIGHT_SRC="$(mktemp -t occt-wasm-eh-preflight).cpp"
EH_PREFLIGHT_OBJ="${EH_PREFLIGHT_SRC%.cpp}.o"
cat > "$EH_PREFLIGHT_SRC" <<'EH_PREFLIGHT_EOF'
struct Failure {};
void raise() { throw Failure(); }
int caught() {
  try { raise(); } catch (const Failure&) { return 1; }
  return 0;
}
EH_PREFLIGHT_EOF
if ! "$PREFLIGHT_CXX" --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
        -std=c++17 $WASM_CXX_EH_FLAGS -mllvm -wasm-enable-sjlj \
        -c "$EH_PREFLIGHT_SRC" -o "$EH_PREFLIGHT_OBJ" 2>/dev/null \
   || ! "$SWIFT_TOOLCHAIN_BIN/llvm-nm" --undefined-only "$EH_PREFLIGHT_OBJ" 2>/dev/null \
        | grep -q '__cxa_begin_catch'; then
    rm -f "$EH_PREFLIGHT_SRC" "$EH_PREFLIGHT_OBJ"
    echo "ERROR: the exception flags did not produce a catch handler." >&2
    echo "" >&2
    echo "  flags: $WASM_CXX_EH_FLAGS -mllvm -wasm-enable-sjlj" >&2
    echo "" >&2
    echo "       A translation unit compiled without working exception flags still lets an" >&2
    echo "       exception propagate through it, but its stack cleanup does not run and a" >&2
    echo "       try/catch written inside it never fires, silently (#2171). OCCT catches" >&2
    echo "       Standard_Failure internally to set IsDone() == false, so this is the difference" >&2
    echo "       between a kernel that reports failures and one that quietly stops reporting them." >&2
    echo "       Check WASM_CXX_EH_FLAGS in Scripts/wasm-toolchain-versions.txt." >&2
    exit 1
fi
rm -f "$EH_PREFLIGHT_SRC" "$EH_PREFLIGHT_OBJ"
echo ">>> Exception preflight passed: $WASM_CXX_EH_FLAGS -mllvm -wasm-enable-sjlj"

# Exported as well as passed with -D: CMake re-includes the toolchain file inside every try_compile
# sub-project, and a -D cache entry does not reach one.
export SWIFT_TOOLCHAIN_BIN SWIFT_WASI_SYSROOT WASI_SDK_EH_LIBDIR WASI_SWIFT_BUILTINS_DIR

cmake ../occt-src \
    -G "Unix Makefiles" \
    "${CMAKE_COMMON_OPTS[@]}" \
    -DCMAKE_TOOLCHAIN_FILE="$WASI_TOOLCHAIN" \
    -DSWIFT_TOOLCHAIN_BIN="$SWIFT_TOOLCHAIN_BIN" \
    -DSWIFT_WASI_SYSROOT="$SWIFT_WASI_SYSROOT" \
    -DWASI_SDK_EH_LIBDIR="$WASI_SDK_EH_LIBDIR" \
    -DWASI_SWIFT_BUILTINS_DIR="$WASI_SWIFT_BUILTINS_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=../occt-install-wasm

if [ -n "$BUILD_TOOLKIT" ]; then
    # The narrow loop. `-k` so one pass reports every file that fails instead of stopping at the
    # first: a platform port needs the whole list at once, and discovering it one error at a time
    # is what makes a guard-site list untrustworthy. The build is therefore ALLOWED to fail here,
    # and the archive check below is what decides whether anything was produced.
    echo ""
    echo ">>> Building toolkit '$BUILD_TOOLKIT' only, with -k (keep going)."
    set +e
    cmake --build . --parallel "$JOBS" --target "$BUILD_TOOLKIT" -- -k
    TOOLKIT_STATUS=$?
    set -e

    TOOLKIT_OBJ_DIR="$(find . -type d -name "${BUILD_TOOLKIT}.dir" -print -quit)"
    if [ -z "$TOOLKIT_OBJ_DIR" ]; then
        echo "" >&2
        echo "ERROR: no ${BUILD_TOOLKIT}.dir under $(pwd); is '$BUILD_TOOLKIT' a toolkit this" >&2
        echo "       configure builds? Nothing was compiled and nothing was archived." >&2
        exit 1
    fi

    # Counted, never estimated. The denominator is every object CMake has a rule for and the
    # numerator is every object on disk, so both come from the build tree rather than from a
    # glob of the source directory that might disagree with what this configure selected.
    TOOLKIT_EXPECTED=$(grep -oE "CMakeFiles/${BUILD_TOOLKIT}\.dir/[A-Za-z0-9_/]+\.(cxx|c)\.obj" \
        "$TOOLKIT_OBJ_DIR/build.make" | sort -u | wc -l | tr -d ' ')
    TOOLKIT_ACTUAL=$(find "$TOOLKIT_OBJ_DIR" -name '*.obj' | wc -l | tr -d ' ')

    TOOLKIT_LIB="$(find . -name "lib${BUILD_TOOLKIT}.a" -print -quit)"
    if [ -z "$TOOLKIT_LIB" ]; then
        # No complete archive, because at least one file did not compile. Archive what did anyway,
        # under a name that cannot be mistaken for the real thing: a partial archive is what makes
        # the toolchain, the shim and the exception flags inspectable at kernel scale while the
        # platform gaps are still open, and the alternative is having nothing to check at all.
        TOOLKIT_LIB="$(pwd)/lib${BUILD_TOOLKIT}-partial.a"
        rm -f "$TOOLKIT_LIB"
        # shellcheck disable=SC2046
        (cd "$TOOLKIT_OBJ_DIR" && "$SWIFT_TOOLCHAIN_BIN/llvm-ar" rcs "$TOOLKIT_LIB" \
            $(find . -name '*.obj' | sort))
    fi

    echo ""
    echo ">>> $BUILD_TOOLKIT: $TOOLKIT_ACTUAL of $TOOLKIT_EXPECTED source files compiled."
    echo ">>> Archive: $TOOLKIT_LIB"
    echo "    members: $("$SWIFT_TOOLCHAIN_BIN/llvm-ar" t "$TOOLKIT_LIB" | wc -l | tr -d ' ')"
    echo "    Inspect it with $SWIFT_TOOLCHAIN_BIN/llvm-nm, not the host's nm: there is no llvm-nm"
    echo "    on the default macOS PATH and host nm misreads a wasm object."
    # --------------------
    # Completeness (#2173)
    # --------------------
    # The status above is the BUILD TOOL's, not a statement about the toolkit, and the counts above
    # are printed rather than checked. --require-complete turns the count into the assertion, so
    # that "every file compiled" is decided by the objects on disk against the rules CMake
    # generated, and a build that is short of the denominator cannot return the same status a
    # complete one does. It is checked BEFORE the status, so the message names the real defect.
    if [ -n "$REQUIRE_COMPLETE" ]; then
        if [ "$TOOLKIT_EXPECTED" -eq 0 ]; then
            echo "" >&2
            echo "ERROR: --require-complete was given and this build tree has no object rule for" >&2
            echo "       '$BUILD_TOOLKIT', so the check examined nothing. Per #2098 that fails" >&2
            echo "       rather than passes: a denominator of zero is not a complete build." >&2
            exit 1
        fi
        if [ "$TOOLKIT_ACTUAL" -ne "$TOOLKIT_EXPECTED" ]; then
            echo "" >&2
            echo "ERROR: --require-complete was given and $BUILD_TOOLKIT is INCOMPLETE:" >&2
            echo "       $TOOLKIT_ACTUAL of $TOOLKIT_EXPECTED source files compiled, $((TOOLKIT_EXPECTED - TOOLKIT_ACTUAL)) short." >&2
            echo "       Every failing file is in the log above, in a single pass. If one of them is" >&2
            echo "       a platform gap, it belongs in Scripts/patches-wasi/ with a patch header" >&2
            echo "       saying what its WASI branch returns; see docs/WASI_GUARD_SITES.md." >&2
            exit 1
        fi
        case "$TOOLKIT_LIB" in
            *-partial.a)
                echo "" >&2
                echo "ERROR: --require-complete was given and the archive is the partial one," >&2
                echo "       '$TOOLKIT_LIB'. CMake produced no lib$BUILD_TOOLKIT.a, so the link" >&2
                echo "       rule did not run even though every object is present." >&2
                exit 1
                ;;
        esac
        if [ "$TOOLKIT_STATUS" -ne 0 ]; then
            echo "" >&2
            echo "ERROR: --require-complete was given and every object is present, but the build" >&2
            echo "       tool exited $TOOLKIT_STATUS. Something other than a compile failed; the" >&2
            echo "       log above is the record." >&2
            exit 1
        fi
        echo ">>> COMPLETE: $TOOLKIT_ACTUAL of $TOOLKIT_EXPECTED, as --require-complete demands."
    fi

    if [ "$TOOLKIT_STATUS" -ne 0 ]; then
        echo "" >&2
        echo ">>> INCOMPLETE. $((TOOLKIT_EXPECTED - TOOLKIT_ACTUAL)) file(s) did not compile; every" >&2
        echo "    one is in the log above, in a single pass. The archive named above holds only the" >&2
        echo "    files that did. Scripts/repro/2172/run.sh turns that log into the guard-site list." >&2
        exit "$TOOLKIT_STATUS"
    fi
    exit 0
fi

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

# llvm-ar from the swift.org toolchain, the one that compiled these objects. Not the host's `ar`:
# there is no llvm-nm or llvm-ar on the default macOS PATH, and the host tools do not read wasm
# objects, which has already produced one wrong conclusion in this initiative.
AR_TOOL="$SWIFT_TOOLCHAIN_BIN/llvm-ar"

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