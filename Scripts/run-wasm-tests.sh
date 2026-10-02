#!/usr/bin/env bash
#
# Build and run the per-domain test suites for wasm32-unknown-wasip1 (#2793).
#
# Phase 0's GO carried four conditions and this closes the third: before this script the only thing
# that ran for wasm was #2052's six spike calls, which is a smoke test and not coverage. EVERY
# per-domain target runs here, since #2928 took `Package.swift`'s whole-target exclusion list to
# empty; that file documents the individual files still excluded and why each one is.
#
#   ./Scripts/run-wasm-tests.sh                  build, then run every suite
#   ./Scripts/run-wasm-tests.sh list             print the suites that would run
#   ./Scripts/run-wasm-tests.sh run OCCTMathTests [...]   run named suites only, no build
#   ./Scripts/run-wasm-tests.sh build            build only
#
# WASM_TEST_TIMEOUT caps each suite in seconds (default 900).
#
# WHY THIS IS A SCRIPT AND NOT `swift test --swift-sdk`. SwiftPM cannot run a wasm test bundle: it
# builds one `<Target>-test-runner.wasm` per test target and has no runner for the triple. This
# drives them under the pinned wasmkit, which is what `Scripts/repro/2175/run.sh` does for the spike.
#
# THE RUNNER NEEDS `--testing-library swift-testing`, AND THAT IS NOT A PREFERENCE. Without it the
# generated entry point runs XCTest first, and XCTest's `XCTMain` reads `Bundle.main`, which traps on
# WASI before a single test executes. Measured: the trap is in
# `Foundation.Bundle.main.unsafeMutableAddressor` under `XCTMainMisc`. Every test in this package is
# Swift Testing, so nothing is skipped by selecting it. `--disable-xctest` at build time would be
# the tidier fix and does NOT work: the flag is accepted and the new Swift Build system relinks the
# runner with XCTest anyway.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

PINS="$SCRIPT_DIR/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }
die() { echo "$*" >&2; exit 2; }

TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
if [ ! -x "$TOOLCHAIN_BIN/swift" ]; then
    # The Linux/CI shape: the swift.org toolchain IS the image, so it is simply on PATH.
    TOOLCHAIN_BIN="$(dirname "$(command -v swift)")"
fi
SWIFT="$TOOLCHAIN_BIN/swift"
WASMKIT="${WASMKIT:-$TOOLCHAIN_BIN/wasmkit}"

# THE SUITES RUN UNDER NODE, NOT wasmkit, AND #2894 IS WHY. The same module file, byte for byte, was
# measured under both: an OCCT exception thrown several frames below the bridge's `catch (...)` is
# caught under Node and reaches `std::terminate` under wasmkit 0.3.1, ending the module. The compiler
# output is not the variable, so a suite run under wasmkit measures the interpreter's exception
# handling rather than the target's, and the target for #1689 is a browser.
#
# wasmkit is kept reachable with WASM_TEST_RUNTIME=wasmkit, because the comparison is worth being able
# to repeat and because it is what `Scripts/repro/2175/run.sh` still uses for the spike.
WASM_TEST_RUNTIME="${WASM_TEST_RUNTIME:-node}"
SHIM_PKG="@bjorn3/browser_wasi_shim@0.4.2"
SHIM_DIR="${WASM_TEST_SHIM_DIR:-$REPO_DIR/.build/wasm-test-shim/browser_wasi_shim}"

# Fetched once and cached, keyed by nothing cleverer than the directory existing: the package is
# pinned by exact version above, which is the same pin #2052's browser rungs use so that a
# disagreement between this and the browser page isolates the browser and not the WASI surface.
ensure_shim() {
    [ -f "$SHIM_DIR/index.js" ] && return 0
    command -v npm >/dev/null || die "npm not on PATH; needed once to fetch $SHIM_PKG"
    local staging
    staging="$(dirname "$SHIM_DIR")"
    rm -rf "$staging"
    mkdir -p "$staging"
    echo ">>> fetching $SHIM_PKG (once, cached in $staging)"
    # The manifest is written rather than `npm init -y`'d: npm infers the name from the directory and
    # refuses one beginning with a dot, which under `set -e` ends the run with no output at all.
    printf '{"name":"occtswift-wasm-test-shim","version":"0.0.0","private":true,"type":"module"}\n' \
        > "$staging/package.json"
    ( cd "$staging" && npm install --silent "$SHIM_PKG" >/dev/null ) \
        || die "npm install $SHIM_PKG failed in $staging. The shim is the only network dependency these suites have; WASM_TEST_RUNTIME=wasmkit runs them without it, at the cost of the exception behaviour #2894 measured."
    cp -R "$staging/node_modules/@bjorn3/browser_wasi_shim/dist" "$SHIM_DIR"
    rm -rf "$staging/node_modules" "$staging/package.json" "$staging/package-lock.json"
}
SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
KNOWN_FAILURES="$SCRIPT_DIR/wasm-test-known-failures.txt"

