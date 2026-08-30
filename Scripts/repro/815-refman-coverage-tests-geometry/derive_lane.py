#!/usr/bin/env python3
"""#815 (Pass 5a of #807): derive the geometry-primitives TEST lane, by call.

WHY THIS SCRIPT EXISTS AT ALL, AND WHY IT DOES MORE THAN ITS THREE SIBLINGS
(`Scripts/repro/811-refman-coverage-features`, `812-refman-coverage-drawing`,
`813-refman-coverage-export-interop`).

Those three passes audit SOURCE against the refman: their `## Lane` names OCCT packages
directly (`BRepFeat_`, `BRepFilletAPI_`, ...), so `derive_lane.py` only has to reconcile that
list against the Swift files that actually call into it. Pass 5a's lane is different in kind:
#815 names four Swift TEST TARGETS (`OCCTCurveTests`, `OCCTGeom2dTests`, `OCCTSurfaceTests`,
`OCCTMathTests`), and #815 itself says to mirror "Pass 1a's source surface" -- #380, the
geometry-primitives duplication audit. But #380 was a DUPLICATION audit, not a refman-coverage
one (see its own issue body: "for accidental code/doc duplication ... reimplemented helpers,
copy-pasted math, drifted doc comments"), so unlike Pass 4a/4b/4c there is no committed
"documented?/wrapped?" class table for this lane to inherit. This script IS that missing
derivation, run twice:

  STEP 1: which Swift types in `Sources/OCCTSwift` are actually the geometry-primitives
          surface these four test targets exercise. NOT #380's 16-file list taken on faith:
          two of those files fail this test outright (see below), and the test targets reach
          well past that list (`MathSolver`, `MathLibrary`'s six math_* facades, `GeomPrimitives`'s
          five gp_-backed classes, `Continuity`'s three enums, `ElLib`, `Interval`, `Quaternion`,
          `TransformFactory`, `VectorMath`, `TrigRoots`, ... none of which #380 named).

  STEP 2: for each such Swift type, every `OCCT*` bridge function its own body calls, resolved
          to the OCCT class(es) each bridge function reaches (reusing `check-bridge-index.py`'s
          `reachable()` rather than re-deriving reachability a third time, per
          `search-before-building`), filtered to real OCCT classes via the same
          `Scripts/occt-packages.txt` manifest `census-doc-occt-attribution.py` uses.

THE DERIVATION RULE, mechanical rather than a hand-picked file list:

    for every `public [final] class|struct|enum TypeName` declared at file scope in
    Sources/OCCTSwift:
        count occurrences of `\\bTypeName\\b` in each of the 18 test targets' own source
        primary = the target with the (STRICTLY unique) highest count
        if primary in {OCCTCurveTests, OCCTGeom2dTests, OCCTSurfaceTests, OCCTMathTests}
           and total >= 2:
               TypeName is in this lane, owned by `primary`

A strict, un-tied maximum, not a majority share: `SurfaceGrid` is 3/2/1 across three targets
(50% short of a majority) and is still unambiguously OCCTSurfaceTests' own type. The one case
this DID exclude on the real tree is `Polygon2D` (`MeshTypes.swift`), tied 3-3 between
OCCTGeom2dTests and OCCTMeshTests: a genuine tie is reported as ambiguous rather than broken
arbitrarily by dict ordering, and `MeshTypes.swift` is correctly not part of this lane (its
primary type, `TangentialDeflectionPoint`, does not even reach 2 total).

TWO FILES #380 NAMED AND THIS DERIVATION DROPS, MEASURED RATHER THAN ASSERTED:

  - `BRepGraph.swift` / `BRepGraph+Attributes.swift`: `BRepGraph`'s primary owner is
    `OCCTBRepGraphTests` (361 of 467 references), which has its own dedicated test target and
    is not one of #815's four. It is the Shape/Topology-adjacent graph-of-faces layer, not a
    geometry primitive by this measurement, and its test-side audit belongs to Pass 5b (#807's
    own sub-issue for Shape/Topology), not here.
  - `MedialAxis.swift`: primary owner is `OCCTAnalysisTests` (21 of 28), which is not named by
    ANY Pass 5 sub-issue. Flagged, not silently dropped: see `--gaps` below.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py
    python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --members
    python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --classes
    python3 Scripts/repro/815-refman-coverage-tests-geometry/derive_lane.py --gaps
"""

from __future__ import annotations

import argparse
import collections
import importlib.util
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
TESTS_DIR = os.path.join(ROOT, "Tests")
SCRIPTS_DIR = os.path.join(ROOT, "Scripts")
PACKAGE_MANIFEST = os.path.join(SCRIPTS_DIR, "occt-packages.txt")

