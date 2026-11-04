# Sourced by build-occt.sh and build-occt-wasm.sh, never run. Applies a directory of carried OCCT
# patches to ./occt-src (the caller's working directory is Libraries/), idempotently and in order.
#
# One copy, because the wasm script had its own loop and it lacked the superseded-patch fallback
# below, so it stopped with "cannot apply 0050 cleanly" on a tree build-occt.sh had patched (#3502).
#
# Portable to bash 3.2, which is what `#!/bin/bash` runs on macOS: no `mapfile`, no `${x,,}`. The
# first version of the fallback used `mapfile`, which is "command not found" there, so a second run
# of ./Scripts/build-occt.sh read every superseded patch as a conflict.
#
# The patches are a stack and a later one may rewrite lines an earlier one added (0055 corrects
# 0050 and 0051, #3010; 0076 rewrites lines of 0074 that 0073 also touches). On a tree that already
# carries the stack, the earlier patch then fails BOTH `--reverse --check` (its added lines are
# gone) and the forward `--check` (it is already applied), which read as "cannot apply cleanly".
#
# That is decided file by file. A patch is carried when every file it touches is either still as
# the patch left it, or is held by a LATER patch that touches that file and reverse-checks clean
# restricted to it, because that later patch can only have applied on top of this one's changes. A
# whole-patch check was not enough: 0074 touches files 0076 does not, so 0074 reverse-checks dirty
# as a whole, and 0073 (whose files 0076 does not touch) then had no successor that did. A patch
# with one file carried and another missing, or one that conflicts with the tree and has no applied
# successor, still stops the build.
patch_files() { git -C occt-src apply --numstat "$1" | cut -f3; }

# superseding_patch <patch> <file> <the directory's patches in order>: prints the first later patch
# whose changes to <file> are in the tree.
superseding_patch() {
    local p=$1 f=$2 q
    shift 2
    for q in "$@"; do
        [[ "$q" > "$p" ]] || continue
        patch_files "$q" | grep -qxF -- "$f" || continue
        if git -C occt-src apply --reverse --check --include="$f" "$q" 2>/dev/null; then
            basename "$q"
            return 0
        fi
    done
    return 1
}

# carried_by_later_patches <patch> <the directory's patches in order>: succeeds when every file of
# the patch is carried (see above), leaving the patches that carry them in CARRIED_BY; fails with
# the file and the reason in CARRIED_WHY. Globals, because a $(...) would lose them.
carried_by_later_patches() {
    local p=$1 f by
    shift
    CARRIED_BY=""
    CARRIED_WHY=""
    while IFS= read -r f; do
        if git -C occt-src apply --reverse --check --include="$f" "$p" 2>/dev/null; then
            continue
        elif git -C occt-src apply --check --include="$f" "$p" 2>/dev/null; then
            CARRIED_WHY="$f is not patched, but the rest of the patch is"
            return 1
        elif by=$(superseding_patch "$p" "$f" "$@"); then
            case " $CARRIED_BY " in *" $by "*) ;; *) CARRIED_BY="${CARRIED_BY:+$CARRIED_BY }$by" ;; esac
        else
            CARRIED_WHY="$f conflicts with the tree and no later patch holds it"
            return 1
        fi
    done < <(patch_files "$p")
    [ -n "$CARRIED_BY" ]
}

# apply_patch_dir <dir> <label>
apply_patch_dir() {
    local dir=$1 label=$2 p
    [ -d "$dir" ] && ls "$dir"/*.patch >/dev/null 2>&1 || return 0
    echo ">>> Applying $label..."
    local -a patches=("$dir"/*.patch)
    for p in "${patches[@]}"; do
        if git -C occt-src apply --reverse --check "$p" 2>/dev/null; then
            echo "    already applied: $(basename "$p")"
        elif git -C occt-src apply --check "$p" 2>/dev/null; then
            git -C occt-src apply "$p"
            echo "    applied: $(basename "$p")"
        elif carried_by_later_patches "$p" "${patches[@]}"; then
            echo "    already applied (rewritten by $CARRIED_BY): $(basename "$p")"
        else
            echo "    ERROR: cannot apply $(basename "$p") cleanly${CARRIED_WHY:+: $CARRIED_WHY}" >&2
            exit 1
        fi
    done
}
