#!/usr/bin/env python3
"""#1399: the wrapped classes no lane of #807 claims, partitioned by what can actually check them.

#820's whole-surface reconciliation found 643 classes with real bridge presence sitting in no
lane's table, and filed the number. A number is not a lane. This derives the same set and splits it
by the only question that decides what work is left:

  machine-covered  a claim the attribution census parses names the class, so
                   census-doc-occt-attribution.py checks it on every run, whole-tree, and its
                   verdict is current rather than a one-off read. 479 of the 643.
  substrate        NCollection/TColStd/TColgp/TCollection containers and Standard_ scalars. A
                   container carries no capability to over- or under-document, the same
                   disposition #1045's fifteen substrate packages got.
  algorithm        real OCCT algorithm classes no parsed claim names. This is the lane's actual
                   reading list.

A fourth bucket, "ours", stood here for the classes this project was assumed to have invented:
BRepGraph, GeomEval, Geom2dEval. It was removed because the assumption was false, which is the
point of auditing against the headers rather than against a memory of them. All three are genuine
OCCT packages, present in the pinned kernel and on upstream master with their own GTests
(BRepGraph in TKBRep, GeomEval and Geom2dEval in TKG3d and TKG2d). They are ordinary algorithm
classes and are read as such: BRepGraph with the healing family, the evaluators with geometry.

Nothing here is hand-typed: the 643 comes from #820's own union by import, and the machine-covered
split from the census's own parser, so both move when the tree moves rather than when someone
remembers to edit a number.

Run from anywhere. Needs Libraries/OCCT.xcframework (pinned headers) and Libraries/occt-src, and
reports SKIPPED (exit 2) without them, as its siblings do.
"""

import argparse
import collections
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PHASE6 = os.path.join(REPO, "Scripts", "repro", "820-refman-coverage-whole-surface")

# The algorithm bucket, split into four reading families by package. Each family is one pass's
# worth of work and one agent's assignment; the split is by subsystem, not by size, so a reader
# holds one mental model at a time. A package named in no family lands in "foundation", which is
# checked by the self-test rather than left to drift.
FAMILIES = {
    "healing": ("ShapeFix", "ShapeAnalysis", "ShapeUpgrade", "ShapeCustom", "ShapeExtend",
                "BRepTools", "BRepLib", "BRepTopAdaptor", "BRepBndLib", "BndLib", "Bnd",
                "BRepGProp", "GProp", "BRepGraph"),
    "geometry": ("Geom", "Geom2d", "GeomEval", "Geom2dEval", "GeomConvert", "Geom2dConvert",
                 "GeomAbs", "GeomProjLib",
                 "GeomGridEval", "Geom2dGridEval", "Geom2dGcc", "GccEnt", "GccInt", "Convert",
                 "CPnts", "Adaptor3d", "Adaptor2d", "ElCLib", "ElSLib", "LProp", "Law",
                 "ProjLib", "FairCurve", "HelixGeom", "TColGeom", "gp"),
    "booleans": ("BOPAlgo", "BOPDS", "IntTools", "Intf", "IntAna", "IntAna2d", "IntRes2d",
                 "Extrema", "ExtremaPC", "Contap", "HatchGen", "Geom2dInt", "TopAbs",
                 "FilletSurf"),
    "foundation": ("math", "OSD", "Units", "UnitsAPI", "UnitsMethods", "Precision", "Standard",
                   "IFSelect", "XSControl", "RWStl", "SelectMgr", "PrsMgr", "Prs3d"),
}


def family_of(cls):
    package = cls.split("_")[0]
    for name, packages in FAMILIES.items():
        if package in packages:
            return name
    return "foundation"


SUBSTRATE_PREFIXES = ("NCollection_", "TColStd_", "TColgp_", "TCollection_", "TShort_",
                      "TColQuaternion_", "Standard_")


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def unlaned_classes():
    """#820's own 'wrapped, claimed by no lane' set, by import rather than by transcription."""
    sys.path.insert(0, PHASE6)
    union = _load(os.path.join(PHASE6, "whole_surface_union.py"), "whole_surface_union")
    substrate = _load(os.path.join(PHASE6, "substrate_audit.py"), "substrate_audit")
    source_rows, _ = union.source_lane_union()
    substrate_rows = substrate.all_rows(verbose=False)
    covered = {r["class"] for r in source_rows} | {r["class"] for r in substrate_rows}
    return sorted(union.residual_report(covered)["wrapped_unaudited"])


