#!/usr/bin/env python3
"""One-shot migration: split Sources/OCCTBridge/src/OCCTBridge_Modeling.mm (16,301 lines) into
per-family .mm files, mirroring #395's approach for the header split (write a script, verify the
reconstruction is exact, run it once, review the diff) rather than hundreds of hand edits.

Unlike #395, this does NOT touch OCCTBridge_Modeling.h: the public C API surface is unchanged,
every new .mm file #imports the same shared header. This is a pure file-content reorganization.

## The scanner is structural, not pattern-matched, and that distinction is why v1 of this script
## was wrong

The first version of this script matched specific line shapes (`OCCTXxx(` for a public function,
`static lowercaseXxx(` for a helper) and missed three real content classes as a result, each
silently DROPPED (not misclassified -- absent from every output file) until a from-scratch full-file
line-coverage check caught it:

1. **119 `#include` lines scattered mid-file**, not just in the top preamble -- this codebase's
   pattern for a file grown incrementally over ~130 releases is to add each new operation's OCCT
   header include right next to where it's first used, not consolidated at the top.
2. **17 top-level `struct`/`class` definitions** between functions (`OCCTFilletBuilder`,
   `OCCTCellsBuilder`, `OCCTBoolTimeoutBreaker`, and 14 more) -- the opaque-handle backing storage
   for exactly the wrapper-builder pattern (`FilletBuilder`, `ChamferBuilder`, `PipeShell`, ...)
   this split's own name-prefix taxonomy already relies on.
3. **One `template <typename T>`-prefixed function** (`runBooleanEx`), whose declaration line
   doesn't itself start with a function-shaped pattern; the template parameter line sits above it.

None of these can be enumerated exhaustively as "the last one, promise" -- a fourth kind could exist
that this pass also didn't think to look for. So the scanner below does not pattern-match at all: it
walks the WHOLE FILE line by line, classifying by structural role only (blank / comment / `#include`
or `#import` / other preprocessor / a "code unit" delimited by brace depth returning to zero), and a
separate, mandatory coverage check (`verify_full_coverage`) confirms every single line of the
original file is accounted for by exactly one of: the global preamble, a scattered #include (folded
into that same preamble), or exactly one classified code unit's block. This is not a defense against
one specific miss; it is a defense against the *shape* of miss ("content between two recognized
items that isn't a blank line or an attached comment"), which is what actually failed here twice.

## Taxonomy (unchanged from the first version, re-verified against the corrected scan)

Split key, per code unit: the most-referenced non-generic OCCT class in its own text (gp_/TopoDS_/
TopAbs_/Standard_/TColStd_/NCollection_/TDF_/TopExp_/TopTools_/gce_/Geom_/GeomAbs_/Poly_/Precision_
excluded as ubiquitous utility types that would dominate every unit's vote and say nothing about its
real domain), falling back to a curated NAME-PREFIX table for the wrapper-builder pattern (its real
OCCT class lives in the struct, not restated in every function that touches it).

  WireEdgeFaceBuilders  BRepBuilderAPI_Make{Edge,Face,Wire,Vertex,Solid,Shell,ShapeOnMesh},
                        BRepLib_Make*, WireBuilder*, MakeDir2d*, WireInterpolate*
  SolidPrimitives       BRepPrimAPI_Make{Sphere,Cylinder,Torus,Prism,Cone,Box,Wedge,Revol,Revolution},
                        ShapeMake{ThickSolid,Draft,Volume,Connected,Periodic}, ShapeRepeat, Quilt
  Transform             BRepBuilderAPI_{Transform,GTransform}, BRepTools_*Modification, Make{Mirror,
                        Rotation,Translation,Scale}*
  ShapeToolsHistory     BRep_Tool, BRep_Builder, BRepLib_FindSurface
  Boolean               BRepAlgoAPI, BOPAlgo, IntTools, BOPTools, BRepAlgo, BRepTools_History,
                        boolean/pattern history, BRepAlgoImage*, OCCTBoolTimeoutBreaker
  Sweep                 BRepOffsetAPI, BRepFill, Law, GeomFill, Approx, Filling*, ThruSections,
                        PipeShell, BRepFillNSections*, BRepFillOffsetAncestors*
  Fillet                BRepFilletAPI, FilletSurf, BiTgte, FilletBuilder*
  Chamfer               ChFi2d, ChFiDS, ChFi3d, ChamferBuilder*
  Features              BRepFeat, Draft, LocOpe, HelixBRep, pattern history, defeaturing helper
  HealingSewing         ShapeFix, ShapeAnalysis, ShapeBuild, ShapeUpgrade, BRepCheck, BRepOffset,
                        UnifySame*, Sewing*, BRepBuilderAPI_Sewing
  HLRProjection         HLRBRep, HLRAppli, BRepProj, NormalProjection, DrawingReachAlongDirection
                        (dead code, zero callers anywhere in the file; moved not deleted, since
                        removing dead code is a behavior-adjacent change out of scope here)
  Misc                  Section builder, CellsBuilder, XCAFDoc, Bnd, BRepPreviewAPI

    python3 split_modeling_mm.py --report     # classification only, writes nothing
    python3 split_modeling_mm.py --verify     # classification + full-file coverage + reconstruction
    python3 split_modeling_mm.py --write      # creates the 12 files (does NOT delete the original)
    python3 split_modeling_mm.py --self-test  # prove the scanner and coverage check work

Run from anywhere; paths derive from this file's location.
"""
from __future__ import annotations

