#!/usr/bin/env python3
"""Re-derive the fifteen #1045 "substrate" packages fresh from the pinned headers, rather than
trusting any of #1045's own three slightly-disagreeing header counts (its title says 337, its own
table sums to 331, and #811's earlier docstring said 337 using different per-package figures again).
Run standalone to print the fresh table; imported by `whole_surface_union.py` for the real audit.
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

SUBSTRATE_PACKAGES = [
    "BRepBlend", "Blend", "BlendFunc", "ChFiDS", "ChFiKPart", "BRepOffset", "Draft", "BiTgte",
    "MAT", "MAT2d", "Bisector", "BRepFill", "GeomFill", "AdvApp2Var", "AdvApprox",
]


def classes_for_package(pkg: str) -> list[str]:
    """Every `<pkg>.hxx` or `<pkg>_<Suffix>.hxx` in the pinned headers, class name = stem.

    The `(?!\\w)` after the bare-package alternative stops `MAT` from matching `MAT2d_Blend.hxx`
    and stops `Blend` from matching `BlendFunc_...` (both real prefix-collision risks in this
    exact package list): matching is anchored so `pkg` must be the WHOLE leading package token
    (up to the first `_` or end of stem), not merely a leading substring.
    """
    out = []
    for fn in os.listdir(HEADERS):
        if not fn.endswith(".hxx"):
            continue
        stem = fn[: -len(".hxx")]
        head = stem.split("_", 1)[0]
        if head == pkg:
            out.append(stem)
    return sorted(out)


def substrate_table() -> dict[str, list[str]]:
    if not os.path.isdir(HEADERS):
        return {}
    return {pkg: classes_for_package(pkg) for pkg in SUBSTRATE_PACKAGES}


if __name__ == "__main__":
    table = substrate_table()
    if not table:
        print(f"{HEADERS} not present, cannot derive")
        raise SystemExit(2)
    total = 0
    for pkg, classes in table.items():
        print(f"{pkg:14} {len(classes):4}")
        total += len(classes)
    print(f"{'TOTAL':14} {total:4}")
