#!/bin/bash
#
# Build OpenCASCADE for WebAssembly (WASI)
#
# Usage: ./build-occt-wasm.sh [--toolkit NAME] [--require-complete] [--census-only] [--package-only]
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
#                    --toolkit. The full build neither takes it nor needs it: as of #2174 it runs
#                    the same census over EVERY toolkit unconditionally and installs and combines
#                    nothing unless all of them are complete. Without this flag a --toolkit run
#                    prints its count and does not check it, and the exit status is whatever the
#                    build tool returned: that was the right behaviour while eight failures were
#                    the expected result of #2172, and the wrong one from #2173 onwards, when a
#                    regression would hand a reader the same status a complete build does. Turn it
#                    on wherever ONE toolkit is expected to be complete; Scripts/repro/2173/run.sh
#                    does.
#
#   --census-only    The per-toolkit completeness census over the build tree that is already
#                    there, and nothing else: no download, no patching, no configure, no compile.
#
#   --package-only   The census, then install, combine and copy headers out of that same tree.
#
# Both exist because the full build is hours and each of those steps is seconds, so neither a
# re-derived count nor a failed packaging step costs a rebuild of every source file. --census-only
# is also how the census is PROVED, by hiding one object and watching the count drop; see
# Scripts/repro/2174/run.sh census-negative.
#
# The full build also runs with `-k` as of #2174, for the reason the narrow loop does: 49 toolkits
# and thousands of source files discovered one error at a time is not a gap list, it is one full
# rebuild per gap. One pass reports every file that fails, per toolkit, and the census that follows
# decides whether anything is installed.
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
# Build time: 69 minutes for the full 49-toolkit set on 10 cores, measured 2026-09-23 (#2174).
#             One toolkit with --toolkit is seconds to a few minutes.
#

set -e

# --------------------
# Arguments
# --------------------
BUILD_TOOLKIT=""
REQUIRE_COMPLETE=""
CENSUS_ONLY=""
PACKAGE_ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --require-complete)
            REQUIRE_COMPLETE="1"
            shift
            ;;
        --census-only)
            CENSUS_ONLY="1"
            shift
            ;;
        --package-only)
            PACKAGE_ONLY="1"
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
            # The header block, which ends at the blank line before `set -e`. Derived rather than
            # hardcoded: the line number was 38 and the block has grown twice since, so `--help`
            # printed a truncated usage both times.
            sed -n '2,/^# Build time:/p' "$0"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument '$1'. Usage: $0 [--toolkit NAME] [--require-complete] [--census-only] [--package-only]" >&2
            exit 1
            ;;
    esac
done

if [ -n "$REQUIRE_COMPLETE" ] && [ -z "$BUILD_TOOLKIT" ]; then
    echo "ERROR: --require-complete needs --toolkit." >&2
    echo "       The full build asserts completeness for every toolkit unconditionally (#2174):" >&2
    echo "       it builds with \`-k\`, counts every toolkit's objects against the rules CMake" >&2
    echo "       generated, and installs and combines nothing unless all of them are complete." >&2
    echo "       Accepting the flag here would be an option that changes no behaviour." >&2
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

# --------------------
# Per-toolkit completeness, counted from the build tree (#2172, generalised in #2174)
# --------------------
# The denominator is every object CMake generated a rule for and the numerator is every object on
# disk, so both come from the build tree rather than from a glob of the source directory that might
# disagree with what this configure selected. One implementation, shared by the narrow loop, by the
# full build's 49-toolkit census and by --census-only: two copies of a count are two counts, and
# --census-only exists so that the census can be re-run, and PROVED, without a three-hour rebuild.
toolkit_object_dirs() {  # every <name>.dir CMake generated, one per line, relative to the build dir
    find . -type d -name '*.dir' -path '*/CMakeFiles/*' | sort
}
toolkit_expected_objs() {  # <objdir> -> every object path CMake has a rule for
    local d="$1" tk
    tk="$(basename "$d" .dir)"
    # Match the OBJECT path and nothing about the source that produced it. #2172's pattern was
    # `[A-Za-z0-9_/]+\.(cxx|c)\.obj`, and it was wrong twice over on the full module set, in
    # opposite directions:
    #
    #   * the character class cannot match a source file name containing a dot, so OCCT's four
    #     generated parsers were invisible: TKExpress counted 61 against a real 63 and TKDESTEP
    #     1733 against a real 1735. --require-complete would have called either COMPLETE with one
    #     of its parsers missing;
    #   * the extension list named `cxx` and `c`, and this configure compiles nine `.cpp` files as
    #     well, of which TKMesh's vendored BRepMesh/delabella.cpp is one. That toolkit counted 66
    #     against a real 67, so it reported 67 of 66 and the object on disk had no rule to belong
    #     to.
    #
    # TKernel, which is every toolkit #2172 and #2173 ever counted, has neither shape. Naming any
    # part of a source file name here is a guess about someone else's build system, so this names
    # none of it: every `.obj` CMake generated a rule for, whatever produced it.
    grep -oE "CMakeFiles/${tk}\.dir/[^ :]+\.obj" "$d/build.make" 2>/dev/null \
        | sed "s|CMakeFiles/${tk}\.dir/||" | sort -u
}
toolkit_actual_objs() {  # <objdir> -> every object on disk
    (cd "$1" && find . -name '*.obj' | sed 's|^\./||' | sort -u)
}
toolkit_missing_objs() {  # <objdir> -> the rules that produced no object
    comm -23 <(toolkit_expected_objs "$1") <(toolkit_actual_objs "$1")
}
toolkit_unruled_objs() {  # <objdir> -> the objects no rule accounts for
    comm -13 <(toolkit_expected_objs "$1") <(toolkit_actual_objs "$1")
}

