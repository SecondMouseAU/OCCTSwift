#!/usr/bin/env python3
"""#1628: `static` definitions in `Sources/OCCTBridge/src/*.mm` with no use in their own file.

A `static` definition at file scope is confined to one translation unit, so "dead" here is a
mechanical, per-file question with no whole-program analysis in it: is the name used anywhere in
the file that defines it? Nothing outside can reach it, which is the whole point of
[helper-placement-by-reach](../okf/policies/helper-placement-by-reach.md) and the reason the `.mm`
splits under #396 left a definition in every file of a domain and callers in one.

CENSUS, not a gate: it exits 0 whether or not it finds anything, and CI runs only its
`--self-test`. It is a census rather than a gate for one reason, and it is not a false-positive
rate: a dead file-static is not a defect. The compiler drops it, and `-Wunused-function` does not
fire on it either, since these are `static` *non-inline* functions in a `.mm` that Objective-C++
still emits. What it costs is paid by readers and by later audits, so the output is a list to
adjudicate, not a verdict on the tree. See
[static-gates](../okf/policies/static-gates.md) for the gate/census distinction.

    python3 Scripts/census-dead-file-statics.py                # the summary
    python3 Scripts/census-dead-file-statics.py --list         # every dead definition, file:line
    python3 Scripts/census-dead-file-statics.py --by-name      # grouped by helper name
    python3 Scripts/census-dead-file-statics.py --divergence   # only names whose copies disagree
    python3 Scripts/census-dead-file-statics.py --json         # machine-readable, for a deletion pass
    python3 Scripts/census-dead-file-statics.py --self-test    # prove each failure mode is caught

## How a use is counted, and which way each rule errs

Every rule below errs towards calling a definition LIVE, because the consumer of this census is a
deletion pass and a false "dead" costs a build break while a false "live" costs nothing but a line.

- **Comments and literals are stripped first**, in one leftmost-match-wins alternation rather than
  two passes, for the reason `derive-bridge-header-split.py` records under #2080: a `/*` inside a
  `//` comment opens a block that runs to the next real `*/` and swallows real code.
- **`Handle(Foo)` is normalised to `Handle_Foo`** before anything is parsed. OCCT's handle macro
  puts a parenthesised type where a return type goes, so `static Handle(Poly_Triangulation)
  occtMergedTriangulation(` reads as a definition of `Handle` to any regex that takes the first
  `name(` it sees. Unnormalised, this script reported 39 definitions of `Handle`.
- **A use must be unqualified.** A `.`, `->` or `::` immediately before the name means a member or
  a scoped name, which cannot be a call to a file-static free function. Without this rule a helper
  sharing a name with any OCCT member (`Value`, `Perform`) reads as live wherever that member is
  called.
- **A use must be outside every definition of that name in the file.** This is what makes a
  self-recursive dead helper come out dead, and it is why the scan needs each definition's brace
  extent rather than just its first line.
- **An overload set is one unit.** `occtArgList` is defined twice per file, and a call cannot be
  attributed to one signature by text. Either every definition of a name in a file is dead or none
  is reported.
- **A name that appears anywhere in `Sources/OCCTBridge/include/*.h` is never reported.** A header
  macro whose body names a helper would expand in the `.mm` with only the macro's own name visible
  there, and the use would be invisible to a per-file scan. No such case exists today; the guard is
  what makes that a measurement rather than an assumption.
- **`#if 0` and other inactive preprocessor blocks are not evaluated**, so a use inside one counts.
  That is the conservative direction.

What is NOT covered: a `static` file-scope *variable* or constant. Those have initialisation order
and address-identity properties a function does not, `--list` would mix two different deletion
decisions, and #1628's own method is functions. `static_count_variables()` reports the figure so
the omission is a number rather than a silence.

## Transitive deadness is reported separately

Deleting a dead helper can leave another dead: `A` is uncalled, `A` is the only caller of `B`, so
`B` is dead once `A` goes. #1628's method is a single pass, so the headline figure is the single
pass, and the fixpoint is printed beside it. A deletion pass wants the fixpoint.
"""
from __future__ import annotations

import argparse
import collections
import glob
import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ROOT)
SRC_DIR = "Sources/OCCTBridge/src"
HEADER_DIR = "Sources/OCCTBridge/include"

