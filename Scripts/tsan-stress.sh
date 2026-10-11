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
#   Scripts/tsan-stress.sh self-test
#                                   Prove the per-scenario timeout against stub
#                                   scenarios, one of which hangs. Needs no build.
#
# Environment:
#   JOBS          parallel build jobs (default: hw.ncpu)
#   SWIFT_FILTER  override the test filter used by the swift mode
#   TSAN_SCENARIO_TIMEOUT
#                 seconds one `run` scenario may take before it is killed and counted as a
#                 failure (default: 300, a positive integer). Scenarios finish in seconds to a
#                 few minutes; a wedged one stalled the gate for 49 minutes (#3058).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LIBRARIES_DIR="$PROJECT_DIR/Libraries"
SRC_DIR="$LIBRARIES_DIR/occt-src"
BUILD_DIR="$LIBRARIES_DIR/occt-build-tsan"
INSTALL_DIR="$LIBRARIES_DIR/occt-install-tsan"
SUPP_FILE="$SCRIPT_DIR/tsan.supp"
JOBS="${JOBS:-$(sysctl -n hw.ncpu)}"
SCENARIO_TIMEOUT="${TSAN_SCENARIO_TIMEOUT:-300}"
case "$SCENARIO_TIMEOUT" in
    ''|*[!0-9]*|0) echo "ERROR: TSAN_SCENARIO_TIMEOUT must be a positive integer (seconds), got '$SCENARIO_TIMEOUT'" >&2; exit 2 ;;
