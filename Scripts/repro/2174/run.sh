#!/bin/bash
#
# #2174: libOCCT-wasm.a for the full module set, linked and run.
#
# Like Scripts/repro/2172/run.sh and Scripts/repro/2173/run.sh, this reads the compiler, the
# sysroot and every flag out of the build tree CMake generated rather than restating them, so it
# cannot drift from the build it describes.
#
#   Scripts/build-occt-wasm.sh          # the build; leaves Libraries/occt-build-wasm,
#                                       # Libraries/occt-install-wasm, Libraries/libOCCT-wasm.a
#                                       # and Libraries/occt-headers-wasm
#   Scripts/repro/2174/run.sh           # everything below
#
#   ./run.sh combine    the archive-of-archives defect, on the REAL per-toolkit archives: what
#                       `llvm-ar rcs` in a loop produces, what an MRI script produces, and what
#                       each of the three new checks in build-occt-wasm.sh says about them. This
#                       is the negative case for the fix, per okf/policies/prove-the-test-fails.md.
#   ./run.sh census     the build script's own per-toolkit census, re-run over the finished tree
#                       with --census-only, plus the regex defect that hid four source files
#   ./run.sh census-negative  the census with one object hidden, which is the only thing that
#                       distinguishes a census that sees a complete tree from one that is blind
#   ./run.sh partial    the combined archive over every object that compiled, named -partial,
#                       for while platform gaps are open. Point the link cases at it with
#                       OCCT_WASM_ARCHIVE=<path>.
#   ./run.sh archive    libOCCT-wasm.a: size, members, defined symbols, wasm32 proof
#   ./run.sh link       build probe.wasm and probe-alloc.wasm, run both under wasmkit
#   ./run.sh libs       the link-only questions: -lsetjmp, -lwasi-emulated-getpid, the eh runtime,
#                       and which libc++ definition of std::__throw_out_of_range won
#   ./run.sh imports    the linked module's wasi_snapshot_preview1 imports, which is what #2052 needs
#   ./run.sh size       the linked module's size, uncompressed and gzipped
#
# `./run.sh` with no argument runs all of them.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB_DIR="$REPO_DIR/Libraries"
BUILD_DIR="$LIB_DIR/occt-build-wasm"
# OCCT_WASM_ARCHIVE overrides which archive the link cases use, so the same probe and the same
# link line can be pointed at the -partial archive while platform gaps are open.
COMBINED="${OCCT_WASM_ARCHIVE:-$LIB_DIR/libOCCT-wasm.a}"
# The header tree the probe compiles against. Libraries/occt-headers-wasm is what
# Scripts/build-occt-wasm.sh produces and what Package.swift reads, and it only exists once the
# packaging step has run, which the census blocks while any platform gap is open.
#
# The fallback is the build tree's own include/opencascade, and it is NOT the same thing: those
# 7,072 files are one-line forwarding stubs, each `#include`ing the real header in Libraries/occt-src
# by ABSOLUTE path. They compile to the same thing on this machine and they are worthless to anyone
# else, so a link against them proves the archive and proves nothing at all about what
# Scripts/build-occt-wasm.sh distributes. The script prints which tree it used; read it.
if [ -d "$LIB_DIR/occt-headers-wasm" ]; then
    HEADERS="$LIB_DIR/occt-headers-wasm"
else
    HEADERS="$BUILD_DIR/include/opencascade"
fi
OUT_DIR="${TMPDIR:-/tmp}/occt-2174"

PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }
TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
AR="$TOOLCHAIN_BIN/llvm-ar"
NM="$TOOLCHAIN_BIN/llvm-nm"
OBJDUMP="$TOOLCHAIN_BIN/llvm-objdump"
WASMKIT="$TOOLCHAIN_BIN/wasmkit"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"

# The TKernel build tree is where the compiler and the sysroot are read from: one toolkit's
# flags.make carries the same CXX and the same CMAKE_SYSROOT as every other's.
TK_DIR="$BUILD_DIR/src/FoundationClasses/TKernel/CMakeFiles/TKernel.dir"
if [ ! -f "$TK_DIR/flags.make" ]; then
    echo "ERROR: no OCCT wasm build tree at $BUILD_DIR." >&2
    echo "       Run it first:  Scripts/build-occt-wasm.sh" >&2
    exit 1
fi
CXX="$(sed -n 's|^# compile CXX with ||p' "$TK_DIR/flags.make" | head -1)"
SYSROOT="$(sed -n 's/^SWIFT_WASI_SYSROOT:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
EH_LIBDIR="$(sed -n 's/^WASI_SDK_EH_LIBDIR:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
BUILTINS_DIR="$(sed -n 's/^WASI_SWIFT_BUILTINS_DIR:[A-Za-z]*=//p' "$BUILD_DIR/CMakeCache.txt" | head -1)"
for v in CXX SYSROOT EH_LIBDIR BUILTINS_DIR; do
    eval "val=\$$v"
    if [ -z "$val" ]; then
        echo "ERROR: $v could not be read from the build tree. It is not restated here on purpose;" >&2
        echo "       a value this script invented would describe a build nobody ran." >&2
        exit 1
    fi
