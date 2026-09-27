#!/bin/bash
#
# Fetch the prebuilt wasm OCCT kernel into Libraries/, so a wasm build needs no 69-minute
# OCCT build.
#
# Usage:
#   Scripts/fetch-occt-wasm.sh              # fetch if missing, verify, unpack
#   Scripts/fetch-occt-wasm.sh --force      # re-fetch even if Libraries/ already has it
#   Scripts/fetch-occt-wasm.sh --verify     # verify what is already unpacked, download nothing
#   Scripts/fetch-occt-wasm.sh --print-plan # resolve and print, download nothing
#
# Every URL, checksum and size comes from Scripts/wasm-kernel-pin.txt. Nothing here is a default
# that disagrees with that file, which is the same rule Scripts/install-wasm-toolchain.sh follows
# for the toolchain.
#
# This is the counterpart to what SwiftPM does for itself on the native side. There, Package.swift
# names a binaryTarget by url: and checksum: and SwiftPM downloads and verifies it. SwiftPM's
# binaryTarget takes an xcframework or a zip of one and never a bare static library, so there is no
# wasm equivalent and this script is it. It is deliberately shaped the same way: a pinned URL, a
# checksum that is verified before anything is unpacked, and a loud failure on a mismatch.
#
# The destination is Libraries/, which is gitignored apart from dummy.c and include/, so this
# writes only build outputs and never anything git tracks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PINS_FILE="$SCRIPT_DIR/wasm-kernel-pin.txt"
LIB_DIR="${OCCT_WASM_LIB_DIR:-$PROJECT_DIR/Libraries}"

FORCE=0
VERIFY_ONLY=0
PRINT_PLAN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --force)      FORCE=1 ;;
        --verify)     VERIFY_ONLY=1 ;;
        --print-plan) PRINT_PLAN=1 ;;
        -h|--help)    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            echo "ERROR: unknown option '$1'" >&2; exit 2 ;;
    esac
    shift
done

die() { echo "ERROR: $*" >&2; exit 1; }

# Parse, do not source. The pins file is data: sourcing it would execute whatever is in it and
# would also import every comment's backticks as a command substitution.
pin() {
    local key="$1" value
    value="$(grep -E "^${key}=" "$PINS_FILE" | head -1 | cut -d= -f2-)"
    [ -n "$value" ] || die "no $key in $PINS_FILE"
    printf '%s' "$value"
}

[ -f "$PINS_FILE" ] || die "no pins file at $PINS_FILE"

URL="$(pin OCCT_WASM_ASSET_URL)"
SHA="$(pin OCCT_WASM_ASSET_SHA256)"
BYTES="$(pin OCCT_WASM_ASSET_BYTES)"
TAG="$(pin OCCT_WASM_RELEASE_TAG)"
ARCHIVE_BYTES="$(pin OCCT_WASM_ARCHIVE_BYTES)"
HEADER_FILES="$(pin OCCT_WASM_HEADER_FILES)"
PATCH_COUNT="$(pin OCCT_WASM_PATCH_COUNT)"
BUILT_FROM="$(pin OCCT_WASM_BUILT_FROM)"

ARCHIVE="$LIB_DIR/libOCCT-wasm.a"
HEADERS="$LIB_DIR/occt-headers-wasm"

if [ "$PRINT_PLAN" = 1 ]; then
    echo "release tag   $TAG"
    echo "asset         $URL"
    echo "sha256        $SHA"
    echo "size          $BYTES bytes"
    echo "built from    $BUILT_FROM ($PATCH_COUNT carried patches)"
    echo "destination   $LIB_DIR"
    echo "  archive     $ARCHIVE ($ARCHIVE_BYTES bytes)"
    echo "  headers     $HEADERS ($HEADER_FILES files)"
    exit 0
fi

