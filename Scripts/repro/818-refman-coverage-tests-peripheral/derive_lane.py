#!/usr/bin/env python3
r"""#818 (Pass 5d of #807): re-derive the test-side lane for the peripheral subsystems.

Pass 5d mirrors Pass 4, which was itself split across FOUR source-side lane audits: #811
(Features), #812 (Drawing/2D-annotation), #813 (Export/interop), #814 (Mesh/presentation/misc).
This file re-derives the union of their four `LANE_CLASSES` tables directly from those four
scripts (imported, not retyped -- retyping is exactly the drift #811's own README warns about:
"things move"), then answers a DIFFERENT question than any of the four asked: not "is this OCCT
class wrapped," but "does a test in the six Pass-5d test targets
(OCCTMeshTests/OCCTDrawingTests/OCCTIntegrationTests/OCCTMiscTests/OCCTStressTests/OCCTThreadTests)
actually exercise it."

THE POPULATION is narrower than the raw union. A class the four source passes classified
`deliberate, recorded` or `under` (i.e. NOT wrapped: no bridge function touches it at all) has no
Swift-callable entry point for any test, anywhere, to exercise -- asking "is it tested" about such
a class just re-asks the source pass's own "is it wrapped" question with different words. So this
file's population is the subset of the union that is WRAPPED (a real, live bridge-token hit),
re-verified fresh against `main` today rather than trusted from the four scripts' own printed
tables, exactly as #818 asks ("re-derived/re-verified... rather than blindly trusted").

THE METHOD, four hops, each one weaker than the last, which is why every automated verdict below
is a CANDIDATE the census hand-verifies before trusting (`MANUAL_OVERRIDES` in `refman_census.py`
is the record of every case where hand-verification disagreed with the automated signal):

  1. OCCT class -> bridge FUNCTION NAMES. Bridge `.mm`/`.h` function bodies are extracted with a
     comment/string-aware brace matcher (naive brace counting is corrupted by a stray `{`/`}`
     inside a `//` comment or string literal -- measured, not assumed: an earlier, naive version
     of this matcher silently produced a different, wrong function-name set). A function's name is
     matched by `(?:OCCT|occt)[A-Za-z0-9_]*` -- both cases, because this bridge's own internal
     helpers are lowercase-prefixed (`occtImportSTLImpl`, `occtDrawingPopulate`, ...) and a class
     reached only through one of those (StlAPI_Reader's sole use is inside `occtImportSTLImpl`) is
     invisible to an OCCT-only pattern.
  2. Bridge function A calls bridge function B (by name, project-wide, since a shared `occt*`
     helper can live in a different `.mm` file, or in `OCCTBridge_Internal.h` as `inline`) -> A
     inherits B's classes too, by fixpoint. Needed for StdSelect_BRepOwner (reached through
     `OCCTSelectorCollectResults`, itself called from `OCCTSelectorPick`).
  3. Swift declaration (func/var/init) -> bridge functions it calls, again by fixpoint over
     same-file helper calls (a `public init` that calls a `private func` that makes the real
     bridge call is a common shape here: `AAG.init(shape:)` -> private `buildGraph()` ->
     `OCCTEdgeGetConvexity`, and `buildGraph()` itself is never named by any test).
  4. Test target calls that Swift declaration. `func`/`init` need a call shape
     (`\bname\s*\(`); `var` accepts a call shape OR a property-access shape (`\.name\b`). A BARE
     type reference alone never counts (the thing #818 asks not to credit: "not just instantiate a
     type that happens to touch it in passing").

A FALSE-POSITIVE GATE sits on step 4, because a generic decl name (`isDone`, `solve`, `evaluate`)
collides across unrelated types sharing one huge multi-type Swift file (`Shape+Modeling.swift`
alone declares over a dozen result/enum types beside `Shape` itself). Measured, not hypothetical:
before this gate, `Plate_Plate` (via `PlateSolver.isDone`) registered as "tested by OCCTStressTests"
because `StressBuilderLifecycleTests.swift` calls `builder.isDone` -- on a completely unrelated
`ChamferBuilder`/`FilletBuilder`, never on a `PlateSolver`. The gate requires the declaring file's
OWN type name(s) to also appear as a bare token in the same test file. It is NOT sufficient by
itself for a file that declares many types (`Shape+Modeling.swift`'s own extremely common `Shape`
token passes the gate for nearly any test file), so a second, human pass -- reading the actual call
site -- is still how `refman_census.py`'s table was finalised; the gate catches the cheap case, not
every case, and says so rather than overclaiming precision it does not have.

WHAT THIS FILE DOES NOT DO. It is not a full Swift/C++ parser: it cannot see a bridge call made
through a stored property initializer with no braces, a class-method body nested inside an
internal support class (`OCCTBRepSelectable::ComputeSelection`), or a class named only as a struct
FIELD type (`struct OCCTZLayerSettings { Graphic3d_ZLayerSettings settings; };`, never inside any
function body at all). All three shapes were found by hand during this pass (see
`refman_census.py`'s `MANUAL_OVERRIDES`) precisely because this file's automated pipeline reported
them as unreached. Re-deriving is still worth running before trusting the overrides table: it is
what tells you WHICH classes need a hand check, not a substitute for the check itself.

Run from anywhere:

    python3 Scripts/repro/818-refman-coverage-tests-peripheral/derive_lane.py
    python3 Scripts/repro/818-refman-coverage-tests-peripheral/derive_lane.py --calls
    python3 Scripts/repro/818-refman-coverage-tests-peripheral/derive_lane.py --structural
"""

