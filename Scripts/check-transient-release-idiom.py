#!/usr/bin/env python3
"""GATE: every bridge release of a raw Standard_Transient follows opencascade::handle::EndScope.

`opencascade::handle<T>::EndScope` (`Standard_Handle.hxx:389-394` in the pinned headers) is the
only caller of `DecrementRefCounter` anywhere in the pinned OCCT tree, and it is the whole of the
kernel's protocol for giving a reference back:

    void EndScope()
    {
      if (entity != nullptr && entity->DecrementRefCounter() == 0)
        entity->Delete();
      entity = nullptr;
    }

Two things in four lines. **Use the value the decrement returns**, and **call the virtual
`Delete()`**. A bridge function that hands a raw `Standard_Transient*` across the C boundary cannot
hold an `opencascade::handle` for the caller, so it writes those lines itself, and `OCCTBridge_
Internal.h` records why each half matters:

  * re-reading with a separate `GetRefCount()` is a race window three ways over. Another thread's
    `BeginScope` landing between the two lines hides a zero and leaks the object; another thread's
    `EndScope` landing between them frees the block that is about to be read; and the acquire fence
    `DecrementRefCounter` issues only on the zero-returning RMW is skipped, so the destructor can
    run against writes it never synchronised with.
  * `delete` is not `Delete()`. `Delete()` is virtual, and it is what the kernel calls.

`OCCTMessengerRelease` and `OCCTReportRelease` wrote `m->DecrementRefCounter(); if (m->GetRefCount()
== 0) delete m;` instead, in both ways at once. That divergence stood from the day those functions
were written, survived review, and survived PR #2969's predecessor, which was specifically about the
correctness of those two functions. It was found by reading the kernel under
`okf/policies/follow-occt-callers.md` and fixed in PR #2969. Nothing stopped it coming back, which
is this gate (#2974).

WHAT IT MATCHES
---------------
The population is every function in `Sources/OCCTBridge/src/*.mm` that calls
`DecrementRefCounter`, which is three today. Inside one of those functions, three rules:

  1. the decrement's value must be compared against literal `0`. A value discarded
     (`x->DecrementRefCounter();`) is the defect EndScope's first line rules out, and a comparison
     against anything else is an off-by-one in a reference count.
  2. no `GetRefCount()`. In a function that has already decremented, the count is the decrement's
     return value and a second read of it is the race above.
  3. no `delete`. `Delete()` is the virtual the kernel calls, and `->Delete()` does not match the
     keyword.

Scoping rule 3 to decrement-calling functions is what keeps it quiet: a bare `delete` on a bridge
struct the bridge itself `new`'d is most of this tree and is correct code. The rule is not "do not
write `delete`", it is "do not write `delete` where the kernel writes `Delete()`".

An exemption is a comment carrying `transient-release-exempt: <reason>`, on the offending line or in
the run of comment lines immediately above it. The reason is required, for the same reason
`check-doc-snippets.py` requires one on `no-typecheck:`: an exemption whose argument is not written
down is indistinguishable from an oversight. `OCCTTObjApplicationRelease` is the one site that holds
one today, and it is a real divergence rather than a grandfathering: its object is a process-wide
singleton whose own function-local static `Handle` holds a permanent reference, so it must never
destroy on a zero count (#2897).

WHAT IT CANNOT SEE
------------------
  * **A release that never touches the reference count at all.** A function that `delete`s a
    `Standard_Transient` straight out of a `static_cast` is outside the population by construction,
    because the population is keyed on `DecrementRefCounter`. Widening rule 3 to every `delete` in
    every bridge file would fire on every opaque handle struct the bridge owns, which is most of
    them, so the scope is the price of the rule being usable. What covers that shape instead is
    `check-borrowed-handles.py` on the Swift side and the create/release pairing rule in
    `CLAUDE.md`'s Handle-Based Memory Management.
  * **Anything outside `Sources/OCCTBridge/src/*.mm`**: a header, a test, the Swift layer.
  * **A call reached through a macro, a member pointer or a template alias.** The scan is textual:
    it matches the spelling `DecrementRefCounter(`, `GetRefCount(`, `delete`.
  * **Whether the pointer is one this bridge handed out.** That is the borrow registry
    (`occtBorrowRegister` / `occtBorrowGiveBack`, #2952), a different invariant with its own
    observable, `OCCTBridgeRefusedReleaseCount`.
  * **Order.** It does not check that the decrement follows the registry give-back, only that the
    decrement itself is written the way the kernel writes it.
  * **A comparison spelled some other way**: a Yoda condition `0 == t->DecrementRefCounter()`, a
    typed literal `0ULL`, a parenthesised `(0)`. None is in this tree. All of them **fail safe**,
    because the accepted continuation is matched after the decrement's closing paren, so an
    unrecognised spelling reports `decrement-not-compared-against-zero` rather than passing. That
    is noise a reader resolves in one look, and widening the regex to accept more spellings risks
    accepting one that is not a comparison at all, which would not fail safe.

It is a GATE rather than a census, decided on `okf/policies/static-gates.md`'s measure-then-gate
rule: the backlog is zero (PR #2969 fixed the two sites, and the third is exempt with a reason), the
subject is a use-after-free and a double free rather than a list to adjudicate, and the population
grows only when a new raw `Standard_Transient` is handed across the C boundary.

Run from anywhere; paths resolve from __file__.
"""