esac

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
  # Issue #1157/#1403, the data-exchange path. Registered 2026-09-20, and the reason it was not
  # registered before is the finding: this harness has existed since #1157 with seven modes and sat
  # in NO scenario, so the one subsystem docs/thread-safety.md describes as protected by a
  # bridge-level mutex (igesMutex(), 40 acquisitions) had no gate coverage at all. That is what the
  # POLICY block above forbids, and docs/thread-safety.md says outright: "A harness under
  # Scripts/repro/ that is not in SCENARIOS is a file, not a gate."
  #
  # The five INDEPENDENT modes only. cross_talk_schema_unlocked and cross_talk_schema_locked are
  # deliberately excluded: they set the same Interface_Static key from every thread and cross-talk
  # 16000/16000 BY CONSTRUCTION, with and without an accessor lock, which is the measurement that
  # proved a locked accessor cannot fix that shape. Expected to race, so they gate nothing, exactly
  # like #341's shared_adaptor_cache.
  #
  # These are EXPECTED TO FAIL on registration: nothing in Scripts/tsan.supp suppresses any DE race
  # and #1403's bucket-(b) state is still shared. That failing run is #1403's re-measurement
  # baseline. Do not add a suppression to make this green; the whole point of registering it is to
  # stop the DE path being silently unmeasured.
  "1157-interface-static-thread-safety/occt_1157_stress.cpp|step_write_independent 8 20 @SCRATCH"
  "1157-interface-static-thread-safety/occt_1157_stress.cpp|step_read_independent 8 20 @SCRATCH"
  "1157-interface-static-thread-safety/occt_1157_stress.cpp|iges_write_independent 8 20 @SCRATCH"
  "1157-interface-static-thread-safety/occt_1157_stress.cpp|iges_read_independent 8 20 @SCRATCH"
  "1157-interface-static-thread-safety/occt_1157_stress.cpp|mixed_step_iges_independent 8 20 @SCRATCH"

  # Issues #2074 and #2075, the two surfaces #707 named as having NO TSan scenario at all.
  # Registered 2026-09-23. Both came back clean, which is the result rather than a non-result:
  # #707's protocol has now been pointed at both surfaces it named, and neither holds a defect
  # this harness can reach.
  #
  # #2074, Surface/Curve3D evaluation. Carried patch 0031 already found a real defect on exactly
  # this surface (BSplCLib_Cache/BSplSLib_Cache rebuilding a span in place from a const
  # evaluator), and 0031 was pinned from v4.0.0-kernel.1 until it was retired at v4.0.0-kernel.6. Every mode drives threads at parameters
  # in DIFFERENT spans, staggered by thread index, because a harness whose threads all evaluate
  # one span would find nothing here however many threads it ran.
  #
  # KNOWN LIMIT, recorded rather than glossed: this harness has NOT been A/B'd against 0031
  # unpatched. 0031 adds a mutex member to BSplCLib_Cache and therefore changes the class layout,
  # so override-linking one unpatched .cxx against an archive built with the patched header is an
  # ODR violation rather than an experiment. What IS proven is that the binary reports: injecting
  # a deliberate unsynchronised global makes it abort with a TSan race. So these modes are clean,
  # not blind, but "would have caught 0031" is not a claim this method can support.
  # See Scripts/repro/2074-adaptor-evaluation/README.md.
  "2074-adaptor-evaluation/occt_2074_stress.cpp|curve_independent 8 40"
  "2074-adaptor-evaluation/occt_2074_stress.cpp|surface_independent 8 40"
  "2074-adaptor-evaluation/occt_2074_stress.cpp|curve_shared_geometry 8 40"
  "2074-adaptor-evaluation/occt_2074_stress.cpp|surface_shared_geometry 8 40"
  # #3065: the pattern the kernel's maintainer says an adaptor is designed for, ONE adaptor with a
  # ShallowCopy() per thread, which is the pattern retired patch 0031 (v4.0.0-kernel.6) stopped masking
  # the lack of. Each
  # thread copies from the shared source and checks every point against the geometry's own
  # evaluator, so a copy that leaked the source's cache fails as a wrong point and not only as a
  # race. The *_shared_adaptor modes stay out: sharing the adaptor itself is the unsupported shape.
  "2074-adaptor-evaluation/occt_2074_stress.cpp|curve_shallow_copy_per_thread 8 40"
  "2074-adaptor-evaluation/occt_2074_stress.cpp|edge_shallow_copy_per_thread 8 40"
  "2074-adaptor-evaluation/occt_2074_stress.cpp|surface_shallow_copy_per_thread 8 40"

  # #2075, BRepGraph. Exploratory: no known defect, ranked second for that reason. The structural
  # read agreed with the measurement before it ran, which is worth recording because it rarely
  # does: across the 83 files of src/ModelingData/TKBRep/BRepGraph there are zero file-scope
  # mutable statics, zero function-local statics, and exactly three `mutable` members, all three
  # of them mutexes. The family was written thread-aware.
  # See Scripts/repro/2075-brepgraph-concurrency/README.md.
  "2075-brepgraph-concurrency/occt_2075_stress.cpp|graph_build_independent 8 30"
  "2075-brepgraph-concurrency/occt_2075_stress.cpp|graph_traverse_independent 8 30"
  "2075-brepgraph-concurrency/occt_2075_stress.cpp|graph_build_traverse_independent 8 30"
)

MACOS_SDK=$(xcrun --sdk macosx --show-sdk-path)
CXX=$(xcrun --find clang++)

