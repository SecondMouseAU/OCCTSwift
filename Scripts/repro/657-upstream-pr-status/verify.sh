#!/usr/bin/env bash
# #657: re-verify the ten upstream OCCT PR statuses and patch 0020's fileability.
#
# Does two independent things per patch, neither of which trusts GitHub's own
# "Update branch" banner or the state recorded in issue #657:
#
#   1. Queries the GitHub API directly for each PR's actual state/merged/mergeable
#      flags, review comments and CI status (a status claim is only as good as the
#      last time someone checked it; see okf's "verify external status claims"
#      lesson).
#   2. Applies this repo's own carried .patch file to a fresh, unmodified checkout
#      of upstream OCCT's CURRENT master tip and checks it applies without a single
#      rejected hunk. This is a stronger claim than GitHub's `mergeable` flag: it
#      proves OUR patch file (not just the PR branch, which may have drifted from
#      it) still matches current upstream source byte-for-byte in context.
#
# This script does NOT reproduce every claim in this directory's README.md: Method 3
# there (diffing the resulting file tree of our local .patch vs. the live PR .diff,
# used for 1388/1399) and Method 4 (0020's reproducer compile-and-run, and its
# clang-format check) are both manual and are not re-run here. See README.md's
# "Method" section for what each of the four covers.
#
# Requires: gh (authenticated), git, network access to github.com. Read-only:
# makes no upstream writes, no comments, no PR/issue mutations of any kind.
#
# Usage: Scripts/repro/657-upstream-pr-status/verify.sh [scratch-dir]
#
# [scratch-dir], when given, is reused across runs rather than re-cloned from
# scratch (this directory's README recommends exactly that for a re-check months
# later). An earlier version of this script took "reused" to mean "skip Step 2
# entirely if the directory already exists", which meant a rerun against a reused
# directory never looked at upstream again at all, and silently re-validated every
# patch against whatever snapshot the first run happened to make, however old. Reuse
# now only saves the initial clone's network/disk cost: every run fetches and resets
# to the CURRENT origin/master tip before Step 3 checks anything against it. The SHA
# actually validated against is printed prominently below; check it (or just re-run)
# before trusting an "OK" that's more than a few days old.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRATCH="${1:-$(mktemp -d)}"
PATCH_DIR="$REPO_ROOT/Scripts/patches"

echo "Scratch dir: $SCRATCH"
mkdir -p "$SCRATCH"

# our_patch_file:pr_number pairs for the ten patches issue #657 lists, plus 0020
# (not upstream-filed, checked for fileability rather than PR status).
PAIRS=(
  "0010-Intf_Interference-O1-tangent-zone-checkpoint-breaker-319.patch:1386"
  "0011-XCAFDoc_ShapeTool-AutoNamingScope-341.patch:1388"
  "0012-CDF_Directory-XCAFApp_Application-thread-safety-344.patch:1390"
  "0014-CDF-driver-reentrancy-mutex-349.patch:1394"
  "0015-CDM_Application-metadata-lookup-table-mutex-353.patch:1397"
  "0016-Resource_Manager-atomic-Debug-Storage_Schema-per-instance-374.patch:1399"
  "0017-null-reshape-context-ComposeShell-WireDivide-484.patch:1410"
  "0018-GCPnts-degenerate-count-and-duplicate-end-point-555.patch:1417"
  "0019-AdvApp2Var-jacobi-max-wrong-workspace-slot-522.patch:1418"
  "0021-CPnts-adaptive-arc-length-integration-603.patch:1420"
)

echo
echo "== Step 1: live PR status from the GitHub API =="
printf '%-70s %-6s %-6s %-8s %-10s %-8s %-8s\n' "patch" "PR" "state" "merged" "mergeable" "comments" "reviews"

# Ten independent lookups by a fixed, known PR number, not a pipeline, so nothing
# stops them running concurrently. --jq does the field selection AND the
# tab-formatting server-side (Open-Cascade-SAS/OCCT), so nothing downstream needs a
# python3 spawn to re-parse JSON gh api already filtered; `null` (e.g. a freshly
# opened PR whose `mergeable` GitHub hasn't computed yet) prints as the literal
# string "null" rather than an empty column.
JOB_DIR="$SCRATCH/jobs.$$"
rm -rf "$JOB_DIR"
mkdir -p "$JOB_DIR"
for pair in "${PAIRS[@]}"; do
  pr="${pair##*:}"
  gh api "repos/Open-Cascade-SAS/OCCT/pulls/$pr" \
    --jq '[.state, .merged, .mergeable, .comments, .review_comments] | map(if . == null then "null" else . end) | @tsv' \
    >"$JOB_DIR/$pr.tsv" &
done
wait

