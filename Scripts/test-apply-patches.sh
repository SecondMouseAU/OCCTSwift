#!/bin/bash
# Tests Scripts/lib/apply-patches.sh, which build-occt.sh and build-occt-wasm.sh both source (#3502).
#
# usage: Scripts/test-apply-patches.sh      (run it under /bin/bash AND under a newer bash: the macOS
#                                            system bash is 3.2, which has no `mapfile`)
#
# Builds a throwaway git tree and a stack of patches that has the shape of 0073, 0074 and 0076
# (a later patch rewrites lines of an earlier one in a file the earliest does not touch), then
# applies the stack twice and breaks the tree in the two ways the helper must still refuse.
# Needs only git. Exits 1 on the first failed expectation.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
GIT=(git -c user.name=t -c user.email=t@t.invalid -c init.defaultBranch=main)

failures=0
expect() { # description, command...
    local what=$1
    shift
    if "$@"; then
        echo "ok   $what"
    else
        echo "FAIL $what"
        failures=$((failures + 1))
    fi
}

# --- the patch stack ------------------------------------------------------------------------
GEN="$WORK/gen"
mkdir -p "$GEN" "$WORK/patches"
(
    cd "$GEN" || exit 1
    "${GIT[@]}" init -q .
    for f in a b c d e f; do
        printf '%s1\n%s2\n%s3\n%s4\n%s5\n' $f $f $f $f $f > $f.txt
    done
    "${GIT[@]}" add . && "${GIT[@]}" commit -q -m base
    "${GIT[@]}" tag base
    step() { # number, then sed expressions "file:expr"
        local n=$1 spec
        shift
        for spec in "$@"; do sed -i.bak "${spec#*:}" "${spec%%:*}"; done
        rm -f ./*.bak
        "${GIT[@]}" diff > "$WORK/patches/$n-step.patch"
        "${GIT[@]}" commit -q -am "$n"
    }
    # 0001 edits a. 0002 rewrites 0001's line in a and adds a line to c. 0003 rewrites 0002's line in
    # c: 0002 no longer reverse-checks as a whole, and 0003 does not touch a, 0001's only file.
    step 0001 'a.txt:s/^a2$/a2-p1/'
    step 0002 'a.txt:s/^a2-p1$/a2-p2/' 'c.txt:s/^c3$/c3-p2/'
    step 0003 'c.txt:s/^c3-p2$/c3-p3/'
    # 0004 touches two files, for the half-applied case. 0005 for a genuine conflict.
    step 0004 'd.txt:s/^d2$/d2-p4/' 'e.txt:s/^e2$/e2-p4/'
    step 0005 'f.txt:s/^f2$/f2-p5/'
) || { echo "could not build the test stack"; exit 1; }

fresh_tree() {
    rm -rf "$WORK/run" && mkdir "$WORK/run"
    "${GIT[@]}" clone -q "$GEN" "$WORK/run/occt-src" && "${GIT[@]}" -C "$WORK/run/occt-src" checkout -q base
}

# apply_stack [patches-dir]: runs the helper from the tree's parent; output in $WORK/out, status in $?
apply_stack() {
    (
        cd "$WORK/run" || exit 1
        # shellcheck source=lib/apply-patches.sh
        source "$HERE/lib/apply-patches.sh"
        apply_patch_dir "${1:-$WORK/patches}" "test patches"
    ) > "$WORK/out" 2>&1
}
said() { grep -q -- "$1" "$WORK/out"; }
file_has() { grep -qx -- "$2" "$WORK/run/occt-src/$1"; }

# --- 1. a fresh tree gets every patch, in order -----------------------------------------------
fresh_tree
apply_stack; rc=$?
expect "fresh tree: exits 0" test $rc -eq 0
expect "fresh tree: applies all five" test "$(grep -c '^    applied: ' "$WORK/out")" -eq 5
expect "fresh tree: a.txt holds 0002's line" file_has a.txt a2-p2
expect "fresh tree: c.txt holds 0003's line" file_has c.txt c3-p3

# --- 2. the second run on a tree that carries the stack ---------------------------------------
apply_stack; rc=$?
expect "second run: exits 0" test $rc -eq 0
expect "second run: 0003 and 0005 are already applied" said "already applied: 0003-step.patch"
expect "second run: 0001 is rewritten by 0002 (a later patch holds its file)" \
    said "already applied (rewritten by 0002-step.patch): 0001-step.patch"
expect "second run: 0002 is rewritten by 0003 (a whole-patch reverse check fails on c.txt)" \
    said "already applied (rewritten by 0003-step.patch): 0002-step.patch"
expect "second run: nothing is applied twice" test "$(grep -c '^    applied: ' "$WORK/out")" -eq 0

# --- 3. a patch with one file carried and the other missing stops the build -------------------
git -C "$WORK/run/occt-src" checkout -q -- e.txt
apply_stack; rc=$?
expect "half-applied patch: exits 1" test $rc -eq 1
expect "half-applied patch: names the patch and the file" \
    said "ERROR: cannot apply 0004-step.patch cleanly: e.txt is not patched"

# --- 4. a patch that conflicts with the tree and has no applied successor stops it ------------
fresh_tree
sed -i.bak 's/^f2$/f2-local-edit/' "$WORK/run/occt-src/f.txt" && rm -f "$WORK/run/occt-src/f.txt.bak"
apply_stack; rc=$?
expect "conflict: exits 1" test $rc -eq 1
expect "conflict: names the patch and the file" \
    said "ERROR: cannot apply 0005-step.patch cleanly: f.txt conflicts with the tree"

# --- 5. a missing directory is not an error ---------------------------------------------------
fresh_tree
apply_stack "$WORK/nope"; rc=$?
expect "no patch directory: exits 0" test $rc -eq 0

echo
if [ "$failures" -ne 0 ]; then
    echo "$failures expectation(s) failed (bash ${BASH_VERSION})"
    exit 1
fi
echo "all expectations met (bash ${BASH_VERSION})"
