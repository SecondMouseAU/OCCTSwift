#!/usr/bin/env python3
"""#2820: a file-scope type defined in more than one `Sources/OCCTBridge/src/*.mm` must be defined
identically in all of them.

A class, struct, union or enum defined in several translation units is well formed **only** while
the definitions are token for token identical. The `.mm` splits under #396 copied every file-scope
type into every file of a domain exactly as they copied the file-static helpers
`census-dead-file-statics.py` (#1628) measures, so the bridge holds hundreds of these, and the ones
that matter most are the opaque handle structs: `OCCTSewingRef` is a typedef'd pointer in a public
header, a Swift caller gets one from a create function in one `.mm` and hands it to a release
function that may live in another. If two definitions ever diverge by a field, the two translation
units disagree about the layout across a boundary the type system cannot see, and the symptom is
memory corruption rather than a compile error.

**Nothing else in the repo can see this.** The compiler cannot: each translation unit sees exactly
one definition and is individually valid, which is what makes ODR violations of this kind silent.
`census-dead-file-statics.py` covers `static` functions and says so. `check-borrowed-handles.py`
reads the Swift side. `derive-bridge-header-split.py` reads declarations in the headers, not
definitions in the `.mm` files.

GATE, not a census, and the exception in `okf/policies/static-gates.md`'s measure-the-rate-then-gate
sequence is what allows that on the day the detector lands. That sequence exists so a required
check is not red for every PR the moment it is added; here the backlog was **already zero** when
#2820 measured it, so there is no backlog to work down, and unlike a dead file-static a divergence
IS a defect rather than a list of sites for a human to adjudicate. It therefore exits 1 on a
divergence and `gate-scripts` runs it bare.

**Duplication on its own is not a finding.** Two identical definitions in two translation units are
legal C++, and the bridge has 605 of them today. The gate fires only on disagreement, which is why
hoisting a type into `OCCTBridge_Internal.h` (#2820's option 2, and what
`okf/policies/helper-placement-by-reach.md` says for a helper reached by more than one file, applied
to a type) makes the gate quieter rather than louder. The duplication census is printed beside the
verdict so the number that motivated #2820 stays derivable.

    python3 Scripts/check-bridge-type-odr.py              # the verdict, plus the duplication census
    python3 Scripts/check-bridge-type-odr.py --list       # every duplicated type, with its files
    python3 Scripts/check-bridge-type-odr.py --json       # machine-readable
    python3 Scripts/check-bridge-type-odr.py --self-test  # prove each failure mode is caught

## How two definitions are compared, and why not textually

ODR is a property of **tokens**, and clang-format aligns consecutive declarations per file, so two
byte-different definitions are routinely the same type. The comparison therefore:

- **strips comments, keeping string and character literals**, in one leftmost-match-wins
  alternation borrowed from `census-dead-file-statics.py` for the reason
  `derive-bridge-header-split.py` records under #2080: a `/*` inside a `//` comment opens a block
  that runs to the next real `*/` and swallows real code. Literals are kept because a literal IS a
  token, so two definitions differing only in one are genuinely different. That is the one place
  this script cannot reuse the census's `prepare()`, which empties literals on purpose.
- **tokenises and rejoins with single spaces**, so whitespace and line breaks do not count.

What that leaves uncovered, stated rather than assumed: two adjacent punctuation characters are
tokenised one character at a time, so `a<<b` and `a< <b` compare equal. Both are unreachable in a
type definition's body and the direction of the error is a missed divergence, not a false one.

## Validating the view, not just the verdict

`okf/policies/static-gates.md` records three gates that were confidently wrong while reporting all
clear, so this one sizes its own population two ways and refuses to report when they disagree: the
parser's definition count is compared against a deliberately dumber line scan (a
`struct`/`class`/`union`/`enum` at column 0 whose line does not end in `;`), and any line the dumb
scan claims and the parser does not is named. That check is what would catch a regex that stopped
matching, rather than a fixture nobody thought to write.
"""
from __future__ import annotations

