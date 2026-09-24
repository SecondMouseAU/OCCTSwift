#!/usr/bin/env bash
# #2256: clang crashes compiling Objective-C++ with -fwasm-exceptions, and what the fix has to
# prove besides "it stopped crashing".
#
# Eleven cases, in three groups:
#
#   1-6   the crash itself, on nine lines of pure C++ that differ only in file extension, plus the
#         one line of LLVM IR that explains it
#   7-10  the same question asked of a REAL bridge translation unit out of Sources/OCCTBridge/src,
#         compiled for wasm32-unknown-wasip1, linked and run: does its outermost catch (...) still
#         fire? Case 10 is #2171's silent failure, reproduced through that same real file.
#   11    where -x c++ lands in a SwiftPM build, and whether it reaches a .c source (it does not,
#         on the build system the wasm cross-build uses)
#
# Exits non-zero if any case does not say what it is supposed to say. Cases 7-10 need the OCCT
# headers; they are skipped, loudly, if none are found, and a skip is not a failure.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
PINS="$REPO_ROOT/Scripts/wasm-toolchain-versions.txt"

pin() { grep "^$1=" "$PINS" | head -1 | cut -d= -f2-; }
SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"
EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"

SWIFT_BIN="${SWIFT_BIN:-/Library/Developer/Toolchains/swift-$SWIFT_TOOLCHAIN_VERSION.xctoolchain/usr/bin}"
if [ ! -x "$SWIFT_BIN/clang++" ]; then
  echo "error: no swift.org toolchain at $SWIFT_BIN" >&2
  exit 1
fi
export PATH="$SWIFT_BIN:$PATH"
export TOOLCHAINS=swift
CLANGXX="$SWIFT_BIN/clang++"

SDK_BUNDLE="$HOME/Library/org.swift.swiftpm/swift-sdks/$SWIFT_WASM_SDK_ID.artifactbundle/$SWIFT_WASM_SDK_ID/$SWIFT_WASM_TRIPLE"
WASI_SYSROOT="$SDK_BUNDLE/WASI.sdk"
RESOURCE_DIR="$SDK_BUNDLE/swift.xctoolchain/usr/lib/clang"
if [ ! -d "$WASI_SYSROOT" ]; then
  echo "error: no Swift SDK for WebAssembly at $SDK_BUNDLE" >&2
  echo "       Scripts/install-wasm-toolchain.sh installs the pinned one." >&2
  exit 1
fi

if [ -z "${WASI_SDK_PREFIX:-}" ]; then
  for candidate in "$REPO_ROOT"/Libraries/wasi-sdk-"$WASI_SDK_VERSION"-*; do
    [ -d "$candidate" ] && WASI_SDK_PREFIX="$candidate" && break
  done
fi
EH_LIB_DIR="${WASI_SDK_PREFIX:-}/share/wasi-sysroot/lib/wasm32-wasip1/eh"

# The OCCT headers. Libraries/ is gitignored, so a linked worktree usually has none of its own and
# the main checkout's tree is the one to point at. These are declarations, not a sysroot: the
# objects below are compiled for wasm32-unknown-wasip1 with them.
OCCT_HEADERS="${OCCT_HEADERS:-$REPO_ROOT/Libraries/OCCT.xcframework/macos-arm64/Headers}"

echo ">>> Swift toolchain : $SWIFT_BIN"
echo ">>> Swift SDK       : $SWIFT_WASM_SDK_ID ($SWIFT_WASM_TRIPLE)"
echo ">>> wasi-sdk        : ${WASI_SDK_PREFIX:-<not found>}"
echo ">>> EH flags        : $EH_FLAGS"
echo ">>> OCCT headers    : $OCCT_HEADERS"
echo

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0
SKIPS=0

ok()   { echo "    ok   $*"; }
bad()  { echo "    FAIL $*"; FAILURES=$((FAILURES + 1)); }
skip() { echo "    skip $*"; SKIPS=$((SKIPS + 1)); }

BASE_ARGS=(--target="$SWIFT_WASM_TRIPLE" --sysroot="$WASI_SYSROOT" -std=c++17 -w)

# Did this compile crash, rather than merely fail? The crash prints the LLVM banner and the pass it
# died in; an ordinary compile error prints neither.
crashed() { grep -q "PLEASE submit a bug report" "$1" && grep -q "Code generation" "$1"; }

cp "$HERE/minimal.mm" "$WORK/t.mm"
cp "$HERE/minimal.mm" "$WORK/t.cpp"