import argparse
import glob
import importlib.util
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(REPO, "Scripts")
SRC = os.path.join(REPO, "Sources", "OCCTBridge", "src")


def _load(name, filename):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCRIPTS, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# check-throwing-calls.py owns the bridge's function-body parsing and the comment/string blanking
# that keeps a word in a comment from reading as code. Both are borrowed rather than copied, per
# okf/policies/helper-placement-by-reach.md, which is also what census-compiled-out-validation.py
# does with the same two. `strip_noise` replaces each blanked character with a space, so every
# offset into the stripped text is the same offset into the original, which is what lets a finding
# report a real line number and look for its exemption in the real comment above it.
THROWING = _load("check_throwing_calls", "check-throwing-calls.py")

DECREMENT_RE = re.compile(r"\bDecrementRefCounter\s*\(\s*\)")
GETCOUNT_RE = re.compile(r"\bGetRefCount\s*\(\s*\)")
DELETE_RE = re.compile(r"\bdelete\b(\s*\[\s*\])?")
# The one accepted continuation after the decrement's closing paren: a comparison against literal
# zero, either sense. `== 0` is EndScope's own spelling and `!= 0` is its negation; both decide on
# the value the RMW returned, which is the whole point.
COMPARED_TO_ZERO_RE = re.compile(r"^\s*(==|!=)\s*0\b")
EXEMPT_RE = re.compile(r"transient-release-exempt:\s*(\S.*?)\s*$")


def line_of(text, offset):
    """1-based line number of `offset` in `text`."""
    return text.count("\n", 0, offset) + 1


def exemption_for(raw, lineno):
    """The reason on the offending line or in the comment block immediately above it, or None.

    Walking upward through comment-only lines is what puts the marker where a reader meets the
    code: the argument for a divergence belongs beside the divergence, not in a manifest a reader
    of the .mm never opens. A comment block is any run of lines whose first non-space characters
    are `//`, `*` or `/*`, which is every comment shape clang-format produces in this tree.
    """
    lines = raw.split("\n")
    index = lineno - 1
    if index < 0 or index >= len(lines):
        return None
    candidates = [lines[index]]
    probe = index - 1
    while probe >= 0:
        stripped = lines[probe].strip()
        if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
            candidates.append(lines[probe])
            probe -= 1
            continue
        break
    for line in candidates:
        match = EXEMPT_RE.search(line)
        if not match:
            continue
        # clang-format wraps a long reason onto the following comment lines, and the rest of the
        # argument is usually where the substance is. Read the continuation too, so the report
        # carries the whole reason rather than whatever fitted on the marker's own line.
        reason = [match.group(1)]
        probe = lines.index(line) + 1 if line in lines else len(lines)
        while probe < len(lines):
            stripped = lines[probe].strip()
            if not (stripped.startswith("//") or stripped.startswith("*")):
                break
            tail = stripped.lstrip("/*").strip()
            if not tail or EXEMPT_RE.search(lines[probe]):
                break
            reason.append(tail)
            probe += 1
        return " ".join(reason)
    return None