# One pass, leftmost-match-wins, so whichever of these opens first consumes the others. Two passes
# cannot work in either order (#2080, in derive-bridge-header-split.py).
COMMENT_OR_LITERAL = re.compile(
    r'"(?:\\.|[^"\\\n])*"'  # string literal
    r"|'(?:\\.|[^'\\\n])*'"  # character literal
    r"|//[^\n]*"  # line comment
    r"|/\*.*?\*/",  # block comment
    re.S,
)

# OCCT's handle macro, `Handle(Geom_Curve)`, in return-type position.
HANDLE_MACRO = re.compile(r"\bHandle\s*\(\s*([A-Za-z_]\w*)\s*\)")

# A file-scope `static` declarator: `static` at column 0, then everything up to the first `(`.
# `[^;{(=]*` is what rejects a `static` variable with a function call in its initialiser
# (`static const double kX = f(1);`) and a `static` variable with no parens at all.
STATIC_DECL = re.compile(r"^static\s+(?P<prefix>[^;{(=]*?)(?P<name>[A-Za-z_]\w*)\s*\(", re.M)

# A file-scope `static` that is not a function: no `(` before the `;` or `=` or `{`.
STATIC_VARIABLE = re.compile(r"^static\s+[^;(]*?[A-Za-z_]\w*\s*(?:\[[^\]]*\])?\s*(?:=|;)", re.M)


def strip_comments_and_literals(text: str) -> str:
    """Blank out comments; keep literals as empty ones so token positions stay sane."""

    def keep_or_drop(match: re.Match) -> str:
        token = match.group(0)
        if token.startswith("//"):
            return " " * len(token)
        if token.startswith("/*"):
            # Preserve newlines so line numbers survive.
            return re.sub(r"[^\n]", " ", token)
        if token.startswith('"'):
            return '""' + " " * (len(token) - 2)
        return "''" + " " * (len(token) - 2)

    return COMMENT_OR_LITERAL.sub(keep_or_drop, text)


def normalise_handles(text: str) -> str:
    """`Handle(Geom_Curve)` -> `Handle_Geom_Curve`, padded so offsets do not move."""

    def replace(match: re.Match) -> str:
        collapsed = "Handle_" + match.group(1)
        return collapsed + " " * (len(match.group(0)) - len(collapsed))

    return HANDLE_MACRO.sub(replace, text)


def prepare(text: str) -> str:
    """The text every scan below runs on. Offsets match the raw file, so line numbers are real."""
    return normalise_handles(strip_comments_and_literals(text))


def brace_extent(text: str, open_paren: int) -> tuple[int, int] | None:
    """From a definition's `(`, the [start, end) of its body, or None if it is a prototype."""
    depth = 0
    i = open_paren
    while i < len(text):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                break
        i += 1
    else:
        return None
    # After the parameter list: a `{` means a definition, a `;` means a prototype.
    j = i + 1
    while j < len(text) and (text[j].isspace() or text[j] in "&*"):
        j += 1
    # Skip trailing specifiers (`const`, `noexcept`, a trailing return type).
    while j < len(text) and text[j] not in "{;":
        j += 1
    if j >= len(text) or text[j] == ";":
        return None
    depth = 0
    k = j
    while k < len(text):
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
            if depth == 0:
                return (j, k + 1)
        k += 1
    return None


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def definitions_in(prepared: str) -> list[dict]:
    """Every file-scope `static` function definition, with its name, line and body extent."""
    out = []
    for match in STATIC_DECL.finditer(prepared):
        extent = brace_extent(prepared, match.end() - 1)
        if extent is None:
            continue  # a prototype, or something that is not a function definition at all
        out.append(
            {
                "name": match.group("name"),
                "line": line_of(prepared, match.start()),
                "decl_start": match.start(),
                "name_start": match.start("name"),
                "body": extent,
                "end_line": line_of(prepared, extent[1]),
            }
        )
    return out


def declarator_name_offsets(prepared: str, name: str) -> set[int]:
    """Where `name` appears as the declared name of a `static` definition or prototype.

    Taken from the match's own named group rather than from a fixed window after `static`: an
    earlier version allowed 20 characters between the two, which `static Handle(Poly_Triangulation)
    dead(` exceeds, so the declarator's own name read as a call and every handle-returning helper
    came out live.
    """
    return {
        m.start("name") for m in STATIC_DECL.finditer(prepared) if m.group("name") == name
    }


