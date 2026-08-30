#!/usr/bin/env python3
"""Generalized one-shot migration: split a large `Sources/OCCTBridge/src/OCCTBridge_<Domain>.mm`
into per-family `OCCTBridge_<Domain>_<Bucket>.mm` files, the same technique #396/#1378 proved out
on `OCCTBridge_Modeling.mm` (see `Scripts/repro/396-modeling-mm-split/`), generalized to take any
domain's file + taxonomy rather than being hardcoded to Modeling.

Does NOT touch `OCCTBridge_<Domain>.h`: the public C API surface is unchanged, every new .mm file
`#import`s the same shared header. Pure file-content reorganization.

## What's reused verbatim from the Modeling split, and why

The scanner (`scan_structural`), name/kind detection (`code_only`, `name_and_kind`), the mandatory
whole-file line-coverage check (`verify_full_coverage`), the SHARED-bucket design for every
struct/class/literal-`static` helper, and the preamble/write-files machinery are UNCHANGED from
`split_modeling_mm.py`. That script's own docstring documents four real, measured bugs the first
(pattern-matched, not structural) version had -- scattered #include capture, struct/class capture,
template-prefixed function capture, and external-linkage lowercase helpers wrongly bucketed SHARED
-- and this generalization does not re-litigate any of them: same scanner, same guards, only the
per-domain taxonomy varies.

## Per-domain configuration

Add an entry to `DOMAINS` below: `src` (the .mm filename stem, e.g. `"IO"`), `buckets` (ordered
list of bucket names), `bucket_desc` (one-line description per bucket, for the file header comment
and PR body), and the four classification tables (`name_prefix_bucket`, `body_package_to_bucket`,
`class_override_bucket`, `name_bucket_override`) built the same way the Modeling ones were: run
`--report`, inspect `UNCLASSIFIED`, add overrides, repeat until 0 unresolved and 0 unclassified.

    python3 split_bridge_mm.py --domain IO --report     # classification only, writes nothing
    python3 split_bridge_mm.py --domain IO --verify     # classification + full-file coverage
    python3 split_bridge_mm.py --domain IO --write      # creates the per-bucket files
    python3 split_bridge_mm.py --self-test              # domain-agnostic scanner/coverage self-test

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
SRC_DIR = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
OUT_DIR = SRC_DIR
PKG_PATH = os.path.join(ROOT, "Scripts", "occt-packages.txt")

GENERIC = {"gp", "TopoDS", "TopAbs", "Standard", "TColStd", "NCollection", "TDF", "TopExp",
           "TopTools", "gce", "Geom", "GeomAbs", "Poly", "Precision"}

PKG_TOKEN = re.compile(r'\b([A-Za-z][A-Za-z0-9]*)_[A-Za-z]')
CLASS_TOKEN = re.compile(r'\b([A-Za-z][A-Za-z0-9]*_[A-Za-z][A-Za-z0-9]*)\b')
NAME_IN_BLOCK = re.compile(r'\b(OCCT[A-Za-z0-9_]+)\s*[(;]')
STATIC_HELPER_NAME = re.compile(r'\b([a-z_][A-Za-z0-9_]*)\s*\(')
# `enum`/`enum class` at file scope is the same shape as struct/class for this purpose (a type
# used across the functions that reference it, so it must go SHARED rather than single-bucket) --
# first seen splitting OCCTBridge_Topology.mm's `enum class OCCTFindSurfaceWant`, a bare top-level
# enum, distinct from the enum-inside-an-anonymous-namespace case NAMESPACE_START/INNER_DECL
# already cover. Group 1 captures just "enum" (not "enum class") so kind stays a single token the
# same `kind in (...)` check downstream already tests against.
STRUCT_OR_CLASS = re.compile(r'^(?:static\s+)?(struct|class|enum)\s+(?:class\s+)?([A-Za-z_][A-Za-z0-9_]*)')
NAMESPACE_START = re.compile(r'^namespace\b')
INNER_DECL = re.compile(r'\b(?:struct|class|enum(?:\s+class)?)\s+([A-Za-z_][A-Za-z0-9_]*)')
# A bare file-scope `static [const|constexpr] <type> name = ...;` (or without initializer):
# distinguished from a `static` FUNCTION forward-declaration (STATIC_HELPER_NAME, above) by what
# follows the captured name -- `=`/`;` here, a call-shaped `(` there -- not by what's IN the type.
# The type's own character class includes `()`: OCCT's `Handle(X)` macro embeds parens even inside
# a template argument (`NCollection_List<Handle(Font_SystemFont)>`, OCCTBridge_Visualization.mm's
# `g_fontList`), which the original class (no `()`) couldn't get past to reach the real name.
STATIC_VAR = re.compile(r'^static\s+(?:const\s+|constexpr\s+)*[A-Za-z_][\w:<>,\s\*&()]*?\b'
                        r'([a-z_][A-Za-z0-9_]*)\s*[=;]')
# The `<...>`/`"..."` payload of a #include/#import line; preamble() takes just the trailing path
# segment of this (basename, dropping any leading directory) so `#import <Geom2d_BezierCurve.hxx>`
# and `#include "../foo/Geom2d_BezierCurve.hxx"` key identically for its dedup.
INCLUDE_KEY = re.compile(r'#\s*(?:include|import)\s*[<"]([^>"]+)[>"]')


def load_packages():
    return set(l.strip() for l in open(PKG_PATH) if l.strip() and not l.startswith("#"))


# ----------------------------------------------------------------------------------------------
# Structural scan: no per-declaration-shape pattern matching. Every line is one of blank / comment
# / include / other-preprocessor / part of a "code unit" delimited by brace depth. Domain-agnostic;
# unchanged from split_modeling_mm.py.
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
        if end < n and lines[end].strip() == ";":
            end += 1
        tokens.append(("code", start, end))
        i = end
    return lines, tokens


def code_only(block_text):
    lines = block_text.split("\n")
    i = 0
    while i < len(lines) and (lines[i].strip() == "" or lines[i].lstrip().startswith("//")):
        i += 1
    return "\n".join(lines[i:])


def strip_template_prefix(text):
    """Remove a leading `template <...>` (parameter list may span multiple lines -- OCCTBridge_
    Document.mm's occtDocumentGdtObjectAtImpl has five), returning what follows it, or `text`
    unchanged if it doesn't start with `template`. Non-greedy up to the first `>`, so a default
    template argument that itself contains angle brackets (`template <typename T =
    std::vector<int>>`) would stop early; no such case exists in this tree today. The single-line
    case (`template <typename T>`) that the original two-line-`join` version handled is a strict
    subset of this."""
    stripped = text.lstrip()
    if not stripped.startswith("template"):
        return text
    m = re.match(r'template\s*<.*?>', stripped, re.DOTALL)
    return stripped[m.end():].lstrip() if m else text


def name_and_kind(block_text):
    code = code_only(block_text)
    first_lines = code.split("\n", 3)
    if not first_lines or first_lines[0].strip() == "":
        return None, None
    probe = strip_template_prefix(code) if first_lines[0].strip().startswith("template") else first_lines[0]
    m = STRUCT_OR_CLASS.match(probe.strip()) or STRUCT_OR_CLASS.match(first_lines[0])
    if m:
        return m.group(1), m.group(2)
    # A `namespace { ... }` (anonymous, or named) block: not seen in the Modeling split (this file
    # has none), first seen splitting OCCTBridge_IO.mm -- twice, wrapping a class
    # (BridgeProgressIndicator) and a helper enum+function (osdPathComponent) respectively. Content
    # inside an anonymous namespace has no external linkage, same reasoning as a literal `static`,
    # so this always routes SHARED regardless of what's inside; the derived name is cosmetic
    # (report/dedup readability), not load-bearing, so a namespace with content this can't name at
    # all still gets a stable, if opaque, one rather than falling through to UNRESOLVED and forcing
    # a domain config to special-case it.
    if NAMESPACE_START.match(first_lines[0].strip()):
        inner = INNER_DECL.search(code) or NAME_IN_BLOCK.search(code) or STATIC_HELPER_NAME.search(code)
        derived = f"ns_{inner.group(1)}" if inner else f"ns_unnamed_{id(code) & 0xffff:x}"
        return "namespace", derived
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
    # Whether this signature is genuinely `static` decides SHARED-vs-single-bucket, and has to be
    # checked BEFORE picking a name pattern: NAME_IN_BLOCK (the OCCTXxx public-function shape) and
    # STATIC_HELPER_NAME (the lowercase internal-helper shape) are about NAME STYLE, not linkage,
    # and every prior split's internal helpers happened to use lowercase names, so checking
    # NAME_IN_BLOCK unconditionally first never crossed paths with a static one. OCCTBridge_
    # Visualization.mm's `static TopAbs_ShapeEnum OCCTModeToShapeEnum(...)` and
    # `static int32_t OCCTSelectorCollectResults(...)` are static helpers that happen to use the
    # OCCTXxx public-function NAMING STYLE anyway -- NAME_IN_BLOCK matched and returned kind="func"
    # before `static` was ever consulted, single-bucketing a SHARED helper and breaking every
    # OTHER caller's build once split, the same failure shape as Document's multi-line-template
    # miss, different mechanism.
    sig_after_template = strip_template_prefix(signature.lstrip())
    is_truly_static = re.match(r'^static\b', sig_after_template) is not None
    m = NAME_IN_BLOCK.search(signature)
    if m:
        return ("static" if is_truly_static else "func"), m.group(1)
    m = STATIC_HELPER_NAME.search(signature)
    if m:
        return ("static" if is_truly_static else "func"), m.group(1)
    # A bare `static <type> name = ...;` file-scope variable (no call-shaped `(`, so
    # STATIC_HELPER_NAME above never matches): OCCTBridge_Document.mm's
    # `static const int kAssemblyItemCountLimit = 100000;` is the first one this split hit.
    # Internal linkage, same reasoning as a `static` function -- routes SHARED.
    m = STATIC_VAR.match(signature.strip())
    if m:
        return "static", m.group(1)
    return None, None


# ----------------------------------------------------------------------------------------------
# Per-domain configuration.
# ----------------------------------------------------------------------------------------------

DOMAINS = {}  # populated by domain config modules imported below


def register_domain(key, **cfg):
    cfg.setdefault("name_prefix_bucket", [])
    cfg.setdefault("class_override_bucket", {})
    cfg.setdefault("name_bucket_override", {})
    DOMAINS[key] = cfg


# ----------------------------------------------------------------------------------------------
# Classification.
# ----------------------------------------------------------------------------------------------

def classify(cfg, name, body):
    if name in cfg["name_bucket_override"]:
        return cfg["name_bucket_override"][name]
    stripped = name[4:] if name.startswith("OCCT") else name
    for prefix, bucket in cfg["name_prefix_bucket"]:
        if prefix in stripped:
            return bucket
    class_counts = collections.Counter(CLASS_TOKEN.findall(body))
    for cls, _ in class_counts.most_common():
        if cls in cfg["class_override_bucket"]:
            return cfg["class_override_bucket"][cls]
    packages = classify.packages
    pkg_counts = collections.Counter()
    for m in PKG_TOKEN.finditer(body):
        pfx = m.group(1)
        if pfx in packages and pfx not in GENERIC:
            pkg_counts[pfx] += 1
    for top, _ in pkg_counts.most_common():
        if top in cfg["body_package_to_bucket"]:
            return cfg["body_package_to_bucket"][top]
    # A function whose body references only GENERIC-excluded types (bare TopoDS_Shape flag
    # accessors like Free()/Modified()/IsEdge() are the common case -- they reference nothing but
    # TopoDS_/TopAbs_/gp_) gets zero package votes and no name-prefix/class-override match either.
    # A domain whose content is genuinely dominated by one base subject (Topology's own
    # BRep_Tool-flavored general shape-query surface) can declare `default_bucket` rather than
    # forcing an explicit name_bucket_override for every such function -- IO declares none, so its
    # equivalent gap (OCCTFile*/OCCTStepHeader* etc.) still needed explicit overrides, which is
    # correct there: IO has no single dominant "everything else" subject the way Topology does.
    return cfg.get("default_bucket")


# ----------------------------------------------------------------------------------------------
# Plan assembly. Domain-agnostic.
# ----------------------------------------------------------------------------------------------

def check_config_bucket_references(cfg):
    """Every bucket a classification table can hand back must be a bucket write_files() actually
    visits, or a plan item silently vanishes: write_files() only iterates cfg['buckets'], so an
    item classified to a bucket string missing from that list (a stale reference after renaming
    or removing a bucket, or a plain typo) is dropped from every output file with no error --
    verify_full_coverage() does NOT catch this, since it marks a plan item's line range covered
    regardless of what its bucket value is. Found removing Document's own empty "TDF" bucket:
    BODY_PACKAGE_TO_BUCKET still mapped a package to it until this check would have caught the
    dangling reference. "SHARED" is always valid (handled separately, never in cfg['buckets'])."""
    valid = set(cfg["buckets"]) | {"SHARED"}
    bad = set()
    for bucket in cfg["body_package_to_bucket"].values():
        if bucket not in valid:
            bad.add(bucket)
    for _, bucket in cfg["name_prefix_bucket"]:
        if bucket not in valid:
            bad.add(bucket)
    for bucket in cfg["class_override_bucket"].values():
        if bucket not in valid:
            bad.add(bucket)
    for bucket in cfg["name_bucket_override"].values():
        if bucket not in valid:
            bad.add(bucket)
    default_bucket = cfg.get("default_bucket")
    if default_bucket is not None and default_bucket not in valid:
        bad.add(default_bucket)
    if bad:
        raise ValueError(f"domain {cfg['src']!r}: classification table(s) reference bucket(s) "
                         f"{sorted(bad)} not in cfg['buckets'] {cfg['buckets']} (and not SHARED) "
                         f"-- these items would be silently dropped by write_files()")


def build_plan(cfg, path=None):
    check_config_bucket_references(cfg)
    if path is None:
        path = os.path.join(SRC_DIR, f"OCCTBridge_{cfg['src']}.mm")
    classify.packages = load_packages()
    lines, tokens = scan_structural(path)

    raw_code_units = [(s, e) for kind, s, e in tokens if kind == "code"]
    first_code_start_raw = min(s for s, _ in raw_code_units) if raw_code_units else len(lines)

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
    scattered_includes = [i for kind, i, _ in tokens if kind == "include" and i >= first_code_start]

    plan = []
    unresolved = []
    unclassified = []
    for start, end in code_units:
        block = "\n".join(lines[start:end])
        kind, name = name_and_kind(block)
        if name is None:
            unresolved.append((start + 1, end - start, block.split("\n")[0]))
            continue
        if kind in ("struct", "class", "static", "namespace", "enum"):
            bucket = "SHARED"
        else:
            bucket = classify(cfg, name, block)
            if bucket is None:
                unclassified.append((kind, name, start + 1, end - start))
        plan.append((kind, name, bucket, start, end, block))

    return lines, plan, unresolved, unclassified, scattered_includes, first_code_start


def preamble(lines, first_code_start, scattered_include_lines, shared_items, issue_note):
    end = first_code_start
    while end > 0 and (lines[end - 1].lstrip().startswith("//") or lines[end - 1].strip() == ""):
        end -= 1
    raw_top = lines[:end]
    # Dedup by the HEADER NAME, not the raw line text: `#import <X.hxx>` and `#include <X.hxx>`
    # both include the same file (`#import` just adds an include-guard the header usually already
    # has), but are different strings, so a literal-text set misses this. Found splitting
    # OCCTBridge_Geom2d.mm (#1380/PR #1384's own Kilo review): the original file already had both
    # spellings for Geom2d_BezierCurve.hxx, ~500 lines apart, a harmless within-file redundancy --
    # but folding BOTH into the shared preamble replicated it into all 7 split files (2 -> 14
    # instances), which is what a text-only dedup could not catch. `INCLUDE_KEY` extracts the
    # `<...>`/`"..."` payload; first-seen spelling wins.
    #
    # Not just top-vs-scattered: the TOP block can duplicate itself too, and at real scale --
    # OCCTBridge_Curve3D.mm's own top preamble (everything before its first function, ~840 lines,
    # since this file's MARK comments sit well before any code) repeats an entire ~30-header block
    # nearly verbatim a few lines later, found in the same PR that added this dedup in the first
    # place. The original per-split behavior (#1378 onward) left `top` untouched on the theory that
    # only SCATTERED includes needed deduping; that theory only held for files whose top block was
    # itself already clean, which Curve3D's isn't. So `top` is filtered the same way `extra` is,
    # keeping first occurrence and dropping later ones, feeding the SAME `seen` set forward into
    # the scattered pass below.
    seen = set()
    top = []
    for l in raw_top:
        stripped = l.strip()
        m = INCLUDE_KEY.match(stripped) if stripped.startswith(("#include", "#import")) else None
        if m:
            key = m.group(1).rsplit("/", 1)[-1]
            if key in seen:
                continue
            seen.add(key)
        top.append(l)
    extra = []
    for i in scattered_include_lines:
        text = lines[i].strip()
        m = INCLUDE_KEY.match(text)
        key = m.group(1).rsplit("/", 1)[-1] if m else text
        if key not in seen:
            seen.add(key)
            extra.append(text)
    result = "\n".join(top)
    if extra:
        result += f"\n\n// Additional includes gathered from throughout the original file ({issue_note}):\n"
        result += "\n".join(extra)
    if shared_items:
        ordered = sorted(shared_items, key=lambda t: t[3])
        result += (f"\n\n// Shared private structs/helpers ({issue_note}): every split file gets this "
                   "identical block,\n// compiled independently per TU -- see this split's own README "
                   "for why.\n\n")
        result += "\n\n".join(block for kind, name, bucket, start, end2, block in ordered)
    return result


def report(cfg):
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan(cfg)
    by_bucket = collections.defaultdict(lambda: [0, 0])
    for kind, name, bucket, start, end, block in plan:
        if bucket is None:
            continue
        by_bucket[bucket][0] += 1
        by_bucket[bucket][1] += end - start
    print(f"{len(plan) + len(unresolved)} code units ({len(plan)} named, {len(unresolved)} "
          f"UNRESOLVED), {len(unclassified)} unclassified, {len(scattered)} scattered includes\n")
    for bucket in cfg["buckets"]:
        count, total_lines = by_bucket.get(bucket, (0, 0))
        print(f"  {bucket:22s} {count:4d} items  {total_lines:6d} lines")
    count, total_lines = by_bucket.get("SHARED", (0, 0))
    print(f"  {'SHARED (every file)':22s} {count:4d} items  {total_lines:6d} lines")
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


def verify(cfg):
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan(cfg)
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
              f"covered by NOTHING. First 20: {uncovered[:20]}")
        ok = False
    if overcovered:
        print(f"FAIL: {len(overcovered)} lines covered by MORE THAN ONE plan item. "
              f"First 20: {overcovered[:20]}")
        ok = False
    if orphaned:
        print(f"NOTE: {len(orphaned)} orphaned comment lines (old MARK dividers) will not appear "
              f"in any output file. Accepted, not a failure.")

    allowed_dups = set(cfg.get("allowed_duplicate_names", ()))
    dup_names = [n for n, c in collections.Counter(n for _, n, *_ in plan).items() if c > 1]
    real_dups = [n for n in dup_names if n not in allowed_dups]
    if real_dups:
        print(f"FAIL: duplicate names outside the configured allowed set: {real_dups}")
        ok = False

    if ok:
        print(f"OK: {len(plan)} code units, full-file line coverage exact (0 uncovered, "
              f"0 overcovered), no unexpected duplicate names")
    return 0 if ok else 1


FILE_HEADER_TEMPLATE = """\
//
//  OCCTBridge_{domain}_{suffix}.mm
//  OCCTSwift
//
//  Split from OCCTBridge_{domain}.mm ({issue_note}): {desc}.
//  Public C surface unchanged; every sibling file imports the same headers this one does
//  (the shared preamble below). No symbol changes, pure file move -- see
//  Scripts/repro/396-bridge-mm-split/ for how.
//

"""


def write_files(cfg):
    lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan(cfg)
    if unresolved or unclassified:
        print("REFUSING to write: unresolved or unclassified units present", file=sys.stderr)
        return 1
    if verify(cfg) != 0:
        print("REFUSING to write: verify() failed", file=sys.stderr)
        return 1

    shared_items = [p for p in plan if p[2] == "SHARED"]
    pre = preamble(lines, first_code_start, scattered, shared_items, cfg["issue_note"])
    by_bucket = collections.defaultdict(list)
    for kind, name, bucket, start, end, block in plan:
        if bucket == "SHARED":
            continue
        by_bucket[bucket].append((start, block))

    domain = cfg["src"]
    header = cfg.get("header", domain)
    for bucket in cfg["buckets"]:
        items_here = sorted(by_bucket.get(bucket, []), key=lambda t: t[0])
        if not items_here:
            print(f"  (skipping {bucket}: 0 items)")
            continue
        file_header = FILE_HEADER_TEMPLATE.format(domain=domain, suffix=bucket,
                                                    issue_note=cfg["issue_note"],
                                                    desc=cfg["bucket_desc"][bucket], header=header)
        body = "\n\n".join(block for _, block in items_here)
        out_path = os.path.join(OUT_DIR, f"OCCTBridge_{domain}_{bucket}.mm")
        with open(out_path, "w") as fh:
            fh.write(file_header + pre + "\n\n" + body + "\n")
        print(f"  wrote {out_path} ({len(items_here)} items)")
    return 0


def self_test():
    """Domain-agnostic: proves the scanner/coverage machinery, not any particular domain's
    taxonomy (each domain's own --report/--verify run is that domain's evidence)."""
    import tempfile
    import shutil

    fixture = """\
//
//  fixture header
//
#import "x.h"
#include <BRepPrimAPI_MakeBox.hxx>
#include <TopoDS_Shape.hxx>
#import <TopoDS_Shape.hxx>

// A boolean helper.
static bool helperFn(int x) { return x > 0; }

// Fuses two shapes (BRepAlgoAPI_Fuse).
OCCTShapeRef OCCTBooleanUnion(OCCTShapeRef a, OCCTShapeRef b)
{
  BRepAlgoAPI_Fuse fuse(a->shape, b->shape);
  return new OCCTShape(fuse.Shape());
}

#include <BRepPrimAPI_MakeBox.hxx>
#import <BRepPrimAPI_MakeBox.hxx>
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

// An anonymous namespace (not present in the Modeling split; first seen splitting
// OCCTBridge_IO.mm's BridgeProgressIndicator/osdPathComponent helpers).
namespace
{
class NamespacedHelper
{
public:
  int value;
};
} // namespace

// Uses BRepPrimAPI_MakeBox so it classifies SolidPrimitives without a new override.
OCCTShapeRef OCCTUsesNamespacedHelper(OCCTShapeRef a)
{
  NamespacedHelper h;
  BRepPrimAPI_MakeBox box(1, 1, 1);
  return a;
}

// References only GENERIC-excluded types (TopoDS_/gp_), so it gets zero package votes -- the
// #1380 gap (bare TopoDS_Shape flag accessors) `default_bucket` exists to cover.
bool OCCTShapeIsFreeFixture(OCCTShapeRef a)
{
  return a->shape.Free();
}

// A bare top-level `enum class` (not inside a namespace) -- the #1380 gap
// (OCCTFindSurfaceWant) NAMESPACE_START/INNER_DECL alone don't cover.
enum class OCCTFixtureWant
{
  A,
  B
};

int OCCTUsesFixtureWant(OCCTFixtureWant w)
{
  return static_cast<int>(w);
}

// A bare file-scope static variable, no call-shaped parentheses at all -- the #1380 gap
// (OCCTBridge_Document.mm's kAssemblyItemCountLimit) STATIC_HELPER_NAME alone doesn't cover.
static const int kFixtureLimit = 100000;

int OCCTUsesFixtureLimit(void)
{
  return kFixtureLimit;
}

// A template whose parameter list spans MULTIPLE lines (not the single-line `template
// <typename T>` case above) -- the #1380 gap (OCCTBridge_Document.mm's
// occtDocumentGdtObjectAtImpl, a 5-line template parameter list) that made a genuinely SHARED
// helper get misclassified into one caller's bucket, breaking every OTHER caller's build.
template <typename A,
         typename B,
         typename C>
static bool multiLineTemplateFn(A a, B b, C c)
{
  return true;
}

OCCTShapeRef OCCTUsesMultiLineTemplateFn(OCCTShapeRef a)
{
  multiLineTemplateFn<int, int, int>(1, 2, 3);
  BRepPrimAPI_MakeBox box(1, 1, 1);
  return a;
}

// A static variable whose TYPE embeds parentheses (OCCT's `Handle(X)` macro inside a template
// argument) -- the #1380 gap (OCCTBridge_Visualization.mm's g_fontList) STATIC_VAR's original
// paren-free character class couldn't get past.
static NCollection_List<Handle(Standard_Transient)> g_fixtureList;

int OCCTUsesFixtureList(void)
{
  return g_fixtureList.Size();
}

// A `static` helper using the OCCTXxx PUBLIC-function naming style, not this codebase's usual
// lowercase internal-helper style -- the #1380 gap (OCCTBridge_Visualization.mm's
// OCCTModeToShapeEnum/OCCTSelectorCollectResults) that made NAME_IN_BLOCK (checked before static-
// ness) claim it as a single-bucket public function and break every OTHER caller once split.
static int OCCTFixtureStaticHelper(int x)
{
  return x + 1;
}

OCCTShapeRef OCCTCallsFixtureStaticHelper(OCCTShapeRef a)
{
  OCCTFixtureStaticHelper(1);
  BRepPrimAPI_MakeBox box(1, 1, 1);
  return a;
}
"""
    tmp_dir = tempfile.mkdtemp()
    fixture_path = os.path.join(tmp_dir, "fixture.mm")
    with open(fixture_path, "w") as fh:
        fh.write(fixture)

    cfg = dict(
        src="Fixture", header="Fixture", issue_note="#396/#1378-generalization",
        buckets=["Boolean", "SolidPrimitives"],
        bucket_desc={"Boolean": "BRepAlgoAPI", "SolidPrimitives": "BRepPrimAPI"},
        default_bucket="SolidPrimitives",
        name_prefix_bucket=[],
        body_package_to_bucket={"BRepAlgoAPI": "Boolean", "BRepPrimAPI": "SolidPrimitives"},
        class_override_bucket={}, name_bucket_override={},
    )

    try:
        lines, plan, unresolved, unclassified, scattered, first_code_start = build_plan(cfg, fixture_path)
        by_name = {n: b for _, n, b, *_ in plan}
        failures = []

        if unresolved:
            failures.append(f"fixture had unresolved units: {unresolved}")
        if by_name.get("OCCTBooleanUnion") != "Boolean":
            failures.append(f"OCCTBooleanUnion classified {by_name.get('OCCTBooleanUnion')!r}, want Boolean")
        if by_name.get("OCCTShapeCreateBox") != "SolidPrimitives":
            failures.append(f"OCCTShapeCreateBox classified {by_name.get('OCCTShapeCreateBox')!r}, want SolidPrimitives")
        if by_name.get("OCCTUsesNamespacedHelper") != "SolidPrimitives":
            failures.append(f"OCCTUsesNamespacedHelper classified {by_name.get('OCCTUsesNamespacedHelper')!r}, want SolidPrimitives")
        if by_name.get("OCCTShapeIsFreeFixture") != "SolidPrimitives":
            failures.append(f"OCCTShapeIsFreeFixture (GENERIC-only body) classified "
                             f"{by_name.get('OCCTShapeIsFreeFixture')!r}, want SolidPrimitives via default_bucket")
        if by_name.get("OCCTFixtureWant") != "SHARED":
            failures.append(f"bare top-level enum class OCCTFixtureWant classified "
                             f"{by_name.get('OCCTFixtureWant')!r}, want SHARED (not captured at all if None)")
        if by_name.get("kFixtureLimit") != "SHARED":
            failures.append(f"bare static variable kFixtureLimit classified "
                             f"{by_name.get('kFixtureLimit')!r}, want SHARED (not captured at all if None)")
        if by_name.get("multiLineTemplateFn") != "SHARED":
            failures.append(f"multi-line-template static helper classified "
                             f"{by_name.get('multiLineTemplateFn')!r}, want SHARED "
                             f"(a real caller-bucket misclassification, not just cosmetic)")
        if by_name.get("g_fixtureList") != "SHARED":
            failures.append(f"static variable with a paren-embedding type classified "
                             f"{by_name.get('g_fixtureList')!r}, want SHARED "
                             f"(not captured at all if None)")
        if by_name.get("OCCTFixtureStaticHelper") != "SHARED":
            failures.append(f"static helper using OCCTXxx public-function naming classified "
                             f"{by_name.get('OCCTFixtureStaticHelper')!r}, want SHARED "
                             f"(a real caller-bucket misclassification, not just cosmetic)")

        names = [n for _, n, *_ in plan]
        ns_names = [n for n in names if n.startswith("ns_")]
        if not ns_names:
            failures.append("the anonymous `namespace { class NamespacedHelper ... }` block was "
                             "not captured as its own unit at all (would show as UNRESOLVED)")
        elif by_name.get(ns_names[0]) != "SHARED":
            failures.append(f"namespace block bucket is {by_name.get(ns_names[0])!r}, want SHARED")
        elif "NamespacedHelper" not in ns_names[0]:
            failures.append(f"namespace block's derived name {ns_names[0]!r} did not pick up the "
                             f"inner class name (cosmetic, but a sign the inner search regressed)")

        names = [n for _, n, *_ in plan]
        if "OCCTBoxHolder" not in names:
            failures.append("struct OCCTBoxHolder was not captured as its own unit (the v1 defect)")
        elif by_name.get("OCCTBoxHolder") != "SHARED":
            failures.append(f"OCCTBoxHolder bucket is {by_name.get('OCCTBoxHolder')!r}, want SHARED")
        if by_name.get("helperFn") is not None and by_name.get("helperFn") != "SHARED":
            failures.append(f"helperFn bucket is {by_name.get('helperFn')!r}, want SHARED")

        shared_items = [p for p in plan if p[2] == "SHARED"]
        pre = preamble(lines, first_code_start, scattered, shared_items, cfg["issue_note"])
        if pre.count("BRepPrimAPI_MakeBox.hxx") < 1:
            failures.append("scattered mid-file #include was not folded into the preamble")
        # The fixture has BRepPrimAPI_MakeBox.hxx three times: the top-preamble #include, an
        # exact-text-duplicate scattered #include, and a scattered #import of the same header --
        # a different spelling, not a different header. All three must collapse to ONE mention.
        if pre.count("BRepPrimAPI_MakeBox.hxx") != 1:
            failures.append(f"#import and #include of the same header did not dedup together: "
                             f"{pre.count('BRepPrimAPI_MakeBox.hxx')} mentions in the preamble, want 1")
        # TopoDS_Shape.hxx is duplicated WITHIN the top block itself (#include then #import, both
        # before the first code unit) -- the Curve3D shape (#1380's own Kilo review round 2): a
        # file whose top preamble is itself internally duplicated, not just top-vs-scattered.
        if pre.count("TopoDS_Shape.hxx") != 1:
            failures.append(f"top-block-internal #include/#import duplicate was not deduped: "
                             f"{pre.count('TopoDS_Shape.hxx')} mentions in the preamble, want 1")
        if "struct OCCTBoxHolder" not in pre:
            failures.append("SHARED struct OCCTBoxHolder was not folded into the preamble")
        if "identityFn" not in pre:
            failures.append("SHARED static helper identityFn was not folded into the preamble")
        if len(scattered) < 1:
            failures.append("the mid-file #include was not detected as 'scattered' at all")

        uncovered, overcovered, orphaned = verify_full_coverage(lines, plan, unresolved, scattered, first_code_start)
        if uncovered or overcovered:
            failures.append(f"clean fixture reported uncovered={uncovered} overcovered={overcovered}")

        stripped_plan = [p for p in plan if p[1] != "OCCTBoxHolder"]
        unc2, ovc2, orph2 = verify_full_coverage(lines, stripped_plan, unresolved, scattered, first_code_start)
        if not unc2:
            failures.append("coverage check did NOT catch an artificially dropped struct (false negative)")

        # check_config_bucket_references(): a dangling bucket reference (a classification table
        # pointing at a bucket string missing from cfg['buckets'], e.g. after renaming or removing
        # a bucket) must be caught loudly -- write_files() would otherwise silently drop every item
        # classified to it, and verify_full_coverage() can't see this since it only checks that a
        # plan item's LINE RANGE is covered, not that its bucket is real. Found live: removing
        # Document's own empty "TDF" bucket while BODY_PACKAGE_TO_BUCKET still mapped a package to
        # it (#1380's own Document PR).
        bad_cfg = dict(cfg, body_package_to_bucket=dict(cfg["body_package_to_bucket"],
                                                        BRepAlgoAPI="NoSuchBucket"))
        try:
            build_plan(bad_cfg, fixture_path)
            failures.append("check_config_bucket_references did NOT catch a dangling "
                             "body_package_to_bucket reference to a bucket not in cfg['buckets']")
        except ValueError:
            pass  # expected

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
    ap.add_argument("--domain", choices=sorted(DOMAINS.keys()) or None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if not args.domain:
        print("error: --domain is required (unless --self-test)", file=sys.stderr)
        print(f"known domains: {sorted(DOMAINS.keys())}", file=sys.stderr)
        return 2
    cfg = DOMAINS[args.domain]
    if args.write:
        return write_files(cfg)
    if args.verify:
        return verify(cfg)
    return report(cfg)


# Domain configs are registered by importing the sibling `domains/` package, so this file stays
# generic; each domain's config lives in its own module (easier to review/diff per domain). Alias
# this running module under its own filename in sys.modules FIRST: when this file is run directly
# (`python3 split_bridge_mm.py`), its module name is `__main__`, and each domain module's own
# `from split_bridge_mm import register_domain` would otherwise re-import this file as a SECOND,
# independent module object with its own empty DOMAINS -- registering into a dict main() never
# reads from, and `DOMAINS[args.domain]` failing with a KeyError despite --report having "worked".
# Measured, not hypothetical: this is exactly what happened on the first run.
sys.modules.setdefault("split_bridge_mm", sys.modules[__name__])
sys.path.insert(0, HERE)
import domains  # noqa: E402  (populates DOMAINS via register_domain)

if __name__ == "__main__":
    sys.exit(main())
