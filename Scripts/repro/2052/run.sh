#!/bin/bash
# #2052: does the Phase 0 spike module run in a real browser, and does its filesystem story hold?
#
# #2175 linked and ran the whole stack under `wasmkit` on macOS and returned GO with four
# conditions. The second of them is that NOTHING HAS RUN IN A BROWSER: the browser filesystem shape
# was inferred from the host-import list being identical, which is a reason to expect it and not a
# measurement. This is the measurement.
#
# Three rungs, each isolating one variable against the one below it:
#
#   1. wasmkit, real directory on disk          already measured, Scripts/repro/2175
#   2. Node + browser_wasi_shim, in-memory      `./run.sh node`
#   3. a real browser, same shim, same code     `./run.sh serve` then load the page
#
# Rung 2 exists so that a rung 3 failure has somewhere to land. If 2 passes and 3 does not, the
# browser is the variable. If both fail, the shim or its in-memory filesystem is, and the module is
# exonerated either way. web/harness.mjs is imported unchanged by both, which is what makes that
# inference valid rather than approximate.
#
# Usage:
#   ./run.sh stage    fetch the pinned shim and stage module + page into .stage/
#   ./run.sh node     rung 2. Asserts. Exits non-zero on any failed case.
#   ./run.sh serve    rung 3. Serves .stage/ and prints the URL to open.
#   ./run.sh all      stage + node
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE="$HERE/.stage"
PORT="${PORT:-8052}"

# Pinned, because the shim's behaviour is part of what is being measured and an unpinned `@latest`
# would make a later re-run a different experiment. See README.md for what 0.4.2 specifically does.
SHIM_PKG="@bjorn3/browser_wasi_shim@0.4.2"

# The module is Scripts/repro/2175's Release build. It is NOT rebuilt here: rebuilding it needs
# wasi-sdk, a Swift wasm SDK and a 69-minute OCCT build, and this issue is about the host side.
# Override with SPIKE_MODULE=... to point at your own build.
DEFAULT_MODULE="$HERE/../2175/spike/.build/out/Products/Release-webassembly-wasm32/OCCTWasmSpike.wasm"
MODULE="${SPIKE_MODULE:-$DEFAULT_MODULE}"

# The sha256 of the module every number in README.md was measured against. A mismatch is not an
# error (you may legitimately have rebuilt it), but it is reported, because a README full of exact
# byte counts taken against a different binary is the failure mode this line exists to prevent.
PINNED_SHA="3ff64f6b8cfcad9d23333bbd562ee55b3157e6c5461d2b387498b42198d8a774"

die() { echo "error: $*" >&2; exit 1; }

check_module() {
    [ -f "$MODULE" ] || die "no module at $MODULE
  Build it with Scripts/repro/2175/run.sh, or set SPIKE_MODULE to yours."
    local actual
    actual="$(shasum -a 256 "$MODULE" | cut -d' ' -f1)"
    echo "module: $MODULE"
    echo "        $(wc -c < "$MODULE" | tr -d ' ') bytes, sha256 $actual"
    if [ "$actual" != "$PINNED_SHA" ]; then
        echo "        NOTE: this is not the binary README.md's numbers were taken against"
        echo "              (pinned $PINNED_SHA)"
    fi
}

do_stage() {
    check_module
    command -v npm >/dev/null || die "npm not on PATH; needed once to fetch $SHIM_PKG"
    rm -rf "$STAGE"
    mkdir -p "$STAGE"
    echo "fetching $SHIM_PKG ..."
    # The manifest is written rather than `npm init -y`'d: npm infers the package name from the
    # directory, and refuses `.stage` with `Invalid name: ".stage"`, which under `set -e` ends the
    # run with no output at all.
    printf '{"name":"occtswift-2052-stage","version":"0.0.0","private":true,"type":"module"}\n' \
        > "$STAGE/package.json"
    ( cd "$STAGE" && npm install --silent "$SHIM_PKG" >/dev/null )
    cp -R "$STAGE/node_modules/@bjorn3/browser_wasi_shim/dist" "$STAGE/browser_wasi_shim"
    rm -rf "$STAGE/node_modules" "$STAGE/package.json" "$STAGE/package-lock.json"
    cp "$HERE/web/harness.mjs" "$HERE/web/node-run.mjs" "$HERE/web/serve.mjs" \
       "$HERE/web/index.html" "$STAGE/"
    # Copied rather than symlinked: a symlink out of the served root is exactly what serve.mjs's
    # traversal guard is there to refuse, and the browser would get a 404 that reads as a bug.
    cp "$MODULE" "$STAGE/OCCTWasmSpike.wasm"
    echo "staged into $STAGE"
}

do_node() {
    [ -d "$STAGE" ] || die "run './run.sh stage' first"
    command -v node >/dev/null || die "node not on PATH"
    echo "===================================================================="
    echo "RUNG 2: Node, browser_wasi_shim, in-memory preopens"
    echo "===================================================================="
    ( cd "$STAGE" && node node-run.mjs ./OCCTWasmSpike.wasm )
}

do_serve() {
    [ -d "$STAGE" ] || die "run './run.sh stage' first"
    echo "===================================================================="
    echo "RUNG 3: a real browser"
    echo "===================================================================="
    echo "Open http://127.0.0.1:$PORT/ and read the verdict at the top of the page."
    echo "window.__RESULT__ carries the whole run record for a driver to read."
    ( cd "$STAGE" && node serve.mjs . "$PORT" )
}

case "${1:-all}" in
    stage) do_stage ;;
    node)  do_node ;;
    serve) do_serve ;;
    all)   do_stage; do_node ;;
    *)     die "unknown command '$1'. One of: stage, node, serve, all" ;;
esac