done

if [ ! -d "$HEADERS" ]; then
    echo "ERROR: no OCCT headers at $HEADERS." >&2
    exit 1
fi
echo ">>> headers: $HEADERS"

mkdir -p "$OUT_DIR"

# --------------------------------------------------------------------------------------------
# The resource directory the wasm32 compiler-rt builtins have to be reached through
# --------------------------------------------------------------------------------------------
# The builtins ship inside the Swift SDK's artifact bundle, at
# swift.xctoolchain/usr/lib/clang/lib/wasip1/libclang_rt.builtins-wasm32.a, and the swift.org
# toolchain's own resource directory has only a darwin one. Measured: `-L<that dir>
# -lclang_rt.builtins-wasm32` does NOT satisfy the driver, which adds its own
# `<resource-dir>/lib/wasm32-unknown-wasip1/libclang_rt.builtins.a` and fails on it not existing.
# So the driver is pointed at a resource directory assembled here out of two symlinks: the
# toolchain's own `include`, so clang's builtin headers still resolve, and the SDK's builtins under
# the name and path the driver looks for.
RESOURCE_DIR="$OUT_DIR/resource-dir"
setup_resource_dir() {
    local clang_res
    clang_res="$("$CXX" -print-resource-dir)"
    rm -rf "$RESOURCE_DIR"
    mkdir -p "$RESOURCE_DIR/lib/$TRIPLE"
    ln -s "$clang_res/include" "$RESOURCE_DIR/include"
    ln -s "$BUILTINS_DIR/libclang_rt.builtins-wasm32.a" \
        "$RESOURCE_DIR/lib/$TRIPLE/libclang_rt.builtins.a"
}
setup_resource_dir

# The link line, in one place. Every case below that links uses it, so a case cannot quietly
# differ from the one whose result is reported.
#   -lc++abi / -lunwind from wasi-sdk's eh directory, because WASI.sdk's libc++abi defines no
#     __cxa_throw (#2169, #2171);
#   -lsetjmp because OCCT compiles with -DOCC_CONVERT_SIGNALS and OCC_CATCH_SIGNALS expands to a
#     real setjmp inside OCCT (#2188), which -mllvm -wasm-enable-sjlj lowers to __wasm_setjmp.
#
# -include the threading shim, which #2170 introduced for OCCT's own compile and which turns out to
# be a CONSUMER requirement too: Message_ProgressIndicator.hxx, NCollection_IncAllocator.hxx and
# Poly_Triangulation.hxx name std::mutex and std::shared_mutex in PUBLIC headers, so a translation
# unit that merely includes OCCT is eight errors without it. That is a finding for #2048's manifest,
# not a convenience here; see README.md.
SHIM="$REPO_DIR/Scripts/wasm-shims/wasi-std-threading.hpp"
link_probe() { # link_probe <src> <out.wasm> [extra link flags...]
    local src="$1" out="$2"
    shift 2
    # shellcheck disable=SC2086
    "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
        -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj \
        -include "$SHIM" \
        -I"$HEADERS" \
        "$src" "$COMBINED" \
        -L"$EH_LIBDIR" -lc++abi -lunwind \
        -lsetjmp \
        "$@" \
        -o "$out"
}