echo "=== case 1: the same nine lines as .cpp, with the pinned exception flags ==="
if "$CLANGXX" "${BASE_ARGS[@]}" $EH_FLAGS -c "$WORK/t.cpp" -o "$WORK/t_cpp.o" 2>"$WORK/1.log"; then
  ok "compiled, so nothing about the code is the problem"
else
  bad "the C++ compile failed: $(head -1 "$WORK/1.log")"
fi

echo "=== case 2: the same nine lines as .mm, with the same flags ==="
"$CLANGXX" "${BASE_ARGS[@]}" $EH_FLAGS -c "$WORK/t.mm" -o "$WORK/t_mm.o" >"$WORK/2.log" 2>&1
if crashed "$WORK/2.log"; then
  ok "crashed: $(grep -m1 "Running pass 'Function Pass Manager'" "$WORK/2.log" | sed 's/^[0-9]*\.\s*//')"
  ok "         $(grep -m1 "Running pass 'WebAssembly" "$WORK/2.log" | sed 's/^[0-9]*\.\s*//')"
else
  bad "expected a code-generation crash and did not get one"
fi

echo "=== case 3: .mm, exception flags, and -fno-objc-exceptions ==="
"$CLANGXX" "${BASE_ARGS[@]}" $EH_FLAGS -fno-objc-exceptions -c "$WORK/t.mm" -o "$WORK/t_mm3.o" \
  >"$WORK/3.log" 2>&1
if crashed "$WORK/3.log"; then
  ok "still crashes, so turning Objective-C exceptions off is not the answer"
else
  bad "expected a crash"
fi

echo "=== case 4: .mm with NO exception flags (this is #2171's silent-failure build) ==="
if "$CLANGXX" "${BASE_ARGS[@]}" -c "$WORK/t.mm" -o "$WORK/t_mm4.o" 2>"$WORK/4.log"; then
  ok "compiled clean, which is exactly the trap: no crash, and no working catch either"
else
  bad "expected this to compile"
fi

echo "=== case 5: .mm compiled as C++ (-x c++), with the exception flags ==="
if "$CLANGXX" "${BASE_ARGS[@]}" -x c++ $EH_FLAGS -c "$WORK/t.mm" -o "$WORK/t_mm5.o" 2>"$WORK/5.log"; then
  ok "compiled, and the extension never changed: the fix is the language, not the file name"
else
  bad "the -x c++ compile failed: $(head -1 "$WORK/5.log")"
fi

echo "=== case 6: why, in one line of LLVM IR ==="
"$CLANGXX" "${BASE_ARGS[@]}" $EH_FLAGS -S -emit-llvm "$WORK/t.cpp" -o "$WORK/t_cpp.ll" 2>/dev/null
"$CLANGXX" "${BASE_ARGS[@]}" $EH_FLAGS -S -emit-llvm "$WORK/t.mm" -o "$WORK/t_mm.ll" 2>/dev/null
CPP_PERS="$(grep -m1 -o 'personality ptr @[A-Za-z0-9_]*' "$WORK/t_cpp.ll" | sed 's/.*@//')"
MM_PERS="$(grep -m1 -o 'personality ptr @[A-Za-z0-9_]*' "$WORK/t_mm.ll" | sed 's/.*@//')"
echo "    .cpp personality : $CPP_PERS"
echo "    .mm  personality : $MM_PERS"
if [ "$CPP_PERS" = "__gxx_wasm_personality_v0" ] && [ "$MM_PERS" != "__gxx_wasm_personality_v0" ]; then
  ok "the Objective-C++ personality is not the wasm one, so the wasm EH lowering skips the"
  ok "function and leaves an invoke/landingpad the WebAssembly selector cannot select"
else
  bad "expected the two personalities to differ, with only the C++ one being the wasm personality"
fi

BRIDGE_TU="$REPO_ROOT/Sources/OCCTBridge/src/OCCTBridge_Curve3D_Curves.mm"
BRIDGE_ARGS=("${BASE_ARGS[@]}"
  -include "$REPO_ROOT/Scripts/wasm-shims/wasi-std-threading.hpp"
  -I "$OCCT_HEADERS"
  -I "$REPO_ROOT/Sources/OCCTBridge/include"
  -I "$REPO_ROOT/Sources/OCCTBridge/src")

if [ ! -d "$OCCT_HEADERS" ]; then
  echo "=== cases 7-10: a real bridge translation unit ==="
  echo "    no OCCT headers at $OCCT_HEADERS. Set OCCT_HEADERS to a checkout that has them."
  skip "case 7"; skip "case 8"; skip "case 9"; skip "case 10"