import argparse
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SRC_PATH = os.path.join(ROOT, "Sources", "OCCTBridge", "src", "OCCTBridge_Modeling.mm")
OUT_DIR = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
PKG_PATH = os.path.join(ROOT, "Scripts", "occt-packages.txt")

GENERIC = {"gp", "TopoDS", "TopAbs", "Standard", "TColStd", "NCollection", "TDF", "TopExp",
           "TopTools", "gce", "Geom", "GeomAbs", "Poly", "Precision"}

PKG_TOKEN = re.compile(r'\b([A-Za-z][A-Za-z0-9]*)_[A-Za-z]')
CLASS_TOKEN = re.compile(r'\b([A-Za-z][A-Za-z0-9]*_[A-Za-z][A-Za-z0-9]*)\b')
NAME_IN_BLOCK = re.compile(r'\b(OCCT[A-Za-z0-9_]+)\s*[(;]')
STATIC_HELPER_NAME = re.compile(r'\b([a-z_][A-Za-z0-9_]*)\s*\(')
STRUCT_OR_CLASS = re.compile(r'^(?:static\s+)?(struct|class)\s+([A-Za-z_][A-Za-z0-9_]*)')


def load_packages():
    return set(l.strip() for l in open(PKG_PATH) if l.strip() and not l.startswith("#"))


# ----------------------------------------------------------------------------------------------
# Structural scan: no per-declaration-shape pattern matching. Every line is one of blank / comment
# / include / other-preprocessor / part of a "code unit" delimited by brace depth.
# ----------------------------------------------------------------------------------------------

def scan_structural(path):
    lines = open(path, errors="ignore").read().split("\n")
    n = len(lines)
    tokens = []  # (kind, start, end) kind in {blank, comment, include, preprocessor, code}
    i = 0
    while i < n:
        stripped = lines[i].strip()
        if stripped == "":
            tokens.append(("blank", i, i + 1))
            i += 1
            continue
        if stripped.startswith("//"):
            tokens.append(("comment", i, i + 1))
            i += 1
            continue
        if stripped.startswith("#include") or stripped.startswith("#import"):
            tokens.append(("include", i, i + 1))
            i += 1
            continue
        if stripped.startswith("#"):
            tokens.append(("preprocessor", i, i + 1))
            i += 1
            continue
        # A genuine top-level code line: consume until brace depth returns to 0 having opened at
        # least one brace, OR (no brace at all -- a bare statement/prototype) until a `;`-ending
        # line.
        start = i
        depth = 0
        opened = False
        j = i
        while j < n:
            depth += lines[j].count("{") - lines[j].count("}")
            if "{" in lines[j]:
                opened = True
            ended_bare = (not opened) and lines[j].rstrip().endswith(";")
            j += 1
            if (opened and depth <= 0) or ended_bare:
                break
        end = j
        # A struct/class definition's closing `};` sometimes lands as `}` then `;` on its own line
        # (this codebase's clang-format style for some multi-line struct closes); absorb a lone
        # trailing `;` line into the same unit rather than leaving it as an orphaned bare statement.
        if end < n and lines[end].strip() == ";":
            end += 1
        tokens.append(("code", start, end))
        i = end
    return lines, tokens


def code_only(block_text):
    """Strip the leading comment block a code unit may have absorbed (its own attached doc
    comment) before any name search: a name-detection regex run against the raw block would
    instead match the FIRST thing that happens to look right inside the PROSE, not the actual
    declaration. Measured, not a hypothetical: "a (nominally planar) wire" inside one function's
    own preceding comment matched the lowercase-static-helper pattern (`a(`) before the real
    `occtSignedWireAreaInPlane` declaration four lines later was ever reached, and a `// MARK:`
    plus multi-line comment ahead of a `struct` definition hid the struct from the first-line-only
    struct/class check entirely."""
    lines = block_text.split("\n")
    i = 0
    while i < len(lines) and (lines[i].strip() == "" or lines[i].lstrip().startswith("//")):
        i += 1
    return "\n".join(lines[i:])