def findings_for(path, text=None):
    """(findings, functions_examined, decrements_seen) for one bridge .mm file.

    A finding is a dict with `path`, `line`, `function`, `kind`, `detail` and `exempt`.
    """
    if text is None:
        with open(path, encoding="utf-8") as handle:
            raw = handle.read()
    else:
        raw = text
    stripped = THROWING.strip_noise(raw)
    findings = []
    examined = 0
    decrements = 0

    for name, open_brace, body in THROWING.function_bodies(stripped):
        if "DecrementRefCounter" not in body:
            continue
        examined += 1

        def report(kind, offset, detail):
            lineno = line_of(raw, open_brace + offset)
            findings.append({"path": path, "line": lineno, "function": name, "kind": kind,
                             "detail": detail, "exempt": exemption_for(raw, lineno)})

        for match in DECREMENT_RE.finditer(body):
            decrements += 1
            tail = body[match.end():]
            if COMPARED_TO_ZERO_RE.match(tail):
                continue
            nxt = tail.lstrip()[:12].strip()
            if tail.lstrip().startswith(";"):
                report("discards-the-decrement", match.start(),
                       "the value DecrementRefCounter() returned is dropped; EndScope destroys on "
                       "it and nothing else")
            else:
                report("decrement-not-compared-against-zero", match.start(),
                       "DecrementRefCounter() is followed by %r, not a comparison against 0"
                       % (nxt or "end of function"))

        for match in GETCOUNT_RE.finditer(body):
            report("re-reads-the-count", match.start(),
                   "GetRefCount() in a function that has already decremented; the decrement's "
                   "return value is the only correct source and a separate relaxed read is a race")

        for match in DELETE_RE.finditer(body):
            report("bare-delete", match.start(),
                   "`delete` where the kernel calls the virtual Delete()")

    return findings, examined, decrements


# ---------------------------------------------------------------------------
# validate the view, not just the verdict (okf/policies/static-gates.md)
# ---------------------------------------------------------------------------
#
# Three gates in this repo were confidently wrong while reporting all clear, and a gate over a
# three-site population is the easiest of all to blind: delete one regex and it reports a clean
# tree forever. So every real run carries two assertions that do not depend on anybody having
# thought of the right fixture.

CANARY = """
void OCCTCanaryGood(OCCTThingRef thing)
{
  auto* t = static_cast<Standard_Transient*>(thing);
  if (t->DecrementRefCounter() == 0)
    t->Delete();
}

void OCCTCanaryBad(OCCTThingRef thing)
{
  auto* t = static_cast<Standard_Transient*>(thing);
  t->DecrementRefCounter();
  if (t->GetRefCount() == 0)
    delete t;
}
"""

CANARY_EXPECTED = {("OCCTCanaryBad", "discards-the-decrement"),
                   ("OCCTCanaryBad", "re-reads-the-count"),
                   ("OCCTCanaryBad", "bare-delete")}


def canary_problems():
    """The parser canary: a fixture holding one clean site and one of each defect, every run.

    The sign is the one okf/policies/static-gates.md gives a parser canary: it must MATCH, and a
    run where it comes back empty is the scan going blind rather than the tree being clean. It is
    not trippable by any legitimate change to the tree, because it reads no file.
    """
    found, examined, _decrements = findings_for("<canary>", CANARY)
    problems = []
    if examined != 2:
        problems.append("the canary holds 2 decrement-calling functions and the parser found %d"
                        % examined)
    seen = {(f["function"], f["kind"]) for f in found}
    missing = CANARY_EXPECTED - seen
    if missing:
        problems.append("the canary's planted defects were not all reported; missing %s"
                        % ", ".join("%s/%s" % pair for pair in sorted(missing)))
    spurious = {pair for pair in seen if pair[0] == "OCCTCanaryGood"}
    if spurious:
        problems.append("the canary's EndScope-shaped site was reported as a defect: %s"
                        % ", ".join("%s/%s" % pair for pair in sorted(spurious)))
    return problems