elif [ ! -d "$EH_LIB_DIR" ]; then
  echo "=== cases 7-10: a real bridge translation unit ==="
  echo "    no wasi-sdk $WASI_SDK_VERSION eh directory. Set WASI_SDK_PREFIX."
  skip "case 7"; skip "case 8"; skip "case 9"; skip "case 10"
else
  echo "=== case 7: $(basename "$BRIDGE_TU"), unmodified, as Objective-C++ ==="
  "$CLANGXX" "${BRIDGE_ARGS[@]}" $EH_FLAGS -c "$BRIDGE_TU" -o "$WORK/bridge_objcxx.o" \
    >"$WORK/7.log" 2>&1
  if crashed "$WORK/7.log"; then
    ok "crashed $(grep -m1 -o "on function '@[A-Za-z0-9_]*'" "$WORK/7.log"), so this is not a"
    ok "property of the nine-line probe"
  else
    bad "expected the real bridge file to crash too"
  fi

  echo "=== case 8: the same file, same flags, compiled as C++ ==="
  if "$CLANGXX" "${BRIDGE_ARGS[@]}" -x c++ $EH_FLAGS -c "$BRIDGE_TU" -o "$WORK/bridge.o" \
       2>"$WORK/8.log"; then
    ok "compiled to a wasm32 object"
  else
    bad "the real bridge file did not compile as C++: $(head -1 "$WORK/8.log")"
  fi

  # The driver asks the bridge for a line through a zero-length direction. OCCT's gp_Dir raises
  # Standard_ConstructionError on that, inside the bridge's own try block, which is the shape
  # CLAUDE.md names: every gp_Dir construction from caller doubles sits inside a try.
  "$CLANGXX" "${BRIDGE_ARGS[@]}" -x c++ $EH_FLAGS -c "$HERE/bridge-catch/driver.cpp" \
    -o "$WORK/driver.o" 2>>"$WORK/8.log"
  "$CLANGXX" "${BRIDGE_ARGS[@]}" -x c++ $EH_FLAGS -c "$HERE/bridge-catch/fake-occt.cpp" \
    -o "$WORK/fake-occt.o" 2>>"$WORK/8.log"

  link_and_run() { # $1 = the bridge object, $2 = output name
    "$CLANGXX" --target="$SWIFT_WASM_TRIPLE" --sysroot="$WASI_SYSROOT" -fwasm-exceptions \
      -resource-dir "$RESOURCE_DIR" -L "$EH_LIB_DIR" \
      "$WORK/driver.o" "$1" "$WORK/fake-occt.o" -lc++abi -lunwind -o "$2" 2>&1 \
      | grep -v "signature mismatch\|>>> defined as" || true
    "$SWIFT_BIN/wasmkit" run "$2" 2>&1 | sed 's/^/      /'
  }

  echo "=== case 9: that object linked and RUN: does the bridge still catch? ==="
  OUT9="$(link_and_run "$WORK/bridge.o" "$WORK/probe.wasm")"
  echo "$OUT9"
  if echo "$OUT9" | grep -q "VERDICT: caught at the bridge boundary"; then
    ok "a Standard_ConstructionError raised by OCCT crossed into the bridge frame, its outermost"
    ok "catch (...) fired, the catch BODY ran, and the function returned its refusal"
  else
    bad "the bridge did not catch it"
  fi

  echo "=== case 10: the same file, still -x c++, but with NO exception flags ==="
  if "$CLANGXX" "${BRIDGE_ARGS[@]}" -x c++ -c "$BRIDGE_TU" -o "$WORK/bridge_noeh.o" \
       2>"$WORK/10.log"; then
    ok "compiled clean, no diagnostic"
  else
    bad "expected this to compile"
  fi
  OUT10="$(link_and_run "$WORK/bridge_noeh.o" "$WORK/probe_noeh.wasm")"
  echo "$OUT10"
  if echo "$OUT10" | grep -q "VERDICT: the bridge did NOT catch it"; then
    ok "#2171's silent failure, through a real bridge file: the catch never fired and the"
    ok "exception left the bridge. A fix that only stops the crash ships exactly this."
  else
    bad "expected the no-flags build to lose its catch"
  fi
fi

