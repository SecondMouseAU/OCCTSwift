#!/bin/bash
#
# #2894: an OCCT exception inside BRepFill_Evolved reaches std::terminate on wasm instead of the
# bridge's catch. Four modes, each re-runnable, each printing what it measured.
#
#   Scripts/repro/2894/run.sh wasm   [cases]   the six cases on wasm32-unknown-wasip1
#   Scripts/repro/2894/run.sh native [cases]   the same six on arm64 macOS, the control
#   Scripts/repro/2894/run.sh bisect           recompile the one OCCT unit at -O0 / -O2 /
#                                              -O2 -fno-inline and run case B against each
#   Scripts/repro/2894/run.sh marks            the same unit, instrumented, at an inlining
#                                              setting that traps instead of terminating, so one
#                                              run shows both the throw site and the cleanup
#   Scripts/repro/2894/run.sh bridge           #2891's inputs through the REAL bridge sources,
#                                              compiled with the toolset's own flags
#
# Cases (default order AEDCFB, each prints its own verdict):
#   A  BRepPrimAPI_MakeBox(0, 0, 0)          a Standard_DomainError from inside the archive
#   E  gp_Ax3(P, (0,0,1), (0,0,1))           #2891's inline raise, expanded in THIS unit
#   D  Geom_TrimmedCurve(C, 1.0, 1.0)        #2894's own raise, with nothing in between
#   C  the same raise under PrepareProfile's locals, unwound through them
#   F  BRepFill_Evolved::Perform on an input that succeeds
#   B  BRepFill_Evolved::Perform on #2894's input
#
# Prerequisites for the wasm legs: Scripts/install-wasm-toolchain.sh and
# Scripts/fetch-occt-wasm.sh. `bisect` additionally needs an OCCT source tree, which lives in the
# main checkout rather than in a worktree: set OCCT_SRC if it is not Libraries/occt-src.
#
# Every toolchain path and flag is read from Scripts/wasm-toolchain-versions.txt, the same pins
# Scripts/build-occt-wasm.sh reads; nothing here is a literal that could drift away from it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PINS_FILE="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/build}"

MODE="${1:-wasm}"
CASES="${2:-AEDCFB}"

die() { echo "ERROR: $*" >&2; exit 1; }

pin() {
    local key="$1" value
    value="$(grep -E "^${key}=" "$PINS_FILE" | head -1 | cut -d= -f2-)"
    [ -n "$value" ] || die "no $key in $PINS_FILE"
    printf '%s' "$value"
}

mkdir -p "$OUT_DIR"

# --------------------------------------------------------------------------------------------
# The native control. -O2 deliberately: the point is that the SAME source at the SAME
# optimisation level behaves differently on the two targets.
# --------------------------------------------------------------------------------------------
if [ "$MODE" = "native" ]; then
    HEADERS="$REPO_DIR/Libraries/OCCT.xcframework/macos-arm64/Headers"
    LIBDIR="$REPO_DIR/Libraries/OCCT.xcframework/macos-arm64"
    [ -d "$HEADERS" ] || die "no macOS OCCT headers at $HEADERS"
    clang++ -std=c++17 -O2 -w \
        -I "$HEADERS" \
        "$SCRIPT_DIR/probe.cpp" \
        -L "$LIBDIR" -lOCCT-macos \
        -framework Foundation -framework AppKit -lz -lc++ \
        -o "$OUT_DIR/probe-native"
    echo ">>> running native probe, cases $CASES"
    "$OUT_DIR/probe-native" "$CASES"
    exit $?
fi

case "$MODE" in
    wasm|bisect|marks|bridge) ;;
    *) die "unknown mode '$MODE' (expected wasm, native, bisect, marks or bridge)" ;;
esac

SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"
WASM_CXX_EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"

ARCH="$(uname -m)"
case "$(uname -s)" in
    Darwin) OS="macos" ;;
    Linux)  OS="linux" ;;
    *)      die "unsupported host $(uname -s)" ;;
esac

SWIFT_TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-${SWIFT_TOOLCHAIN_VERSION}.xctoolchain/usr/bin}"
SWIFT_SDKS_DIR="${SWIFT_SDKS_DIR:-$HOME/.swiftpm/swift-sdks}"
SWIFT_WASI_SYSROOT="${SWIFT_WASI_SYSROOT:-$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}/WASI.sdk}"
# The wasi-sdk install lives beside occt-src in the MAIN checkout's Libraries by default; a
# worktree has its own Libraries and need not carry a second copy of it.
WASI_SDK_PREFIX="${WASI_SDK_PREFIX:-$REPO_DIR/Libraries/wasi-sdk-${WASI_SDK_VERSION}-${ARCH}-${OS}}"
[ -d "$WASI_SDK_PREFIX" ] || die "no wasi-sdk at $WASI_SDK_PREFIX (set WASI_SDK_PREFIX)"
WASI_SDK_EH_LIBDIR="$WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasip1/eh"
[ -f "$WASI_SDK_EH_LIBDIR/libc++abi.a" ] || die "no exception-enabled libc++abi at $WASI_SDK_EH_LIBDIR"
[ -x "$SWIFT_TOOLCHAIN_BIN/clang++" ] || die "no swift.org clang++ at $SWIFT_TOOLCHAIN_BIN"
[ -f "$REPO_DIR/Libraries/libOCCT-wasm.a" ] || die "no Libraries/libOCCT-wasm.a (Scripts/fetch-occt-wasm.sh)"