def name_and_kind(block_text):
    """Best-effort (kind, name) for a 'code' unit's text, searched only in the CODE portion (see
    `code_only`). struct/class checked first (anchored at the code's own start, skipping a leading
    `template <...>` line if present); otherwise the first OCCTXxx(/;) mention; otherwise the first
    lowercase-leading call-shaped identifier (a static helper). Returns (None, None) if nothing
    recognizable is found -- callers must treat that as a hard failure, not a silent skip."""
    code = code_only(block_text)
    first_lines = code.split("\n", 3)
    if not first_lines or first_lines[0].strip() == "":
        return None, None
    probe = "\n".join(first_lines[:2]) if first_lines[0].strip().startswith("template") else first_lines[0]
    m = STRUCT_OR_CLASS.match(probe.strip()) or STRUCT_OR_CLASS.match(first_lines[0])
    if m:
        return m.group(1), m.group(2)
    # The declared name only ever appears in the SIGNATURE (return type + name + parameter list),
    # never in the body -- searching the whole `code` text found a constructor call to the wrapper
    # type (`return new OCCTShape(...)` inside a `static occtShapePeriodicImpl(...)`'s own body)
    # before ever reaching that static helper's real name. `signature` is everything up to the
    # first `{` that opens the body (or the first `;` for a bare declaration), which is where a
    # multi-line parameter list still lives but the body's own contents do not.
    brace_idx = code.find("{")
    semi_idx = code.find(";")
    if brace_idx == -1 and semi_idx == -1:
        signature = code
    elif brace_idx == -1:
        signature = code[:semi_idx + 1]
    elif semi_idx == -1 or brace_idx < semi_idx:
        signature = code[:brace_idx]
    else:
        signature = code[:semi_idx + 1]
    m = NAME_IN_BLOCK.search(signature)
    if m:
        return "func", m.group(1)
    m = STATIC_HELPER_NAME.search(signature)
    if m:
        # The `static` KEYWORD, not just a lowercase name, decides internal vs. external linkage.
        # Measured, not assumed: occtDefeaturingFacesFromShapes/occtDefeaturePerform are lowercase
        # like every other internal helper but carry NO `static` and are forward-declared in the
        # shared OCCTBridge_Internal.h (external linkage, one definition needed process-wide,
        # already `#import`ed by every file in the preamble); routing them to SHARED alongside the
        # genuine `static` helpers produced 12 competing external definitions and a real "duplicate
        # symbol" link error. Only a signature that actually starts with `static` goes to SHARED;
        # everything else with a lowercase name is still classified like a "func" (single bucket).
        sig_after_template = signature.lstrip()
        if sig_after_template.startswith("template"):
            # Skip the `template <...>` line itself before checking for `static`, same as the
            # struct/class probe above already does -- `static` sits on the NEXT line for a
            # template-prefixed helper (`runBooleanEx`'s own shape), not the first.
            sig_after_template = sig_after_template.split("\n", 1)[1].lstrip() if "\n" in sig_after_template else ""
        is_truly_static = sig_after_template.startswith("static") and \
            re.match(r'^static\b', sig_after_template) is not None
        return ("static" if is_truly_static else "func"), m.group(1)
    return None, None


# ----------------------------------------------------------------------------------------------
# Classification (bucket taxonomy) -- unchanged logic from v1, applied to the corrected scan.
# ----------------------------------------------------------------------------------------------

NAME_PREFIX_BUCKET = [
    ("FilletBuilder", "Fillet"),
    ("ChamferBuilder", "Chamfer"),
    ("PipeShell", "Sweep"),
    ("SectionBuilder", "Misc"),
    ("CellsBuilder", "Misc"),
    ("ThruSections", "Sweep"),
    ("UnifySame", "HealingSewing"),
    ("WireBuilder", "WireEdgeFaceBuilders"),
    ("Filling", "Sweep"),
    ("Sewing", "HealingSewing"),
    ("ShapeSewTwo", "HealingSewing"),
    ("AsDes", "Boolean"),
    ("BooleanHistory", "Boolean"),
    ("BRepAlgoImage", "Boolean"),
    ("BoolTimeoutBreaker", "Boolean"),
    ("ShapeHistory", "Boolean"),
    ("History", "Boolean"),  # HistoryAdd/Has/Is/Modified/Generated/Remove/Destroy
    ("MakeMirror", "Transform"),
    ("MakeRotation", "Transform"),
    ("MakeTranslation", "Transform"),
    ("MakeScale", "Transform"),
    ("MakeDir2d", "WireEdgeFaceBuilders"),
    ("LawFunction", "Sweep"),
    ("WireInterpolate", "WireEdgeFaceBuilders"),
    ("WireCreateCubicBSpline", "WireEdgeFaceBuilders"),
    ("ShapeRepeat", "SolidPrimitives"),
    ("ShapeCompound", "SolidPrimitives"),
    ("ShapeMake", "SolidPrimitives"),
    ("ShapeQuilt", "SolidPrimitives"),
    ("FreeShape", "SolidPrimitives"),
    ("FreeWire", "WireEdgeFaceBuilders"),
    ("NormalProjection", "HLRProjection"),
    ("BRepFillOffsetAncestors", "Sweep"),
    ("OffsetAncestorsOpaque", "Sweep"),
    ("BRepFillNSections", "Sweep"),
    ("NSectionsOpaque", "Sweep"),
    ("BRepFeatCylindricalHole", "Features"),
    ("Defeaturing", "Features"),
]