case "$WASM_TEST_RUNTIME" in
    node)
        command -v node >/dev/null || die "node not on PATH (or set WASM_TEST_RUNTIME=wasmkit)"
        ;;
    wasmkit)
        [ -x "$WASMKIT" ] || die "no wasmkit at $WASMKIT (set WASMKIT=)"
        ;;
    *)
        die "WASM_TEST_RUNTIME must be 'node' or 'wasmkit', not '$WASM_TEST_RUNTIME'"
        ;;
esac
[ -f Libraries/libOCCT-wasm.a ] || { echo "no Libraries/libOCCT-wasm.a: run Scripts/fetch-occt-wasm.sh"; exit 2; }

TOOLSET="${TOOLSET:-}"
if [ -z "$TOOLSET" ]; then
    TOOLSET="$(mktemp -t wasm-toolset).json"
    python3 "$SCRIPT_DIR/make-wasi-toolset.py" -o "$TOOLSET" >/dev/null
fi

# `-Xswiftc -enable-testing` is REQUIRED and is not belt and braces. In release configuration
# SwiftPM does not pass it, so `@testable import OCCTSwift` fails with "module 'OCCTSwift' was not
# compiled for testing" in all 13 targets. Release rather than debug because that is what the rest of
# the wasm pipeline uses and because a debug wasm module of this size is not worth the wall clock.
# `--no-parallel` IS NOT A PREFERENCE EITHER, AND THE MEASUREMENT IS WHY. Swift Testing runs tests
# in parallel by default. On a single-threaded target that means hundreds of concurrent tasks on one
# cooperative executor, and the result is not slower-but-fine: running `OCCTCurveTests` in the default
# mode printed 563 "started" lines and **zero** completions, because the slow tests interleave with
# everything else and nothing finishes. The same runner with `--no-parallel` completed 281 tests in
# under three minutes. Parallelism buys nothing here and costs the ability to see progress at all.
# TWO ARGUMENT LISTS, AND THE SPLIT IS NOT COSMETIC. `wasmkit run [options] <module> [args...]`:
# anything after the module path is handed to the GUEST, so a `--dir` or `--env` placed there is
# silently accepted, passed to Swift Testing, ignored, and the preopen never happens. That cost a
# round of wrong conclusions here, because running wasmkit by hand with the flags in the right order
# passed while the script with the same flags in the wrong order failed.
TEST_ARGS=(--testing-library swift-testing --no-parallel)

# THE SUITES NEED A WRITABLE PREOPEN, and a missing one does not look like an environment problem, it
# looks like a geometry failure. `Issue336ChainedHistoryTests` failed with
# `.exportFailed("BREP export to issue336-....brep failed")` until this was added: the test writes a
# BREP to a temp path, WASI grants no filesystem access unless the host preopens it, and the bridge
# reported the refusal the same way it reports a bad shape.
#
# `/tmp` is preopened as well because that is what `FileManager.default.temporaryDirectory` falls
# back to, which is the same pair `Scripts/repro/2175/run.sh` passes and for the same reason.
#
# TMPDIR IS PINNED, AND THE PREOPENS ALONE ARE NOT ENOUGH. wasmkit passes no host environment, so
# without this the guest's TMPDIR is unset and `FileManager.default.temporaryDirectory` resolves
# somewhere the preopens do not cover. Measured on the full `OCCTBRepGraphTests` suite: 1 failing with
# both preopens and no TMPDIR, 0 failing with TMPDIR set to the work directory. It passed under
# `--filter Issue336` either way, which is what made the preopens look sufficient.
#
# `docs/guides/wasm-consumer-setup.md` already states this requirement for consumers ("set `TMPDIR`
# and preopen it", with a browser example that passes `TMPDIR=/tmp`). This script simply was not
# following it. Worth knowing that the symptom does not look like a configuration problem: the
# bridge reports a denied write as `.exportFailed`, which reads as a geometry or history defect.
WASM_TEST_WORK_DIR="${WASM_TEST_WORK_DIR:-/tmp/occt-wasm-tests}"
mkdir -p "$WASM_TEST_WORK_DIR"
WASMKIT_ARGS=(--dir "$WASM_TEST_WORK_DIR" --dir /tmp --env "TMPDIR=$WASM_TEST_WORK_DIR")

