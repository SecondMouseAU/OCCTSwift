#!/bin/bash
#
# #2175: the Phase 0 go/no-go. Swift, over the OCCTSwift public API, over the bridge, over OCCT,
# in one wasm32-unknown-wasip1 module, run under the pinned wasmkit.
#
# Like Scripts/repro/2172, 2173 and 2174's runners, this reads the compiler, the sysroot and every
# flag out of the build tree CMake generated rather than restating them, so it cannot drift from
# the build it describes.
#
#   Scripts/build-occt-wasm.sh       # the kernel: 49 toolkits, ~35 minutes, leaves
#                                    # Libraries/libOCCT-wasm.a and Libraries/occt-headers-wasm
#   Scripts/repro/2175/run.sh        # everything below
#
#   ./run.sh build     generate the consumer toolset and build spike/ for wasm, release
#   ./run.sh run       run the module under wasmkit with a preopened directory. Six cases, of
#                      which two must FAIL in the kernel's own words rather than trap. ASSERTS.
#   ./run.sh sjlj      the blocker this issue found and the negative case for its fix: what
#                      -DOCC_CONVERT_SIGNALS does to one OCCT source file, and what the module
#                      built from it does under wasmkit. ASSERTS, in both directions.
#   ./run.sh controls  two plain SwiftWasm modules, with and without Foundation, so the size and
#                      import numbers below are read as a DIFFERENCE and not as a total
#   ./run.sh size      uncompressed, gzip and brotli, plus the wasm section breakdown
#   ./run.sh imports   the host imports each module needs, which is what #2052 was asking
#
# `./run.sh` with no argument runs all of them, in that order.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB_DIR="$REPO_DIR/Libraries"
BUILD_DIR="$LIB_DIR/occt-build-wasm"
ARCHIVE="${OCCT_WASM_ARCHIVE:-$LIB_DIR/libOCCT-wasm.a}"
SPIKE_DIR="$SCRIPT_DIR/spike"
OUT_DIR="${TMPDIR:-/tmp}/occt-2175"
FAILURES=0

PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }
TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
AR="$TOOLCHAIN_BIN/llvm-ar"
NM="$TOOLCHAIN_BIN/llvm-nm"
OBJDUMP="$TOOLCHAIN_BIN/llvm-objdump"
WASMKIT="$TOOLCHAIN_BIN/wasmkit"
SWIFT="$TOOLCHAIN_BIN/swift"
SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"

# The pinned toolchain's llvm tools and nobody else's. There is no llvm-nm on the default macOS
# PATH at all, and host `nm -g` on a wasm object lists undefined symbols as though they were
# defined, which has already produced two wrong conclusions in this initiative (#2174).
for tool in "$AR" "$NM" "$OBJDUMP" "$WASMKIT" "$SWIFT"; do
    if [ ! -x "$tool" ]; then
        echo "ERROR: $tool is missing. Install the pinned toolchain:" >&2
        echo "       Scripts/install-wasm-toolchain.sh" >&2
        exit 1
    fi
done

if [ ! -f "$ARCHIVE" ]; then
    echo "ERROR: no kernel archive at $ARCHIVE." >&2
    echo "       Build it first:  Scripts/build-occt-wasm.sh" >&2
    exit 1
fi
if [ ! -d "$LIB_DIR/occt-headers-wasm" ]; then
    echo "ERROR: no header tree at $LIB_DIR/occt-headers-wasm." >&2
    echo "       It is what Package.swift's .headerSearchPath names, and only the packaging step" >&2
    echo "       of Scripts/build-occt-wasm.sh writes it." >&2
    exit 1
fi

WASI_SDK_PREFIX="${WASI_SDK_PREFIX:-$LIB_DIR/wasi-sdk-$(pin WASI_SDK_VERSION)-arm64-macos}"
if [ ! -d "$WASI_SDK_PREFIX" ]; then
    echo "ERROR: wasi-sdk not found at '$WASI_SDK_PREFIX'. Set WASI_SDK_PREFIX." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
TOOLSET="$OUT_DIR/toolset.json"

note_failure() {
    FAILURES=$((FAILURES + 1))
    echo "    *** FAILED: $1"
}