BODY_PACKAGE_TO_BUCKET = {
    "BRepAlgoAPI": "Boolean", "BOPAlgo": "Boolean", "IntTools": "Boolean", "BOPTools": "Boolean",
    "BRepAlgo": "Boolean",
    "BRepBuilderAPI": "WireEdgeFaceBuilders", "BRepLib": "WireEdgeFaceBuilders",
    "BRepPrimAPI": "SolidPrimitives", "BRepPreviewAPI": "Misc",
    "BRep": "ShapeToolsHistory", "BRepTools": "ShapeToolsHistory",
    "GC": "WireEdgeFaceBuilders", "TColgp": "WireEdgeFaceBuilders",
    "BRepFilletAPI": "Fillet", "FilletSurf": "Fillet", "BiTgte": "Fillet",
    "ChFi2d": "Chamfer", "ChFiDS": "Chamfer", "ChFi3d": "Chamfer",
    "BRepOffsetAPI": "Sweep", "BRepFill": "Sweep", "Law": "Sweep", "GeomFill": "Sweep",
    "Approx": "Sweep",
    "LocOpe": "Features", "BRepFeat": "Features", "Draft": "Features", "HelixBRep": "Features",
    "ShapeFix": "HealingSewing", "ShapeAnalysis": "HealingSewing", "ShapeBuild": "HealingSewing",
    "ShapeUpgrade": "HealingSewing", "BRepCheck": "HealingSewing", "BRepOffset": "HealingSewing",
    "HLRBRep": "HLRProjection", "HLRAppli": "HLRProjection", "BRepProj": "HLRProjection",
    "XCAFDoc": "Misc", "Bnd": "Misc",
}

CLASS_OVERRIDE_BUCKET = {
    "BRepBuilderAPI_Transform": "Transform",
    "BRepBuilderAPI_GTransform": "Transform",
    "BRepTools_TrsfModification": "Transform",
    "BRepTools_GTrsfModification": "Transform",
    "BRepTools_CopyModification": "Transform",
    "BRepTools_Quilt": "SolidPrimitives",
    "BRepBuilderAPI_Sewing": "HealingSewing",
    "BRepTools_History": "Boolean",
}

# Structural-scan corrections: things `name_and_kind` cannot resolve from body content alone
# (bodies referencing only GENERIC types, or whose "most relevant" callers determine the bucket,
# found by explicit caller investigation, not guessed).
NAME_BUCKET_OVERRIDE = {
    "occtDrawingReachAlongDirection": "HLRProjection",  # dead code; HLR is its topical home
    "runBooleanEx": "Boolean",
    "occtArgList": "Boolean",
    "occtSignedWireAreaInPlane": "WireEdgeFaceBuilders",
    "_storeTrsf": "Transform",
    "_storeTrsf2d": "Transform",
    "occtQuiltShells": "SolidPrimitives",
    "occtShapePeriodicImpl": "SolidPrimitives",
    "occtPatternHistory": "Features",
    "occtWireInterpolateImpl": "WireEdgeFaceBuilders",
    "occtSampleWirePoints": "WireEdgeFaceBuilders",
    "occtFacePlane": "WireEdgeFaceBuilders",
    "fillCommonPart": "Boolean",
    "toGlueEnum": "Boolean",
    "occtFilletBuilderHistoryQuery": "Fillet",
    "occtChamferBuilderHistoryQuery": "Chamfer",
    "occtDefeaturingFacesByIndex": "Features",
}

BUCKETS = ["WireEdgeFaceBuilders", "SolidPrimitives", "Transform", "ShapeToolsHistory", "Boolean",
           "Sweep", "Fillet", "Chamfer", "Features", "HealingSewing", "HLRProjection", "Misc"]


