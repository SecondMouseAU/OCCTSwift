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
        #
        # NOTE (PR #693 review): this case does NOT prove `_loop_body_span`'s braceless dispatch
        # (`if code[i] == "{"`) is load-bearing. Forcing that check to always take the brace-match
        # path still lands on OCCURRENCE here, for a different reason (the depth-scan finds no
        # zero-crossing at all inside a braceless body with no braces of its own until the
        # trailing `catch`, so it returns None, and None defaults to OCCURRENCE too). Both the
        # correct code and the broken code agree by accident. Kept as a regression test for the
        # original brace-matching bug it documents; the dispatch guard itself is proven by
        # `other_braceless_find_first_with_later_catch_return` below.
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
    (
        # Same braceless-loop-then-catch shape as above, but the loop's single statement is
        # itself a find-first (`return true;`), so the correct and broken answers diverge: forcing
        # `if code[i] == "{"` to always take the brace-match path makes the depth-scan cross zero
        # on the CATCH block's closing brace with the wrong starting depth (it dips negative on
        # the `try`'s own closing brace first), never finds a legitimate zero-crossing, and
        # returns None -- which silently defaults to OCCURRENCE instead of the correct OTHER.
        "other_braceless_find_first_with_later_catch_return",
        """
        bool OCCTFakeBracelessFindFirst(OCCTShapeRef shape) {
            try {
                for (TopExp_Explorer ex(shape->shape, TopAbs_FACE); ex.More(); ex.Next())
                    if (isTheOneWeWant(ex.Current())) return true;
                return false;
            } catch (...) { return false; }
        }
        """,
        "OTHER",
    ),
    (
        # Models the real `static Handle(Poly_Triangulation) occtMergedTriangulation(...)`
        # (OCCTBridge_Document.mm). `Handle(Type)` nests a nested paren pair inside the return
        # type, which FUNC_START_RE's single-level `\\(...\\)` parameter match cannot cross.
        # `_blank_handle_macro` exists to blank it out before matching. With that guard
        # neutered, FUNC_START_RE cannot match this function's signature line at all --
        # `split_functions` returns no functions, and the case fails as NO FUNCTION PARSED,
        # not as a misclassification. No prior case in this list contains the literal text
        # `Handle(`, so this parser path was previously untested end to end.
        "occurrence_handle_return_type",
        """
        static Handle(Poly_Triangulation) OCCTFakeHandleReturnType(const TopoDS_Shape& shape) {
            int32_t count = 0;
            for (TopExp_Explorer exp(shape, TopAbs_FACE); exp.More(); exp.Next()) {
                count++;
            }
            if (count == 0) return Handle(Poly_Triangulation)();
            return new Poly_Triangulation();
        }
        """,
        "OCCURRENCE",
    ),
    (
        # Models the real `OCCTShapeFixSolid` (OCCTBridge_Healing.mm), whose loop body carries a
        # comment reading "...Shape() only ever returns the input solid, one fixed solid, or a
        # compound." Unstripped, `\\breturn` matches inside "returns" (the word boundary check
        # only anchors the START of the match) and `[^;]*` then swallows everything up to the
        # next real semicolon, which lands well past the comment, in genuine code -- a false
        # find-first match that flips the verdict from OCCURRENCE to OTHER. `strip_comments`'s
        # line-comment removal is what keeps this from happening; disabling it moved the real
        # census's OCCURRENCE/OTHER totals by one function in each direction (54/21 to 53/22),
        # a real effect the PR's own self-test run never caught.
        "occurrence_comment_contains_return_word",
        """
        int32_t OCCTFakeCommentMentionsReturn(OCCTShapeRef shape) {
            int32_t count = 0;
            for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
                // Shape() only ever returns the input solid, one fixed solid, or a compound;
                count++;
            }
            return count;
        }
        """,
        "OCCURRENCE",
    ),
    (
        # Same false-positive mechanism as the line-comment case above, for a `/* ... */` block
        # comment instead. No real function in the current bridge hits this (the equivalent
        # mutation leaves the real census unchanged), but the failure mode is identical and
        # untested without this case: nothing currently proves `strip_comments`' block-comment
        # removal is load-bearing, only that it happens not to matter yet.
        "occurrence_block_comment_contains_return_word",
        """
        int32_t OCCTFakeBlockCommentMentionsReturn(OCCTShapeRef shape) {
            int32_t count = 0;
            for (TopExp_Explorer exp(shape->shape, TopAbs_FACE); exp.More(); exp.Next()) {
                /* Shape() only ever returns the input solid, one fixed solid, or a compound; */
                count++;
            }
            return count;
        }
        """,
        "OCCURRENCE",
    ),
    (
        # A TopExp_Explorer used purely as "give me the first item of this type", never looped:
        # `.More()` is checked once and there is no `.Next()` anywhere in the function. Models
        # the real `occtShellIsInsideSolid`/`OCCTShapeCreateHalfSpace`/`OCCTSolidFromShells`
        # shape (OCCTBridge_Healing.mm / OCCTBridge_Modeling.mm), among others. `_loop_body_span`
        # cannot find a loop body at all here (there is no `.Next()` to anchor the search on);
        # the `if not next_match: return None` guard is what turns that into a graceful
        # "no span found" (classify_body then falls through to its OCCURRENCE default) instead of
        # an AttributeError crash calling `.end()` on `None`. Removing the guard does not change
        # the verdict here (both paths land on OCCURRENCE, since a span-less call always takes the
        # default) -- it crashes 10 real functions in the actual census outright, which is a
        # stronger, not weaker, argument for testing it: a self-test that reports 6/6 while this
        # guard has zero coverage is silent about a real crash-on-real-data risk. This case
        # exists to keep that guard from being removed unnoticed even though it cannot, by
        # construction, be proven via a verdict mismatch the way the other new cases are.
        "occurrence_explorer_checked_once_no_next_call",
        """
        bool OCCTFakeNoNextCall(OCCTShapeRef shape) {
            TopExp_Explorer exp(shape->shape, TopAbs_VERTEX);
            if (!exp.More()) return false;
            return true;
        }
        """,
        "OCCURRENCE",
    ),
    (
        # A TopExp_Explorer declared and never used again: no `.More()` call at all. Models the
        # "unused/dead declaration" branch's own stated reason. This function is called directly
        # by `self_test()`, bypassing `classify_file`'s own pre-filter (which only invokes
        # `classify_body` when TopExp usage is already known to exist) -- so unlike in
        # `run_report()`, a fixture reaching `classify_body` here is not guaranteed to have a
        # live `.More()` call, and this is the only case that exercises that branch at all.
        "other_dead_explorer_declaration",
        """
        int32_t OCCTFakeDeadExplorerDeclaration(OCCTShapeRef shape) {
            TopExp_Explorer exp(shape->shape, TopAbs_FACE);
            return 0;
        }
        """,
        "OTHER",
    ),
    (
        # No TopExp_Explorer or TopExp::MapShapes anywhere, but a DIFFERENT iterator's `.More()`
        # call is present (`MORE_RE` matches any `.More()`, not just a TopExp_Explorer's). In
        # `run_report()`, `classify_file`'s pre-filter means `classify_body` is never called on a
        # function like this at all. `self_test()` calls `classify_body` directly, bypassing that
        # filter -- so the `if not explorer_matches: return OTHER` guard is the only thing
        # standing between this shape and `explorer_matches[0]` on an empty list, an IndexError.
        "other_unrelated_iterator_no_topexp_usage",
        """
        int32_t OCCTFakeUnrelatedIterator(OCCTShapeRef shape) {
            TDF_ChildIterator it(shape->label);
            for (; it.More(); it.Next()) {
                doSomething(it.Value());
            }
            return 0;
        }
        """,
        "OTHER",
    ),
]


def self_test(verbose=True):
    passed = 0
    failed = []
    for case_name, snippet, expected in SELF_TEST_CASES:
        funcs = split_functions(snippet)
        if not funcs:
            verdict, reason = "NO FUNCTION PARSED", "split_functions() found no function in the fixture"
        else:
            _, body = funcs[0]
            # A guard removed by mutation can turn a graceful "wrong verdict" into an
            # uncaught exception (e.g. `_loop_body_span` dereferencing a None match). Catching
            # it here keeps the report a clean per-case matrix instead of a bare traceback that
            # stops evaluating every case after it -- the failure is exactly as real either way.
            try:
                verdict, reason = classify_body(body)
            except Exception as exc:
                verdict, reason = f"CRASH: {exc}", "unhandled exception in classify_body"
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