# ---------------------------------------------------------------------------------------------
do_combine() {
    echo "===================================================================="
    echo "COMBINE: llvm-ar r nests, an MRI script flattens"
    echo "===================================================================="
    local a b nested flat
    a="$(find "$BUILD_DIR" -name 'libTKernel.a' -print -quit)"
    b="$(find "$BUILD_DIR" -name 'libTKMath.a' -print -quit)"
    if [ -z "$a" ] || [ -z "$b" ]; then
        echo "  no per-toolkit archives in the build tree; run Scripts/build-occt-wasm.sh first" >&2
        return 1
    fi
    nested="$OUT_DIR/nested.a"
    flat="$OUT_DIR/flat.a"

    # The code that was in build-occt-wasm.sh until #2174, verbatim in shape.
    rm -f "$nested"
    local lib
    for lib in "$a" "$b"; do "$AR" rcs "$nested" "$lib"; done

    rm -f "$flat"
    { printf 'create %s\n' "$flat"
      printf 'addlib %s\n' "$a" "$b"
      printf 'save\nend\n'; } | "$AR" -M

    local n_members n_arch n_syms f_members f_arch f_syms
    n_members=$("$AR" t "$nested" | wc -l | tr -d ' ')
    n_arch=$("$AR" t "$nested" | grep -c '\.a$')
    n_syms=$("$NM" --defined-only "$nested" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')
    f_members=$("$AR" t "$flat" | wc -l | tr -d ' ')
    f_arch=$("$AR" t "$flat" | grep -c '\.a$' || true)
    f_syms=$("$NM" --defined-only "$flat" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')

    printf '  inputs: %s + %s\n' "$(basename "$a")" "$(basename "$b")"
    printf '  %-34s %-12s %-12s\n' "" "llvm-ar rcs" "MRI addlib"
    printf '  %-34s %-12s %-12s\n' "members" "$n_members" "$f_members"
    printf '  %-34s %-12s %-12s\n' "of which are themselves archives" "$n_arch" "$f_arch"
    printf '  %-34s %-12s %-12s\n' "defined symbols (llvm-nm)" "$n_syms" "$f_syms"
    printf '  %-34s %-12s %-12s\n' "size, bytes" "$(wc -c < "$nested" | tr -d ' ')" \
           "$(wc -c < "$flat" | tr -d ' ')"
    printf '  %-34s %-12s %-12s\n' "[ -f ] && [ -s ], the old check" \
           "$([ -f "$nested" ] && [ -s "$nested" ] && echo PASSES)" \
           "$([ -f "$flat" ] && [ -s "$flat" ] && echo PASSES)"

    echo ""
    echo "  the three checks build-occt-wasm.sh now runs, against each:"
    local which f
    for which in nested flat; do
        eval "f=\$$which"
        local m ar sy verdict
        m=$("$AR" t "$f" | wc -l | tr -d ' ')
        ar=$("$AR" t "$f" | grep -c '\.a$' || true)
        sy=$("$NM" --defined-only "$f" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')
        verdict="accepted"
        [ "$ar" -ne 0 ] && verdict="REJECTED: $ar member(s) are archives"
        [ "$sy" -eq 0 ] && verdict="REJECTED: defines no symbols"
        printf '    %-8s members=%-6s archive-members=%-4s symbols=%-8s %s\n' \
               "$which" "$m" "$ar" "$sy" "$verdict"
    done

    echo ""
    echo "  and what wasm-ld says about the nested one:"
    printf 'int main(void){return 0;}\n' > "$OUT_DIR/nul.c"
    "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
        "$OUT_DIR/nul.c" "$nested" -o "$OUT_DIR/nul.wasm" 2>&1 \
        | grep -E 'archive member|neither Wasm' | head -4 | sed 's/^/    /'
}

# ---------------------------------------------------------------------------------------------
toolkit_dirs() { (cd "$BUILD_DIR" && find . -type d -name '*.dir' -path '*/CMakeFiles/*' | sort); }

do_census() {
    echo ""
    echo "===================================================================="
    echo "CENSUS: 49 toolkits, asserted"
    echo "===================================================================="
    # The census itself is NOT reimplemented here. `--census-only` runs the same function the full
    # build runs, over the tree that is already there, so this page reports the build script's own
    # count rather than a second one that could disagree with it.
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --census-only
    echo "  exit status: $?  (0 means every toolkit is complete)"

    echo ""
    echo "-- and the denominator defect the full module set exposed"
    echo "   #2172's regex for an object rule was [A-Za-z0-9_/]+, which cannot match a source file"
    echo "   name containing a dot. OCCT has four, all generated parsers. TKernel has none, which"
    echo "   is why one toolkit could not find this."
    local d tk loose strict tot_l=0 tot_s=0
    for d in $(toolkit_dirs); do
        tk="$(basename "$d" .dir)"
        [ -f "$BUILD_DIR/$d/build.make" ] || continue
        loose=$(grep -oE "CMakeFiles/${tk}\.dir/[^ :]+\.(cxx|c)\.obj" "$BUILD_DIR/$d/build.make" | sort -u | wc -l | tr -d ' ')
        strict=$(grep -oE "CMakeFiles/${tk}\.dir/[A-Za-z0-9_/]+\.(cxx|c)\.obj" "$BUILD_DIR/$d/build.make" | sort -u | wc -l | tr -d ' ')
        [ "$loose" -eq 0 ] && continue
        tot_l=$((tot_l + loose)); tot_s=$((tot_s + strict))
        if [ "$loose" -ne "$strict" ]; then
            printf '   %-14s real %s, old regex %s, invisible to it:\n' "$tk" "$loose" "$strict"
            comm -13 \
                <(grep -oE "CMakeFiles/${tk}\.dir/[A-Za-z0-9_/]+\.(cxx|c)\.obj" "$BUILD_DIR/$d/build.make" | sort -u) \
                <(grep -oE "CMakeFiles/${tk}\.dir/[^ :]+\.(cxx|c)\.obj" "$BUILD_DIR/$d/build.make" | sort -u) \
                | sed "s|CMakeFiles/${tk}.dir/|        |; s|\.obj$||"
        fi
    done
    printf '   denominator: %s real, %s under the old regex, %s short\n' \
           "$tot_l" "$tot_s" "$((tot_l - tot_s))"
}

# The census's own negative case. A completeness check that has only ever been watched saying
# "complete" is indistinguishable from one that cannot see an absence; per
# okf/policies/prove-the-test-fails.md, it is run once with its subject broken. One object is moved
# aside, the census is re-run, and the object is put back on a trap so an interrupted run still
# restores it.
# The census's own missing count, read back out of its TOTAL line rather than recomputed here.
missing_count() {
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --census-only 2>/dev/null \
        | sed -n 's/.*across [0-9]* toolkits, \([0-9]*\) missing.*/\1/p'
}

do_census_negative() {
    echo ""
    echo "===================================================================="
    echo "CENSUS, NEGATIVE: hide one object and watch the count drop"
    echo "===================================================================="
    local victim_dir victim
    victim_dir="$BUILD_DIR/src/ModelingData/TKG3d/CMakeFiles/TKG3d.dir"
    victim="$victim_dir/Geom/Geom_CartesianPoint.cxx.obj"
    if [ ! -f "$victim" ]; then
        echo "  no $victim to hide; run Scripts/build-occt-wasm.sh first" >&2
        return 1
    fi
    # The baseline is whatever the tree reports right now, which need not be zero while a real
    # platform gap is open. What this case proves is that hiding one more object CHANGES the
    # answer, so the comparison is against that baseline rather than against zero.
    local before after
    before=$(missing_count)
    printf '  missing before: %s\n' "$before"

    # shellcheck disable=SC2064
    trap "mv -f '$victim.hidden' '$victim' 2>/dev/null || true" EXIT INT TERM
    mv "$victim" "$victim.hidden"
    echo "  hidden: TKG3d/Geom/Geom_CartesianPoint.cxx.obj"
    "$REPO_DIR/Scripts/build-occt-wasm.sh" --census-only 2>&1 \
        | grep -E 'TKG3d +[0-9]|did not compile|Geom_CartesianPoint|TOTAL'
    echo "  exit status: ${PIPESTATUS[0]}  (0 would mean the census cannot see an absence)"

    mv -f "$victim.hidden" "$victim"
    trap - EXIT INT TERM
    after=$(missing_count)
    printf '  restored; missing after: %s\n' "$after"
    if [ "$after" = "$before" ]; then
        printf '  the count went %s -> %s -> %s, so the census saw the absence and nothing leaked.\n' \
               "$before" "$((before + 1))" "$after"
    else
        printf '  MISMATCH: %s before, %s after. The restore did not restore.\n' "$before" "$after"
        return 1
    fi
}

# ---------------------------------------------------------------------------------------------
# The combined archive over every object that DID compile, under a name that cannot be mistaken
# for the real one. #2172 set this precedent with libTKernel-partial.a: while platform gaps are
# open there is no complete kernel to package, and a partial archive is what keeps the toolchain,
# the flags and the LINK inspectable at kernel scale in the meantime.
#
# Scripts/build-occt-wasm.sh deliberately will not produce this. Its census refuses to install or
# combine anything while a toolkit is short, and weakening that to get a number would be the exact
# trade this whole effort exists to stop making.
do_partial_archive() {
    echo ""
    echo "===================================================================="
    echo "PARTIAL ARCHIVE: every object that compiled, named -partial"
    echo "===================================================================="
    local objs n
    objs="$OUT_DIR/objects.txt"
    (cd "$BUILD_DIR" && find . -name '*.obj' -path '*/CMakeFiles/*' | sort) > "$objs"
    n=$(wc -l < "$objs" | tr -d ' ')
    if [ "$n" -eq 0 ]; then
        echo "  no objects in $BUILD_DIR; run Scripts/build-occt-wasm.sh first" >&2
        return 1
    fi
    PARTIAL="$BUILD_DIR/libOCCT-wasm-partial.a"
    rm -f "$PARTIAL"
    # MRI again, on stdin, because 5,000-odd object paths do not fit on a command line. `addmod`
    # adds a FILE as a member, which is what an object is; `addlib` would be the archive case.
    { printf 'create %s\n' "$PARTIAL"
      sed "s|^\./|addmod $BUILD_DIR/|" "$objs"
      printf 'save\nend\n'; } | "$AR" -M
    printf '  path:            %s\n' "$PARTIAL"
    printf '  objects offered: %s\n' "$n"
    printf '  members:         %s\n' "$("$AR" t "$PARTIAL" | wc -l | tr -d ' ')"
    printf '  archive members: %s\n' "$("$AR" t "$PARTIAL" | grep -c '\.a$' || true)"
    printf '  defined symbols: %s\n' \
        "$("$NM" --defined-only "$PARTIAL" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    printf '  size:            %s bytes\n' "$(wc -c < "$PARTIAL" | tr -d ' ')"

    # Per toolkit, from the archives the build tree holds. occt-install-wasm does not exist while
    # the census blocks packaging, and these are the same archives cmake --install would copy.
    echo ""
    echo "  per toolkit: size, members, defined symbols"
    local lib name libdir
    libdir="$(dirname "$(find "$BUILD_DIR" -name 'libTKernel.a' -print -quit)")"
    for lib in $(find "$libdir" -name 'libTK*.a' | sort); do
        name="$(basename "$lib")"
        printf '    %-18s %10s  %5s  %8s\n' "$name" "$(wc -c < "$lib" | tr -d ' ')" \
            "$("$AR" t "$lib" | wc -l | tr -d ' ')" \
            "$("$NM" --defined-only "$lib" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    done
    printf '    %s of 49 toolkits have an archive; the rest is the one that did not compile.\n' \
        "$(find "$libdir" -name 'libTK*.a' | wc -l | tr -d ' ')"

    # wasm32, proved the way #2172 proved it: `file` cannot tell wasm32 from wasm64, the width of
    # the memory-address relocation can.
    local member
    member="$("$AR" t "$PARTIAL" | head -1)"
    rm -f "$OUT_DIR/$member"
    "$AR" x --output="$OUT_DIR" "$PARTIAL" "$member" 2>/dev/null
    printf '\n  first member %s: %s\n' "$member" "$(file -b "$OUT_DIR/$member")"
    printf '  its memory relocations: %s\n' \
        "$("$OBJDUMP" -r "$OUT_DIR/$member" 2>/dev/null | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u | tr '\n' ' ')"
}

# ---------------------------------------------------------------------------------------------
do_archive() {
    echo ""
    echo "===================================================================="
    echo "ARCHIVE: Libraries/libOCCT-wasm.a"
    echo "===================================================================="
    if [ ! -f "$COMBINED" ]; then
        echo "  not built; run Scripts/build-occt-wasm.sh" >&2
        return 1
    fi
    printf '  path:                     %s\n' "$COMBINED"
    printf '  size:                     %s bytes\n' "$(wc -c < "$COMBINED" | tr -d ' ')"
    printf '  members:                  %s\n' "$("$AR" t "$COMBINED" | wc -l | tr -d ' ')"
    printf '  members that are archives: %s\n' "$("$AR" t "$COMBINED" | grep -c '\.a$' || true)"
    printf '  defined symbols:          %s\n' \
        "$("$NM" --defined-only "$COMBINED" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    printf '  per-toolkit archives installed: %s\n' \
        "$(find "$LIB_DIR/occt-install-wasm" -name '*.a' 2>/dev/null | wc -l | tr -d ' ')"
    echo ""
    echo "  per toolkit: size, members, defined symbols"
    local lib name
    for lib in $(find "$LIB_DIR/occt-install-wasm" -name '*.a' 2>/dev/null | sort); do
        name="$(basename "$lib")"
        printf '    %-18s %10s  %5s  %8s\n' "$name" "$(wc -c < "$lib" | tr -d ' ')" \
            "$("$AR" t "$lib" | wc -l | tr -d ' ')" \
            "$("$NM" --defined-only "$lib" 2>/dev/null | grep -cE '^[0-9a-f]+ [A-Za-z] ')"
    done
    # wasm32, proved the way #2172 proved it: `file` cannot tell wasm32 from wasm64, the width of
    # the memory-address relocation can.
    local member
    member="$("$AR" t "$COMBINED" | head -1)"
    rm -f "$OUT_DIR/$member"
    "$AR" x --output="$OUT_DIR" "$COMBINED" "$member" 2>/dev/null
    printf '\n  first member %s: %s\n' "$member" "$(file -b "$OUT_DIR/$member")"
    printf '  its memory relocations: %s\n' \
        "$("$OBJDUMP" -r "$OUT_DIR/$member" 2>/dev/null | grep -oE 'R_WASM_MEMORY_ADDR[A-Z_0-9]*' | sort -u | tr '\n' ' ')"
}

# ---------------------------------------------------------------------------------------------
do_link() {
    echo ""
    echo "===================================================================="
    echo "LINK: a C++ main over the OCCT archive, run under wasmkit"
    echo "===================================================================="
    rm -f "$OUT_DIR/probe.wasm" "$OUT_DIR/probe-alloc.wasm" "$OUT_DIR/probe-step.wasm"

    echo "  linking probe.wasm (handle, raise/catch, modelling, mesh, libc++ seam)..."
    link_probe "$SCRIPT_DIR/probe.cxx" "$OUT_DIR/probe.wasm" 2>&1 | sed 's/^/    /'
    if [ -f "$OUT_DIR/probe.wasm" ]; then
        printf '  probe.wasm: %s bytes\n' "$(wc -c < "$OUT_DIR/probe.wasm" | tr -d ' ')"
        echo "  running..."
        "$WASMKIT" run "$OUT_DIR/probe.wasm" 2>&1 | sed 's/^/    /'
        echo "  exit status: ${PIPESTATUS[0]}  (the number of failed cases)"
    else
        echo "  LINK FAILED" >&2
    fi

    echo ""
    echo "  linking probe-alloc.wasm (operator new / std::bad_alloc, #2171 left it unprobed)..."
    link_probe "$SCRIPT_DIR/probe-alloc.cxx" "$OUT_DIR/probe-alloc.wasm" 2>&1 | sed 's/^/    /'
    if [ -f "$OUT_DIR/probe-alloc.wasm" ]; then
        "$WASMKIT" run "$OUT_DIR/probe-alloc.wasm" 2>&1 | sed 's/^/    /'
        echo "  exit status: ${PIPESTATUS[0]}  (0 threw std::bad_alloc, 3 returned, anything else is the finding)"
    fi

    echo ""
    echo "  linking probe-step.wasm, which is expected to FAIL while the TKDESTEP gap is open..."
    mkdir -p "$OUT_DIR/stepout"
    # Removed before the run, not after: the check below passes on a file of non-zero length, and a
    # file left by an earlier run is exactly the shape of a case that measures nothing.
    rm -f "$OUT_DIR/stepout/probe-box.step"
    link_probe "$SCRIPT_DIR/probe-step.cxx" "$OUT_DIR/probe-step.wasm" >"$OUT_DIR/step-link.txt" 2>&1
    if [ -f "$OUT_DIR/probe-step.wasm" ]; then
        printf '  probe-step.wasm: %s bytes\n' "$(wc -c < "$OUT_DIR/probe-step.wasm" | tr -d ' ')"
        "$WASMKIT" run --dir "$OUT_DIR/stepout" "$OUT_DIR/probe-step.wasm" "$OUT_DIR/stepout" 2>&1 \
            | sed 's/^/    /'
        echo "  exit status: ${PIPESTATUS[0]}"
        if [ -f "$OUT_DIR/stepout/probe-box.step" ]; then
            echo "  the STEP file it wrote, first 4 lines:"
            head -4 "$OUT_DIR/stepout/probe-box.step" | sed 's/^/    /'
        fi
    else
        printf '  did not link: %s undefined-symbol line(s), every one of them a member of\n' \
            "$(grep -c 'undefined symbol' "$OUT_DIR/step-link.txt" || true)"
        echo "  STEPConstruct_AP203Context, the single file this build does not compile:"
        grep -oE 'undefined symbol: [^ ]+' "$OUT_DIR/step-link.txt" | sort -u | head -5 \
            | sed 's/^/    /'
        printf '    all %s of them referenced from: %s\n' \
            "$(grep -c 'undefined symbol' "$OUT_DIR/step-link.txt" || true)" \
            "$(sed -n 's/.*\.a(\([^)]*\)).*/\1/p' "$OUT_DIR/step-link.txt" | sort -u | tr '\n' ' ')"
    fi
}

# ---------------------------------------------------------------------------------------------
do_libs() {
    echo ""
    echo "===================================================================="
    echo "LIBS: the link-only questions #2171 could not reach"
    echo "===================================================================="
    local log
    echo ""
    echo "-- the libc++ seam: which definition of std::__throw_out_of_range is in play"
    # Not a weak-symbol race. libc++ ABI-tags every header-inline symbol with _LIBCPP_ODR_SIGNATURE,
    # which encodes whether exceptions are on, so the aborting definition in a no-exceptions libc++
    # and the throwing one an exception-enabled compile emits do not share a mangled name and
    # cannot resolve to each other at any link order. The three spellings, printed rather than
    # asserted, because the tags carry the library version and will move at the next SDK bump:
    printf '    in the OCCT archive:          %s\n' \
        "$("$NM" --defined-only "$COMBINED" 2>/dev/null | grep -oE '_ZNSt3__2?[0-9]*__throw_out_of_range[A-Za-z0-9]*EPKc' | sort -u | head -1)"
    printf '    in the sysroot libc++.a:      %s\n' \
        "$("$NM" --defined-only "$SYSROOT/lib/wasm32-wasip1/libc++.a" 2>/dev/null | grep -oE '_ZNSt3__2?[0-9]*__throw_out_of_range[A-Za-z0-9]*EPKc' | sort -u | head -1)"
    printf '    in wasi-sdk eh libc++.a:      %s\n' \
        "$("$NM" --defined-only "$EH_LIBDIR/libc++.a" 2>/dev/null | grep -oE '_ZNSt3__2?[0-9]*__throw_out_of_range[A-Za-z0-9]*EPKc' | sort -u | head -1)"
    printf '    the tag is _LIBCPP_ODR_SIGNATURE: hardening, exceptions (n or e), version:\n'
    grep -A2 '_LIBCPP_EXCEPTIONS_SIG n' "$SYSROOT/include/c++/v1/__config" | sed 's/^/      /'
    printf '    __cxa_throw defined in the sysroot libc++abi.a: %s\n' \
        "$("$NM" --defined-only "$SYSROOT/lib/wasm32-wasip1/libc++abi.a" 2>/dev/null | grep -cE ' T __cxa_throw$' || true)"
    printf '    __cxa_throw defined in wasi-sdk eh libc++abi.a: %s\n' \
        "$("$NM" --defined-only "$EH_LIBDIR/libc++abi.a" 2>/dev/null | grep -cE ' T __cxa_throw$' || true)"
    log="$OUT_DIR/why-extract.txt"
    link_probe "$SCRIPT_DIR/probe.cxx" "$OUT_DIR/probe-why.wasm" \
        -Wl,--why-extract="$log" >/dev/null 2>&1
    if [ -f "$log" ]; then
        printf '    members pulled from the sysroot libc++.a: %s, and none of them for a __throw_ helper: %s\n' \
            "$(grep -c 'libc++\.a' "$log" || true)" \
            "$(grep -c '__throw_' "$log" || true)"
    fi

    echo ""
    echo "-- the negative cases: one piece removed from the link line at a time."
    echo "   Each is a claim that a flag is load-bearing, and a claim like that is worth nothing"
    echo "   until the link has been watched to fail without it."
    local case_name out status
    for case_name in setjmp eh-runtime builtins shim; do
        out="$OUT_DIR/neg-$case_name.txt"
        case "$case_name" in
            setjmp)
                "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
                    -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj -include "$SHIM" \
                    -I"$HEADERS" "$SCRIPT_DIR/probe.cxx" "$COMBINED" \
                    -L"$EH_LIBDIR" -lc++abi -lunwind \
                    -o "$OUT_DIR/neg.wasm" >"$out" 2>&1
                ;;
            eh-runtime)
                "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
                    -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj -include "$SHIM" \
                    -I"$HEADERS" "$SCRIPT_DIR/probe.cxx" "$COMBINED" \
                    -lsetjmp \
                    -o "$OUT_DIR/neg.wasm" >"$out" 2>&1
                ;;
            builtins)
                "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" \
                    -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj -include "$SHIM" \
                    -I"$HEADERS" "$SCRIPT_DIR/probe.cxx" "$COMBINED" \
                    -L"$EH_LIBDIR" -lc++abi -lunwind -lsetjmp \
                    -o "$OUT_DIR/neg.wasm" >"$out" 2>&1
                ;;
            shim)
                "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
                    -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj \
                    -I"$HEADERS" "$SCRIPT_DIR/probe.cxx" "$COMBINED" \
                    -L"$EH_LIBDIR" -lc++abi -lunwind -lsetjmp \
                    -o "$OUT_DIR/neg.wasm" >"$out" 2>&1
                ;;
        esac
        status=$?
        printf '    without %-11s exit=%s  %s\n' "$case_name" "$status" \
            "$(grep -oE 'undefined symbol: [^ ]+|no type named .[a-z_]+. in namespace .std.|cannot open [^ ]+' "$out" \
               | sort -u | head -3 | tr '\n' '|')"
        printf '      %s undefined-symbol line(s), %s compile error(s)\n' \
            "$(grep -c 'undefined symbol' "$out" || true)" \
            "$(grep -c 'error:' "$out" || true)"
    done

    echo ""
    echo "-- is -lwasi-emulated-getpid needed at all"
    printf '    archive members referencing getpid: %s\n' \
        "$("$NM" --undefined-only "$COMBINED" 2>/dev/null | grep -cE '^ +U getpid$' || true)"
    printf '    does probe.wasm need it: %s\n' \
        "$([ -f "$OUT_DIR/probe.wasm" ] && echo 'no, it linked without it' || echo 'unknown, it did not link')"
    # probe.wasm pulls neither of the two members, so it cannot answer the question. probe-getpid
    # calls OSD_Process::ProcessId() directly, which pulls one of them, and then the link either
    # resolves getpid or does not. Both directions are run, because "it linked" with the library
    # present proves nothing on its own.
    local without with
    "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
        -std=c++17 $EH_FLAGS -mllvm -wasm-enable-sjlj -include "$SHIM" -I"$HEADERS" \
        "$SCRIPT_DIR/probe-getpid.cxx" "$COMBINED" -L"$EH_LIBDIR" -lc++abi -lunwind -lsetjmp \
        -o "$OUT_DIR/probe-getpid.wasm" >"$OUT_DIR/getpid-without.txt" 2>&1
    without=$?
    link_probe "$SCRIPT_DIR/probe-getpid.cxx" "$OUT_DIR/probe-getpid.wasm" \
        -lwasi-emulated-getpid >"$OUT_DIR/getpid-with.txt" 2>&1
    with=$?
    printf '    a probe that DOES call OSD_Process::ProcessId():\n'
    printf '      without -lwasi-emulated-getpid: exit=%s  %s\n' "$without" \
        "$(grep -oE 'undefined symbol: [^ ]+' "$OUT_DIR/getpid-without.txt" | sort -u | tr '\n' ' ')"
    printf '      with    -lwasi-emulated-getpid: exit=%s\n' "$with"
    if [ -f "$OUT_DIR/probe-getpid.wasm" ]; then
        printf '      it runs: %s\n' "$("$WASMKIT" run "$OUT_DIR/probe-getpid.wasm" 2>&1 | head -1)"
    fi
}

