#!/usr/bin/env bash
# #2048: can a wasm build of OCCTSwift's shape be consumed as an ordinary SwiftPM dependency?
#
# The failure mode is exact and it is not about wasm: SwiftPM refuses `.unsafeFlags` in a package
# resolved by VERSION, which is how a published consumer reaches it. Everything the WASI path needs
# is currently an unsafe flag, so the question is which of those flags have a safe spelling and
# where the rest can come from.
#
# This script builds a stub with OCCTSwift's target shape and no OCCT in it, publishes it as a git
# repository with a tag, and consumes it from a second package. Nine cases, each printed with the
# verdict it produced. Exits non-zero if any case did not produce the outcome it is asserting.
#
# Nothing here needs libOCCT-wasm.a, which is #2174's work and does not exist yet.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
PINS="$REPO_ROOT/Scripts/wasm-toolchain-versions.txt"

if [ ! -f "$PINS" ]; then
  echo "error: $PINS is missing." >&2
  exit 1
fi
pin() { grep "^$1=" "$PINS" | head -1 | cut -d= -f2-; }
SWIFT_TOOLCHAIN_VERSION="$(pin SWIFT_TOOLCHAIN_VERSION)"
SWIFT_WASM_SDK_ID="$(pin SWIFT_WASM_SDK_ID)"
SWIFT_WASM_TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
WASI_SDK_VERSION="$(pin WASI_SDK_VERSION)"
EH_FLAGS="$(pin WASM_CXX_EH_FLAGS)"

SWIFT_BIN="${SWIFT_BIN:-/Library/Developer/Toolchains/swift-$SWIFT_TOOLCHAIN_VERSION.xctoolchain/usr/bin}"
if [ ! -x "$SWIFT_BIN/swift" ]; then
  echo "error: no swift.org toolchain at $SWIFT_BIN" >&2
  exit 1
fi
export PATH="$SWIFT_BIN:$PATH"
export TOOLCHAINS=swift

if [ -z "${WASI_SDK_PREFIX:-}" ]; then
  for candidate in "$REPO_ROOT"/Libraries/wasi-sdk-"$WASI_SDK_VERSION"-* \
                   /Users/"$USER"/Projects/OCCTSwift/Libraries/wasi-sdk-"$WASI_SDK_VERSION"-*; do
    [ -d "$candidate" ] && WASI_SDK_PREFIX="$candidate" && break
  done
fi
if [ -z "${WASI_SDK_PREFIX:-}" ] || [ ! -d "$WASI_SDK_PREFIX" ]; then
  echo "error: no wasi-sdk $WASI_SDK_VERSION found. Set WASI_SDK_PREFIX, or run" >&2
  echo "       Scripts/install-wasm-toolchain.sh." >&2
  exit 1
fi
EH_LIB_DIR="$WASI_SDK_PREFIX/share/wasi-sysroot/lib/wasm32-wasip1/eh"

# The SWIFT SDK's WASI.sdk, not wasi-sdk's own sysroot. Scripts/cmake/wasi-swift-sdk.cmake says
# why at length: the two are two libc++ major versions apart, the Swift side links WASI.sdk's copy
# whatever the C++ side was built against, and only WASI.sdk sets _LIBCPP_HAS_THREADS 0, which is
# the configuration the threading shim asserts on. Compiling the stub kernel with wasi-sdk's own
# clang++ picks up wasi-sdk's sysroot and the shim refuses the compile, which is the assertion
# doing its job.
SWIFT_SDKS_DIR="${SWIFT_SDKS_DIR:-$HOME/Library/org.swift.swiftpm/swift-sdks}"
[ -d "$SWIFT_SDKS_DIR" ] || SWIFT_SDKS_DIR="$HOME/.swiftpm/swift-sdks"
SWIFT_WASI_SYSROOT="${SWIFT_WASI_SYSROOT:-$SWIFT_SDKS_DIR/${SWIFT_WASM_SDK_ID}.artifactbundle/${SWIFT_WASM_SDK_ID}/${SWIFT_WASM_TRIPLE}/WASI.sdk}"
if [ ! -f "$SWIFT_WASI_SYSROOT/include/c++/v1/__config_site" ]; then
  echo "error: the Swift wasm SDK's WASI sysroot is not at '$SWIFT_WASI_SYSROOT'." >&2
  echo "       Install it with Scripts/install-wasm-toolchain.sh, or set SWIFT_WASI_SYSROOT." >&2
  exit 1
