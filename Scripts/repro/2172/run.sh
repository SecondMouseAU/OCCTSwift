#!/bin/bash
#
# #2172: what TKernel does on wasm32-unknown-wasip1, measured rather than sampled.
#
# Four measurements, all against the build tree Scripts/build-occt-wasm.sh --toolkit TKernel leaves
# at Libraries/occt-build-wasm. Run that first; this script reads its generated flags rather than
# restating them, so it cannot drift from the build it describes.
#
#   ./run.sh guards     every diagnostic from every TKernel file that does NOT compile, with
#                       -ferror-limit=0 so the list is complete rather than truncated at 20. This
#                       is the list #2173 consumes.
#   ./run.sh emulation  the same files again with wasi-libc's emulation defines added, to measure
#                       how much of the gap is a link-time flag and how much is real source work.
#                       NOTHING is committed from this: #2172 does not fix these files.
#   ./run.sh negatives  the two flag injections. Without the exception flags a compiled catch
#                       handler disappears from the object; without -mllvm -wasm-enable-sjlj the
#                       setjmp lowering does not happen and the object is left with undefined
#                       `setjmp`/`longjmp`. Both failures are silent at compile time, which is why
#                       they are asserted rather than trusted.
#   ./run.sh archive    archive every object that DID compile and prove the result is a wasm32
#                       archive of wasm objects, with the pinned llvm-ar/llvm-nm and not the host's.
#
# `./run.sh` with no argument runs all four.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="$REPO_DIR/Libraries/occt-build-wasm"
SRC_DIR="$REPO_DIR/Libraries/occt-src"
TK_DIR="$BUILD_DIR/src/FoundationClasses/TKernel/CMakeFiles/TKernel.dir"
TK_SRC="$SRC_DIR/src/FoundationClasses/TKernel"
OUT_DIR="${TMPDIR:-/tmp}/occt-2172"

PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }
TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
NM="$TOOLCHAIN_BIN/llvm-nm"
AR="$TOOLCHAIN_BIN/llvm-ar"

if [ ! -f "$TK_DIR/flags.make" ]; then
    echo "ERROR: no TKernel build tree at $TK_DIR." >&2
    echo "       Run it first:  Scripts/build-occt-wasm.sh --toolkit TKernel" >&2
    exit 1
fi

# The compiler and every flag come out of the build tree CMake generated. Restating them here would
# be a copy that silently stops describing the build the moment either changes.
CXX="$(sed -n 's|^# compile CXX with ||p' "$TK_DIR/flags.make" | head -1)"
CXX_DEFINES="$(sed -n 's/^CXX_DEFINES = //p' "$TK_DIR/flags.make" | head -1)"
CXX_INCLUDES="$(sed -n 's/^CXX_INCLUDES = //p' "$TK_DIR/flags.make" | head -1)"
CXX_FLAGS="$(sed -n 's/^CXX_FLAGS = //p' "$TK_DIR/flags.make" | head -1)"
# The toolchain file sets CMAKE_SYSROOT from SWIFT_WASI_SYSROOT, which is what lands in the cache;
# CMake itself caches no CMAKE_SYSROOT entry, so reading that one would silently yield an empty
# --sysroot and every compile below would fail on `'version' file not found` instead of on the
# platform gap being measured. Asserted rather than assumed, for exactly that reason.
SYSROOT="$(sed -n 's/^SWIFT_WASI_SYSROOT:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
if [ ! -f "$SYSROOT/include/c++/v1/__config_site" ]; then
    echo "ERROR: no WASI sysroot resolved from $BUILD_DIR/CMakeCache.txt (got '$SYSROOT')." >&2
    exit 1
fi

# eval, because CXX_FLAGS carries a quoted -include path that must survive as one argument.
compile() { # compile <src> <obj> [extra flags...]
    local src="$1" obj="$2"; shift 2
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $CXX_FLAGS \
        $* -c \"$src\" -o \"$obj\"" 2>&1
}

