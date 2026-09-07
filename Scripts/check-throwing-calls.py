#!/usr/bin/env python3
"""Gate: a bridge call that OCCT can throw from must sit inside a try in its own function.

The failure this prevents is #345: an uncaught C++ exception crossing from the bridge into
Swift-generated frames has no matching unwind personality routine, so it is a guaranteed
std::terminate/SIGABRT with almost no diagnostic trail. Forty-nine sites had exactly that shape and
were fixed by hand; nothing re-checked that the fix held, or that a bridge function written since
did not reintroduce it. Filed as #1407.

What counts as a throwing call is deliberately narrow, and each entry earned its place in #345's own
audit rather than being guessed:

  * gp_Dir, gp_Ax1, gp_Ax2, gp_Ax3, Geom_Direction, gp_Dir2d, gp_Ax22d built from values, which
    raise Standard_ConstructionError on a null-length or non-perpendicular argument, and
  * the D1/D2 derivative evaluators, which raise on a parameter outside the curve or surface range.

A construction whose arguments are all numeric literals is exempt: its outcome is fixed at compile
time and visible in the line itself, so gp_Dir(0, 0, 1) is not a hazard the caller can trip.

The unwind boundary is the bridge's exported entry point, not each function, so the check follows
the call chain rather than stopping at the enclosing body. An exported OCCT* function must catch
for itself. A file-local helper is covered when EVERY call of it, in the file that defines it, is
itself inside a try or inside another covered helper, resolved to a fixpoint. That distinction is
not cosmetic: the first version of this gate stopped at the function and reported 33 sites, of
which 30 were helpers whose callers already catch, exactly the false-positive rate #1407 asked to
measure before gating.

Run from anywhere; paths resolve from __file__.
"""

import argparse
import glob
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "Sources", "OCCTBridge", "src")

# Types whose construction from caller values can throw. Each earned its place in an audit rather
# than a guess: the gp_ axis and direction family from #345's own 49 sites, and Standard_GUID from
# #1399's substrate read, which found the bridge building one from a caller-supplied string at
# eight sites. Those eight are all inside a try already, so it was added for the next one.
THROWING_TYPES = [
    "gp_Dir", "gp_Dir2d", "gp_Ax1", "gp_Ax2", "gp_Ax3", "gp_Ax22d", "Geom_Direction",
    "Geom2d_Direction", "Standard_GUID",
]

# Evaluators that raise outside their parameter range.
EVALUATOR_RE = re.compile(r"(?:\.|->)(D1|D2)\s*\(")

CONSTRUCTION_RE = re.compile(
    r"\b(" + "|".join(THROWING_TYPES) + r")\s*(?:\w+\s*)?\(([^;]*)")

NUMERIC_ARG_RE = re.compile(r"^[\s\d.,+\-eE()]*$")

# Functions this gate deliberately does not read, each with the reason it is exempt.
EXEMPT_FUNCTIONS = {
    # occtEnsureSignals installs OCCT's signal handler and runs before any geometry exists.
    "occtEnsureSignals",
}