fi

WORK="${WORK_DIR:-$(mktemp -d)}"
KEEP="${KEEP_WORK:-0}"
cleanup() { [ "$KEEP" = "1" ] || rm -rf "$WORK"; }
trap cleanup EXIT

echo ">>> Swift toolchain : $SWIFT_BIN"
echo ">>> Swift SDK       : $SWIFT_WASM_SDK_ID ($SWIFT_WASM_TRIPLE)"
echo ">>> wasi-sdk        : $WASI_SDK_PREFIX"
echo ">>> EH flags        : $EH_FLAGS"
echo ">>> work directory  : $WORK"
echo

# --- materialise the stub ------------------------------------------------------------------
# The stub is source-only in the repository. Its prebuilt archive and its copy of the threading
# shim are produced here, so that nothing binary and nothing duplicated is committed.
STUB="$WORK/StubOCCT"  # the leaf names the package identity SwiftPM resolves it under
cp -R "$HERE/stub" "$STUB"
mkdir -p "$STUB/Libraries/stub-headers-wasm" "$STUB/Libraries/include" "$STUB/shims"
# The kernel target's default public-headers directory. SwiftPM refuses to LOAD a package whose
# target has no include directory, and nothing creates Libraries/include in OCCTSwift either,
# which is a finding about Package.swift rather than about the stub.
printf '%s\n' '// Deliberately empty. The archive headers are in stub-headers-wasm/.' \
  > "$STUB/Libraries/include/stub-kernel-placeholder.h"
cp "$REPO_ROOT/Scripts/wasm-shims/wasi-std-threading.hpp" "$STUB/shims/"
cp "$STUB/kernel-src/stubkernel.hpp" "$STUB/Libraries/stub-headers-wasm/"
: > "$STUB/Libraries/dummy.c"

# Built the way Scripts/build-occt-wasm.sh builds OCCT: the exception flags on and the shim
# force-included. The sysroot is the SWIFT SDK's WASI.sdk, for the reason given just above, not
# wasi-sdk's own. The kernel is NOT the variable in any case below.
# shellcheck disable=SC2086
"$SWIFT_BIN/clang++" --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" -O1 -c $EH_FLAGS \
  -include "$STUB/shims/wasi-std-threading.hpp" \
  -o "$WORK/stubkernel.o" "$STUB/kernel-src/stubkernel.cpp" || exit 1
"$SWIFT_BIN/llvm-ar" rcs "$STUB/Libraries/libSTUBKERNEL-wasm.a" "$WORK/stubkernel.o" || exit 1
rm -rf "$STUB/kernel-src"

( cd "$STUB" && git init -q . && git add -A \
  && git -c user.email=probe@localhost -c user.name=probe commit -qm "stub 1.0.0" \
  && git tag 1.0.0 ) || exit 1

CONSUMER="$WORK/consumer"
cp -R "$HERE/consumer" "$CONSUMER"

# The dependency checkout SwiftPM will create, which is where the kernel archive ends up and
# therefore what a -L has to name. Its leaf is the repository directory's name.
CHECKOUT_LIBS="$CONSUMER/.build/checkouts/StubOCCT/Libraries"

# --- the toolsets --------------------------------------------------------------------------
# A toolset is the consumer's file, not the package's. It is where a flag that has no safe
# manifest spelling can live without making the package unresolvable.
emit_toolset() { # $1 = out, $2 = eh|noeh, $3 = sjlj|nosjlj, $4 = include-shim|no-include-shim
  local out="$1" eh="$2" sjlj="$3" shim="$4"
  local cxx=() cc=()
  if [ "$eh" = "eh" ]; then
    # shellcheck disable=SC2206
    cxx=($EH_FLAGS)
    # The C compiler gets the SAME set. -wasm-use-legacy-eh=false is an -mllvm option and applies
    # to any language, and a C object built for SjLj without it carries the legacy encoding, which
    # wasmkit then refuses for the WHOLE module with `Illegal opcode: [6]`. That is not a
    # hypothetical: this function handed the C compiler only the SjLj pair on its first run and
    # cases 7 and 8 failed exactly that way.
    # shellcheck disable=SC2206
    cc=($EH_FLAGS)
  fi
  if [ "$sjlj" = "sjlj" ]; then
    cc+=(-mllvm -wasm-enable-sjlj)
    cxx+=(-mllvm -wasm-enable-sjlj)
  fi
  if [ "$shim" = "include-shim" ]; then
    cxx+=(-include "$STUB_CHECKOUT_SHIM")
  fi
  python3 "$HERE/emit-toolset.py" "$out" "$EH_LIB_DIR" "$CHECKOUT_LIBS" "${#cxx[@]}" \
    "${cxx[@]+"${cxx[@]}"}" "${cc[@]+"${cc[@]}"}"
}