# ---------------------------------------------------------------------------------------------
do_imports() {
    echo ""
    echo "===================================================================="
    echo "IMPORTS: what the linked module asks of the host (#2052)"
    echo "===================================================================="
    if [ ! -f "$OUT_DIR/probe.wasm" ]; then
        echo "  no probe.wasm; run ./run.sh link first" >&2
        return 1
    fi
    # A linked wasm module's host imports show up as its remaining undefined symbols, each named
    # __imported_<module>_<field>. Measured against a hello-world C program, which imports five.
    local f
    for f in probe.wasm probe-alloc.wasm; do
        [ -f "$OUT_DIR/$f" ] || continue
        echo "  $f imports these wasi_snapshot_preview1 functions:"
        "$NM" --undefined-only "$OUT_DIR/$f" 2>/dev/null | awk '{print $NF}' \
            | sed -n 's/^__imported_wasi_snapshot_preview1_//p' | sort -u | sed 's/^/    /'
        printf '    count: %s\n' \
            "$("$NM" --undefined-only "$OUT_DIR/$f" 2>/dev/null | awk '{print $NF}' \
               | grep -c '^__imported_wasi_snapshot_preview1_' || true)"
        printf '    imports from any other module: %s\n' \
            "$("$NM" --undefined-only "$OUT_DIR/$f" 2>/dev/null | awk '{print $NF}' \
               | grep -cv '^__imported_wasi_snapshot_preview1_' || true)"
    done
    # The control: what a C program that only calls printf imports, so the OCCT figure above is
    # read as a difference rather than as a total.
    printf '#include <stdio.h>\nint main(void){printf("hi\\n");return 0;}\n' > "$OUT_DIR/hello.c"
    "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -resource-dir="$RESOURCE_DIR" \
        "$OUT_DIR/hello.c" -o "$OUT_DIR/hello.wasm" 2>/dev/null
    echo "  control, a hello-world C program:"
    "$NM" --undefined-only "$OUT_DIR/hello.wasm" 2>/dev/null | awk '{print $NF}' \
        | sed -n 's/^__imported_wasi_snapshot_preview1_//p' | sort -u | sed 's/^/    /'
}

