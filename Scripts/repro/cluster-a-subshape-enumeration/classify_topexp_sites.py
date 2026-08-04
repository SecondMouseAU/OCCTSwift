#!/usr/bin/env python3
"""Cluster A census (#664), static half: classify every TopExp_Explorer / TopExp::MapShapes
call site in the OCCTBridge .mm sources as DEDUP, OCCURRENCE or OTHER.

This is the SECONDARY, cross-check evidence the census README describes -- not the primary
evidence. #664 is explicit that a grep-shaped classifier "must not be the primary evidence: a
shared helper, a cast, or an entry point that walks via another entry point will all defeat it."
This script is exactly that kind of grep-shaped classifier: it finds a C function's own body and
looks for textual patterns, so it is blind to indirection (a helper called BY the function that
does the real walk) and to functions that share a header comment but not a body. It exists to be
compared against the DYNAMIC measurement in main.swift / README.md, not to replace it. Where the
two disagree, that disagreement is the most valuable output (README.md's "static vs dynamic"
section).

Classification per C function definition found in Sources/OCCTBridge/src/*.mm:

  DEDUP      -- the function calls `TopExp::MapShapes` (any of the three overloads:
                `MapShapes`, `MapShapesAndAncestors`, `MapShapesAndUniqueAncestors`), or builds an
                indexed/plain shape map (`TopTools_IndexedMapOfShape` / `TopTools_MapOfShape` /
                `NCollection_IndexedMap<TopoDS_Shape>`) and calls `.Add(` on it from inside a
                `TopExp_Explorer` loop -- the hand-rolled-dedup shape #664 asks a static check to
                still recognise.
  OCCURRENCE -- the function has a bare `TopExp_Explorer` loop (a `for`/`while` whose condition
                calls `.More()`) with no DEDUP structure anywhere in the same function, and the
                loop is not a find-first-then-break (see OTHER below).
  OTHER      -- anything else: no live TopExp usage in the function (comment-only or an unrelated
                match), or a `TopExp_Explorer` used to find a single match and `break`/`return`
                within a few lines of entering the loop, which is existence-checking rather than
                enumeration.

Usage:
    python3 classify_topexp_sites.py              # print the classification table
    python3 classify_topexp_sites.py --self-test   # prove the classifier on known fixtures
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
BRIDGE_SRC = REPO_ROOT / "Sources" / "OCCTBridge" / "src"
BRIDGE_INCLUDE = REPO_ROOT / "Sources" / "OCCTBridge" / "include"
SWIFT_SRC = REPO_ROOT / "Sources" / "OCCTSwift"

MAPSHAPES_RE = re.compile(r"TopExp::MapShapes(AndAncestors|AndUniqueAncestors)?\s*\(")
EXPLORER_RE = re.compile(r"TopExp_Explorer\s+\w+\s*\(")
MAP_DECL_RE = re.compile(
    r"(TopTools_IndexedMapOfShape|TopTools_MapOfShape|NCollection_IndexedMap\s*<\s*TopoDS_Shape\s*>)\s+(\w+)"
)
MAP_ADD_RE = re.compile(r"\b(\w+)\.Add\s*\(")
MORE_RE = re.compile(r"\.More\s*\(\s*\)")
BREAK_OR_RETURN_RE = re.compile(r"\b(break|return[^;]*)\s*;")

# A C function definition: return-type-ish tokens, a name starting with a letter, a paren'd
# parameter list, then an opening brace on the same or a later line. Deliberately permissive: this
# is a classifier, not a C++ parser, and every function in this bridge follows this shape.
FUNC_START_RE = re.compile(
    r"^[ \t]*(?:[A-Za-z_][\w:<>\*&\s,]*?)\s+(\b[A-Za-z_]\w*)\s*\(([^;{}()]*)\)\s*\{", re.MULTILINE
)


HANDLE_MACRO_RE = re.compile(r"\bHandle\(\s*[\w:]+\s*\)")


def _blank_handle_macro(text):
    """Collapse OCCT's `Handle(Type)` return-type/cast idiom to a same-length run of `_`.

    `Handle(Type)` contains a nested paren pair, which defeats FUNC_START_RE's single-level
    `\\(...\\)` parameter-list match: on `static Handle(Poly_Triangulation) occtMergedTriangulation(...)`
    the naive regex either captures "Handle" as the function name (swallowing everything up to the
    real closing paren, an early bug this comment replaces) or, once that greedy span is
    disallowed, fails to match the line at all and silently drops a real function -- worse, since a
    dropped function is invisible rather than mislabeled. Blanking the macro to a same-length,
    paren-free placeholder BEFORE matching keeps every byte offset valid (so brace-matching against
    the same string still lines up) while letting the return-type portion of FUNC_START_RE span
    across it like any other identifier.
    """
    return HANDLE_MACRO_RE.sub(lambda m: "H" + "_" * (len(m.group(0)) - 1), text)


def split_functions(text):
    """Yield (name, body) for each top-level C/ObjC++ function definition in `text`.

    Brace-depth matching from the opening `{` found by FUNC_START_RE. Skips anything whose
    "name(args) {" is actually a control-flow construct (if/for/while/switch/catch) by name
    filtering, and skips matches inside a `//` line comment.
    """
    text = _blank_handle_macro(text)
    control_words = {"if", "for", "while", "switch", "catch", "return", "sizeof"}
    functions = []
    for m in FUNC_START_RE.finditer(text):
        name = m.group(1)
        if name in control_words:
            continue
        line_start = text.rfind("\n", 0, m.start()) + 1
        line = text[line_start:m.start()]
        if "//" in line:
            continue
        brace_start = m.end() - 1
        depth = 0
        i = brace_start
        while i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = text[brace_start:i + 1]
        functions.append((name, body))
    return functions


def strip_comments(text):
    """Remove // and /* */ comments so they cannot masquerade as live code."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"//[^\n]*", "", text)
    return text