def claim_named_classes():
    """Every OCCT class named by a claim census-doc-occt-attribution.py parses."""
    census = _load(os.path.join(REPO, "Scripts", "census-doc-occt-attribution.py"), "cen")
    prefixes, bare = census.load_packages()
    claims = census.doc_claims(census.in_scope_docs()) + census.bridge_header_claims()
    named = set()
    for claim in claims:
        for token in census.class_tokens(claim.text, prefixes, bare, set()):
            named.add(token if isinstance(token, str) else token[0])
    return named


def bridge_text():
    """Every bridge source, including the private headers that live in src/ beside the .mm files.

    Reading only src/*.mm and include/*.h misses those, and the miss is not theoretical: it made
    this script report Prs3d as wrapped-by-nothing when the bridge calls Prs3d::GetDeflection from
    src/OCCTBridge_Internal.h. #820's own token cache reads both directories without filtering on
    extension, which is why its count was right and this one's was not.
    """
    parts = []
    for sub in ("src", "include"):
        directory = os.path.join(REPO, "Sources", "OCCTBridge", sub)
        for name in sorted(os.listdir(directory)):
            if name.endswith((".mm", ".h")):
                with open(os.path.join(directory, name), encoding="utf-8") as handle:
                    parts.append(handle.read())
    return "\n".join(parts)


def docs_text():
    """Every doc page except the changelog.

    docs/CHANGELOG.md is release history, not documentation of the current surface: a class named
    only in a v0.x entry is a record of what once happened, and counting it makes an undocumented
    class read as documented. The healing family's read found three such rows. #811's lane excluded
    docs/occtswift-wrapping-gaps.md from its own token cache for the same reason.
    """
    parts = []
    for root, _, files in os.walk(os.path.join(REPO, "docs")):
        for name in sorted(files):
            if name.endswith(".md") and name != "CHANGELOG.md":
                with open(os.path.join(root, name), encoding="utf-8", errors="ignore") as handle:
                    parts.append(handle.read())
    return "\n".join(parts)


def bucket_of(cls, machine_covered):
    if cls in machine_covered:
        return "machine-covered"
    if cls.startswith(SUBSTRATE_PREFIXES):
        return "substrate"
    return "algorithm"


def rows():
    classes = unlaned_classes()
    machine_covered = claim_named_classes()
    bridge, docs = bridge_text(), docs_text()
    out = []
    for cls in classes:
        pattern = re.compile(r"\b" + re.escape(cls) + r"\b")
        out.append({
            "class": cls,
            "package": cls.split("_")[0],
            "bucket": bucket_of(cls, machine_covered),
            "family": family_of(cls) if bucket_of(cls, machine_covered) == "algorithm" else "",
            "bridge_uses": len(pattern.findall(bridge)),
            "documented": bool(pattern.search(docs)),
        })
    return out


def family_report(name):
    """One family's reading list, the assignment for a single pass."""
    selected = sorted([r for r in rows() if r["family"] == name],
                      key=lambda r: (-r["bridge_uses"], r["class"]))
    print("#1399 reading family: %s (%d classes)" % (name, len(selected)))
    print("=" * 78)
    for row in selected:
        print("%-44s uses=%-4d docs=%s" %
              (row["class"], row["bridge_uses"], "yes" if row["documented"] else "no"))
    return 0