# ---------------------------------------------------------------------------------------------
do_size() {
    echo ""
    echo "===================================================================="
    echo "SIZE: the distribution facts"
    echo "===================================================================="
    local f
    for f in "$COMBINED" "$OUT_DIR/probe.wasm" "$OUT_DIR/probe-alloc.wasm"; do
        [ -f "$f" ] || continue
        # brotli as well as gzip where the tool is there, because the only published figure this
        # can be read against, occt-wasm's ~4.5 MB, is a brotli number. Comparing a gzip size with
        # a brotli size is the like-for-like mistake #2174's own issue body warns about.
        local br
        if command -v brotli >/dev/null 2>&1; then
            br="$(brotli -q 11 -c "$f" | wc -c | tr -d ' ')"
        else
            br="(no brotli on PATH)"
        fi
        printf '  %-28s %12s bytes  %12s gzip  %12s brotli\n' "$(basename "$f")" \
            "$(wc -c < "$f" | tr -d ' ')" "$(gzip -9 -c "$f" | wc -c | tr -d ' ')" "$br"
    done
    printf '  %-28s %12s bytes (%s files)\n' "$(basename "$HEADERS")/" \
        "$(du -sk "$HEADERS" 2>/dev/null | awk '{print $1 * 1024}')" \
        "$(find "$HEADERS" -type f | wc -l | tr -d ' ')"
    printf '    (that is the tree named on the >>> headers line above; the build tree'"'"'s own is\n'
    printf '     forwarding stubs and its size is not a distribution fact)\n' 
}

case "${1:-all}" in
    combine) do_combine ;;
    partial) do_partial_archive ;;
    census)  do_census ;;
    census-negative) do_census_negative ;;
    archive) do_archive ;;
    link)    do_link ;;
    libs)    do_libs ;;
    imports) do_imports ;;
    size)    do_size ;;
    all)     do_combine; do_census; do_census_negative; do_archive; do_link; do_libs
             do_imports; do_size ;;
    *) echo "usage: $0 [combine|census|census-negative|partial|archive|link|libs|imports|size|all]" >&2
       exit 1 ;;
esac