LANE_TARGETS = ["OCCTCurveTests", "OCCTGeom2dTests", "OCCTSurfaceTests", "OCCTMathTests"]
MIN_TOTAL = 2  # below this a hit is likelier a stray fixture reference than real ownership


def read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


# ------------------------------------------------------------------------------------------------
# OCCT package manifest, same file and same two-section format census-doc-occt-attribution.py (#928)
# reads. Reimplemented rather than imported: that module's `load_packages` is a four-line function
# and importing the whole file via importlib (as this script does for `reachable()`, below, where
# there IS no small alternative) would run its argparse/self-test scaffolding for no benefit.
# ------------------------------------------------------------------------------------------------

def load_packages() -> tuple[set[str], set[str]]:
    prefixes, bare = set(), set()
    section = None
    for line in read(PACKAGE_MANIFEST).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            if line.startswith("# ["):
                section = line[3:-1]
            continue
        (prefixes if section == "prefixes" else bare).add(line)
    return prefixes, bare


def is_occt_class(tok: str, prefixes: set[str], bare: set[str]) -> bool:
    if tok in bare:
        return True
    if "_" in tok:
        return tok.split("_", 1)[0] in prefixes
    return False


# ------------------------------------------------------------------------------------------------
# `check-bridge-index.py`'s primitives (`definitions()`, `domain_group()`, `source_files()`) are
# reused rather than re-derived a third time in this repo (#811/#928 already made a version of this
# call each). Its own `reachable()`, the thing #811/#928 actually called, is DELIBERATELY NOT
# reused here, and that took a real, measured defect to find rather than a taste call.
#
# `reachable()` is a two-step closure: (1) a function reaches what its own wrapper-struct field
# holds (`OCCTCurve3DRef` -> `Geom_Curve`, via the `types` table) -- safe, and kept below -- then
# (2) a function reaches what ANY bare identifier in its own body ALSO happens to name, if that
# name is a function or type defined ANYWHERE else in the bridge (its own docstring: "a local
# variable sharing a name with a helper drags that helper's whole reach in"). #811/#928 measured
# that step as an ACCEPTABLE cost for their own question (a permissive "could this claim be true"
# existence check, where over-approximating only hides a real over-coverage finding, never
# invents one). For #815 the direction is reversed: this lane wants ONE class table this member
# actually represents, not everything it could conceivably be confused for.
#
# MEASURED, not assumed, that step (2) is unsound here: `OCCTShapeConstructAdjustCurve3D`
# (`OCCTBridge_Curve3D_Conversion.mm`), backing `Curve3D.adjustEndpoints`, has a five-line body
# constructing exactly `ShapeConstruct_Curve` and `gp_Pnt` -- nothing OCAF-related anywhere near
# it. `reachable()` nonetheless resolves it to 78 names including `TDocStd_Document`,
# `XCAFDoc_ShapeTool`, `TDF_Label`, `TNaming_Scope`. Traced with a standalone harness
# (`Scripts/repro/815-refman-coverage-tests-geometry/`'s own dev history, not committed): the
# wrapper struct `OCCTCurve3D` declares its held curve as `Handle(Geom_Curve) curve;`, so the bare
# token `Handle` -- OCCT's own smart-pointer macro, used in nearly every bridge function that
# touches a `Geom_*`/`TopoDS_*` handle -- lands in this function's name set via step (1). Step (2)
# then asks "is `Handle` also the NAME of some function or type defined anywhere in the bridge",
# and `OCCTBridge_Internal.h` happens to define an unrelated OCAF helper literally called
# `Handle(...)`, whose own reach is the 78-name OCAF cluster above. Since `Handle(...)` is one of
# the single most common tokens in this entire codebase, this is not a one-off: it would
# potentially contaminate every function that names a `Handle`d type anywhere in its own body,
# which is most of the bridge. Reusing `reachable()` unmodified here would have shipped a class
# table where a `Curve3D` method reads as reaching `XCAFDoc_ShapeTool`, an error a reviewer would
# have caught immediately and, rightly, would have discredited the whole table.
#
# So this keeps step (1) (the wrapper-holds-class expansion: genuinely useful, and the ONLY reason
# `Geom_Curve`/`Geom_Surface`/`Geom2d_Curve` show up for methods whose own body never spells the
# class name, only the bridge's own opaque `OCCTCurve3DRef`-style handles) and drops step (2)
# entirely. The cost is real and stated in the README: a class reached ONLY through a same-file
# helper by name (not by wrapper field) is missed here, where `reachable()` would have found it.
# That is a narrower, LESS permissive table, which is the correct direction to err for a "what
# does this member actually represent" question, the opposite of #811/#928's own tradeoff.
# ------------------------------------------------------------------------------------------------