# The eight files the build does not compile, derived from the build tree rather than listed:
# every .cxx.obj CMake has a rule for, minus every .obj that exists.
failing_sources() {
    local expected actual
    expected="$(grep -oE 'CMakeFiles/TKernel\.dir/[A-Za-z0-9_/]+\.cxx\.obj' \
        "$TK_DIR/build.make" | sed 's|CMakeFiles/TKernel.dir/||' | sort -u)"
    actual="$(cd "$TK_DIR" && find . -name '*.cxx.obj' | sed 's|^\./||' | sort -u)"
    comm -23 <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/\.obj$//'
}

mkdir -p "$OUT_DIR"

do_guards() {
    echo "===================================================================="
    echo "GUARD SITES: every diagnostic, -ferror-limit=0"
    echo "===================================================================="
    local rel
    for rel in $(failing_sources); do
        echo ""
        echo "-------- $rel --------"
        compile "$TK_SRC/$rel" "$OUT_DIR/$(basename "$rel").obj" -ferror-limit=0 \
            | grep -E '^[^ ].*(error|fatal error):' | sed 's|.*/TKernel/||'
    done
}

do_emulation() {
    echo ""
    echo "===================================================================="
    echo "EMULATION DEFINES: what wasi-libc's emulation alone would close"
    echo "===================================================================="
    echo "(measurement only; #2172 commits none of these, the files belong to #2173)"
    local rel n
    for rel in $(failing_sources); do
        n="$(compile "$TK_SRC/$rel" "$OUT_DIR/emul-$(basename "$rel").obj" -ferror-limit=0 \
              -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_GETPID \
              -D_WASI_EMULATED_PROCESS_CLOCKS \
              | grep -cE '^[^ ].*(error|fatal error):')"
        printf '  %-44s %s errors remain\n' "$rel" "$n"
    done
}

do_negatives() {
    echo ""
    echo "===================================================================="
    echo "NEGATIVE CASES: both flags are load-bearing and both fail silently"
    echo "===================================================================="
    # A file measured to carry a compiled catch handler in the real build.
    local eh_src="$TK_SRC/Storage/Storage_Schema.cxx"
    local strip_eh strip_sjlj
    strip_eh="$(printf '%s' "$CXX_FLAGS" | sed 's/-fwasm-exceptions//; s/-mllvm -wasm-use-legacy-eh=false//')"
    echo ""
    echo "-- Storage_Schema.cxx, exception flags present vs removed"
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $CXX_FLAGS \
        -c \"$eh_src\" -o \"$OUT_DIR/eh-with.obj\"" >/dev/null 2>&1
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $strip_eh \
        -c \"$eh_src\" -o \"$OUT_DIR/eh-without.obj\"" >/dev/null 2>&1
    printf '   with flags:    __cxa_begin_catch x%s\n' \
        "$("$NM" --undefined-only "$OUT_DIR/eh-with.obj" 2>/dev/null | grep -c '__cxa_begin_catch')"
    printf '   without flags: __cxa_begin_catch x%s   <- the handler is gone, no diagnostic\n' \
        "$("$NM" --undefined-only "$OUT_DIR/eh-without.obj" 2>/dev/null | grep -c '__cxa_begin_catch')"

    # A file measured to expand OCC_CATCH_SIGNALS into a real setjmp pair.
    local sj_src="$TK_SRC/OSD/OSD_ThreadPool.cxx"
    strip_sjlj="$(printf '%s' "$CXX_FLAGS" | sed 's/-mllvm -wasm-enable-sjlj//')"
    echo ""
    echo "-- OSD_ThreadPool.cxx, -mllvm -wasm-enable-sjlj present vs removed"
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $CXX_FLAGS \
        -c \"$sj_src\" -o \"$OUT_DIR/sj-with.obj\"" >/dev/null 2>&1
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $strip_sjlj \
        -c \"$sj_src\" -o \"$OUT_DIR/sj-without.obj\"" >/dev/null 2>&1
    printf '   with flag:     %s\n' \
        "$("$NM" --undefined-only "$OUT_DIR/sj-with.obj" 2>/dev/null | grep -oE '__wasm_(setjmp|longjmp|setjmp_test)|^ *U (setjmp|longjmp)$' | sort -u | tr '\n' ' ')"
    printf '   without flag:  %s   <- lowering never happened; the LINK is what fails\n' \
        "$("$NM" --undefined-only "$OUT_DIR/sj-without.obj" 2>/dev/null | grep -oE '__wasm_(setjmp|longjmp|setjmp_test)|(setjmp|longjmp)' | sort -u | tr '\n' ' ')"
}