# ---------------------------------------------------------------------------------------------
do_build() {
    echo ""
    echo "===================================================================="
    echo "BUILD: the consumer toolset, and spike/ for $TRIPLE"
    echo "===================================================================="
    # The toolset is the consumer's file, not the package's, which is the whole mechanism #2048
    # settled: SwiftPM refuses .unsafeFlags for a dependency resolved by VERSION, and every flag
    # in here names a property of this machine that a published manifest could not know.
    python3 "$REPO_DIR/Scripts/make-wasi-toolset.py" \
        --wasi-sdk "$WASI_SDK_PREFIX" \
        --occt-lib-dir "$(dirname "$ARCHIVE")" \
        -o "$TOOLSET" || { note_failure "make-wasi-toolset.py"; return 1; }
    echo "    toolset: $TOOLSET"
    ( cd "$SPIKE_DIR" \
        && OCCTSWIFT_WASI=1 TOOLCHAINS=swift "$SWIFT" build -c release \
            --toolset "$TOOLSET" --swift-sdk "$SDK_ID" --triple "$TRIPLE" ) \
        || { note_failure "swift build"; return 1; }
    local module="$SPIKE_DIR/.build/out/Products/Release-webassembly-wasm32/OCCTWasmSpike.wasm"
    [ -f "$module" ] || { note_failure "no module at $module"; return 1; }
    printf '    module: %s, %s bytes\n' "$module" "$(stat -f%z "$module" 2>/dev/null || stat -c%s "$module")"
}

MODULE="$SPIKE_DIR/.build/out/Products/Release-webassembly-wasm32/OCCTWasmSpike.wasm"

# ---------------------------------------------------------------------------------------------
do_run() {
    echo ""
    echo "===================================================================="
    echo "RUN: five calls through the OCCTSwift public API, six cases, under wasmkit"
    echo "===================================================================="
    [ -f "$MODULE" ] || { note_failure "no module; run ./run.sh build first"; return 1; }
    local work="$OUT_DIR/work"
    rm -rf "$work"
    mkdir -p "$work"
    local log="$OUT_DIR/run.txt"
    # Two preopens, and they answer different questions. $work is where the spike writes and reads
    # its own STEP file with an explicit path. /tmp is what FileManager.default.temporaryDirectory
    # resolves to, which is what the `stepData` bytes-out convenience uses; without that preopen it
    # refuses, which is itself the finding (see README).
    "$WASMKIT" run --dir "$work" --dir /tmp "$MODULE" "$work" >"$log" 2>&1
    local status=$?
    grep -E '^(case|note|failures)' "$log" || true
    if [ "$status" -ne 0 ]; then
        echo ""
        echo "    the module did not exit 0. What it said:"
        sed 's/^/      /' "$log" | tail -20
        note_failure "wasmkit exit $status"
        return 1
    fi
    # Assert on the case lines rather than on the exit status alone: a module that printed nothing
    # and exited 0 would otherwise pass. Six cases, every one of them PASS.
    local passes
    passes="$(grep -c '^case .* PASS ' "$log" || true)"
    if [ "$passes" -ne 6 ]; then
        note_failure "expected 6 PASS lines, saw $passes"
        return 1
    fi
    grep -q '^failures: 0$' "$log" || { note_failure "the module did not report 'failures: 0'"; return 1; }
    echo "    VERDICT: 6 of 6 cases PASS, exit 0."
}

# ---------------------------------------------------------------------------------------------
# The blocker, and the negative case for its fix.
#
# Scripts/build-occt-wasm.sh now passes -UOCC_CONVERT_SIGNALS, so OCC_CATCH_SIGNALS expands to
# nothing and no OCCT function carries a lowered setjmp. Before it did, and the module the pinned
# clang emitted for BRepCheck_ParallelAnalyzer::operator()(int) const was INVALID: a br_table whose
# targets do not all have the same label types. This case builds both kernels' version of that one
# file, swaps each into a copy of the archive, links the real spike against both and runs both.
# ---------------------------------------------------------------------------------------------
SIGNALS_SOURCE="$LIB_DIR/occt-src/src/ModelingAlgorithms/TKTopAlgo/BRepCheck/BRepCheck_Analyzer.cxx"
SIGNALS_OBJECT="BRepCheck_Analyzer.cxx.obj"