# Prints the table and returns 1 if any toolkit disagrees with its own rules, 2 if it examined
# nothing. Run from the build directory.
#
# Per toolkit, and summed per toolkit rather than from the totals. The first version of this
# subtracted one grand total from the other, and on the first full build that arithmetic reported
# `TOTAL 5487 of 5487` and `0 source file(s) did not compile` while TKDESTEP was one object short
# and TKMesh was one object over: the two cancelled. A count that can cancel is not a count of
# anything, and that line is exactly the worthless green check this whole effort exists to remove.
census_all_toolkits() {
    local objdir tk exp act miss extra
    CENSUS_TOOLKITS=0
    CENSUS_EXPECTED=0
    CENSUS_ACTUAL=0
    CENSUS_MISSING=0
    CENSUS_EXTRA=0
    CENSUS_INCOMPLETE=()
    CENSUS_UNRULED=()
    echo "===================================================================="
    echo "Per-toolkit completeness"
    echo "===================================================================="
    for objdir in $(toolkit_object_dirs); do
        [ -f "$objdir/build.make" ] || continue
        tk="$(basename "$objdir" .dir)"
        exp=$(toolkit_expected_objs "$objdir" | wc -l | tr -d ' ')
        [ "$exp" -eq 0 ] && continue
        act=$(toolkit_actual_objs "$objdir" | wc -l | tr -d ' ')
        miss=$(toolkit_missing_objs "$objdir" | wc -l | tr -d ' ')
        extra=$(toolkit_unruled_objs "$objdir" | wc -l | tr -d ' ')
        CENSUS_TOOLKITS=$((CENSUS_TOOLKITS + 1))
        CENSUS_EXPECTED=$((CENSUS_EXPECTED + exp))
        CENSUS_ACTUAL=$((CENSUS_ACTUAL + act))
        CENSUS_MISSING=$((CENSUS_MISSING + miss))
        CENSUS_EXTRA=$((CENSUS_EXTRA + extra))
        if [ "$miss" -ne 0 ]; then
            CENSUS_INCOMPLETE+=("$objdir")
            printf '  %-16s %5s of %-5s  INCOMPLETE, %s did not compile\n' "$tk" "$act" "$exp" "$miss"
        elif [ "$extra" -ne 0 ]; then
            CENSUS_UNRULED+=("$objdir")
            printf '  %-16s %5s of %-5s  %s object(s) with no rule\n' "$tk" "$act" "$exp" "$extra"
        else
            printf '  %-16s %5s of %-5s\n' "$tk" "$act" "$exp"
        fi
    done
    echo "--------------------------------------------------------------------"
    printf '  %-16s %5s of %-5s across %s toolkits, %s missing, %s unruled\n' \
        "TOTAL" "$CENSUS_ACTUAL" "$CENSUS_EXPECTED" "$CENSUS_TOOLKITS" \
        "$CENSUS_MISSING" "$CENSUS_EXTRA"

    # Per #2098, a check that examined nothing fails rather than passes.
    if [ "$CENSUS_TOOLKITS" -eq 0 ] || [ "$CENSUS_EXPECTED" -eq 0 ]; then
        echo "" >&2
        echo "ERROR: this build tree has no toolkit object rules at all, so the completeness check" >&2
        echo "       examined nothing. A denominator of zero is not a complete build (#2098)." >&2
        return 2
    fi

    if [ "$CENSUS_MISSING" -ne 0 ]; then
        echo "" >&2
        echo "ERROR: $CENSUS_MISSING source file(s) did not compile, in ${#CENSUS_INCOMPLETE[@]} toolkit(s)." >&2
        echo "       Every one of them is in the build log, in a single pass. The list:" >&2
        for objdir in "${CENSUS_INCOMPLETE[@]}"; do
            tk="$(basename "$objdir" .dir)"
            toolkit_missing_objs "$objdir" | sed "s|^|         $tk  |; s|\.obj$||" >&2
        done
        echo "" >&2
        echo "       If one of these is a platform gap, it belongs in Scripts/patches-wasi/ with a" >&2
        echo "       patch header saying what its WASI branch returns; see docs/WASI_GUARD_SITES.md" >&2
        echo "       and okf/policies/wasi-patch-base.md." >&2
        echo "" >&2
        echo "       Re-run one toolkit at a time to iterate in seconds rather than in a full build:" >&2
        echo "         Scripts/build-occt-wasm.sh --toolkit <NAME>" >&2
        return 1
    fi

    # An object CMake has no rule for means the DENOMINATOR is wrong, so every other number above
    # is unproven rather than merely incomplete. It fails for that reason and not because the
    # object is unwelcome.
    if [ "$CENSUS_EXTRA" -ne 0 ]; then
        echo "" >&2
        echo "ERROR: $CENSUS_EXTRA object(s) on disk match no rule in the build.make that should" >&2
        echo "       have produced them, so this census's denominator does not describe this build" >&2
        echo "       and none of the counts above can be trusted. The list:" >&2
        for objdir in "${CENSUS_UNRULED[@]}"; do
            tk="$(basename "$objdir" .dir)"
            toolkit_unruled_objs "$objdir" | sed "s|^|         $tk  |" >&2
        done
        return 1
    fi
    return 0
}