def classify(name, body):
    if name in NAME_BUCKET_OVERRIDE:
        return NAME_BUCKET_OVERRIDE[name]
    stripped = name[4:] if name.startswith("OCCT") else name
    for prefix, bucket in NAME_PREFIX_BUCKET:
        if prefix in stripped:
            return bucket
    class_counts = collections.Counter(CLASS_TOKEN.findall(body))
    for cls, _ in class_counts.most_common():
        if cls in CLASS_OVERRIDE_BUCKET:
            return CLASS_OVERRIDE_BUCKET[cls]
    packages = classify.packages
    pkg_counts = collections.Counter()
    for m in PKG_TOKEN.finditer(body):
        pfx = m.group(1)
        if pfx in packages and pfx not in GENERIC:
            pkg_counts[pfx] += 1
    if pkg_counts:
        top = pkg_counts.most_common(1)[0][0]
        if top in BODY_PACKAGE_TO_BUCKET:
            return BODY_PACKAGE_TO_BUCKET[top]
    return None


# ----------------------------------------------------------------------------------------------
# Plan assembly
# ----------------------------------------------------------------------------------------------

def build_plan(path=None):
    if path is None:
        path = SRC_PATH
    classify.packages = load_packages()
    lines, tokens = scan_structural(path)

    raw_code_units = [(s, e) for kind, s, e in tokens if kind == "code"]
    first_code_start_raw = min(s for s, _ in raw_code_units) if raw_code_units else len(lines)

    # Attach each code unit's immediately-preceding contiguous comment block (#395's own rule for
    # a declaration's doc comment) by extending its start backward over "comment" tokens, stopping
    # at a blank line or anything else. The first code unit's own comment (if any) stays claimed by
    # the shared preamble instead, since it sits inside the header-comment block every file gets.
    comment_ranges = {s: e for kind, s, e in tokens if kind == "comment"}
    code_units = []
    for start, end in raw_code_units:
        if start == first_code_start_raw:
            code_units.append((start, end))
            continue
        cstart = start
        while cstart - 1 in comment_ranges:
            cstart -= 1
        code_units.append((cstart, end))

    first_code_start = min(s for s, _ in code_units) if code_units else len(lines)

    # Only #include/#import lines strictly AFTER the shared preamble region count as "scattered":
    # ones inside it are already covered by `lines[:first_code_start]` and double-counting them
    # would make the coverage check falsely report an overlap.
    scattered_includes = [i for kind, i, _ in tokens if kind == "include" and i >= first_code_start]

    plan = []
    unresolved = []  # code units with no recognizable name at all -- hard failure
    unclassified = []  # named units the bucket classifier couldn't place
    for start, end in code_units:
        block = "\n".join(lines[start:end])
        kind, name = name_and_kind(block)
        if name is None:
            unresolved.append((start + 1, end - start, block.split("\n")[0]))
            continue
        if kind in ("struct", "class", "static"):
            # NOT single-bucket-assigned, on purpose, after measuring why not: a first attempt
            # assigned each struct/static helper to the one bucket its OWN identified callers sat
            # in, and the real build immediately proved that assumption false three separate ways
            # (OCCTLawFunction, defined for Sweep-bucket callers, also constructed from a Fillet
            # function; occtSampleWirePoints/occtFacePlane/occtSignedWireAreaInPlane, homed in
            # WireEdgeFaceBuilders, also called from a HealingSewing function; OCCTBooleanHistory,
            # homed in Boolean, also constructed from a Features function). All three are the
            # opaque-handle backing storage or a private helper for the wrapper-builder pattern
            # this split's own taxonomy is built on, and that pattern is used across domain
            # boundaries by design (a Fillet operation can carry Boolean-shaped history, etc.).
            # Every struct/static, not just the three caught so far, goes into the SHARED preamble
            # instead: each of the 12 output files is its own translation unit, so an identical
            # struct/function definition compiled once per file (not externally linked, never
            # passed by value across a TU boundary) is standard, safe C++, the same way an
            # #include'd header's contents are duplicated into every TU that includes it.
            bucket = "SHARED"
        else:
            bucket = classify(name, block)
            if bucket is None:
                unclassified.append((kind, name, start + 1, end - start))
        plan.append((kind, name, bucket, start, end, block))

    return lines, plan, unresolved, unclassified, scattered_includes, first_code_start