BUILD_ARGS=(
    --toolset "$TOOLSET"
    --swift-sdk "$SDK_ID"
    --triple "$TRIPLE"
    -c release
    --build-tests
    -Xswiftc -enable-testing
)

build() {
    # THE TEST PRODUCTS ARE DELETED FIRST, AND THIS IS NOT BELT AND BRACES. Swift Build does not
    # re-plan when a target's `exclude:` list changes: the archive is rebuilt, with a fresh mtime and
    # an identical size, still containing the excluded file's symbols. Measured twice, the second
    # time after the first had already been written down in `Scripts/repro/2793/README.md`: the
    # manifest listed `Issue612FilletContourSelectionTests.swift` as excluded while
    # `libOCCTModelingTests.a` still held 256 of its symbols, so the suite kept trapping on a test
    # that was supposed to be gone.
    #
    # Deleting them costs the same two minutes the build already costs, and CI builds clean anyway,
    # so the only thing this changes is that a local run cannot silently test a stale exclusion set.
    local products
    products="$(bin_path)"
    rm -rf "$products"/libOCCT*Tests.a "$products"/*-test-runner.wasm
    echo ">>> building the wasm test runners"
    OCCTSWIFT_WASI=1 "$SWIFT" build "${BUILD_ARGS[@]}"
}

bin_path() {
    OCCTSWIFT_WASI=1 "$SWIFT" build "${BUILD_ARGS[@]}" --show-bin-path
}

# A SUITE THAT MAKES NO PROGRESS MUST BE REPORTED, NOT WAITED ON. The first full run sat on
# `OCCTCurveTests` with no output for minutes, which in CI is a job that burns its whole timeout and
# reports nothing. Every suite therefore runs under a wall-clock cap, and exceeding it is a hard
# failure that no known-failure list can excuse.
#
# `timeout` is coreutils and is not on a stock macOS; `gtimeout` is there with Homebrew coreutils.
# Neither is required: the fallback is a watchdog subshell, and a suite killed that way exits 137.
#
# RAISED FROM 900 BY #2928, which brought the remaining five targets in, and the raise is necessary
# rather than cautious. `OCCTThreadTests` is now the slowest suite by a wide margin: measured 8
# minutes 34 seconds on an idle machine and 16 MINUTES 52 SECONDS on the same machine under load,
# against 224 seconds for the whole 13-suite run before it. The loaded figure is past 900 s, so the
# old cap would have failed that run on the clock rather than on a result. Screw-thread geometry is
# helical sweeps and booleans, and single tests take 32 and 41 seconds. The whole 18-suite run
# measured 17 minutes idle and 29 loaded, 6,548 tests either way.
WASM_TEST_TIMEOUT="${WASM_TEST_TIMEOUT:-1800}"

if command -v timeout >/dev/null 2>&1; then
    with_timeout() { timeout -s KILL "$WASM_TEST_TIMEOUT" "$@"; }
elif command -v gtimeout >/dev/null 2>&1; then
    with_timeout() { gtimeout -s KILL "$WASM_TEST_TIMEOUT" "$@"; }
else
    with_timeout() {
        "$@" &
        local pid=$!
        ( sleep "$WASM_TEST_TIMEOUT"; kill -9 "$pid" 2>/dev/null ) &
        local watchdog=$!
        local status=0
        wait "$pid" || status=$?
        kill -9 "$watchdog" 2>/dev/null || true
        wait "$watchdog" 2>/dev/null || true
        return $status
    }
fi

# The failure identifier as Swift Testing prints it, which is what the known-failure list holds.
#
# WHICH LINE SHAPES THIS HANDLES, and which it does not. Measured across the twelve transcripts of a
# full run, the `✘` lines are: `✘ Test <name> recorded an issue ...`, `✘ Test <name> failed after
# ...`, `✘ Test run with N tests ...` and `✘ Suite <name> failed after ...`. The first two are the
# ones taken. The run line is dropped by the `grep -v` below, and suite lines are ignored
# deliberately: a failing suite always prints its failing tests too, so counting it as well would
# double-count and would put a suite name in a list that holds test names.
#
# NOT handled: `✘ Test case passing N arguments ... to "<name>"`, which is what a parameterised case
# prints. No failure in this project takes that shape today, measured, so nothing is missed now. If
# one appears, the identifier extracted carries the argument list, matches no entry in the
# known-failure list, and is reported as a NEW FAILURE. That is the safe direction: the run fails
# loudly rather than passing something unrecognised, and the fix at that point is to teach this
# function the shape rather than to widen the list.
#
# `|| true` ON BOTH, AND IT IS LOAD-BEARING. `grep -v` exits 1 when it emits nothing, so under
# `set -e` a suite with ZERO failures made the `failed=$(failing_names ...)` assignment fail and the
# script exit silently, mid-loop, on the first clean suite. It reported two suites and stopped, and
# because the caller piped it to `tail` even the exit status looked like success.
failing_names() {
    { sed -n 's/^✘ Test \(.*\) recorded an issue.*/\1/p;s/^✘ Test \(.*\) failed after.*/\1/p' "$1" \
        | grep -v '^run with ' || true; } | sort -u
}