def _load_cbi():
    spec = importlib.util.spec_from_file_location(
        "_cbi_815", os.path.join(SCRIPTS_DIR, "check-bridge-index.py")
    )
    cbi = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cbi)
    return cbi


def bridge_reach() -> dict[str, set[str]]:
    cbi = _load_cbi()
    cwd = os.getcwd()
    os.chdir(ROOT)
    try:
        per_file: dict[str, dict[str, set[str]]] = {}
        types: dict[str, set[str]] = collections.defaultdict(set)
        for path in cbi.source_files():
            fns: dict[str, set[str]] = {}
            for kind, name, names in cbi.definitions(path):
                if kind == "type":
                    types[name] |= names
                else:
                    fns.setdefault(name, set()).update(names)
            group = cbi.domain_group(os.path.basename(path))
            target = per_file.setdefault(group, {})
            for name, names in fns.items():
                target.setdefault(name, set()).update(names)

        # Step (1) only: a function reaches what its own wrapper-struct field holds.
        for fns in per_file.values():
            for names in fns.values():
                for t in list(names):
                    base = t[:-3] if t.endswith("Ref") else t
                    if base in types:
                        names |= types[base]

        merged: dict[str, set[str]] = collections.defaultdict(set)
        for fns in per_file.values():
            for name, names in fns.items():
                merged[name] |= names
        return merged
    finally:
        os.chdir(cwd)


# ------------------------------------------------------------------------------------------------
# Step 1: which Swift types this lane owns
# ------------------------------------------------------------------------------------------------

TYPE_DECL_RE = re.compile(r'^public\s+(?:final\s+)?(?:class|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)',
                          re.M)


def all_test_targets() -> list[str]:
    return sorted(d for d in os.listdir(TESTS_DIR) if os.path.isdir(os.path.join(TESTS_DIR, d)))


def _target_text(targets: list[str]) -> dict[str, str]:
    out = {}
    for t in targets:
        tdir = os.path.join(TESTS_DIR, t)
        buf = []
        for dirpath, _dirs, files in os.walk(tdir):
            for fn in sorted(files):
                if fn.endswith(".swift"):
                    buf.append(read(os.path.join(dirpath, fn)))
        out[t] = "\n".join(buf)
    return out


def derive_lane_types():
    """(lane_types, ambiguous, all_types) -- see module docstring for the rule.

    lane_types: list of dict(type, file, target, total, counts)
    ambiguous: types with a tied maximum, reported not silently dropped
    all_types: every (type, file) this repo declares, for --gaps below
    """
    targets = all_test_targets()
    target_text = _target_text(targets)

    all_types = []
    for fn in sorted(os.listdir(SWIFT_DIR)):
        if not fn.endswith(".swift") or "+" in fn:
            continue
        src = read(os.path.join(SWIFT_DIR, fn))
        for ty in TYPE_DECL_RE.findall(src):
            all_types.append((ty, fn))

    lane_types, ambiguous = [], []
    for ty, fn in all_types:
        pat = re.compile(r'\b' + re.escape(ty) + r'\b')
        counts = {t: len(pat.findall(target_text[t])) for t in targets if pat.search(target_text[t])}
        total = sum(counts.values())
        if total < MIN_TOTAL:
            continue
        top = max(counts.values())
        winners = [t for t, n in counts.items() if n == top]
        if len(winners) > 1:
            ambiguous.append({"type": ty, "file": fn, "counts": counts})
            continue
        primary = winners[0]
        if primary in LANE_TARGETS:
            lane_types.append({"type": ty, "file": fn, "target": primary, "total": total,
                               "counts": counts})
    return lane_types, ambiguous, all_types


# ------------------------------------------------------------------------------------------------
# Step 2: per lane type, the OCCT* bridge calls its own body makes, and the OCCT classes those
# bridge functions reach.
# ------------------------------------------------------------------------------------------------