def prototypes_in(prepared: str) -> list[tuple[str, int]]:
    """Every file-scope `static` function PROTOTYPE (declared, defined further down)."""
    out = []
    for match in STATIC_DECL.finditer(prepared):
        if brace_extent(prepared, match.end() - 1) is None:
            out.append((match.group("name"), line_of(prepared, match.start())))
    return out


def unqualified_uses(prepared: str, name: str) -> list[int]:
    """Offsets of every unqualified occurrence of `name`.

    Qualified means preceded by `.`, `->` or `::`: a member or a scoped name, neither of which can
    be a call to a file-static free function.
    """
    hits = []
    for match in re.finditer(rf"\b{re.escape(name)}\b", prepared):
        before = prepared[max(0, match.start() - 2) : match.start()]
        if before.endswith("->") or before.endswith("::") or before.endswith("."):
            continue
        hits.append(match.start())
    return hits


def header_names() -> set[str]:
    """Every identifier appearing anywhere in the bridge headers.

    A helper named in a header macro's body would be used in a `.mm` under the macro's name, and a
    per-file scan cannot see that. Any candidate whose name occurs in a header is not reported.
    """
    names: set[str] = set()
    for path in sorted(glob.glob(os.path.join(HEADER_DIR, "*.h"))):
        with open(path, encoding="utf-8") as fh:
            names.update(re.findall(r"\b[A-Za-z_]\w*\b", fh.read()))
    return names


def static_count_variables(prepared: str) -> int:
    """File-scope `static` definitions that are not functions. Counted, not reported (see docstring)."""
    return sum(1 for _ in STATIC_VARIABLE.finditer(prepared))


def analyse_text(prepared: str, excluded: set[str] | None = None) -> dict:
    """One file's verdicts. `excluded` names are never reported dead (the header-macro guard)."""
    excluded = excluded or set()
    defs = definitions_in(prepared)
    protos = dict(collections.Counter(n for n, _ in prototypes_in(prepared)))
    by_name: dict[str, list[dict]] = collections.defaultdict(list)
    for d in defs:
        by_name[d["name"]].append(d)

    result = {"definitions": defs, "dead": [], "live": [], "prototypes": protos}
    for name, group in by_name.items():
        extents = [d["body"] for d in group]
        # A declarator's own name, in a definition or in a prototype further up, is not a use.
        declarators = declarator_name_offsets(prepared, name)
        external = []
        for offset in unqualified_uses(prepared, name):
            if offset in declarators:
                continue
            if any(start <= offset < end for start, end in extents):
                continue  # inside one of its own bodies: recursion, not a caller
            external.append(offset)
        if external or name in excluded:
            result["live"].extend(group)
        else:
            result["dead"].extend(group)
    return result


def transitive_dead(prepared: str, excluded: set[str] | None = None) -> list[dict]:
    """The fixpoint: deleting a dead helper can leave its callees dead too."""
    excluded = excluded or set()
    removed: set[str] = set()
    while True:
        masked = prepared
        for name in removed:
            for d in definitions_in(prepared):
                if d["name"] == name:
                    start, end = d["decl_start"], d["body"][1]
                    masked = masked[:start] + " " * (end - start) + masked[end:]
        result = analyse_text(masked, excluded)
        names = {d["name"] for d in result["dead"]}
        if names <= removed:
            return [d for d in definitions_in(prepared) if d["name"] in removed]
        removed |= names


def mm_files() -> list[str]:
    return sorted(glob.glob(os.path.join(SRC_DIR, "*.mm")))


def body_text(raw: str, d: dict) -> str:
    """The raw source of one definition, declaration line through closing brace."""
    return raw[d["decl_start"] : d["body"][1]]