# --- the case runner -----------------------------------------------------------------------
FAILURES=0
CASE_NO=0
say() { printf '\n=== case %s: %s ===\n' "$1" "$2"; }
verdict() { # $1 = "ok"/"bad", $2 = text
  if [ "$1" = ok ]; then printf '    ok   %s\n' "$2"; else printf '    FAIL %s\n' "$2"; FAILURES=$((FAILURES + 1)); fi
}

build_consumer() { # env passed by caller; $1..= extra swift build args
  ( cd "$CONSUMER" && rm -rf .build Package.resolved \
    && swift build --manifest-cache none \
        --swift-sdk "$SWIFT_WASM_SDK_ID" --triple "$SWIFT_WASM_TRIPLE" "$@" ) 2>&1
}

resolve_then_build() { # resolve first, so the checkout (and its Libraries) exists for -L
  ( cd "$CONSUMER" && rm -rf .build Package.resolved \
    && swift package --manifest-cache none resolve >/dev/null 2>&1 \
    && swift build --manifest-cache none \
        --swift-sdk "$SWIFT_WASM_SDK_ID" --triple "$SWIFT_WASM_TRIPLE" "$@" ) 2>&1
}

# Runs the built module, leaving its output in $RUN and its exit status in $MODULE_STATUS.
# Not a command substitution, because a subshell could not report the status back.
run_module() {
  local wasm="$CONSUMER/.build/out/Products/Debug-webassembly-wasm32/consumer.wasm"
  [ -f "$wasm" ] || wasm="$(find "$CONSUMER/.build" -name consumer.wasm 2>/dev/null | head -1)"
  if [ -z "$wasm" ] || [ ! -f "$wasm" ]; then
    MODULE_STATUS=127
    RUN="(no consumer.wasm was produced)"
    return
  fi
  RUN="$(wasmkit run "$wasm" 2>&1)"
  MODULE_STATUS=$?
}

export STUB_WASI=1
export STUB_EXPECT_WASI=1
export STUB_SJLJ=0

# ------------------------------------------------------------------------------------------
say 1 "unsafeFlags, consumed as a VERSIONED dependency (what #1689's app does)"
OUT="$(STUB_PACKAGE_URL="$STUB" STUB_UNSAFE_FLAGS=1 STUB_SHIM_VIA_INCLUDE=0 build_consumer)"
if grep -q "contains unsafe build flags" <<<"$OUT"; then
  verdict ok "refused: $(grep -m1 'unsafe build flags' <<<"$OUT" | sed 's/^error: //')"
else
  verdict bad "expected a refusal, got:"; tail -5 <<<"$OUT"
fi

# ------------------------------------------------------------------------------------------
say 2 "the same unsafeFlags, consumed as a PATH dependency (what a checkout does)"
OUT="$(STUB_PACKAGE_PATH="$STUB" STUB_UNSAFE_FLAGS=1 STUB_SHIM_VIA_INCLUDE=0 resolve_then_build)"
if grep -q "contains unsafe build flags" <<<"$OUT"; then
  verdict bad "a path dependency was also refused, which would change the finding"
elif grep -q "wasm-ld: error" <<<"$OUT"; then
  verdict ok "accepted, and the build reached the LINK, so the refusal is about the requirement"
  printf '         (a version), not about the flag\n'
else
  verdict bad "expected the flags accepted and the build to reach the link, got:"; tail -8 <<<"$OUT"
fi

# From here on the stub carries only settings SwiftPM considers safe, and every case is the
# versioned dependency, which is the one the refusal applies to.
export STUB_PACKAGE_URL="$STUB"
unset STUB_UNSAFE_FLAGS