apply_patches() {
    # Same idempotent loop as build-occt.sh: carried patches must be in the
    # instrumented kernel too, otherwise the gate re-reports every fixed race.
    #
    # The patches are a stack and a later one may rewrite lines an earlier one added (0055
    # corrects 0050 and 0051, #3010), so on a tree that carries the stack the earlier patch fails
    # BOTH checks below. build-occt.sh carries it when a LATER patch touching one of its files
    # reverse-checks clean; this loop did not, and stopped at 0050 on a fully patched tree.
    local -a patches
    patches=("$SCRIPT_DIR"/patches/*.patch)
    patch_files() { git -C "$SRC_DIR" apply --numstat "$1" | cut -f3; }
    superseded_by_applied_patch() {
        local p=$1 q f
        local -a files
        # A read loop and not `mapfile`: this script runs under macOS's /bin/bash 3.2, which has no
        # mapfile, and `set -u` there treats an empty array as unbound.
        files=()
        while IFS= read -r f; do files+=("$f"); done < <(patch_files "$p")
        for q in "${patches[@]}"; do
            [[ "$q" > "$p" ]] || continue
            for f in ${files[@]+"${files[@]}"}; do
                if patch_files "$q" | grep -qxF -- "$f" &&
                   git -C "$SRC_DIR" apply --reverse --check "$q" 2>/dev/null; then
                    echo "$(basename "$q")"
                    return 0
                fi
            done
        done
        return 1
    }
    if compgen -G "$SCRIPT_DIR/patches/*.patch" > /dev/null; then
        echo ">>> Applying carried OCCT patches to occt-src..."
        for p in "${patches[@]}"; do
            if git -C "$SRC_DIR" apply --reverse --check "$p" 2>/dev/null; then
                echo "    already applied: $(basename "$p")"
            elif git -C "$SRC_DIR" apply --check "$p" 2>/dev/null; then
                git -C "$SRC_DIR" apply "$p"
                echo "    applied: $(basename "$p")"
            elif by=$(superseded_by_applied_patch "$p"); then
                echo "    already applied (rewritten by $by): $(basename "$p")"
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

# Run a command under a wall-clock limit, in its own process group, and kill the whole group on
# expiry (#3058). macOS ships no timeout(1) or gtimeout, so this is perl, which it does ship.
#
# Group, not child: ThreadSanitizer's abort path can leave threads running after the process
# stops making progress, and `alarm` + `exec` signals only the one pid. The child calls setpgrp
# before exec, so `kill KILL, -pgid` reaches it and anything it spawned.
#
#   run_with_timeout <seconds> <flag-file> <command> [args...]
#
# Exit status is the command's own (128+signal when it died of one). On expiry the flag file is
# created and the status is 124, but callers must read the flag file, not 124: a harness can
# legitimately exit 124. Ctrl-C and SIGTERM kill the group too, so an interrupted gate leaves no
# orphan hammering the machine.
run_with_timeout() {
    perl -e '
        use POSIX ":sys_wait_h";
        my ($limit, $flag, @cmd) = @ARGV;
        my $pid = fork();
        die "fork: $!" unless defined $pid;
        if (!$pid) { setpgrp(0, 0); exec @cmd or exit 127; }
        # Parent calls it too: if the limit fires before the child has run its own call, the group
        # does not exist yet and the group kill would miss. Both calls is the setpgid(2) idiom
        # (shells do it); a late EACCES after the child has exec-ed is harmless, it is already leader.
        setpgrp($pid, $pid);
        $SIG{INT} = $SIG{TERM} = sub { kill "KILL", -$pid; waitpid($pid, 0); exit 130; };
        my $deadline = time + $limit;
        my ($timed_out, $st) = (0, 0);
        while (1) {
            my $r = waitpid($pid, WNOHANG);
            if ($r == $pid) { $st = $?; last; }
            if (time >= $deadline) {
                kill "KILL", -$pid;
                waitpid($pid, 0);
                $timed_out = 1;
                last;
            }
            select(undef, undef, undef, 0.1);
        }
        if ($timed_out) {
            # Status 125, not 124, when the flag cannot be written: the scenario WAS killed, and
            # run_one must still report a timeout rather than a plain failure with a stray status.
            open(my $f, ">", $flag) or do { print STDERR "run_with_timeout: cannot write flag $flag: $!\n"; exit 125; };
            close($f);
            exit 124;
        }
        exit(($st & 127) ? 128 + ($st & 127) : ($st >> 8));
    ' "$@"
}

# Run one scenario binary and print its verdict. Returns 0 if clean, 1 otherwise.
#
# A timeout is its own verdict, `TIMEOUT (killed after Ns)`, never a race count: the log of a
# wedged scenario can hold any number of warnings and none of them is the finding. It is counted
# in the "N/M scenarios clean" line like any failure, so it cannot pass.
#
#   run_one <binary> <log> <args...>
run_one() {
    local bin="$1" log="$2"
    shift 2
    local flag="${TSAN_TIMEOUT_FLAG:-$log.timeout}" status=0 started=$SECONDS
    TIMED_OUT=0
    rm -f "$flag"
    MMGT_OPT=0 \
    TSAN_OPTIONS="halt_on_error=0:exitcode=66:suppressions=$SUPP_FILE" \
        run_with_timeout "$SCENARIO_TIMEOUT" "$flag" "$bin" "$@" > "$log" 2>&1 || status=$?

    # 125 plus the wrapper's own message means it killed the scenario and then could not write the
    # flag; that is still a timeout and the message stays in the log (see run_with_timeout).
    local flag_error=""
    if [ "$status" -eq 125 ] && grep -q "^run_with_timeout: cannot write flag" "$log"; then
        flag_error=" (flag file unwritable, see log)"
    fi
    if [ -e "$flag" ] || [ -n "$flag_error" ]; then
        TIMED_OUT=1
        echo "TIMEOUT: $(basename "$bin") $* killed after $((SECONDS - started))s" \
             "(limit ${SCENARIO_TIMEOUT}s, whole process group)$flag_error: $log" >> "$log"
        echo "     TIMEOUT (killed after ${SCENARIO_TIMEOUT}s; ran $((SECONDS - started))s)$flag_error: $log"
        return 1
    fi

    local races
    races=$(grep -c "WARNING: ThreadSanitizer" "$log" || true)
    if [ "$status" -eq 0 ] && [ "$races" -eq 0 ]; then
        echo "     PASS (0 races)"
        return 0
    fi
    echo "     FAIL (exit $status, $races race warnings): $log"
    return 1
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

    local failures=0 total=0 timeouts=""
    TIMED_OUT=0
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
        # $args is deliberately unquoted: it is a space-separated argument list.
        # shellcheck disable=SC2086
        if ! run_one "$bin" "$log" $args; then
            failures=$((failures + 1))
            if [ "$TIMED_OUT" -eq 1 ]; then
                timeouts="$timeouts
    $(basename "$bin") $args"
            fi
        fi
    done

    echo ""
    echo ">>> TSan gate: $((total - failures))/$total scenarios clean"
    if [ -n "$timeouts" ]; then
        echo ">>> TIMED OUT (killed after ${SCENARIO_TIMEOUT}s each; a hang, not a race count):$timeouts"
    fi
    if [ "$failures" -gt 0 ]; then
        echo ">>> FAILED. Inspect the logs above. A race that is confirmed benign or is an"
        echo ">>> already-filed open kernel finding may be added to Scripts/tsan.supp, with"
        echo ">>> an issue link and removal condition (see the policy in that file)."
        exit 1
    fi
}

# Prove the timeout against stub scenarios, with no OCCT build. One stub hangs and leaves a
# grandchild behind, which is the shape #3058 measured; the others are clean, racing and failing
# stubs, which must keep their old verdicts and must run AFTER the hang.
do_self_test() {
    # local: run_one reads both by dynamic scope, and the script-level values are left alone.
    local dir ok=0 total=0 out SUPP_FILE=/dev/null SCENARIO_TIMEOUT="${TSAN_SCENARIO_TIMEOUT:-2}"
    dir=$(mktemp -d /tmp/occt-tsan-selftest.XXXXXX)

    printf '#!/bin/sh\nexit 0\n' > "$dir/clean"
    printf '#!/bin/sh\necho "WARNING: ThreadSanitizer: data race"\nexit 66\n' > "$dir/race"
    printf '#!/bin/sh\nexit 3\n' > "$dir/crash"
    # Wedged: a grandchild that outlives the parent's own death, then sleeps past the limit. The
    # grandchild records its pid so the test can ask whether the group kill reached it.
    printf '#!/bin/sh\nsleep 300 &\necho $! > "%s/grandchild.pid"\necho "ThreadSanitizer: SEGV"\nsleep 300\n' "$dir" > "$dir/hang"
    chmod +x "$dir"/clean "$dir"/race "$dir"/crash "$dir"/hang

    check() {
        total=$((total + 1))
        if [ "$2" = "yes" ]; then ok=$((ok + 1)); else echo "  FAIL  $1" >&2; fi
    }

    # Glob match without case/esac, whose `*)` terminator breaks bash 3.2's $(...) parser.
    has() { if [[ "$1" == $2 ]]; then echo yes; else echo no; fi; }

    local t0=$SECONDS
    out=$(run_one "$dir/hang" "$dir/hang.log" 8 20; echo "rc=$?")
    local elapsed=$((SECONDS - t0))
    echo "$out"
    check "a hanging scenario is reported as TIMEOUT" "$(has "$out" "*TIMEOUT (killed after ${SCENARIO_TIMEOUT}s*")"
    check "a timeout is a failure (returns 1)" "$(has "$out" "*rc=1")"
    check "it returned near the limit, not after the sleep (${elapsed}s)" "$([ "$elapsed" -le $((SCENARIO_TIMEOUT + 4)) ] && echo yes || echo no)"
    check "the log names the timeout" "$(grep -q '^TIMEOUT: hang ' "$dir/hang.log" && echo yes || echo no)"
    sleep 0.3
    local gc
    gc=$(cat "$dir/grandchild.pid" 2>/dev/null || echo 0)
    check "the whole process group was killed (grandchild $gc gone)" "$(kill -0 "$gc" 2>/dev/null && echo no || echo yes)"
    [ "$gc" -gt 0 ] && kill -9 "$gc" 2>/dev/null || true

    # An unwritable flag path: the scenario is still killed and still reported as a timeout, with
    # the wrapper's message in the log, not a plain FAIL.
    out=$(TSAN_TIMEOUT_FLAG=/nonexistent-dir/flag run_one "$dir/hang" "$dir/hang2.log" 8 20; echo "rc=$?")
    echo "$out"
    check "an unwritable flag path is still a TIMEOUT, not a plain FAIL" "$(has "$out" "*TIMEOUT (killed after*flag file unwritable*rc=1")"
    check "the wrapper's flag error reaches the scenario log" "$(grep -q 'cannot write flag /nonexistent-dir/flag' "$dir/hang2.log" && echo yes || echo no)"
    pkill -9 -f "$dir/hang" 2>/dev/null || true

    out=$(run_one "$dir/clean" "$dir/clean.log"; echo "rc=$?")
    check "a clean scenario after the hang still passes" "$(has "$out" "*PASS*rc=0")"
    out=$(run_one "$dir/race" "$dir/race.log"; echo "rc=$?")
    check "a racing scenario is FAIL with its race count, not TIMEOUT" "$(has "$out" "*FAIL (exit 66, 1 race warnings)*rc=1")"
    out=$(run_one "$dir/crash" "$dir/crash.log"; echo "rc=$?")
    check "a nonzero exit keeps its own status" "$(has "$out" "*FAIL (exit 3, 0 race*")"

    rm -rf "$dir"
    echo "self-test: $ok/$total cases correct"
    [ "$ok" -eq "$total" ]
}

do_swift() {
    # Wrapper-only coverage: SwiftPM instruments the Swift + OCCTBridge sources,
    # but the prebuilt OCCT.xcframework is NOT instrumented, so races entirely
    # inside the kernel are invisible here. Kernel coverage comes from do_run.
    local filter="${SWIFT_FILTER:-Thread|Stress|Concurren|Parallel}"
    echo ">>> swift test --sanitize=thread --filter \"$filter\""
    # TSAN_OPTIONS is not optional here, it is what makes this a gate rather than a report.
    # Without it a detected race prints to stdout and the process still exits 0, because the
    # suites in this filter are deliberately exercisers: they assert "did not deadlock, did not
    # crash", which stays true while a race is being reported three lines above. Measured
    # 2026-09-19 during #1404: a run that reported a data race in
    # TObj_Application::SetVerbose exited 0 and this function called it a pass. exitcode=66
    # matches do_run's, so both halves of the gate fail the same way, and the same suppression
    # file applies to both.
    (cd "$PROJECT_DIR" &&
       TSAN_OPTIONS="halt_on_error=0:exitcode=66:suppressions=$SUPP_FILE" \
         swift test --sanitize=thread --filter "$filter")
}

case "${1:-}" in
    build) do_build ;;
    run)   do_run ;;
    swift) do_swift ;;
    self-test) do_self_test ;;
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
        sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