# TWO SPACES BEFORE THE `#`, AND THAT IS THE WHOLE COMMENT SYNTAX. Test names in this project contain
# issue references: `"the by-plane per-face sum is the volume, for any plane (#2827)"`. Stripping from
# the first `#` truncated every one of them mid-name and turned the comparison below into nonsense, so
# the marker is `<two spaces>#` and `(#2827)` cannot collide with it.
expected_names() {
    { grep -v '^[[:space:]]*#' "$KNOWN_FAILURES" | grep -v '^[[:space:]]*$' \
        | sed 's/  #.*$//' | sed 's/[[:space:]]*$//' || true; } | sort -u
}

BIN=""
case "${1:-all}" in
    build) build; exit 0 ;;
    list)
        BIN="$(bin_path)"
        for r in "$BIN"/*-test-runner.wasm; do basename "$r" -test-runner.wasm; done
        exit 0
        ;;
    run) shift; BIN="$(bin_path)" ;;
    all) build; BIN="$(bin_path)" ;;
    *) echo "usage: $0 [all|build|list|run <suite>...]"; exit 2 ;;
esac

RUNNERS=()
FULL_RUN=1
if [ "$#" -gt 0 ]; then
    for n in "$@"; do RUNNERS+=("$BIN/$n-test-runner.wasm"); done
    # A subset cannot say anything about the whole known-failure list: every entry belonging to a
    # suite that did not run would read as "started passing". Named suites therefore check only for
    # NEW failures, and the exact-set assertion is kept for the full run.
    FULL_RUN=0
else
    for r in "$BIN"/*-test-runner.wasm; do RUNNERS+=("$r"); done
fi

OUT_DIR="${WASM_TEST_OUT_DIR:-$(mktemp -d -t wasm-tests)}"
mkdir -p "$OUT_DIR"
if [ "$WASM_TEST_RUNTIME" = "node" ]; then
    ensure_shim
    runtime_label="node $(node --version) + $SHIM_PKG"
else
    runtime_label="wasmkit $("$WASMKIT" --version 2>/dev/null || echo "(version unknown)")"
fi
echo ">>> running ${#RUNNERS[@]} suite(s) under $runtime_label"
echo ">>> transcripts in $OUT_DIR"
echo ""

TOTAL_TESTS=0
ALL_FAILING="$OUT_DIR/.failing"
: > "$ALL_FAILING"

for runner in "${RUNNERS[@]}"; do
    name="$(basename "$runner" -test-runner.wasm)"
    log="$OUT_DIR/$name.out"
    # wasmkit's exit status is the module's, so a non-zero here is "tests failed" or "trapped", and
    # the two are told apart below by whether the transcript has a summary line at all.
    set +e
    if [ "$WASM_TEST_RUNTIME" = "node" ]; then
        # The preopens and TMPDIR live inside the runner script, because they are properties of the
        # in-memory filesystem it builds rather than of this loop.
        with_timeout node "$SCRIPT_DIR/wasm-test-node-runner.mjs" "$SHIM_DIR" "$runner" \
            "${TEST_ARGS[@]}" > "$log" 2>&1
    else
        with_timeout "$WASMKIT" run "${WASMKIT_ARGS[@]}" "$runner" "${TEST_ARGS[@]}" > "$log" 2>&1
    fi
    run_status=$?
    set -e
    summary="$(sed -n 's/.*Test run with \([0-9]*\) tests in \([0-9]*\) suites.*/\1 tests, \2 suites/p' "$log" | tail -1)"
    if [ "$run_status" = "70" ]; then
        echo "  TRAPPED  $name"
        sed -n 's/^TRAP: /           /p' "$log" | head -2
        echo "$name: TRAPPED" >> "$ALL_FAILING"
        continue
    fi
    if [ "$run_status" = "137" ] || [ "$run_status" = "124" ]; then
        echo "  TIMEOUT  $name"
        echo "           no result after ${WASM_TEST_TIMEOUT}s. Last line: $(tail -1 "$log" | cut -c1-100)"
        echo "$name: TIMEOUT" >> "$ALL_FAILING"
        continue
    fi
    if [ -z "$summary" ]; then
        echo "  TRAPPED  $name"
        echo "           no summary line: the module died rather than reporting. Transcript: $log"
        sed -n '/^Error: Trap/,+4p' "$log" | sed 's/^/           /'
        echo "$name: TRAPPED" >> "$ALL_FAILING"
        continue
    fi
    count="$(echo "$summary" | sed 's/ tests.*//')"
    TOTAL_TESTS=$((TOTAL_TESTS + count))
    failed="$(failing_names "$log" | wc -l | tr -d ' ')"
    if [ "$failed" = "0" ]; then
        printf "  ok       %-24s %s\n" "$name" "$summary"
    else
        printf "  %-8s %-24s %s, %s failing\n" "FAILED" "$name" "$summary" "$failed"
        failing_names "$log" >> "$ALL_FAILING"
    fi
