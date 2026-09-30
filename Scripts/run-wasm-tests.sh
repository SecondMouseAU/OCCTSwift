#!/usr/bin/env bash
#
# Build and run the per-domain test suites for wasm32-unknown-wasip1 (#2793).
#
# Phase 0's GO carried four conditions and this closes the third: before this script the only thing
# that ran for wasm was #2052's six spike calls, which is a smoke test and not coverage. 13 of the
# 18 domain targets run here; `Package.swift` documents which five cannot exist on the platform and
# why, and which individual files are excluded from the 13.
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

TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
if [ ! -x "$TOOLCHAIN_BIN/swift" ]; then
    # The Linux/CI shape: the swift.org toolchain IS the image, so it is simply on PATH.
    TOOLCHAIN_BIN="$(dirname "$(command -v swift)")"
fi
SWIFT="$TOOLCHAIN_BIN/swift"
WASMKIT="${WASMKIT:-$TOOLCHAIN_BIN/wasmkit}"
SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
KNOWN_FAILURES="$SCRIPT_DIR/wasm-test-known-failures.txt"

[ -x "$WASMKIT" ] || { echo "no wasmkit at $WASMKIT (set WASMKIT=)"; exit 2; }
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
RUN_ARGS=(--testing-library swift-testing --no-parallel)

BUILD_ARGS=(
    --toolset "$TOOLSET"
    --swift-sdk "$SDK_ID"
    --triple "$TRIPLE"
    -c release
    --build-tests
    -Xswiftc -enable-testing
)

build() {
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
WASM_TEST_TIMEOUT="${WASM_TEST_TIMEOUT:-900}"

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
# `|| true` ON BOTH, AND IT IS LOAD-BEARING. `grep -v` exits 1 when it emits nothing, so under
# `set -e` a suite with ZERO failures made the `failed=$(failing_names ...)` assignment fail and the
# script exit silently, mid-loop, on the first clean suite. It reported two suites and stopped, and
# because the caller piped it to `tail` even the exit status looked like success.
failing_names() {
    { sed -n 's/^✘ Test \(.*\) recorded an issue.*/\1/p;s/^✘ Test \(.*\) failed after.*/\1/p' "$1" \
        | grep -v '^run with ' || true; } | sort -u
}

expected_names() {
    { grep -v '^[[:space:]]*#' "$KNOWN_FAILURES" | grep -v '^[[:space:]]*$' \
        | sed 's/[[:space:]]*#.*$//' | sed 's/[[:space:]]*$//' || true; } | sort -u
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
if [ "$#" -gt 0 ]; then
    for n in "$@"; do RUNNERS+=("$BIN/$n-test-runner.wasm"); done
else
    for r in "$BIN"/*-test-runner.wasm; do RUNNERS+=("$r"); done
fi

OUT_DIR="${WASM_TEST_OUT_DIR:-$(mktemp -d -t wasm-tests)}"
mkdir -p "$OUT_DIR"
echo ">>> running ${#RUNNERS[@]} suite(s) under $("$WASMKIT" --version 2>/dev/null || echo wasmkit)"
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
    with_timeout "$WASMKIT" run "$runner" "${RUN_ARGS[@]}" > "$log" 2>&1
    run_status=$?
    set -e
    summary="$(sed -n 's/.*Test run with \([0-9]*\) tests in \([0-9]*\) suites.*/\1 tests, \2 suites/p' "$log" | tail -1)"
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
if [ -n "$UNEXPECTED_PASSES" ]; then
    echo ""
    echo "These are listed as known failures and PASSED. Remove them from the list: a line nobody"
    echo "removes is how a fixed defect stays recorded as broken."
    echo "$UNEXPECTED_PASSES" | sed 's/^/  /'
    status=1
fi

if [ "$status" = "0" ]; then
    echo "$(echo "$EXPECTED" | grep -c . ) known failures, all accounted for. PASS"
fi
exit $status
