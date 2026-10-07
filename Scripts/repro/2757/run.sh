#!/bin/bash
#
# #2757: reproduce, and bound, the invalid br_table that setjmp lowering plus wasm exceptions emits.
#
#   Scripts/repro/2757/run.sh
#
# Needs only the pinned toolchain (Scripts/install-wasm-toolchain.sh), the Swift wasm SDK's WASI
# sysroot, and `node` (any release with standardised exception handling, so >= 24) as the
# validator. No OCCT, no kernel archive, no 69-minute build. Every case ASSERTS, in both
# directions: a control that stops validating is as much a finding as a defect that stops
# reproducing.
#
# Overrides: SWIFT_TOOLCHAIN_BIN, SWIFT_WASI_SYSROOT, NODE.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PINS="$REPO_DIR/Scripts/wasm-toolchain-versions.txt"
pin() { sed -n "s/^$1=//p" "$PINS" | head -1; }

TOOLCHAIN_BIN="${SWIFT_TOOLCHAIN_BIN:-/Library/Developer/Toolchains/swift-$(pin SWIFT_TOOLCHAIN_VERSION).xctoolchain/usr/bin}"
SYSROOT="${SWIFT_WASI_SYSROOT:-$HOME/Library/org.swift.swiftpm/swift-sdks/$(pin SWIFT_WASM_SDK_ID).artifactbundle/$(pin SWIFT_WASM_SDK_ID)/$(pin SWIFT_WASM_TRIPLE)/WASI.sdk}"
TRIPLE="$(pin SWIFT_WASM_TRIPLE)"
NODE="${NODE:-node}"
CXX="$TOOLCHAIN_BIN/clang++"
LD="$TOOLCHAIN_BIN/wasm-ld"
NM="$TOOLCHAIN_BIN/llvm-nm"
OBJDUMP="$TOOLCHAIN_BIN/llvm-objdump"
EH="$(pin WASM_CXX_EH_FLAGS)"   # -fwasm-exceptions -mllvm -wasm-use-legacy-eh=false
for t in "$CXX" "$LD" "$NM" "$OBJDUMP"; do
    [ -x "$t" ] || { echo "ERROR: $t missing; run Scripts/install-wasm-toolchain.sh" >&2; exit 1; }
done
[ -d "$SYSROOT" ] || { echo "ERROR: no WASI sysroot at $SYSROOT (set SWIFT_WASI_SYSROOT)" >&2; exit 1; }
command -v "$NODE" >/dev/null || { echo "ERROR: node not found; it is the validator" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/occt-2757.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
FAILURES=0
fail() { echo "    FAIL: $*"; FAILURES=$((FAILURES + 1)); }

echo "clang: $("$CXX" --version | head -1)"
echo "node:  $("$NODE" --version)"

# compile <name> <source> <flags...>; then link to a wasm module and ask V8 to validate it.
# Prints "valid" or V8's message; sets RESULT.
build_and_validate() {
    local name="$1" src="$2"; shift 2
    # shellcheck disable=SC2086
    "$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -O2 "$@" -c "$src" -o "$WORK/$name.o" 2>"$WORK/$name.err" \
        || { RESULT="COMPILE-ERROR: $(head -2 "$WORK/$name.err")"; return; }
    "$LD" --no-entry --allow-undefined --no-gc-sections --export-all -o "$WORK/$name.wasm" "$WORK/$name.o" 2>"$WORK/$name.lderr" \
        || { RESULT="LINK-ERROR: $(head -2 "$WORK/$name.lderr")"; return; }
    RESULT="$("$NODE" -e 'const b=require("fs").readFileSync(process.argv[1]);try{new WebAssembly.Module(b);console.log("valid")}catch(e){console.log(e.message)}' "$WORK/$name.wasm")"
}

BAD="$SCRIPT_DIR/sjlj-br-table.cpp"
# shellcheck disable=SC2206
BOTH=($EH -mllvm -wasm-enable-sjlj)

echo ""
echo "== the reduction, at every optimisation level"
for o in -O0 -O1 -O2 -O3 -Os -Oz; do
    build_and_validate "bad$o" "$BAD" "${BOTH[@]}" "$o"
    printf '    %-4s %s\n' "$o" "$RESULT"
    case "$RESULT" in *"br_table: label arity inconsistent"*) ;; *) fail "$o: expected the br_table refusal" ;; esac
done

echo ""
echo "== the br_table, disassembled (-O2)"
build_and_validate bad "$BAD" "${BOTH[@]}"
"$OBJDUMP" -d "$WORK/bad.wasm" | grep -B3 -A1 'br_table' | sed 's/^/    /' | head -24

echo ""
echo "== controls: each changes ONE thing and must validate"
# 1. the legacy EH encoding, with the same sjlj lowering
build_and_validate legacy "$BAD" -fwasm-exceptions -mllvm -wasm-enable-sjlj
printf '    %-52s %s\n' "legacy EH encoding (drop -wasm-use-legacy-eh=false)" "$RESULT"
[ "$RESULT" = valid ] || fail "legacy encoding no longer validates"

# 2. no setjmp in the function
sed 's/if (setjmp(lab()))/lab(); if (true)/' "$BAD" >"$WORK/nosetjmp.cpp"
build_and_validate nosetjmp "$WORK/nosetjmp.cpp" "${BOTH[@]}"
printf '    %-52s %s\n' "no setjmp call" "$RESULT"
[ "$RESULT" = valid ] || fail "without setjmp it no longer validates"

# 3. lab() is noexcept
sed 's/^jmp_buf& lab();.*/jmp_buf\& lab() noexcept;/' "$BAD" >"$WORK/noexcept.cpp"
build_and_validate noexcept "$WORK/noexcept.cpp" "${BOTH[@]}"
printf '    %-52s %s\n' "setjmp argument call is noexcept" "$RESULT"
[ "$RESULT" = valid ] || fail "noexcept variant no longer validates"

# 4. a plain global buffer instead of a call
sed -e 's/^jmp_buf& lab();.*/extern jmp_buf buf;/' -e 's/setjmp(lab())/setjmp(buf)/' "$BAD" >"$WORK/global.cpp"
build_and_validate global "$WORK/global.cpp" "${BOTH[@]}"
printf '    %-52s %s\n' "setjmp(global jmp_buf), no call in the try" "$RESULT"
[ "$RESULT" = valid ] || fail "global-buffer variant no longer validates"

# 5. only one loop level
cat >"$WORK/oneloop.cpp" <<'EOF'
#include <setjmp.h>
jmp_buf& lab();
void a();
bool more();
void f() { while (more()) { try { if (setjmp(lab())) a(); } catch (...) {} } }
EOF
build_and_validate oneloop "$WORK/oneloop.cpp" "${BOTH[@]}"
printf '    %-52s %s\n' "one loop level instead of two" "$RESULT"
[ "$RESULT" = valid ] || fail "one-loop variant no longer validates"

echo ""
echo "== without -wasm-enable-sjlj the setjmp is not lowered at all"
"$CXX" --target="$TRIPLE" --sysroot="$SYSROOT" -O2 $EH -c "$BAD" -o "$WORK/nolower.o" \
    || fail "compile without -wasm-enable-sjlj"
if "$NM" --undefined-only "$WORK/nolower.o" | grep -qE '^ *U setjmp$'; then
    echo "    undefined reference to plain 'setjmp' (a link error on wasip1)"
else
    fail "expected a plain undefined setjmp"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then echo ">>> OK"; else echo ">>> $FAILURES check(s) failed."; fi
exit "$FAILURES"