def strip_swift_comments(text: str) -> str:
    text = re.sub(r'/\*.*?\*/', ' ', text, flags=re.S)
    text = re.sub(r'//[^\n]*', ' ', text)
    text = re.sub(r'"""(?:.|\n)*?"""', ' ', text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', ' ', text)
    return text


def _brace_span(text: str, start: int) -> str:
    """Balanced `{`...`}` starting at `text[start] == '{'`."""
    depth, i = 0, start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
        i += 1
    return text[start:]


def type_body(text: str, type_name: str) -> str | None:
    """The brace-balanced span of `type_name`'s own declaration, `{` to matching `}`."""
    pat = re.compile(r'^public\s+(?:final\s+)?(?:class|struct|enum)\s+' + re.escape(type_name)
                     + r'\b', re.M)
    m = pat.search(text)
    if not m:
        return None
    start = text.find("{", m.end())
    return _brace_span(text, start) if start != -1 else None


# `public struct <Name>: ... NativeHandleView ... { ... }` DECLARED INSIDE an extension of a lane
# type (`Curve2D.CircleProperties`, `Curve3D.EllipseProperties`, `Surface.SphereProperties`, ...).
# `derive_lane_types()`'s file-scope-only scan cannot see these: they sit one level deeper than
# `^public struct` allows, inside an `extension Curve2D { public struct CircleProperties { ... } }`
# block, so `type_members()` correctly does NOT attribute their members to `Curve2D` itself (they
# ARE a distinct nested type, accessed as `curve.circleProperties.radius`, not `curve.radius`) --
# but nothing else picked them up either, and MEASURED, not assumed: `Curve2D` alone carries 7 of
# these (`CircleProperties`, `EllipseProperties`, `HyperbolaProperties`, `ParabolaProperties`,
# `LineProperties`, `OffsetProperties`, `BezierProperties`), `Curve3D` 5, `Surface` 6, for 31 total
# in the whole tree via `grep -c 'public struct.*: .*NativeHandleView'`. Extracted separately here
# and folded into `lane_members()` under a compound name (`Curve2D.CircleProperties`) sharing the
# outer type's owning target, since a bare property-view struct exists only as an accessor on its
# owner and was never going to have its own primary test-target ownership to derive independently.
NESTED_VIEW_RE = re.compile(
    r'public\s+struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:[^{\n]*NativeHandleView[^{\n]*\{')


def nested_view_bodies(body: str) -> list[tuple[str, str]]:
    out = []
    for m in NESTED_VIEW_RE.finditer(body):
        start = m.end() - 1
        out.append((m.group(1), _brace_span(body, start)))
    return out


EXTENSION_RE_CACHE: dict[str, re.Pattern] = {}


def extension_bodies(text: str, type_name: str) -> list[str]:
    """Every `extension TypeName ... { ... }` block's body, brace-balanced. A bare conformance
    extension (`extension Curve3D: NativeHandleOwner {}`) yields an empty body, harmless: it has
    no members for `type_members` to find."""
    pat = EXTENSION_RE_CACHE.setdefault(
        type_name, re.compile(r'^extension\s+' + re.escape(type_name) + r'\b[^\n{]*\{', re.M))
    out = []
    for m in pat.finditer(text):
        start = m.end() - 1
        out.append(_brace_span(text, start))
    return out


def all_bodies_for_type(swift_texts: dict[str, str], type_name: str, decl_file: str) -> list[tuple[str, str]]:
    """(file, body) for the type's own declaration plus every extension of it anywhere in
    `Sources/OCCTSwift`. #815's own measurement of why this matters: `Curve3D`'s primary class body
    holds 49 top-level members; the type ALSO carries 39 `extension Curve3D { ... }` blocks, all in
    `Curve3D.swift` itself, plus a real one in `ShapeAxis.swift` for `Surface` (`NativeHandleView.swift`'s
    three are bare protocol conformances, `extension X: NativeHandleOwner {}`, and correctly
    contribute zero members). A census that only read the primary declaration would silently drop
    most of this lane's real API surface, and every finding drawn from it would be about the wrong,
    much smaller, subset."""
    bodies = []
    primary = type_body(swift_texts[decl_file], type_name)
    if primary:
        bodies.append((decl_file, primary))
    for fn, text in swift_texts.items():
        for body in extension_bodies(text, type_name):
            bodies.append((fn, body))
    return bodies


OCCT_TOKEN_RE = re.compile(r'\bOCCT[A-Za-z0-9_]*')


def bridge_calls_in(body: str) -> set[str]:
    return set(OCCT_TOKEN_RE.findall(strip_swift_comments(body)))


def all_swift_texts() -> dict[str, str]:
    out = {}
    for fn in sorted(os.listdir(SWIFT_DIR)):
        if fn.endswith(".swift"):
            out[fn] = read(os.path.join(SWIFT_DIR, fn))
    return out


def lane_class_table(lane_types, reach: dict[str, set[str]], prefixes, bare, swift_texts=None):
    """OCCT class -> {'types': {...}, 'via': {bridge_fn: {classes}}}. Reads the primary declaration
    AND every extension (see `all_bodies_for_type`)."""
    swift_texts = swift_texts if swift_texts is not None else all_swift_texts()
    class_table: dict[str, dict] = {}
    per_type_calls = {}
    for entry in lane_types:
        bodies = all_bodies_for_type(swift_texts, entry["type"], entry["file"])
        calls: set[str] = set()
        for _fn, body in bodies:
            calls |= bridge_calls_in(body)
        resolved = sorted(c for c in calls if c in reach)
        unresolved = sorted(c for c in calls if c not in reach)
        per_type_calls[entry["type"]] = {"resolved": resolved, "unresolved": unresolved}
        for bridge_fn in resolved:
            classes = {n for n in reach[bridge_fn] if is_occt_class(n, prefixes, bare)}
            for cls in classes:
                rec = class_table.setdefault(cls, {"types": set(), "via": collections.defaultdict(set)})
                rec["types"].add(entry["type"])
                rec["via"][bridge_fn].add(entry["type"])
    return class_table, per_type_calls


# ------------------------------------------------------------------------------------------------
# Member-level parsing. #815's own question ("an OCCT behaviour ... which no test exercises") is
# finer than "is this TYPE tested": `Curve3D` is exercised 481 times in `OCCTCurveTests` and that
# tells you nothing about whether any one of its ~90 members is. This is the piece #811/#812/#813
# did not need (they classify at class granularity throughout, because their question -- wrapped
# vs documented -- IS a class-level question). Reused for both the `tested` axis of the class
# census AND, on its own, as the substrate for the deeper member-level spot-check the README
# describes.
# ------------------------------------------------------------------------------------------------

MEMBER_DECL_RE = re.compile(
    r'^\s*public\s+(?P<static>static\s+)?(?:final\s+)?(?:override\s+)?'
    r'(?:func\s+(?P<func>[A-Za-z_][A-Za-z0-9_]*)|var\s+(?P<var>[A-Za-z_][A-Za-z0-9_]*)'
    r'|(?P<init>init[?!]?)\b)'
)
DOC_LINE_RE = re.compile(r'^\s*///.*$')


def _depth_source(body: str) -> str:
    """`body` with every comment and string-literal character blanked to a space, same length and
    same line breaks, so brace-DEPTH counting cannot be thrown off by a `{`/`}` inside a doc
    comment's code example or a string literal, while every offset still lines up with `body`
    itself for slicing. This is NOT `strip_swift_comments` (that one is used to find `OCCT*`
    tokens and collapses text, losing offsets and line counts; depth-tracking specifically needs
    both preserved). Measured why this matters, not assumed: without it, `Curve3D.swift`'s own
    member count comes back 49 instead of the true count, because several of its members carry a
    ```` ```swift ```` doc-comment example containing a bare `{` (a trailing-closure call), which
    silently pushes `depth` up by one for the rest of the file and desyncs every later
    pre_depth == 1 check.
    """
    out = list(body)

    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] not in ("\n",):
                out[k] = " "

    # Block comments first (may contain // or " that would otherwise confuse the per-line pass).
    for m in re.finditer(r'/\*.*?\*/', body, flags=re.S):
        blank(m.start(), m.end())
    protected = "".join(out)
    # Line comments (///, //!, //) and string literals, line by line so a `//` inside a string
    # earlier on the same line cannot hide a real comment (not attempted here in the other
    # direction: a `"` inside a `//` comment is already blanked as part of the comment).
    result = []
    for line in protected.split("\n"):
        c = line.find("//")
        if c != -1:
            line = line[:c] + " " * (len(line) - c)
        line = re.sub(r'"(?:\\.|[^"\\])*"', lambda m: " " * len(m.group()), line)
        result.append(line)
    return "\n".join(result)


