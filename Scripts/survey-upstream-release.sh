#!/bin/bash
#
# Survey the carried patches against a new upstream OCCT release: which retire, which rebase, which
# apply unchanged. The method the 8.0.1 to 8.0.2 survey used (docs/occt-upgrades.md), as a script, so
# that 8.0.3 or 8.1 is a run and not a day.
#
# Usage:
#   Scripts/survey-upstream-release.sh <tag>                    survey Scripts/patches against <tag>
#   Scripts/survey-upstream-release.sh <tag> --wasi             survey Scripts/patches-wasi too
#   Scripts/survey-upstream-release.sh <tag> --tree DIR         take <tag> from DIR (any OCCT clone) instead of cloning
#   Scripts/survey-upstream-release.sh <tag> --merge3 NNNN --base <old tag> --tree DIR
#                                                               three-way merge patch NNNN onto the tree
#
# Read-only against the repo and against any tree you name: it works in a throwaway copy of <tag>
# and never writes under Scripts/. Two passes, in the order that matters:
#
#   independent  each patch alone against the pristine tag, forward and reverse. A patch that
#                reverse-applies is already in the release: retire it. A patch that applies forward
#                and not in reverse is still needed.
#   cumulative   the stack in order, as Scripts/build-occt.sh applies it, which is the authority:
#                a patch may depend on an earlier one (0076 on 0074), so alone it conflicts and in
#                the stack it applies.
#
# THE RULE THE VERDICTS FOLLOW (okf/policies/kernel-fix-ledger.md): when upstream took only part of
# a patch, never carry the surviving half. The half upstream took is what makes the other half
# safe. Keep the patch whole, or drop it whole and file the gap.
#
# What each verdict asks of you, in the ledger (Scripts/kernel-fixes.tsv):
#   unchanged     nothing.
#   RETIRE        group becomes `absorbed`, upstream_in becomes <tag's version>, relation is identical
#                 or same-code (compare the patched file to the release's), and the patch file is
#                 deleted AND its edits reverted in occt-src (build-occt.sh never reverts).
#   HALF          upstream took part of it: decide whole-or-nothing, as above.
#   REBASE        the release changed lines near the hunk: --merge3 does a three-way merge against
#                 the old tag, markers left in place for a hand resolution.
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TAG=""
TREE=""
WASI=""
MERGE3=""
BASE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --wasi) WASI=1; shift ;;
        --tree) TREE="$2"; shift 2 ;;
        --merge3) MERGE3="$2"; shift 2 ;;
        --base) BASE="$2"; shift 2 ;;
        -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d'; exit 0 ;;
        -*) echo "ERROR: unknown option '$1'." >&2; exit 2 ;;
        *) [ -z "$TAG" ] && TAG="$1" || { echo "ERROR: one tag only." >&2; exit 2; }; shift ;;
    esac
done
[ -n "$TAG" ] || { echo "usage: $0 <upstream tag, e.g. V8_0_3> [--wasi] [--tree DIR]" >&2; exit 2; }

# The survey RESETS and CLEANS the tree it patches, so it never touches a tree you hand it: a
# Libraries/occt-src carrying the build's patches would be wiped. It works in a throwaway copy, a
# shallow clone or, with --tree, a detached git worktree of <tag> taken from your tree. The one
# exception is --merge3, whose whole point is to write markers into a tree you named.
CLEANUP=""
WORK=""
cleanup() {
    [ -n "$CLEANUP" ] && git -C "$CLEANUP" worktree remove --force "$WORK/tree" >/dev/null 2>&1
    [ -n "$WORK" ] && rm -rf "$WORK"
}
trap cleanup EXIT
if [ -z "$MERGE3" ]; then
    WORK="$(mktemp -d "${TMPDIR:-/tmp}/occt-survey.XXXXXX")"
    if [ -n "$TREE" ]; then
        [ -d "$TREE/.git" ] || [ -f "$TREE/.git" ] || { echo "ERROR: $TREE is not a git tree." >&2; exit 2; }
        git -C "$TREE" worktree add -q --detach "$WORK/tree" "$TAG" || { echo "ERROR: $TAG is not a tag or commit in $TREE." >&2; exit 2; }
        CLEANUP="$TREE"
    else
        echo ">>> cloning $TAG (shallow) into $WORK/tree"
        git clone -q --depth 1 --branch "$TAG" https://github.com/Open-Cascade-SAS/OCCT.git "$WORK/tree" || exit 2
    fi
    TREE="$WORK/tree"
fi
[ -e "$TREE/.git" ] || { echo "ERROR: $TREE is not a git tree." >&2; exit 2; }

# A ledger id for a patch file, so the table says which row to move.
ledger_id() { echo "F${1:0:4}"; }

# files_of <patch>: the files it touches.
files_of() { git -C "$TREE" apply --numstat "$1" | cut -f3; }