def agreement_problems(paths, counts):
    """Two independent measurements of the same population, and they have to agree.

    A plain count of `DecrementRefCounter(` over the blanked text does not know what a function is;
    the scan above reaches every one of them only if `function_bodies` parsed every function that
    holds one. If a declaration shape defeats that parser, the first number stays put and the
    second falls, which is the specific way this gate would go quiet without going red. Preferred
    over a floor on the absolute population, per okf/policies/static-gates.md: an agreement check
    has no direction, so the legitimate change of deleting a release moves both numbers together.
    """
    flat = 0
    for path in paths:
        flat += len(DECREMENT_RE.findall(THROWING.strip_noise(open(path, encoding="utf-8").read())))
    if flat != counts["decrements"]:
        return ["a flat scan finds %d DecrementRefCounter() call(s) and the per-function scan "
                "reached %d; a function holding one was not parsed" % (flat, counts["decrements"])]
    return []


def population_problems(counts, paths):
    """A population of zero is a refusal, not a clean run.

    It means either that the last bridge function handing out a raw Standard_Transient is gone, in
    which case this gate protects nothing and should be retired in the PR that removed it, or that
    the scan stopped seeing them. Those look identical from a green check, which is the whole
    argument of okf/policies/static-gates.md, so the run says so and exits 2 rather than passing.
    """
    if not paths:
        return ["found no .mm files under %s" % os.path.relpath(SRC, REPO)]
    if counts["functions"] == 0:
        return ["no bridge function calls DecrementRefCounter, so this gate examined nothing. "
                "Either the last raw Standard_Transient release is gone (retire the gate in the "
                "PR that removed it) or the scan is blind. "
                "`grep -rn DecrementRefCounter Sources/OCCTBridge/src/` tells the two apart."]
    return []


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------


def collect(paths):
    findings = []
    counts = {"functions": 0, "decrements": 0}
    for path in paths:
        found, examined, decrements = findings_for(path)
        findings.extend(found)
        counts["functions"] += examined
        counts["decrements"] += decrements
    return findings, counts


def run(list_only=False):
    paths = sorted(glob.glob(os.path.join(SRC, "*.mm")))
    problems = canary_problems()
    if problems:
        print("check-transient-release-idiom: refusing to report, the parser canary did not come "
              "back as planted:")
        for problem in problems:
            print("  %s" % problem)
        return 2

    findings, counts = collect(paths)
    problems = population_problems(counts, paths) + agreement_problems(paths, counts)
    if problems:
        print("check-transient-release-idiom: refusing to report, its own view is implausible:")
        for problem in problems:
            print("  %s" % problem)
        return 2

    print("check-transient-release-idiom: %d bridge function(s) in %s call DecrementRefCounter, "
          "over %d call site(s) in %d file(s)"
          % (counts["functions"], os.path.relpath(SRC, REPO), counts["decrements"], len(paths)))

    exempt = [f for f in findings if f["exempt"]]
    real = [f for f in findings if not f["exempt"]]

    for finding in sorted(exempt, key=lambda f: (f["path"], f["line"])):
        print("  exempt  %s:%d  %s  %s: %s"
              % (os.path.relpath(finding["path"], REPO), finding["line"], finding["function"],
                 finding["kind"], finding["exempt"]))

    if list_only:
        for finding in sorted(real, key=lambda f: (f["path"], f["line"])):
            print("  finding %s:%d  %s  %s"
                  % (os.path.relpath(finding["path"], REPO), finding["line"], finding["function"],
                     finding["kind"]))
        return 0

    if not real:
        print("\nEvery one of them follows opencascade::handle::EndScope "
              "(Standard_Handle.hxx:389-394).")
        return 0

    print("\n%d site(s) diverge from opencascade::handle::EndScope "
          "(Standard_Handle.hxx:389-394):\n" % len(real))
    for finding in sorted(real, key=lambda f: (f["path"], f["line"])):
        print("  %s:%d  %s" % (os.path.relpath(finding["path"], REPO), finding["line"],
                               finding["function"]))
        print("      %s: %s" % (finding["kind"], finding["detail"]))
    print("\nWrite what EndScope writes:")
    print("    if (p->DecrementRefCounter() == 0)")
    print("      p->Delete();")
    print("A deliberate divergence carries `transient-release-exempt: <reason>` on the line or in "
          "the comment above it, as OCCTTObjApplicationRelease does for the process-wide singleton "
          "(#2897). See okf/policies/follow-occt-callers.md and #2974.")
    return 1