def body_digests(path: str, raw: str, result: dict) -> dict:
    """One digest per helper name in this file, for the divergence comparison.

    Two things the shape of this is load-bearing for, one per half.

    **The digest covers the file's WHOLE overload set in source order**, because hashing each
    definition separately made every overload set look divergent: `occtArgList`'s two signatures are
    two different bodies by design, in all twelve files identically.

    **Live definitions are digested as well as dead ones**, because the comparison that matters is
    dead against live, not dead against dead. `fillCommonPart`'s eleven dead copies agreed perfectly
    with each other and disagreed with the one live copy, which is the whole of #1628's realised
    prediction, and a dead-only comparison reports that as clean.
    """
    per_name: dict[str, list[dict]] = collections.defaultdict(list)
    for d in result["dead"] + result["live"]:
        per_name[d["name"]].append(d)
    dead_here = {(d["name"], d["line"]) for d in result["dead"]}
    out = {}
    for name, group in per_name.items():
        ordered = sorted(group, key=lambda x: x["line"])
        joined = "\n".join(body_text(raw, d) for d in ordered)
        out[name] = {
            "file": path,
            "digest": hashlib.sha256(joined.encode()).hexdigest()[:12],
            "lines": sum(d["end_line"] - d["line"] + 1 for d in ordered),
            "state": "dead" if (ordered[0]["name"], ordered[0]["line"]) in dead_here else "live",
        }
    return out


def run_census() -> dict:
    files = mm_files()
    if not files:
        print(f"ABORT: no .mm files under {SRC_DIR}", file=sys.stderr)
        sys.exit(2)
    excluded = header_names()
    report = {
        "files": len(files),
        "definitions": 0,
        "dead": [],
        "live": 0,
        "transitive_extra": [],
        "static_variables": 0,
        "bodies": {},
    }
    for path in files:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
        prepared = prepare(raw)
        if raw.strip() and not prepared.strip():
            print(f"ABORT: stripping emptied {path}", file=sys.stderr)
            sys.exit(2)
        result = analyse_text(prepared, excluded)
        report["definitions"] += len(result["definitions"])
        report["live"] += len(result["live"])
        report["static_variables"] += static_count_variables(prepared)
        single = {d["name"] for d in result["dead"]}
        for d in result["dead"]:
            report["dead"].append({"file": path, **{k: d[k] for k in ("name", "line", "end_line")}})
        for name, entry in body_digests(path, raw, result).items():
            report["bodies"].setdefault(name, []).append(entry)
        for d in transitive_dead(prepared, excluded):
            if d["name"] not in single:
                report["transitive_extra"].append(
                    {"file": path, **{k: d[k] for k in ("name", "line", "end_line")}}
                )
    # Validate the view, not just the verdict (static-gates.md). A run where nothing is live means
    # the use scan is broken, and it would look exactly like a tree with no live helpers.
    if report["definitions"] and not report["live"]:
        print("ABORT: every static definition read as dead; the use scan is blind", file=sys.stderr)
        sys.exit(2)
    if report["definitions"] < 100:
        print(
            f"ABORT: only {report['definitions']} static definitions found across "
            f"{len(files)} files; the definition scan is not seeing the tree",
            file=sys.stderr,
        )
        sys.exit(2)
    return report


def divergent_sets(report: dict) -> dict:
    """Names with a dead copy whose bodies are not all byte-identical across files.

    The difference is the finding, per helper-placement-by-reach.md: six of #957's twelve copies had
    already lost a guard, which is what turned that from drift-prevention into a `type:bug`. Names
    with only one definition in the tree cannot diverge and are not reported.
    """
    out = {}
    for name, entries in report["bodies"].items():
        if not any(e["state"] == "dead" for e in entries):
            continue
        if len({e["digest"] for e in entries}) > 1:
            out[name] = entries
    return out