NEXT_CALL_RE = re.compile(r"\.Next\s*\(\s*\)")


def _loop_body_span(code, explorer_start):
    """Find the body of the `for (TopExp_Explorer ...) BODY` starting near `explorer_start`, by
    anchoring on the loop header's `.Next())` close. `BODY` is either a braced block (brace-match
    it) or -- just as common in this bridge, e.g. `for (...; ex.More(); ex.Next()) count++;` --
    a single unbraced statement up to its own `;`. Getting this wrong is not academic: the first
    version of this script brace-matched the wrong `{` (the function's own `try`/`catch` block,
    the next one in the file) for every braceless loop, and a `catch (...) { return 0; }` a few
    lines later made every one of them look like a find-first `return` inside the loop. Returns
    (body_start, body_end) or None if the shape doesn't match."""
    next_match = NEXT_CALL_RE.search(code, explorer_start)
    if not next_match:
        return None
    for_close = code.find(")", next_match.end())
    if for_close == -1:
        return None
    i = for_close + 1
    while i < len(code) and code[i].isspace():
        i += 1
    if i >= len(code):
        return None
    if code[i] == "{":
        depth = 0
        j = i
        while j < len(code):
            if code[j] == "{":
                depth += 1
            elif code[j] == "}":
                depth -= 1
                if depth == 0:
                    return (i, j + 1)
            j += 1
        return None
    # Braceless single-statement loop body: up to its own terminating `;`.
    semi = code.find(";", i)
    if semi == -1:
        return None
    return (i, semi + 1)


def classify_body(body):
    """Classify one function body. Returns (verdict, reason)."""
    code = strip_comments(body)

    if MAPSHAPES_RE.search(code):
        return "DEDUP", "calls TopExp::MapShapes(AndAncestors/AndUniqueAncestors)"

    map_names = {mm.group(2) for mm in MAP_DECL_RE.finditer(code)}
    if map_names:
        for add_match in MAP_ADD_RE.finditer(code):
            if add_match.group(1) in map_names:
                return "DEDUP", f"builds {sorted(map_names)} and calls .Add() on it"

    explorer_matches = list(EXPLORER_RE.finditer(code))
    if not explorer_matches:
        return "OTHER", "no TopExp_Explorer / TopExp::MapShapes in this function"

    if not MORE_RE.search(code):
        return "OTHER", "TopExp_Explorer present but .More() never called (unused/dead declaration)"

    # Find-first: a `break` or `return` INSIDE the loop's own body (not after it, where an
    # accumulated count/array is legitimately returned once the walk is done).
    span = _loop_body_span(code, explorer_matches[0].start())
    if span is not None:
        loop_body = code[span[0]:span[1]]
        if BREAK_OR_RETURN_RE.search(loop_body):
            return "OTHER", "TopExp_Explorer loop contains a break/return (find-first, not an enumeration)"

    return "OCCURRENCE", "bare TopExp_Explorer loop, no dedup map in this function"


def classify_file(path):
    text = path.read_text()
    results = []
    for name, body in split_functions(text):
        code_only = strip_comments(body)
        if not (MAPSHAPES_RE.search(code_only) or EXPLORER_RE.search(code_only)):
            continue
        verdict, reason = classify_body(body)
        results.append((name, verdict, reason))
    return results


def swift_reachable_names():
    """C function names actually referenced from Sources/OCCTSwift/*.swift -- the reachability
    check that separates a genuine public entry point from an orphaned bridge function nobody
    calls (OCCTShapeCountFaces / OCCTShapeCountEdges are exactly this: declared and implemented,
    called from nowhere)."""
    names = set()
    for f in SWIFT_SRC.glob("*.swift"):
        text = f.read_text()
        for m in re.finditer(r"\bOCCT[A-Za-z0-9_]+\s*\(", text):
            names.add(m.group(0)[:-1].strip())
    return names