def _member_span(body: str, depth_src: str, start: int) -> tuple[str, int]:
    """From `start` (the member decl line's own start offset in `body`), the member's own text and
    the offset just past it. A one-line stored/computed property with no `{` gets just its line.
    Brace matching reads `depth_src` (comments/strings blanked); slicing reads `body` (verbatim)."""
    brace = depth_src.find("{", start)
    nl = body.find("\n", start)
    if brace == -1 or (nl != -1 and nl < brace):
        end = nl if nl != -1 else len(body)
        return body[start:end], end
    depth, i = 0, brace
    while i < len(depth_src):
        if depth_src[i] == "{":
            depth += 1
        elif depth_src[i] == "}":
            depth -= 1
            if depth == 0:
                return body[start:i + 1], i + 1
        i += 1
    return body[start:], len(body)


def type_members(body: str) -> list[dict]:
    """Top-level members of a type body: (name, kind, doc, text), depth-1 only.

    Depth is tracked (over `_depth_source(body)`, comments/strings blanked, see its docstring) so
    a `func` inside a nested closure, or a member of a nested type, is not double-counted as this
    type's own member, and a `{`/`}` inside a doc comment's own code example does not desync the
    count. Doc comment: contiguous `///` lines immediately above the declaration, blank lines not
    allowed between (this codebase's own convention, see e.g. `WireCurve.swift`).
    """
    depth_src = _depth_source(body)
    d_lines = depth_src.splitlines(keepends=True)
    lines = body.splitlines(keepends=True)
    out = []
    depth = 0
    offset = 0
    offsets = []
    for ln in lines:
        offsets.append(offset)
        offset += len(ln)
    i = 0
    while i < len(lines):
        dline = d_lines[i] if i < len(d_lines) else lines[i]
        pre_depth = depth
        depth += dline.count("{") - dline.count("}")
        if pre_depth == 1:
            m = MEMBER_DECL_RE.match(lines[i])
            if m:
                name = m.group("func") or m.group("var") or "init"
                kind = "func" if m.group("func") else ("var" if m.group("var") else "init")
                is_static = bool(m.group("static"))
                # doc: walk upward over contiguous `///` lines, skipping (not collecting) a
                # single attribute line (`@discardableResult`, `@inlinable`, ...) in between,
                # since this codebase writes both `/// doc\npublic func` and
                # `/// doc\n@discardableResult\npublic func`.
                doc_lines = []
                j = i - 1
                if j >= 0 and lines[j].strip().startswith("@"):
                    j -= 1
                while j >= 0 and DOC_LINE_RE.match(lines[j]):
                    doc_lines.insert(0, lines[j])
                    j -= 1
                text, _end_offset = _member_span(body, depth_src, offsets[i])
                out.append({"name": name, "kind": kind, "static": is_static,
                           "doc": "".join(doc_lines), "text": text})
        i += 1
    return out