# Check what is unpacked against the pinned SHAPE, not just for existence. A truncated archive or a
# half-extracted header tree is the failure that otherwise surfaces hundreds of files into a build
# as a missing symbol or a missing include, where the archive is the last thing anyone suspects.
verify_unpacked() {
    local problems=0
    if [ ! -f "$ARCHIVE" ]; then
        echo "  missing: $ARCHIVE"; problems=1
    else
        local actual; actual="$(wc -c < "$ARCHIVE" | tr -d ' ')"
        if [ "$actual" != "$ARCHIVE_BYTES" ]; then
            echo "  $ARCHIVE is $actual bytes, pinned at $ARCHIVE_BYTES"; problems=1
        else
            echo "  ok: libOCCT-wasm.a, $actual bytes"
        fi
    fi
    if [ ! -d "$HEADERS" ]; then
        echo "  missing: $HEADERS"; problems=1
    else
        local actual; actual="$(find "$HEADERS" -type f | wc -l | tr -d ' ')"
        if [ "$actual" != "$HEADER_FILES" ]; then
            echo "  $HEADERS holds $actual files, pinned at $HEADER_FILES"; problems=1
        else
            echo "  ok: occt-headers-wasm/, $actual files"
        fi
    fi
    return $problems
}

if [ "$VERIFY_ONLY" = 1 ]; then
    echo "verifying $LIB_DIR against $PINS_FILE"
    if verify_unpacked; then
        echo "VERIFIED"
        exit 0
    fi
    echo "NOT VERIFIED. Run without --verify to fetch." >&2
    exit 1
fi

if [ "$FORCE" = 0 ] && verify_unpacked >/dev/null 2>&1; then
    echo "already present and matching the pin; nothing to do"
    verify_unpacked
    echo "Pass --force to re-fetch."
    exit 0
fi

command -v curl >/dev/null || die "curl not on PATH"
command -v shasum >/dev/null || command -v sha256sum >/dev/null \
    || die "neither shasum nor sha256sum on PATH"

mkdir -p "$LIB_DIR"
# A temp file beside the destination, so the move is on one filesystem and cannot half-succeed, and
# so an interrupted download never leaves something that looks like a valid archive.
TMP="$(mktemp "$LIB_DIR/.occt-wasm-XXXXXX.tar.gz")"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

echo "fetching $URL"
echo "  ($BYTES bytes, tag $TAG)"
curl -fSL --retry 3 --retry-delay 2 -o "$TMP" "$URL" \
    || die "download failed from $URL"

actual_bytes="$(wc -c < "$TMP" | tr -d ' ')"
[ "$actual_bytes" = "$BYTES" ] \
    || die "downloaded $actual_bytes bytes, pinned at $BYTES. Wrong asset, or a truncated transfer."

if command -v shasum >/dev/null; then
    actual_sha="$(shasum -a 256 "$TMP" | cut -d' ' -f1)"
else
    actual_sha="$(sha256sum "$TMP" | cut -d' ' -f1)"
fi
# Before unpacking, never after. This is the whole point of a pinned checksum, and unpacking first
# would put 153 MB of unverified object code where the build is about to link it.
[ "$actual_sha" = "$SHA" ] || die "checksum mismatch.
  expected $SHA
  actual   $actual_sha
If the asset was rebuilt and republished, BOTH the url and the sha256 in
$PINS_FILE have to move together. See the feedback rule on SPM packaging."

echo "checksum ok: $actual_sha"

# Remove the old tree before unpacking, so a header deleted upstream does not survive as a stale
# file that the next build silently includes.
rm -rf "$HEADERS" "$ARCHIVE"
tar -xzf "$TMP" -C "$LIB_DIR" || die "could not unpack $TMP into $LIB_DIR"

echo "unpacked into $LIB_DIR"
if verify_unpacked; then
    echo "FETCHED AND VERIFIED"
else
    die "the unpacked tree does not match the pin, which means the asset's contents moved
without its sha256 moving. That should be impossible; report it."
fi