import argparse
import collections
import glob
import hashlib
import importlib.util
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ROOT)
SRC_DIR = "Sources/OCCTBridge/src"


def _load_dead_file_statics():
    """The #1628 census, for its comment/literal alternation and line arithmetic.

    #2820 asked whether this check belongs in that census as a mode. It does not: that script is a
    census whose bare run always exits 0 and whose subject is `static` functions, and this one is a
    gate whose bare run exits 1 over types. What is worth sharing is the parsing, so the parsing is
    imported rather than rewritten. `importlib` because the filename has hyphens, the same route
    `census-comment-staleness.py` and `census-doc-occt-attribution.py` already take.
    """
    path = os.path.join(ROOT, "census-dead-file-statics.py")
    spec = importlib.util.spec_from_file_location("census_dead_file_statics", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


DEAD_STATICS = _load_dead_file_statics()

# A file-scope class/struct/union/enum DEFINITION. `^` anchors it at column 0, which is where the
# bridge puts every one of them; a type declared inside a function body or inside another class is
# not an inter-translation-unit ODR question and is deliberately out of scope.
#
# `[^;{=]*` is what separates a definition from a forward declaration and from a variable: it can
# span lines, because OCCT's style puts the opening brace on its own line and a base-clause between
# (`class OCCTBoolTimeoutBreaker : public Message_ProgressIndicator\n{`), but it cannot cross the
# `;` of a `struct Foo;` or the `=` of a `struct Foo bar = {...};`. That is the lesson
# `census-dead-file-statics.py` records for `STATIC_DECL`: a character class matching newlines will
# pair one declaration's head with the next construct's brace unless the terminators are excluded.
TYPE_DEF = re.compile(
    r"^(?P<keyword>struct|class|union|enum)"
    r"(?:\s+(?:class|struct))?"  # `enum class`, `enum struct`
    r"\s+(?P<name>[A-Za-z_]\w*)"
    r"(?P<tail>[^;{=]*)"
    r"\{",
    re.M,
)

# The independent sizing of the same population, deliberately dumber than the parser above: a
# keyword at column 0 on a line that is not a forward declaration. Anything this claims and
# TYPE_DEF does not is reported as a blind spot rather than skipped.
LOOSE_HEAD = re.compile(r"^(?:typedef\s+)?(?:struct|class|union|enum)\b[^\n]*$", re.M)

# One C++ token: identifier/keyword, number, string or character literal, or a single punctuator.
TOKEN = re.compile(
    r'[A-Za-z_]\w*'
    r"|\d[\w.]*"
    r'|"(?:\\.|[^"\\\n])*"'
    r"|'(?:\\.|[^'\\\n])*'"
    r"|\S"
)


def strip_comments_keep_literals(text: str) -> str:
    """Blank comments, leave literals untouched, preserve every offset and line number.

    The alternation is the census's, so the #2080 shape (a `/*` inside a `//` comment) is handled
    once rather than twice. The replacement is not the census's: a string literal is a token, so
    two definitions that differ only in one differ, and emptying literals would hide that.
    """

    def keep_or_drop(match: re.Match) -> str:
        token = match.group(0)
        if token.startswith("//"):
            return " " * len(token)
        if token.startswith("/*"):
            return re.sub(r"[^\n]", " ", token)  # keep newlines, so line numbers survive
        return token  # a literal: a token, kept verbatim

    return DEAD_STATICS.COMMENT_OR_LITERAL.sub(keep_or_drop, text)


def blank_literals(text: str) -> str:
    """Same length, literals emptied. Used only for brace matching, where a `{` in a literal lies."""

    def empty(match: re.Match) -> str:
        token = match.group(0)
        if token.startswith('"') or token.startswith("'"):
            return token[0] + token[-1] + " " * (len(token) - 2)
        return token

    return DEAD_STATICS.COMMENT_OR_LITERAL.sub(empty, text)


def normalise_tokens(source: str) -> str:
    """The ODR comparison key: tokens, single-spaced. Whitespace and comments are not tokens."""
    return " ".join(TOKEN.findall(source))


def body_end(structural: str, open_brace: int) -> int | None:
    """Offset just past the matching `}` of the `{` at `open_brace`, or None if unbalanced."""
    depth = 0
    i = open_brace
    while i < len(structural):
        if structural[i] == "{":
            depth += 1
        elif structural[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


def definitions_in(structural: str) -> list[dict]:
    """Every file-scope type definition, with its name, keyword, line and [start, end) extent."""
    out = []
    for match in TYPE_DEF.finditer(structural):
        end = body_end(structural, match.end() - 1)
        if end is None:
            continue
        out.append(
            {
                "name": match.group("name"),
                "keyword": match.group("keyword"),
                "line": DEAD_STATICS.line_of(structural, match.start()),
                "end_line": DEAD_STATICS.line_of(structural, end),
                "start": match.start(),
                "end": end,
            }
        )
    return out


def loose_heads(structural: str) -> list[tuple[int, str]]:
    """(line, text) for every column-0 type keyword line that is not a forward declaration.

    The independent sizing. A line ending in `;` is `struct Foo;`, which declares and defines
    nothing; everything else at column 0 starting with one of these keywords is a definition in
    this tree, so the parser owing one match per line is a checkable claim.
    """
    out = []
    for match in LOOSE_HEAD.finditer(structural):
        line = match.group(0).strip()
        if line.endswith(";"):
            continue
        out.append((DEAD_STATICS.line_of(structural, match.start()), line))
    return out


def mm_files() -> list[str]:
    return sorted(glob.glob(os.path.join(SRC_DIR, "*.mm")))


def scan_file(path: str, raw: str) -> dict:
    """One file's type definitions, each with the digest of its normalised token stream."""
    commentless = strip_comments_keep_literals(raw)
    structural = blank_literals(commentless)
    if raw.strip() and not structural.strip():
        return {"error": "stripping emptied the file"}
    defs = definitions_in(structural)
    for d in defs:
        tokens = normalise_tokens(commentless[d["start"] : d["end"]])
        d["digest"] = hashlib.sha256(tokens.encode()).hexdigest()[:12]
        d["tokens"] = len(tokens.split())
        d["file"] = path
    claimed = loose_heads(structural)
    parsed_lines = {d["line"] for d in defs}
    return {
        "definitions": defs,
        "unparsed": [(line, text) for line, text in claimed if line not in parsed_lines],
        "loose": len(claimed),
    }


def run_scan() -> dict:
    files = mm_files()
    if not files:
        print(f"ABORT: no .mm files under {SRC_DIR}", file=sys.stderr)
        sys.exit(2)
    report: dict = {
        "files": len(files),
        "definitions": 0,
        "loose_heads": 0,
        "by_name": collections.defaultdict(list),
        "unparsed": [],
    }
    for path in files:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
        result = scan_file(path, raw)
        if "error" in result:
            print(f"ABORT: {result['error']}: {path}", file=sys.stderr)
            sys.exit(2)
        report["definitions"] += len(result["definitions"])
        report["loose_heads"] += result["loose"]
        for line, text in result["unparsed"]:
            report["unparsed"].append({"file": path, "line": line, "text": text})
        for d in result["definitions"]:
            report["by_name"][d["name"]].append(d)
    report["by_name"] = dict(report["by_name"])

    # Validate the view, not only the verdict (static-gates.md). A line the dumb scan claims and
    # the parser missed is a definition this gate never compared, and "no divergence" from a parser
    # that read nothing looks exactly like a clean tree.
    if report["unparsed"]:
        print(
            f"ABORT: {len(report['unparsed'])} column-0 type definition line(s) the parser did not "
            f"match, so they were never compared:",
            file=sys.stderr,
        )
        for row in report["unparsed"][:20]:
            print(f"  {row['file']}:{row['line']}  {row['text'][:100]}", file=sys.stderr)
        sys.exit(2)
    if report["definitions"] < 100:
        print(
            f"ABORT: only {report['definitions']} file-scope type definitions across "
            f"{len(files)} files; the definition scan is not seeing the tree",
            file=sys.stderr,
        )
        sys.exit(2)
    return report


def divergent(report: dict) -> dict:
    """Names defined in more than one file whose definitions do not all agree token for token."""
    out = {}
    for name, defs in report["by_name"].items():
        if len({d["file"] for d in defs}) < 2:
            continue
        if len({d["digest"] for d in defs}) > 1:
            out[name] = defs
    return out


def duplicated(report: dict) -> dict:
    """Names defined at file scope in more than one `.mm`, agreeing or not. #2820's census."""
    return {
        name: defs
        for name, defs in report["by_name"].items()
        if len({d["file"] for d in defs}) > 1
    }


def print_report(report: dict, args) -> int:
    dups = duplicated(report)
    bad = divergent(report)
    dup_definitions = sum(len(defs) for defs in dups.values())

    if args.json:
        print(
            json.dumps(
                {
                    "files": report["files"],
                    "definitions": report["definitions"],
                    "duplicated_names": sorted(dups),
                    "duplicated_definitions": dup_definitions,
                    "divergent": {
                        name: [
                            {k: d[k] for k in ("file", "line", "end_line", "digest", "tokens")}
                            for d in sorted(defs, key=lambda x: x["file"])
                        ]
                        for name, defs in sorted(bad.items())
                    },
                },
                indent=2,
            )
        )
        return 1 if bad else 0

    if args.list:
        for name, defs in sorted(dups.items(), key=lambda kv: (-len(kv[1]), kv[0])):
            print(f"{len(defs):3d}  {defs[0]['keyword']} {name}")
            for d in sorted(defs, key=lambda x: x["file"]):
                print(f"       {d['digest']}  {d['file']}:{d['line']}-{d['end_line']}")
        print()

    print(f"Bridge .mm files scanned:              {report['files']}")
    print(f"File-scope type definitions:           {report['definitions']}")
    print(f"  distinct type names:                 {len(report['by_name'])}")
    print(f"  names defined in more than one file: {len(dups)}  across {dup_definitions} definitions")
    print()

    if not bad:
        print(
            "OK: every type defined in more than one translation unit is defined identically in "
            "all of them.\nDuplication on its own is legal and is not a finding; see "
            "okf/policies/helper-placement-by-reach.md\nfor why hoisting one into "
            "OCCTBridge_Internal.h is still the better shape."
        )
        return 0

    print(
        f"ODR VIOLATION: {len(bad)} type(s) defined in more than one translation unit with "
        f"definitions that\ndisagree. Each translation unit is individually valid, so the compiler "
        f"cannot diagnose this and\nthe symptom is memory corruption across a handle boundary, not "
        f"a build failure. Reconcile the\ndefinitions, or hoist the type into "
        f"OCCTBridge_Internal.h where exactly one can exist.\n"
    )
    for name, defs in sorted(bad.items()):
        digests = collections.Counter(d["digest"] for d in defs)
        print(f"  {defs[0]['keyword']} {name}: {len(defs)} definitions, {len(digests)} distinct")
        for d in sorted(defs, key=lambda x: (x["digest"], x["file"])):
            print(f"    {d['digest']}  {d['tokens']:4d} tokens  {d['file']}:{d['line']}-{d['end_line']}")
    return 1


# ---------------------------------------------------------------------------
# Self-test


def self_test() -> bool:
    failures: list[str] = []

    def collect(files: dict[str, str]) -> dict:
        report = {"files": len(files), "definitions": 0, "loose_heads": 0,
                  "by_name": collections.defaultdict(list), "unparsed": [], "defs": []}
        for path, raw in files.items():
            result = scan_file(path, raw)
            if "error" in result:
                failures.append(f"scan_file() errored on {path}: {result['error']}")
                continue
            report["definitions"] += len(result["definitions"])
            report["loose_heads"] += result["loose"]
            for line, text in result["unparsed"]:
                report["unparsed"].append({"file": path, "line": line, "text": text})
            for d in result["definitions"]:
                report["by_name"][d["name"]].append(d)
                report["defs"].append(d)
        report["by_name"] = dict(report["by_name"])
        return report

    def expect(label: str, files: dict[str, str], bad_names: set[str], dup_names: set[str]) -> None:
        report = collect(files)
        got_bad = set(divergent(report))
        got_dup = set(duplicated(report))
        if got_bad != bad_names:
            failures.append(f"{label}: divergent={sorted(got_bad)}, expected {sorted(bad_names)}")
        if got_dup != dup_names:
            failures.append(f"{label}: duplicated={sorted(got_dup)}, expected {sorted(dup_names)}")

    # 1. The base case: the same struct twice, identically. Legal, and NOT a finding.
    same = "struct OCCTThing\n{\n  int a;\n};\n"
    expect("identical copies are not a finding", {"a.mm": same, "b.mm": same}, set(), {"OCCTThing"})

    # 2. The defect this gate exists for: one copy gains a field. Silent in every compiler.
    expect(
        "an added field is a divergence",
        {"a.mm": same, "b.mm": "struct OCCTThing\n{\n  int a;\n  int b;\n};\n"},
        {"OCCTThing"}, {"OCCTThing"},
    )

    # 3. A reordered field: same size, same members, different layout. Still a divergence.
    expect(
        "reordered members are a divergence",
        {"a.mm": "struct T\n{\n  int a;\n  double b;\n};\n",
         "b.mm": "struct T\n{\n  double b;\n  int a;\n};\n"},
        {"T"}, {"T"},
    )

    # 4. WHITESPACE and clang-format alignment are not tokens. This is why the comparison is not
    #    textual: OCCT's style aligns consecutive declarations per file, so two files formatted
    #    independently produce byte-different, token-identical definitions.
    expect(
        "clang-format alignment is not a divergence",
        {"a.mm": "struct T\n{\n  int          a;\n  Handle(Foo)  b;\n};\n",
         "b.mm": "struct T\n{\n  int a;\n  Handle(Foo) b;\n};\n"},
        set(), {"T"},
    )

    # 5. A COMMENT is not a token either.
    expect(
        "a comment is not a divergence",
        {"a.mm": "struct T\n{\n  int a;  // the handle\n};\n",
         "b.mm": "struct T\n{\n  int a;\n};\n"},
        set(), {"T"},
    )

    # 6. A STRING LITERAL is a token, so a difference in one is a real difference. This is the case
    #    `census-dead-file-statics.py`'s `prepare()` cannot see, because it empties literals on
    #    purpose, and it is why this script carries its own stripper rather than calling that one.
    expect(
        "a differing string literal is a divergence",
        {"a.mm": 'struct T\n{\n  const char* k = "alpha";\n};\n',
         "b.mm": 'struct T\n{\n  const char* k = "beta";\n};\n'},
        {"T"}, {"T"},
    )
    #    And the same stripper must still blank a comment that CONTAINS a literal, or the two rules
    #    fight: leftmost-match-wins means the comment opens first and swallows the quote.
    expect(
        'a literal inside a comment is still a comment',
        {"a.mm": 'struct T\n{\n  int a;  // was "alpha"\n};\n',
         "b.mm": 'struct T\n{\n  int a;  // was "beta"\n};\n'},
        set(), {"T"},
    )

    # 7. #2080's shape: a `/*` inside a `//` comment must not swallow the rest of the file. Without
    #    the leftmost-match-wins alternation, `b.mm`'s second definition disappears and the pair
    #    reads as clean.
    expect(
        "a /* inside a // comment does not swallow the next definition",
        {"a.mm": "struct T\n{\n  int a;\n};\n",
         "b.mm": "// see Sources/OCCTBridge/src/*.mm\nstruct T\n{\n  int b;\n};\n"},
        {"T"}, {"T"},
    )

    # 8. A type defined in only ONE file cannot have an ODR problem and is not duplication either.
    expect(
        "a single definition is neither",
        {"a.mm": "struct Only\n{\n  int a;\n};\n"},
        set(), set(),
    )

    #    And the reverse guard: two definitions of one name in ONE file are a redefinition the
    #    compiler rejects outright, so they are not this gate's finding and must not be reported as
    #    one. Without the file-count guard in `divergent()` this reads as an ODR violation, and the
    #    removal matrix showed nothing else exercised that branch.
    expect(
        "two definitions in one file are the compiler's problem, not this gate's",
        {"a.mm": "struct T\n{\n  int a;\n};\nstruct T\n{\n  int b;\n};\n"},
        set(), set(),
    )

    # 9. A FORWARD DECLARATION is not a definition, and must not pair its own head with the next
    #    construct's brace. `[^;{=]*` is the only thing stopping that, and the character class
    #    matches newlines because it has to (OCCT puts the brace on its own line).
    fwd = collect({"a.mm": "struct Later;\n\nint f(void)\n{\n  return 0;\n}\n"})
    if fwd["defs"]:
        failures.append(
            f"a forward declaration read as a definition: "
            f"{[(d['name'], d['line']) for d in fwd['by_name'].get('Later', [])]}"
        )
    #    ...and the real definition further down is still found, exactly once.
    pair = collect({"a.mm": "struct Later;\n\nstruct Later\n{\n  int a;\n};\n"})
    if len(pair["by_name"].get("Later", [])) != 1:
        failures.append(
            f"forward declaration plus definition: {len(pair['by_name'].get('Later', []))} "
            f"definitions of Later, expected 1"
        )

    # 10. A VARIABLE with a brace initialiser at column 0 is not a type definition. `=` is excluded
    #     for the same reason `;` is.
    var = collect({"a.mm": "struct Thing gDefault = {1, 2};\n"})
    if var["defs"]:
        failures.append(
            f"a brace-initialised variable read as a type definition: "
            f"{[d['name'] for d in var['defs']]}"
        )

    # 11. Shapes the bridge actually uses: `enum class` with a base, and a class with a base clause
    #     whose brace is on the next line.
    shapes = collect(
        {"a.mm": "enum class OSDPathComponent : int\n{\n  Trek = 0\n};\n"
                 "class BridgeProgressIndicator : public Message_ProgressIndicator\n{\n"
                 "public:\n  void Show(void) {}\n};\n"}
    )
    if {d["name"] for d in shapes["defs"]} != {"OSDPathComponent", "BridgeProgressIndicator"}:
        failures.append(
            f"real bridge shapes not parsed: {sorted(d['name'] for d in shapes['defs'])}"
        )

    # 12. A NESTED type is inside its parent's extent and is not a separate file-scope definition.
    nested = collect({"a.mm": "struct Outer\n{\n  struct Inner\n  {\n    int a;\n  };\n  int b;\n};\n"})
    if {d["name"] for d in nested["defs"]} != {"Outer"}:
        failures.append(
            f"nested type read as file-scope: {sorted(d['name'] for d in nested['defs'])}"
        )

    # 13. A `{` inside a STRING LITERAL must not be counted by the brace matcher, or the extent runs
    #     past the type and swallows whatever follows. This is what `blank_literals()` is for, and
    #     the assertion is the extent rather than the name, since the name survives either way.
    braced = collect({"a.mm": 'struct T\n{\n  const char* k = "{";\n};\n'
                              'struct U\n{\n  int a;\n};\n'})
    if {d["name"] for d in braced["defs"]} != {"T", "U"}:
        failures.append(
            f"a brace inside a literal broke the extent: "
            f"{sorted(d['name'] for d in braced['defs'])}"
        )

    # 14. The view check is not decorative. Two shapes it must tell apart, and then the branch
    #     itself.
    #     A `template` head is out of scope in both scans, so it is silently not compared rather
    #     than reported. That is a stated limitation, not a blind spot the gate can find, and the
    #     assertion here is what keeps it stated: if the loose scan ever starts claiming one, this
    #     case fails and the limitation has to be revisited.
    blind = scan_file("a.mm", "template <typename T> struct Wrapped\n{\n  T v;\n};\n")
    if blind["unparsed"]:
        failures.append(
            "a `template` head at column 0 is now claimed by the loose scan, so it counts as a "
            "definition this gate never compared; TYPE_DEF has to learn it or the loose scan has "
            "to keep excluding it"
        )
    seen_blind = scan_file("a.mm", "class Odd final\n{\n  int a;\n};\n"
                                   "struct Fine\n{\n  int b;\n};\n")
    if len(seen_blind["definitions"]) != 2 or seen_blind["unparsed"]:
        failures.append(
            f"a `final` specifier broke the parser: {len(seen_blind['definitions'])} definitions, "
            f"unparsed={seen_blind['unparsed']}"
        )
    #     The branch itself, driven by a head the loose scan claims and TYPE_DEF cannot match: a
    #     keyword with no name at all (an anonymous file-scope type). The bridge has none, and if
    #     one ever appears this gate must say so rather than pass over it.
    anon = scan_file("a.mm", "struct\n{\n  int a;\n} gAnon;\n")
    if not anon["unparsed"]:
        failures.append(
            "an anonymous column-0 type was neither parsed nor reported as unparsed, so the view "
            "check cannot fire"
        )

    # 15. Guard sanity: the shared stripper and the token normaliser each do what the rules above
    #     assume, proved directly rather than only through a fixture's verdict.
    if normalise_tokens("int   a ;") != normalise_tokens("int a;"):
        failures.append("normalise_tokens() treats whitespace as significant")
    if normalise_tokens('"a"') == normalise_tokens('"b"'):
        failures.append("normalise_tokens() collapses differing string literals")
    if strip_comments_keep_literals('x = "kept"; // dropped') .strip() != 'x = "kept";':
        failures.append("strip_comments_keep_literals() did not keep a literal or drop a comment")
    if len(blank_literals('x = "abc";')) != len('x = "abc";'):
        failures.append("blank_literals() changed the text length, so extents would shift")

    # 16. The real tree, which is what #2820's number is about and what no fixture can stand in for.
    real = run_scan()
    if len(duplicated(real)) < 1:
        failures.append("the real tree reports no duplicated type at all; the scan is blind")
    if "OCCTSewing" not in real["by_name"]:
        failures.append("OCCTSewing, the most copied type in the bridge, was not found at all")

    if failures:
        for line in failures:
            print(f"SELF-TEST FAILURE: {line}")
        return False
    print(
        "SELF-TEST: OK (21 cases: identical copies, added field, reordered members, "
        "clang-format alignment, comment, string literal x2, #2080 comment shape, single "
        "definition, one file twice, forward declaration x2, brace-initialised variable, real "
        "bridge shapes, nested type, brace in a literal, view check x3, normaliser sanity x4, "
        "real tree)"
    )
    return True


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--list", action="store_true", help="every duplicated type, with its files")
    ap.add_argument("--json", action="store_true", help="machine-readable")
    ap.add_argument("--self-test", action="store_true", help="prove each failure mode is caught")
    args = ap.parse_args()

    if args.self_test:
        return 0 if self_test() else 1
    return print_report(run_scan(), args)


if __name__ == "__main__":
    os.chdir(REPO_ROOT)
    sys.exit(main())
