#!/bin/bash
#
# Optimised-build (`-c release`) test run, for the class of defect a debug build hides (#3130).
#
# Swift may release an owning wrapper (`let edges = box.edges()`) as soon as its last use is the
# `.handle` load, before the C call that receives the pointer runs. A debug build extends every
# lifetime to scope end, so `swift test` (ci.yml's `build-and-test`) cannot see it. Measured and
# explained in Scripts/repro/3130-borrowed-handle/README.md and docs/architecture/overview.md.
#
# Usage:
#   Scripts/release-mode-test.sh subset   Build every test target, run only the suites that call a
#                                         bridge function with a raw `.handle`/`withHandle`.
#   Scripts/release-mode-test.sh full     Build every test target, run the whole suite.
#   Scripts/release-mode-test.sh list     Print the subset's suite names, build nothing.
#
# The subset is DERIVED, not listed: every Tests/**/*.swift that mentions `.handle` or
# `withHandle` contributes its `struct` names (the `--filter` argument matches the struct name, see
# CLAUDE.md "Test Layout"). A hand-kept list would silently stop covering the next suite that
# passes a raw pointer into a bridge call. Issue3130BorrowedHandle is such a file, so the
# regression test for `withHandle` itself is always in.
#
# Both scopes build every test target. `swift test --skip-build` insists on every target's
# .xctest bundle (measured: "OCCTThreadTests.xctest doesn't exist in file system" with only the
# subset's targets built), and `swift build --target A --target B` builds only B (measured: Math in
# 4 s, Topology left stale), so a narrower build is not available short of driving the bundles by
# hand. What the subset saves is the test phase, not the build; the numbers and the reason for the
# split are in okf/policies/release-mode-tests.md.
#
# The test run (not the build) is under MallocScribble and MallocPreScribble: a freed block is
# overwritten with a pattern instead of left readable, which is what made the original
# use-after-free fail 7 of 8 runs instead of reading stale-but-plausible memory. MallocGuardEdges
# and MallocErrorAbort are set too (the malloc-scribble-stress.yml set): measured on the whole
# suite, 4 of 4 runs green and no slower than scribbling alone.
#
# Run from anywhere; it cds to the repo root. An ambient OCCTSWIFT_BRIDGE_PREBUILT is unset, since
# a prebuilt bridge would hide a bridge-side change from the optimised build.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
unset OCCTSWIFT_BRIDGE_PREBUILT

mode="${1:-}"

# Files whose tests hand a raw native pointer to the bridge.
handle_files() {
  grep -rlE '\.handle\b|withHandle' Tests --include='*.swift' | sort
}

subset_suites() {
  # shellcheck disable=SC2046
  grep -hoE '^(public |private |fileprivate )?(final )?struct [A-Za-z0-9_]+' $(handle_files) \
    | awk '{print $NF}' | sort -u
}

case "$mode" in
  list)
    subset_suites
    exit 0
    ;;
  subset | full) ;;
  *)
    echo "usage: $0 subset|full|list" >&2
    exit 2
    ;;
esac

flags=(-c release -Xswiftc -enable-testing)

swift build "${flags[@]}" --build-tests

if [ "$mode" = full ]; then
  test_args=()
else
  [ -n "$(subset_suites)" ] || {
    echo "::error::no test file mentions .handle: the subset is empty" >&2
    exit 1
  }
  regex="$(subset_suites | paste -sd'|' -)"
  echo "subset filter: $regex"
  test_args=(--filter "$regex")
fi

mkdir -p .build
# `set -o pipefail` keeps swift test's own exit status through the tee.
MallocScribble=1 MallocPreScribble=1 MallocGuardEdges=1 MallocErrorAbort=1 \
  swift test "${flags[@]}" --skip-build ${test_args[@]+"${test_args[@]}"} 2>&1 | tee .build/release-mode-test.log