# ------------------------------------------------------------------------------------------
say 3 "safe settings only, no threading shim, no toolset"
OUT="$(STUB_SHIM_VIA_INCLUDE=0 resolve_then_build)"
if grep -q "no type named 'mutex' in namespace 'std'" <<<"$OUT"; then
  verdict ok "compile failed on std::mutex, so the shim is load-bearing rather than belt and braces"
else
  verdict bad "expected the std::mutex failure, got:"; tail -5 <<<"$OUT"
fi

# ------------------------------------------------------------------------------------------
say 4 "shim by a guarded #include (safe settings only), still no toolset"
OUT="$(STUB_SHIM_VIA_INCLUDE=1 resolve_then_build)"
if grep -q "unable to find library" <<<"$OUT"; then
  verdict ok "compiled, so the shim needs no build setting at all. The LINK then failed:"
  grep -o "unable to find library -l[A-Za-z0-9+_-]*" <<<"$OUT" | sort -u | sed 's/^/         /'
  printf '         The library NAMES reached wasm-ld from .linkedLibrary; the -L that finds them\n'
  printf '         has no safe spelling at all.\n'
else
  verdict bad "expected a link failure on a missing library, got:"; tail -8 <<<"$OUT"
fi

# ------------------------------------------------------------------------------------------
# Cases 5 onward need the checkout to exist before a toolset can name paths inside it.
( cd "$CONSUMER" && rm -rf .build Package.resolved && swift package --manifest-cache none resolve ) >/dev/null 2>&1
STUB_CHECKOUT_SHIM="$CONSUMER/.build/checkouts/StubOCCT/shims/wasi-std-threading.hpp"

say 5 "toolset with the library paths but WITHOUT the exception flags"
emit_toolset "$WORK/toolset-noeh.json" noeh nosjlj no-include-shim
OUT="$(STUB_SHIM_VIA_INCLUDE=1 build_consumer --toolset "$WORK/toolset-noeh.json")"
if grep -qi "error:" <<<"$OUT"; then
  verdict bad "expected a clean build, got:"; tail -8 <<<"$OUT"
else
  run_module
  echo "$RUN" | sed 's/^/      /'
  if [ "$MODULE_STATUS" = 127 ]; then
    # This case asserts a NEGATIVE, so a module that never ran would satisfy it for the wrong
    # reason: no module means no catch, and the case would report the #2171 finding it did not
    # measure. 127 is run_module's "nothing to run".
    verdict bad "no module was produced, so this case measured nothing"
  elif grep -q "outermost catch (...) fires: 22" <<<"$RUN"; then
    verdict bad "the catch fired without the exception flags, which would retire gap 2"
  else
    verdict ok "built clean with no diagnostic, and the outermost catch (...) did not fire (module exit $MODULE_STATUS)"
  fi
fi

# ------------------------------------------------------------------------------------------
export STUB_SJLJ=1

say 6 "setjmp in the graph, exception flags on, but no -mllvm -wasm-enable-sjlj"
emit_toolset "$WORK/toolset-eh-nosjlj.json" eh nosjlj no-include-shim
OUT="$(STUB_SHIM_VIA_INCLUDE=1 build_consumer --toolset "$WORK/toolset-eh-nosjlj.json")"
# One line has to carry both words. Two independent greps over the whole output would also be
# satisfied by any unrelated failure that merely mentions setjmp somewhere, `wasm-ld: error:
# unable to find library -lsetjmp` among them, and the case would report a diagnostic it never saw.
if grep -qi "error.*setjmp" <<<"$OUT"; then
  verdict ok "refused, and the diagnostic names setjmp, so that flag is separate from the EH pair"
  grep -im1 "error.*setjmp" <<<"$OUT" | sed 's/^/         /'
else
  verdict bad "expected one diagnostic naming both an error and setjmp, got:"; tail -8 <<<"$OUT"
fi

say 7 "toolset with the library paths, the exception flags AND the sjlj flag (the recommendation)"
emit_toolset "$WORK/toolset-eh.json" eh sjlj no-include-shim
OUT="$(STUB_SHIM_VIA_INCLUDE=1 build_consumer --toolset "$WORK/toolset-eh.json")"
if grep -qi "error:" <<<"$OUT"; then
  verdict bad "build failed:"; tail -12 <<<"$OUT"