# per_file <patch> <mode>: "ok", "in-tree" or "CONFLICT" for each file, mode = forward check.
per_file() {
    local p=$1 file out=""
    while IFS= read -r file; do
        if git -C "$TREE" apply --check --include="$file" "$p" 2>/dev/null; then out="$out $file(ok)"
        elif git -C "$TREE" apply --reverse --check --include="$file" "$p" 2>/dev/null; then out="$out $file(in-tree)"
        else out="$out $file(CONFLICT)"; fi
    done < <(files_of "$p")
    echo "$out"
}

if [ -n "$MERGE3" ]; then
    [ -n "$BASE" ] || { echo "ERROR: --merge3 needs --base <the tag the patches were written against>." >&2; exit 2; }
    P="$(ls "$REPO_ROOT"/Scripts/patches/"$MERGE3"-*.patch 2>/dev/null | head -1)"
    [ -n "$P" ] || { echo "ERROR: no Scripts/patches/$MERGE3-*.patch." >&2; exit 2; }
    T="$(mktemp -d "${TMPDIR:-/tmp}/merge3.XXXXXX")"
    trap 'rm -rf "$T"' EXIT
    git -C "$TREE" fetch -q --depth 1 origin "refs/tags/$BASE:refs/tags/$BASE" 2>/dev/null || true
    # base   = the old tag's file plus every EARLIER patch that touches it (they were applied on the old tag)
    # theirs = base plus this patch;  ours = the survey tree's file
    for f in $(files_of "$P"); do
        mkdir -p "$T/base/$(dirname "$f")" "$T/theirs/$(dirname "$f")"
        if git -C "$TREE" cat-file -e "$BASE:$f" 2>/dev/null; then git -C "$TREE" show "$BASE:$f" > "$T/base/$f"; else : > "$T/base/$f"; fi
    done
    for q in "$REPO_ROOT"/Scripts/patches/*.patch; do
        [[ "$(basename "$q")" < "$(basename "$P")" ]] || break
        for f in $(files_of "$P"); do
            files_of "$q" | grep -qxF "$f" && (cd "$T/base" && git apply --include="$f" "$q" 2>/dev/null)
        done
    done
    cp -R "$T/base/." "$T/theirs/"
    (cd "$T/theirs" && git apply "$P") || { echo "ERROR: the patch does not apply to its own base."; exit 1; }
    for f in $(files_of "$P"); do
        [ -f "$TREE/$f" ] || : > "$TREE/$f"
        if git merge-file -L ours -L base -L theirs "$TREE/$f" "$T/base/$f" "$T/theirs/$f"; then echo "  merged clean: $f"
        else echo "  CONFLICT: $f ($(grep -c '^<<<<<<<' "$TREE/$f") regions, markers left in $TREE/$f)"; fi
    done
    exit 0
fi

survey_dir() {
    local dir=$1 label=$2 p n f r
    [ -d "$dir" ] && ls "$dir"/*.patch >/dev/null 2>&1 || return 0
    echo
    echo "== $label, independent (each patch alone, pristine $(git -C "$TREE" describe --tags --always))"
    git -C "$TREE" reset -q --hard && git -C "$TREE" clean -qfdx
    for p in "$dir"/*.patch; do
        n="$(basename "$p" | cut -c1-4)"
        f=no; r=no
        git -C "$TREE" apply --check "$p" 2>/dev/null && f=yes
        git -C "$TREE" apply --reverse --check "$p" 2>/dev/null && r=yes
        printf '%s %s fwd=%s rev=%s\n' "$n" "$(ledger_id "$n")" "$f" "$r"
    done
    echo
    echo "== $label, cumulative (the stack in order, as the build applies it)"
    local retire="" half="" rebase="" clean=0
    for p in "$dir"/*.patch; do
        n="$(basename "$p" | cut -c1-4)"
        if git -C "$TREE" apply --reverse --check "$p" 2>/dev/null; then
            echo "$n $(ledger_id "$n") RETIRE   already in the release (reverse-applies)"; retire="$retire $n"
        elif git -C "$TREE" apply --check "$p" 2>/dev/null; then
            git -C "$TREE" apply "$p" && clean=$((clean + 1))
        else
            detail="$(per_file "$p")"
            case "$detail" in
                *"(in-tree)"*"(ok)"*|*"(ok)"*"(in-tree)"*)
                    echo "$n $(ledger_id "$n") HALF     part is in the release, part is not:$detail"; half="$half $n" ;;
                *)  echo "$n $(ledger_id "$n") REBASE   $detail"; rebase="$rebase $n" ;;
            esac
        fi
    done
    echo
    echo "$label: $clean unchanged;${retire:+ RETIRE$retire;}${half:+ HALF$half;}${rebase:+ REBASE$rebase;}"
    [ -z "$retire$half$rebase" ] && echo "$label: nothing to do."
    git -C "$TREE" status --short | wc -l | sed 's/^ */files modified in the survey tree: /'
}

survey_dir "$REPO_ROOT/Scripts/patches" "Scripts/patches"
[ -n "$WASI" ] && survey_dir "$REPO_ROOT/Scripts/patches-wasi" "Scripts/patches-wasi"
exit 0
