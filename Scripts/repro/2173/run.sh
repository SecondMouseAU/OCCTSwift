#!/bin/bash
#
# #2173: the eight TKernel platform gaps, closed and measured.
#
# Like Scripts/repro/2172/run.sh, this reads the compiler and every flag out of the build tree
# CMake generated rather than restating them, so it cannot drift from the build it describes. Run
# the build first; `complete` below runs it for you.
#
#   ./run.sh guards     compile each of the eight files TWICE, once from its pre-image and once
#                       from the patched tree, and print the error count of each. The pre-image is
#                       read out of git into a scratch copy, so the checkout is never mutated.
#   ./run.sh mman       the Standard_MMgrOpt decision, measured rather than argued: build, link and
#                       RUN the mmap() call that file makes, with -D_WASI_EMULATED_MMAN and
#                       -lwasi-emulated-mman, against the pinned toolchain.
#   ./run.sh complete   run Scripts/build-occt-wasm.sh --toolkit TKernel --require-complete and
#                       report what it says.
#   ./run.sh negative   prove --require-complete fails on an incomplete build: hide one WASI patch,
#                       rebuild, expect a non-zero exit naming the shortfall, restore the patch.
#                       The restore is on a trap, so an interrupted run still puts it back.
#   ./run.sh archive    the real libTKernel.a, inspected with the PINNED llvm-ar/llvm-nm and not
#                       the host's.
#
# `./run.sh` with no argument runs guards, mman and archive, which need no rebuild.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BUILD_DIR="$REPO_DIR/Libraries/occt-build-wasm"
SRC_DIR="$REPO_DIR/Libraries/occt-src"
TK_DIR="$BUILD_DIR/src/FoundationClasses/TKernel/CMakeFiles/TKernel.dir"
TK_SRC="$SRC_DIR/src/FoundationClasses/TKernel"
OUT_DIR="${TMPDIR:-/tmp}/occt-2173"

PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }
TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
NM="$TOOLCHAIN_BIN/llvm-nm"
AR="$TOOLCHAIN_BIN/llvm-ar"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"

# The eight files #2172 measured, with the patch that closes each. Listed here because this is the
# list the issue is about; every number below is derived, but the subject is not.
GAPS="
Message/Message_PrinterSystemLog.cxx:wasi-message-printersyslog.patch
OSD/OSD_File.cxx:wasi-osd-file.patch
OSD/OSD_Host.cxx:wasi-osd-host.patch
OSD/OSD_Path.cxx:wasi-osd-path.patch
OSD/OSD_Process.cxx:wasi-osd-process.patch
OSD/OSD_signal.cxx:wasi-osd-signal.patch
Standard/Standard_MMgrOpt.cxx:wasi-standard-mmgropt.patch
Standard/Standard_StackTrace.cxx:wasi-standard-stacktrace.patch
"

if [ ! -f "$TK_DIR/flags.make" ]; then
    echo "ERROR: no TKernel build tree at $TK_DIR." >&2
    echo "       Run it first:  Scripts/build-occt-wasm.sh --toolkit TKernel --require-complete" >&2
    exit 1
fi

CXX="$(sed -n 's|^# compile CXX with ||p' "$TK_DIR/flags.make" | head -1)"
CXX_DEFINES="$(sed -n 's/^CXX_DEFINES = //p' "$TK_DIR/flags.make" | head -1)"
CXX_INCLUDES="$(sed -n 's/^CXX_INCLUDES = //p' "$TK_DIR/flags.make" | head -1)"
CXX_FLAGS="$(sed -n 's/^CXX_FLAGS = //p' "$TK_DIR/flags.make" | head -1)"
# Read from the cache, not guessed: CMake caches no CMAKE_SYSROOT entry of its own, so reading that
# one would silently yield an empty --sysroot and every compile below would fail on a missing
# `version` header instead of on the thing being measured (the same trap Scripts/repro/2172 names).
SYSROOT="$(sed -n 's/^SWIFT_WASI_SYSROOT:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
if [ ! -f "$SYSROOT/include/c++/v1/__config_site" ]; then
    echo "ERROR: no WASI sysroot resolved from $BUILD_DIR/CMakeCache.txt (got '$SYSROOT')." >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