def function_bodies(text):
    """Yield (name, start_offset, body) for each top-level function in a .mm file."""
    for match in re.finditer(r"^([A-Za-z_][\w:<>,\s*&]*?)\b(\w+)\s*\([^;{]*\)\s*\{", text,
                             re.MULTILINE):
        name = match.group(2)
        open_brace = text.index("{", match.end() - 1)
        depth = 0
        for i in range(open_brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    yield name, open_brace, text[open_brace:i + 1]
                    break


def try_spans(body):
    """Offsets (start, end) of every try block in a function body, relative to the body."""
    spans = []
    for match in re.finditer(r"\btry\b\s*\{", body):
        open_brace = body.index("{", match.end() - 1)
        depth = 0
        for i in range(open_brace, len(body)):
            if body[i] == "{":
                depth += 1
            elif body[i] == "}":
                depth -= 1
                if depth == 0:
                    spans.append((open_brace, i))
                    break
    return spans


def inside(spans, offset):
    return any(start <= offset <= end for start, end in spans)


def strip_noise(body):
    """Blank out comments and string literals so neither can look like a call."""
    out = list(body)
    i = 0
    while i < len(body):
        if body.startswith("//", i):
            j = body.find("\n", i)
            j = len(body) if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
        elif body.startswith("/*", i):
            j = body.find("*/", i + 2)
            j = len(body) if j < 0 else j + 2
            for k in range(i, j):
                out[k] = " "
            i = j
        elif body[i] == '"':
            j = i + 1
            while j < len(body) and not (body[j] == '"' and body[j - 1] != "\\"):
                j += 1
            for k in range(i, min(j + 1, len(body))):
                out[k] = " "
            i = j + 1
        else:
            i += 1
    return "".join(out)


GUARD_RE = re.compile(r"\b(\w+)\s*(?:\.\s*(?:Magnitude|SquareMagnitude)\s*\(\s*\)\s*)?"
                      r"[<>]=?\s*[\d.]+\s*[eE]?-?\d*")


def guarded_names(body, before):
    """Variables compared against a numeric threshold earlier in the function.

    The bridge's idiom for a value that would throw is to measure it and leave early:
    `if (d1.Magnitude() < 1e-12) return false;` before `gp_Dir dir(d1)`, or a `dirLen` computed
    and tested before dividing by it. A construction reading only such variables cannot reach the
    throw, so flagging it would be reporting the guard rather than its absence.
    """
    return {m.group(1) for m in GUARD_RE.finditer(body[:before])}


def findings_for(path, text=None):
    text = open(path, encoding="utf-8").read() if text is None else text
    results = []
    for name, start, raw_body in function_bodies(text):
        if name in EXEMPT_FUNCTIONS:
            continue
        body = strip_noise(raw_body)
        spans = try_spans(body)
        for match in CONSTRUCTION_RE.finditer(body):
            args = match.group(2).split(")")[0]
            if NUMERIC_ARG_RE.match(args):
                continue  # literal construction, outcome fixed at compile time
            names_used = set(re.findall(r"\b([A-Za-z_]\w*)\b", args))
            if names_used & guarded_names(body, match.start()):
                continue  # measured and rejected earlier in this function
            if not inside(spans, match.start()):
                line = text[:start + match.start()].count("\n") + 1
                results.append((line, name, "%s(%s)" % (match.group(1), args.strip()[:48])))
        for match in EVALUATOR_RE.finditer(body):
            if not inside(spans, match.start()):
                line = text[:start + match.start()].count("\n") + 1
                results.append((line, name, match.group(0).strip()))
    return results


def covered_helpers(text):
    """Names of file-local helpers whose every call site is already inside a try, to a fixpoint."""
    bodies = list(function_bodies(text))
    exported = {n for n, _, _ in bodies if n.startswith("OCCT") or n.startswith("occt")}
    calls = {}  # helper -> list of (caller, offset-in-caller, caller-body)
    names = {n for n, _, _ in bodies}
    for name, _, raw in bodies:
        body = strip_noise(raw)
        for match in re.finditer(r"\b(\w+)\s*\(", body):
            callee = match.group(1)
            if callee in names and callee != name:
                calls.setdefault(callee, []).append((name, match.start(), body))
    covered = set()
    changed = True
    while changed:
        changed = False
        for name in names - exported - covered:
            sites = calls.get(name, [])
            if not sites:
                continue  # never called in this file: nothing to lean on
            if all(inside(try_spans(cb), off) or caller in covered for caller, off, cb in sites):
                covered.add(name)
                changed = True
    return covered


def uncalled_helpers(text):
    """File-local helpers with no call site in their own file: dead in this translation unit.

    The .mm splits copied every file-static helper into every split file of the domain, so most
    copies are never called where they sit and cannot reach the bridge boundary from there. They
    are reported as a count rather than as findings, and the duplication itself is its own issue.
    """
    bodies = list(function_bodies(text))
    exported = {n for n, _, _ in bodies if n.startswith("OCCT")}
    dead = set()
    for name, _, _ in bodies:
        if name in exported:
            continue
        if len(re.findall(r"\b" + re.escape(name) + r"\s*\(", strip_noise(text))) <= 1:
            dead.add(name)
    return dead


def run(report_only=False):
    total = []
    unreachable = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.mm"))):
        text = open(path, encoding="utf-8").read()
        safe = covered_helpers(text)
        dead = uncalled_helpers(text)
        for line, func, snippet in findings_for(path, text):
            if func in safe:
                continue
            if func in dead:
                unreachable.append((os.path.relpath(path, REPO), line, func))
                continue
            total.append((os.path.relpath(path, REPO), line, func, snippet))
    if total:
        print("check-throwing-calls: %d call site(s) outside any try in their own function\n"
              % len(total))
        for rel, line, func, snippet in total:
            print("  %s:%d  %s  %s" % (rel, line, func, snippet))
        print("\nEach can raise Standard_ConstructionError from caller values. Reaching the Swift "
              "boundary uncaught is a SIGABRT, not a nil (#345). Wrap the function body in "
              "try/catch, or construct from literals if the values really are fixed.")
        return 0 if report_only else 1
    print("check-throwing-calls: clean, every throwing construction and D1/D2 evaluator in "
          "Sources/OCCTBridge/src is caught, guarded, or unreachable")
    if unreachable:
        print("  %d site(s) sit in file-local helpers never called in their own file, which the "
              ".mm splits duplicated into every file of a domain; they cannot reach the bridge "
              "boundary from there. Tracked as its own cleanup." % len(unreachable))
    return 0


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))
        return ok

    flagged = "void OCCTThing(double x, double y, double z)\n{\n  gp_Dir d(x, y, z);\n}\n"
    case("bare-construction-flagged", len(findings_for("<f>", flagged)) == 1)

    guarded = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
               "    gp_Dir d(x, y, z);\n  }\n  catch (...)\n  {\n  }\n}\n")
    case("guarded-construction-clean", findings_for("<f>", guarded) == [])

    literal = "void OCCTThing()\n{\n  gp_Dir d(0, 0, 1);\n}\n"
    case("literal-construction-exempt", findings_for("<f>", literal) == [])

    evaluator = ("void OCCTThing(double u)\n{\n  gp_Pnt p;\n  gp_Vec v;\n  curve->D1(u, p, v);\n}\n")
    case("bare-evaluator-flagged", len(findings_for("<f>", evaluator)) == 1)

    commented = "void OCCTThing(double x)\n{\n  // gp_Dir d(x, x, x);\n}\n"
    case("comment-not-a-call", findings_for("<f>", commented) == [])

    stringy = 'void OCCTThing(double x)\n{\n  const char* s = "gp_Dir(x, y, z)";\n}\n'
    case("string-not-a-call", findings_for("<f>", stringy) == [])

    # A try in a DIFFERENT function must not cover this one: the unwind boundary is per call frame.
    neighbour = ("void OCCTFirst(double x)\n{\n  try\n  {\n    gp_Dir a(x, x, x);\n  }\n"
                 "  catch (...)\n  {\n  }\n}\n\n"
                 "void OCCTSecond(double y)\n{\n  gp_Dir b(y, y, y);\n}\n")
    found = findings_for("<f>", neighbour)
    case("try-does-not-leak-across-functions",
         len(found) == 1 and found[0][1] == "OCCTSecond", str(found))

    # A construction after the try block closes is still unguarded.
    after = ("void OCCTThing(double x)\n{\n  try\n  {\n    int i = 0;\n  }\n  catch (...)\n"
             "  {\n  }\n  gp_Dir d(x, x, x);\n}\n")
    case("construction-after-try-flagged", len(findings_for("<f>", after)) == 1)

    # The live tree, which is what CI gates.
    helper = ("static gp_Dir tangentOf(double x)\n{\n  return gp_Dir(x, x, x);\n}\n\n"
              "void OCCTThing(double x)\n{\n  try\n  {\n    gp_Dir d = tangentOf(x);\n  }\n"
              "  catch (...)\n  {\n  }\n}\n")
    case("helper-called-only-inside-try-is-covered", "tangentOf" in covered_helpers(helper),
         str(sorted(covered_helpers(helper))))

    leaky = ("static gp_Dir tangentOf(double x)\n{\n  return gp_Dir(x, x, x);\n}\n\n"
             "void OCCTGuarded(double x)\n{\n  try\n  {\n    gp_Dir d = tangentOf(x);\n  }\n"
             "  catch (...)\n  {\n  }\n}\n\n"
             "void OCCTBare(double y)\n{\n  gp_Dir e = tangentOf(y);\n}\n")
    case("helper-with-one-unguarded-caller-is-not-covered",
         "tangentOf" not in covered_helpers(leaky), str(sorted(covered_helpers(leaky))))

    exported_never_covered = ("void OCCTHelperish(double x)\n{\n  gp_Dir d(x, x, x);\n}\n\n"
                              "void OCCTCaller(double x)\n{\n  try\n  {\n"
                              "    OCCTHelperish(x);\n  }\n  catch (...)\n  {\n  }\n}\n")
    case("exported-function-must-catch-for-itself",
         "OCCTHelperish" not in covered_helpers(exported_never_covered))

    live = []
    for path in sorted(glob.glob(os.path.join(SRC, "*.mm"))):
        text = open(path, encoding="utf-8").read()
        safe = covered_helpers(text) | uncalled_helpers(text)
        live.extend([f for f in findings_for(path, text) if f[1] not in safe])
    case("live-tree-clean", not live, "%d site(s), first: %s" % (len(live), live[0] if live else ""))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--report-only", action="store_true",
                        help="list findings but exit 0, for triaging a large backlog")
    args = parser.parse_args()
    sys.exit(self_test() if args.self_test else run(args.report_only))
