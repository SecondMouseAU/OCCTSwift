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
clear, so this one refuses to report unless two independent statements hold.

**1. The two scans agree, line for line.** The parser (`TYPE_DEF`) is checked against a deliberately
dumber line scan (`LOOSE_HEAD`: a `struct`/`class`/`union`/`enum` at column 0 whose line does not end
in `;`) in both directions: every line the dumb scan claims must carry exactly one parsed definition,
and every parsed definition must sit on a line the dumb scan claimed. All 623 column-0 type lines in
the bridge today are the same OCCT shape, keyword and name with the brace on the next line, so the
two totals are equal and the equality is exact rather than approximate. The two reconciliations that
would break it are a definition written entirely on one line and two definitions sharing a line;
neither exists, clang-format does not produce either, and both are named by file and line rather than
folded into a number.

**2. A canary is found.** `canary()` runs the whole comparison over two fixed strings that differ by
one field, on every bare invocation, and the run aborts if the parser does not find both definitions
or `divergent()` does not report the disagreement. That is the `static-gates.md` canary rule with its
sign flipped: a compiler canary must fail, and a parser canary must match.

**What this replaced, because the shape is worth naming.** Until #2833 the second statement was
`if definitions < 100: abort`, an absolute floor on the population. That floor aborts precisely when
the refactor this script's own output recommends succeeds: hoisting a duplicated type into
`OCCTBridge_Internal.h` is what `okf/policies/helper-placement-by-reach.md` asks for, and what the OK
message below tells the reader to do, and each hoist removes file-scope definitions from the `.mm`
files. A gate that fails on the legitimate direction of travel gets deleted rather than understood.
An agreement floor has no such direction: hoisting drops both counts together, and the fully hoisted
end state is nothing to compare rather than a blind scan, which the report says in those words.
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
#
# Anything BEFORE the keyword is out of scope for this regex and for `LOOSE_HEAD` both, so such a
# definition is silently not compared rather than reported: `template <...> struct Foo`,
# `[[nodiscard]] struct Foo`, `alignas(16) struct Foo`. Measured across the 74 bridge `.mm` files and
# the 16 headers on 2026-09-29: **zero** `[[...]]` attributes and **zero** `alignas` anywhere, and 33
# column-0 `template` heads of which every one introduces a function rather than a type. So the
# population this cannot see is empty, which is why the answer is a self-test case pinning the
# limitation (case 14) rather than a wider regex: widening it would add a branch no input exercises,
# and the self-test fails the day the loose scan starts claiming one of these shapes.
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
    claimed_lines = {line for line, _ in claimed}
    per_line = collections.Counter(d["line"] for d in defs)
    return {
        "definitions": defs,
        # The dumb scan claimed a line the parser did not match: a definition never compared.
        "unparsed": [(line, text) for line, text in claimed if line not in per_line],
        # The reverse direction. The parser matched a line the dumb scan never claimed, or matched
        # one line twice, so the two views no longer size the same population.
        "unclaimed": [(d["line"], d["keyword"] + " " + d["name"])
                      for d in defs if d["line"] not in claimed_lines],
        "crowded": [(line, count) for line, count in sorted(per_line.items()) if count > 1],
        "loose": len(claimed),
    }


CANARY_NAME = "OCCTOdrCanaryType"
CANARY_FILES = {
    "canary-a.mm": "struct %s\n{\n  int a;\n};\n" % CANARY_NAME,
    "canary-b.mm": "struct %s\n{\n  int a;\n  int b;\n};\n" % CANARY_NAME,
}


def canary() -> list[str]:
    """Run the whole comparison over fixed text that MUST report one divergence. Problems, or [].

    `static-gates.md`'s canary rule, with its sign flipped. A detector that shells out to a compiler
    carries an input the compiler cannot miss and aborts when it comes back clean; a detector that
    parses carries an input its parser cannot miss and aborts when the parser comes back empty. This
    is the statement the old `definitions < 100` floor was reaching for, made about text this script
    owns rather than about the size of the tree, so no refactor of the bridge can move it: hoisting
    every duplicated type into `OCCTBridge_Internal.h` leaves the canary exactly as it is.

    It covers more than `TYPE_DEF`. A `body_end()` that stopped matching braces, a digest that
    collapsed, or a `divergent()` whose file-count guard swallowed everything would each report the
    real tree as clean and are each caught here.
    """
    problems: list[str] = []
    by_name: dict[str, list[dict]] = collections.defaultdict(list)
    for path, raw in CANARY_FILES.items():
        result = scan_file(path, raw)
        if "error" in result:
            problems.append(f"canary {path}: scan errored: {result['error']}")
            continue
        names = [d["name"] for d in result["definitions"]]
        if names != [CANARY_NAME]:
            problems.append(
                f"canary {path}: the parser found {names or 'nothing'}, expected "
                f"[{CANARY_NAME!r}]"
            )
        if result["unparsed"] or result["unclaimed"] or result["crowded"]:
            problems.append(
                f"canary {path}: the two scans disagree on fixed text "
                f"(unparsed={result['unparsed']}, unclaimed={result['unclaimed']}, "
                f"crowded={result['crowded']})"
            )
        for d in result["definitions"]:
            by_name[d["name"]].append(d)
    fixture = {"by_name": dict(by_name)}
    if set(duplicated(fixture)) != {CANARY_NAME}:
        problems.append(
            f"canary: duplicated()={sorted(duplicated(fixture))}, expected [{CANARY_NAME!r}]"
        )
    if set(divergent(fixture)) != {CANARY_NAME}:
        problems.append(
            f"canary: divergent()={sorted(divergent(fixture))}, expected [{CANARY_NAME!r}]; two "
            f"definitions differing by a field were not reported, so a real divergence would not be "
            f"either"
        )
    return problems