def preamble(lines, first_code_start, scattered_include_lines, shared_items):
    """Top-of-file header comment + import/include block, trimmed of trailing comment/blank noise,
    PLUS the deduplicated set of every #include/#import found anywhere else in the file (in
    first-seen order), PLUS every struct/class/static-helper item (in original file order, to
    preserve any helper-calls-an-earlier-helper dependency). Every one of the 12 new files gets
    this identical preamble; each compiles its own copy, which is safe C++ since none of this is
    externally linked or passed by value across a file boundary -- the same reasoning that makes
    an #include'd header's contents safe to duplicate into every TU that includes it."""
    end = first_code_start
    while end > 0 and (lines[end - 1].lstrip().startswith("//") or lines[end - 1].strip() == ""):
        end -= 1
    top = lines[:end]
    top_include_set = {l.strip() for l in top if l.strip().startswith(("#include", "#import"))}
    extra = []
    seen = set(top_include_set)
    for i in scattered_include_lines:
        text = lines[i].strip()
        if text not in seen:
            seen.add(text)
            extra.append(text)
    result = "\n".join(top)
    if extra:
        result += "\n\n// Additional includes gathered from throughout the original file (#396):\n"
        result += "\n".join(extra)
    if shared_items:
        ordered = sorted(shared_items, key=lambda t: t[3])  # by original start line
        result += ("\n\n// Shared private structs/helpers (#396): every one of the twelve split "
                   "files gets this\n// identical block, compiled independently per TU -- see this "
                   "split's own README for why.\n\n")
        result += "\n\n".join(block for kind, name, bucket, start, end2, block in ordered)
    return result


def report():
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan()
    by_bucket = collections.defaultdict(lambda: [0, 0])
    for kind, name, bucket, start, end, block in plan:
        if bucket is None:
            continue
        by_bucket[bucket][0] += 1
        by_bucket[bucket][1] += end - start
    print(f"{len(plan) + len(unresolved)} code units ({len(plan)} named, {len(unresolved)} "
          f"UNRESOLVED), {len(unclassified)} unclassified, {len(scattered)} scattered includes\n")
    for bucket in BUCKETS:
        count, total_lines = by_bucket.get(bucket, (0, 0))
        print(f"  {bucket:22s} {count:4d} items  {total_lines:6d} lines")
    count, total_lines = by_bucket.get("SHARED", (0, 0))
    print(f"  {'SHARED (every file)':22s} {count:4d} items  {total_lines:6d} lines "
          f"(structs + static helpers, in the preamble, not a standalone file)")
    if unresolved:
        print(f"\nUNRESOLVED (no recognizable name at all) ({len(unresolved)}):")
        for lineno, size, first in unresolved:
            print(f"  line {lineno} ({size}L): {first!r}")
    if unclassified:
        print(f"\nUNCLASSIFIED ({len(unclassified)}):")
        for kind, name, lineno, size in unclassified:
            print(f"  {kind} {name} (line {lineno}, {size}L)")
    return 0 if (not unresolved and not unclassified) else 1


def verify_full_coverage(lines, plan, unresolved, scattered_includes, first_code_start):
    """Every FUNCTIONAL line of the original file must be accounted for by exactly one of: the
    shared preamble region (before first_code_start), a scattered #include (folded into the
    preamble), or exactly one plan item's [start, end) range. A line covered by neither, or by more
    than one, is the exact failure shape that made v1 of this script silently drop 138 lines.

    A stand-alone `//` comment line NOT attached to any following item (an old MARK divider sitting
    between two unrelated functions, separated from both by a blank line) is deliberately exempt
    from "uncovered", not silently passed: `orphaned_comments` reports it. Losing these organizational
    dividers is an accepted, intentional consequence of replacing 104 in-file MARK sections with 12
    purpose-named files, not a defect on the order of dropping an #include or a struct definition."""
    n = len(lines)
    coverage = [0] * n
    for i in range(first_code_start):
        coverage[i] += 1
    for i in scattered_includes:
        coverage[i] += 1
    for kind, name, bucket, start, end, block in plan:
        for i in range(start, end):
            coverage[i] += 1

    uncovered = []
    orphaned_comments = []
    for i in range(n):
        if coverage[i] != 0:
            continue
        stripped = lines[i].strip()
        if stripped == "":
            continue
        if stripped.startswith("//"):
            orphaned_comments.append(i + 1)
            continue
        uncovered.append(i + 1)
    overcovered = [i + 1 for i in range(n) if coverage[i] > 1]
    return uncovered, overcovered, orphaned_comments