# ------------------------------------------------------------------------------------------------
# Tested? Whether a member (by NAME, at the call-site syntax its kind implies) is exercised
# anywhere in the four lane test targets' own source. Deliberately permissive about WHICH of the
# four targets: a `Curve3D` member is legitimately tested from `OCCTSurfaceTests` (fixture reuse
# is common, see `derive_lane_types`'s own cross-target counts), so this checks the union of all
# four rather than only the member's owning type's primary target.
#
# GENERICITY SAFETY VALVE. A bare property read (`.length`, `.count`, `.value`) cannot be
# distinguished by name alone from the same call on some unrelated type. Both directions are real
# risks and this pass is built to err toward the SAFER one: `False` (or `None`) rather than a
# false `True`, because a false `True` here would hide a genuine untested capability behind
# borrowed credit from a different type's test, which is exactly the failure #815 exists to catch.
# A name is treated as ambiguous, `None` ("cannot say"), rather than resolved either way, when it
# is short and generic (the fixed list below) OR when THIS LANE's own derivation reuses it across
# more than `OVERLOAD_FANOUT` distinct types (data-driven: a name several unrelated lane types
# share is evidently common vocabulary here, whether or not it happens to be english-generic).
# ------------------------------------------------------------------------------------------------

GENERIC_MEMBER_NAMES = {
    "value", "values", "count", "length", "type", "id", "name", "first", "last", "data", "text",
    "description", "kind", "isEmpty", "point", "points", "center", "distance", "area", "volume",
    "index", "result", "status", "range", "domain", "isValid", "isClosed", "copy", "clone",
}
OVERLOAD_FANOUT = 3

CALL_RE_CACHE: dict[tuple[str, str, bool], re.Pattern] = {}


def _call_pattern(type_name: str, member_name: str, kind: str, is_static: bool) -> re.Pattern:
    key = (type_name, member_name, kind == "func")
    if key in CALL_RE_CACHE:
        return CALL_RE_CACHE[key]
    esc = re.escape(member_name)
    if kind == "init":
        pat = re.compile(r'\b' + re.escape(type_name) + r'[?!]?\s*\(')
    elif kind == "func":
        if is_static:
            pat = re.compile(r'\b' + re.escape(type_name) + r'\.' + esc + r'\s*\(|\.' + esc
                             + r'\s*\(')
        else:
            pat = re.compile(r'\.' + esc + r'\s*\(')
    else:  # var
        if is_static:
            pat = re.compile(r'\b' + re.escape(type_name) + r'\.' + esc + r'\b|\.' + esc + r'\b')
        else:
            pat = re.compile(r'\.' + esc + r'\b')
    CALL_RE_CACHE[key] = pat
    return pat


def member_test_status(type_name: str, member: dict, combined_test_text: str,
                       name_type_fanout: dict[str, int]) -> bool | None:
    """True (found a call site), False (searched, found none), None (name too ambiguous to ask)."""
    name = member["name"]
    if name in GENERIC_MEMBER_NAMES or name_type_fanout.get(name, 0) > OVERLOAD_FANOUT:
        return None
    pat = _call_pattern(type_name, name, member["kind"], member["static"])
    return bool(pat.search(combined_test_text))