def view_problems(report: dict) -> list[str]:
    """Why this run's view of the tree is not plausible, or [] when the two scans agree.

    Validate the view, not only the verdict (`static-gates.md`). Both directions, because each
    catches something the other cannot: a line the dumb scan claims and the parser missed is a
    definition this gate never compared, and a definition the dumb scan never claimed means the two
    are no longer sizing the same population, which is what makes their agreement evidence.
    """
    problems: list[str] = []
    if report["unparsed"]:
        rows = "\n".join(
            f"  {row['file']}:{row['line']}  {row['text'][:100]}" for row in report["unparsed"][:20]
        )
        problems.append(
            f"{len(report['unparsed'])} column-0 type definition line(s) the parser did not match, "
            f"so they were never compared:\n{rows}"
        )
    if report["unclaimed"]:
        rows = "\n".join(
            f"  {row['file']}:{row['line']}  {row['text'][:100]}" for row in report["unclaimed"][:20]
        )
        problems.append(
            f"{len(report['unclaimed'])} parsed definition(s) on a line the loose scan never "
            f"claimed, so the two scans no longer size the same population. Every one of the "
            f"bridge's column-0 type lines is keyword-and-name with the brace on the next line; a "
            f"definition written entirely on one line is the shape that reaches here, and the loose "
            f"scan has to learn it:\n{rows}"
        )
    if report["crowded"]:
        rows = "\n".join(f"  {row['file']}:{row['line']}  {row['count']} definitions"
                         for row in report["crowded"][:20])
        problems.append(
            f"{len(report['crowded'])} line(s) carrying more than one parsed definition, which the "
            f"loose scan counts once:\n{rows}"
        )
    if not problems and report["definitions"] != report["loose_heads"]:
        problems.append(
            f"the two scans reconcile line for line yet their totals differ "
            f"({report['definitions']} parsed, {report['loose_heads']} claimed); the arithmetic "
            f"above is wrong"
        )
    return problems