def verify():
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan()
    ok = True
    if unresolved:
        print(f"FAIL: {len(unresolved)} code units with no recognizable name")
        for lineno, size, first in unresolved:
            print(f"  line {lineno} ({size}L): {first!r}")
        ok = False
    if unclassified:
        print(f"FAIL: {len(unclassified)} unclassified named units")
        ok = False
    uncovered, overcovered, orphaned = verify_full_coverage(lines, plan, unresolved, scattered, first_code_start)
    if uncovered:
        print(f"FAIL: {len(uncovered)} non-blank, non-comment lines of the original file are "
              f"covered by NOTHING (preamble, scattered include, or plan item). "
              f"First 20: {uncovered[:20]}")
        ok = False
    if overcovered:
        print(f"FAIL: {len(overcovered)} lines covered by MORE THAN ONE plan item (overlap). "
              f"First 20: {overcovered[:20]}")
        ok = False
    if orphaned:
        print(f"NOTE: {len(orphaned)} orphaned comment lines (old MARK dividers not attached to "
              f"any surviving item) will not appear in any output file. Accepted, not a failure.")

    dup_names = [n for n, c in collections.Counter(n for _, n, *_ in plan).items() if c > 1]
    real_dups = [n for n in dup_names if n != "occtArgList"]
    if real_dups:
        print(f"FAIL: duplicate names outside the known occtArgList overload pair: {real_dups}")
        ok = False

    if ok:
        print(f"OK: {len(plan)} code units, full-file line coverage exact (0 uncovered, "
              f"0 overcovered), no unexpected duplicate names")
    return 0 if ok else 1


FILE_HEADER_TEMPLATE = """\
//
//  OCCTBridge_Modeling_{suffix}.mm
//  OCCTSwift
//
//  Split from OCCTBridge_Modeling.mm (#396/#819): {desc}.
//  Public C surface unchanged; imports the same OCCTBridge_Modeling.h every sibling file does.
//  No symbol changes, pure file move -- see Scripts/repro/396-modeling-mm-split/ for how.
//

"""

BUCKET_DESC = {
    "WireEdgeFaceBuilders": "BRepBuilderAPI_Make{Edge,Face,Wire,Vertex,Solid,Shell}, BRepLib_Make*",
    "SolidPrimitives": "BRepPrimAPI_Make{Sphere,Cylinder,Torus,Prism,Cone,Box,Wedge,Revol}, shape assembly",
    "Transform": "BRepBuilderAPI_{Transform,GTransform}, BRepTools_*Modification",
    "ShapeToolsHistory": "BRep_Tool, BRep_Builder, BRepLib_FindSurface",
    "Boolean": "BRepAlgoAPI, BOPAlgo, IntTools, BOPTools, boolean/pattern history",
    "Sweep": "BRepOffsetAPI, BRepFill, Law, Filling, ThruSections, PipeShell",
    "Fillet": "BRepFilletAPI, FilletSurf, BiTgte, FilletBuilder",
    "Chamfer": "ChFi2d, ChFiDS, ChFi3d, ChamferBuilder",
    "Features": "BRepFeat, Draft, LocOpe, Helix, patterns",
    "HealingSewing": "ShapeFix, ShapeAnalysis, ShapeBuild, ShapeUpgrade, BRepCheck, Sewing",
    "HLRProjection": "HLRBRep, HLRAppli, BRepProj, NormalProjection",
    "Misc": "Section builder, CellsBuilder, XCAFDoc, Bnd, BRepPreviewAPI",
}


def write_files():
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan()
    if unresolved or unclassified:
        print("REFUSING to write: unresolved or unclassified units present", file=sys.stderr)
        return 1
    if verify() != 0:
        print("REFUSING to write: verify() failed", file=sys.stderr)
        return 1

    shared_items = [p for p in plan if p[2] == "SHARED"]
    pre = preamble(lines, first_code_start, scattered, shared_items)
    by_bucket = collections.defaultdict(list)
    for kind, name, bucket, start, end, block in plan:
        if bucket == "SHARED":
            continue
        by_bucket[bucket].append((start, block))

    for bucket in BUCKETS:
        items_here = sorted(by_bucket.get(bucket, []), key=lambda t: t[0])
        if not items_here:
            print(f"  (skipping {bucket}: 0 items)")
            continue
        header = FILE_HEADER_TEMPLATE.format(suffix=bucket, desc=BUCKET_DESC[bucket])
        body = "\n\n".join(block for _, block in items_here)
        out_path = os.path.join(OUT_DIR, f"OCCTBridge_Modeling_{bucket}.mm")
        with open(out_path, "w") as fh:
            fh.write(header + pre + "\n\n" + body + "\n")
        print(f"  wrote {out_path} ({len(items_here)} items)")
    return 0