do_sjlj() {
    echo ""
    echo "===================================================================="
    echo "SJLJ: setjmp plus wasm exceptions in one function emits an invalid module"
    echo "===================================================================="
    [ -f "$SIGNALS_SOURCE" ] || { note_failure "no $SIGNALS_SOURCE"; return 1; }
    # This case ends by relinking the spike against the real archive, so it needs the real
    # toolset whether or not `build` ran in this invocation.
    if [ ! -f "$TOOLSET" ]; then
        python3 "$REPO_DIR/Scripts/make-wasi-toolset.py" --wasi-sdk "$WASI_SDK_PREFIX" \
            --occt-lib-dir "$(dirname "$ARCHIVE")" -o "$TOOLSET" >/dev/null \
            || { note_failure "make-wasi-toolset.py"; return 1; }
    fi
    local tk_dir="$BUILD_DIR/src/ModelingAlgorithms/TKTopAlgo/CMakeFiles/TKTopAlgo.dir"
    [ -f "$tk_dir/flags.make" ] || { note_failure "no TKTopAlgo build tree"; return 1; }

    # Every flag comes out of the build tree, so this compiles the file the way the kernel did and
    # cannot restate a flag the kernel does not use.
    local cxx includes flags
    cxx="$(sed -n 's|^# compile CXX with ||p' "$tk_dir/flags.make" | head -1)"
    includes="$(sed -n 's/^CXX_INCLUDES = //p' "$tk_dir/flags.make" | head -1)"
    flags="$(sed -n 's/^CXX_FLAGS = //p' "$tk_dir/flags.make" | head -1)"
    local sysroot
    sysroot="$(sed -n 's/^SWIFT_WASI_SYSROOT:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
    for v in cxx includes flags sysroot; do
        eval "val=\$$v"
        [ -n "$val" ] || { note_failure "$v could not be read from the build tree"; return 1; }
    done
    echo "    flags, from the build tree: $flags"

    local work="$OUT_DIR/sjlj"
    rm -rf "$work"
    mkdir -p "$work/with" "$work/without"
    # `eval` because $includes and $flags are a build system's command line, quoting included.
    # -DOCC_CONVERT_SIGNALS after $flags, so it beats the -U that is in there now, which is the
    # same "last word wins" the build script relies on in the other direction.
    eval "\"\$cxx\" --target=$TRIPLE --sysroot=\"\$sysroot\" -DHAVE_RAPIDJSON $includes $flags \
        -DOCC_CONVERT_SIGNALS -c \"\$SIGNALS_SOURCE\" -o \"\$work/with/\$SIGNALS_OBJECT\"" \
        >"$work/with.log" 2>&1 || { note_failure "compiling with signals"; sed 's/^/      /' "$work/with.log" | tail -5; return 1; }
    eval "\"\$cxx\" --target=$TRIPLE --sysroot=\"\$sysroot\" -DHAVE_RAPIDJSON $includes $flags \
        -c \"\$SIGNALS_SOURCE\" -o \"\$work/without/\$SIGNALS_OBJECT\"" \
        >"$work/without.log" 2>&1 || { note_failure "compiling without signals"; sed 's/^/      /' "$work/without.log" | tail -5; return 1; }

    local with_sj without_sj with_size without_size
    with_sj="$("$NM" --undefined-only "$work/with/$SIGNALS_OBJECT" | grep -cE '__wasm_setjmp|__wasm_longjmp' || true)"
    without_sj="$("$NM" --undefined-only "$work/without/$SIGNALS_OBJECT" | grep -cE '__wasm_setjmp|__wasm_longjmp' || true)"
    with_size="$(stat -f%z "$work/with/$SIGNALS_OBJECT" 2>/dev/null || stat -c%s "$work/with/$SIGNALS_OBJECT")"
    without_size="$(stat -f%z "$work/without/$SIGNALS_OBJECT" 2>/dev/null || stat -c%s "$work/without/$SIGNALS_OBJECT")"
    printf '    %-24s setjmp symbols=%s  object=%s bytes\n' "-DOCC_CONVERT_SIGNALS" "$with_sj" "$with_size"
    printf '    %-24s setjmp symbols=%s  object=%s bytes\n' "-UOCC_CONVERT_SIGNALS" "$without_sj" "$without_size"
    [ "$with_sj" -gt 0 ] || note_failure "the define no longer produces a lowered setjmp; this case measures nothing"
    [ "$without_sj" -eq 0 ] || note_failure "-U left $without_sj setjmp symbol(s) behind"

    # The whole archive, so the difference is one object and nothing else.
    cp "$ARCHIVE" "$work/libOCCT-wasm.a" || { note_failure "copying the archive"; return 1; }
    ( cd "$work/with" && "$AR" r "$work/libOCCT-wasm.a" "$SIGNALS_OBJECT" ) \
        || { note_failure "swapping the object in"; return 1; }
    python3 "$REPO_DIR/Scripts/make-wasi-toolset.py" --wasi-sdk "$WASI_SDK_PREFIX" \
        --occt-lib-dir "$work" -o "$work/toolset.json" >/dev/null \
        || { note_failure "toolset for the negative case"; return 1; }
    ( cd "$SPIKE_DIR" && OCCTSWIFT_WASI=1 TOOLCHAINS=swift "$SWIFT" build -c release \
        --toolset "$work/toolset.json" --swift-sdk "$SDK_ID" --triple "$TRIPLE" ) \
        >"$work/link.log" 2>&1 || { note_failure "linking against the with-signals archive"; return 1; }

    local run_work="$work/run"
    mkdir -p "$run_work"
    "$WASMKIT" run --dir "$run_work" "$MODULE" "$run_work" >"$work/negative.txt" 2>&1
    local status=$?
    echo ""
    echo "    the same spike, against an archive whose BRepCheck_Analyzer.cxx.obj carries setjmp:"
    sed 's/^/      /' "$work/negative.txt" | head -6
    if [ "$status" -eq 0 ]; then
        note_failure "the with-signals module RAN; this issue's blocker no longer reproduces, and -UOCC_CONVERT_SIGNALS is now unexplained"
    elif grep -q 'br_table' "$work/negative.txt"; then
        echo "    VERDICT: refused, and refused for the br_table reason. This is #2175's blocker."
    else
        note_failure "it failed, but not on br_table; read $work/negative.txt before believing the diagnosis"
    fi

    # Put the good module back, so a later `./run.sh run` in the same invocation is not measuring
    # the negative case's binary.
    ( cd "$SPIKE_DIR" && OCCTSWIFT_WASI=1 TOOLCHAINS=swift "$SWIFT" build -c release \
        --toolset "$TOOLSET" --swift-sdk "$SDK_ID" --triple "$TRIPLE" ) >/dev/null 2>&1 \
        || note_failure "relinking against the real archive"
}

