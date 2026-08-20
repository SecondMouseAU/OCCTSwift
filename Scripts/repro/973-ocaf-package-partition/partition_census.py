#!/usr/bin/env python3
"""Issue #973 (part of #807): which pass of the refman-coverage epic owns each OCAF-family package.

This is a PARTITION census, not a coverage audit. It answers one question for every OCAF-family
package in the pinned kernel: **which sub-issue of #807 owns it**, and if the answer is "nobody",
that is a defect this script exits 1 on. The per-class `ok`/`under`/`over`/`deliberate, recorded`
audit of each package is the owning pass's own job, and each owning pass lands its own artifact.

WHY THIS EXISTS. This programme's characteristic defect is a file or package that belongs to no
pass. #382 left three Wire files unclaimed for weeks, #384 left seven assembly files unclaimed
until challenged, #377 records three files holding the repo's highest-scoring duplication that
belong to no pass at all, and #810's census found six packages in its own lane that no sub-issue
named. #973 is that defect at package scale, and this file is the standing check that it does not
come back: a kernel bump that adds an OCAF package, or a `## Lane` edit that drops one, turns this
red instead of arriving unannounced at Phase 6.

WHAT "OCAF FAMILY" MEANS HERE, derived rather than chosen. Four rules, each mechanical, and each
recorded as the package's `tier` in the table below:

  `module`        the package is in OCCT's own `ApplicationFramework` module. No judgement at all:
                  this is the source tree's own grouping, `src/ApplicationFramework/TK*/<package>/`.
                  43 packages, 509 headers.
  `ocaf-only`     the package is outside that module, and every OCCT package that references its
                  symbols is an OCAF package. Measured over `Libraries/occt-src` with
                  `--reverify-family`, not guessed from the name. `Plugin_` is the clean case:
                  thirteen consumers, zero outside OCAF.
  `xde`           the XDE attribute layer in `DataExchange/TKXCAF`. Outside the module because it
                  depends on `TopoDS_`, and it is the document API Pass 3 already audits.
  `prefix-stray`  NOT OCAF. In #973's original table only because it matches a `Bin*`, `Xml*` or
                  `Std*` prefix. `StdFail_` is the kernel's exception vocabulary, `StdPrs_` and
                  `StdSelect_` are `Visualization/TKV3d`, `BinTools_` is BREP serialisation in
                  `ModelingData/TKBRep`. They are kept in the table rather than deleted from it
                  because they were, in fact, owned by no pass, which is the finding; deleting them
                  would put them straight back into the state this issue exists to end.

WHAT #973's OWN TABLE SAID, and how this differs. #973's title and prose say "44 packages, ~460
headers"; the table in its body lists 43 rows summing to 410. Both were re-derived here rather than
inherited, per `okf/policies/measure-dont-assume.md`, and all three numbers reconcile:

  * The 43 rows' per-package header counts are all correct against the pinned headers.
  * The table is missing five packages, 49 headers: `LDOM` (24), `ShapePersistent` (13), `UTL` (1),
    `FSD` (7) and `Plugin` (4). The first three are `ApplicationFramework` packages a prefix-shaped
    derivation cannot see, because their names do not begin `Bin`, `Xml`, `Std`, `T` or `App`. The
    last two are `FoundationClasses/TKernel` and were reached here by the consumer measurement, not
    by a prefix.
  * 410 + 49 = 459, which is the "~460" the prose gives. So the prose total was right and the table
    it sits above was the incomplete artifact, the reverse of the usual direction.
  * 43 + 5 = 48 packages, so "44" was wrong against both its own table and the kernel.

`--reconcile-973` prints that comparison from the baked table rather than from this docstring.

ONE LIMITATION OF `--verify-lanes`, stated rather than left to be found. It checks the FORWARD
direction only: every package this table assigns to issue N must be named in N's `## Lane`. It does
not fail when a second issue also names the package, because a lane section legitimately names its
neighbours (#982's lane explains `AppStd_Application` in terms of `TDocStd_Application`, which is
#810's). Extra namers are reported, not failed, and a genuine double claim is visible in that
report but is not caught automatically.

Run from anywhere; paths derive from this file's location, not the cwd:

    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --pass 983
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --why Resource
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --reconcile-973
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --global
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --verify-lanes
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --reverify-family
    python3 Scripts/repro/973-ocaf-package-partition/partition_census.py --self-test

Exit codes: 0 clean, 1 a defect (a family package with no owner, a header count that has drifted, a
lane that no longer names what it owns, a self-test failure), 2 the environment cannot answer (no
`Libraries/OCCT.xcframework`, no `Libraries/occt-src`, no `gh`). 2 is deliberately distinct from 1:
a missing xcframework is not a finding about the tree.
"""

from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")
OCCT_SRC = os.path.join(ROOT, "Libraries", "occt-src", "src")
BRIDGE_DIRS = [os.path.join(ROOT, "Sources", "OCCTBridge", "src"),
               os.path.join(ROOT, "Sources", "OCCTBridge", "include")]
DOCS_DIR = os.path.join(ROOT, "docs")
REPO = "SecondMouseAU/OCCTSwift"

# ------------------------------------------------------------------------------------------------
# Header-to-package mapping.
#
# A shipped header's package is the part of its basename before the first `_`, with four exceptions
# tree-wide, three of which are in this family. `--reverify-family` re-derives this list from
# `Libraries/occt-src` and fails if it has grown, which is the only way to notice a fifth.
# ------------------------------------------------------------------------------------------------

HEADER_PACKAGE_OVERRIDES = {
    "LDOMBasicString.hxx": "LDOM",
    "LDOMParser.hxx": "LDOM",
    "LDOMString.hxx": "LDOM",
    "step.tab.hxx": "StepFile",   # not in this family; carried so --reverify-family stays exact
}