else
  run_module
  echo "$RUN" | sed 's/^/      /'
  if grep -q "consumer: all cases passed" <<<"$RUN"; then
    verdict ok "a VERSIONED dependency built for $SWIFT_WASM_TRIPLE and every case passed"
  else
    verdict bad "the module ran but not every case passed (exit $MODULE_STATUS)"
  fi
fi

say 8 "the same, with the shim force-included by the toolset instead of by the source"
emit_toolset "$WORK/toolset-eh-include.json" eh sjlj include-shim
OUT="$(STUB_SHIM_VIA_INCLUDE=0 build_consumer --toolset "$WORK/toolset-eh-include.json")"
if grep -qi "error:" <<<"$OUT"; then
  verdict bad "build failed:"; tail -12 <<<"$OUT"
else
  run_module
  echo "$RUN" | sed 's/^/      /'
  if grep -q "consumer: all cases passed" <<<"$RUN"; then
    verdict ok "-include from a toolset works too, so the shim has two viable mechanisms"
  else
    verdict bad "the module ran but not every case passed (exit $MODULE_STATUS)"
  fi
fi

# ------------------------------------------------------------------------------------------
# Not about SwiftPM at all, and found while measuring the above: Sources/OCCTBridge/src holds 33
# Objective-C++ files, and the recommendation puts -fwasm-exceptions on every one of them.
say 9 "Objective-C++ plus -fwasm-exceptions, compiled directly (no SwiftPM)"
printf '%s\n' '#include <vector>' \
  'extern "C" int objcxxProbe(void) { std::vector<int> v{1, 2, 3}; return (int)v.size(); }' \
  > "$WORK/objcxx.mm"
OBJCXX_OK=1
# shellcheck disable=SC2086
"$SWIFT_BIN/clang++" -x c++ --target="$SWIFT_WASM_TRIPLE" --sysroot="$SWIFT_WASI_SYSROOT" \
  -c $EH_FLAGS "$WORK/objcxx.mm" -o "$WORK/objcxx-cpp.o" >/dev/null 2>&1 || OBJCXX_OK=0
OBJCXX_MM=1
# The output is kept rather than discarded: the verdict below names a specific clang crash, and an
# exit status alone cannot tell a crash from an ordinary diagnostic. If the toolchain ever turns
# this into a plain "unsupported option" error, the case has to say so rather than keep reporting
# a crash it no longer sees.
# shellcheck disable=SC2086
MM_OUT="$("$SWIFT_BIN/clang++" -x objective-c++ --target="$SWIFT_WASM_TRIPLE" \
  --sysroot="$SWIFT_WASI_SYSROOT" -c $EH_FLAGS "$WORK/objcxx.mm" -o "$WORK/objcxx-mm.o" 2>&1)" \
  || OBJCXX_MM=0
if [ "$OBJCXX_OK" = 1 ] && [ "$OBJCXX_MM" = 0 ] \
   && grep -q "WebAssembly Exception Information" <<<"$MM_OUT"; then
  verdict ok "the same file compiles as C++ and CRASHES clang as Objective-C++, in the"
  printf '         WebAssembly Exception Information pass. The bridge is 33 .mm files, so the\n'
  printf '         recommendation below is blocked on that until they compile as C++.\n'
elif [ "$OBJCXX_OK" = 1 ] && [ "$OBJCXX_MM" = 0 ]; then
  verdict bad "Objective-C++ still fails, but not in the WebAssembly Exception Information pass,"
  printf '         so the note about this blocker no longer describes what happens:\n'
  tail -5 <<<"$MM_OUT" | sed 's/^/         /'
elif [ "$OBJCXX_MM" = 1 ]; then
  verdict bad "Objective-C++ now compiles with the exception flags, so this blocker is gone and"
  printf '         the note about it should be deleted rather than left standing.\n'
else
  verdict bad "the C++ control did not compile either, so this case measured nothing"
fi

echo
if [ "$FAILURES" = 0 ]; then
  echo "All cases produced the outcome they assert. See README.md for what each one means."
else
  echo "$FAILURES case(s) did not. See the output above."
fi
[ "$KEEP" = "1" ] && echo "work directory kept at $WORK"
exit $((FAILURES > 0))
