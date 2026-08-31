#!/usr/bin/env python3
"""Shared machinery for #820 (Phase 6 of #807): load every source lane's own committed census
script and re-run ITS OWN classification logic, rather than retyping any lane's verdicts.

This is the mechanism `whole_surface_union.py` is built on, split into its own file so the
self-test can exercise it directly. Two classify() shapes exist across the nine source-lane
scripts (#808, #809, #810, #811, #812, #813, #814, #982, #983), confirmed by reading each script
rather than assumed:

  TYPE A (#808, #809, #810): `classify(cls, wrapped, documented, gaps_text) -> (verdict, note)`,
  fed by the module's own `_is_wrapped(cls, bridge_files)` / `_is_documented(cls, doc_files)` /
  `_read(GAPS_FILE)`.

  TYPE B (#811, #812, #813, #814, #982, #983): `classify(cls, cache) -> (verdict, note, bridge,
  docs)`, fed by the module's own `build_cache()`.

Both shapes were established by reading each of the nine `refman_census.py` files' `classify`/
`build_cache`/`_is_wrapped`/`_is_documented` definitions directly. `verify_shapes()` (exposed via
`whole_surface_union.py --verify-shapes`) re-reads the nine files' own source text and reports if
the signature assumptions below stop matching, so a future edit to any of the nine that changes
its calling convention is caught here rather than silently mis-called (which would either crash
loudly, the safe direction, or -- worse -- silently return zero rows for that lane).
"""

from __future__ import annotations

import importlib.util
import os
import sys
import types

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
REPRO = os.path.join(ROOT, "Scripts", "repro")

# issue -> (directory under Scripts/repro, classify shape)
SOURCE_LANES: dict[str, tuple[str, str]] = {
    "808": ("808-refman-shape-topology", "A"),
    "809": ("809-refman-selection-construction", "A"),
    "810": ("810-refman-document-xde", "A"),
    "811": ("811-refman-coverage-features", "B"),
    "812": ("812-refman-coverage-drawing", "B"),
    "813": ("813-refman-coverage-export-interop", "B"),
    "814": ("814-refman-coverage-mesh-presentation-misc", "B"),
    "982": ("982-refman-coverage-ocaf-framework", "B"),
    "983": ("983-ocaf-persistence-drivers", "B"),
}


def load_module(issue: str) -> types.ModuleType:
    """Import one lane's `refman_census.py` as an isolated module object.

    A fresh `spec_from_file_location` per call (module name suffixed with the issue number) so
    nine modules that each define `ROOT`, `LANE_CLASSES`, `classify`, etc. at top level do not
    collide in `sys.modules`.
    """
    dirname, _shape = SOURCE_LANES[issue]
    path = os.path.join(REPRO, dirname, "refman_census.py")
    modname = f"_lane_{issue}_refman_census"
    spec = importlib.util.spec_from_file_location(modname, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"could not load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[modname] = mod
    spec.loader.exec_module(mod)
    return mod


def rows_for_lane(issue: str) -> list[dict]:
    """Every (family, class, verdict, note) row for one lane, using ONLY that lane's own code."""
    _dirname, shape = SOURCE_LANES[issue]
    mod = load_module(issue)
    rows: list[dict] = []

    if shape == "A":
        bridge_files = mod._bridge_files()
        doc_files = mod._doc_files()
        gaps_text = mod._read(mod.GAPS_FILE)
        for family, classes in mod.LANE_CLASSES.items():
            for cls in classes:
                wrapped, _wf = mod._is_wrapped(cls, bridge_files)
                documented, _df = mod._is_documented(cls, doc_files)
                verdict, note = mod.classify(cls, wrapped, documented, gaps_text)
                rows.append({"lane": issue, "family": family, "class": cls,
                             "verdict": verdict, "note": note})
    elif shape == "B":
        cache = mod.build_cache()
        for family, classes in mod.LANE_CLASSES.items():
            for cls in classes:
                verdict, note, _bridge, _docs = mod.classify(cls, cache)
                rows.append({"lane": issue, "family": family, "class": cls,
                             "verdict": verdict, "note": note})
    else:
        raise ValueError(f"unknown shape {shape!r} for lane {issue}")

    return rows


# ---------------------------------------------------------------------------------------------
# `--verify-shapes`: re-read each of the nine scripts' own source and confirm the classify/
# build_cache signatures this loader assumes are still what is actually on disk.
# ---------------------------------------------------------------------------------------------

_TYPE_A_CLASSIFY = "def classify(cls: str, wrapped: bool, documented: bool, gaps_text: str)"
_TYPE_B_CLASSIFY = "def classify(cls: str, cache)"


def verify_shapes() -> list[str]:
    problems = []
    for issue, (dirname, shape) in SOURCE_LANES.items():
        path = os.path.join(REPRO, dirname, "refman_census.py")
        with open(path) as fh:
            text = fh.read()
        if shape == "A":
            if _TYPE_A_CLASSIFY not in text:
                problems.append(f"#{issue}: expected Type A classify() signature not found")
            for fn in ("_is_wrapped(cls: str, bridge_files: list[str])",
                       "_is_documented(cls: str, doc_files: list[str])"):
                if f"def {fn}" not in text:
                    problems.append(f"#{issue}: expected Type A helper `{fn}` not found")
        elif shape == "B":
            if _TYPE_B_CLASSIFY not in text:
                problems.append(f"#{issue}: expected Type B classify() signature not found")
            if "def build_cache()" not in text:
                problems.append(f"#{issue}: expected Type B `build_cache()` not found")
        if "LANE_CLASSES: dict[str, list[str]]" not in text:
            problems.append(f"#{issue}: expected `LANE_CLASSES: dict[str, list[str]]` not found")
    return problems