# ------------------------------------------------------------------------------------------------
# The partition. package -> (headers, module, toolkit, tier, owning issue).
#
# Derived 2026-08-20 against the pinned kernel (OCCT 8.0.1 plus the carried patches). Header counts
# are re-measured on every run and a mismatch exits 1; they are baked so that a drift is a failure
# rather than a silently different answer.
# ------------------------------------------------------------------------------------------------

FAMILY: dict[str, tuple[int, str, str, str, str]] = {
    "AppStd": (1, "ApplicationFramework", "TKCAF", "module", "982"),
    "AppStdL": (1, "ApplicationFramework", "TKLCAF", "module", "982"),
    "BinDrivers": (4, "ApplicationFramework", "TKBin", "module", "983"),
    "BinLDrivers": (6, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinMDF": (9, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinMDataStd": (23, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinMDataXtd": (7, "ApplicationFramework", "TKBin", "module", "983"),
    "BinMDocStd": (2, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinMFunction": (4, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinMNaming": (3, "ApplicationFramework", "TKBin", "module", "983"),
    "BinMXCAFDoc": (15, "DataExchange", "TKBinXCAF", "ocaf-only", "983"),
    "BinObjMgt": (10, "ApplicationFramework", "TKBinL", "module", "983"),
    "BinTObjDrivers": (8, "ApplicationFramework", "TKBinTObj", "module", "983"),
    "BinTools": (14, "ModelingData", "TKBRep", "prefix-stray", "813"),
    "BinXCAFDrivers": (3, "DataExchange", "TKBinXCAF", "ocaf-only", "983"),
    "CDF": (12, "ApplicationFramework", "TKCDF", "module", "810"),
    "CDM": (11, "ApplicationFramework", "TKCDF", "module", "810"),
    "FSD": (7, "FoundationClasses", "TKernel", "ocaf-only", "983"),
    "LDOM": (24, "ApplicationFramework", "TKCDF", "module", "983"),
    "PCDM": (19, "ApplicationFramework", "TKCDF", "module", "983"),
    "Plugin": (4, "FoundationClasses", "TKernel", "ocaf-only", "983"),
    "Resource": (8, "FoundationClasses", "TKernel", "prefix-stray", "813"),
    "ShapePersistent": (13, "ApplicationFramework", "TKStd", "module", "983"),
    "StdDrivers": (2, "ApplicationFramework", "TKStd", "module", "983"),
    "StdFail": (5, "FoundationClasses", "TKernel", "prefix-stray", "820"),
    "StdLDrivers": (2, "ApplicationFramework", "TKStdL", "module", "983"),
    "StdLPersistent": (16, "ApplicationFramework", "TKStdL", "module", "983"),
    "StdObjMgt": (6, "ApplicationFramework", "TKStdL", "module", "983"),
    "StdObject": (7, "ApplicationFramework", "TKStd", "module", "983"),
    "StdPersistent": (9, "ApplicationFramework", "TKStd", "module", "983"),
    "StdPrs": (28, "Visualization", "TKV3d", "prefix-stray", "814"),
    "StdSelect": (11, "Visualization", "TKV3d", "prefix-stray", "814"),
    "StdStorage": (11, "ApplicationFramework", "TKStd", "module", "983"),
    "Storage": (36, "FoundationClasses", "TKernel", "ocaf-only", "983"),
    "TDF": (51, "ApplicationFramework", "TKLCAF", "module", "810"),
    "TDataStd": (53, "ApplicationFramework", "TKLCAF", "module", "810"),
    "TDataXtd": (17, "ApplicationFramework", "TKCAF", "module", "810"),
    "TDocStd": (19, "ApplicationFramework", "TKLCAF", "module", "810"),
    "TFunction": (14, "ApplicationFramework", "TKLCAF", "module", "982"),
    "TNaming": (36, "ApplicationFramework", "TKCAF", "module", "810"),
    "TObj": (23, "ApplicationFramework", "TKTObj", "module", "982"),
    "TPrsStd": (12, "ApplicationFramework", "TKVCAF", "module", "982"),
    "UTL": (1, "ApplicationFramework", "TKCDF", "module", "983"),
    "XCAFApp": (1, "DataExchange", "TKXCAF", "xde", "810"),
    "XCAFDimTolObjects": (23, "DataExchange", "TKXCAF", "xde", "810"),
    "XCAFDoc": (41, "DataExchange", "TKXCAF", "xde", "810"),
    "XCAFNoteObjects": (1, "DataExchange", "TKXCAF", "xde", "810"),
    "XCAFPrs": (11, "DataExchange", "TKXCAF", "xde", "810"),
    "XCAFView": (2, "DataExchange", "TKXCAF", "xde", "810"),
    "XmlDrivers": (3, "ApplicationFramework", "TKXml", "module", "983"),
    "XmlLDrivers": (5, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlMDF": (8, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlMDataStd": (23, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlMDataXtd": (7, "ApplicationFramework", "TKXml", "module", "983"),
    "XmlMDocStd": (2, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlMFunction": (4, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlMNaming": (4, "ApplicationFramework", "TKXml", "module", "983"),
    "XmlMXCAFDoc": (15, "DataExchange", "TKXmlXCAF", "ocaf-only", "983"),
    "XmlObjMgt": (9, "ApplicationFramework", "TKXmlL", "module", "983"),
    "XmlTObjDrivers": (8, "ApplicationFramework", "TKXmlTObj", "module", "983"),
    "XmlXCAFDrivers": (3, "DataExchange", "TKXmlXCAF", "ocaf-only", "983"),
}

OWNERS = {
    "810": "Pass 3, Document/XDE assembly",
    "813": "Pass 4c, Export and interop",
    "814": "Pass 4d, Mesh plus presentation",
    "820": "Phase 6 only, no lane pass",
    "982": "Pass 3b, OCAF framework layer",
    "983": "Pass 3c, OCAF persistence and format drivers",
}

# Reasoning is recorded per GROUP, because these cluster naturally and 61 per-package paragraphs
# would be 61 places for the reason to drift from the assignment. Packages whose reason is NOT the
# group's are in PACKAGE_REASONS below, and every one of those was measured rather than reasoned.
GROUP_REASONS = {
    ("810", "module"):
        "The OCAF document API itself. Already Pass 3's lane and audited by its census.",
    ("810", "xde"):
        "The XDE attribute layer and its payload types. Pass 3's census claimed all six after "
        "measuring that no sub-issue named them; #973 corrected #810's `## Lane` prose to say so, "
        "so the issue and its artifact now describe the same scope.",
    ("982", "module"):
        "OCAF proper, above the document API and below the persistence drivers: the function and "
        "regeneration mechanism, the presentation attributes, the TObj object model, and the two "
        "standard application subclasses. The closest siblings of Pass 3's lane, the most wrapped "
        "of the unowned set (9 classes), and the ones a CAD consumer notices missing. Folding them "
        "into #810 was rejected: that pass's audit is complete and its PR open, so anything added "
        "now would be inside a finished lane and audited by nothing.",
    ("983", "module"):
        "The OCAF persistence layer: one driver package per attribute family per format, plus the "
        "persistent object model, the schema and stream layer, and the XML DOM the Xml drivers "
        "read through. Eight classes of 342 headers are reached from the bridge, all of them "
        "format-registration entry points. Folding into #813 (#973's own candidate) was rejected "
        "on measurement: after this partition #813's lane is 192 headers and this is 342, so "
        "folding would take Pass 4c to 534, nearly three times its size and 45% larger than the "
        "largest pass in the epic (Pass 4d at 368).",
    ("983", "ocaf-only"):
        "Outside OCCT's ApplicationFramework module, and in this lane because every OCCT package "
        "that references their symbols is an OCAF package, or because they are OCAF attribute "
        "drivers separated from their siblings only by an XCAFDoc dependency. Measured with "
        "--reverify-family, not inferred from the name.",
    ("813", "prefix-stray"):
        "Not OCAF at all. Both are file and configuration surface wrapped in "
        "Sources/OCCTBridge/src/OCCTBridge_IO.mm, which is Pass 4c's own bridge file, and both "
        "reached #973's table only by matching a Bin*/Std* prefix.",
    ("814", "prefix-stray"):
        "Not OCAF at all. Both are Visualization/TKV3d, the same toolkit as the AIS_ already in "
        "Pass 4d's lane, and both reached #973's table only by matching a Std* prefix.",
    ("820", "prefix-stray"):
        "Belongs to no lane pass, on purpose. See PACKAGE_REASONS.",
}

PACKAGE_REASONS = {
    "Storage":
        "The schema and stream layer StdStorage_ and PCDM_ are defined in terms of. Fifteen OCCT "
        "packages reference it and every one is OCAF except FSD_ (its own driver), BinTools_ and "
        "Standard_.",
    "FSD":
        "The physical file drivers Storage_, PCDM_ and StdStorage_ open. Also reached by RWStl_, "
        "RWGltf_ and BinTools_, which are Pass 4c's, so this is a genuine overlap rather than a "
        "clean fit; filed with the persistence lane because that is what it is defined against, "
        "and recorded here so the overlap is not rediscovered as a finding.",
    "Plugin":
        "The driver loader CDF_Application and every *Drivers package calls. Thirteen consumers, "
        "zero outside OCAF: the cleanest ocaf-only case in the family.",
    "LDOM":
        "OCCT's own XML DOM, which the Xml* drivers read and write through. Missing from #973's "
        "table because a prefix-shaped derivation cannot see it, and 3 of its 24 headers "
        "(LDOMParser, LDOMString, LDOMBasicString) do not even carry the package underscore.",
    "UTL":
        "One header, a CDF utility. Missing from #973's table for the same reason as LDOM.",
    "ShapePersistent":
        "The persistent-shape schema StdStorage_ saves a TopoDS_Shape through. Missing from "
        "#973's table for the same reason as LDOM.",
    "BinTools":
        "The binary BREP reader and writer, wrapped as BinTools_ShapeReader/ShapeWriter in "
        "OCCTBridge_IO.mm. OCCT files it under ModelingData/TKBRep next to BRep_ and TopoDS_, so "
        "a reading by toolkit would put it in Pass 2a; its consumers outside OCAF are DEBREP_ (the "
        "BREP format provider) and BRepFill_, which is export surface, so it is Pass 4c's.",
    "Resource":
        "#973 guessed this belonged to Phase 6 because OCAF's format registration uses it. "
        "Measured, it has a public ResourceManager Swift type, thirteen operations in "
        "docs/API_REFERENCE.md, a bridge home in OCCTBridge_IO.mm, and twelve of its seventeen "
        "OCCT consumers outside OCAF are DESTEP_, DEIGES_, STEPControl_, STEPCAFControl_, "
        "StepData_, XSAlgo_, ShapeProcess_ and Units_. Resource_Unicode::SetFormat is the STEP and "
        "IGES text encoding switch specifically. So it is Pass 4c's, not Phase 6's.",
    "StdPrs":
        "The presentation builder family AIS_ and PrsDim_ present through. Nothing in it is "
        "wrapped and the string StdPrs appears nowhere under docs/, so all 28 classes are an "
        "`under` until Pass 4d records a reason.",
    "StdSelect":
        "The selection decomposition. StdSelect_BRepSelectionTool::Load and StdSelect_BRepOwner "
        "are called in OCCTBridge_Visualization.mm and named in docs/reference/Selection.md. The "
        "one boundary in this partition where two passes have a claim, since the Selection Swift "
        "surface is Pass 2b's (#809) subject; filed with Pass 4d because the OCCT classes are "
        "TKV3d and the bridge site is the AIS one, while #809's OCCT lane is geometry.",
    "StdFail":
        "No lane pass owns it, and that is the recorded answer rather than a gap. StdFail_ is the "
        "kernel's exception vocabulary (StdFail_NotDone and four siblings). It is referenced by 56 "
        "OCCT packages, every one of them outside OCAF and spread across every lane in the epic, "
        "so no lane has a better claim than any other. Nothing wraps it as a capability: it is "
        "what the bridge catches, not what it calls, and the only claims docs/ makes about it are "
        "convention statements in docs/naming-conventions.md. Phase 6 (#820) sees the whole "
        "surface by construction and will reach it there.",
}

# #973's own table, transcribed from the issue body on 2026-08-20, for --reconcile-973. Its
# per-package header counts were all correct; what it was missing was five whole packages.
ISSUE_973_TABLE = {
    "AppStd": 1, "AppStdL": 1, "BinDrivers": 4, "BinLDrivers": 6, "BinMDF": 9, "BinMDataStd": 23,
    "BinMDataXtd": 7, "BinMDocStd": 2, "BinMFunction": 4, "BinMNaming": 3, "BinMXCAFDoc": 15,
    "BinObjMgt": 10, "BinTObjDrivers": 8, "BinTools": 14, "BinXCAFDrivers": 3, "PCDM": 19,
    "Resource": 8, "StdDrivers": 2, "StdFail": 5, "StdLDrivers": 2, "StdLPersistent": 16,
    "StdObjMgt": 6, "StdObject": 7, "StdPersistent": 9, "StdPrs": 28, "StdSelect": 11,
    "StdStorage": 11, "Storage": 36, "TFunction": 14, "TObj": 23, "TPrsStd": 12, "XmlDrivers": 3,
    "XmlLDrivers": 5, "XmlMDF": 8, "XmlMDataStd": 23, "XmlMDataXtd": 7, "XmlMDocStd": 2,
    "XmlMFunction": 4, "XmlMNaming": 4, "XmlMXCAFDoc": 15, "XmlObjMgt": 9, "XmlTObjDrivers": 8,
    "XmlXCAFDrivers": 3,
}
ISSUE_973_PROSE_PACKAGES = 44
ISSUE_973_PROSE_HEADERS = 460

# Every sub-issue of #807 that declares an OCCT lane, for --global. The four test passes (#815 to
# #818) and Phase 6 (#820) declare no OCCT prefixes, so they cannot own a package here.
LANE_ISSUES = ["808", "809", "810", "811", "812", "813", "814", "982", "983"]

# The plain run's guard against a package silently leaving the table, which is the failure this
# whole issue is about and the one `--reverify-family` cannot catch without `Libraries/occt-src`.
# Any shipped package matching one of these prefixes must be either in FAMILY or in
# PREFIX_SWEEP_EXCLUSIONS with a reason. The prefixes are deliberately loose: `Std` is what swept
# `StdFail_`, `StdPrs_` and `StdSelect_` into #973's own table, and a loose prefix that forces a
# decision is exactly what this guard wants. Measured against the pinned kernel on 2026-08-20, the
# exclusion table is EMPTY, so every prefix match today is a family member.
OCAF_PREFIXES = ("Bin", "Xml", "Std", "TDF", "TDoc", "TData", "TNaming", "TFunction", "TObj",
                 "TPrsStd", "AppStd", "XCAF", "PCDM", "CDF", "CDM", "LDOM", "Storage", "FSD",
                 "Plugin", "UTL", "ShapePersistent")
PREFIX_SWEEP_EXCLUSIONS: dict[str, str] = {}


# ------------------------------------------------------------------------------------------------
# Measurement
# ------------------------------------------------------------------------------------------------

def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def header_package(filename: str) -> str:
    """The package a shipped header belongs to.

    The underscore split, plus HEADER_PACKAGE_OVERRIDES for the four headers tree-wide whose
    filename does not carry their package name. Three of those four are LDOM's, and getting them
    wrong is the whole difference between LDOM being 21 headers and 24.
    """
    if filename in HEADER_PACKAGE_OVERRIDES:
        return HEADER_PACKAGE_OVERRIDES[filename]
    return os.path.splitext(filename)[0].split("_", 1)[0]


def shipped_packages() -> dict[str, int]:
    counts: collections.Counter[str] = collections.Counter()
    for name in os.listdir(OCCT_HEADERS):
        if name.endswith(".hxx"):
            counts[header_package(name)] += 1
    return dict(counts)


def _is_comment(line: str) -> bool:
    s = line.strip()
    return s.startswith("//") or s.startswith("*") or s.startswith("/*")


def bridge_text() -> str:
    """Bridge lines that are neither a bare `#include` nor a comment.

    Same rule as #808's and #810's censuses, and it matters here for the same reason: this bridge
    `#include`s `BinDrivers.hxx` and friends, and counting an include as a use would report the
    whole persistence lane as reached.
    """
    out = []
    for d in BRIDGE_DIRS:
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if not (f.endswith(".mm") or f.endswith(".h")):
                continue
            for line in _read(os.path.join(d, f)).splitlines():
                if line.strip().startswith("#include") or _is_comment(line):
                    continue
                out.append(line)
    return "\n".join(out)


def docs_text() -> str:
    """Every markdown page under docs/ except CHANGELOG.md.

    CHANGELOG.md is excluded for the reason #810's census gives: it records what a past release
    changed, which is not a claim about the current tree.
    """
    out = []
    for dirpath, _dirnames, filenames in os.walk(DOCS_DIR):
        for fn in filenames:
            if fn.endswith(".md") and fn != "CHANGELOG.md":
                out.append(_read(os.path.join(dirpath, fn)))
    return "\n".join(out)


def package_classes(pkg: str) -> list[str]:
    return sorted(os.path.splitext(n)[0] for n in os.listdir(OCCT_HEADERS)
                  if n.endswith(".hxx") and header_package(n) == pkg)


def named_classes(classes: list[str], haystack: str) -> list[str]:
    return [c for c in classes if re.search(r"\b" + re.escape(c) + r"\b", haystack)]


NAMED_IN_LANE = re.compile(r"`[^`\n]*")


def lane_names_package(lane_text: str, pkg: str) -> bool:
    """Does a `## Lane` section name this package, inside backticks?

    Backticks are required because plain prose mentioning a word is not a lane declaration, and
    every lane in #807 writes its prefixes as code. The trailing character must be `_`, `*` or a
    non-word character, so `BRepMesh_*` does not claim `BRepMeshData`.
    """
    return re.search(r"`[^`\n]*\b" + re.escape(pkg) + r"(?:_|\*|\b)", lane_text) is not None


def gh_issue_body(number: str) -> str | None:
    try:
        proc = subprocess.run(["gh", "issue", "view", number, "--repo", REPO,
                               "--json", "body"],
                              capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)["body"]
    except (ValueError, KeyError):
        return None


def lane_section(body: str) -> str:
    m = re.search(r"^## Lane\s*\n(.*?)(?=\n## |\Z)", body, re.S | re.M)
    return m.group(1) if m else ""


# ------------------------------------------------------------------------------------------------
# Reports
# ------------------------------------------------------------------------------------------------

def reason_for(pkg: str) -> str:
    if pkg in PACKAGE_REASONS:
        return PACKAGE_REASONS[pkg]
    _n, _mod, _tk, tier, owner = FAMILY[pkg]
    return GROUP_REASONS.get((owner, tier), "(no reason recorded, which is itself a defect)")


def require_headers() -> int | None:
    if os.path.isdir(OCCT_HEADERS):
        return None
    print("ENVIRONMENT: Libraries/OCCT.xcframework/macos-arm64/Headers is not present.")
    print("  This census measures the pinned kernel's own headers, which CLAUDE.md names as the")
    print("  source of truth for version-sensitive detail, so it cannot run in CI or in a fresh")
    print("  clone. Reported rather than passed silently. Exit 2 is not a finding about the tree.")
    return 2


def main_report(verbose: bool) -> int:
    rc = require_headers()
    if rc is not None:
        return rc

    shipped = shipped_packages()
    bridge = bridge_text()
    docs = docs_text()

    failures: list[str] = []
    rows = []
    for pkg in sorted(FAMILY):
        expected, module, toolkit, tier, owner = FAMILY[pkg]
        actual = shipped.get(pkg, 0)
        if actual != expected:
            failures.append(f"{pkg}: baked {expected} headers, pinned kernel has {actual}")
        classes = package_classes(pkg)
        rows.append({
            "pkg": pkg, "headers": actual, "module": module, "toolkit": toolkit, "tier": tier,
            "owner": owner,
            "wrapped": named_classes(classes, bridge),
            "documented": named_classes(classes, docs),
        })

    print(f"{'package':20} {'hxx':>4} {'module/toolkit':38} {'tier':13} {'owner':6} "
          f"{'wrapped':>7} {'doc''d':>5}")
    print("-" * 104)
    for r in rows:
        print(f"{r['pkg']:20} {r['headers']:4} "
              f"{r['module'] + '/' + r['toolkit']:38} {r['tier']:13} #{r['owner']:5} "
              f"{len(r['wrapped']):7} {len(r['documented']):5}")
        if verbose and r["wrapped"]:
            print(f"{'':20}   wrapped: {', '.join(r['wrapped'])}")

    print()
    by_owner: collections.Counter[str] = collections.Counter()
    hdr_by_owner: collections.Counter[str] = collections.Counter()
    wrapped_by_owner: collections.Counter[str] = collections.Counter()
    for r in rows:
        by_owner[r["owner"]] += 1
        hdr_by_owner[r["owner"]] += r["headers"]
        wrapped_by_owner[r["owner"]] += len(r["wrapped"])
    print(f"OCAF family: {len(rows)} packages, {sum(r['headers'] for r in rows)} headers, "
          f"{sum(len(r['wrapped']) for r in rows)} classes reached from the bridge")
    for owner in sorted(by_owner):
        print(f"  #{owner}  {OWNERS[owner]:46} {by_owner[owner]:3} packages "
              f"{hdr_by_owner[owner]:4} headers {wrapped_by_owner[owner]:3} wrapped")

    print()
    print("OWNED BY NO PASS")
    unowned = [r for r in rows if r["owner"] not in OWNERS]
    if unowned:
        for r in unowned:
            print(f"  {r['pkg']}")
        failures.append(f"{len(unowned)} family packages have no owner")
    else:
        print("  none. Every OCAF-family package in the pinned kernel is assigned.")
        print("  #973 found 48 packages and 459 headers here; the partition is what emptied it,")
        print("  and this section is printed on every run so it can never again be discovered by")
        print("  accident. `--global` prints the packages outside this family that are still")
        print("  unowned, which are Phase 6's (#820) and out of scope for #973.")

    # A package present in the kernel and absent from FAMILY is the exact shape this census exists
    # to catch, and it is what a kernel bump, or a careless edit to the table, would produce.
    # `--reverify-family` catches it exactly but needs `Libraries/occt-src`, which is a build
    # artifact and gitignored. This prefix sweep is the form that works from the shipped headers
    # alone, and it FAILS rather than reporting: an unrecognised prefix match needs a decision, and
    # printing a note is what let one arrive unnoticed in the first place.
    print()
    missing_from_table = sorted(p for p in shipped
                                if p not in FAMILY and p not in PREFIX_SWEEP_EXCLUSIONS
                                and p.startswith(OCAF_PREFIXES))
    if missing_from_table:
        print("PREFIX SWEEP: shipped packages matching an OCAF-shaped prefix, absent from the")
        print("table, and with no recorded exclusion. Each needs an owner or an entry in")
        print("PREFIX_SWEEP_EXCLUSIONS saying why it is not in this family:")
        for p in missing_from_table:
            print(f"  {p} ({shipped[p]} headers)")
        failures.append(f"{len(missing_from_table)} prefix-matching package(s) in neither FAMILY "
                        f"nor PREFIX_SWEEP_EXCLUSIONS: {', '.join(missing_from_table)}")
    else:
        print(f"PREFIX SWEEP: every shipped package matching one of the {len(OCAF_PREFIXES)} "
              f"OCAF-shaped prefixes is in the table "
              f"({len(PREFIX_SWEEP_EXCLUSIONS)} recorded exclusions).")

    print()
    if failures:
        print("FAILURES")
        for f in failures:
            print(f"  {f}")
        return 1
    print("OK: header counts match the pinned kernel and every family package has an owner.")
    return 0


def pass_report(number: str) -> int:
    rc = require_headers()
    if rc is not None:
        return rc
    if number not in OWNERS:
        print(f"unknown owner #{number}. Known: {', '.join('#' + o for o in sorted(OWNERS))}")
        return 1
    shipped = shipped_packages()
    bridge = bridge_text()
    docs = docs_text()
    pkgs = sorted(p for p in FAMILY if FAMILY[p][4] == number)
    print(f"#{number}  {OWNERS[number]}")
    print()
    total = 0
    for p in pkgs:
        classes = package_classes(p)
        w = named_classes(classes, bridge)
        d = named_classes(classes, docs)
        total += shipped.get(p, 0)
        print(f"  {p + '_':22} {shipped.get(p, 0):4} headers  {len(w):3} wrapped  "
              f"{len(d):3} documented  [{FAMILY[p][3]}]")
    print()
    print(f"  {len(pkgs)} packages, {total} headers")
    return 0


def why_report(pkg: str) -> int:
    if pkg not in FAMILY:
        near = [p for p in FAMILY if p.lower().startswith(pkg.lower()[:3])]
        print(f"{pkg} is not in this family table." + (f" Did you mean: {', '.join(near)}" if near
                                                       else ""))
        return 1
    headers, module, toolkit, tier, owner = FAMILY[pkg]
    print(f"{pkg}_")
    print(f"  headers  {headers}")
    print(f"  OCCT     {module}/{toolkit}")
    print(f"  tier     {tier}")
    print(f"  owner    #{owner}  {OWNERS[owner]}")
    print(f"  reason   {reason_for(pkg)}")
    return 0


def reconcile_973() -> int:
    rc = require_headers()
    if rc is not None:
        return rc
    shipped = shipped_packages()
    print("#973's own table against the pinned kernel")
    print()
    bad = [p for p, n in sorted(ISSUE_973_TABLE.items()) if shipped.get(p, 0) != n]
    if bad:
        for p in bad:
            print(f"  header count differs: {p} table={ISSUE_973_TABLE[p]} "
                  f"kernel={shipped.get(p, 0)}")
    else:
        print("  every per-package header count in #973's table is correct.")
    missing = sorted(set(FAMILY) - set(ISSUE_973_TABLE) - {p for p in FAMILY
                                                           if FAMILY[p][4] == "810"})
    print()
    print(f"  packages in the unowned set that #973's table does not list: {len(missing)}, "
          f"{sum(shipped.get(p, 0) for p in missing)} headers")
    for p in missing:
        print(f"    {p} ({shipped.get(p, 0)})")
    unowned = {p: shipped.get(p, 0) for p in FAMILY if FAMILY[p][4] != "810"}
    print()
    print(f"  #973 table       {len(ISSUE_973_TABLE):3} packages "
          f"{sum(ISSUE_973_TABLE.values()):4} headers")
    print(f"  #973 prose       {ISSUE_973_PROSE_PACKAGES:3} packages "
          f"{ISSUE_973_PROSE_HEADERS:4} headers")
    print(f"  measured here    {len(unowned):3} packages {sum(unowned.values()):4} headers")
    print()
    print("  The prose header total was right and the table under it was not, which is the reverse")
    print("  of the usual direction and the reason #973 asked for a re-derivation rather than an")
    print("  inheritance. The prose package count was wrong against both.")
    return 0


def global_report() -> int:
    """Every shipped package no lane names. Context only, and #820's subject rather than #973's."""
    rc = require_headers()
    if rc is not None:
        return rc
    bodies = {}
    for n in LANE_ISSUES:
        body = gh_issue_body(n)
        if body is None:
            print(f"ENVIRONMENT: could not read issue #{n} through `gh`.")
            return 2
        bodies[n] = lane_section(body)
    shipped = shipped_packages()
    unowned = {p: n for p, n in shipped.items()
               if not any(lane_names_package(t, p) for t in bodies.values())}
    print(f"shipped packages: {len(shipped)}, {sum(shipped.values())} headers")
    print(f"named by no lane: {len(unowned)}, {sum(unowned.values())} headers")
    print()
    print("Largest 40, for calibration. This is NOT a work list: a lane names a prefix family, and")
    print("most of these are foundation containers, collection instantiations and internal")
    print("algorithm packages no pass would ever name individually. Phase 6 (#820) is the check")
    print("that covers them, and #973 deliberately partitioned only the OCAF family.")
    for p, n in sorted(unowned.items(), key=lambda kv: (-kv[1], kv[0]))[:40]:
        print(f"  {p:28} {n:4}")
    return 0


def verify_lanes() -> int:
    """Every package this table assigns to issue N must be named in N's `## Lane`.

    This is the check that requirement 3 of #973 stays true: the decision has to live where a cold
    reader of #811 or #814 sees it, not only in #973's body. Forward direction only; see the module
    docstring for why extra namers are reported rather than failed.
    """
    bodies = {}
    for n in sorted(set(FAMILY[p][4] for p in FAMILY) | set(LANE_ISSUES)):
        body = gh_issue_body(n)
        if body is None:
            print(f"ENVIRONMENT: could not read issue #{n} through `gh`. Needs network and auth.")
            return 2
        bodies[n] = lane_section(body)

    failures = []
    extras = []
    for pkg in sorted(FAMILY):
        owner = FAMILY[pkg][4]
        namers = [n for n, t in bodies.items() if t and lane_names_package(t, pkg)]
        if owner == "820":
            if namers:
                failures.append(f"{pkg}: recorded as owned by no lane pass, but "
                                f"{', '.join('#' + n for n in namers)} names it")
            continue
        if owner not in namers:
            failures.append(f"{pkg}: assigned to #{owner}, whose `## Lane` does not name it")
        others = [n for n in namers if n != owner]
        if others:
            extras.append(f"{pkg} (#{owner}) also named by {', '.join('#' + n for n in others)}")

    print(f"checked {len(FAMILY)} packages against {len(bodies)} issue bodies")
    if extras:
        print()
        print("also named elsewhere (reported, not failed: a lane legitimately names its "
              "neighbours)")
        for e in extras:
            print(f"  {e}")
    print()
    if failures:
        print("FAILURES")
        for f in failures:
            print(f"  {f}")
        return 1
    print("OK: every package is named by the `## Lane` of the issue this table assigns it to.")
    return 0


def reverify_family() -> int:
    """Re-derive the family from `Libraries/occt-src` and fail on any difference.

    Three derivations, all against the source tree rather than against this file's own table:
    the ApplicationFramework module membership, the header-to-package overrides, and the header
    counts.
    """
    rc = require_headers()
    if rc is not None:
        return rc
    if not os.path.isdir(OCCT_SRC):
        print("ENVIRONMENT: Libraries/occt-src is not present, so module membership cannot be")
        print("  re-derived. It is a build artifact of Scripts/build-occt.sh and is gitignored.")
        return 2

    pkg_loc: dict[str, tuple[str, str]] = {}
    hdr_pkg: dict[str, str] = {}
    for module in sorted(os.listdir(OCCT_SRC)):
        md = os.path.join(OCCT_SRC, module)
        if not os.path.isdir(md):
            continue
        for toolkit in sorted(os.listdir(md)):
            td = os.path.join(md, toolkit)
            if not os.path.isdir(td):
                continue
            for pkg in sorted(os.listdir(td)):
                pd = os.path.join(td, pkg)
                if pkg == "GTests" or not os.path.isdir(pd):
                    continue
                pkg_loc.setdefault(pkg, (module, toolkit))
                for f in os.listdir(pd):
                    if f.endswith(".hxx"):
                        hdr_pkg.setdefault(f, pkg)

    failures = []

    derived_overrides = {}
    for name in sorted(os.listdir(OCCT_HEADERS)):
        if not name.endswith(".hxx"):
            continue
        src_pkg = hdr_pkg.get(name)
        if src_pkg is None:
            continue
        if src_pkg != os.path.splitext(name)[0].split("_", 1)[0]:
            derived_overrides[name] = src_pkg
    if derived_overrides != HEADER_PACKAGE_OVERRIDES:
        failures.append(f"HEADER_PACKAGE_OVERRIDES is stale: baked {HEADER_PACKAGE_OVERRIDES}, "
                        f"derived {derived_overrides}")
    else:
        print(f"header-package overrides: {len(derived_overrides)} derived, all baked")

    shipped = shipped_packages()
    derived_module = sorted(p for p in shipped
                            if pkg_loc.get(p, ("", ""))[0] == "ApplicationFramework")
    baked_module = sorted(p for p in FAMILY if FAMILY[p][3] == "module")
    if derived_module != baked_module:
        failures.append(f"ApplicationFramework membership drifted: "
                        f"only in kernel {sorted(set(derived_module) - set(baked_module))}, "
                        f"only in table {sorted(set(baked_module) - set(derived_module))}")
    else:
        print(f"ApplicationFramework module: {len(derived_module)} packages, "
              f"{sum(shipped[p] for p in derived_module)} headers, all baked as tier `module`")

    for pkg in sorted(FAMILY):
        headers, module, toolkit, _tier, _owner = FAMILY[pkg]
        loc = pkg_loc.get(pkg)
        if loc is None:
            failures.append(f"{pkg}: not found in Libraries/occt-src")
            continue
        if loc != (module, toolkit):
            failures.append(f"{pkg}: baked {module}/{toolkit}, source tree says {loc[0]}/{loc[1]}")
        if shipped.get(pkg, 0) != headers:
            failures.append(f"{pkg}: baked {headers} headers, kernel has {shipped.get(pkg, 0)}")
    print(f"per-package module, toolkit and header count: {len(FAMILY)} checked")

    print()
    if failures:
        print("FAILURES")
        for f in failures:
            print(f"  {f}")
        return 1
    print("OK: the family derivation still agrees with the source tree.")
    return 0


# ------------------------------------------------------------------------------------------------
# Self-test.
#
# Two detectors here can go blind and report "all clear" for the wrong reason:
# `lane_names_package`, which decides whether an issue claims a package, and `header_package`,
# which decides how many headers a package has. Both get a fixture battery, and the removal matrix
# proving each accepting and rejecting shape is load-bearing is in this directory's README.
# ------------------------------------------------------------------------------------------------

LANE_CASES = [
    ("Everything Pass 4d covers: `BRepMesh_*`, `Poly_*`, `StdPrs_*`.", "StdPrs", True,
     "the plain declaration shape every lane in #807 uses."),
    ("Everything Pass 4d covers: `BRepMesh_*`, `Poly_*`, `StdPrs_*`.", "BRepMeshData", False,
     "the prefix trap: `BRepMesh_*` must not claim the separate BRepMeshData package. Removing "
     "the `(?:_|\\*|\\b)` tail turns this into a false claim."),
    ("Everything Pass 4d covers: `BRepMesh_*`, `Poly_*`, `StdPrs_*`.", "BRepMesh", True,
     "the package `BRepMesh_*` does claim, so a check answering False for everything fails here."),
    ("Everything Pass 3 covers: `CDF_*`/`CDM_*`.", "CDM", True,
     "two prefixes in one backtick-delimited run separated by a slash, which is how #810 writes "
     "it. Removing the `[^`\\n]*` prefix walk turns this into a missed claim."),
    ("Everything Pass 2a covers: `BRep_Tool`, `TopoDS_*`.", "BRep", True,
     "a lane naming a CLASS rather than a prefix. #808 names `BRep_Tool` and nothing else from "
     "that package, and the package is still claimed."),
    ("Prose naming StdPrs with no backticks at all.", "StdPrs", False,
     "no backtick, no claim. Without this case the pattern could drop its backtick anchor and "
     "every case above would still pass."),
    ("A fenced line: `Resource_Manager` is wrapped.", "Resource", True,
     "a class name inside backticks still names its package, which is what makes #813's `## Lane` "
     "satisfy --verify-lanes for Resource."),
    ("- **OCCT:** `Handle(TFunction_Driver)` is registered by GUID.", "TFunction", True,
     "the package is not at the start of the backtick run. Removing the `[^`\\n]*` walk turns "
     "this into a missed claim. NOTE: no `## Lane` in #807 is written this way today, so this "
     "case is the ONLY thing holding that shape; see the removal matrix in this directory's "
     "README, where removal R2 fails on this line and nothing else."),
    ("`StdSelectSomethingElse_Foo`", "StdSelect", False,
     "a longer package name that merely starts with this one. Removing the tail assertion turns "
     "this into a false claim, the same failure as the BRepMeshData case but on the other side of "
     "the boundary."),
]

HEADER_PACKAGE_CASES = [
    ("TDataStd_Name.hxx", "TDataStd", "the ordinary underscore split, 53 of TDataStd's headers."),
    ("Storage.hxx", "Storage", "a package-name header with no underscore at all."),
    ("LDOMParser.hxx", "LDOM",
     "the override that is the whole difference between LDOM being 21 headers and 24. Removing "
     "HEADER_PACKAGE_OVERRIDES makes this answer LDOMParser and the family total drop by 3."),
    ("LDOM_Element.hxx", "LDOM", "the same package reached the ordinary way."),
    ("step.tab.hxx", "StepFile",
     "the fourth override, outside this family. Carried so --reverify-family's derived list and "
     "the baked one can be compared for equality rather than for containment."),
]


def self_test() -> int:
    failures = 0

    print(f"self-test, lane claim detector: {len(LANE_CASES)} cases")
    for text, pkg, expected, why in LANE_CASES:
        got = lane_names_package(text, pkg)
        ok = got is expected
        print(f"  [{'PASS' if ok else 'FAIL'}] {pkg:16} in {text[:52]!r} -> {got}")
        if not ok:
            print(f"         expected {expected}: {why}")
            failures += 1

    print()
    print(f"self-test, header-package mapping: {len(HEADER_PACKAGE_CASES)} cases")
    for filename, expected, why in HEADER_PACKAGE_CASES:
        got = header_package(filename)
        ok = got == expected
        print(f"  [{'PASS' if ok else 'FAIL'}] {filename:24} -> {got}")
        if not ok:
            print(f"         expected {expected}: {why}")
            failures += 1

    print()
    print("self-test, table integrity: every family package has a known owner and a reason")
    for pkg in sorted(FAMILY):
        owner = FAMILY[pkg][4]
        if owner not in OWNERS:
            print(f"  [FAIL] {pkg}: owner #{owner} is not in OWNERS")
            failures += 1
        elif reason_for(pkg).startswith("(no reason recorded"):
            print(f"  [FAIL] {pkg}: no group or package reason recorded")
            failures += 1
    print(f"  [{'PASS' if failures == 0 else 'FAIL'}] {len(FAMILY)} packages checked")

    total = len(LANE_CASES) + len(HEADER_PACKAGE_CASES) + 1
    print()
    if failures:
        print(f"SELF-TEST FAILED: {failures} of {total}")
        return 1
    print(f"SELF-TEST PASSED: {total} of {total} "
          f"({len(LANE_CASES)} lane, {len(HEADER_PACKAGE_CASES)} header-package, 1 table)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--verbose", action="store_true",
                        help="list the wrapped class names per package")
    parser.add_argument("--pass", dest="pass_", metavar="ISSUE",
                        help="print only the packages one issue owns, e.g. --pass 983")
    parser.add_argument("--why", metavar="PACKAGE",
                        help="print the recorded reason for one package's owner")
    parser.add_argument("--reconcile-973", action="store_true",
                        help="compare #973's own table against the pinned kernel")
    parser.add_argument("--global", dest="global_", action="store_true",
                        help="every shipped package no lane names, for calibration (needs `gh`)")
    parser.add_argument("--verify-lanes", action="store_true",
                        help="fail if an owning issue's `## Lane` no longer names what it owns "
                             "(needs `gh`)")
    parser.add_argument("--reverify-family", action="store_true",
                        help="re-derive the family from Libraries/occt-src and fail on drift")
    parser.add_argument("--self-test", action="store_true",
                        help="run this file's own detector fixture battery")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.why:
        return why_report(args.why)
    if args.pass_:
        return pass_report(args.pass_.lstrip("#"))
    if args.reconcile_973:
        return reconcile_973()
    if args.global_:
        return global_report()
    if args.verify_lanes:
        return verify_lanes()
    if args.reverify_family:
        return reverify_family()
    return main_report(args.verbose)


if __name__ == "__main__":
    sys.exit(main())