# ---------------------------------------------------------------------------
# self-test
# ---------------------------------------------------------------------------


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))
        return ok

    def kinds(source):
        found, _examined, _decrements = findings_for("<f>", source)
        return sorted((f["kind"], bool(f["exempt"])) for f in found)

    def wrap(body):
        return "void OCCTThingRelease(OCCTThingRef thing)\n{\n  auto* t = " \
               "static_cast<Message_Messenger*>(thing);\n%s}\n" % body

    # Rule 1, both signs. EndScope's own shape is clean; dropping the value is the defect.
    case("endscope-shape-is-clean",
         kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n")) == [],
         str(kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n"))))
    case("discarded-decrement-is-reported",
         kinds(wrap("  t->DecrementRefCounter();\n")) == [("discards-the-decrement", False)],
         str(kinds(wrap("  t->DecrementRefCounter();\n"))))

    # The negated sense of the same comparison decides on the same value, so it is clean too.
    case("negated-comparison-against-zero-is-clean",
         kinds(wrap("  if (t->DecrementRefCounter() != 0)\n    return;\n  t->Delete();\n")) == [],
         str(kinds(wrap("  if (t->DecrementRefCounter() != 0)\n    return;\n  t->Delete();\n"))))

    # Rule 1b: the value is used, and against the wrong number. A reference count compared against
    # 1 destroys one reference early, which is the same use-after-free by a different route.
    case("comparison-against-nonzero-is-reported",
         kinds(wrap("  if (t->DecrementRefCounter() == 1)\n    t->Delete();\n"))
         == [("decrement-not-compared-against-zero", False)],
         str(kinds(wrap("  if (t->DecrementRefCounter() == 1)\n    t->Delete();\n"))))

    # Rule 2, both signs.
    case("re-read-with-getrefcount-is-reported",
         kinds(wrap("  t->DecrementRefCounter();\n  if (t->GetRefCount() == 0)\n    t->Delete();\n"))
         == [("discards-the-decrement", False), ("re-reads-the-count", False)],
         str(kinds(wrap("  t->DecrementRefCounter();\n  if (t->GetRefCount() == 0)\n"
                        "    t->Delete();\n"))))
    # ...and a GetRefCount in a function that never decrements is an observable, not a defect.
    # OCCTTObjApplicationRefCount is exactly that, which is why the population is keyed on the
    # decrement rather than on the counter API as a whole.
    case("getrefcount-outside-a-decrementing-function-is-not-reported",
         kinds("int OCCTThingRefCount(OCCTThingRef thing)\n{\n  return "
               "static_cast<Message_Messenger*>(thing)->GetRefCount();\n}\n") == [],
         str(kinds("int OCCTThingRefCount(OCCTThingRef thing)\n{\n  return "
                   "static_cast<Message_Messenger*>(thing)->GetRefCount();\n}\n")))

    # Rule 3, both signs. ->Delete() is the kernel's own call and must never read as `delete`.
    case("bare-delete-is-reported",
         kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    delete t;\n"))
         == [("bare-delete", False)],
         str(kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    delete t;\n"))))
    case("virtual-Delete-is-not-reported-as-delete",
         kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n")) == [],
         str(kinds(wrap("  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n"))))
    # ...and the scoping that makes rule 3 usable: a bridge struct the bridge new'd is deleted
    # with `delete` all over this tree, and only a decrement-calling function is in the population.
    case("delete-outside-a-decrementing-function-is-not-reported",
         kinds("void OCCTShapeRelease(OCCTShapeRef shape)\n{\n  delete shape;\n}\n") == [],
         str(kinds("void OCCTShapeRelease(OCCTShapeRef shape)\n{\n  delete shape;\n}\n")))

    # #2969's actual defect, both halves in one function, which is the shape this gate exists for.
    pr2969 = wrap("  t->DecrementRefCounter();\n  if (t->GetRefCount() == 0)\n    delete t;\n")
    case("the-2969-defect-is-reported-as-all-three",
         kinds(pr2969) == [("bare-delete", False), ("discards-the-decrement", False),
                           ("re-reads-the-count", False)],
         str(kinds(pr2969)))

    # Reformatting must not defeat it. clang-format is free to break any of these lines, so the
    # same defect spread over four lines has to report identically to the one-line spelling.
    spread = wrap("  t\n    ->DecrementRefCounter\n    (\n    )\n  ;\n")
    case("a-reformatted-discard-is-still-reported",
         kinds(spread) == [("discards-the-decrement", False)], str(kinds(spread)))
    folded = wrap("  if (t->DecrementRefCounter()\n      == 0)\n    t->Delete();\n")
    case("a-comparison-folded-onto-the-next-line-is-still-clean",
         kinds(folded) == [], str(kinds(folded)))

    # Comments and string literals are blanked, so neither can create or hide a finding.
    commented = wrap("  // t->DecrementRefCounter(); delete t;\n"
                     "  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n")
    case("a-defect-quoted-in-a-comment-is-not-a-finding",
         kinds(commented) == [], str(kinds(commented)))
    quoted = wrap('  const char* m = "delete";\n'
                  "  if (t->DecrementRefCounter() == 0)\n    t->Delete();\n")
    case("the-word-delete-in-a-string-is-not-a-finding", kinds(quoted) == [], str(kinds(quoted)))

    # The exemption, both signs. A marker with a reason suppresses the finding; the same
    # divergence with no marker does not.
    exempted = wrap("  // transient-release-exempt: the singleton's own static Handle holds a\n"
                    "  // permanent reference, so a zero count must never destroy (#2897).\n"
                    "  t->DecrementRefCounter();\n")
    case("an-exempt-divergence-is-reported-as-exempt",
         kinds(exempted) == [("discards-the-decrement", True)], str(kinds(exempted)))
    case("the-same-divergence-without-a-marker-is-a-finding",
         kinds(wrap("  // the singleton's static Handle holds a permanent reference.\n"
                    "  t->DecrementRefCounter();\n"))
         == [("discards-the-decrement", False)],
         str(kinds(wrap("  // the singleton's static Handle holds a permanent reference.\n"
                        "  t->DecrementRefCounter();\n"))))
    # A reason clang-format wrapped is read whole, not truncated at the marker's own line: the
    # substance of an argument is usually past the first line, and a report that shows half of it
    # invites the reader to re-derive the rest.
    wrapped = wrap("  // transient-release-exempt: the singleton's own static Handle holds\n"
                   "  // a permanent reference, so this release can never reach zero.\n"
                   "  t->DecrementRefCounter();\n")
    wrapped_found, _e, _d = findings_for("<f>", wrapped)
    wrapped_reason = [f["exempt"] for f in wrapped_found]
    case("a-wrapped-exemption-reason-is-read-whole",
         wrapped_reason == ["the singleton's own static Handle holds "
                            "a permanent reference, so this release can never reach zero."],
         str(wrapped_reason))

    # A marker with no reason after the colon is not an exemption, on check-doc-snippets.py's
    # precedent: the argument is the whole value of the marker.
    bare_marker = wrap("  // transient-release-exempt:\n  t->DecrementRefCounter();\n")
    case("a-marker-with-no-reason-does-not-exempt",
         kinds(bare_marker) == [("discards-the-decrement", False)], str(kinds(bare_marker)))
    # ...and a marker several comment lines above the statement still reaches it, because that is
    # where clang-format puts a paragraph of justification.
    far_marker = wrap("  // transient-release-exempt: the reason, stated first.\n"
                      "  // Then three more lines of why, which is how this tree writes a\n"
                      "  // justification: the marker leads and the argument follows.\n"
                      "  // The statement is below all of it.\n"
                      "  t->DecrementRefCounter();\n")
    case("a-marker-above-a-comment-paragraph-still-exempts",
         kinds(far_marker) == [("discards-the-decrement", True)], str(kinds(far_marker)))
    # ...but a marker in a DIFFERENT function does not reach into this one. The comment block walk
    # stops at the first non-comment line, which is the closing brace of whatever came before.
    leaked = ("void OCCTOtherRelease(OCCTThingRef thing)\n{\n"
              "  // transient-release-exempt: this one has a reason.\n"
              "  static_cast<Message_Messenger*>(thing)->DecrementRefCounter();\n}\n"
              + wrap("  t->DecrementRefCounter();\n"))
    case("an-exemption-does-not-leak-into-the-next-function",
         kinds(leaked) == [("discards-the-decrement", False), ("discards-the-decrement", True)],
         str(kinds(leaked)))

    # The view checks. The canary must come back exactly as planted on every real run.
    case("the-parser-canary-comes-back-as-planted", canary_problems() == [],
         str(canary_problems()))

    # ...and it has to be able to fail, or it is decoration. Blinding the decrement scan is the
    # single edit that would make this gate report a clean tree forever.
    saved = globals()["DECREMENT_RE"]
    try:
        globals()["DECREMENT_RE"] = re.compile(r"\bNeverAppearsAnywhere\s*\(\s*\)")
        blinded = canary_problems()
        case("a-blinded-scan-trips-the-canary",
             len(blinded) >= 1 and any("found 0" in p or "missing" in p for p in blinded),
             str(blinded))
    finally:
        globals()["DECREMENT_RE"] = saved

    # The agreement check, both signs, against a fixture rather than the tree.
    case("agreement-holds-when-the-two-scans-see-the-same-thing",
         agreement_problems([], {"decrements": 0}) == [],
         str(agreement_problems([], {"decrements": 0})))
    case("a-zero-population-is-a-refusal-and-not-a-clean-run",
         len(population_problems({"functions": 0}, ["<f>"])) == 1
         and "examined nothing" in population_problems({"functions": 0}, ["<f>"])[0],
         str(population_problems({"functions": 0}, ["<f>"])))
    case("a-nonzero-population-is-not-a-refusal",
         population_problems({"functions": 3}, ["<f>"]) == [],
         str(population_problems({"functions": 3}, ["<f>"])))

    # The live tree, which is the half a fixture cannot assert: the gate must actually reach the
    # three real sites, not just its own fixtures. A refactor that renamed the bridge source
    # directory would leave every case above green.
    paths = sorted(glob.glob(os.path.join(SRC, "*.mm")))
    if paths:
        _found, counts = collect(paths)
        case("the-live-tree-population-is-not-empty",
             counts["functions"] >= 1 and counts["decrements"] >= 1,
             "functions=%d decrements=%d" % (counts["functions"], counts["decrements"]))
        case("the-live-tree-agrees-with-a-flat-scan", agreement_problems(paths, counts) == [],
             str(agreement_problems(paths, counts)))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--self-test", action="store_true",
                        help="run the fixture battery proving the detector is not blind")
    parser.add_argument("--list", action="store_true",
                        help="print the population and every site, and exit 0 either way")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    return run(list_only=args.list)


if __name__ == "__main__":
    sys.exit(main())