# eval, because CXX_FLAGS carries a quoted -include path that must survive as one argument.
compile() { # compile <src> <obj> [extra flags...]
    local src="$1" obj="$2"; shift 2
    eval "\"$CXX\" --target=\"$TRIPLE\" --sysroot=\"$SYSROOT\" $CXX_DEFINES $CXX_INCLUDES $CXX_FLAGS \
        $* -c \"$src\" -o \"$obj\"" 2>&1
}

count_errors() { grep -cE '^[^ ].*(error|fatal error):' || true; }

do_guards() {
    echo "===================================================================="
    echo "GUARD SITES: every one of the eight, before and after its patch"
    echo "===================================================================="
    echo "(the 'before' file is git's copy of the pre-image, compiled in $OUT_DIR;"
    echo " $SRC_DIR is never mutated by this script)"
    local entry rel patch before after pre
    for entry in $GAPS; do
        rel="${entry%%:*}"
        patch="${entry##*:}"
        pre="$OUT_DIR/pre-$(basename "$rel")"
        # HEAD is V8_0_1, and no carried patch touches any of these eight, so git's copy IS the
        # carried-patch state for them. Asserted rather than assumed: a carried patch that starts
        # touching one of these files would make the next line the wrong pre-image, and
        # check-wasi-patch-base.py would report the collision as CARRIED_COLLISION first.
        git -C "$SRC_DIR" show "HEAD:src/FoundationClasses/TKernel/$rel" > "$pre" 2>/dev/null
        before="$(compile "$pre" "$OUT_DIR/before-$(basename "$rel").obj" -ferror-limit=0 | count_errors)"
        after="$(compile "$TK_SRC/$rel" "$OUT_DIR/after-$(basename "$rel").obj" -ferror-limit=0 | count_errors)"
        printf '  %-42s  before %2s errors -> after %2s   (%s)\n' "$rel" "$before" "$after" "$patch"
    done
}

do_mman() {
    echo ""
    echo "===================================================================="
    echo "THE Standard_MMgrOpt DECISION: -D_WASI_EMULATED_MMAN, measured"
    echo "===================================================================="
    local builtins sdk_id
    sdk_id="$(pin SWIFT_WASM_SDK_ID)"
    builtins="${WASI_SWIFT_BUILTINS_DIR:-$HOME/.swiftpm/swift-sdks/$sdk_id.artifactbundle/$sdk_id/$TRIPLE/swift.xctoolchain/usr/lib/clang/lib/wasip1}"
    if [ ! -f "$builtins/libclang_rt.builtins-wasm32.a" ]; then
        echo "  SKIPPED: no wasm32 compiler-rt builtins at $builtins" >&2
        return 1
    fi
    # -nodefaultlibs plus the three archives by name: the swift.org toolchain's clang looks for its
    # builtins under its OWN resource dir, where the wasm32 ones are not, and --resource-dir cannot
    # be repointed without also losing its stddef.h. This is the same set link_directories() hands
    # the CMake build.
    "$TOOLCHAIN_BIN/clang" --target="$TRIPLE" --sysroot="$SYSROOT" -D_WASI_EMULATED_MMAN \
        -nodefaultlibs "$SCRIPT_DIR/probe-mman.c" \
        -lc -lwasi-emulated-mman "$builtins/libclang_rt.builtins-wasm32.a" \
        -o "$OUT_DIR/probe-mman.wasm" || return 1
    "$TOOLCHAIN_BIN/wasmkit" run "$OUT_DIR/probe-mman.wasm"
}

do_complete() {
    echo ""
    echo "===================================================================="
    echo "THE BUILD: --require-complete"
    echo "===================================================================="
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --toolkit TKernel --require-complete
    printf '   exit status: %s\n' "$?"
}