def header_declared_names():
    names = set()
    for f in BRIDGE_INCLUDE.glob("*.h"):
        text = f.read_text()
        for m in re.finditer(r"\b(OCCT[A-Za-z0-9_]+)\s*\(", text):
            names.add(m.group(1))
    return names


def run_report():
    reachable = swift_reachable_names()
    declared = header_declared_names()
    total = 0
    by_verdict = {"DEDUP": 0, "OCCURRENCE": 0, "OTHER": 0}
    print(f"{'file':<28} {'function':<42} {'verdict':<11} {'reachable?':<11} reason")
    print("-" * 140)
    for path in sorted(BRIDGE_SRC.glob("*.mm")):
        for name, verdict, reason in classify_file(path):
            total += 1
            by_verdict[verdict] += 1
            reach = "swift" if name in reachable else ("header-only" if name in declared else "internal")
            print(f"{path.name:<28} {name:<42} {verdict:<11} {reach:<11} {reason}")
    print("-" * 140)
    print(f"total functions containing TopExp usage: {total}")
    print(f"  DEDUP:      {by_verdict['DEDUP']}")
    print(f"  OCCURRENCE: {by_verdict['OCCURRENCE']}")
    print(f"  OTHER:      {by_verdict['OTHER']}")
    return 0


# ---------------------------------------------------------------------------
# Self-test: prove the classifier actually distinguishes the three verdicts,
# per okf/policies/prove-the-test-fails.md.
# ---------------------------------------------------------------------------

SELF_TEST_CASES = [
    (
        "dedup_literal_mapshapes",
        """
        int32_t OCCTFakeDedupLiteral(OCCTShapeRef shape) {
            TopTools_IndexedMapOfShape faceMap;
            TopExp::MapShapes(shape->shape, TopAbs_FACE, faceMap);
            return faceMap.Extent();
        }
        """,
        "DEDUP",
    ),
    (
        "dedup_hand_rolled_add",
        """
        int32_t OCCTFakeDedupHandRolled(OCCTShapeRef shape) {
            TopTools_IndexedMapOfShape seen;
            for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                seen.Add(exp.Current());
            }
            return seen.Extent();
        }
        """,
        "DEDUP",
    ),
    (
        "occurrence_bare_explorer",
        """
        int32_t OCCTFakeOccurrence(OCCTShapeRef shape) {
            int32_t count = 0;
            for (TopExp_Explorer exp(shape->shape, TopAbs_EDGE); exp.More(); exp.Next()) {
                count++;
            }
            return count;
        }
        """,
        "OCCURRENCE",
    ),
    (
        "other_find_first_break",
        """
        bool OCCTFakeFindFirst(OCCTShapeRef shape) {
            for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
                if (isTheOneWeWant(exp.Current())) {
                    break;
                }
            }
            return true;
        }
        """,
        "OTHER",
    ),
    (
        "other_comment_only",
        """
        void OCCTFakeCommentOnly(OCCTShapeRef shape) {
            // historically this used TopExp_Explorer; see OCCTShapeNbEdges for the real one.
            doSomethingElse(shape);
        }
        """,
        "OTHER",
    ),
    (
        # The exact shape of OCCTShapeCountFaces/OCCTShapeCountEdges/OCCTFaceWireCount: a
        # braceless single-statement loop body, followed (outside the loop) by a `catch` block
        # that itself contains a `return`. A version of this script that only knew how to
        # brace-match found that catch block's `{ return 0; }` instead of the (nonexistent) loop
        # braces, and misclassified every one of these three real functions as OTHER.
        "occurrence_braceless_loop_with_later_catch_return",
        """
        int32_t OCCTFakeBracelessLoop(OCCTShapeRef shape) {
            if (!shape) return 0;
            try {
                int count = 0;
                for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next()) count++;
                return count;
            } catch (...) { return 0; }
        }
        """,
        "OCCURRENCE",
    ),
]


def self_test(verbose=True):
    passed = 0
    failed = []
    for case_name, snippet, expected in SELF_TEST_CASES:
        funcs = split_functions(snippet)
        if not funcs:
            failed.append((case_name, expected, "NO FUNCTION PARSED"))
            continue
        _, body = funcs[0]
        verdict, reason = classify_body(body)
        ok = verdict == expected
        if ok:
            passed += 1
        else:
            failed.append((case_name, expected, verdict))
        if verbose:
            status = "PASS" if ok else "FAIL"
            print(f"[{status}] {case_name}: expected {expected}, got {verdict} ({reason})")
    print(f"\nself-test: {passed}/{len(SELF_TEST_CASES)} cases correct")
    if failed:
        print("failures:")
        for case_name, expected, got in failed:
            print(f"  {case_name}: expected {expected}, got {got}")
    return len(failed) == 0


def main():
    if "--self-test" in sys.argv:
        ok = self_test()
        return 0 if ok else 1
    return run_report()


if __name__ == "__main__":
    sys.exit(main())