do_archive() {
    echo ""
    echo "===================================================================="
    echo "ARCHIVE: every object that did compile"
    echo "===================================================================="
    local lib="$BUILD_DIR/libTKernel-partial.a"
    rm -f "$lib"
    # shellcheck disable=SC2046
    (cd "$TK_DIR" && "$AR" rcs "$lib" $(find . -name '*.obj' | sort))
    printf '   %s\n' "$lib"
    printf '   size:    %s bytes\n' "$(wc -c < "$lib" | tr -d ' ')"
    printf '   members: %s\n' "$("$AR" t "$lib" | wc -l | tr -d ' ')"
    local member
    member="$("$AR" t "$lib" | head -1)"
    "$AR" x --output="$OUT_DIR" "$lib" "$member"
    printf '   member %s: %s\n' "$member" "$(file -b "$OUT_DIR/$member")"
    printf '   file(1) on the archive: %s\n' "$(file -b "$lib")"
    # llvm-nm, not the host's nm. There is no llvm-nm on the default macOS PATH, and host `nm -g`
    # on a wasm object lists undefined symbols as though they were defined, which has already
    # produced one wrong conclusion in this initiative.
    printf '   %s --defined-only on that member, first 5:\n' "$(basename "$NM")"
    "$NM" --defined-only "$OUT_DIR/$member" | head -5 | sed 's/^/     /'
    printf '   defined symbols across the whole archive: %s\n' \
        "$("$NM" --defined-only "$lib" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    # wasm32, proved rather than assumed. `file` CANNOT tell wasm32 from wasm64: measured, a
    # wasm64 object and a wasm32-unknown-wasip1 object of the same source produce byte-identical
    # `file` output and identical llvm-nm addresses. What does tell them apart is the width of the
    # memory-address relocations, R_WASM_MEMORY_ADDR_* against the same name suffixed 64. This
    # build is -fPIC, so the relocation is the REL_SLEB form rather than the LEB form; matching the
    # family rather than one spelling is why this reports a number instead of zero, which is what
    # the first attempt at this check did.
    local reloc32 reloc64 o names
    reloc32=0; reloc64=0
    for o in $(cd "$TK_DIR" && find . -name '*.obj' | sort); do
        names="$("$TOOLCHAIN_BIN/llvm-objdump" -r "$TK_DIR/$o" 2>/dev/null \
                 | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u)"
        case "$names" in
            *64) reloc64=$((reloc64 + 1)) ;;
            *64*) reloc64=$((reloc64 + 1)) ;;
            ?*) reloc32=$((reloc32 + 1)) ;;
        esac
    done
    printf '   memory relocations: %s members 32-bit, %s members 64-bit\n' "$reloc32" "$reloc64"

    # The discriminator's own negative case, because a check that reports "0 members 64-bit" is
    # indistinguishable from one that cannot see 64-bit relocations at all.
    printf 'static const char s[] = "x"; const char *f(void){ return s; }\n' > "$OUT_DIR/width.c"
    local w32 w64
    w32="$("$CXX" --target=wasm32-unknown-wasip1 -fPIC -c "$OUT_DIR/width.c" -o "$OUT_DIR/w32.o" 2>/dev/null \
          && "$TOOLCHAIN_BIN/llvm-objdump" -r "$OUT_DIR/w32.o" | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u)"
    w64="$("$CXX" --target=wasm64-unknown-unknown -fPIC -c "$OUT_DIR/width.c" -o "$OUT_DIR/w64.o" 2>/dev/null \
          && "$TOOLCHAIN_BIN/llvm-objdump" -r "$OUT_DIR/w64.o" | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u)"
    printf '   control: a wasm32 object relocates as %s, a wasm64 object as %s\n' "$w32" "$w64"
}

case "${1:-all}" in
    guards)    do_guards ;;
    emulation) do_emulation ;;
    negatives) do_negatives ;;
    archive)   do_archive ;;
    all)       do_guards; do_emulation; do_negatives; do_archive ;;
    *) echo "usage: $0 [guards|emulation|negatives|archive|all]" >&2; exit 1 ;;
esac