from __future__ import annotations

import argparse
import collections
import importlib.util
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
BRIDGE_SRC = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
TESTS_DIR = os.path.join(ROOT, "Tests")

# The four source-side lane audits Pass 4 was split across. Imported by file path (their directory
# names start with a digit, so they cannot be dotted-imported) rather than retyped, per this file's
# own module docstring: a retyped copy is exactly the kind of number that goes stale unnoticed.
SOURCE_LANES = {
    "811": ("Scripts/repro/811-refman-coverage-features/refman_census.py", "Features"),
    "812": ("Scripts/repro/812-refman-coverage-drawing/refman_census.py", "Drawing/2D-annotation"),
    "813": ("Scripts/repro/813-refman-coverage-export-interop/refman_census.py", "Export/interop"),
    "814": (
        "Scripts/repro/814-refman-coverage-mesh-presentation-misc/refman_census.py",
        "Mesh/presentation/misc",
    ),
}

# Pass 5d's own six test targets (#818's `## Lane`).
MY_TARGETS = frozenset({
    "OCCTMeshTests", "OCCTDrawingTests", "OCCTIntegrationTests", "OCCTMiscTests",
    "OCCTStressTests", "OCCTThreadTests",
})


def _load_module(name: str, relpath: str):
    path = os.path.join(ROOT, relpath)
    spec = importlib.util.spec_from_file_location(f"_lane818_{name}", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _read(path: str) -> str:
    with open(path, errors="ignore") as fh:
        return fh.read()


def union_lane() -> tuple[dict[str, str], dict[str, set[str]]]:
    """(class -> owning source-lane id, source-lane id -> its classes)."""
    owner: dict[str, str] = {}
    per_lane: dict[str, set[str]] = {}
    for lane_id, (relpath, _label) in SOURCE_LANES.items():
        mod = _load_module(lane_id, relpath)
        classes = {c for lst in mod.LANE_CLASSES.values() for c in lst}
        per_lane[lane_id] = classes
        for c in classes:
            if c in owner and owner[c] != lane_id:
                raise SystemExit(
                    f"COLLISION: {c!r} claimed by both lane {owner[c]} and {lane_id} -- the four "
                    "source lanes are supposed to be disjoint package sets; this needs a human, "
                    "not a silent pick.")
            owner[c] = lane_id
    return owner, per_lane


# ------------------------------------------------------------------------------------------------
# Hop 0: is the class WRAPPED at all (bridge token hit)? Same method #811-#814 use for their own
# "wrapped" test: a class named on a bridge line that does not start with #include/#import/a
# comment marker. File-level, not function-level -- this is deliberately the coarse, reliable
# signal that decides the POPULATION; the finer, weaker signal below decides ATTRIBUTION within it.
# ------------------------------------------------------------------------------------------------

_TOKEN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def _bridge_files() -> list[str]:
    out = []
    for d in (BRIDGE_SRC, BRIDGE_INC):
        for fn in sorted(os.listdir(d)):
            p = os.path.join(d, fn)
            if os.path.isfile(p) and fn.endswith((".mm", ".h")):
                out.append(p)
    return out


def bridge_token_cache() -> dict[str, set[str]]:
    cache: dict[str, set[str]] = {}
    for path in _bridge_files():
        rel = os.path.relpath(path, ROOT)
        for line in _read(path).splitlines():
            stripped = line.strip()
            if stripped.startswith(("#include", "#import", "//", "*", "/*")):
                continue
            for tok in _TOKEN_RE.findall(stripped):
                cache.setdefault(tok, set()).add(rel)
    return cache


def wrapped_classes(union_classes: set[str]) -> set[str]:
    cache = bridge_token_cache()
    return {c for c in union_classes if c in cache}


# ------------------------------------------------------------------------------------------------
# Hop 1+2: bridge function bodies (comment/string-aware brace matching) and the call graph between
# them, propagated to a fixpoint so a public OCCTXxx that calls an internal occtXxx helper inherits
# every class the helper touches.
# ------------------------------------------------------------------------------------------------

_BFUNC_SIG_RE = re.compile(
    r"^\s*(?:[A-Za-z_][A-Za-z0-9_ \*<>,:&]*?)\b((?:OCCT|occt)[A-Za-z0-9_]*)\s*\([^;{}]*\)\s*\n?\s*\{",
    re.M,
)


def _find_matching_brace_cstyle(text: str, open_pos: int) -> int:
    """Comment/string-aware brace matcher for C/C++/ObjC++. `text[open_pos]` must be `{`.

    Naive `text.count('{')`-style brace counting is corrupted by a stray brace inside a `//`/`/*
    */` comment or a `"..."`/`'...'` literal; this walks the text skipping over both.
    """
    n = len(text)
    i = open_pos
    depth = 0
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j == -1 else j + 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        if c == "'":
            i += 1
            while i < n and text[i] != "'":
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n - 1


def _strip_c_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', " ", text)
    text = re.sub(r"'(?:\\.|[^'\\\n])*'", " ", text)
    return text


def bridge_function_bodies() -> dict[str, list[tuple[str, str]]]:
    """function name -> [(relative file, body text incl. braces), ...] (.mm src + inline .h)."""
    out: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
    files = [os.path.join(BRIDGE_SRC, fn) for fn in sorted(os.listdir(BRIDGE_SRC))
             if fn.endswith(".mm")]
    files += [os.path.join(BRIDGE_INC, fn) for fn in sorted(os.listdir(BRIDGE_INC))
              if fn.endswith(".h")]
    for path in files:
        text = _read(path)
        rel = os.path.relpath(path, ROOT)
        for m in _BFUNC_SIG_RE.finditer(text):
            name = m.group(1)
            open_pos = m.end() - 1
            close_pos = _find_matching_brace_cstyle(text, open_pos)
            out[name].append((rel, text[open_pos:close_pos + 1]))
    return out


def bridge_call_graph(bfb: dict[str, list]) -> dict[str, tuple[set[str], set[str]]]:
    """function name -> (classes named directly in its body, other bridge functions it calls)."""
    all_names = set(bfb)
    graph: dict[str, tuple[set[str], set[str]]] = {}
    for name, occurrences in bfb.items():
        combined = _strip_c_comments("\n".join(b for _, b in occurrences))
        toks = set(_TOKEN_RE.findall(combined))
        called = {t for t in re.findall(r"\b((?:OCCT|occt)[A-Za-z0-9_]*)\s*\(", combined)
                  if t != name}
        graph[name] = (toks, called & all_names)
    return graph


def propagate_bridge_reach(graph: dict, wrapped: set[str]) -> dict[str, set[str]]:
    """function name -> classes reachable (direct or via calling another bridge function)."""
    reach = {name: (toks & wrapped) for name, (toks, _called) in graph.items()}
    changed = True
    rounds = 0
    while changed and rounds < 8:
        changed = False
        rounds += 1
        for name, (_toks, called) in graph.items():
            before = len(reach[name])
            for callee in called:
                reach[name] |= reach.get(callee, set())
            if len(reach[name]) > before:
                changed = True
    return reach


def class_to_bridge_functions(func_reach: dict[str, set[str]]) -> dict[str, set[str]]:
    out: dict[str, set[str]] = collections.defaultdict(set)
    for name, classes in func_reach.items():
        for c in classes:
            out[c].add(name)
    return out


# ------------------------------------------------------------------------------------------------
# Hop 3: Swift declarations (func/var/init) and the same call-graph propagation, within one file
# (helpers this codebase's own convention keeps private to the file that owns them).
# ------------------------------------------------------------------------------------------------

_SWIFT_FUNC_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public\s+|private\s+|internal\s+|fileprivate\s+|static\s+|final\s+|open\s+|mutating\s+|"
    r"convenience\s+|override\s+|nonisolated\s+|class\s+)*"
    r"func\s+([A-Za-z_][A-Za-z0-9_]*)[^\{]*\{",
    re.M,
)
_SWIFT_INIT_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public\s+|private\s+|internal\s+|fileprivate\s+|convenience\s+|required\s+|override\s+|"
    r"nonisolated\s+)*"
    r"init\s*[?!]?\s*(?:<[^>]*>)?\s*\([^\{]*\)[^\{]*\{",
    re.M,
)
_SWIFT_VAR_RE = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s*)*"
    r"(?:public\s+|private\s+|internal\s+|fileprivate\s+|static\s+|final\s+|open\s+|"
    r"nonisolated\s+)*"
    r"var\s+([A-Za-z_][A-Za-z0-9_]*)\s*:[^\{=]*\{",
    re.M,
)
_SWIFT_TYPE_RE = re.compile(
    r"^\s*(?:public\s+|final\s+|open\s+)*(?:class|struct|enum|extension)\s+([A-Za-z_][A-Za-z0-9_]*)",
    re.M,
)