def self_test():
    import tempfile
    import shutil

    fixture = """\
//
//  fixture header
//
#import "x.h"
#include <BRepPrimAPI_MakeBox.hxx>

// A boolean helper.
static bool helperFn(int x) { return x > 0; }

// Fuses two shapes (BRepAlgoAPI_Fuse).
OCCTShapeRef OCCTBooleanUnion(OCCTShapeRef a, OCCTShapeRef b)
{
  BRepAlgoAPI_Fuse fuse(a->shape, b->shape);
  return new OCCTShape(fuse.Shape());
}

#include <BRepPrimAPI_MakeBox.hxx>
struct OCCTBoxHolder
{
  int x;
};

/// Makes a box (BRepPrimAPI_MakeBox).
OCCTShapeRef OCCTShapeCreateBox(double w, double h, double d)
{
  BRepPrimAPI_MakeBox box(w, h, d);
  return new OCCTShape(box.Shape());
}

template <typename T>
static T identityFn(T x)
{
  return x;
}
"""
    tmp_dir = tempfile.mkdtemp()
    fixture_path = os.path.join(tmp_dir, "fixture.mm")
    with open(fixture_path, "w") as fh:
        fh.write(fixture)

    try:
        lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan(fixture_path)
        by_name = {n: b for _, n, b, *_ in plan}
        failures = []

        if unresolved:
            failures.append(f"fixture had unresolved units: {unresolved} (identityFn's "
                             f"template-prefixed static helper should have resolved)")

        if by_name.get("OCCTBooleanUnion") != "Boolean":
            failures.append(f"OCCTBooleanUnion classified {by_name.get('OCCTBooleanUnion')!r}, want Boolean")
        if by_name.get("OCCTShapeCreateBox") != "SolidPrimitives":
            failures.append(f"OCCTShapeCreateBox classified {by_name.get('OCCTShapeCreateBox')!r}, want SolidPrimitives")

        # struct OCCTBoxHolder must be scanned as its own code unit (not dropped, not merged into
        # a neighbour) -- this is the exact defect class the whole rewrite exists to catch -- and
        # must land in the SHARED bucket (every struct/static does, after the real build proved
        # single-bucket assignment wrong for three of them).
        names = [n for _, n, *_ in plan]
        if "OCCTBoxHolder" not in names:
            failures.append("struct OCCTBoxHolder was not captured as its own unit (the v1 defect)")
        elif by_name.get("OCCTBoxHolder") != "SHARED":
            failures.append(f"OCCTBoxHolder bucket is {by_name.get('OCCTBoxHolder')!r}, want SHARED")
        if by_name.get("helperFn") is not None and by_name.get("helperFn") != "SHARED":
            failures.append(f"helperFn (a static helper) bucket is {by_name.get('helperFn')!r}, want SHARED")

        # The scattered #include (the SECOND BRepPrimAPI_MakeBox.hxx, mid-file, not in the top
        # preamble) must be captured and folded into the shared preamble, not dropped; the SHARED
        # struct/static content (OCCTBoxHolder, identityFn) must also appear in the preamble now,
        # since it is no longer written into any single bucket file.
        shared_items = [p for p in plan if p[2] == "SHARED"]
        pre = preamble(lines, first_code_start, scattered, shared_items)
        if pre.count("BRepPrimAPI_MakeBox.hxx") < 1:
            failures.append("scattered mid-file #include was not folded into the preamble")
        if "struct OCCTBoxHolder" not in pre:
            failures.append("SHARED struct OCCTBoxHolder was not folded into the preamble")
        if "identityFn" not in pre:
            failures.append("SHARED static helper identityFn was not folded into the preamble")

        if len(scattered) < 1:
            failures.append("the mid-file #include was not detected as 'scattered' at all")

        # Full-line-coverage check must be clean on a well-formed fixture...
        uncovered, overcovered, orphaned = verify_full_coverage(lines, plan, unresolved, scattered, first_code_start)
        if uncovered or overcovered:
            failures.append(f"clean fixture reported uncovered={uncovered} overcovered={overcovered}")

        # ...and must FAIL LOUDLY if a unit is artificially removed from the plan (simulating the
        # v1 defect directly): drop OCCTBoxHolder's entry and re-check coverage.
        stripped_plan = [p for p in plan if p[1] != "OCCTBoxHolder"]
        unc2, ovc2, orph2 = verify_full_coverage(lines, stripped_plan, unresolved, scattered, first_code_start)
        if not unc2:
            failures.append("coverage check did NOT catch an artificially dropped struct (false negative)")

        if failures:
            for f in failures:
                print(f"SELF-TEST FAILURE: {f}")
            return 1
        print("SELF-TEST: OK (struct/class capture, scattered #include capture, template-prefixed "
              "function capture, and the coverage check's own drop-detection all correct)")
        return 0
    finally:
        shutil.rmtree(tmp_dir)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if args.write:
        return write_files()
    if args.verify:
        return verify()
    return report()


if __name__ == "__main__":
    sys.exit(main())