def print_report(report: dict, args) -> None:
    dead = report["dead"]
    by_name = collections.Counter(d["name"] for d in dead)
    dead_lines = sum(d["end_line"] - d["line"] + 1 for d in dead)

    if args.json:
        print(json.dumps({k: v for k, v in report.items() if k != "bodies"}, indent=2))
        return

    if args.divergence:
        diverged = divergent_sets(report)
        print(f"Names with a dead copy whose bodies are NOT all byte-identical: {len(diverged)}")
        for name, entries in sorted(diverged.items()):
            print(
                f"\n  {name}: {len(entries)} files, "
                f"{len({e['digest'] for e in entries})} distinct bodies"
            )
            for e in sorted(entries, key=lambda x: (x["state"], x["file"])):
                print(f"    {e['state']:4s}  {e['digest']}  {e['lines']:3d} lines  {e['file']}")
        return

    if args.by_name:
        for name, count in by_name.most_common():
            files = sorted(d["file"] for d in dead if d["name"] == name)
            print(f"{count:3d}  {name}")
            for path in files:
                line = next(d["line"] for d in dead if d["name"] == name and d["file"] == path)
                print(f"       {path}:{line}")
        print()

    if args.list:
        for d in dead:
            print(f"{d['file']}:{d['line']}-{d['end_line']}  {d['name']}")
        print()

    print(f"Bridge .mm files scanned:            {report['files']}")
    print(f"File-scope static function defs:     {report['definitions']}")
    print(f"  with a use in their own file:      {report['live']}")
    print(f"  DEAD (no use in their own file):   {len(dead)}  in {len({d['file'] for d in dead})} files")
    print(f"  distinct dead helper names:        {len(by_name)}")
    print(f"  source lines they occupy:          {dead_lines}")
    print(f"Dead only once the above go:         {len(report['transitive_extra'])}")
    print(f"File-scope static VARIABLES (not in scope, counted): {report['static_variables']}")
    diverged = divergent_sets(report)
    print(f"Dead-copy sets with divergent bodies: {len(diverged)}  ({', '.join(sorted(diverged)) or 'none'})")


# ---------------------------------------------------------------------------
# Self-test


def _analyse_fixture(source: str, excluded: set[str] | None = None) -> dict:
    return analyse_text(prepare(source), excluded)


