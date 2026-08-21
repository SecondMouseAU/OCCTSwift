#!/usr/bin/env python3
"""Draw the hand-adjudication sample for `occt-class-coverage.py` (#1001).

The detector prints a coverage ratio per class, but a ratio is not a finding anybody can act on.
The unit a re-sweep would act on is one NAME in its "not reached" list: "this is a public method of
the class and our bridge never calls it". That is what this samples, uniformly across the sixteen
classes Pass 4a reported, with a fixed seed so the sample is redrawable.

A row is FALSE when either half of that claim fails:

  * the name is not a public method of the class at all (a parameter type, a nested type, an enum
    value, a macro, a protected or private member: denominator pollution), or
  * the bridge does reach it and the matcher missed the call.

THE COMMITTED SAMPLE IS NOT REDRAWN BY RUNNING THIS TODAY, AND THAT IS NOT A BUG
-------------------------------------------------------------------------------
The forty rows in `adjudicated-sample.tsv` were drawn from the population BEFORE #1001 fixed the
detector's four denominator-inflating causes: 253 rows then, 207 now. The seed is unchanged, so the
same seed over a smaller population yields different rows. Redrawing is for taking a NEW sample;
re-scoring the committed one against any later version of the detector is `score_sample.py`'s job,
and that is the comparison that stays valid.

    python3 Scripts/repro/1001-detector-fp-rates/sample_class_coverage.py            # draw
    python3 Scripts/repro/1001-detector-fp-rates/sample_class_coverage.py --context  # with header lines
"""

import importlib.util
import io
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DETECTOR = os.path.join(ROOT, "Scripts", "repro", "385-coverage-sample", "occt-class-coverage.py")
HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

# The sixteen classes Pass 4a sampled, in its own README's order.
CLASSES = [
    "XCAFDimTolObjects_DatumObject",
    "XCAFDimTolObjects_DimensionObject",
    "XCAFDimTolObjects_GeomToleranceObject",
    "Draft_FaceInfo",
    "Draft_VertexInfo",
    "Draft_EdgeInfo",
    "Plate_Plate",
    "GeomPlate_BuildPlateSurface",
    "BRepFeat_Gluer",
    "BRepFeat_MakeDPrism",
    "XCAFDoc_DimTolTool",
    "BRepFeat_SplitShape",
    "BRepOffsetAPI_ThruSections",
    "GeomPlate_BuildAveragePlane",
    "ShapeFix_Face",
    "BRepFeat_MakeCylindricalHole",
]

SAMPLE_SIZE = 40
SEED = 1001


def load_detector():
    """Import the detector as a module.

    It runs its report at import time, so stdout is redirected for the duration; otherwise its
    empty table header leaks into every caller's output.
    """
    spec = importlib.util.spec_from_file_location("_coverage", DETECTOR)
    mod = importlib.util.module_from_spec(spec)
    saved_argv, saved_out = sys.argv, sys.stdout
    sys.argv = ["occt-class-coverage.py"]
    sys.stdout = io.StringIO()
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv, sys.stdout = saved_argv, saved_out
    return mod


def main(argv):
    if not os.path.isdir(HEADERS):
        print("SKIPPED: Libraries/OCCT.xcframework is absent, so the header half cannot run.")
        return 0
    det = load_detector()
    bridge_files = [f for f in os.listdir(det.BR) if f.endswith(".mm") or f.endswith(".h")]

    population = []
    for cls in CLASSES:
        pub = det.occt_public_methods(cls)
        if pub is None:
            continue
        used = det.bridge_calls(cls, bridge_files)
        for name in sorted(pub - used):
            population.append((cls, name))

    rng = random.Random(SEED)
    sample = rng.sample(population, min(SAMPLE_SIZE, len(population)))
    sample.sort()

    print(f"# population {len(population)} (class, unreached method) rows over "
          f"{len(CLASSES)} classes")
    print(f"# sample {len(sample)}, seed {SEED}\n")
    want_context = "--context" in argv
    for cls, name in sample:
        print(f"{cls}\t{name}")
        if want_context:
            path = os.path.join(HEADERS, cls + ".hxx")
            with open(path, errors="ignore") as fh:
                for i, line in enumerate(fh, 1):
                    if name in line:
                        print(f"    {cls}.hxx:{i}: {line.rstrip()}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
