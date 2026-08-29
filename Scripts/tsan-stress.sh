#!/bin/bash
#
# ThreadSanitizer gate for concurrency-touching changes.
#
# Formalizes the TSan protocol used to find and fix issues #298, #319, #341, #344
# and #349: a minimal-module ThreadSanitizer build of the pinned OCCT (with all
# carried patches applied) plus the standalone C++ stress harnesses in
# Scripts/repro/, run with race detection on. See docs/thread-safety.md
# ("ThreadSanitizer gate") for when running this is required.
#
# Usage:
#   Scripts/tsan-stress.sh build    One-time: build the TSan-instrumented OCCT
#                                   into Libraries/occt-install-tsan (~15-30 min)
#   Scripts/tsan-stress.sh run     Compile + run every gate scenario under TSan
#   Scripts/tsan-stress.sh swift   swift test --sanitize=thread on the
#                                   concurrency-focused suites (wrapper-only
#                                   coverage; see docs/thread-safety.md)
#   Scripts/tsan-stress.sh all     build (if needed) + run + swift
#
# Environment:
#   JOBS          parallel build jobs (default: hw.ncpu)
#   SWIFT_FILTER  override the test filter used by the swift mode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"
SRC_DIR="$LIBRARIES_DIR/occt-src"
BUILD_DIR="$LIBRARIES_DIR/occt-build-tsan"
INSTALL_DIR="$LIBRARIES_DIR/occt-install-tsan"
SUPP_FILE="$SCRIPT_DIR/tsan.supp"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"

# ---------------------------------------------------------------------------
# Gate scenario matrix.
#
# One line per scenario: "<source relative to Scripts/repro>|<program args>".
# The token @SCRATCH is replaced with a per-run scratch directory.
#
# POLICY: when a change introduces a new concurrent usage pattern (a new
# subsystem wrapped for parallel use, a serialization mutex removed, a new
# concurrent path through the bridge), add a scenario here, either a new mode
# in an existing harness or a new standalone harness under Scripts/repro/.
#
# Only DOCUMENTED-SAFE usage patterns belong here (independent shapes,
# unique file paths). Deliberately adversarial modes that exercise
# documented-unsafe usage (341's shared_adaptor_cache, obj_roundtrip_shared)
# are excluded: they are expected to race and gate nothing.
# ---------------------------------------------------------------------------
SCENARIOS=(
  "341-meshcaf/occt_341_stress.cpp|create_fillet_boolean 8 30"
  "341-meshcaf/occt_341_stress.cpp|mesh_independent 8 30"
  "341-meshcaf/occt_341_stress.cpp|obj_roundtrip_unique 8 25 @SCRATCH"
  "344-cdf-directory/occt_344_newdoc_only.cpp|8 50"
  "344-cdf-directory/occt_344_barrier.cpp|8 50"
  "344-cdf-directory/occt_344_stress.cpp|8 25 @SCRATCH"
  "349-ocaf-driver-reentrancy/occt_349_barrier.cpp|8 50 @SCRATCH"
  "353-cdm-metadata-lookup-table/occt_353_barrier.cpp|8 50 @SCRATCH"
  "371-getapplication-singleton-elimination/occt_371_private_app.cpp|8 50 @SCRATCH"
  "374-resource-manager-storage-schema-race/occt_374_stress.cpp|8 50 @SCRATCH"
  # Carried patch 0011 (#341/#363). Its own regression harness existed from the day the
  # OwnAutoNamingScope redesign landed and was never wired in here, so the scenario that
  # checks the property the earlier mutex fix could NOT guarantee (half the threads
  # overriding auto-naming locally while the other half rely on the process-wide default,
  # concurrently, on independent documents) ran in no gate at all.
  "363-own-autonaming/occt_363_isolation.cpp|isolation 8 50 @SCRATCH"
  # Issue #1155: survey of eight candidate classes named as "algorithms with internal
  # mutable state" (BRepBuilderAPI_Transform, BRepClass3d_SolidClassifier,
  # GeomAPI_ProjectPointOnSurf, BRepBuilderAPI_MakeEdge/MakeWire/MakeFace,
  # BRepOffsetAPI_MakePipeShell/MakeThickSolid, BRepFilletAPI_MakeFillet/MakeChamfer,
  # ShapeFix_Face/Wire/Shape, BRepCheck_Analyzer). All eight confirmed clean (instance
  # state only); see Scripts/repro/1155-thread-safety-survey/README.md for the full
  # characterization, including the one near-miss (a live-but-unreachable file-scope
  # static cluster in the legacy fillet-reconstruction engine, tracked as a follow-up).
  "1155-thread-safety-survey/occt_1155_stress.cpp|transform_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|classify_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|project_point_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|make_edge_wire_face_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|pipe_shell_thick_solid_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|fillet_chamfer_all_edges_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|shapefix_independent 8 30"
  "1155-thread-safety-survey/occt_1155_stress.cpp|check_analyzer_independent 8 30"
)

MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)
CXX=$(xcrun --find clang++)

apply_patches() {
    # Same idempotent loop as build-occt.sh: carried patches must be in the
    # instrumented kernel too, otherwise the gate re-reports every fixed race.
    if compgen -G "$SCRIPT_DIR/patches/*.patch" > /dev/null; then
        echo ">>> Applying carried OCCT patches to occt-src..."
        for p in "$SCRIPT_DIR"/patches/*.patch; do
            if git -C "$SRC_DIR" apply --reverse --check "$p" 2>/dev/null; then
                echo "    already applied: $(basename "$p")"
            elif git -C "$SRC_DIR" apply --check "$p" 2>/dev/null; then
                git -C "$SRC_DIR" apply "$p"
                echo "    applied: $(basename "$p")"
            else
                echo "    ERROR: cannot apply $(basename "$p") cleanly" >&2
                exit 1
            fi
        done
    fi
}

# The OCCT tag this gate must be built from, read out of build-occt.sh rather than repeated here,
# so a version bump cannot move one and leave the other behind.
expected_occt_tag() {
    local v rc
    v=$(grep -m1 '^OCCT_VERSION=' "$SCRIPT_DIR/build-occt.sh" | cut -d'"' -f2)
    rc=$(grep -m1 '^OCCT_RC=' "$SCRIPT_DIR/build-occt.sh" | cut -d'"' -f2)
    if [ -n "$rc" ]; then echo "V${v//./_}_${rc}"; else echo "V${v//./_}"; fi
}

# What the instrumented kernel in $INSTALL_DIR was built from: the OCCT tag plus a digest of every
# carried patch. `all` compares this against the current tree and rebuilds when they differ.
#
# Until the v2.0.0 release check, `all` was `[ -d "$INSTALL_DIR/lib" ] || do_build`, so an install
# from any date at all counted as current. The one on the machine that check ran on was from
# 30 July: before the V8_0_1 absorb, and before patches 0017 through 0025. Every scenario would
# have run against a kernel that is not the release kernel, found nothing, and exited 0. That is
# #585's failure shape (a gate validating the wrong kernel and reading as clean) moved into the
# concurrency gate, where it is harder to notice because a race that does not reproduce looks
# exactly like a race that is fixed.
tsan_stamp() {
    local tag digest
    tag=$(git -C "$SRC_DIR" describe --tags --exact-match HEAD 2>/dev/null || echo "untagged")
    digest=$(cat "$SCRIPT_DIR"/patches/*.patch 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
    echo "$tag ${digest:0:16}"
}

do_build() {
    if [ ! -d "$SRC_DIR" ]; then
        echo "ERROR: $SRC_DIR not found. Run Scripts/build-occt.sh once first (it clones the pinned OCCT source)." >&2
        exit 1
    fi

    # Same check build-occt.sh makes, for the same reason: this gate is only meaningful against the
    # kernel the release actually ships, and reusing a tree at another tag builds the wrong one
    # under the right name. Aborts rather than resetting, so a diagnostic probe left in the tree is
    # not destroyed silently.
    local want current
    want=$(expected_occt_tag)
    current=$(git -C "$SRC_DIR" describe --tags --exact-match HEAD 2>/dev/null || true)
    if [ "$current" != "$want" ]; then
        echo "ERROR: $SRC_DIR is at '${current:-an untagged commit}', but this gate must be built" >&2
        echo "       from $want, the tag build-occt.sh names. A TSan run against another kernel" >&2
        echo "       proves nothing about the one being released." >&2
        echo "" >&2
        echo "       Check for work worth keeping first:" >&2
        echo "         git -C '$SRC_DIR' status --porcelain" >&2
        echo "       Then:  rm -rf '$SRC_DIR' && Scripts/build-occt.sh   (re-clones at $want)" >&2
        exit 1
    fi

    apply_patches

    # Wipe both trees. build-occt.sh already does this for its own install prefixes, on the grounds
    # that "leaked headers masquerade as current API"; the same argument applies here and this
    # script did not. Reusing them is not merely untidy: cmake reinstalls every library whether or
    # not it rebuilt it, so a stale prefix comes out wearing today's timestamps, and an incremental
    # build over a dependency graph recorded before a patch landed can relink an archive whose
    # object code predates it. Measured on the v2.0.0 release check: a "rebuild" over a 3 August
    # tree finished in 1m26s and left all 48 libraries dated today. Nothing about that result told
    # you which of them had actually been recompiled.
    rm -rf "$BUILD_DIR" "$INSTALL_DIR"

    # Minimal-module config, mirroring the proven #298/#341/#344/#349 protocol
    # builds (Libraries/occt-build-tsan344/349): FoundationClasses + ModelingData
    # + ModelingAlgorithms + DataExchange. Toolkits those modules depend on
    # (TKLCAF/TKCDF etc.) are built by OCCT's own dependency resolution.
    echo ">>> Configuring TSan OCCT build ($BUILD_DIR)..."
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
        -DBUILD_LIBRARY_TYPE=Static \
        -DBUILD_MODULE_ApplicationFramework=OFF \
        -DBUILD_MODULE_DataExchange=ON \
        -DBUILD_MODULE_Draw=OFF \
        -DBUILD_MODULE_FoundationClasses=ON \
        -DBUILD_MODULE_ModelingAlgorithms=ON \
        -DBUILD_MODULE_ModelingData=ON \
        -DBUILD_MODULE_Visualization=OFF \
        -DUSE_FREETYPE=OFF -DUSE_FREEIMAGE=OFF -DUSE_TBB=OFF \
        -DUSE_VTK=OFF -DUSE_OPENGL=OFF -DUSE_GLES2=OFF \
        -DUSE_DRACO=OFF -DUSE_FFMPEG=OFF -DUSE_OPENVR=OFF \
        -DUSE_XLIB=OFF -DUSE_TCL=OFF -DUSE_RAPIDJSON=OFF \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DCMAKE_CXX_COMPILER="$CXX" \
        -DCMAKE_CXX_FLAGS="-arch arm64 -isysroot $MACOS_SDK -mmacosx-version-min=12.0 -fsanitize=thread -g" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
    echo ">>> Building (this takes a while)..."
    cmake --build "$BUILD_DIR" --parallel "$JOBS"
    cmake --install "$BUILD_DIR"
    echo ">>> TSan OCCT installed at $INSTALL_DIR"

    tsan_stamp > "$INSTALL_DIR/.tsan-stamp"
    echo ">>> instrumented kernel stamped: $(cat "$INSTALL_DIR/.tsan-stamp")"
}

do_run() {
    if [ ! -d "$INSTALL_DIR/lib" ]; then
        echo "ERROR: no TSan OCCT install at $INSTALL_DIR. Run: Scripts/tsan-stress.sh build" >&2
        exit 1
    fi
    local inc="$INSTALL_DIR/include/opencascade"
    [ -d "$inc" ] || inc="$INSTALL_DIR/include"
    local libs
    libs=$(ls "$INSTALL_DIR"/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/')

    local results scratch
    results=$(mktemp -d /tmp/occt-tsan-results.XXXXXX)
    scratch=$(mktemp -d /tmp/occt-tsan-scratch.XXXXXX)
    echo ">>> TSan gate: logs in $results"

    local failures=0 total=0
    for entry in "${SCENARIOS[@]}"; do
        local src="${entry%%|*}"
        local args="${entry#*|}"
        args="${args//@SCRATCH/$scratch}"
        local src_path="$SCRIPT_DIR/repro/$src"
        local bin="$results/$(basename "${src%.cpp}")"

        # results dir is fresh per run, so "binary exists" means "already
        # compiled this run" (macOS /bin/bash is 3.2: no associative arrays)
        if [ ! -x "$bin" ]; then
            echo ">>> Compiling $src"
            "$CXX" -std=c++17 -fsanitize=thread -g -O1 -w \
                -isysroot "$MACOS_SDK" \
                -I"$inc" -L"$INSTALL_DIR/lib" \
                "$src_path" -o "$bin" \
                $libs -lz -lc++ -framework Foundation
        fi

        total=$((total + 1))
        local log="$results/$(basename "${src%.cpp}").$(echo "$args" | tr ' /' '__').log"
        echo ">>> RUN  $(basename "$bin") $args"
        local status=0
        MMGT_OPT=0 \
        TSAN_OPTIONS="halt_on_error=0:exitcode=66:suppressions=$SUPP_FILE" \
            "$bin" $args > "$log" 2>&1 || status=$?

        local races
        races=$(grep -c "WARNING: ThreadSanitizer" "$log" || true)
        if [ "$status" -eq 0 ] && [ "$races" -eq 0 ]; then
            echo "     PASS (0 races)"
        else
            echo "     FAIL (exit $status, $races race warnings): $log"
            failures=$((failures + 1))
        fi
    done

    echo ""
    echo ">>> TSan gate: $((total - failures))/$total scenarios clean"
    if [ "$failures" -gt 0 ]; then
        echo ">>> FAILED. Inspect the logs above. A race that is confirmed benign or is an"
        echo ">>> already-filed open kernel finding may be added to Scripts/tsan.supp, with"
        echo ">>> an issue link and removal condition (see the policy in that file)."
        exit 1
    fi
}

do_swift() {
    # Wrapper-only coverage: SwiftPM instruments the Swift + OCCTBridge sources,
    # but the prebuilt OCCT.xcframework is NOT instrumented, so races entirely
    # inside the kernel are invisible here. Kernel coverage comes from do_run.
    local filter="${SWIFT_FILTER:-Thread|Stress|Concurren|Parallel}"
    echo ">>> swift test --sanitize=thread --filter \"$filter\""
    (cd "$PROJECT_DIR" && swift test --sanitize=thread --filter "$filter")
}

case "${1:-}" in
    build) do_build ;;
    run)   do_run ;;
    swift) do_swift ;;
    all)
        want_stamp=$(tsan_stamp)
        have_stamp=$(cat "$INSTALL_DIR/.tsan-stamp" 2>/dev/null || echo "(never built)")
        if [ ! -d "$INSTALL_DIR/lib" ] || [ "$want_stamp" != "$have_stamp" ]; then
            echo ">>> instrumented kernel is absent or was built from something else; rebuilding"
            echo "    want: $want_stamp"
            echo "    have: $have_stamp"
            do_build
        else
            echo ">>> instrumented kernel matches occt-src + Scripts/patches ($have_stamp)"
        fi
        do_run
        do_swift
        ;;
    *)
        sed -n '2,27p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
