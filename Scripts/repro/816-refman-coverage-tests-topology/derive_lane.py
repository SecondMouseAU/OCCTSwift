#!/usr/bin/env python3
r"""Issue #816 (Pass 5b of #807/#819): re-derive the test-side lane for Shape/Topology core.

Passes 5a-5d ask a different question from 2a-4d: not "is this OCCT class wrapped and documented"
but "does a TEST in this lane's targets actually exercise it". #816's lane is the five test
targets that mirror Pass 2a's (#808) source lane: `OCCTTopologyTests`, `OCCTModelingTests`,
`OCCTAnalysisTests`, `OCCTShapeHealingTests`, `OCCTBRepGraphTests`.

THE GROUND TRUTH IS #808's OWN CENSUS, RE-VERIFIED, NOT RETYPED. This file imports
`Scripts/repro/808-refman-shape-topology/refman_census.py` directly and calls its own
`_is_wrapped`/`_is_documented`/`classify`/`reverify_lane` rather than copying `LANE_CLASSES` by
hand, so a class list retyped here could not silently drift from the one #808 committed. Only the
classes that census marks `ok` (documented AND wrapped, #808's own two-question test) are this
pass's subject: an OCCT behaviour we do not wrap or do not document is #808's finding, not this
one's, and re-litigating it here would blur which pass owns which question.

Re-run first, before trusting anything below: `python3 derive_lane.py --reverify-808`. Measured on
2026-08-31: 151 lane classes, 66 `ok`, 85 `deliberate, recorded`, 0 `under`, lane re-derivation
against the pinned headers clean. If that has moved, the 66-class TEST_LANE below has moved with
it and needs re-deriving, not patching.

THE TRACE, three hops, all mechanical and all printed so a claim here is never "trust me":

  1. CLASS -> BRIDGE FUNCTION. For each of the 66 `ok` classes, parse every `Sources/OCCTBridge/
     src/*.mm` file `_is_wrapped` already named, extract each C function's body (brace-depth
     matched, comments and string literals stripped first), and keep the function if the class
     name appears in that body on a real (non-comment) line. A function is a candidate bridge
     entry point only if its name starts with `OCCT`, this bridge's own naming convention for its
     public C surface (see CLAUDE.md's Naming Conventions); a `static` helper the public API calls
     internally is deliberately invisible here, because Swift never calls it directly and tracing
     through it would need a second, unbounded hop this pass does not attempt (recorded under
     "What this pass did not do" in the README).

  2. BRIDGE FUNCTION -> SWIFT DECLARATION. For each such C function name, search every
     `Sources/OCCTSwift/*.swift` file (comments and string literals stripped) for a call to it
     (`\bname\s*\(`), then find the SMALLEST enclosing Swift `func`/computed `var`/`init`
     declaration whose brace span contains that call, by the same brace-depth technique. That is
     the Swift-level entry point a test would actually call.

  3. SWIFT DECLARATION -> TESTED?. Search every `.swift` file under the five lane test targets
     (comments and string literals stripped) for a call-shaped reference to that declaration:
     `\.name\s*\(` for a method/static factory (dot syntax covers both, since C has no overloading
     to disambiguate and this bridge's Swift wrappers are consistently called as `x.name(...)` or
     `Type.name(...)`), `\.name\b(?!\s*\()` for a computed property, or `\bTypeName\s*\(` for a
     bare `init` (the one shape dot-syntax cannot express; `TypeName` is resolved the same
     brace-depth way from the enclosing `struct`/`class`/`extension`).

WHAT THIS CANNOT SEE, stated rather than hidden, because a mechanical trace across three hops has
real holes and the census built on top of it treats every one below as "needs a human", not as a
verdict:

  - A name collision. `.close(` or `.value(` would match any method of that name on any type, not
    only the one this trace means. Every class whose only associated declarations have a
    common-word name is flagged `ambiguous-name` rather than folded into `tested`/`untested`,
    listed separately below.
  - A bridge function called through a shared internal helper rather than by name directly (the
    #811 `occtPlateApproxSurface`-shaped case). Not observed in this lane's 66 classes by
    inspection of the printed table, but not exhaustively ruled out either.
  - A test that exercises the behaviour through a DIFFERENT Swift entry point that happens to
    share the same bridge function (two Swift methods calling one C function). The trace records
    every (bridge function, swift declaration) pair it finds, so this shows up as extra rows, not
    as a false negative, but a reviewer should not read "1 declaration found" as "exactly 1 Swift
    surface exists".
  - A test that instantiates or passes through a type without exercising the SPECIFIC behaviour
    tied to a class, which is the distinction #816 draws explicitly. This trace's "tested" bit
    means "some test calls a Swift declaration whose body reaches a bridge function naming this
    class", which is a real behavioural signal for a narrow bridge function but is closer to
    "touched" than "checked" for a wide one; `refman_census.py`'s hand read of each `under` verdict
    is what closes that gap, not this script.

Run from anywhere (paths derive from this file's location, not the cwd):

    python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py
    python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py --verbose
    python3 Scripts/repro/816-refman-coverage-tests-topology/derive_lane.py --reverify-808
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
TEST_TARGETS = [
    "OCCTTopologyTests", "OCCTModelingTests", "OCCTAnalysisTests", "OCCTShapeHealingTests",
    "OCCTBRepGraphTests",
]
TESTS_DIR = os.path.join(ROOT, "Tests")

CENSUS808_PATH = os.path.join(ROOT, "Scripts", "repro", "808-refman-shape-topology",
                               "refman_census.py")


def _load_census808():
    spec = importlib.util.spec_from_file_location("census808", CENSUS808_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# -------------------------------------------------------------------------------------------
# Generic comment/string stripper, adapted from `Scripts/census-unmeasured-values.py`'s
# `strip_comments`. Works unmodified on both Objective-C++ (`//`, `/* */`, `"..."`) and Swift
# (same three shapes) source, replacing stripped spans with spaces so line/column positions do
# not move -- load-bearing here, since the brace-depth scans below report byte offsets that a
# caller turns back into line numbers against the ORIGINAL text.
# -------------------------------------------------------------------------------------------


def strip_comments(text: str) -> str:
    out, i, n = [], 0, len(text)
    while i < n:
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("".join(c if c == "\n" else " " for c in text[i:j]))
            i = j
        elif text[i] == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    j += 1
                j += 1
            j = min(j + 1, n)
            out.append(" " * (j - i))
            i = j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def _brace_span(text: str, open_pos: int) -> int:
    """Given the position of a `{`, return the position of its matching `}`."""
    depth, i, n = 0, open_pos, len(text)
    while i < n:
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n


# A C/Objective-C++ function DEFINITION: a return type, a name, a parameter list with no `;` or
# `{` inside it (ruling out a prototype or a call), then `{`. `[^;{]*?` deliberately excludes a
# `;` so a prototype (`OCCTFoo(int x);`) is not mistaken for a definition.
C_FUNC = re.compile(
    r"^(?:static\s+)?[A-Za-z_][\w:<>,\s\*&]*?\b(\w+)\s*\(([^;{]*?)\)\s*\{", re.M | re.S
)


def c_functions(stripped_text: str):
    """Yields (name, body_start, body_end) for every C function DEFINITION in `stripped_text`."""
    for m in C_FUNC.finditer(stripped_text):
        name = m.group(1)
        start = m.end() - 1
        end = _brace_span(stripped_text, start)
        yield name, start, end


# Swift declarations this trace can enclose a call in: a `func`, a computed `var` (only the ones
# with a body -- a stored property has no brace to bound), and a bare `init`.
SWIFT_VAR = re.compile(r"\bvar\s+(\w+)\s*:[^=\{]*\{")
SWIFT_TYPE = re.compile(r"\b(?:struct|class|enum|extension)\s+(\w+)[^\{]*\{")

# `func NAME` / `init` followed by a PAREN-BALANCED parameter list. The single-regex approach
# (`\([^)]*\)`) that an earlier version of this file shared with `SWIFT_VAR` breaks the moment a
# parameter or return type itself contains a `)` before the list's real close -- a tuple type
# (`triangles: [(Int32, Int32, Int32)]`) or a generic with a nested call-shaped constraint. Measured
# concretely: `Shape.fromMesh(points:triangles:)` (`Sources/OCCTSwift/Shape+Mesh.swift`) has exactly
# this shape, `[^)]*\)` closes on the TUPLE's `)` three characters early, the trailing `-> Shape? {`
# never matches, and the whole declaration goes undetected, silently turning `OCCTShapeFromMesh`'s
# very real call two lines below into a false "no Swift caller found". A manual scan that walks
# paren/bracket depth explicitly is what the fix needs, not a bigger regex.
_FUNC_OR_INIT_HEAD = re.compile(r"\bfunc\s+(\w+)|\binit[\?!]?\b")


def _skip_ws(text: str, i: int) -> int:
    n = len(text)
    while i < n and text[i] in " \t\r\n":
        i += 1
    return i


def _matching(text: str, open_pos: int, open_ch: str, close_ch: str) -> int:
    depth, i, n = 0, open_pos, len(text)
    while i < n:
        if text[i] == open_ch:
            depth += 1
        elif text[i] == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n


def _find_body_open_brace(text: str, start: int) -> int:
    """From just after a parameter list, scan forward (skipping nested (), [], <> and any `->`
    return-type clause) for the `{` that opens the body, at bracket depth 0. Returns -1 if a `;`
    (protocol/@objc stub, no body) is reached first, or if the text ends first."""
    i, n = start, len(text)
    depth = 0
    while i < n:
        c = text[i]
        if c in "([<":
            depth += 1
        elif c in ")]>":
            depth = max(0, depth - 1)
        elif depth == 0 and c == "{":
            return i
        elif depth == 0 and c == ";":
            return -1
        i += 1
    return -1


def swift_decls(stripped_text: str):
    """Yields (kind, name, start, end) for every func/var/init declaration with a brace body."""
    text = stripped_text
    for m in _FUNC_OR_INIT_HEAD.finditer(text):
        is_init = m.group(0).startswith("init")
        name = "init" if is_init else m.group(1)
        i = _skip_ws(text, m.end())
        if i < len(text) and text[i] == "<":
            i = _skip_ws(text, _matching(text, i, "<", ">") + 1)
        if i >= len(text) or text[i] != "(":
            continue  # not a call-shaped declaration (e.g. a computed-property-style `init` typo)
        params_end = _matching(text, i, "(", ")")
        brace_pos = _find_body_open_brace(text, params_end + 1)
        if brace_pos < 0:
            continue
        start = brace_pos
        yield ("init" if is_init else "func"), name, start, _brace_span(text, start)
    for m in SWIFT_VAR.finditer(text):
        start = m.end() - 1
        yield "var", m.group(1), start, _brace_span(text, start)


def swift_types(stripped_text: str):
    """Yields (name, start, end) for every struct/class/enum/extension body."""
    for m in SWIFT_TYPE.finditer(stripped_text):
        start = m.end() - 1
        yield m.group(1), start, _brace_span(stripped_text, start)


def _enclosing(spans, pos):
    """The narrowest (start, end) span containing pos, or None. `spans` is a list of tuples whose
    first two elements are (start, end) followed by arbitrary payload."""
    best = None
    for span in spans:
        start, end = span[0], span[1]
        if start <= pos <= end:
            if best is None or (end - start) < (best[1] - best[0]):
                best = span
    return best


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


# -------------------------------------------------------------------------------------------
# Hop 1: class -> bridge function.
# -------------------------------------------------------------------------------------------


def all_bridge_function_bodies():
    """(func_name, file_basename, body_text) for EVERY C function definition (public `OCCT*` entry
    point AND `static`/`inline` internal helper alike) across `Sources/OCCTBridge/src/*.mm` and
    `OCCTBridge_Internal.h` (the shared helper header those `.mm` files `#import`).

    Not filtered to `OCCT*` names, unlike an earlier version of this file: a class referenced only
    from a `static` helper's body -- `checkSubShape()` in `OCCTBridge_Healing_Fix.mm` constructing
    `BRepCheck_Edge`/`Wire`/`Shell`/`Vertex`, called from `OCCTCheckEdge`/`Wire`/`Shell`/`Vertex` --
    would otherwise vanish between hop 1 and the class it names, since the OCCT-prefixed CALLER's
    own body never mentions the class at all. `class_to_bridge_functions` below closes that with a
    reverse-call-graph walk rather than by widening the direct-mention test."""
    out = []
    files = [os.path.join(BRIDGE_SRC, fn) for fn in sorted(os.listdir(BRIDGE_SRC))
             if fn.endswith(".mm") or fn == "OCCTBridge_Internal.h"]
    for path in files:
        raw = _read(path)
        stripped = strip_comments(raw)
        for name, start, end in c_functions(stripped):
            out.append((name, os.path.basename(path), stripped[start:end]))
    return out


def class_to_bridge_functions(classes, bridge_bodies):
    """{class_name: {(occt_prefixed_func_name, file_basename), ...}}

    Two-step: (1) DIRECT mentions, any function (helper or public) whose body names the class.
    (2) REACHERS: every function that calls (transitively, through any number of other helpers) a
    function with a direct mention, found by reverse-BFS over a call graph built by scanning each
    body for `\\bknown_name\\s*\\(`. The public, OCCT-prefixed subset of (direct union reachers) is
    what is returned; a helper itself is not a Swift-callable entry point and is reported only via
    the OCCT-prefixed function(s) that reach it, per the file's own header note.
    """
    all_names = {name for name, _f, _b in bridge_bodies}
    body_of = {}
    file_of = {}
    for name, fn, body in bridge_bodies:
        body_of.setdefault(name, body)  # first definition wins; this bridge has no duplicate names
        file_of.setdefault(name, fn)

    # One token-extraction pass per body (O(F * body length)) rather than testing every known name
    # against every body (O(F^2) regex searches, minutes rather than seconds on ~4,000 functions).
    call_token = re.compile(r"\b([A-Za-z_]\w*)\s*\(")
    reverse_calls: dict[str, set[str]] = {n: set() for n in all_names}
    for caller, body in body_of.items():
        for m in call_token.finditer(body):
            callee = m.group(1)
            if callee != caller and callee in all_names:
                reverse_calls[callee].add(caller)

    pats = {c: re.compile(r"\b" + re.escape(c) + r"\b") for c in classes}
    out = {c: set() for c in classes}
    for c, pat in pats.items():
        direct = {name for name, body in body_of.items() if pat.search(body)}
        visited = set(direct)
        frontier = list(direct)
        while frontier:
            f = frontier.pop()
            for caller in reverse_calls.get(f, ()):
                if caller not in visited:
                    visited.add(caller)
                    frontier.append(caller)
        for name in visited:
            if name.startswith("OCCT"):
                out[c].add((name, file_of[name]))
    return out


# -------------------------------------------------------------------------------------------
# Hop 2: bridge function -> Swift declaration.
# -------------------------------------------------------------------------------------------


def swift_file_index():
    """Per Sources/OCCTSwift/*.swift file: (stripped_text, decl_spans, type_spans)."""
    out = {}
    for fn in sorted(os.listdir(SWIFT_DIR)):
        if not fn.endswith(".swift"):
            continue
        raw = _read(os.path.join(SWIFT_DIR, fn))
        stripped = strip_comments(raw)
        decls = list(swift_decls(stripped))
        types = list(swift_types(stripped))
        out[fn] = (stripped, decls, types)
    return out


def bridge_function_to_swift_decls(func_names, swift_index):
    """{func_name: [(swift_file, decl_kind, decl_name, owning_type_or_None), ...]}"""
    out = {f: [] for f in func_names}
    pats = {f: re.compile(r"\b" + re.escape(f) + r"\s*\(") for f in func_names}
    for fn, (stripped, decls, types) in swift_index.items():
        for f, pat in pats.items():
            for m in pat.finditer(stripped):
                pos = m.start()
                enc = _enclosing([(s, e, kind, name) for kind, name, s, e in decls], pos)
                if enc is None:
                    continue
                _s, _e, kind, name = enc
                owning = _enclosing([(s, e, tname) for tname, s, e in types], pos)
                owning_name = owning[2] if owning else None
                out[f].append((fn, kind, name, owning_name))
    return out


# -------------------------------------------------------------------------------------------
# Hop 3: Swift declaration -> tested?
# -------------------------------------------------------------------------------------------

COMMON_NAMES = {
    # Common enough across unrelated types that a bare name match is not real evidence; classes
    # resolving ONLY to one of these are reported `ambiguous-name` rather than tested/untested.
    "value", "count", "type", "shape", "shapes", "name", "id", "status", "error", "result",
    "isValid", "isEmpty", "isNull", "isDone", "description", "kind", "index", "first", "last",
}


def test_file_text():
    texts = []
    for target in TEST_TARGETS:
        d = os.path.join(TESTS_DIR, target)
        if not os.path.isdir(d):
            continue
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".swift"):
                path = os.path.join(d, fn)
                texts.append((os.path.join(target, fn), strip_comments(_read(path))))
    return texts


def is_tested(kind: str, name: str, owning_type: str | None, test_texts):
    """(tested: bool, ambiguous: bool, hit_files: [str])"""
    ambiguous = name in COMMON_NAMES
    if kind == "init":
        if not owning_type:
            return (False, True, [])
        pat = re.compile(r"\b" + re.escape(owning_type) + r"\s*\(")
    elif kind == "var":
        pat = re.compile(r"\." + re.escape(name) + r"\b(?!\s*\()")
    else:
        pat = re.compile(r"\." + re.escape(name) + r"\s*\(")
    hits = [f for f, text in test_texts if pat.search(text)]
    return (len(hits) > 0, ambiguous, hits)


# -------------------------------------------------------------------------------------------
# Assemble the full trace for one class.
# -------------------------------------------------------------------------------------------


def trace_lane(census808, verbose: bool = False):
    """Returns (test_lane_classes, per_class_trace) where per_class_trace[cls] is a list of
    dict rows, one per (bridge_function, swift_decl) pair found, each carrying tested/ambiguous.
    A class with an empty list has NO bridge function this trace could find (reported, not
    silently dropped -- see NO_BRIDGE_FUNCTION_FOUND handling in refman_census.py)."""
    bridge_files = census808._bridge_files()
    doc_files = census808._doc_files()
    gaps_text = census808._read(census808.GAPS_FILE)

    test_lane = []
    for lane, classes in census808.LANE_CLASSES.items():
        for cls in classes:
            wrapped, _wf = census808._is_wrapped(cls, bridge_files)
            documented, _df = census808._is_documented(cls, doc_files)
            verdict, _note = census808.classify(cls, wrapped, documented, gaps_text)
            if verdict == "ok":
                test_lane.append(cls)

    bodies = all_bridge_function_bodies()
    c2f = class_to_bridge_functions(test_lane, bodies)
    all_funcs = sorted({f for fs in c2f.values() for f, _file in fs})
    swift_index = swift_file_index()
    f2d = bridge_function_to_swift_decls(all_funcs, swift_index)
    test_texts = test_file_text()

    per_class = {}
    for cls in test_lane:
        rows = []
        for func_name, bridge_file in sorted(c2f[cls]):
            decls = f2d.get(func_name, [])
            if not decls:
                rows.append({
                    "bridge_function": func_name, "bridge_file": bridge_file,
                    "swift_file": None, "decl_kind": None, "decl_name": None,
                    "owning_type": None, "tested": False, "ambiguous": False,
                    "hit_files": [], "no_swift_caller": True,
                })
                continue
            for swift_file, kind, name, owning in decls:
                tested, ambiguous, hits = is_tested(kind, name, owning, test_texts)
                rows.append({
                    "bridge_function": func_name, "bridge_file": bridge_file,
                    "swift_file": swift_file, "decl_kind": kind, "decl_name": name,
                    "owning_type": owning, "tested": tested, "ambiguous": ambiguous,
                    "hit_files": hits, "no_swift_caller": False,
                })
        per_class[cls] = rows
    return test_lane, per_class


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--reverify-808", action="store_true",
                     help="re-run #808's own --reverify-lane before deriving this pass's lane")
    args = ap.parse_args()

    census808 = _load_census808()

    if args.reverify_808:
        checked, msgs = census808.reverify_lane()
        if not checked:
            print(f"#808 lane re-derivation SKIPPED: {msgs[0]}")
        elif msgs:
            print("#808 LANE DRIFT (fix upstream before trusting this pass's 66-class subset):")
            for m in msgs:
                print(f"  {m}")
            return 1
        else:
            print("#808 lane re-derivation clean: matches the pinned headers.")
        print()

    test_lane, per_class = trace_lane(census808, verbose=args.verbose)

    print(f"Test lane (classes #808 marks 'ok' -- documented AND wrapped): {len(test_lane)}")
    print()
    n_tested = n_untested = n_ambiguous = n_no_bridge_fn = n_no_swift = 0
    for cls in test_lane:
        rows = per_class[cls]
        if not rows:
            n_no_bridge_fn += 1
            verdict = "NO-BRIDGE-FUNCTION-FOUND"
        elif all(r["no_swift_caller"] for r in rows):
            n_no_swift += 1
            verdict = "NO-SWIFT-CALLER-FOUND"
        elif any(r["ambiguous"] for r in rows) and not any(
                r["tested"] and not r["ambiguous"] for r in rows):
            n_ambiguous += 1
            verdict = "AMBIGUOUS-NAME"
        elif any(r["tested"] for r in rows):
            n_tested += 1
            verdict = "tested"
        else:
            n_untested += 1
            verdict = "UNTESTED"
        n_funcs = len({r["bridge_function"] for r in rows})
        n_tested_funcs = len({r["bridge_function"] for r in rows if r["tested"]})
        print(f"  {cls:42} {verdict:26} bridge_functions={n_funcs:3} tested={n_tested_funcs:3}")
        if args.verbose:
            for r in rows:
                tag = ("no-swift-caller" if r["no_swift_caller"]
                       else ("ambiguous" if r["ambiguous"]
                             else ("tested" if r["tested"] else "untested")))
                print(f"      {r['bridge_function']:<36} {r['bridge_file']:<44} "
                      f"-> {r['swift_file']} {r['decl_kind']}.{r['decl_name']} [{tag}]"
                      + (f" via {r['hit_files']}" if r["hit_files"] else ""))

    print()
    print(f"tested={n_tested} untested={n_untested} ambiguous-name={n_ambiguous} "
          f"no-bridge-function-found={n_no_bridge_fn} no-swift-caller-found={n_no_swift} "
          f"(total {len(test_lane)})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