def report(verbose=False, bucket_filter=None):
    table = rows()
    counts = collections.Counter(r["bucket"] for r in table)
    print("#1399: wrapped classes claimed by no #807 lane")
    print("=" * 78)
    print("total: %d" % len(table))
    for name in ("machine-covered", "algorithm", "substrate"):
        selected = [r for r in table if r["bucket"] == name]
        documented = sum(1 for r in selected if r["documented"])
        print("  %-16s %4d   (%d named somewhere in docs/)" % (name, counts[name], documented))
    print()
    print("The reading list is the algorithm bucket: %d classes. machine-covered is checked on "
          "every run by\ncensus-doc-occt-attribution.py, which is why it is not re-read here."
          % counts["algorithm"])
    if verbose or bucket_filter:
        print()
        for name in ([bucket_filter] if bucket_filter else
                     ("algorithm", "substrate", "machine-covered")):
            selected = sorted([r for r in table if r["bucket"] == name],
                              key=lambda r: (-r["bridge_uses"], r["class"]))
            print("-- %s (%d)" % (name, len(selected)))
            for row in selected:
                print("   %-42s uses=%-4d docs=%s" %
                      (row["class"], row["bridge_uses"], "yes" if row["documented"] else "no"))
            print()
    return 0


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))

    table = rows()
    counts = collections.Counter(r["bucket"] for r in table)

    case("total-matches-phase-6", len(table) == len(unlaned_classes()),
         "%d rows" % len(table))
    case("every-class-has-a-bucket",
         all(r["bucket"] in ("machine-covered", "substrate", "algorithm") for r in table))
    case("buckets-partition", sum(counts.values()) == len(table))
    case("every-class-is-really-wrapped", all(r["bridge_uses"] > 0 for r in table),
         "min uses=%d" % min(r["bridge_uses"] for r in table))

    covered = claim_named_classes()
    case("machine-covered-is-not-empty", len(counts["machine-covered"] * [0]) > 0
         and counts["machine-covered"] > 100, "%d" % counts["machine-covered"])
    case("machine-covered-really-named-in-a-claim",
         all(r["class"] in covered for r in table if r["bucket"] == "machine-covered"))
    case("no-bucket-leaks-into-machine-covered",
         all(r["class"] not in covered for r in table if r["bucket"] != "machine-covered"))

    # A substrate class must not be classified by accident of its name alone: check one real one.
    case("substrate-rule-is-prefix-based",
         bucket_of("NCollection_Sequence", set()) == "substrate"
         and bucket_of("BRepLib", set()) == "algorithm"
         and bucket_of("BRepLib", {"BRepLib"}) == "machine-covered")
    # The packages the removed "ours" bucket claimed are OCCT's, so they must read as algorithm
    # classes and land in a family. Checked here because assuming otherwise is what put them in a
    # bucket of their own in the first place.
    case("packages-once-assumed-ours-are-occt-classes",
         all(bucket_of(c, set()) == "algorithm" and family_of(c) in FAMILIES
             for c in ("BRepGraph_Copy", "GeomEval_EllipsoidSurface", "Geom2dEval_SineWaveCurve")),
         "BRepGraph->%s, GeomEval->%s" % (family_of("BRepGraph_Copy"),
                                          family_of("GeomEval_EllipsoidSurface")))

    # The changelog must not count as documentation: a class named only in a v0.x entry is a
    # record of what once happened. Proven against a string that exists in docs/CHANGELOG.md and
    # nowhere else, rather than against the exclusion rule restating itself.
    changelog = open(os.path.join(REPO, "docs", "CHANGELOG.md"), encoding="utf-8").read()
    marker = "## Unreleased"
    case("changelog-does-not-count-as-documentation",
         marker in changelog and marker not in docs_text(),
         "marker present in the changelog, absent from the docs corpus")

    algorithm = [r for r in table if r["bucket"] == "algorithm"]
    case("every-algorithm-class-has-a-family",
         all(r["family"] in FAMILIES for r in algorithm))
    case("families-partition-the-algorithm-bucket",
         sum(len([r for r in algorithm if r["family"] == f]) for f in FAMILIES) == len(algorithm))
    case("no-family-is-empty-or-swallows-everything",
         all(0 < len([r for r in algorithm if r["family"] == f]) < len(algorithm) for f in FAMILIES),
         ", ".join("%s=%d" % (f, len([r for r in algorithm if r["family"] == f])) for f in FAMILIES))
    case("only-algorithm-rows-carry-a-family",
         all(r["family"] == "" for r in table if r["bucket"] != "algorithm"))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verbose", action="store_true", help="print every class, per bucket")
    parser.add_argument("--bucket", choices=("machine-covered", "substrate", "algorithm"),
                        help="print one bucket's classes only")
    parser.add_argument("--family", choices=tuple(FAMILIES),
                        help="print one reading family of the algorithm bucket")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    headers = os.path.join(REPO, "Libraries", "OCCT.xcframework")
    if not os.path.isdir(headers):
        print("SKIPPED: needs Libraries/OCCT.xcframework (pinned headers)")
        return 2
    if args.self_test:
        return self_test()
    if args.family:
        return family_report(args.family)
    return report(args.verbose, args.bucket)


if __name__ == "__main__":
    sys.exit(main())