echo "=== case 11: where -x c++ lands in a SwiftPM build, and what it does to a .c ==="
# Two one-file probes rather than one mixed target, because a build that stops at the first error
# cannot tell "the setting did not reach this file" from "this file was never compiled". Each probe
# holds exactly one source that a C++ compile must reject, plus a neutral .cpp so SwiftPM classifies
# the target as C++ in both.
make_probe() { # $1 = directory, $2 = the offending source's name, $3 = its text
  mkdir -p "$1/Sources/Probe/include"
  : > "$1/Sources/Probe/include/probe.h"
  printf '%s' "$3" > "$1/Sources/Probe/$2"
  echo 'int anchor_fn(void) { return 0; }' > "$1/Sources/Probe/anchor.cpp"
  cat > "$1/toolset.json" <<'TOOLSET'
{ "schemaVersion": "1.0", "cxxCompiler": { "extraCLIOptions": ["-x", "c++"] } }
TOOLSET
}
# C-only spellings: as C++ this is a syntax error.
make_probe "$WORK/probe-c" probe.c 'int probe_fn(void) { int class = 1; int new = 2; return class + new; }
'
# An @-keyword: as C++ this is a syntax error.
make_probe "$WORK/probe-mm" probe.mm 'int probe_fn(void) { @autoreleasepool { return 7; } }
'

manifest() { # $1 = package dir, $2 = extra target arguments
  cat > "$1/Package.swift" <<EOF
// swift-tools-version: 6.1
import PackageDescription

let package = Package(name: "probe", targets: [.target(name: "Probe"$2)])
EOF
}

# "yes" when the offending source was rejected, which is only possible if -x c++ reached it.
reached() { # $1 = package dir, $2 = build system, $3... = extra swift build args
  local pkg="$1" system="$2"; shift 2
  rm -rf "$pkg/.build"
  local log="$WORK/swiftpm.log"
  (cd "$pkg" && swift build --build-system "$system" "$@" >"$log" 2>&1)
  if grep -q "Sources/Probe/probe\.[cm]*:.*error" "$log"; then echo yes; else echo no; fi
}

ROW_C=""  # set by row(): did the setting reach the .c source?
row() { # $1 = label, $2 = the cxxSettings argument, $3 = build system, $4... = extra args
  local label="$1" setting="$2" system="$3"; shift 3
  manifest "$WORK/probe-c" "$setting"
  manifest "$WORK/probe-mm" "$setting"
  local mm
  mm="$(reached "$WORK/probe-mm" "$system" "$@")"
  ROW_C="$(reached "$WORK/probe-c" "$system" "$@")"
  printf '    %-40s reaches the .mm: %-3s | reaches the .c: %s\n' "$label" "$mm" "$ROW_C"
  [ "$mm" = yes ] || bad "$label did not reach the .mm at all"
}

manifest "$WORK/probe-c" ""
manifest "$WORK/probe-mm" ""
rm -rf "$WORK/probe-c/.build"
if (cd "$WORK/probe-c" && swift build >"$WORK/11-base.log" 2>&1); then
  ok "baseline: with no language override, the C-only source compiles"
else
  bad "the baseline package does not build: $(grep -m1 error "$WORK/11-base.log")"
fi

SETTING=', cxxSettings: [.unsafeFlags(["-x", "c++"])]'
row 'cxxSettings, swiftbuild (the default)' "$SETTING" swiftbuild
C_SWIFTBUILD_SETTINGS="$ROW_C"
row 'cxxSettings, native (deprecated)' "$SETTING" native
C_NATIVE_SETTINGS="$ROW_C"
row 'toolset,     swiftbuild (the default)' '' swiftbuild --toolset toolset.json
C_SWIFTBUILD_TOOLSET="$ROW_C"
row 'toolset,     native (deprecated)' '' native --toolset toolset.json
C_NATIVE_TOOLSET="$ROW_C"

if [ "$C_SWIFTBUILD_SETTINGS" = no ] && [ "$C_SWIFTBUILD_TOOLSET" = no ] \
   && [ "$C_NATIVE_TOOLSET" = no ]; then
  ok "on swiftbuild, which is what the wasm cross-build uses, neither route reaches a .c source,"
  ok "so Libraries/dummy.c is untouched by either"
else
  bad "a route reached a .c source on the default build system"
fi
if [ "$C_NATIVE_SETTINGS" = yes ]; then
  ok "on the deprecated native build system the cxxSettings route DOES reach a .c source in the"
  ok "same target, and the toolset route does not: that is why the toolset is the better home"
else
  bad "expected the native build system's cxxSettings route to leak onto the .c source"
fi

echo
if [ "$FAILURES" -eq 0 ]; then
  echo ">>> all cases said what they should${SKIPS:+ ($SKIPS skipped)}"
  exit 0
fi
echo ">>> $FAILURES case(s) did not"
exit 1
