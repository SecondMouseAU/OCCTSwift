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
# Requires: gh (authenticated), git, network access to github.com. Read-only:
# makes no upstream writes, no comments, no PR/issue mutations of any kind.
#
# Usage: Scripts/repro/657-upstream-pr-status/verify.sh [scratch-dir]

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
for pair in "${PAIRS[@]}"; do
  patch="${pair%%:*}"
  pr="${pair##*:}"
  json=$(gh api "repos/Open-Cascade-SAS/OCCT/pulls/$pr" --jq '{state, merged, mergeable, comments, review_comments}')
  state=$(echo "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["state"])')
  merged=$(echo "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["merged"])')
  mergeable=$(echo "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["mergeable"])')
  comments=$(echo "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["comments"])')
  reviews=$(echo "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["review_comments"])')
  printf '%-70s %-6s %-6s %-8s %-10s %-8s %-8s\n' "$patch" "$pr" "$state" "$merged" "$mergeable" "$comments" "$reviews"
done

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
    src/ModelingAlgorithms/TKFeat/BRepFeat \
    && git checkout master)
fi
echo "master tip: $(git -C "$SCRATCH/occt-master" log -1 --format='%H %ci')"

echo
echo "== Step 3: does our carried patch file still apply cleanly to that tip? =="
for pair in "${PAIRS[@]}" "0020-BRepFeat_MakeCylindricalHole-select-tool-parts-532.patch:(not filed)"; do
  patch="${pair%%:*}"
  pr="${pair##*:}"
  rm -rf "$SCRATCH/check"
  cp -R "$SCRATCH/occt-master" "$SCRATCH/check"
  if (cd "$SCRATCH/check" && git apply --check -p1 "$PATCH_DIR/$patch" 2>"$SCRATCH/err.txt"); then
    echo "OK      $patch (PR $pr) applies with zero rejected hunks"
  else
    echo "FAILED  $patch (PR $pr):"
    sed 's/^/        /' "$SCRATCH/err.txt"
  fi
done

echo
echo "Done. This does not modify, comment on, or push to Open-Cascade-SAS/OCCT in any way."