done

echo ""
echo ">>> $TOTAL_TESTS tests across ${#RUNNERS[@]} suite(s)"

if grep -qE ': (TRAPPED|TIMEOUT)$' "$ALL_FAILING" 2>/dev/null; then
    echo ""
    echo "A suite trapped or timed out. Neither is ever an expected outcome and neither can be listed"
    echo "as a known failure: both end the module, so every test after the one that did it is"
    echo "unreported and the counts above are not the whole suite."
    exit 1
fi

ACTUAL="$(sort -u "$ALL_FAILING")"
EXPECTED="$(expected_names)"

UNEXPECTED_FAILS="$(comm -23 <(echo "$ACTUAL") <(echo "$EXPECTED") | grep -v '^$' || true)"
UNEXPECTED_PASSES="$(comm -13 <(echo "$ACTUAL") <(echo "$EXPECTED") | grep -v '^$' || true)"

status=0
if [ -n "$UNEXPECTED_FAILS" ]; then
    echo ""
    echo "NEW FAILURES, not in $KNOWN_FAILURES:"
    echo "$UNEXPECTED_FAILS" | sed 's/^/  /'
    status=1
fi
if [ -n "$UNEXPECTED_PASSES" ] && [ "$FULL_RUN" = "1" ]; then
    echo ""
    echo "These are listed as known failures and PASSED. Remove them from the list: a line nobody"
    echo "removes is how a fixed defect stays recorded as broken."
    echo "$UNEXPECTED_PASSES" | sed 's/^/  /'
    status=1
fi

if [ "$status" = "0" ]; then
    if [ "$FULL_RUN" = "1" ]; then
        echo "$(echo "$EXPECTED" | grep -c .) known failures, all accounted for. PASS"
    else
        echo "no new failures in the named suite(s). PASS (subset: the known-failure list is not asserted)"
    fi
fi
exit $status
