#!/bin/bash
#
# Install the pinned wasm toolchain, then prove it builds and runs a module.
#
# Usage:
#   Scripts/install-wasm-toolchain.sh              # install what is missing, then verify
#   Scripts/install-wasm-toolchain.sh --verify     # verify only, install nothing
#   Scripts/install-wasm-toolchain.sh --no-verify  # install only
#   Scripts/install-wasm-toolchain.sh --print-plan # resolve and print, download nothing
#
# Every version, URL and checksum comes from Scripts/wasm-toolchain-versions.txt, so a bump reaches
# this script, Scripts/build-occt-wasm.sh and CI by editing one file. Nothing here is a default
# that disagrees with that file.
#
# The one step this script will not take for you is installing the swift.org Swift toolchain: on
# macOS that is a signed .pkg that wants an administrator, and on Linux it is a tarball whose
# unpack location is the user's choice. It prints the exact command and stops.
#
# What each piece is for, and the measurements behind the choices, are in docs/wasm-feasibility.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PINS_FILE="$SCRIPT_DIR/wasm-toolchain-versions.txt"

DO_INSTALL=1
DO_VERIFY=1
PRINT_PLAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --verify)     DO_INSTALL=0 ;;
        --no-verify)  DO_VERIFY=0 ;;
        --print-plan) PRINT_PLAN=1; DO_INSTALL=0; DO_VERIFY=0 ;;
        -h|--help)    sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)            echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    esac
    shift
done

# --------------------
# Read the pins
# --------------------

pin() {
    # First KEY=value line wins; everything after the first '=' is the value, spaces included.
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

SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
SWIFT_TOOLCHAIN_URL_MACOS="$(pin SWIFT_TOOLCHAIN_URL_MACOS)"
SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_SDK_URL="$(pin SWIFT_WASM_SDK_URL)"
SWIFT_WASM_SDK_CHECKSUM="$(pin SWIFT_WASM_SDK_CHECKSUM)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"
WASI_SDK_URL_BASE="$(pin WASI_SDK_URL_BASE)"
WASM_RUNTIME="$(pin WASM_RUNTIME)"

# --------------------
# Resolve host, paths and tools
# --------------------

ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    darwin) OS="macos" ;;
    linux)  OS="linux" ;;
    *) echo "ERROR: unsupported host OS '$OS'." >&2; exit 1 ;;
esac

WASI_SDK_NAME="wasi-sdk-${WASI_SDK_VERSION}-${ARCH}-${OS}"
WASI_SDK_TARBALL="${WASI_SDK_NAME}.tar.gz"
WASI_SDK_SHA256="$(pin "WASI_SDK_SHA256_${ARCH}_${OS}")"
# Libraries/ is gitignored in its entirety and already holds occt-src and the built kernels, so a
# toolchain unpacked there is next to what it compiles and never reaches a commit.
WASI_SDK_PREFIX="${WASI_SDK_PREFIX:-$PROJECT_DIR/Libraries/$WASI_SDK_NAME}"

sha256_of() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        sha256sum "$1" | cut -d' ' -f1
    fi
}

# The swift.org toolchain, never Xcode's. On macOS the installed toolchains live under
# /Library/Developer/Toolchains; on Linux whatever `swift` is on PATH is the only candidate.
resolve_swift() {
    local candidate
    if [ "$OS" = "macos" ]; then
        for candidate in \
            "/Library/Developer/Toolchains/swift-${SWIFT_TOOLCHAIN_VERSION}.xctoolchain" \
            "$HOME/Library/Developer/Toolchains/swift-${SWIFT_TOOLCHAIN_VERSION}.xctoolchain"; do
            if [ -x "$candidate/usr/bin/swift" ]; then
                SWIFT_BIN_DIR="$candidate/usr/bin"
                return 0
            fi
        done
        return 1
    fi
    candidate="$(command -v swift || true)"
    [ -n "$candidate" ] || return 1
    SWIFT_BIN_DIR="$(dirname "$(readlink -f "$candidate")")"
    [ -x "$SWIFT_BIN_DIR/wasm-ld" ] || return 1
    return 0
}

require_swift() {
    if resolve_swift; then
        return 0
    fi
    echo "ERROR: no swift.org Swift $SWIFT_TOOLCHAIN_VERSION toolchain found." >&2
    echo "" >&2
    echo "       Xcode's toolchain cannot link for wasm (no wasm-ld, no swift-autolink-extract)," >&2
    echo "       so the swift.org build of the same version is required. Install it, then re-run:" >&2
    echo "" >&2
    if [ "$OS" = "macos" ]; then
        echo "         curl -LO $SWIFT_TOOLCHAIN_URL_MACOS" >&2
        echo "         sudo installer -pkg swift-${SWIFT_TOOLCHAIN_VERSION}-osx.pkg -target /" >&2
    else
        echo "         See https://www.swift.org/install/linux/ for the $SWIFT_TOOLCHAIN_VERSION tarball" >&2
        echo "         for your distribution, unpack it, and put its usr/bin first on PATH." >&2
    fi
    exit 1
}

# --------------------
# Plan
# --------------------