def lane_members(lane_types, reach: dict[str, set[str]], prefixes, bare, swift_texts=None):
    """Every lane member, its own bridge calls -> classes, and its tested status.

    Returns list of dict(type, target, file, name, kind, doc, classes, tested, tested_anywhere).
    `classes` is the set of OCCT classes this ONE member's own body reaches (a member-level
    narrowing of `lane_class_table`'s type-level union), empty for a member that calls no bridge
    function at all (pure Swift logic, e.g. a convenience overload).

    TWO "tested" SIGNALS, DELIBERATELY, because they answer different questions and conflating
    them produces a false alarm. `tested` asks the question #815's own `## Lane` literally poses
    ("The test targets Pass 5a sweeps"): is there a call site in one of the FOUR lane targets.
    `tested_anywhere` asks #815's actual under-coverage QUESTION ("An OCCT behaviour ... which no
    test exercises"): is there a call site ANYWHERE in `Tests/`. Measured, not a hypothetical: the
    first cut of this script used only the four-target text, and 12 of its 42 "candidate unders"
    (`.torsion`, `.localTangent`, `.localNormal`, `.localCentreOfCurvature`, `.splitAt`, ...) are
    real Curve3D/Curve2D/Surface capabilities that ARE tested, correctly, in `OCCTAnalysisTests`
    (differential-geometry batch suites) or `OCCTShapeHealingTests`, following this repo's own Test
    Layout convention of filing a suite under "the domain target that best matches it" rather than
    a type's own primary-usage target. Reporting those as `under` would have been a wrong finding
    from a real bug in the check, not a real gap in the tree, and #815's own **Handling real
    findings** section says an over-eager census is exactly the class of mistake to avoid. A member
    with `tested=False, tested_anywhere=True` is not a coverage gap; it is a note about which
    target happens to own the test, which is Pass 5b/5c/5d/Phase-6 territory (which target OWNS an
    "unowned" suite like `OCCTAnalysisTests`), not this pass's. Only `tested_anywhere=False` is a
    genuine `under` candidate.
    """
    swift_texts = swift_texts if swift_texts is not None else all_swift_texts()
    target_text = _target_text(LANE_TARGETS)
    combined = "\n".join(target_text[t] for t in LANE_TARGETS)
    all_target_text = _target_text(all_test_targets())
    combined_all = "\n".join(all_target_text.values())

    # name -> set of owning types, for the overload-fanout part of the genericity valve. Nested
    # views (below) get their own compound "type" name (`Curve2D.CircleProperties`) so a plain
    # `radius` shared across several such views doesn't collide with an outer type's own `radius`
    # for genericity purposes, matching how they are otherwise treated as independent types.
    name_type_fanout: dict[str, set[str]] = collections.defaultdict(set)
    per_type_members: dict[str, list[dict]] = {}
    nested_owner: dict[str, str] = {}  # compound name -> owning lane entry's "type"
    for entry in lane_types:
        bodies = all_bodies_for_type(swift_texts, entry["type"], entry["file"])
        members = []
        for _fn, body in bodies:
            members.extend(type_members(body))
            for nested_name, nested_body in nested_view_bodies(body):
                compound = f"{entry['type']}.{nested_name}"
                nested_members = type_members(nested_body)
                per_type_members[compound] = nested_members
                nested_owner[compound] = entry["type"]
                for m in nested_members:
                    name_type_fanout[m["name"]].add(compound)
        per_type_members[entry["type"]] = members
        for m in members:
            name_type_fanout[m["name"]].add(entry["type"])
    fanout_counts = {n: len(types) for n, types in name_type_fanout.items()}

    lane_and_nested = list(lane_types) + [
        {"type": compound, "target": next(e["target"] for e in lane_types if e["type"] == owner),
         "file": next(e["file"] for e in lane_types if e["type"] == owner)}
        for compound, owner in nested_owner.items()
    ]

    out = []
    for entry in lane_and_nested:
        for m in per_type_members[entry["type"]]:
            calls = bridge_calls_in(m["text"])
            resolved = [c for c in calls if c in reach]
            classes: set[str] = set()
            for fn in resolved:
                classes |= {n for n in reach[fn] if is_occt_class(n, prefixes, bare)}
            tested = member_test_status(entry["type"], m, combined, fanout_counts)
            tested_anywhere = member_test_status(entry["type"], m, combined_all, fanout_counts)
            out.append({"type": entry["type"], "target": entry["target"], "file": entry["file"],
                       "name": m["name"], "kind": m["kind"], "doc": m["doc"],
                       "bridge_calls": resolved, "classes": classes, "tested": tested,
                       "tested_anywhere": tested_anywhere})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="#815 lane derivation, by call")
    ap.add_argument("--members", action="store_true", help="also list per-type bridge calls")
    ap.add_argument("--classes", action="store_true", help="also list the derived OCCT class table")
    ap.add_argument("--member-detail", action="store_true",
                    help="member-level table: name, classes reached, tested?")
    ap.add_argument("--gaps", action="store_true",
                    help="types #380 named that this derivation places outside the lane, plus "
                         "ambiguous ties")
    args = ap.parse_args()

    lane_types, ambiguous, all_types = derive_lane_types()
    prefixes, bare = load_packages()
    reach = bridge_reach()
    swift_texts = all_swift_texts()
    class_table, per_type_calls = lane_class_table(lane_types, reach, prefixes, bare, swift_texts)

    by_target = collections.defaultdict(list)
    for e in lane_types:
        by_target[e["target"]].append(e)

    print(f"lane types: {len(lane_types)} across {len(set(e['file'] for e in lane_types))} files, "
          f"{len(class_table)} distinct OCCT classes reached")
    print()
    for t in LANE_TARGETS:
        entries = sorted(by_target[t], key=lambda e: -e["total"])
        files = sorted(set(e["file"] for e in entries))
        print(f"{t}: {len(entries)} types across {len(files)} files")
        for e in entries:
            print(f"    {e['type']:<24} {e['file']:<28} total={e['total']:<5} {e['counts']}")
    print()
    print(f"OCCT classes reached: {len(class_table)}")

    if args.members:
        print()
        print("per-type bridge calls:")
        for e in sorted(lane_types, key=lambda e: (e["target"], e["type"])):
            info = per_type_calls[e["type"]]
            print(f"  {e['type']} ({e['target']}): {len(info['resolved'])} resolved, "
                  f"{len(info['unresolved'])} unresolved")
            if info["unresolved"]:
                print(f"      unresolved: {', '.join(info['unresolved'])}")

    if args.classes:
        print()
        print("derived OCCT class table:")
        for cls in sorted(class_table):
            rec = class_table[cls]
            print(f"  {cls:<38} via {len(rec['via'])} bridge fn(s), types: "
                  f"{', '.join(sorted(rec['types']))}")

    if args.member_detail:
        members = lane_members(lane_types, reach, prefixes, bare, swift_texts)
        with_calls = [m for m in members if m["bridge_calls"]]
        tested_true = sum(1 for m in with_calls if m["tested"] is True)
        tested_false = sum(1 for m in with_calls if m["tested"] is False)
        tested_none = sum(1 for m in with_calls if m["tested"] is None)
        elsewhere = [m for m in with_calls if m["tested"] is False and m["tested_anywhere"] is True]
        real_under = [m for m in with_calls
                      if m["tested"] is False and m["tested_anywhere"] is False]
        print()
        print(f"members: {len(members)} total, {len(with_calls)} call a bridge function "
              f"(the rest are pure-Swift logic: convenience overloads, computed combinations, ...)")
        print(f"  tested=True in the 4 lane targets       : {tested_true}")
        print(f"  tested=False in the 4 lane targets      : {tested_false}")
        print(f"    of which tested_anywhere=True (tested in another target, e.g. "
              f"OCCTAnalysisTests): {len(elsewhere)}")
        print(f"    of which tested_anywhere=False (no test in ANY of the 18 targets): "
              f"{len(real_under)}")
        print(f"  tested=None (name too ambiguous to ask) : {tested_none}")
        print()
        print("REAL candidates (tested_anywhere=False, no test anywhere exercises them):")
        for m in sorted(real_under, key=lambda m: (m["target"], m["type"], m["name"])):
            print(f"  {m['target']:<18} {m['type']:<22} .{m['name']:<24} "
                  f"-> {', '.join(sorted(m['classes'])) or '(class unresolved)'}")
        print()
        print("tested elsewhere (a different target than the 4, not a coverage gap):")
        for m in sorted(elsewhere, key=lambda m: (m["target"], m["type"], m["name"])):
            print(f"  {m['target']:<18} {m['type']:<22} .{m['name']}")

    if args.gaps:
        print()
        print("ambiguous (tied primary owner, excluded):")
        for a in ambiguous:
            print(f"  {a['type']} ({a['file']}): {a['counts']}")
        print()
        print("#380's own 16-file list, checked against this derivation:")
        legacy = ["Surface", "Curve2D", "Curve3D", "BRepGraph", "MedialAxis", "FillingSurface",
                 "LawFunction", "BSplineApproxInterp", "PolynomialSolver", "Point2D",
                 "Transform2D", "AxisPlacement2D", "Period", "WireCurve", "EdgeCurve"]
        lane_files = {e["file"][:-len(".swift")] for e in lane_types}
        for ty in legacy:
            status = "IN LANE" if ty in lane_files else "NOT in this lane (see docstring)"
            print(f"  {ty:<20} {status}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