def _find_matching_brace_swift(text: str, open_pos: int) -> int:
    n = len(text)
    i = open_pos
    depth = 0
    while i < n:
        c = text[i]
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            j = text.find("\n", i)
            i = n if j == -1 else j + 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            j = text.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue
        if text.startswith('"""', i):
            j = text.find('"""', i + 3)
            i = n if j == -1 else j + 3
            continue
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                i += 2 if text[i] == "\\" else 1
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n - 1


def _strip_swift_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    text = re.sub(r'"""(?:.|\n)*?"""', " ", text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', " ", text)
    return text


def swift_files() -> list[str]:
    return [os.path.join(SWIFT_DIR, fn) for fn in sorted(os.listdir(SWIFT_DIR))
            if fn.endswith(".swift")]


DeclKey = tuple[str, str, str]  # (file basename, kind in {func,var,init}, name)


def swift_decl_calls() -> tuple[dict[DeclKey, tuple[set[str], set[str]]], dict[str, list[str]]]:
    """decl key -> (bridge calls, local (same-file) calls); file -> its own declared type names.

    `local calls` is deliberately over-inclusive (every `identifier(` in the body, stdlib and
    property names included): it only matters where the name ALSO happens to be another
    declaration in the same file, which is exactly the same-file-helper shape this hop exists to
    catch (`AAG.init(shape:)` calling the private `buildGraph()`).
    """
    calls: dict[DeclKey, tuple[set[str], set[str]]] = {}
    file_types: dict[str, list[str]] = {}
    for path in swift_files():
        fname = os.path.splitext(os.path.basename(path))[0]
        text = _read(path)
        types_in_file = sorted(set(_SWIFT_TYPE_RE.findall(text)))
        file_types[fname] = types_in_file
        for regex, kind in ((_SWIFT_FUNC_RE, "func"), (_SWIFT_VAR_RE, "var"),
                            (_SWIFT_INIT_RE, "init")):
            for m in regex.finditer(text):
                name = m.group(1) if kind != "init" else "init"
                open_pos = m.end() - 1
                close_pos = _find_matching_brace_swift(text, open_pos)
                raw_body = text[open_pos:close_pos + 1]
                body = _strip_swift_comments(raw_body)
                bridge_calls = set(re.findall(r"\bOCCT[A-Za-z0-9_]*", body))
                local_calls = (set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", body))
                               - bridge_calls)
                if kind == "init":
                    for t in types_in_file:
                        key: DeclKey = (fname, "init", t)
                        b, loc = calls.setdefault(key, (set(), set()))
                        calls[key] = (b | bridge_calls, loc | local_calls)
                else:
                    key = (fname, kind, name)
                    b, loc = calls.setdefault(key, (set(), set()))
                    calls[key] = (b | bridge_calls, loc | local_calls)
    return calls, file_types


def propagate_swift_calls(
    decl_calls: dict[DeclKey, tuple[set[str], set[str]]],
) -> dict[DeclKey, tuple[set[str], set[str]]]:
    by_file: dict[str, list[DeclKey]] = collections.defaultdict(list)
    for key in decl_calls:
        by_file[key[0]].append(key)

    changed = True
    rounds = 0
    while changed and rounds < 8:
        changed = False
        rounds += 1
        for fname, keys in by_file.items():
            name_to_keys: dict[str, list[DeclKey]] = collections.defaultdict(list)
            for k in keys:
                if k[1] in ("func", "var"):
                    name_to_keys[k[2]].append(k)
            for k in keys:
                bridge, local = decl_calls[k]
                for called_name in local:
                    for target_key in name_to_keys.get(called_name, []):
                        if target_key == k:
                            continue
                        t_bridge, _t_local = decl_calls[target_key]
                        new = t_bridge - bridge
                        if new:
                            bridge = bridge | new
                            changed = True
                decl_calls[k] = (bridge, local)
    return decl_calls


def class_to_swift_decls(
    c2bfn: dict[str, set[str]], decl_bridge: dict[DeclKey, set[str]]
) -> dict[str, set[DeclKey]]:
    out: dict[str, set[DeclKey]] = collections.defaultdict(set)
    for cls, bfns in c2bfn.items():
        for key, calls in decl_bridge.items():
            if calls & bfns:
                out[cls].add(key)
    return out


# ------------------------------------------------------------------------------------------------
# Hop 4: which test targets (all 18, not just Pass 5d's six) call a given declaration.
# ------------------------------------------------------------------------------------------------


def test_targets() -> list[str]:
    return sorted(d for d in os.listdir(TESTS_DIR)
                  if os.path.isdir(os.path.join(TESTS_DIR, d)) and d.startswith("OCCT"))


def test_target_ident_sets() -> dict[str, tuple[set[str], set[str], set[str]]]:
    """target -> (call-shaped idents, dot-property idents, ALL bare idents -- the co-occurrence
    gate's token set, which must be the unfiltered one: a bare type reference like `Shape.box(`
    puts `Shape` in neither the call set nor the property set, only in the full token scan)."""
    out = {}
    for target in test_targets():
        d = os.path.join(TESTS_DIR, target)
        calls: set[str] = set()
        props: set[str] = set()
        idents: set[str] = set()
        for fn in os.listdir(d):
            if not fn.endswith(".swift"):
                continue
            text = _strip_swift_comments(_read(os.path.join(d, fn)))
            calls |= set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(", text))
            props |= set(re.findall(r"\.([A-Za-z_][A-Za-z0-9_]*)\b", text))
            idents |= set(_TOKEN_RE.findall(text))
        out[target] = (calls, props, idents)
    return out


def _decl_hit(kind: str, name: str, calls: set[str], props: set[str], idents: set[str],
              file_types: dict[str, list[str]], fname: str) -> bool:
    if kind == "func":
        if name not in calls:
            return False
    elif kind == "init":
        return name in calls  # name IS the type; the call shape (TypeName(...)) is the gate
    elif kind == "var":
        if not (name in props or name in calls):
            return False
    else:
        return False
    types = file_types.get(fname, [])
    if not types:
        return True  # a free function outside any type: nothing to gate on
    return any(t in idents for t in types)


class LaneResult:
    def __init__(self):
        self.owner: dict[str, str] = {}
        self.per_lane: dict[str, set[str]] = {}
        self.wrapped: set[str] = set()
        self.c2bfn: dict[str, set[str]] = {}
        self.c2decls: dict[str, set[DeclKey]] = {}
        self.class_hits: dict[str, set[str]] = {}  # class -> test targets (all 18) that reach it


def compute() -> LaneResult:
    r = LaneResult()
    r.owner, r.per_lane = union_lane()
    r.wrapped = wrapped_classes(set(r.owner))

    bfb = bridge_function_bodies()
    graph = bridge_call_graph(bfb)
    func_reach = propagate_bridge_reach(graph, r.wrapped)
    r.c2bfn = class_to_bridge_functions(func_reach)

    decl_calls, file_types = swift_decl_calls()
    decl_calls = propagate_swift_calls(decl_calls)
    decl_bridge = {k: v[0] for k, v in decl_calls.items() if v[0]}
    r.c2decls = class_to_swift_decls(r.c2bfn, decl_bridge)

    ttc = test_target_ident_sets()
    for cls in sorted(r.wrapped):
        decls = r.c2decls.get(cls, set())
        hits: set[str] = set()
        for target in test_targets():
            calls, props, idents = ttc[target]
            for (fname, kind, name) in decls:
                if _decl_hit(kind, name, calls, props, idents, file_types, fname):
                    hits.add(target)
                    break
        r.class_hits[cls] = hits
    return r


def main() -> int:
    ap = argparse.ArgumentParser(description="#818 lane derivation, test-side")
    ap.add_argument("--calls", action="store_true", help="print full per-class evidence")
    ap.add_argument("--structural", action="store_true",
                     help="print the source-lane -> test-target structural mapping only")
    args = ap.parse_args()

    r = compute()

    print(f"union lane (four source passes): {len(r.owner)} classes")
    for lane_id, (_relpath, label) in SOURCE_LANES.items():
        print(f"  {lane_id} ({label}): {len(r.per_lane[lane_id])} classes")

    print(f"\nwrapped (the population this pass actually audits): "
          f"{len(r.wrapped)} / {len(r.owner)}")
    for lane_id in SOURCE_LANES:
        w = r.per_lane[lane_id] & r.wrapped
        print(f"  {lane_id}: {len(w)} / {len(r.per_lane[lane_id])} wrapped")

    print("\nstructural finding: which of Pass 5d's six targets each source lane's wrapped "
          "classes actually land in, vs. some OTHER existing test target entirely, vs. nowhere:")
    print(f"{'lane':<6}{'wrapped':>8}{'in-my-6':>9}{'elsewhere':>11}{'nowhere':>9}")
    totals = [0, 0, 0, 0]
    for lane_id in SOURCE_LANES:
        w = r.per_lane[lane_id] & r.wrapped
        in6 = sum(1 for c in w if r.class_hits[c] & MY_TARGETS)
        elsewhere = sum(1 for c in w if r.class_hits[c] and not (r.class_hits[c] & MY_TARGETS))
        nowhere = sum(1 for c in w if not r.class_hits[c])
        print(f"{lane_id:<6}{len(w):>8}{in6:>9}{elsewhere:>11}{nowhere:>9}")
        totals[0] += len(w)
        totals[1] += in6
        totals[2] += elsewhere
        totals[3] += nowhere
    print(f"{'TOTAL':<6}{totals[0]:>8}{totals[1]:>9}{totals[2]:>11}{totals[3]:>9}")

    if args.structural:
        print("\nper-class, which OTHER (non-Pass-5d) target(s) actually carry the coverage:")
        for cls in sorted(r.wrapped):
            hits = r.class_hits[cls]
            if hits and not (hits & MY_TARGETS):
                print(f"  {cls}: {sorted(hits)}")
        return 0

    if args.calls:
        print("\nper-class evidence (bridge functions reached, swift decls, test targets hit):")
        for cls in sorted(r.wrapped):
            print(f"  {cls}")
            print(f"      bridge fns: {sorted(r.c2bfn.get(cls, []))}")
            print(f"      swift decls: {sorted(r.c2decls.get(cls, set()))}")
            print(f"      test targets: {sorted(r.class_hits[cls])}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
