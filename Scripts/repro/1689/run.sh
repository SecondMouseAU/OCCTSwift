#!/bin/bash
# #1689: can the project that asked for this actually use it?
#
# Everything else in Scripts/repro/217x and 2052 measures OCCTSwift from INSIDE this repository, or
# through a spike that reaches it by a path dependency. Neither is what a consumer does. This builds
# a separate package that depends on OCCTSwift the way an application would, and exercises exactly
# the API list #1689 asked for:
#
#   "Must expose: Shape.loadSTEP, Shape.writeSTEP, basic BRep construction (makeBox, makeCylinder)"
#   "Compatible with three.js WebGL context"
#
# The second of those is why `mesh` is in here. A browser CAD app has to DISPLAY geometry, not only
# export it, and #2175's six cases never touched tessellation. This was the first run of
# Shape.mesh() on wasm.
#
# Usage:
#   ./run.sh            resolve, fetch the kernel, build, run. Asserts.
#   ./run.sh --print    show the commands without running them
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$HERE/probe"
WORK="${WORK_DIR:-$HERE/.work}"

if [ "${1:-}" = "--print" ]; then
    sed -n '/^# Usage/,/^set -e/p' "${BASH_SOURCE[0]}"
    exit 0
fi

die() { echo "ERROR: $*" >&2; exit 1; }
command -v node >/dev/null || true

: "${WASI_SDK_PREFIX:?set WASI_SDK_PREFIX to a wasi-sdk install, see Scripts/install-wasm-toolchain.sh}"

cd "$PROBE"

echo ">>> resolving OCCTSwift as a consumer would"
OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift package resolve

CHECKOUT="$PROBE/.build/checkouts/OCCTSwift"
[ -d "$CHECKOUT" ] || die "no OCCTSwift checkout at $CHECKOUT"

# The checkout has no kernel: Libraries/ is gitignored in OCCTSwift, so a consumer gets dummy.c and
# include/ and nothing else. This is the step that makes the difference between a 69-minute build
# and a download, and it is the one a consumer has to be told about.
echo ">>> fetching the prebuilt kernel into the checkout"
"$CHECKOUT/Scripts/fetch-occt-wasm.sh"

echo ">>> generating the consumer toolset"
python3 "$CHECKOUT/Scripts/make-wasi-toolset.py" --wasi-sdk "$WASI_SDK_PREFIX" -o "$PROBE/toolset.json"

echo ">>> building for wasm32-unknown-wasip1"
OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift build \
    --toolset "$PROBE/toolset.json" \
    --swift-sdk swift-6.4.0-RELEASE_wasm \
    --triple wasm32-unknown-wasip1 \
    -c release

MODULE="$(OCCTSWIFT_WASI=1 TOOLCHAINS=swift swift build --toolset "$PROBE/toolset.json" \
    --swift-sdk swift-6.4.0-RELEASE_wasm --triple wasm32-unknown-wasip1 -c release \
    --show-bin-path)/ValveGearProbe.wasm"
[ -f "$MODULE" ] || die "no module at $MODULE"
echo "    $MODULE ($(wc -c < "$MODULE" | tr -d ' ') bytes)"

# Two preopens, for the same reason a browser host needs two: one to work in, and /tmp because
# Exporter.stepData writes there and reads back.
WASMKIT="$(dirname "$(xcrun -f swift 2>/dev/null || command -v swift)")/wasmkit"
[ -x "$WASMKIT" ] || WASMKIT=/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/wasmkit
[ -x "$WASMKIT" ] || die "no wasmkit; it ships inside the pinned swift.org toolchain"

rm -rf "$WORK"; mkdir -p "$WORK"
echo ">>> running under wasmkit"
"$WASMKIT" run --dir "$WORK" --dir /tmp "$MODULE" "$WORK"
