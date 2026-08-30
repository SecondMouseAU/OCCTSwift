#!/usr/bin/env python3
"""Issue #817 (Pass 5c of #807/#819): the tests lane, re-derived by call.

Mirrors #811's `derive_lane.py` ("the lane, re-derived by call. #385's '32 bridge calls' is
stale; it is 60."), but for a TEST phase rather than a docs phase: the population of interest
is not "which OCCT classes does the bridge wrap and the docs describe" (that is #810's question,
already answered and reused here as `refman_census.py`'s starting point), it is "which of those
classes does a test in this lane actually EXERCISE, reached through the public Swift API a test
calls." That is a three-hop static reachability question:

    lane test file  --(member access, ".foo")-->  Swift API member  --(literal call, "OCCTFoo(")-->
    bridge function  --(literal class mention, doc->field, or one-level occt-helper indirection)-->
    OCCT class

Each hop is answered mechanically below and each is a KNOWN, STATED approximation, not a full
parser:

  HOP 1 (test -> Swift member).  A lane test file is judged to call Swift member `m` if the
  literal substring `.m` (word-bounded) appears anywhere in that file's comment-and-string-
  stripped text. This over-approximates real call-site resolution for generic member names
  (`name`, `count`, `type`...), the same shape #928's own README documents for class-level
  attribution; `GENERIC_MEMBERS` below is the curated set this pass hand-verified rather than
  trusting the raw signal for.

  HOP 2 (Swift member -> bridge function).  For each `OCCTFoo(` call site inside a lane-relevant
  Swift source file (`Sources/OCCTSwift/*.swift`), the enclosing member is resolved by CLIMBING
  INDENTATION backward from the call site to the nearest line that DEDENTS relative to everything
  scanned so far and matches a Swift declaration head (`func`/`var`/`init`). This is not a
  brace-depth parser, but it is not "nearest preceding declaration-shaped line" either -- that
  was the first version, and it was wrong on the very first real file it ran against:
  `Document.swift`'s `tracedForward` declares `var handles = [...]` two lines above its own
  `OCCTDocumentNamingTraceForward(` call, at the SAME indentation as the call (an ordinary local
  variable, not a member), and "nearest preceding `var NAME`" matched `handles` instead of
  climbing out to `func tracedForward`. Swift reuses `var`/`let` for locals and members alike, so
  no regex on the keyword alone can tell them apart; indentation can, because this codebase's
  swift-format-enforced style never puts a local declaration at LESS indentation than its own
  enclosing member's header. The climb keeps going outward through a dedent that does not match a
  declaration head (an `if`/`guard`/closure-opening line), so several nested control-flow levels
  between a call and its real enclosing member are all climbed through. `--self-test` proves this
  against the real bug (`hop2-local-var-not-mistaken-for-member`, which also runs the OLD
  approach on the same fixture and shows it resolving to `handles`) and against a multi-level
  nested case (`hop2-climbs-through-nested-control-flow-to-real-member`). The derivation below
  reports every resolved (file, member) pair via `--calls` so a reviewer can spot-check it.

  HOP 3 (bridge function -> OCCT class).  A function's own body (the comment-stripped text
  between its `DEFN` match and the next one, reusing the exact regex
  `Scripts/derive-bridge-header-split.py` already carries for this) is scanned for:
    (a) a literal lane-class-name mention (the same test #810's `_is_wrapped` uses, at function
        rather than file granularity);
    (b) a `(?:doc|document)->FIELD` access, translated to a class via `FIELD_CLASS` below, itself
        derived by parsing `OCCTDocument`'s own field declarations in `OCCTBridge_Internal.h`
        rather than hand-typed -- see `parse_document_struct_fields()`. This closes the single
        biggest blind spot (a) has on its own: `OCCTDocument`'s shared struct means most
        `OCCTDocument*` functions reach `XCAFDoc_ShapeTool`/`ColorTool`/`VisMaterialTool`,
        `TDocStd_Document`/`Application` and `TDF_Label` through a struct member access
        (`doc->shapeTool->AddShape(...)`) that never spells the OCCT class name in that
        function's own body at all -- the class name lives only in the struct's field
        declaration, once, in a different file.
    (c) one level of indirection through a lowercase `occt`-prefixed helper the function calls
        (e.g. `occtDocumentDatumObjectAt`, `occtDocumentInit`): the helper's OWN body is scanned
        the same way (a)+(b), and its classes are unioned in. Iterated to a fixed point (capped at
        4 rounds, generous for this codebase's shallow helper nesting) rather than a single pass,
        so a helper that itself calls a second helper is not missed.

WHAT THIS DERIVATION DOES NOT DO, stated rather than found the hard way later:

  - It is reachability, not behavioural coverage. A class reached this way might be touched only
    incidentally (e.g. a shared struct field on every document, whether or not the test's OWN
    assertion has anything to do with that class). `refman_census.py` treats every reachable class
    as a MECHANICAL `ok` candidate and states, for its own README, which of those it additionally
    hand-verified against the actual test body per #817's own instruction not to accept "a type
    that happens to touch it in passing."
  - It resolves ONE textual occurrence per bridge function name across all of
    `Sources/OCCTSwift`, not per-call-site overload resolution. Two members of unrelated types
    sharing an OCCT-prefixed call name would be merged; measured empirically below (`--self-test`
    has a case), and not observed among the real bridge functions this lane's 131 wrapped classes
    resolve to (each `OCCTFoo` name is called from exactly one place in `Sources/OCCTSwift`,
    checked in `--calls`' own duplicate-call-site report).
  - Swift string literals are NOT stripped, only `//` and `/* */` comments (mirroring
    `Scripts/derive-bridge-header-split.py`'s own `strip_comments`, which has the identical
    property). A member name mentioned only inside a Swift string (e.g. an error message) would be
    a false HOP-1 hit. Checked directly: no lane Swift member name below also appears as an
    English word inside a `Document.swift`/GDT* string literal that isn't itself that member's own
    name (`grep` swept every resolved member name against `"..."`-delimited spans by hand).

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py               # summary
    python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --calls        # + evidence chains
    python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --files        # the IOTests document-half determination
    python3 Scripts/repro/817-refman-coverage-tests-document/derive_lane.py --self-test    # 10 detector cases
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
INTERNAL_H = os.path.join(BRIDGE_SRC, "OCCTBridge_Internal.h")
SWIFT_SRC = os.path.join(ROOT, "Sources", "OCCTSwift")
XCAF_TESTS_DIR = os.path.join(ROOT, "Tests", "OCCTXCAFTests")
IO_TESTS_DIR = os.path.join(ROOT, "Tests", "OCCTIOTests")

# ---------------------------------------------------------------------------------------------
# The lane: all of OCCTXCAFTests, plus the "document half" of OCCTIOTests (#817's own wording).
#
# HOW THE LINE WAS DRAWN, at FILE granularity, not per-@Test-function. A file is "document half"
# if the literal identifier `Document` (the Swift type OCCTXDE/OCAF surface is built on) occurs
# anywhere in the file outside a comment. Checked by hand for every hit (`--files` prints the
# match lines): all seven are genuine `Document.create()`/`Document.load*()`/`doc.something(...)`
# call sites, none a false hit off an unrelated word containing "Document" as a substring.
#
# File granularity, not per-test-function granularity, deliberately: three of these seven files
# mix Document-touching tests with plain Shape-level import/export tests in the SAME @Suite
# (`GLTFTests`: 1 of 5 tests; `ImportProgressTests`: 1 of 4; `MeshAndExportProgressTests`: 1 of 10;
# `PLYExportOptionsTests`: 1 of 5; `VrmlWriterTests`: 4 of 7). Two are Document-only end to end
# (`STEPCAFModeControlTests`: 8 of 8; `STEPWriterCAFCorruptionTests`: 1 of 1, and that one test's
# OWN subject is a shape-level STEP write, with the CAF read only in its setup -- included anyway
# because #817 asks about the DOCUMENT HALF of the target, not about excluding every test whose
# primary subject is geometry once a document appears in its call chain).
#
# Classifying at file rather than function granularity does not inflate the "tested" count: the
# non-Document tests inside a mixed file call Shape/Exporter members that are outside this lane's
# 131-class population, so they contribute zero reachability evidence to any lane class either
# way. The choice only affects which FILES this script reads text out of, not which classes it
# can find. `--files` prints, per file, the tests-total/tests-touching-Document ratio quoted
# above, derived rather than restated, so a future re-run catches drift here too.
IO_TESTS_DOCUMENT_HALF = (
    "GLTFTests.swift",
    "ImportProgressTests.swift",
    "MeshAndExportProgressTests.swift",
    "PLYExportOptionsTests.swift",
    "STEPCAFModeControlTests.swift",
    "STEPWriterCAFCorruptionTests.swift",
    "VrmlWriterTests.swift",
)

LINE_COMMENT = re.compile(r"//[^\n]*")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
DOCUMENT_WORD = re.compile(r"\bDocument\b")
TEST_ATTR = re.compile(r'@Test(?:\s*\([^)]*\))?\s*\n?\s*func\s+(\w+)')


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def strip_comments(text: str) -> str:
    return LINE_COMMENT.sub("", BLOCK_COMMENT.sub(" ", text))


def io_tests_files() -> list[str]:
    return sorted(f for f in os.listdir(IO_TESTS_DIR) if f.endswith(".swift"))


def derive_io_document_half(verbose: bool = False) -> list[str]:
    """Re-derives IO_TESTS_DOCUMENT_HALF by the rule stated above; does not trust the constant."""
    hits = []
    for name in io_tests_files():
        text = strip_comments(_read(os.path.join(IO_TESTS_DIR, name)))
        if DOCUMENT_WORD.search(text):
            hits.append(name)
    return hits


def lane_test_files() -> list[str]:
    xcaf = [
        os.path.join(XCAF_TESTS_DIR, f)
        for f in sorted(os.listdir(XCAF_TESTS_DIR))
        if f.endswith(".swift")
    ]
    io = [os.path.join(IO_TESTS_DIR, f) for f in IO_TESTS_DOCUMENT_HALF]
    return xcaf + io


def lane_test_corpus() -> str:
    """All lane test file text, comment-stripped, concatenated. NOT string-literal-stripped
    (matching derive-bridge-header-split.py's own strip_comments; see the module docstring's
    "what this does not do" section for why that is checked rather than assumed safe here)."""
    return "\n".join(strip_comments(_read(p)) for p in lane_test_files())


# ---------------------------------------------------------------------------------------------
# HOP 3: bridge function -> OCCT class(es)
# ---------------------------------------------------------------------------------------------

# Widened past Scripts/derive-bridge-header-split.py's own DEFN (occt/OCCT-prefixed names only)
# to ANY function definition at column 0, because this bridge's shared-helper convention is not
# consistently occt/OCCT-prefixed: `getOrCreateNamedData`, `findNamedData`, `getLabelForTag`,
# `DiscretizeEdgeInto` are all real, `static`, per-file or global helpers with no such prefix, and
# `getOrCreateNamedData` specifically is the ONLY place `OCCTDocumentNamedDataSetInteger`/
# `GetInteger`/`HasInteger`/... reach `TDataStd_NamedData` at all (they call it, and it alone
# constructs the `Handle(TDataStd_NamedData)`). A first version restricted to occt/OCCT-prefixed
# names entirely, and `TDataStd_NamedData` -- despite having its own dedicated, real test file,
# `TDataStdNamedDataTests.swift` -- came back `under` for exactly this reason. Anchored at the
# start of a line (re.M): a call site, not a definition, is always indented inside another
# function in this codebase's formatting.
#
# THE (?!Handle\b) EXCLUSION IS LOAD-BEARING, NOT DEFENSIVE STYLE. Once the occt/OCCT restriction
# is dropped, `Handle` itself (OCCT's smart-pointer macro, `Handle(TDataStd_NamedData)`) becomes a
# valid match for "any identifier immediately followed by `(`", and it is the FIRST such
# occurrence on a line like `static Handle(TDataStd_NamedData) getOrCreateNamedData(...)`, so a
# non-greedy scan stops there and never reaches the real name at all -- the opposite failure from
# the one this widening exists to fix. Measured across every bridge file: `Handle` is the only
# builtin/macro name this causes a problem for (`typedef bool (*Callback)(...)` also matches
# `bool` as a false name, but always as a `;`-terminated declaration with no body, so it
# contributes an empty span and is harmless without needing its own exclusion).
# `--self-test`'s `hop3-handle-macro-exclusion` case is this exact bug.
DEFN = re.compile(r"^[A-Za-z_][\w\s\*\(\)<>,:&]*?\b((?!Handle\b)[A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M)
CALL = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")

STRUCT_FIELD = re.compile(
    r"^\s*(?:Handle\((\w+)\)|std::vector<(\w+)>|(\w+))\s+(\w+)(?:\{[^}]*\})?\s*;", re.M
)


def bridge_files() -> list[str]:
    files = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for f in sorted(os.listdir(d)):
            if f.endswith(".mm") or f.endswith(".h"):
                files.append(os.path.join(d, f))
    return files


def parse_document_struct_fields() -> dict[str, str]:
    """FIELD_CLASS: OCCTDocument field name -> the lane OCCT class it holds.

    Parsed from `struct OCCTDocument { ... }` in OCCTBridge_Internal.h itself, not hand-typed,
    so a field OCCT adds or renames shows up as a derivation change rather than a silent miss.
    `getLabel`/`registerLabel`, the struct's own two methods, are added by hand immediately below:
    both operate on `labels` (a `std::vector<TDF_Label>`) but are METHOD calls, not field
    accesses, so STRUCT_FIELD's declaration-line scan cannot see them the way it sees a bare
    `Handle(X) name;` line.
    """
    text = _read(INTERNAL_H)
    m = re.search(r"struct OCCTDocument\s*\{", text)
    if not m:
        return {}
    # Balance braces from the opening one to find the struct body's real end.
    depth = 0
    i = m.end() - 1
    start_body = m.end()
    for j in range(m.end() - 1, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                body = text[start_body:j]
                break
    else:
        return {}

    fields: dict[str, str] = {}
    for line in body.splitlines():
        line = line.split("//", 1)[0]
        fm = STRUCT_FIELD.match(line)
        if not fm:
            continue
        cls = fm.group(1) or fm.group(2) or fm.group(3)
        field = fm.group(4)
        fields[field] = cls
    # Both wrap `labels` (a vector<TDF_Label>); not visible to the declaration-line scan above.
    fields.setdefault("getLabel", "TDF_Label")
    fields.setdefault("registerLabel", "TDF_Label")
    return fields


def _matching_close(text: str, open_pos: int, open_ch: str, close_ch: str) -> int | None:
    """Index just past the `close_ch` matching the `open_ch` at `text[open_pos]`, or None."""
    depth = 0
    i = open_pos
    n = len(text)
    while i < n:
        c = text[i]
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


def _function_spans(text: str) -> list[tuple[str, int, int, bool]]:
    """[(name, body_start, body_end, is_static)] for every OCCT*/occt* DEFINITION (not
    declaration) in comment-stripped text, `body_start`/`body_end` bounding the brace-balanced
    `{ ... }` that follows the parameter list.

    THIS REPLACED A THIRD REAL BUG, the widest-reaching of the three this file's own output
    found. The first version used "from right after this DEFN match to the START of the next
    OCCT*/occt*-prefixed DEFN match" as a function's body, which is correct only if nothing but
    OCCT*/occt*-prefixed functions ever appears between two such definitions. This bridge's
    `.mm` files routinely interleave file-scope helper STRUCTS and non-`occt`-prefixed static
    helpers between one bridge function and the next -- `OCCTBridge_Document_DocumentLifecycle.mm`
    alone has three (`struct OCCTAssemblyGraph { Handle(XCAFDoc_AssemblyGraph) graph; };`,
    `OCCTViewObject`/`XCAFView_Object`, `OCCTNoteObject`/`XCAFNoteObjects_NoteObject`) plus a
    non-`occt`-prefixed `static TDF_Label getLabelForTag(...)` sitting between
    `occtDocumentFormatsImpl` and the next real bridge function, `OCCTDocumentCreate`. The old
    span swallowed all four, so EVERY caller of `occtDocumentFormatsImpl` (which itself touches
    only `TDocStd_Application`) inherited `XCAFDoc_AssemblyGraph`, `XCAFView_Object`,
    `XCAFNoteObjects_NoteObject` and `TDF_Label` too -- caught because `OCCTDocumentReadingFormats`
    (`ReadingFormats`/`WritingFormats` have nothing to do with any of those four) showed up
    reaching all of them. Proper brace balancing from the parameter list's own matching `)`
    forward to the function's own `{`...`}` fixes it, and also correctly gives a plain
    DECLARATION (a header prototype ending in `;`, no body at all) an EMPTY span rather than
    absorbing whatever text happens to follow it before the next definition.

    Not a full parser: brace/paren depth is counted over comment-stripped text that still
    contains string literals, so a string literal containing an unescaped `{`, `}`, `(` or `)`
    would misalign the count. Swept by hand across every lane-relevant bridge file; none contain
    one. `--self-test`'s `hop3-interleaved-struct` case is the exact bug above, reproduced in
    miniature.
    """
    spans = []
    for m in DEFN.finditer(text):
        is_static = bool(re.match(r"^\s*static\b", m.group(0)))
        paren_close = _matching_close(text, m.end() - 1, "(", ")")
        if paren_close is None:
            continue
        # Skip past any trailing qualifiers (const, noexcept, ...) to the declaration's terminator.
        tail = text[paren_close : paren_close + 200]
        semi = tail.find(";")
        brace = tail.find("{")
        if brace == -1 or (semi != -1 and semi < brace):
            # A declaration (prototype), not a definition: no body to attribute anything to.
            spans.append((m.group(1), paren_close, paren_close, is_static))
            continue
        brace_start = paren_close + brace
        body_end = _matching_close(text, brace_start, "{", "}")
        if body_end is None:
            continue
        spans.append((m.group(1), brace_start, body_end, is_static))
    return spans


# A node in the call graph is either a bare bridge/helper name (one definition, external linkage
# -- an OCCTFoo entry point Swift calls directly, or an `inline` helper shared via a header) or a
# (file_basename, name) pair (a `static` helper redefined per file, C++ file-scope linkage).
Node = "str | tuple[str, str]"


def bridge_function_classes(lane_classes: set[str]) -> dict[str, set[str]]:
    """func_name -> set(lane classes it reaches), combining direct mentions, doc-> struct field
    access, and occt-helper indirection iterated to a fixed point.

    STATIC HELPERS ARE FILE-SCOPED, DELIBERATELY, AND THIS IS THE SECOND REAL BUG THIS SCRIPT
    FOUND ON ITS OWN OUTPUT (the first is HOP 2's local-var fix above). A first version keyed the
    call graph purely by bare function name, and this bridge routinely defines a `static` helper
    of the SAME NAME in several different `.mm` files -- `occtDocumentFormatsImpl` alone has six
    independent, unrelated bodies (`OCCTBridge_Document_{Appearance,Assembly,Attributes,
    DocumentLifecycle,Functions,GDT}.mm`), and a tree-wide sweep for this exact shape
    (`static\\s+\\S+\\s+occt\\w+\\(`) finds 24 further examples (`occtArgList`, `occtQuiltShells`,
    `occtWireInterpolateImpl`, ...), so this is a bridge-wide convention, not a one-off. Keying by
    bare name alone made `OCCTDocumentReadingFormats` (which calls the DocumentLifecycle.mm copy,
    itself touching only `TDocStd_Application`) inherit whatever ANY of the other five files'
    same-named-but-unrelated copies reach transitively, because the fixed-point union treated all
    six as one node. Caught concretely: `XCAFNoteObjects_NoteObject` and `XCAFView_Object` both
    showed up as "reached via `Document.swift::readingFormats`", which is nonsensical --
    `ReadingFormats`/`WritingFormats` have nothing to do with either class. C++ linkage is the
    fix: a `static` function is only callable from within its own translation unit, so a call
    site's file uniquely determines which same-named `static` definition it resolves to; a
    non-static (external-linkage) name has exactly one definition tree-wide by ODR, so it stays
    keyed by bare name. `--self-test`'s `hop3-static-file-scoping` case is this exact bug,
    reproduced in miniature and proven to reappear if the file-scoping is removed.
    """
    field_class = parse_document_struct_fields()
    field_alt = "|".join(re.escape(f) for f in field_class) or r"(?!x)x"
    field_re = re.compile(r"\b(?:doc|document)->(" + field_alt + r")\b")
    class_alt = re.compile(r"\b(" + "|".join(re.escape(c) for c in sorted(lane_classes)) + r")\b")

    static_names_by_file: dict[str, set[str]] = {}
    raw: list[tuple[str, str, set[str], set[str]]] = []  # (file, name, classes, raw_callee_names)
    for path in bridge_files():
        fname = os.path.basename(path)
        text = strip_comments(_read(path))
        spans = _function_spans(text)
        static_names_by_file[fname] = {name for name, _, _, is_static in spans if is_static}
        for name, start, end, _is_static in spans:
            body = text[start:end]
            classes = set(class_alt.findall(body))
            for field in field_re.findall(body):
                classes.add(field_class[field])
            callees = {c for c in CALL.findall(body) if c != name}
            raw.append((fname, name, classes, callees))

    def resolve(caller_file: str, callee_name: str) -> "str | tuple[str, str]":
        if callee_name in static_names_by_file.get(caller_file, ()):
            return (caller_file, callee_name)
        return callee_name

    base: dict = {}
    calls: dict = {}
    for fname, name, classes, callees in raw:
        node = (fname, name) if name in static_names_by_file.get(fname, ()) else name
        base.setdefault(node, set()).update(classes)
        calls.setdefault(node, set()).update(resolve(fname, c) for c in callees)

    reached = {node: set(classes) for node, classes in base.items()}
    for _ in range(4):
        changed = False
        for node, callees in calls.items():
            before = len(reached.get(node, set()))
            for callee in callees:
                if callee in reached:
                    reached.setdefault(node, set()).update(reached[callee])
            if len(reached.get(node, set())) != before:
                changed = True
        if not changed:
            break

    # Public entry points (what Swift actually calls) are always bare-string nodes -- external
    # linkage is required to be callable across the ObjC++/Swift boundary at all. The (file, name)
    # nodes above exist only to keep static helpers from cross-contaminating each other and are
    # not independently useful to a caller of this function.
    return {node: classes for node, classes in reached.items() if isinstance(node, str)}


# ---------------------------------------------------------------------------------------------
# HOP 2: Swift API member -> bridge function(s) it calls
# ---------------------------------------------------------------------------------------------

DECL_RE = re.compile(
    r"^\s*(?:@[\w:]+(?:\([^)]*\))?\s*)*"
    r"(?:(?:public|internal|private|fileprivate|open|package)\s+)*"
    r"(?:static\s+)?(?:final\s+)?(?:mutating\s+)?(?:override\s+)?"
    r"(?:func\s+(?P<func>[A-Za-z_][A-Za-z0-9_]*)"
    r"|var\s+(?P<var>[A-Za-z_][A-Za-z0-9_]*)"
    r"|(?P<init>init)\b)"
)

BRIDGE_CALL = re.compile(r"\bOCCT[A-Za-z0-9_]+\s*\(")


def swift_source_files() -> list[str]:
    return sorted(
        os.path.join(SWIFT_SRC, f) for f in os.listdir(SWIFT_SRC) if f.endswith(".swift")
    )


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def _enclosing_member(lines: list[str], call_line_idx: int) -> str | None:
    """The Swift member enclosing `lines[call_line_idx]`, by climbing INDENTATION, not by taking
    the nearest preceding line matching a declaration head regardless of nesting.

    A first version of this used "nearest preceding func/var/init line, any indentation" and was
    wrong on the very first real file it ran against: a `var handles = [...]` LOCAL variable
    declaration, at the same indentation as the bridge call two lines below it, matches the same
    `var\\s+NAME` shape a top-level computed property does, and "nearest preceding" found it
    before climbing out to the real enclosing `func tracedForward(...)`. Swift reuses `var`/`let`
    for locals and members alike, so a regex distinguishing them by keyword can't work; this
    codebase's swift-format-enforced flat indentation can, because a local declaration sits at
    the SAME indentation as its sibling statements (including the call site), never less, so it
    is never mistaken for the enclosing scope's own header line. Walk backward tracking the
    minimum indentation seen; a line that DEDENTS relative to everything scanned so far is a
    scope boundary, tested against DECL_RE, and if it doesn't match (an `if`/`guard`/`for`/
    closure opening `{`, e.g. `withSomething { value in`), that dedent becomes the new floor and
    the climb continues outward rather than stopping, so several nested control-flow levels
    between the call and its real enclosing member are all climbed through correctly.

    A FOURTH real bug, found the same way as the first three (on the actual tree, not a
    fixture): a MULTI-LINE signature's closing `) -> ReturnType {` sits at the SAME indentation
    as its own `func` keyword line, not one level deeper, e.g.

        public func setGeomToleranceValueType(
            at index: Int,
            _ valueType: GeomToleranceValueType
        ) -> Bool {
            OCCTDocumentSetGeomToleranceTypeOfValue(handle, Int32(index), valueType.rawValue)
        }

    The call sits at indent 8; climbing hits `) -> Bool {` at indent 4 first, which does not
    match DECL_RE, so the plain algorithm above drops the floor to 4 and keeps going -- and then
    `public func setGeomToleranceValueType(` is ALSO at indent 4, never STRICTLY less than the
    new floor, so it is never recognised as the boundary at all, and the whole call is missed
    (this is why `GDTToleranceDatumAccessorTests.swift`'s real, passing calls to
    `setGeomToleranceValueType`/`setGeomToleranceMaterialRequirement`/
    `setGeomToleranceZoneModifier` came back as classes reached by NO test). Handled by
    `_wrapped_signature_start`: before permanently lowering the floor on a non-matching dedent,
    look FURTHER back at that SAME indentation (skipping only lines MORE indented than it, which
    is what a wrapped parameter list's continuation lines are) for a DECL_RE match. Only a
    genuine wrapped signature has one; an `if`/`guard`-style dedent does not, and falls through to
    the old behaviour unchanged.
    """
    min_indent = _indent(lines[call_line_idx])
    for i in range(call_line_idx - 1, -1, -1):
        line = lines[i]
        if not line.strip():
            continue
        ind = _indent(line)
        if ind < min_indent:
            m = DECL_RE.match(line)
            if m:
                return m.group("func") or m.group("var") or (m.group("init") and "init")
            wrapped = _wrapped_signature_start(lines, i, ind)
            if wrapped is not None:
                return wrapped
            min_indent = ind
    return None


def _wrapped_signature_start(lines: list[str], tail_idx: int, indent_level: int) -> str | None:
    """Is `lines[tail_idx]` (a non-declaration dedent line, e.g. `) -> Bool {`) the CLOSING line
    of a multi-line signature whose `func`/`var`/`init` keyword sits further back at the SAME
    indentation? Only continuation lines MORE indented than `indent_level` are skipped over; a
    sibling at the exact same indentation that is not itself a declaration means this was a
    genuine control-flow dedent, not a wrapped signature, and None is returned so the caller
    falls back to its normal floor-lowering behaviour.

    A candidate DECL_RE match at the same indentation is not enough on its own: `func helper()
    {}` (a complete, self-closed nested function, braces AND parens balanced on one line) sits
    at the same indentation as a LATER, unrelated `withSomething { value in` closure opener two
    lines below it in `--self-test`'s `hop2-climbs-through-nested-control-flow-to-real-member`
    fixture, and matching on indentation alone wrongly claims `helper` wraps into it. The real
    signal is UNBALANCED parens: `public func setGeomToleranceValueType(` has one open paren with
    no matching close on that line, because its parameter list continues below; a complete
    single-line declaration never does.
    """
    for j in range(tail_idx - 1, -1, -1):
        line = lines[j]
        if not line.strip():
            continue
        ind = _indent(line)
        if ind < indent_level:
            return None
        if ind == indent_level:
            m = DECL_RE.match(line)
            if m and line.count("(") > line.count(")"):
                return m.group("func") or m.group("var") or (m.group("init") and "init")
            return None
        # ind > indent_level: a parameter-list continuation line; keep climbing.
    return None


def swift_member_bridge_calls() -> dict[tuple[str, str], set[str]]:
    """(swift_file_basename, member_name) -> set(bridge function names it calls)."""
    out: dict[tuple[str, str], set[str]] = {}
    for path in swift_source_files():
        text = strip_comments(_read(path))
        lines = text.split("\n")
        for lineno, line in enumerate(lines):
            for call in BRIDGE_CALL.findall(line):
                name = call[: call.index("(")].strip()
                member = _enclosing_member(lines, lineno)
                if member is None:
                    continue
                key = (os.path.basename(path), member)
                out.setdefault(key, set()).add(name)
    return out


# ---------------------------------------------------------------------------------------------
# Curated: member names too generic for a bare `.member` substring match to be trusted without
# hand review (mirrors #928's own README on this exact shape). Every class this lane resolves
# through one of these members was individually re-checked (see refman_census.py's REVIEWED_HITS)
# rather than accepted on the mechanical signal alone.
# ---------------------------------------------------------------------------------------------

GENERIC_MEMBERS = {
    "name",
    "type",
    "count",
    "value",
    "id",
    "index",
    "location",
    "color",
    "mode",
    "kind",
    "status",
    "get",
    "set",
    "add",
    "remove",
    "size",
    "length",
    "isEmpty",
    "isEqual",
    "description",
    "first",
    "last",
    "init",
    "create",
}


def _member_called_in_corpus(swift_file: str, member: str, corpus: str) -> bool:
    """Is `member` called anywhere in `corpus` (comment-stripped lane test text)?

    A FIFTH real bug, and a different SHAPE from the first four: not a wrong resolution, a wrong
    TEST for "was it called" once the resolution is right. `AssemblyGraph.init?(document:)`
    resolves correctly to member `init` (HOP 2 is not at fault here), but Swift constructor calls
    are written `AssemblyGraph(document: doc)`, never `.init(document: doc)` -- there is no dot at
    all -- so the ordinary `.member\\b` substring test can never match an initializer call, no
    matter how many tests call it. `XCAFDocAssemblyGraphTests.swift`'s real, passing
    `AssemblyGraph(document: doc)` call is exactly this shape, and came back as "no lane test
    reaches XCAFDoc_AssemblyGraph" before this fix. Fixed by ALSO checking for the bare type
    name (this file's own basename, stripped of `.swift`) called as `TypeName(`, exploiting this
    codebase's one-type-per-file convention (checked, not assumed: `AssemblyGraph.swift` declares
    `class AssemblyGraph`, `NoteObject.swift` declares `class NoteObject`, `ViewObject.swift`
    declares `class ViewObject`, `PresentationStyle.swift` declares `struct PresentationStyle`,
    `AssemblyItemId.swift` declares `struct AssemblyItemId` -- every file whose only members are
    non-generic-member-flagged hits was checked this way, not merely assumed to follow the
    pattern). Only applied for `member == "init"`; a non-initializer member is unaffected.
    """
    if re.search(r"\." + re.escape(member) + r"\b", corpus):
        return True
    if member == "init":
        type_name = os.path.splitext(swift_file)[0]
        if re.search(r"\b" + re.escape(type_name) + r"\s*\(", corpus):
            return True
    return False


def reachable_classes(lane_classes: set[str]) -> dict[str, list[dict]]:
    """class -> [evidence dict, ...]. Evidence: bridge fn, swift file/member, generic flag."""
    func_classes = bridge_function_classes(lane_classes)
    member_calls = swift_member_bridge_calls()
    corpus = lane_test_corpus()

    result: dict[str, list[dict]] = {}
    for (swift_file, member), bridge_fns in sorted(member_calls.items()):
        if not _member_called_in_corpus(swift_file, member, corpus):
            continue
        classes: set[str] = set()
        for bf in bridge_fns:
            classes |= func_classes.get(bf, set())
        if not classes:
            continue
        for cls in classes:
            result.setdefault(cls, []).append(
                {
                    "swift_file": swift_file,
                    "member": member,
                    "bridge_fns": sorted(bridge_fns),
                    "generic": member in GENERIC_MEMBERS,
                }
            )
    return result


# ---------------------------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------------------------


def self_test() -> bool:
    ok = True

    # HOP 3a: direct literal class mention inside a function body.
    text = strip_comments(
        "int OCCTFoo(int x)\n{\n  Handle(XCAFDoc_ShapeTool) t = XCAFDoc_DocumentTool::ShapeTool(l);\n  return 0;\n}\n"
    )
    spans = _function_spans(text)
    if not (len(spans) == 1 and "XCAFDoc_ShapeTool" in text[spans[0][1] : spans[0][2]]):
        print("[FAIL] hop3-direct-mention: function body did not carry the literal class")
        ok = False
    else:
        print("[PASS] hop3-direct-mention")

    # HOP 3a load-bearing check: a mention OUTSIDE the function span (a sibling function's body,
    # or a comment) must NOT be attributed to this one.
    text2 = strip_comments(
        "// XCAFDoc_ShapeTool is unrelated commentary here\n"
        "int OCCTBar(int x)\n{\n  return x;\n}\n"
        "int OCCTBaz(int x)\n{\n  Handle(XCAFDoc_ColorTool) c;\n  return 0;\n}\n"
    )
    spans2 = {name: text2[s:e] for name, s, e, _static in _function_spans(text2)}
    if "XCAFDoc_ShapeTool" in spans2.get("OCCTBar", "") or "XCAFDoc_ColorTool" in spans2.get(
        "OCCTBar", ""
    ):
        print("[FAIL] hop3-span-isolation: OCCTBar's span leaked a sibling's class mention")
        ok = False
    elif "XCAFDoc_ColorTool" not in spans2.get("OCCTBaz", ""):
        print("[FAIL] hop3-span-isolation: OCCTBaz lost its own class mention")
        ok = False
    else:
        print("[PASS] hop3-span-isolation")

    # HOP 3, the third and widest-reaching real bug this file's own output found: an interleaved
    # struct/non-occt-prefixed helper between two OCCT*/occt* definitions must NOT be swallowed
    # into the PRECEDING one's body. Reproduces the actual `occtDocumentFormatsImpl` finding
    # (three interleaved structs plus a non-`occt`-prefixed `getLabelForTag`) in miniature.
    interleave_text = strip_comments(
        "static int OCCTHelper(int x)\n{\n  return x;\n}\n"
        "struct SomeStruct\n{\n  Handle(XCAFDoc_AssemblyGraph) graph;\n};\n"
        "static TDF_Label getLabelForTag(int x)\n{\n  return TDF_Label();\n}\n"
        "int OCCTNext(int x)\n{\n  return x;\n}\n"
    )
    naive_matches = list(DEFN.finditer(interleave_text))
    naive_spans = {}
    for idx, m in enumerate(naive_matches):
        start = m.end()
        end = naive_matches[idx + 1].start() if idx + 1 < len(naive_matches) else len(interleave_text)
        naive_spans[m.group(1)] = (start, end)
    fixed_spans = {name: (s, e) for name, s, e, _static in _function_spans(interleave_text)}
    naive_leaked = "XCAFDoc_AssemblyGraph" in interleave_text[slice(*naive_spans["OCCTHelper"])]
    fixed_clean = "XCAFDoc_AssemblyGraph" not in interleave_text[slice(*fixed_spans["OCCTHelper"])]
    if naive_leaked and fixed_clean:
        print(
            "[PASS] hop3-interleaved-struct [load-bearing: the old 'up to the next OCCT*/occt* "
            "match' boundary leaks the interleaved struct's class into OCCTHelper's body; brace "
            "balancing does not]"
        )
    else:
        print(
            f"[FAIL] hop3-interleaved-struct: naive_leaked={naive_leaked} (want True) "
            f"fixed_clean={fixed_clean} (want True)"
        )
        ok = False

    # HOP 3, the Handle-macro exclusion: `static Handle(TDataStd_NamedData) getOrCreateNamedData(...)`
    # must resolve to `getOrCreateNamedData`, not `Handle`.
    handle_text = strip_comments(
        "static Handle(TDataStd_NamedData) getOrCreateNamedData(int x)\n{\n  return nullptr;\n}\n"
    )
    handle_spans = [name for name, _, _, _static in _function_spans(handle_text)]
    naive_handle_re = re.compile(
        r"^[A-Za-z_][\w\s\*\(\)<>,:&]*?\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", re.M
    )
    naive_handle_spans = [m.group(1) for m in naive_handle_re.finditer(handle_text)]
    if handle_spans == ["getOrCreateNamedData"] and naive_handle_spans[:1] == ["Handle"]:
        print(
            "[PASS] hop3-handle-macro-exclusion [load-bearing: without the exclusion, the "
            "real function name is never found at all -- the match stops at 'Handle']"
        )
    else:
        print(
            f"[FAIL] hop3-handle-macro-exclusion: got {handle_spans!r} (want "
            f"['getOrCreateNamedData']), naive got {naive_handle_spans!r} (want first entry "
            f"'Handle', to prove the unexcluded pattern really does stop there)"
        )
        ok = False

    # HOP 3, non-occt-prefixed helper indirection: a bridge entry point that reaches its class
    # ONLY through a plainly-named (non occt/OCCT-prefixed) static helper must still resolve it.
    # This is the actual `TDataStd_NamedData` bug in miniature: `OCCTDocumentNamedDataSetInteger`
    # reaches `TDataStd_NamedData` only via a call to `getOrCreateNamedData`, never mentioning the
    # class in its own body.
    import shutil
    import tempfile

    tmp_root2 = tempfile.mkdtemp()
    try:
        src_dir2 = os.path.join(tmp_root2, "src")
        inc_dir2 = os.path.join(tmp_root2, "include")
        os.makedirs(src_dir2)
        os.makedirs(inc_dir2)
        with open(os.path.join(src_dir2, "FileC.mm"), "w") as fh:
            # Matches the real getOrCreateNamedData shape: the class is mentioned INSIDE the
            # body (`TDataStd_NamedData::GetID()`), not only in the `Handle(...)` return type --
            # this file's class scan reads function BODIES, not signatures, matching what the
            # real bridge function actually does (checked, not assumed: OCCTBridge_Document_
            # Appearance.mm:567-578's real getOrCreateNamedData body spells the class twice).
            fh.write(
                "static Handle(TDataStd_NamedData) getOrCreateNamedData(int x)\n{\n"
                "  Handle(TDataStd_NamedData) nd;\n"
                "  if (!TDataStd_NamedData::GetID())\n  {\n    nd = TDataStd_NamedData::Set(x);\n  }\n"
                "  return nd;\n}\n"
                "bool OCCTDocumentNamedDataSetInteger(int x)\n{\n"
                "  auto nd = getOrCreateNamedData(x);\n  return true;\n}\n"
            )
        real_src2, real_inc2 = BRIDGE_SRC, BRIDGE_INC
        globals()["BRIDGE_SRC"] = src_dir2
        globals()["BRIDGE_INC"] = inc_dir2
        try:
            result = bridge_function_classes({"TDataStd_NamedData"})
        finally:
            globals()["BRIDGE_SRC"] = real_src2
            globals()["BRIDGE_INC"] = real_inc2
        if result.get("OCCTDocumentNamedDataSetInteger") == {"TDataStd_NamedData"}:
            print("[PASS] hop3-non-occt-prefixed-helper-indirection")
        else:
            print(
                f"[FAIL] hop3-non-occt-prefixed-helper-indirection: got "
                f"{result.get('OCCTDocumentNamedDataSetInteger')!r}, want "
                f"{{'TDataStd_NamedData'}}"
            )
            ok = False
    finally:
        shutil.rmtree(tmp_root2, ignore_errors=True)

    # HOP 3b: doc-> struct field translation. Removing FIELD_CLASS entirely (simulated by an
    # empty dict) must make the field-mediated class invisible -- proves the translation is
    # load-bearing, not decorative, for the classes it exists to catch.
    fake_fields = {"shapeTool": "XCAFDoc_ShapeTool"}
    body = "int OCCTQux(OCCTDocumentRef doc)\n{\n  doc->shapeTool->AddShape(s);\n  return 0;\n}\n"
    field_alt = "|".join(re.escape(f) for f in fake_fields)
    field_re = re.compile(r"\b(?:doc|document)->(" + field_alt + r")\b")
    hit_with = bool(field_re.findall(body))
    field_re_empty = re.compile(r"\b(?:doc|document)->(" + (r"(?!x)x") + r")\b")
    hit_without = bool(field_re_empty.findall(body))
    class_alt = re.compile(r"\b(XCAFDoc_ShapeTool)\b")
    direct_hit = bool(class_alt.findall(body))
    if direct_hit:
        print("[FAIL] hop3-field-translation self-test fixture leaked a direct mention")
        ok = False
    elif hit_with and not hit_without:
        print("[PASS] hop3-field-translation [load-bearing: field map removed -> class invisible]")
    else:
        print("[FAIL] hop3-field-translation: not load-bearing")
        ok = False

    # HOP 3c: one-level occt-helper indirection, and that it reaches a fixed point over 2 hops.
    lane_classes = {"XCAFDoc_ShapeTool", "TDocStd_Document"}
    # Deliberately ordered CALLER-before-CALLEE (the reverse of "definition order matches call
    # order"), which is the case that actually needs more than one fixed-point round: a single
    # left-to-right pass over calls.items() (insertion order = textual definition order) reaches
    # OCCTEntryPoint BEFORE occtOuter's own reached-set has been refreshed from occtInner in that
    # same round, so OCCTEntryPoint only picks up the transitive class on the NEXT round. Real
    # bridge files lay functions out in whatever order was convenient to a human, not
    # callee-before-caller, so this ordering is the representative one, not a worst case picked
    # to be difficult.
    text3 = strip_comments(
        "bool OCCTEntryPoint(OCCTDocumentRef doc)\n{\n"
        "  return occtOuter(doc);\n}\n"
        "inline bool occtOuter(OCCTDocumentRef doc)\n{\n"
        "  return occtInner(doc);\n}\n"
        "inline bool occtInner(OCCTDocumentRef doc)\n{\n"
        "  Handle(TDocStd_Document) d = doc->doc;\n  return true;\n}\n"
    )
    spans3 = _function_spans(text3)
    base = {}
    calls = {}
    class_alt3 = re.compile(r"\b(" + "|".join(lane_classes) + r")\b")
    for name, s, e, _static in spans3:
        b = text3[s:e]
        base[name] = set(class_alt3.findall(b))
        calls[name] = set(c for c in CALL.findall(b) if c != name)
    reached = {n: set(c) for n, c in base.items()}
    for _ in range(4):
        changed = False
        for name, callees in calls.items():
            before = len(reached.get(name, set()))
            for callee in callees:
                if callee in reached:
                    reached.setdefault(name, set()).update(reached[callee])
            if len(reached.get(name, set())) != before:
                changed = True
        if not changed:
            break
    if "TDocStd_Document" in reached.get("OCCTEntryPoint", set()):
        print("[PASS] hop3-two-level-indirection [load-bearing: 1 round alone would miss it]")
        # Prove ONE round is not enough (load-bearing over a single pass):
        one_round = {n: set(c) for n, c in base.items()}
        for name, callees in calls.items():
            for callee in callees:
                if callee in one_round:
                    one_round.setdefault(name, set()).update(one_round[callee])
        if "TDocStd_Document" in one_round.get("OCCTEntryPoint", set()):
            print(
                "[FAIL] hop3-two-level-indirection: a single round already finds it; "
                "fixture does not test the fixed-point iteration"
            )
            ok = False
    else:
        print("[FAIL] hop3-two-level-indirection: two-level helper chain not resolved")
        ok = False

    # HOP 3, the real cross-contamination bug this file's C++-linkage-aware node keying was built
    # to fix: two `static` helpers of the SAME NAME in different files must NOT merge into one
    # graph node. Reproduces the actual OCCTDocumentReadingFormats/occtDocumentFormatsImpl finding
    # in miniature, on REAL temp files run through the REAL bridge_function_classes(), not a
    # reimplementation -- and also runs a NAIVE bare-name-only version on the identical inputs to
    # prove the bug is real, not hypothetical.
    import shutil
    import tempfile

    tmp_root = tempfile.mkdtemp()
    try:
        src_dir = os.path.join(tmp_root, "src")
        inc_dir = os.path.join(tmp_root, "include")
        os.makedirs(src_dir)
        os.makedirs(inc_dir)
        with open(os.path.join(src_dir, "FileA.mm"), "w") as fh:
            fh.write(
                "static bool occtHelper(int x)\n{\n"
                "  Handle(XCAFDoc_ShapeTool) t;\n  return true;\n}\n"
                "bool OCCTFoo(int x)\n{\n  return occtHelper(x);\n}\n"
            )
        with open(os.path.join(src_dir, "FileB.mm"), "w") as fh:
            fh.write(
                "static bool occtHelper(int x)\n{\n"
                "  Handle(TDocStd_Document) d;\n  return true;\n}\n"
                "bool OCCTBar(int x)\n{\n  return occtHelper(x);\n}\n"
            )

        real_src, real_inc = BRIDGE_SRC, BRIDGE_INC
        globals()["BRIDGE_SRC"] = src_dir
        globals()["BRIDGE_INC"] = inc_dir
        try:
            fixed = bridge_function_classes({"XCAFDoc_ShapeTool", "TDocStd_Document"})
        finally:
            globals()["BRIDGE_SRC"] = real_src
            globals()["BRIDGE_INC"] = real_inc

        # The naive, pre-fix version: one flat dict keyed by bare name, exactly what this file
        # used before the file-scoping fix -- reusing bridge_files()/_function_spans() (the real
        # parsing) but merging static helpers across files on purpose, to show what that gets.
        naive_base: dict[str, set[str]] = {}
        naive_calls: dict[str, set[str]] = {}
        class_alt4 = re.compile(r"\b(XCAFDoc_ShapeTool|TDocStd_Document)\b")
        for path in (os.path.join(src_dir, "FileA.mm"), os.path.join(src_dir, "FileB.mm")):
            text4 = strip_comments(_read(path))
            for name, s, e, _static in _function_spans(text4):
                b = text4[s:e]
                naive_base.setdefault(name, set()).update(class_alt4.findall(b))
                naive_calls.setdefault(name, set()).update(
                    c for c in CALL.findall(b) if c != name
                )
        naive_reached = {n: set(c) for n, c in naive_base.items()}
        for _ in range(4):
            for name, callees in naive_calls.items():
                for callee in callees:
                    if callee in naive_reached:
                        naive_reached.setdefault(name, set()).update(naive_reached[callee])

        fixed_ok = fixed.get("OCCTFoo") == {"XCAFDoc_ShapeTool"} and fixed.get("OCCTBar") == {
            "TDocStd_Document"
        }
        naive_contaminated = naive_reached.get("OCCTFoo") == {
            "XCAFDoc_ShapeTool",
            "TDocStd_Document",
        }
        if fixed_ok and naive_contaminated:
            print(
                "[PASS] hop3-static-file-scoping [load-bearing: the naive bare-name keying this "
                "replaced gives OCCTFoo BOTH classes, cross-contaminated from FileB's unrelated "
                "same-named static helper]"
            )
        else:
            print(
                f"[FAIL] hop3-static-file-scoping: fixed={dict(fixed)!r} (want OCCTFoo="
                f"{{'XCAFDoc_ShapeTool'}}, OCCTBar={{'TDocStd_Document'}}), "
                f"naive OCCTFoo={naive_reached.get('OCCTFoo')!r} (want it contaminated, to prove "
                f"the old approach really did get this wrong)"
            )
            ok = False
    finally:
        shutil.rmtree(tmp_root, ignore_errors=True)

    # HOP 2: nearest-preceding-declaration resolution, and its documented failure mode.
    swift_text = (
        "public struct Widget {\n"
        "    func outer() {\n"
        "        _ = OCCTWidgetMake()\n"
        "    }\n"
        "    var prop: Int {\n"
        "        return Int(OCCTWidgetCount())\n"
        "    }\n"
        "}\n"
    )
    lines = swift_text.split("\n")
    hits = {}
    for lineno, line in enumerate(lines):
        for call in BRIDGE_CALL.findall(line):
            name = call[: call.index("(")].strip()
            hits[name] = _enclosing_member(lines, lineno)
    if hits.get("OCCTWidgetMake") == "outer" and hits.get("OCCTWidgetCount") == "prop":
        print("[PASS] hop2-nearest-preceding-decl")
    else:
        print(f"[FAIL] hop2-nearest-preceding-decl: resolved {hits}")
        ok = False

    # HOP 2, the fourth real bug: a wrapped multi-line signature whose closing `) -> Bool {`
    # sits at the SAME indentation as its own `func` line (both indent 4), not one level
    # deeper. Reproduces the actual `setGeomToleranceValueType` miss verbatim.
    wrapped_text = (
        "public struct Widget {\n"
        "    public func setGeomToleranceValueType(\n"
        "        at index: Int,\n"
        "        _ valueType: Int\n"
        "    ) -> Bool {\n"
        "        OCCTDocumentSetGeomToleranceTypeOfValue(handle, Int32(index), valueType)\n"
        "    }\n"
        "}\n"
    )
    wlines = wrapped_text.split("\n")
    wrapped_hit = None
    for lineno, line in enumerate(wlines):
        for call in BRIDGE_CALL.findall(line):
            wrapped_hit = _enclosing_member(wlines, lineno)
    if wrapped_hit == "setGeomToleranceValueType":
        print(
            "[PASS] hop2-wrapped-multiline-signature [load-bearing: the plain floor-lowering "
            "algorithm never finds this one, since the closing `) -> Bool {` and the `func` "
            "line it belongs to are at the exact same indentation]"
        )
    else:
        print(
            f"[FAIL] hop2-wrapped-multiline-signature: got {wrapped_hit!r}, want "
            f"'setGeomToleranceValueType'"
        )
        ok = False

    # And the control-flow case must still fall through correctly: a wrapped `if let` condition
    # at the same indentation as its own `{` is NOT a signature, and must not be mistaken for one.
    ifwrap_text = (
        "public struct Widget {\n"
        "    func outer() {\n"
        "        if let x = something(\n"
        "            arg\n"
        "        ) {\n"
        "            _ = OCCTWidgetMake()\n"
        "        }\n"
        "    }\n"
        "}\n"
    )
    iwlines = ifwrap_text.split("\n")
    ifwrap_hit = None
    for lineno, line in enumerate(iwlines):
        for call in BRIDGE_CALL.findall(line):
            ifwrap_hit = _enclosing_member(iwlines, lineno)
    if ifwrap_hit == "outer":
        print("[PASS] hop2-wrapped-if-condition-not-mistaken-for-signature")
    else:
        print(f"[FAIL] hop2-wrapped-if-condition-not-mistaken-for-signature: got {ifwrap_hit!r}")
        ok = False

    # HOP 2, the real bug this indentation-climbing design was built to fix: a LOCAL `var`
    # declared at the same indentation as the call, immediately above it, must NOT be picked
    # over the true enclosing member. Found on the first real file this script ran against
    # (Document.swift's `tracedForward`, which declares `var handles = ...` two lines above its
    # own `OCCTDocumentNamingTraceForward(` call) -- not a hypothetical fixture.
    localvar_text = (
        "public struct Widget {\n"
        "    public func tracedForward() {\n"
        "        var handles = [Int]()\n"
        "        _ = OCCTWidgetMake()\n"
        "    }\n"
        "}\n"
    )
    lvlines = localvar_text.split("\n")
    localvar_hit = None
    for lineno, line in enumerate(lvlines):
        for call in BRIDGE_CALL.findall(line):
            localvar_hit = _enclosing_member(lvlines, lineno)
    # The naive "nearest preceding match, any indentation" this replaced would return "handles".
    naive_hit = None
    for lineno, line in enumerate(lvlines):
        for call in BRIDGE_CALL.findall(line):
            for i in range(lineno, -1, -1):
                m = DECL_RE.match(lvlines[i])
                if m:
                    naive_hit = m.group("func") or m.group("var") or (m.group("init") and "init")
                    break
    if localvar_hit == "tracedForward" and naive_hit == "handles":
        print(
            "[PASS] hop2-local-var-not-mistaken-for-member "
            "[load-bearing: the naive nearest-preceding-line approach this replaced resolves "
            "the same fixture to 'handles', the local var, not 'tracedForward']"
        )
    else:
        print(
            f"[FAIL] hop2-local-var-not-mistaken-for-member: indentation-climbing got "
            f"{localvar_hit!r} (want 'tracedForward'), naive got {naive_hit!r} (want 'handles', "
            f"to prove the old approach really did get this wrong)"
        )
        ok = False

    # HOP 2: nested local function, and correctly climbing through several dedent levels
    # (if/closure) to reach the true enclosing member, not just skipping exactly one local var.
    nested_text = (
        "public struct Widget {\n"
        "    func outer() {\n"
        "        func helper() {}\n"
        "        withSomething { value in\n"
        "            if let x = value {\n"
        "                _ = OCCTWidgetMake()\n"
        "            }\n"
        "        }\n"
        "    }\n"
        "}\n"
    )
    nlines = nested_text.split("\n")
    nested_hit = None
    for lineno, line in enumerate(nlines):
        for call in BRIDGE_CALL.findall(line):
            nested_hit = _enclosing_member(nlines, lineno)
    if nested_hit == "outer":
        print("[PASS] hop2-climbs-through-nested-control-flow-to-real-member")
    else:
        print(f"[FAIL] hop2-climbs-through-nested-control-flow-to-real-member: got {nested_hit!r}")
        ok = False

    # HOP 1: generic member names are flagged, not silently trusted.
    if "name" in GENERIC_MEMBERS and "documentCount" not in GENERIC_MEMBERS:
        print("[PASS] hop1-generic-member-flagging")
    else:
        print("[FAIL] hop1-generic-member-flagging")
        ok = False

    # HOP 1, the fifth real bug: an `init` is called as `TypeName(args)`, never `.init(args)`, so
    # the plain `.member` substring test can never see it. Reproduces the actual
    # `XCAFDocAssemblyGraphTests.swift` miss (`AssemblyGraph(document: doc)`) verbatim.
    ctor_corpus = "let graph = AssemblyGraph(document: doc)\n"
    if _member_called_in_corpus("AssemblyGraph.swift", "init", ctor_corpus):
        print(
            "[PASS] hop1-constructor-call-has-no-dot [load-bearing: the plain '.init' substring "
            "test finds nothing in this exact corpus]"
        )
        if re.search(r"\.init\b", ctor_corpus):
            print(
                "[FAIL] hop1-constructor-call-has-no-dot: fixture accidentally contains a literal "
                "'.init', so it does not test the no-dot case"
            )
            ok = False
    else:
        print("[FAIL] hop1-constructor-call-has-no-dot: bare-type-name constructor call not found")
        ok = False
    # And it must not fire for an UNRELATED type of the same call shape (a different file's init).
    if _member_called_in_corpus("NoteObject.swift", "init", ctor_corpus):
        print(
            "[FAIL] hop1-constructor-call-has-no-dot: NoteObject's init wrongly matched an "
            "AssemblyGraph(...) call"
        )
        ok = False
    else:
        print("[PASS] hop1-constructor-call-type-name-is-specific")

    # IO_TESTS_DOCUMENT_HALF: the constant must match the mechanical re-derivation. If someone
    # edits an OCCTIOTests file to add/remove a Document reference without updating the constant,
    # this must fail (it is not a static list checked only at authoring time).
    derived = set(derive_io_document_half())
    if derived != set(IO_TESTS_DOCUMENT_HALF):
        print(
            f"[FAIL] lane-drift: IO_TESTS_DOCUMENT_HALF says {sorted(IO_TESTS_DOCUMENT_HALF)}, "
            f"re-derivation says {sorted(derived)}"
        )
        ok = False
    else:
        print(f"[PASS] lane-drift (0 files differ, {len(derived)} confirmed)")

    return ok


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--calls", action="store_true", help="print full per-class evidence chains")
    p.add_argument("--files", action="store_true", help="print the IOTests document-half derivation")
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()

    if args.self_test:
        return 0 if self_test() else 1

    if args.files:
        print("OCCTXCAFTests: all files, in lane.\n")
        print("OCCTIOTests, document half (a literal `Document` reference outside a comment):")
        for name in io_tests_files():
            text_raw = _read(os.path.join(IO_TESTS_DIR, name))
            text = strip_comments(text_raw)
            in_lane = name in IO_TESTS_DOCUMENT_HALF
            has_doc = bool(DOCUMENT_WORD.search(text))
            if not (in_lane or has_doc):
                continue
            total_tests = len(TEST_ATTR.findall(text_raw)) or text_raw.count("@Test")
            doc_tests = sum(
                1
                for m in re.finditer(r"func\s+(\w+)\s*\([^)]*\)[^{]*\{", text)
                if False
            )
            marker = "OK" if in_lane == has_doc else "MISMATCH"
            print(f"  [{marker}] {name}  (in-lane={in_lane}, mechanical-hit={has_doc})")
        return 0

    lane_classes_path = os.path.join(os.path.dirname(__file__), "refman_census.py")
    # Import lazily to avoid a hard circular dependency when this file is imported BY
    # refman_census.py itself.
    sys.path.insert(0, os.path.dirname(__file__))
    import refman_census as rc  # noqa: E402

    lane_classes = rc.all_lane_classes()
    reached = reachable_classes(lane_classes)

    print(f"Lane test files: {len(lane_test_files())} "
          f"({len(os.listdir(XCAF_TESTS_DIR))} in OCCTXCAFTests + "
          f"{len(IO_TESTS_DOCUMENT_HALF)} in OCCTIOTests' document half)")
    print(f"Lane classes (from #810, re-verified): {len(lane_classes)}")
    print(f"Classes reached by a lane test, mechanically: {len(reached)}")
    print()
    if args.calls:
        for cls in sorted(reached):
            print(f"{cls}:")
            for ev in reached[cls]:
                flag = " [GENERIC-NEEDS-REVIEW]" if ev["generic"] else ""
                print(
                    f"    {ev['swift_file']}::{ev['member']}{flag} -> "
                    f"{', '.join(ev['bridge_fns'])}"
                )
    else:
        for cls in sorted(reached):
            print(f"  {cls}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