def self_test() -> bool:
    failures: list[str] = []

    def check(label: str, source: str, expect_dead: set[str], expect_live: set[str],
              excluded: set[str] | None = None) -> None:
        result = _analyse_fixture(source, excluded)
        dead = {d["name"] for d in result["dead"]}
        live = {d["name"] for d in result["live"]}
        if dead != expect_dead:
            failures.append(f"{label}: dead={sorted(dead)}, expected {sorted(expect_dead)}")
        if live != expect_live:
            failures.append(f"{label}: live={sorted(live)}, expected {sorted(expect_live)}")

    # 1. The base case: one dead, one called.
    check(
        "plain dead and live",
        "static int dead(int a) { return a; }\n"
        "static int live(int a) { return a; }\n"
        "int entry(void) { return live(1); }\n",
        {"dead"}, {"live"},
    )

    # 2. A use inside a COMMENT is not a use. Without stripping, every helper reads as live.
    check(
        "comment mention is not a use",
        "static int dead(int a) { return a; }\n"
        "// dead(1) is what this used to do\n"
        "int entry(void) { return 0; }\n",
        {"dead"}, set(),
    )

    # 3. A use inside a STRING LITERAL is not a use.
    check(
        "string literal mention is not a use",
        "static int dead(int a) { return a; }\n"
        'const char* s = "dead(1)";\n',
        {"dead"}, set(),
    )

    # 4. #2080's shape: a `/*` inside a `//` comment must not swallow the real call below it.
    check(
        "a /* inside a // comment does not swallow real code",
        "static int live(int a) { return a; }\n"
        "// see Sources/OCCTBridge/src/*.mm for the rest\n"
        "int entry(void) { return live(1); }\n",
        set(), {"live"},
    )

    # 5. OCCT's handle macro in return-type position: the name is the function, not `Handle`.
    check(
        "Handle(Foo) return type",
        "static Handle(Poly_Triangulation) dead(int a) { return 0; }\n",
        {"dead"}, set(),
    )

    # 6. A QUALIFIED occurrence is not a use: a member of the same name does not revive a helper.
    check(
        "qualified use does not count",
        "static double Value(int a) { return a; }\n"
        "double entry(Curve c) { return c.Value(1); }\n",
        {"Value"}, set(),
    )

    # 7. Self-recursion is not a use: a recursive helper nobody calls is still dead.
    check(
        "self-recursion is not a caller",
        "static int dead(int a) { return a > 0 ? dead(a - 1) : 0; }\n",
        {"dead"}, set(),
    )

    # 8. An OVERLOAD SET is one unit: a call to either keeps both.
    check(
        "overload set with one call keeps both",
        "static int over(int a) { return a; }\n"
        "static int over(int a, int b) { return a + b; }\n"
        "int entry(void) { return over(1); }\n",
        set(), {"over"},
    )
    check(
        "overload set with no call reports both",
        "static int over(int a) { return a; }\n"
        "static int over(int a, int b) { return a + b; }\n",
        {"over"}, set(),
    )

    # 9. A PROTOTYPE is not a use, and the definition below it is still dead. The COUNT is the
    #    assertion, not just the name: a first version of this case checked the name set alone, and
    #    the removal matrix showed it still passed with `brace_extent()` accepting a prototype as a
    #    definition, because both entries carry the same name and both come out dead.
    proto_src = "static int dead(int a);\nstatic int dead(int a) { return a; }\n"
    check("prototype plus definition, no caller", proto_src, {"dead"}, set())
    proto_result = _analyse_fixture(proto_src)
    if len(proto_result["definitions"]) != 1:
        failures.append(
            f"a prototype was counted as a definition: "
            f"{len(proto_result['definitions'])} definitions, expected 1"
        )
    if len(proto_result["dead"]) != 1:
        failures.append(
            f"a prototype was reported as a deletable definition: "
            f"{len(proto_result['dead'])} dead, expected 1"
        )

    # 10. A FUNCTION POINTER reference with no call parens is a use.
    check(
        "function pointer reference is a use",
        "static int live(int a) { return a; }\n"
        "int (*fp)(int) = live;\n",
        set(), {"live"},
    )

    # 11. A use through a same-file MACRO is a use.
    check(
        "same-file macro body naming the helper is a use",
        "static int live(int a) { return a; }\n"
        "#define CALL_IT(x) live(x)\n"
        "int entry(void) { return CALL_IT(1); }\n",
        set(), {"live"},
    )

    # 12. The header-macro guard: an excluded name is never reported dead.
    check(
        "header-named helper is never reported",
        "static int fromHeader(int a) { return a; }\n",
        set(), {"fromHeader"}, {"fromHeader"},
    )

    # 13. A static VARIABLE is not a function definition, even with parens in its initialiser.
    result = _analyse_fixture(
        "static const double kTol = computeTol(1);\n"
        "static const char* kNames[] = { \"a\", \"b\" };\n"
        "static const gp_Pnt kOrigin(0, 0, 0);\n"
    )
    if result["definitions"]:
        failures.append(
            f"static variables read as function definitions: "
            f"{[d['name'] for d in result['definitions']]}"
        )

    #     And the declarator must not run PAST its own `;` into the next function. `STATIC_DECL`'s
    #     character class matches newlines, which it has to: a bridge definition's return type,
    #     name and parameter list routinely span lines. So excluding `;` is the only thing stopping
    #     a `static` variable from pairing with the next ordinary function's name, and the removal
    #     matrix showed nothing exercised that. `entry` below is not `static` and must not be
    #     reported at all.
    result = _analyse_fixture("static int kCount;\nint entry(void) { return kCount; }\n")
    if result["definitions"]:
        failures.append(
            f"a static variable's declarator reached into the next function: "
            f"{[d['name'] for d in result['definitions']]}"
        )

    # 14. A use inside another DEAD helper's body still counts as a use on the single pass, and the
    #     transitive pass is what finds it. This is the figure #1628's method does not report.
    prepared = prepare(
        "static int inner(int a) { return a; }\n"
        "static int outer(int a) { return inner(a); }\n"
    )
    single = {d["name"] for d in analyse_text(prepared)["dead"]}
    fixpoint = {d["name"] for d in transitive_dead(prepared)}
    if single != {"outer"}:
        failures.append(f"single pass: dead={sorted(single)}, expected ['outer']")
    if fixpoint != {"inner", "outer"}:
        failures.append(f"fixpoint: dead={sorted(fixpoint)}, expected ['inner', 'outer']")

    # 15. `#if 0` is not evaluated, so a use inside one counts: the conservative direction.
    check(
        "inactive preprocessor block counts as a use",
        "static int live(int a) { return a; }\n"
        "#if 0\n"
        "int entry(void) { return live(1); }\n"
        "#endif\n",
        set(), {"live"},
    )

    # 16. `--divergence` compares dead against LIVE, not dead against dead. A first version compared
    #     only the dead copies, which reports `fillCommonPart` as clean: its eleven dead copies agree
    #     perfectly with each other and disagree with the one live copy, which is the entire finding.
    #
    #     Two fixtures, because one of them could not see it. The first runs the real collection over
    #     two synthetic FILES, which is what `fillCommonPart` is: a dead copy in one file and a
    #     different live copy in another. The removal matrix showed the report-shaped fixture below
    #     passed with live definitions dropped from the collection entirely, since it hands
    #     `divergent_sets()` a dict the collection never built.
    dead_file = "static int helper(int a) { return a; }\n"
    live_file = "static int helper(int a) { return a + 1; }\nint entry(void) { return helper(1); }\n"
    collected: dict = {}
    for path, src in (("dead.mm", dead_file), ("live.mm", live_file)):
        prepared = prepare(src)
        for name, entry in body_digests(path, src, analyse_text(prepared)).items():
            collected.setdefault(name, []).append(entry)
    states = {e["file"]: e["state"] for e in collected.get("helper", [])}
    if states != {"dead.mm": "dead", "live.mm": "live"}:
        failures.append(f"body_digests() states: {states}, expected dead.mm dead and live.mm live")
    if "helper" not in divergent_sets({"bodies": collected}):
        failures.append(
            "divergence: a dead copy whose body differs from the live copy in another file "
            "was not reported by the real collection path"
        )

    stale = {
        "bodies": {
            "staleCopies": [
                {"file": "a.mm", "digest": "aaa", "lines": 32, "state": "dead"},
                {"file": "b.mm", "digest": "aaa", "lines": 32, "state": "dead"},
                {"file": "c.mm", "digest": "bbb", "lines": 68, "state": "live"},
            ],
            "agreeing": [
                {"file": "a.mm", "digest": "ccc", "lines": 10, "state": "dead"},
                {"file": "c.mm", "digest": "ccc", "lines": 10, "state": "live"},
            ],
            "liveOnlyDivergence": [
                {"file": "a.mm", "digest": "ddd", "lines": 10, "state": "live"},
                {"file": "c.mm", "digest": "eee", "lines": 11, "state": "live"},
            ],
        }
    }
    diverged = divergent_sets(stale)
    if "staleCopies" not in diverged:
        failures.append("divergence: dead copies disagreeing with the LIVE copy were not reported")
    if "agreeing" in diverged:
        failures.append("divergence: a name whose copies all agree was reported")
    if "liveOnlyDivergence" in diverged:
        failures.append("divergence: a name with no dead copy at all was reported")

    # 17. The abort guards are not decorative: prove each one can fire.
    if static_count_variables(prepare("static const double kX = 1.0;\n")) != 1:
        failures.append("static_count_variables() did not count a plain static variable")
    real_headers = header_names()
    if "OCCTShapeCreateBox" not in real_headers:
        failures.append("header_names() did not find a known bridge declaration; the guard is blind")
    if "occtDefinitelyNotAnIdentifierAnywhere" in real_headers:
        failures.append("header_names() reported an identifier that cannot exist")

    if failures:
        for f in failures:
            print(f"SELF-TEST FAILURE: {f}")
        return False
    print("SELF-TEST: OK (19 cases: dead/live base, comment, literal, #2080 comment shape, "
          "Handle(Foo), qualified use, recursion, overload set x2, prototype, function pointer, "
          "macro, header guard, static variable x2, transitive fixpoint, #if 0, divergence vs "
          "live x2, guard sanity)")
    return True


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--list", action="store_true", help="every dead definition, file:line-line")
    ap.add_argument("--by-name", action="store_true", help="group the dead definitions by helper name")
    ap.add_argument("--divergence", action="store_true", help="only the dead-copy sets that disagree")
    ap.add_argument("--json", action="store_true", help="machine-readable, for a deletion pass")
    ap.add_argument("--self-test", action="store_true", help="prove each failure mode is caught")
    args = ap.parse_args()

    if args.self_test:
        return 0 if self_test() else 1

    print_report(run_census(), args)
    return 0  # census, never a gate


if __name__ == "__main__":
    os.chdir(REPO_ROOT)
    sys.exit(main())