# The wasm32 compiler-rt builtins ship inside the Swift SDK bundle rather than in the swift.org
# toolchain, which is the same note Scripts/build-occt-wasm.sh carries. They are laid out in
# clang's pre-per-target scheme (lib/wasip1/libclang_rt.builtins-wasm32.a), so pointing
# -resource-dir at that xctoolchain's clang directory is what makes the driver find them; a bare
# -L does not, because the driver asks for libclang_rt.builtins.a by its resource-dir path.
WASI_RESOURCE_DIR="$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}/swift.xctoolchain/usr/lib/clang"
[ -d "$WASI_RESOURCE_DIR/lib/wasip1" ] || die "no wasm32 compiler-rt builtins under $WASI_RESOURCE_DIR"

# A 4 MB shadow stack, so a deep OCCT unwind cannot be confused with the default 64 KB one
# running out. The defect reproduces at the default size too; this removes the question.
STACK_FLAG="-Wl,-z,stack-size=4194304"

# shellcheck disable=SC2206  # WASM_CXX_EH_FLAGS is several flags and must word-split
EH_FLAGS=($WASM_CXX_EH_FLAGS -mllvm -wasm-enable-sjlj)

compile_probe() {   # compile_probe <source> <object> [extra flags...]
    local src="$1" obj="$2"; shift 2
    "$SWIFT_TOOLCHAIN_BIN/clang++" \
        --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
        -std=c++17 -O2 "${EH_FLAGS[@]}" -w \
        -include "$REPO_DIR/Scripts/wasm-shims/wasi-std-threading.hpp" \
        -I "$REPO_DIR/Libraries/occt-headers-wasm" \
        "$@" -c "$src" -o "$obj"
}

link_wasm() {       # link_wasm <output> <objects...>
    local out="$1"; shift
    "$SWIFT_TOOLCHAIN_BIN/clang++" \
        --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
        -fwasm-exceptions "$@" \
        -resource-dir "$WASI_RESOURCE_DIR" \
        -L "$WASI_SDK_EH_LIBDIR" -L "$REPO_DIR/Libraries" \
        -lOCCT-wasm -lc++ -lc++abi -lunwind -lsetjmp -lwasi-emulated-getpid \
        "$STACK_FLAG" -o "$out"
}

# --------------------------------------------------------------------------------------------
# bridge: #2891's inputs through the real bridge sources, with the toolset's own C++ flags.
# --------------------------------------------------------------------------------------------
if [ "$MODE" = "bridge" ]; then
    BRIDGE_FLAGS=(-x c++
        -I "$REPO_DIR/Sources/OCCTBridge/include" -I "$REPO_DIR/Scripts/wasm-shims"
        -DOCCT_AVAILABLE=1 -DOCCT_NO_DEPRECATED -DSWIFT_PACKAGE)
    echo ">>> compiling the bridge units Package.swift builds for WASI"
    compile_probe "$REPO_DIR/Sources/OCCTBridge/src/OCCTBridge.mm" \
        "$OUT_DIR/bridge-core.o" "${BRIDGE_FLAGS[@]}"
    compile_probe "$REPO_DIR/Sources/OCCTBridge/src/OCCTBridge_Spatial_GeometryUtils.mm" \
        "$OUT_DIR/bridge-geom.o" "${BRIDGE_FLAGS[@]}"
    compile_probe "$SCRIPT_DIR/probe-2891.cpp" "$OUT_DIR/probe-2891.o" "${BRIDGE_FLAGS[@]}"
    link_wasm "$OUT_DIR/probe-2891.wasm" \
        "$OUT_DIR/probe-2891.o" "$OUT_DIR/bridge-geom.o" "$OUT_DIR/bridge-core.o"
    echo ">>> running under wasmkit"
    set +e
    "$SWIFT_TOOLCHAIN_BIN/wasmkit" run --dir / "$OUT_DIR/probe-2891.wasm"
    STATUS=$?
    set -e
    echo ">>> exit status $STATUS"
    exit $STATUS
fi