# --census-only: the census over the tree that is already there, with no download, no patching, no
# configure and no compile. It is how the census is re-derived after the fact, and how it is proved
# (hide one object, watch the count drop and the file be named) without a three-hour rebuild.
if [ -n "$CENSUS_ONLY" ]; then
    if [ -n "$BUILD_TOOLKIT" ] || [ -n "$REQUIRE_COMPLETE" ]; then
        echo "ERROR: --census-only takes neither --toolkit nor --require-complete. It reads the" >&2
        echo "       whole build tree and asserts every toolkit, which is what both of those ask" >&2
        echo "       for in a mode that builds." >&2
        exit 1
    fi
    if [ ! -d "$LIBRARIES_DIR/occt-build-wasm" ]; then
        echo "ERROR: no build tree at $LIBRARIES_DIR/occt-build-wasm to take a census of." >&2
        exit 1
    fi
    cd "$LIBRARIES_DIR/occt-build-wasm"
    census_all_toolkits
    exit $?
fi

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

# --package-only: install, combine and copy headers out of a build tree that is already complete,
# with no download, no patching, no configure and no compile. It runs the SAME census first, so it
# cannot package an incomplete kernel, and it exists because the compile is hours while this step is
# seconds: a packaging failure must not cost a rebuild of every source file.
if [ -n "$PACKAGE_ONLY" ]; then
    if [ -n "$BUILD_TOOLKIT" ] || [ -n "$REQUIRE_COMPLETE" ] || [ -n "$CENSUS_ONLY" ]; then
        echo "ERROR: --package-only takes no other mode flag." >&2
        exit 1
    fi
    if [ ! -d occt-build-wasm ]; then
        echo "ERROR: no build tree at $LIBRARIES_DIR/occt-build-wasm to package." >&2
        exit 1
    fi
    cd occt-build-wasm
    census_all_toolkits || exit 1
    census_all_toolkits || exit 1
    package_build
    exit 0
    exit 0
fi

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

    # Counted, never estimated, by the shared helpers above.
    TOOLKIT_EXPECTED=$(toolkit_expected_objs "$TOOLKIT_OBJ_DIR" | wc -l | tr -d ' ')
    TOOLKIT_ACTUAL=$(toolkit_actual_objs "$TOOLKIT_OBJ_DIR" | wc -l | tr -d ' ')

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

# --------------------
# The full build, with -k, and a census of every toolkit (#2174)
# --------------------
# `-k` for the reason the narrow loop has it. This configure builds 49 toolkits across six modules
# and 5,488 source files; stopping at the first file that does not compile turns the gap list into
# one full rebuild per gap, and a full rebuild is 69 minutes on 10 cores, measured. The build is therefore ALLOWED to fail here, and the census
# below is what decides whether anything is installed.
echo ""
echo ">>> Building every toolkit, with -k (keep going)."
set +e
cmake --build . --parallel "$JOBS" -- -k
FULL_STATUS=$?
set -e

echo ""
set +e
census_all_toolkits
CENSUS_STATUS=$?
set -e
if [ "$CENSUS_STATUS" -ne 0 ]; then
    echo "" >&2
    echo "       Nothing has been installed and no combined archive has been written: an" >&2
    echo "       incomplete kernel packaged as a complete one is the failure mode this whole" >&2
    echo "       check exists for." >&2
    exit 1
fi

if [ "$FULL_STATUS" -ne 0 ]; then
    echo "" >&2
    echo "ERROR: every object is present, but the build tool exited $FULL_STATUS. Something other" >&2
    echo "       than a compile failed, an archive step most likely; the log above is the record." >&2
    exit 1
fi
echo ">>> COMPLETE: every toolkit built every source file it has a rule for."

package_build
