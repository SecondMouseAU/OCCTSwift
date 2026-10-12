#!/bin/bash
# fetch-attachments.sh <dir> : download the reproducer attachments of the upstream issues in this set into <dir>/<issue>/.
# The files are the reporters' (OCCT issues, FreeCAD reports), not ours, so they are fetched, never committed.
# Read-only against upstream: plain GETs of public attachment URLs.
set -e
OUT=${1:-attachments}
get() { # issue url
  mkdir -p "$OUT/$1"; curl -sSL -o "$OUT/$1/a.zip" "$2"
  (cd "$OUT/$1" && unzip -oq a.zip 2>/dev/null || true)
}
get 1568 https://github.com/user-attachments/files/32802272/fillet-opposite-edge-crash.zip
get 1619 https://github.com/user-attachments/files/33318719/fillet_uaf.zip
get 737  https://github.com/user-attachments/files/22557948/fillet_edge_blend_orientation.zip
get 1421 https://github.com/user-attachments/files/30617286/crash-failing-fillet.zip
get 1576 https://github.com/user-attachments/files/32854368/crash-on-chamfer-complex-shape.zip
get 1570 https://github.com/user-attachments/files/32807154/fillet-faulty-shape.zip
get 1569 https://github.com/user-attachments/files/32803500/fillet-faulty-shape.zip
get 1430 https://github.com/user-attachments/files/30743123/fillet-crashes-self-intersections.zip
get 1571 https://github.com/user-attachments/files/32809419/faulty-shape-fillet-rounded-cube.zip
get 1427 https://github.com/user-attachments/files/30632379/failing_fillet_on_tapered_surface.zip
get 736  https://github.com/user-attachments/files/22491322/vol.zip
get 900  https://github.com/user-attachments/files/24063931/straight-base-sweep-curve-opposite-dir.zip
get 899  https://github.com/user-attachments/files/24063846/curved-base-sweep-curve-opposite-dir.zip
get 694  https://github.com/user-attachments/files/22048930/straight-base-sweep-straight.zip
get 692  https://github.com/user-attachments/files/22047591/curved-base-sweep-curve-same-dir.zip
get 691  https://github.com/user-attachments/files/22047342/curved-base-sweep-straight.zip
get 1106 https://github.com/user-attachments/files/25471999/pacman.brep.zip
get 1107 https://github.com/user-attachments/files/25472105/wrench.brep.zip
# OCCT#1521: the gist's STEP file.
mkdir -p "$OUT/1521"
curl -sSL -o "$OUT/1521/defeaturing_corner_round.step" \
  https://gist.githubusercontent.com/GabrielJMS/6c722dc8e675c42211af777e342aeb25/raw/18e67cbe6576a214cd3828fe8af6e0e156cf52ab/defeaturing_corner_round.step
curl -sSL -o "$OUT/1521/repro.cxx" \
  https://gist.githubusercontent.com/GabrielJMS/6c722dc8e675c42211af777e342aeb25/raw/a159ba6262ca0081b5cbce0ea1c4de1e26f941ad/repro.cxx
# PR #1507 and PR #1533 carry their data files in the diff: pull them out of `gh pr diff` (read-only).
extract() { # pr path-in-diff out
  mkdir -p "$(dirname "$3")"
  gh pr diff "$1" -R Open-Cascade-SAS/OCCT | python3 -I -c '
import sys
want = sys.argv[1]
body, on = [], False
for line in sys.stdin:
    if line.startswith("diff --git "):
        on = line.rstrip().endswith(" b/" + want)
        started = False
        continue
    if on:
        if line.startswith("@@"):
            started = True
        elif started and line.startswith("+"):
            body.append(line[1:])
sys.stdout.write("".join(body))
' "$2" > "$3"
  [ -s "$3" ] || { echo "fetch-attachments: $2 not found in the diff of PR $1, $3 is empty" >&2; rm -f "$3"; return 1; }
}
extract 1507 data/occ/periodic_seam_fillet.brep "$OUT/1507/periodic_seam_fillet.brep"
extract 1533 src/ModelingAlgorithms/TKFillet/GTests/data/bug1177_corner.brep "$OUT/1533/bug1177_corner.brep"
