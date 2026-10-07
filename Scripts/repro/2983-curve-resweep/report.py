#!/usr/bin/env python3
"""Compare two matrices written by run-injection-matrix.py, from the committed JSON alone.

usage: python3 Scripts/repro/2983-curve-resweep/report.py BEFORE_LABEL AFTER_LABEL

A switch is CAUGHT by a test file when at least one test of that file is red under it, or the
run hangs or crashes (a hang or a crash fails CI too). Switches are grouped into the families
below, each family attached to the test files that are about its subject; GROSS switches are a
total failure (nil, empty, false), SEMANTIC ones are wrong-but-plausible answers, from the
`# ---- GROSS|SEMANTIC` headers in `switches.txt`.
"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]

# family name -> (switch prefixes, test files whose job it is to catch them)
FAMILIES = [
    ("Issue554: ellipse / hyperbola / parabola construction",
     ("ELL_", "ARC_", "ARCP_", "HYP_", "PAR_"), ["Issue554Conic3dDegenerateTests"]),
    ("Issue554: in-place setters and getters",
     ("ELLM_", "ELLJ_", "HYPM_", "HYPJ_", "PARF_", "CIRR_", "GET_"), ["Issue554Conic3dDegenerateTests"]),
    ("Issue554: extrema", ("XE_", "XP_", "XL_"), ["Issue554Conic3dDegenerateTests"]),
    ("Issue554: three-point forms", ("GC3",), ["Issue554Conic3dDegenerateTests"]),
    ("Issue211: WireCurve / EdgeCurve primitives", ("W_", "E_"), ["Issue211WireCurveTests"]),
    ("Issue479: sampling bounds and count derivation", ("SMP_", "ADP_"),
     ["Issue479SampleCountBoundTests"]),
    ("Issue481 / 403 / 1399: law knot splitting", ("LAW_", "LAWSW_"),
     ["Issue481LawKnotSplittingTruncationTests", "Issue403LawKnotSplitParamsTests",
      "Issue1399LawKnotSplitFactoryReachTests"]),
    ("BSplineMutations", ("BS_",), ["BSplineMutationsTests"]),
    ("Issue485: continuity ordinals", ("CONT_",), ["Issue485Curve3DContinuityTests"]),
    ("OffsetCurveBasis", ("OFS_",), ["OffsetCurveBasisTests"]),
    ("Issue539: edge projection", ("PRJ_",), ["Issue539NearestPointOnCurveTests"]),
    ("Issue490: point fitting and continuity analysis", ("FIT_", "P2B_", "LA_"),
     ["Issue490ContinuityDecoderTests"]),
]


def file_of_struct():
    """struct name -> test file stem, from files.txt."""
    out = {}
    for f in (HERE / "files.txt").read_text().split():
        text = (ROOT / f).read_text() if (ROOT / f).exists() else ""
        stem = pathlib.Path(f).stem
        for m in re.findall(r"^struct (\w+)", text, re.M):
            out[m] = stem
    return out


def categories():
    cat, out = None, {}
    for line in (HERE / "switches.txt").read_text().splitlines():
        line = line.strip()
        if line.startswith("# ----"):
            cat = line.split()[2].rstrip(":")
        elif line and not line.startswith("#"):
            out[line] = cat
    return out


def main():
    before = json.loads((HERE / f"matrix-{sys.argv[1]}.json").read_text())
    after = json.loads((HERE / f"matrix-{sys.argv[2]}.json").read_text())
    cats = categories()
    struct_file = file_of_struct()

    def caught(matrix, switch, files):
        row = matrix["rows"][switch]
        if row.get("hang") or row.get("crash"):
            return True
        for t in row["red"]:
            struct = t.split(".")[0]
            if struct_file.get(struct, struct) in files or struct in files:
                return True
        return False

    print("| family | switches | caught by the old tests | caught by the new tests |")
    print("|---|---|---|---|")
    totals = [0, 0, 0]
    missing_after, missing_before = {}, {}
    for name, prefixes, files in FAMILIES:
        sws = [s for s in after["rows"] if s.startswith(prefixes)]
        # The old matrix may lack switches added later; a missing row counts as not caught.
        cb = [s for s in sws if s in before["rows"] and caught(before, s, files)]
        ca = [s for s in sws if caught(after, s, files)]
        missing_before[name] = [s for s in sws if s not in cb]
        missing_after[name] = [s for s in sws if s not in ca]
        totals = [totals[0] + len(sws), totals[1] + len(cb), totals[2] + len(ca)]
        print(f"| {name} | {len(sws)} | {len(cb)} | {len(ca)} |")
    print(f"| all | {totals[0]} | {totals[1]} | {totals[2]} |")
    print()
    for cat in ("GROSS", "SEMANTIC"):
        fam_sw = [s for s in after["rows"] if cats.get(s) == cat]
        cb = sum(1 for s in fam_sw if s in before["rows"] and any(
            caught(before, s, files) for _, p, files in FAMILIES if s.startswith(p)))
        ca = sum(1 for s in fam_sw if any(
            caught(after, s, files) for _, p, files in FAMILIES if s.startswith(p)))
        print(f"{cat:8s} {len(fam_sw):3d} switches: caught before {cb}, caught after {ca}")
    print()
    for name, _, _ in FAMILIES:
        if missing_after[name]:
            print(f"NOT caught by the new tests, {name}: {missing_after[name]}")
    print()
    for name, _, _ in FAMILIES:
        if missing_before[name]:
            print(f"not caught by the old tests, {name} ({len(missing_before[name])}): "
                  f"{missing_before[name]}")


if __name__ == "__main__":
    main()