# ---------------------------------------------------------------------------------------------
# The controls. #1689's consumer is a SwiftWasm app that already carries the Swift runtime and a
# WASI shim, so the number that matters is what OCCT and the bridge ADD, not the total.
# ---------------------------------------------------------------------------------------------
CONTROL_DIR="$OUT_DIR/controls"
CONTROL_PLAIN="$CONTROL_DIR/.build/out/Products/Release-webassembly-wasm32/HelloPlain.wasm"
CONTROL_FOUNDATION="$CONTROL_DIR/.build/out/Products/Release-webassembly-wasm32/HelloFoundation.wasm"

do_controls() {
    echo ""
    echo "===================================================================="
    echo "CONTROLS: a SwiftWasm module with and without Foundation"
    echo "===================================================================="
    rm -rf "$CONTROL_DIR"
    mkdir -p "$CONTROL_DIR/Sources/HelloPlain" "$CONTROL_DIR/Sources/HelloFoundation"
    cat > "$CONTROL_DIR/Package.swift" <<'EOF'
// swift-tools-version: 6.1
import PackageDescription
let package = Package(
    name: "Controls",
    targets: [
        .executableTarget(name: "HelloPlain"),
        .executableTarget(name: "HelloFoundation"),
    ]
)
EOF
    printf 'print("hi")\n' > "$CONTROL_DIR/Sources/HelloPlain/main.swift"
    # Foundation's file surface specifically, because that is what OCCTSwift's Exporter and
    # importer use and it is what pulls the preopen-related WASI imports.
    cat > "$CONTROL_DIR/Sources/HelloFoundation/main.swift" <<'EOF'
import Foundation
print(
    URL(fileURLWithPath: "/tmp").path, Data([1, 2, 3]).count,
    FileManager.default.temporaryDirectory.path)
EOF
    ( cd "$CONTROL_DIR" && TOOLCHAINS=swift "$SWIFT" build -c release \
        --swift-sdk "$SDK_ID" --triple "$TRIPLE" ) >"$OUT_DIR/controls.log" 2>&1 \
        || { note_failure "building the controls"; sed 's/^/      /' "$OUT_DIR/controls.log" | tail -5; return 1; }
    for f in "$CONTROL_PLAIN" "$CONTROL_FOUNDATION"; do
        [ -f "$f" ] || { note_failure "no control at $f"; continue; }
        printf '    %-20s %s bytes\n' "$(basename "$f")" "$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")"
    done
}