do_negative() {
    echo ""
    echo "===================================================================="
    echo "NEGATIVE CASE: --require-complete on an incomplete build"
    echo "===================================================================="
    local victim="$REPO_DIR/Scripts/patches-wasi/wasi-standard-stacktrace.patch"
    local stash="$OUT_DIR/$(basename "$victim").hidden"
    # shellcheck disable=SC2064
    trap "mv -f '$stash' '$victim' 2>/dev/null; git -C '$SRC_DIR' checkout -- src/FoundationClasses/TKernel/Standard/Standard_StackTrace.cxx 2>/dev/null" EXIT INT TERM
    git -C "$SRC_DIR" checkout -- src/FoundationClasses/TKernel/Standard/Standard_StackTrace.cxx
    mv -f "$victim" "$stash"
    echo "  hidden: $(basename "$victim"); Standard_StackTrace.cxx is back at its pre-image"
    set +e
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --toolkit TKernel --require-complete > "$OUT_DIR/negative.log" 2>&1
    local rc=$?
    set -e
    printf '  exit status: %s  (0 would mean the flag does not work)\n' "$rc"
    grep -E 'ERROR: --require-complete|source files compiled' "$OUT_DIR/negative.log" | sed 's/^/  /'
    mv -f "$stash" "$victim"
    trap - EXIT INT TERM
    echo "  restored: $(basename "$victim")"
    echo "  rebuilding to leave the tree complete again..."
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --toolkit TKernel --require-complete \
        > "$OUT_DIR/negative-restore.log" 2>&1
    printf '  restore build exit status: %s\n' "$?"
    grep -E 'COMPLETE:' "$OUT_DIR/negative-restore.log" | sed 's/^/  /'
}

do_archive() {
    echo ""
    echo "===================================================================="
    echo "THE ARCHIVE: a complete libTKernel.a, with the pinned tools"
    echo "===================================================================="
    local lib
    lib="$(find "$BUILD_DIR" -name 'libTKernel.a' -print -quit)"
    if [ -z "$lib" ]; then
        echo "  no libTKernel.a under $BUILD_DIR; only a -partial.a means the build is short" >&2
        find "$BUILD_DIR" -name 'libTKernel*.a' | sed 's/^/  /' >&2
        return 1
    fi
    printf '   %s\n' "$lib"
    printf '   size:    %s bytes\n' "$(wc -c < "$lib" | tr -d ' ')"
    printf '   members: %s\n' "$("$AR" t "$lib" | wc -l | tr -d ' ')"
    printf '   defined symbols across the archive: %s\n' \
        "$("$NM" --defined-only "$lib" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    local member
    member="$("$AR" t "$lib" | head -1)"
    "$AR" x --output="$OUT_DIR" "$lib" "$member"
    printf '   member %s: %s\n' "$member" "$(file -b "$OUT_DIR/$member")"
    # wasm32 proved by relocation width, not by file(1): measured in #2172, a wasm64 object and a
    # wasm32-unknown-wasip1 object of the same source produce byte-identical file(1) output.
    local reloc32 reloc64 names o
    reloc32=0; reloc64=0
    while IFS= read -r -d '' o; do
        names="$("$TOOLCHAIN_BIN/llvm-objdump" -r "$o" 2>/dev/null \
                 | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u)"
        case "$names" in
            *64) reloc64=$((reloc64 + 1)) ;;
            ?*)  reloc32=$((reloc32 + 1)) ;;
        esac
    done < <(find "$TK_DIR" -name '*.obj' -print0)
    printf '   memory relocations: %s members 32-bit, %s members 64-bit\n' "$reloc32" "$reloc64"
    # The eight are IN the archive, named rather than counted.
    local entry rel
    echo "   the eight, as members:"
    for entry in $GAPS; do
        rel="${entry%%:*}"
        printf '     %-42s %s\n' "$rel" \
            "$("$AR" t "$lib" | grep -c "$(basename "$rel").obj$") member(s)"
    done
}

case "${1:-default}" in
    guards)   do_guards ;;
    mman)     do_mman ;;
    complete) do_complete ;;
    negative) do_negative ;;
    archive)  do_archive ;;
    default)  do_guards; do_mman; do_archive ;;
    all)      do_guards; do_mman; do_complete; do_negative; do_archive ;;
    *) echo "usage: $0 [guards|mman|complete|negative|archive|all]" >&2; exit 1 ;;
esac