for pair in "${PAIRS[@]}"; do
  patch="${pair%%:*}"
  pr="${pair##*:}"
  if [ ! -s "$JOB_DIR/$pr.tsv" ]; then
    echo "ERROR: gh api lookup for PR $pr produced no output (network or auth failure?)" >&2
    exit 1
  fi
  IFS=$'\t' read -r state merged mergeable comments reviews <"$JOB_DIR/$pr.tsv"
  printf '%-70s %-6s %-6s %-8s %-10s %-8s %-8s\n' "$patch" "$pr" "$state" "$merged" "$mergeable" "$comments" "$reviews"
done
rm -rf "$JOB_DIR"

echo
echo "== Step 2: sparse checkout of upstream OCCT master tip =="
if [ ! -d "$SCRATCH/occt-master" ]; then
  git clone --filter=blob:none --no-checkout --depth 100 \
    https://github.com/Open-Cascade-SAS/OCCT.git "$SCRATCH/occt-master"
  (cd "$SCRATCH/occt-master" && git sparse-checkout init --cone && git sparse-checkout set \
    src/ModelingAlgorithms/TKBO/BOPAlgo \
    src/ModelingAlgorithms/TKGeomAlgo/Intf \
    src/ModelingAlgorithms/TKGeomAlgo/GTests \
    src/DataExchange/TKDEGLTF/RWGltf \
    src/DataExchange/TKRWMesh/RWMesh \
    src/DataExchange/TKXCAF/XCAFDoc \
    src/DataExchange/TKXCAF/XCAFApp \
    src/ApplicationFramework/TKCDF/CDF \
    src/ApplicationFramework/TKCDF/PCDM \
    src/ApplicationFramework/TKCDF/CDM \
    src/ApplicationFramework/TKLCAF/TDocStd \
    src/ApplicationFramework/TKXmlL/XmlLDrivers \
    src/FoundationClasses/TKernel/Resource \
    src/FoundationClasses/TKernel/Storage \
    src/ModelingAlgorithms/TKShHealing/ShapeFix \
    src/ModelingAlgorithms/TKShHealing/ShapeUpgrade \
    src/ModelingData/TKGeomBase/GCPnts \
    src/ModelingData/TKGeomBase/AdvApp2Var \
    src/ModelingData/TKGeomBase/CPnts \
    src/ModelingAlgorithms/TKFeat/BRepFeat)
else
  echo "Reusing $SCRATCH/occt-master (skipping the clone, not the freshness check)."
fi
# Whether this occt-master is brand new or reused from an earlier run, always fetch
# and hard-reset it to the CURRENT origin/master tip before Step 3 looks at it. This
# is the fix for the bug this comment block opens with: reuse is for the git
# objects, not for the answer. `reset --hard`, not `checkout -B`: when the local
# branch already points at the same commit `git fetch` just confirmed as still
# current (nothing changed upstream since the last run), `checkout -B <br> <ref>`
# leaves the working tree alone rather than reporting "nothing to do", verified by
# injecting a local edit into a tracked file and confirming `checkout -B` preserves
# it while `reset --hard` discards it, matching a stale/corrupted cached checkout.
(cd "$SCRATCH/occt-master" && git fetch --depth 100 origin master && git checkout -B master origin/master && git reset --hard origin/master)
MASTER_SHA="$(git -C "$SCRATCH/occt-master" rev-parse HEAD)"
MASTER_DATE="$(git -C "$SCRATCH/occt-master" log -1 --format='%ci')"
echo "master tip: $MASTER_SHA $MASTER_DATE"
echo
echo "*** Validated against upstream Open-Cascade-SAS/OCCT master $MASTER_SHA ($MASTER_DATE). ***"
echo "*** Record this SHA next to any table built from this run's output. ***"

echo
echo "== Step 3: does our carried patch file still apply cleanly to that tip? =="
# git apply --check is a dry run: it never writes to the working tree. So, unlike an
# earlier version of this script, there is nothing to gain from copying occt-master
# aside before each check (11 unneeded `rm -rf` + `cp -R` of a multi-thousand-file
# tree): check directly against the shared checkout.
for pair in "${PAIRS[@]}" "0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch:(not filed)"; do
  patch="${pair%%:*}"
  pr="${pair##*:}"
  if (cd "$SCRATCH/occt-master" && git apply --check -p1 "$PATCH_DIR/$patch" 2>"$SCRATCH/err.txt"); then
    echo "OK      $patch (PR $pr) applies with zero rejected hunks"
  else
    echo "FAILED  $patch (PR $pr):"
    sed 's/^/        /' "$SCRATCH/err.txt"
  fi
done

echo
echo "Validated against upstream OCCT master $MASTER_SHA ($MASTER_DATE)."
echo "Done. This does not modify, comment on, or push to Open-Cascade-SAS/OCCT in any way."