# ---------------------------------------------------------------------------------------------
size_of() { stat -f%z "$1" 2>/dev/null || stat -c%s "$1"; }

do_size() {
    echo ""
    echo "===================================================================="
    echo "SIZE: the distribution facts"
    echo "===================================================================="
    echo "    brotli is the column to read against occt-wasm's published ~4.5 MB and against"
    echo "    #1689's 5 MB target, which is a target and not a gate. Comparing a gzip number"
    echo "    against a brotli one is the like-for-like mistake #2174's own body warns about."
    echo ""
    printf '    %-24s %12s %12s %12s\n' "module" "uncompressed" "gzip -9" "brotli -q 11"
    local f name u g b
    for f in "$CONTROL_PLAIN" "$CONTROL_FOUNDATION" "$MODULE"; do
        [ -f "$f" ] || continue
        name="$(basename "$f" .wasm)"
        u="$(size_of "$f")"
        g="$(gzip -9 -c "$f" | wc -c | tr -d ' ')"
        if command -v brotli >/dev/null 2>&1; then
            b="$(brotli -q 11 -c "$f" | wc -c | tr -d ' ')"
        else
            b="(no brotli)"
        fi
        printf '    %-24s %12s %12s %12s\n' "$name" "$u" "$g" "$b"
    done
    echo ""
    echo "    where the bytes are, by wasm section:"
    for f in "$CONTROL_FOUNDATION" "$MODULE"; do
        [ -f "$f" ] || continue
        echo "      $(basename "$f")"
        "$OBJDUMP" -h "$f" 2>/dev/null | awk '/^ +[0-9]+ (CODE|DATA)/ {printf "        %-6s 0x%s\n", $2, $3}'
    done
}

# ---------------------------------------------------------------------------------------------
wasi_imports() {
    "$NM" --undefined-only "$1" 2>/dev/null | awk '{print $NF}' \
        | sed -n 's/^__imported_wasi_snapshot_preview1_//p' | sort -u
}
other_imports() {
    "$NM" --undefined-only "$1" 2>/dev/null | awk '{print $NF}' \
        | grep -cv '^__imported_wasi_snapshot_preview1_' || true
}

do_imports() {
    echo ""
    echo "===================================================================="
    echo "IMPORTS: what the host has to supply, and what OCCT adds to it"
    echo "===================================================================="
    local f
    for f in "$CONTROL_PLAIN" "$CONTROL_FOUNDATION" "$MODULE"; do
        [ -f "$f" ] || continue
        printf '    %-24s wasi_snapshot_preview1: %-3s  from any other module: %s\n' \
            "$(basename "$f" .wasm)" "$(wasi_imports "$f" | wc -l | tr -d ' ')" "$(other_imports "$f")"
    done
    if [ -f "$CONTROL_FOUNDATION" ] && [ -f "$MODULE" ]; then
        echo ""
        echo "    what the OCCTSwift module imports that a Foundation SwiftWasm module does not:"
        local added
        added="$(comm -13 <(wasi_imports "$CONTROL_FOUNDATION") <(wasi_imports "$MODULE"))"
        if [ -z "$added" ]; then
            echo "      (nothing)"
        else
            echo "$added" | sed 's/^/      /'
        fi
    fi
    if [ -f "$MODULE" ]; then
        echo ""
        echo "    the full list the OCCTSwift module needs:"
        wasi_imports "$MODULE" | tr '\n' ' ' | fold -s -w 88 | sed 's/^/      /'
    fi
}

# ---------------------------------------------------------------------------------------------
case "${1:-all}" in
    build) do_build ;;
    run) do_run ;;
    sjlj) do_sjlj ;;
    controls) do_controls ;;
    size) do_size ;;
    imports) do_imports ;;
    all)
        do_build
        do_run
        do_sjlj
        do_controls
        do_size
        do_imports
        ;;
    *)
        echo "usage: $0 [build|run|sjlj|controls|size|imports|all]" >&2
        exit 1
        ;;
esac

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo ">>> OK"
else
    echo ">>> $FAILURES case(s) failed."
fi
exit "$FAILURES"