# --------------------------------------------------------------------------------------------
# bisect: the same OCCT unit, three optimisation settings, one case.
#
# Each object is listed BEFORE -lOCCT-wasm on the link line and defines every symbol the
# archive member does, so the archive member is never pulled in and the locally compiled one is
# what runs.
# --------------------------------------------------------------------------------------------
if [ "$MODE" = "bisect" ] || [ "$MODE" = "marks" ]; then
    OCCT_SRC="${OCCT_SRC:-$REPO_DIR/Libraries/occt-src}"
    EVOLVED="$OCCT_SRC/src/ModelingAlgorithms/TKBool/BRepFill/BRepFill_Evolved.cxx"
    if [ ! -f "$EVOLVED" ]; then
        die "no OCCT source at $EVOLVED. A worktree has no occt-src; set OCCT_SRC to the main
       checkout's Libraries/occt-src, or run Scripts/build-occt.sh once to fetch it."
    fi
    compile_probe "$SCRIPT_DIR/probe.cpp" "$OUT_DIR/probe.o"
fi

# --------------------------------------------------------------------------------------------
# marks: one run that shows the throw site and the cleanup that should not have run.
#
# -mllvm -inline-threshold=0 is deliberate and is NOT "no inlining": CutEdgeProf is file-static
# with one call site, so it is inlined whatever the threshold. What the threshold removes is the
# rest of the inlining, and with it the terminate scope that otherwise swallows the failure, so
# the same defect surfaces as a trap that names the destructor instead.
# --------------------------------------------------------------------------------------------
if [ "$MODE" = "marks" ]; then
    python3 "$SCRIPT_DIR/instrument.py" "$EVOLVED" "$OUT_DIR/BRepFill_Evolved-marked.cxx"
    echo ">>> compiling the instrumented unit at -O2 -mllvm -inline-threshold=0"
    "$SWIFT_TOOLCHAIN_BIN/clang++" \
        --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
        -std=c++17 -O2 -mllvm -inline-threshold=0 "${EH_FLAGS[@]}" -w -DNo_Exception \
        -include "$REPO_DIR/Scripts/wasm-shims/wasi-std-threading.hpp" \
        -I "$REPO_DIR/Libraries/occt-headers-wasm" \
        -c "$OUT_DIR/BRepFill_Evolved-marked.cxx" -o "$OUT_DIR/evolved-marked.o"
    link_wasm "$OUT_DIR/probe-marked.wasm" "$OUT_DIR/probe.o" "$OUT_DIR/evolved-marked.o"
    echo ">>> running under wasmkit, case B"
    set +e
    "$SWIFT_TOOLCHAIN_BIN/wasmkit" run --dir / "$OUT_DIR/probe-marked.wasm" B
    STATUS=$?
    set -e
    echo ">>> exit status $STATUS"
    exit $STATUS
fi

if [ "$MODE" = "bisect" ]; then
    # -DNo_Exception, because that is what OCCT's own Release build defines for its own sources
    # (okf/policies/occt-validation-is-compiled-out.md). Compiling the unit without it would be
    # measuring a different kernel from the one we ship.
    for variant in "O0:-O0" "O2:-O2" "O2-no-inline:-O2 -fno-inline"; do
        name="${variant%%:*}"
        flags="${variant#*:}"
        echo
        echo "=============================================================="
        echo ">>> BRepFill_Evolved.cxx compiled $flags"
        echo "=============================================================="
        # shellcheck disable=SC2086  # flags is several flags and must word-split
        "$SWIFT_TOOLCHAIN_BIN/clang++" \
            --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
            -std=c++17 $flags "${EH_FLAGS[@]}" -w -DNo_Exception \
            -include "$REPO_DIR/Scripts/wasm-shims/wasi-std-threading.hpp" \
            -I "$REPO_DIR/Libraries/occt-headers-wasm" \
            -c "$EVOLVED" -o "$OUT_DIR/evolved-$name.o"
        link_wasm "$OUT_DIR/probe-$name.wasm" "$OUT_DIR/probe.o" "$OUT_DIR/evolved-$name.o"
        set +e
        "$SWIFT_TOOLCHAIN_BIN/wasmkit" run --dir / "$OUT_DIR/probe-$name.wasm" B
        echo ">>> exit status $?"
        set -e
    done
    exit 0
fi

# --------------------------------------------------------------------------------------------
# wasm: the six cases against the pinned kernel archive.
# --------------------------------------------------------------------------------------------
echo ">>> compiling probe.cpp for $SWIFT_WASM_TRIPLE"
compile_probe "$SCRIPT_DIR/probe.cpp" "$OUT_DIR/probe.o"
echo ">>> linking"
link_wasm "$OUT_DIR/probe.wasm" "$OUT_DIR/probe.o"
echo ">>> running under wasmkit, cases $CASES"
set +e
"$SWIFT_TOOLCHAIN_BIN/wasmkit" run --dir / "$OUT_DIR/probe.wasm" "$CASES"
STATUS=$?
set -e
echo ">>> exit status $STATUS"
exit $STATUS