echo "========================================"
echo "Pinned wasm toolchain"
echo "========================================"
echo "  Swift toolchain : $SWIFT_TOOLCHAIN_VERSION (swift.org)"
echo "  Swift SDK       : $SWIFT_WASM_SDK_ID"
echo "  Target triple   : $SWIFT_WASM_TRIPLE"
echo "  wasi-sdk        : $WASI_SDK_VERSION -> $WASI_SDK_PREFIX"
echo "  Runtime         : $WASM_RUNTIME (shipped inside the Swift toolchain)"
echo ""

if [ "$PRINT_PLAN" -eq 1 ]; then
    echo "Swift SDK download : $SWIFT_WASM_SDK_URL"
    echo "Swift SDK checksum : $SWIFT_WASM_SDK_CHECKSUM"
    echo "wasi-sdk download  : $WASI_SDK_URL_BASE/$WASI_SDK_TARBALL"
    echo "wasi-sdk checksum  : $WASI_SDK_SHA256"
    exit 0
fi

require_swift
echo ">>> Swift toolchain: $SWIFT_BIN_DIR"

if [ ! -x "$SWIFT_BIN_DIR/$WASM_RUNTIME" ]; then
    echo "ERROR: $SWIFT_BIN_DIR holds no '$WASM_RUNTIME'." >&2
    echo "       The pinned runtime ships inside the swift.org toolchain; a toolchain without it" >&2
    echo "       is not the pinned one, whatever \`swift --version\` reports." >&2
    exit 1
fi

# --------------------
# Install: Swift SDK for WebAssembly
# --------------------

if [ "$DO_INSTALL" -eq 1 ]; then
    if "$SWIFT_BIN_DIR/swift" sdk list 2>/dev/null | grep -qx "$SWIFT_WASM_SDK_ID"; then
        echo ">>> Swift SDK $SWIFT_WASM_SDK_ID already installed"
    else
        echo ">>> Installing Swift SDK $SWIFT_WASM_SDK_ID..."
        "$SWIFT_BIN_DIR/swift" sdk install "$SWIFT_WASM_SDK_URL" --checksum "$SWIFT_WASM_SDK_CHECKSUM"
    fi

    # --------------------
    # Install: wasi-sdk
    # --------------------

    if [ -d "$WASI_SDK_PREFIX" ]; then
        echo ">>> wasi-sdk already present at $WASI_SDK_PREFIX"
    else
        echo ">>> Downloading $WASI_SDK_TARBALL..."
        mkdir -p "$(dirname "$WASI_SDK_PREFIX")"
        tmp_tarball="$(dirname "$WASI_SDK_PREFIX")/$WASI_SDK_TARBALL"
        curl -sSL -o "$tmp_tarball" "$WASI_SDK_URL_BASE/$WASI_SDK_TARBALL"
        actual="$(sha256_of "$tmp_tarball")"
        if [ "$actual" != "$WASI_SDK_SHA256" ]; then
            rm -f "$tmp_tarball"
            echo "ERROR: checksum mismatch for $WASI_SDK_TARBALL." >&2
            echo "       expected $WASI_SDK_SHA256" >&2
            echo "       actual   $actual" >&2
            exit 1
        fi
        echo "    checksum verified: $actual"
        tar xzf "$tmp_tarball" -C "$(dirname "$WASI_SDK_PREFIX")"
        rm -f "$tmp_tarball"
        echo "    unpacked to $WASI_SDK_PREFIX"
    fi
fi

# --------------------
# Verify: build and run
# --------------------

if [ "$DO_VERIFY" -eq 1 ]; then
    probe_dir="$SCRIPT_DIR/repro/2169/standalone"
    if [ ! -f "$probe_dir/Package.swift" ]; then
        echo "ERROR: verification package not found at $probe_dir." >&2
        exit 1
    fi
    if [ ! -d "$WASI_SDK_PREFIX" ]; then
        echo "ERROR: wasi-sdk not found at '$WASI_SDK_PREFIX'." >&2
        echo "       Run this script without --verify, or set WASI_SDK_PREFIX." >&2
        exit 1
    fi

    echo ""
    echo ">>> Building the verification package for $SWIFT_WASM_TRIPLE..."
    (
        cd "$probe_dir"
        rm -rf .build
        WASI_SDK_PREFIX="$WASI_SDK_PREFIX" PATH="$SWIFT_BIN_DIR:$PATH" \
            "$SWIFT_BIN_DIR/swift" build \
                --swift-sdk "$SWIFT_WASM_SDK_ID" --triple "$SWIFT_WASM_TRIPLE"
    )

    module="$(find "$probe_dir/.build" -name "wasmprobe.wasm" -print -quit)"
    if [ -z "$module" ]; then
        echo "ERROR: the build produced no wasmprobe.wasm." >&2
        exit 1
    fi

    echo ""
    echo ">>> Running $module under $WASM_RUNTIME..."
    "$SWIFT_BIN_DIR/$WASM_RUNTIME" run "$module"

    echo ""
    echo "========================================"
    echo "Toolchain verified: a wasm module built and ran."
    echo "========================================"
fi