def run_scan() -> dict:
    files = mm_files()
    if not files:
        print(f"ABORT: no .mm files under {SRC_DIR}", file=sys.stderr)
        sys.exit(2)
    problems = canary()
    if problems:
        print("ABORT: the parser canary did not come back:", file=sys.stderr)
        for line in problems:
            print(f"  {line}", file=sys.stderr)
        sys.exit(2)
    report: dict = {
        "files": len(files),
        "definitions": 0,
        "loose_heads": 0,
        "by_name": collections.defaultdict(list),
        "unparsed": [],
        "unclaimed": [],
        "crowded": [],
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
        for line, text in result["unclaimed"]:
            report["unclaimed"].append({"file": path, "line": line, "text": text})
        for line, count in result["crowded"]:
            report["crowded"].append({"file": path, "line": line, "count": count})
        for d in result["definitions"]:
            report["by_name"][d["name"]].append(d)
    report["by_name"] = dict(report["by_name"])

    problems = view_problems(report)
    if problems:
        print("ABORT: the two scans disagree about what is in the tree, so no verdict is "
              "reported:", file=sys.stderr)
        for line in problems:
            print(line, file=sys.stderr)
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
                    "loose_heads": report["loose_heads"],
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
    print(f"File-scope type definitions:           {report['definitions']}"
          f"  (loose scan agrees: {report['loose_heads']})")
    print(f"  distinct type names:                 {len(report['by_name'])}")
    print(f"  names defined in more than one file: {len(dups)}  across {dup_definitions} definitions")
    print()

    if not report["definitions"]:
        # The fully hoisted end state, and not a blind scan: the canary proves the parser still
        # matches a definition, and the loose scan claims nothing either. A `.mm` file with no
        # file-scope type cannot disagree with another about one.
        print(
            "OK: no bridge .mm file defines a type at file scope any more, so there is nothing for "
            "two\ntranslation units to disagree about. The parser canary still matched, so this is "
            "the end state\nokf/policies/helper-placement-by-reach.md asks for rather than a scan "
            "that saw nothing."
        )
        return 0

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
                  "by_name": collections.defaultdict(list), "unparsed": [], "unclaimed": [],
                  "crowded": [], "defs": []}
        for path, raw in files.items():
            result = scan_file(path, raw)
            if "error" in result:
                failures.append(f"scan_file() errored on {path}: {result['error']}")
                continue
            report["definitions"] += len(result["definitions"])
            report["loose_heads"] += result["loose"]
            for line, text in result["unparsed"]:
                report["unparsed"].append({"file": path, "line": line, "text": text})
            for line, text in result["unclaimed"]:
                report["unclaimed"].append({"file": path, "line": line, "text": text})
            for line, count in result["crowded"]:
                report["crowded"].append({"file": path, "line": line, "count": count})
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
    #     An ATTRIBUTE or `alignas` before the keyword is the same stated limitation as `template`,
    #     and #2833's review asked for the regex to learn it. Measured first: zero `[[...]]` and zero
    #     `alignas` across the 74 `.mm` files and the 16 headers, so widening TYPE_DEF would add a
    #     branch nothing exercises. This pins the limitation instead, in both directions: the shape is
    #     not parsed, and it is not claimed by the loose scan either, so it is silently uncompared
    #     rather than a false ABORT. The day the bridge acquires one, `check-bridge-type-odr` has to
    #     learn it, and this case is what says so.
    for attributed in ("[[nodiscard]] struct Attributed\n{\n  int v;\n};\n",
                       "alignas(16) struct Aligned\n{\n  int v;\n};\n"):
        shape = scan_file("a.mm", attributed)
        if shape["definitions"]:
            failures.append(
                f"an attributed definition is now parsed ({attributed.splitlines()[0]}), so the "
                f"limitation this case pins is gone and the comment on TYPE_DEF is stale"
            )
        if shape["unparsed"] or shape["unclaimed"]:
            failures.append(
                f"an attributed definition now reaches the view check "
                f"({attributed.splitlines()[0]}): unparsed={shape['unparsed']}, "
                f"unclaimed={shape['unclaimed']}. TYPE_DEF has to learn the shape, or the gate "
                f"ABORTs on legal code"
            )

    # 14b. #2833's CRITICAL. The plausibility check replacing the `definitions < 100` floor, and the
    #      two properties it needs: it still catches a parser that matches nothing, and it does NOT
    #      fire on the legitimate direction of travel, which is types moving into
    #      OCCTBridge_Internal.h until no `.mm` defines one.
    hoisted = collect({"a.mm": "int f(void)\n{\n  return 0;\n}\n",
                       "b.mm": "#include \"OCCTBridge_Internal.h\"\nint g(void)\n{\n  return 1;\n}\n"})
    if view_problems(hoisted):
        failures.append(
            f"a fully hoisted bridge, the end state helper-placement-by-reach.md asks for, was "
            f"reported as an implausible view: {view_problems(hoisted)}"
        )
    if hoisted["definitions"] or hoisted["loose_heads"]:
        failures.append(
            f"the hoisted fixture is not actually empty: {hoisted['definitions']} definitions, "
            f"{hoisted['loose_heads']} loose heads"
        )
    #      ...and a parser that matches nothing over a tree that HAS types is still caught, which is
    #      the whole job the floor was doing. Driven by neutering TYPE_DEF rather than by a fixture,
    #      because a regex that stops matching is the failure mode and no fixture can stand in for it.
    saved = globals()["TYPE_DEF"]
    try:
        globals()["TYPE_DEF"] = re.compile(r"^(?!)", re.M)  # matches nothing, ever
        blinded = collect({"a.mm": same, "b.mm": same})
        if not view_problems(blinded):
            failures.append(
                "TYPE_DEF matching nothing over a tree with two type definitions was reported as a "
                "plausible view; the replacement for the `definitions < 100` floor does not do the "
                "job the floor did"
            )
        blind_canary = canary()
        if not blind_canary:
            failures.append(
                "the canary came back clean with TYPE_DEF matching nothing, so it cannot catch a "
                "parser that goes blind against a tree that has also been emptied"
            )
    finally:
        globals()["TYPE_DEF"] = saved
    #      The canary passes against the real parser, and it is what covers the one case the
    #      two-scan agreement cannot: both scans blind at once, which agrees at zero.
    if canary():
        failures.append(f"the canary does not come back against the real parser: {canary()}")
    #      A definition written on one line is the shape that breaks the equality in the other
    #      direction, and it must be NAMED rather than counted: the loose scan skips a line ending in
    #      `;`, the parser matches it, so the two stop sizing the same population.
    one_liner = collect({"a.mm": "struct Inline { int a; };\n"})
    if not one_liner["unclaimed"] or not view_problems(one_liner):
        failures.append(
            f"a one-line type definition did not reach the view check: "
            f"unclaimed={one_liner['unclaimed']}, problems={view_problems(one_liner)}"
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
        "SELF-TEST: OK (28 cases: identical copies, added field, reordered members, "
        "clang-format alignment, comment, string literal x2, #2080 comment shape, single "
        "definition, one file twice, forward declaration x2, brace-initialised variable, real "
        "bridge shapes, nested type, brace in a literal, view check x3, attributed definition x2, "
        "fully hoisted tree, blinded parser x2, canary, one-line definition, normaliser sanity x4, "
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
