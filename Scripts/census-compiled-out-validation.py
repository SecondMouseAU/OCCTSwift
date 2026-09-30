#!/usr/bin/env python3
"""CENSUS: bridge try/catch protection that depends on an OCCT check this build compiles out.

`Scripts/build-occt.sh` configures every slice `-DCMAKE_BUILD_TYPE=Release`, OCCT's
`CMakeLists.txt` defaults `BUILD_RELEASE_DISABLE_EXCEPTIONS` to ON, and
`adm/cmake/occt_defs_flags.cmake` turns that into `-DNo_Exception` on the Release flags. 111 of
OCCT's exception headers gate their `<Exception>_Raise_if` macro on that symbol, so in every OCCT
translation unit the macro expands to nothing.

`No_Exception` is defined only while OCCT's own sources compile. SwiftPM defines nothing of the sort
for `Sources/OCCTBridge/src/*.mm`, so a macro expanded in a header the bridge includes still carries
its check. That gives the asymmetry this census measures (#2801):

  * a `_Raise_if` in an OCCT `.cxx` is compiled once, into libOCCT, with the macro empty. The check
    does not exist in the binary.
  * a `_Raise_if` in an inline body in a `.hxx`/`.lxx` is compiled into the bridge's own object
    file, with the macro live, and fires.

And the sharper consequence, which the raw counts do not state: an inline check is live **only at
the bridge's own instantiation point**. Anything the bridge reaches through an out-of-line OCCT
function had every `_Raise_if` on that path compiled out, at every depth, because every OCCT unit in
between was compiled with `No_Exception`. What survives at depth is only a literal `throw`
statement, which no macro gates. `gp_Ax2(P, N, Vx)` is the worked example: `gp_Ax2` has no
`_Raise_if` of its own, `gp_Ax2.cxx` builds a `gp_Dir` from a cross product, and `gp_Dir`'s check is
inline, so it is live for the bridge and dead for `gp_Ax2.cxx`.

So a bridge `try`/`catch` whose only justification is OCCT validating caller-supplied numbers may be
catching something that cannot be thrown: protection that reads as real and is not, which is #726's
shape applied to control flow. This script reports those sites. It is a census and not a gate: the
verdict on each one is whether the `catch` had another reason to exist, and that is a reading, not a
mechanical fact. See `okf/policies/occt-validation-is-compiled-out.md`.

Four channels, and #2858 added the last two plus the depth qualifier:

  one    try blocks protecting a construction from `check-throwing-calls.py`'s caller-values
         vocabulary (`gp_Dir`, `gp_Ax*`, `Geom_Direction`, the evaluators), verdict per class.
  two    bridge locals of a class whose `StdFail_NotDone` guard is out-of-line, read through one
         of the accessors that guard was protecting, and whether the bridge tests `IsDone()`.
  three  a caller-controlled index or dimension handed to a member whose only bound test was an
         out-of-line `Standard_OutOfRange` / `RangeError` / `DimensionError` macro. Channel two's
         population is `StdFail_NotDone` and nothing else, 1 of the 28 exception kinds among the
         828 out-of-line sites, and all three defects the #2801 sweep proved sat outside it.
         Carries the within-file asymmetry signal: a sibling function in the same file that DOES
         bound-check the same accessor name, which is how #2859 and #2861 were found by hand.
  four   the six OCCT out-of-line files whose `#ifndef No_Exception` region swallows the CONDITION
         as well as the raise, so the check's answer is discarded and the next statement runs on
         data the kernel knows is wrong (PR #2849). Committed as a literal table, because no
         derivation over raise sites can see it; `--verify-no-exception-regions` re-derives it.

WHAT IS STILL DARK, so nobody reads a clean run as an all-clear (#2858):

  * **Channel one's verdict is class-level**, so a class with an inline check on ANY member reads
    as protected even where the member actually called has its check in the `.cxx`. The bias is
    deliberate and it is the reason a clean channel-one run is weaker evidence than a finding.
  * **The map's `members` column is access-blind.** It nominates `private` members no caller can
    reach (`GeomAdaptor_Curve::LocalContinuity`), and it aggregates every exception on a class into
    one row, so channel three's member set includes members guarded by something else.
  * **`inline-raise` does not mean live.** It means live in whichever unit expands it. The
    `inline-dead-at-depth` kind counts the OCCT out-of-line units that name each inline-checked
    class, which is where the same check is compiled out; `gp_Dir` is named by 602 of them.
  * **Neither of the two P1s the sweep found is visible as a finding.** #2840 faults in
    `NCollection_Sequence::Value` and #2855 writes out of bounds in `NCollection_Array1`, in each
    case inside somebody else's `.cxx`, and the class the bridge names reads as protected.
  * **A value the KERNEL fabricates is not this script's subject at all**, nor
    `census-unmeasured-values.py`'s: see that script's sub-kind 5 and #2844.

Modes, and only the bare run works without an OCCT source tree:

  --write-table / --reverify-table   derive `Scripts/occt-raise-if-map.txt` from
                                     `Libraries/occt-src`, one row per OCCT class per kind of
                                     raise site. Needs the tree; `--reverify-table` reports SKIPPED
                                     without it unless `--require-occt-src` is given. Both stamp
                                     the map with the OCCT version and the carried patch set the
                                     tree held, after verifying every carried patch is really in
                                     it, and refuse the tree if one is not (#2885).
                                     `check-inventory-prose.py` is what then fails, on every PR
                                     and with no tree, when that stamp and `Scripts/patches/`
                                     disagree.
  --verify-no-exception-regions      re-derive channel four's committed table, same rules.
  (bare run)                         the census, pure Python over the committed table and
                                     `Sources/OCCTBridge/src/*.mm`.

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
TABLE = os.path.join(SCRIPTS, "occt-raise-if-map.txt")
DEFAULT_OCCT_SRC = os.path.join(REPO, "Libraries", "occt-src")

# ---------------------------------------------------------------------------
# shared bridge parsing, borrowed rather than copied
# ---------------------------------------------------------------------------


def _load(name, filename):
    spec = importlib.util.spec_from_file_location(name, os.path.join(SCRIPTS, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# check-throwing-calls.py owns the bridge's function/try parsing and the vocabulary of OCCT types
# whose construction from caller values can throw. Its subject is the sites OUTSIDE a try; this
# census reads the ones inside, so the two must agree on what a try block and a construction are.
# One copy, per okf/policies/helper-placement-by-reach.md.
THROWING = _load("check_throwing_calls", "check-throwing-calls.py")

# check-inventory-prose.py owns the provenance stamp `--write-table` writes into the map: the
# format, the patch digests it records and the parser that reads them back. It is the gate that
# fails when that stamp and `Scripts/patches/` disagree, which is the only reason the stamp exists
# (#2885), so the writer borrows the format from the reader rather than keeping a second copy of
# it. One copy, per okf/policies/helper-placement-by-reach.md, the same as THROWING above.
INVENTORY = _load("check_inventory_prose", "check-inventory-prose.py")

# ---------------------------------------------------------------------------
# half one: derive the map from OCCT's own sources
# ---------------------------------------------------------------------------

RAISE_RE = re.compile(r"\b([A-Za-z_]\w*)_Raise_if\s*\(")
THROW_RE = re.compile(r"\bthrow\s+([A-Z][A-Za-z0-9]*_[A-Za-z0-9_]+)\s*[({]")
DIRECTIVE_RE = re.compile(r"^\s*#")
# The prefix (a return type, `inline`, `template <...>`) is optional, because OCCT writes every
# out-of-line constructor and destructor with the qualified name at column 0 and nothing before it:
# `math_FunctionRoots::math_FunctionRoots(`, `gp_Dir::~gp_Dir()`. A *required* one-character prefix
# ending at a `\b` cannot match those at all, since there is no word boundary inside the class name,
# so every raise in an out-of-line constructor body used to reach `member_at`'s fallback. Measured
# before the fix: 1,274 of 5,554 sites unattributed, 720 of them in a `.cxx`.
MEMBER_RE = re.compile(r"^\s*(?:[A-Za-z_][\w:<>,\s*&~]*?\b)?([A-Za-z_]\w*)::"
                       r"(~?[A-Za-z_]\w*|operator\S*)\s*\(", re.MULTILINE)

# What the members column records for a site no member body encloses. Written rather than silently
# folded into the class name, because channel two reads this column for accessor names and a class
# name is not one: an unattributed `StdFail_NotDone` site is outside that channel's population, and
# saying so is the difference between a disclosed limitation and an invisible one.
UNATTRIBUTED = "<file-scope>"

# .pxx is a private header OCCT includes from a .cxx, so its checks are compiled with the kernel's
# flags exactly as a .cxx's are. .lxx is included from the .hxx and so is compiled with the
# includer's flags, which for the bridge means the check is live.
INLINE_EXTS = (".hxx", ".lxx")
OUTOFLINE_EXTS = (".cxx", ".pxx")

KINDS = ("inline-raise", "outofline-raise", "inline-throw", "outofline-throw",
         "outofline-delegated", "inherited-live", "inline-dead-at-depth")

CLASS_DECL_RE = re.compile(r"^\s*class\s+(?:Standard_EXPORT\s+)?([A-Za-z_]\w*)\s*:\s*([^{;]*)",
                           re.MULTILINE)
BASE_RE = re.compile(r"\bpublic\s+([A-Za-z_]\w*)")


def strip_comments(text):
    """Blank out comments and string literals. OCCT's doc comments name exceptions constantly."""
    return THROWING.strip_noise(text)


def enclosing_members(text):
    """(start, end, member) for every `Class::Member(...) { ... }` body in a file, by brace match."""
    spans = []
    for match in MEMBER_RE.finditer(text):
        brace = text.find("{", match.end() - 1)
        semi = text.find(";", match.end() - 1)
        if brace < 0 or (0 <= semi < brace):
            continue  # a declaration, or a definition whose body we cannot see
        depth = 0
        for i in range(brace, len(text)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    spans.append((brace, i, match.group(2)))
                    break
    return spans


def member_at(spans, offset, fallback=UNATTRIBUTED):
    """The innermost member body containing an offset, or `fallback` where none encloses it.

    **The fallback is a disclosed gap, not a member name.** `MEMBER_RE` finds a definition written
    `Class::Member(...)`, which leaves two populations it cannot attribute. Measured against the
    `v4.0.0-kernel.2` tree with the constructor fix above in place, 823 of 5,554 sites reach the
    fallback, split:

      * 524 in a `.hxx`, a member OCCT defines inside the class body rather than out of line, which
        is how the `NCollection_*` templates and much of `math_*` are written. The fix does not reach
        these and no regex of this shape can: there is no `Class::` to find.
      * 281 in a `.cxx` or `.pxx` and 18 in a `.lxx`, a raise inside a file-static helper, a free
        function or a lambda, which has no member to belong to.

    `derive`'s docstring used to name only the second, which understated it. The count that matters
    is the one `format_table` prints, and the consumer that can be biased by it is channel two: it
    reads this column for accessor names, so an unattributed `StdFail_NotDone` site drops out of its
    population. Measured, that costs it nothing today, because every out-of-line `StdFail_NotDone`
    site this scan cannot attribute is in a constructor body rather than on an accessor, and a
    constructor is not something the bridge reads a result through.
    """
    best = None
    for start, end, member in spans:
        if start <= offset <= end and (best is None or start > best[0]):
            best = (start, member)
    return best[1] if best else fallback


def file_sites(ext, raw):
    """[(kind, exception, member)] for one OCCT source file, and the class declarations it makes.

    Factored out of `derive` so the self-test can drive the real scan rather than a restatement of
    it. That is not tidiness: a removal matrix found the comment-stripping and preprocessor-skip
    rules decorative precisely because the fixtures reimplemented this loop and so could not notice
    the rule being gone.
    """
    if ext in INLINE_EXTS:
        kinds = ("inline-raise", "inline-throw")
    elif ext in OUTOFLINE_EXTS:
        kinds = ("outofline-raise", "outofline-throw")
    else:
        return [], {}
    text = strip_comments(raw)
    bases = {}
    if ext in INLINE_EXTS:
        for decl in CLASS_DECL_RE.finditer(text):
            found = BASE_RE.findall(decl.group(2))
            if found:
                bases[decl.group(1)] = set(found)
    if "_Raise_if" not in raw and "throw " not in raw:
        return [], bases
    sites = []
    spans = None
    for regex, kind in ((RAISE_RE, kinds[0]), (THROW_RE, kinds[1])):
        for match in regex.finditer(text):
            line_start = text.rfind("\n", 0, match.start()) + 1
            if DIRECTIVE_RE.match(text[line_start:match.start() + 1]):
                continue  # the macro's own #define / #if, not a call of it
            if spans is None:
                spans = enclosing_members(text)
            sites.append((kind, match.group(1), member_at(spans, match.start())))
    return sites, bases


# The two facts #2331 measured by hand, one live and one dead, from two different files by two
# different code paths through this scan. They are the parser canary
# okf/policies/static-gates.md asks for: it must match, and coming back empty aborts the run.
CANARIES = (("gp_Dir", "inline-raise", "#2331's measured live check"),
            ("Geom_Direction", "outofline-raise", "#2331's measured dead check"))


def canary_problems(table):
    """Whatever is wrong with a derived or committed map that makes it not a map of an OCCT tree.

    **This replaced a floor on the walked file count**, `if files < 5000: sys.exit(...)`, and the
    reason is okf/policies/static-gates.md's rule after #2833: prefer an agreement floor and a canary
    to a magic number, and where a magic number is unavoidable, name the legitimate change that would
    cross it. Measured against the `v4.0.0-kernel.2` tree, the walk sees 14,671 files (7,085 `.hxx`,
    6,333 `.cxx`, 865 `.pxx`, 388 `.lxx`), so the floor sat at 34% of the population and could not
    answer either question a floor is for. Nothing plausible crosses it from above: OCCT grows across
    versions, no carried patch deletes files, and even a restructure that moved every header out of
    `src/` the way OCCT's generated `inc/` already holds them would leave 7,198. Nothing near it
    discriminates either: a tree of 5,001 files is not the pinned tree and passed, while a tree of
    4,999 is not meaningfully worse and failed, with a message blaming the tree rather than naming
    what was missing.

    What the floor was actually catching is `--occt-src` pointed at something that is not an OCCT
    source tree, which lands at 0 files, and these two assertions catch that with a message that says
    which fact was absent. A version bump that really did move `gp_Dir`'s check out of line would
    abort too, and correctly: that is the news this map exists to carry, not a parser fault.

    The population-size question belongs to the consumer and is already there:
    `assert_view_is_plausible` refuses to *report* from a map holding under 500 classes or under 100
    packages, which is the check on a thin tree, run where a thin map would do damage rather than
    where it is written. `--reverify-table` is the agreement half, re-deriving and diffing against the
    committed copy.
    """
    out = []
    for cls, kind, what in CANARIES:
        if kind not in table.get(cls, {}):
            out.append("%s has no %s row, so the map cannot be of an OCCT tree: it is %s"
                       % (cls, kind, what))
    return out


def derive(occt_src):
    """({class: {kind: (exceptions, members, count)}}, packages) over OCCT's raises and throws.

    The class is the file stem, which OCCT's one-class-per-file convention makes reliable and which
    a `Class::Member` scan is not: what is being recorded is where the code was compiled, and every
    site in a translation unit was compiled with that unit's flags whichever function it sits in.
    The *member* column is the one a `Class::Member` scan owns, and where it cannot name a member the
    column says `<file-scope>` rather than borrowing the class name; see `member_at`.

    `packages` is every `Foo` of a `Foo_Bar` file the walk examined, and it is what lets the census
    tell "this class has no validity check" from "this name is not a class I looked at". Without it
    the two are the same absence, and the first was assumed eight times in a hand-written whitelist
    before the plausibility check rejected it: `gp_Vec`, `gp_XY`, `gp_XYZ`, `gp_Trsf`, `gp_Trsf2d`,
    `gp_GTrsf`, `gp_Lin2d` and `gp_Vec2d` all raise, and were all assumed inert.
    """
    table = {}
    packages = set()
    bases = {}
    files = 0
    for root, _dirs, names in os.walk(os.path.join(occt_src, "src")):
        for name in sorted(names):
            stem, ext = os.path.splitext(name)
            if ext not in INLINE_EXTS + OUTOFLINE_EXTS:
                continue
            path = os.path.join(root, name)
            try:
                raw = open(path, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            files += 1
            if "_" in stem:
                packages.add(stem.split("_", 1)[0])
            sites, file_bases = file_sites(ext, raw)
            for cls, found in file_bases.items():
                bases.setdefault(cls, set()).update(found)
            for kind, exception, member in sites:
                entry = table.setdefault(stem, {})
                excs, members, count = entry.get(kind, (set(), set(), 0))
                excs.add(exception)
                members.add(member)
                entry[kind] = (excs, members, count + 1)
    problems = canary_problems(table)
    if problems:
        sys.exit("census-compiled-out-validation: walked %d source file(s) under %s and the result "
                 "is not an OCCT raise map:\n  %s\nPoint --occt-src at an OCCT *source* tree; an "
                 "install tree has no src/ and its headers are in include/opencascade."
                 % (files, occt_src, "\n  ".join(problems)))
    derive_delegated(occt_src, table)
    derive_inherited(table, bases)
    derive_dead_at_depth(occt_src, table)
    return table, packages


# How many packages a dead-at-depth row names before it stops naming them. The column is colour
# rather than payload (the payload is the unit count), and NCollection_Array1 is named by 273
# packages, which is a row no reader reads. The truncation is written into the data as a
# `+N-more` token rather than left to this comment, because a silently truncated list is the kind
# of number this repo has been wrong about before.
DEAD_AT_DEPTH_PACKAGES = 8


def outofline_sources(occt_src):
    """(stem, raw) for every OCCT out-of-line source file under a tree.

    The two derivations below take this as a parameter so their self-test cases drive the real
    loop rather than a restatement of it, which is the rule `file_sites` records above: a removal
    matrix found this script's comment-stripping decorative precisely because a fixture that
    reimplements the loop cannot notice a rule going missing.
    """
    for root, _dirs, names in os.walk(os.path.join(occt_src, "src")):
        for name in sorted(names):
            stem, ext = os.path.splitext(name)
            if ext not in OUTOFLINE_EXTS:
                continue
            try:
                yield stem, open(os.path.join(root, name), encoding="utf-8",
                                 errors="replace").read()
            except OSError:
                continue


def derive_dead_at_depth(occt_src, table, sources=None):
    """Record, per inline-checked class, how many OCCT out-of-line units compile that check dead.

    This is #2858's first item, and the thing it corrects is the map's single most misleading
    statement. `inline-raise` is described as "live", and the qualifier that matters is in the
    second clause: live **in whichever unit expands it**. An OCCT `.cxx` that names the class
    expands the same header with `No_Exception` defined, so on that path the check is gone. The
    classes carrying the most inline sites are exactly the ones OCCT's own code uses constantly,
    `NCollection` 135 sites and `math` 128, and both of the P1s the #2801 sweep read as protected
    fault inside one: #2840 in `NCollection_Sequence::Value` and #2855 in
    `NCollection_Array1::SetValue`, each expanded inside somebody else's `.cxx`.

    The count is **out-of-line translation units that name the class**, which is an upper bound on
    the call sites and a lower bound on nothing: a unit that names the class may not call a guarded
    member, and a unit that reaches it through a typedef (`TColgp_Array1OfPnt`) does call one and is
    not counted. Both directions are disclosed here and in the map header; what the number is for is
    telling a reader that a class is reached at depth constantly rather than never, and no
    tighter derivation changes that answer. The class's own `.cxx` counts, because the check is
    equally dead there.
    """
    inline_checked = sorted(cls for cls, entry in table.items() if "inline-raise" in entry)
    if not inline_checked:
        return
    pattern = re.compile(r"\b(" + "|".join(re.escape(c) for c in inline_checked) + r")\b")
    units = {}
    for stem, raw in (outofline_sources(occt_src) if sources is None else sources):
        package = stem.split("_", 1)[0] if "_" in stem else stem
        for match in pattern.finditer(strip_comments(raw)):
            seen = units.setdefault(match.group(1), {})
            seen.setdefault(package, set()).add(stem)
    for cls, by_package in units.items():
        total = sum(len(stems) for stems in by_package.values())
        ranked = sorted(by_package, key=lambda p: (-len(by_package[p]), p))
        shown = ranked[:DEAD_AT_DEPTH_PACKAGES]
        if len(ranked) > DEAD_AT_DEPTH_PACKAGES:
            shown.append("+%d-more" % (len(ranked) - DEAD_AT_DEPTH_PACKAGES))
        table[cls]["inline-dead-at-depth"] = (table[cls]["inline-raise"][0], set(shown), total)


def derive_inherited(table, bases):
    """Record a class that inherits a live throw from a base, so the census does not call it inert.

    `BRepPrimAPI_MakeBox` holds no throw of its own and one `outofline-delegated` `gp_Dir`, so
    class-locally it reads as compiled out. `BRepBuilderAPI_Command::Check`, four bases up, holds a
    literal `throw StdFail_NotDone`, which no macro gates. Without this the census reported a try
    around `BRepPrimAPI_MakeBox` as unjustified, which is the opposite of the truth.
    """
    def live_base(cls, seen):
        if cls in seen:
            return None
        seen.add(cls)
        for base in sorted(bases.get(cls, ())):
            entry = table.get(base, {})
            if {"inline-raise", "inline-throw", "outofline-throw"} & set(entry):
                return base
            deeper = live_base(base, seen)
            if deeper:
                return deeper
        return None

    for cls in sorted(bases):
        entry = table.get(cls, {})
        if {"inline-raise", "inline-throw", "outofline-throw"} & set(entry):
            continue  # already live on its own account
        source = live_base(cls, set())
        if source:
            excs = set()
            for kind in ("inline-raise", "inline-throw", "outofline-throw"):
                if kind in table[source]:
                    excs |= table[source][kind][0]
            table.setdefault(cls, {})["inherited-live"] = (excs, {source}, 1)


def derive_delegated(occt_src, table):
    """Record which classes build an inline-checked class from inside their own out-of-line code.

    This is the case the counts alone hide, and it is the one `CLAUDE.md` had wrong. `gp_Ax2` and
    `gp_Ax3` document "Raises ConstructionError if theN and theVx are parallel" and hold no
    `_Raise_if` of their own: `gp_Ax2.cxx` builds a `gp_Dir` from a cross product, and `gp_Dir`'s
    check is inline. Inline means live in the translation unit that expands it, and the unit
    expanding it here is `gp_Ax2.cxx`, compiled with `No_Exception`. So the documented exception
    cannot be thrown, and a bridge `try` around `gp_Ax2(P, N, Vx)` catches nothing.
    """
    inline_checked = sorted(cls for cls, entry in table.items() if "inline-raise" in entry)
    if not inline_checked:
        return
    pattern = re.compile(r"\b(" + "|".join(re.escape(c) for c in inline_checked) + r")\s*\(")
    for root, _dirs, names in os.walk(os.path.join(occt_src, "src")):
        for name in sorted(names):
            stem, ext = os.path.splitext(name)
            if ext not in OUTOFLINE_EXTS:
                continue
            try:
                raw = open(os.path.join(root, name), encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            hits = {}
            for match in pattern.finditer(strip_comments(raw)):
                delegate = match.group(1)
                if delegate == stem:
                    continue  # its own constructor, already counted as the class's own check
                hits[delegate] = hits.get(delegate, 0) + 1
            if not hits:
                continue
            excs = set()
            for delegate in hits:
                excs |= table[delegate]["inline-raise"][0]
            entry = table.setdefault(stem, {})
            old_excs, old_members, old_count = entry.get("outofline-delegated",
                                                         (set(), set(), 0))
            entry["outofline-delegated"] = (old_excs | excs, old_members | set(hits),
                                            old_count + sum(hits.values()))


def format_table(derived, provenance=()):
    lines = [
        "# OCCT raise-site map, derived by Scripts/census-compiled-out-validation.py "
        "--write-table.",
        "# One row per OCCT class per kind of site: <class> <kind> <count> <exceptions> <members>.",
        "#",
        "# kind is where the site was compiled, which decides whether the bridge sees it:",
        "#   outofline-raise  an <Exception>_Raise_if in a .cxx or .pxx. COMPILED OUT: the kernel is",
        "#                    built Release, which defines No_Exception, which empties the macro.",
        "#   inline-raise     an <Exception>_Raise_if in a .hxx or .lxx. Live in the bridge's own",
        "#                    translation unit, and only there: an OCCT unit that expands the same",
        "#                    header compiled it with No_Exception too.",
        "#   outofline-throw  a literal `throw Exception(...)` in a .cxx or .pxx. Always live; no",
        "#   inline-throw     macro gates a throw statement.",
        "#   outofline-delegated  the class has no check of its own and builds an inline-checked",
        "#                    class from inside its own .cxx, so the check it documents is expanded",
        "#                    with No_Exception on and is COMPILED OUT. gp_Ax2 via gp_Dir is the",
        "#                    case; the members column names the classes delegated to.",
        "#   inherited-live   a transitive base class holds a live site, so a bridge call through",
        "#                    this class can still throw. The members column names that base.",
        "#   inline-dead-at-depth  the count of OCCT out-of-line translation units that NAME an",
        "#                    inline-checked class, and so expand its inline check with",
        "#                    No_Exception defined. Every one of them is a path on which that",
        "#                    check is COMPILED OUT, which is the qualifier inline-raise's word",
        "#                    \"live\" leaves out: live in whichever unit expands it, and the",
        "#                    bridge is that unit only when the bridge is the immediate caller.",
        "#                    The members column names the OCCT packages doing the naming, the",
        "#                    top few by unit count, with a +N-more token where it is cut. An",
        "#                    upper bound on call sites (naming is not calling) and blind to a",
        "#                    typedef (TColgp_Array1OfPnt never spells NCollection_Array1).",
        "#",
        "# A class the walk examined and found no site of any kind gets no row. The packages line",
        "# below is what separates that from a name the walk never saw, which is uncertainty rather",
        "# than inertness.",
        "#",
        "# A members column reading <file-scope> is this scan declining to name a member, not a",
        "# member called that: the site sits in a file-static helper, a free function, or a member",
        "# OCCT defines inside the class body rather than as `Class::Member`, which is how the",
        "# NCollection_ templates are written. Channel two reads this column for accessor names, so",
        "# a StdFail_NotDone site recorded <file-scope> is outside its population; the count below",
        "# is how much of the map that covers.",
        "#",
        "# The members column is also ACCESS-BLIND: it names a private member no caller can reach",
        "# as readily as a public one. GeomAdaptor_Curve::LocalContinuity and its 2D twin are",
        "# private (GeomAdaptor_Curve.hxx:273, Geom2dAdaptor_Curve.hxx:251) and are in the column",
        "# anyway, so any channel reading it will keep proposing them (#2858).",
        "#",
        "# Regenerate after an OCCT version bump or a carried patch that touches a raise site, and",
        "# check the totals below moved the way the change predicts.",
    ]
    # The provenance stamp (#2885). Empty only where a caller formats a table for its own
    # inspection; --write-table and --reverify-table both pass one, so the committed copy always
    # carries it and check-inventory-prose.py fails when it disagrees with Scripts/patches/.
    lines.extend(provenance)
    table, packages = derived
    totals = {kind: 0 for kind in KINDS}
    classes = {kind: 0 for kind in KINDS}
    for entry in table.values():
        for kind, (_excs, _members, count) in entry.items():
            totals[kind] += count
            classes[kind] += 1
    lines.append("#")
    for kind in KINDS:
        lines.append("# totals: %-16s %5d site(s) in %4d class(es)"
                     % (kind, totals[kind], classes[kind]))
    rows = sum(len(entry) for entry in table.values())
    unattributed = sum(1 for entry in table.values() for _kind, (_e, members, _c) in entry.items()
                       if UNATTRIBUTED in members)
    only = sum(1 for entry in table.values() for _kind, (_e, members, _c) in entry.items()
               if members == {UNATTRIBUTED})
    lines.append("#")
    lines.append("# member attribution: %d of %d row(s) carry at least one <file-scope> site, %d "
                 "name no member at all" % (unattributed, rows, only))
    lines.append("#")
    lines.append("# packages examined: %d" % len(packages))
    for i in range(0, len(sorted(packages)), 12):
        lines.append("# packages: %s" % ",".join(sorted(packages)[i:i + 12]))
    lines.append("")
    for cls in sorted(table):
        for kind in KINDS:
            if kind not in table[cls]:
                continue
            excs, members, count = table[cls][kind]
            lines.append("%s %s %d %s %s" % (cls, kind, count, ",".join(sorted(excs)),
                                             ",".join(sorted(members))))
    return "\n".join(lines) + "\n"


def parse_table(path=TABLE):
    """({class: {kind: ...}}, packages) from the committed map."""
    table = {}
    packages = set()
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line.startswith("# packages:"):
            packages.update(line.split(":", 1)[1].strip().split(","))
            continue
        if not line or line.startswith("#"):
            continue
        parts = line.split(" ")
        if len(parts) < 4:
            sys.exit("census-compiled-out-validation: malformed row in %s: %r" % (path, line))
        cls, kind, count = parts[0], parts[1], int(parts[2])
        excs = set(parts[3].split(",")) if parts[3] else set()
        members = set(parts[4].split(",")) if len(parts) > 4 and parts[4] else set()
        if kind not in KINDS:
            sys.exit("census-compiled-out-validation: unknown kind %r in %s" % (kind, path))
        table.setdefault(cls, {})[kind] = (excs, members, count)
    return table, packages


# ---------------------------------------------------------------------------
# half two: the census over the bridge
# ---------------------------------------------------------------------------

OCCT_CLASS_RE = re.compile(r"\b([A-Z][A-Za-z0-9]*_[A-Za-z0-9_]+)\b")

# Names `OCCT_CLASS_RE` produces that are not an OCCT class, so `classes_named` must not hand them to
# `classify_class`, where an unrecognised name becomes `unexamined` and downgrades a verdict to
# `mixed`. **Nothing here is a judgement about whether a type can throw**; that judgement is the
# map's, never this list's, which is why each entry below says what it is instead of a class and not
# whether it is inert. `OCCT_CLASS_RE` is above it because both halves of the rationale are about its
# shape: a name it yields must start with an uppercase letter and contain an underscore, so a
# lowercase or underscore-free spelling never reaches here and does not belong on this list.
#
#   OCCT\w*                our own exported C bridge surface, which is `OCCT`-prefixed by
#                          convention: `OCCTShapeRef`, and the `OCCTBridge_<Domain>_h` include
#                          guards. 22 of the 26 names this list excludes from the bridge today.
#   Standard_Real          each of these is a `typedef` in `Standard_TypeDef.hxx`, not a class: no
#   Standard_Integer       file of that stem exists, so the map has no row for it and it would read
#   Standard_Boolean       as `unexamined` forever. `Standard_Address` is `void*`,
#   Standard_CString       `Standard_CString` is `const char*`, `Standard_Size` is `size_t`.
#   Standard_Size          Measured over the bridge: `Standard_Real`, `Standard_Integer`,
#   Standard_ShortReal     `Standard_Boolean` and `Standard_ShortReal` are written; the other six
#   Standard_Character     are prophylactic, kept because a typedef the bridge starts using would
#   Standard_ExtCharacter  otherwise silently turn a verdict into `mixed` with no defect anywhere.
#   Standard_Address
#   Standard_Byte
#   NS_\w+                 Objective-C and Core Foundation annotation macros, `NS_ASSUME_NONNULL_
#   CF\w+                  BEGIN` and `CF_RETURNS_RETAINED`, which take the class shape and are
#                          neither a class nor ours. Prophylactic: the bridge writes none today.
#
# **Measured over the population that consults this list, not one entry fires**, which is a fact
# about the list rather than a reason to shorten it. `classes_named` is called on try-block text only,
# so the numbers to look at are: 253 distinct class-shaped names inside the try blocks of the
# vocabulary population, none of them excluded here; 1,114 inside every try block, of which four are
# (`Standard_Real`, `Standard_Integer`, `Standard_Boolean`, `Standard_ShortReal`); and the 22
# `OCCT`-prefixed names in the bridge are all `OCCTBridge_<Domain>_h` include guards, which sit at
# file scope where no try block can reach them. So the entries are a list of spellings held against a
# bridge that has not written them yet, and the self-test covers the mechanism with a fixture rather
# than one case per entry, because nothing in the tree would make such a case fail on removal.
#
# `Handle` and `occt\w+` were here and are gone, and they are the other kind of dead: not "the tree
# does not write it yet" but "this can never match". `OCCT_CLASS_RE` requires an underscore, which
# bare `Handle` has none of, and an initial uppercase letter, which our lowercase internal helpers
# (`occtShapeIsPresent`) do not have. An entry that cannot fire reads as a decision somebody took and
# is not one.
#
# `Standard_Type` was here too, and it is a real OCCT class the map holds an `inherited-live` row
# for. Excluding it was the one judgement about throwing this list is not allowed to make, and it had
# a direction: it suppressed a live second justification and so biased a block towards `fabricated`.
# Its single bridge mention, `Handle(Standard_Type)` in `OCCTBridge_IO_Diagnostics.mm`, is outside
# the vocabulary population, so removing it moves no verdict; it is removed because the contract
# above says so, not because it was costing anything.
NOT_OCCT_RE = re.compile(r"^(?:OCCT\w*|Standard_Real|Standard_Integer|"
                         r"Standard_Boolean|Standard_CString|Standard_Size|Standard_ShortReal|"
                         r"Standard_Character|Standard_ExtCharacter|Standard_Address|"
                         r"Standard_Byte|NS_\w+|CF\w+)$")

# The per-class verdicts that count as a second justification for a catch. `inert` and `unexamined`
# are both an absence of rows, and keeping those two apart is the point: the first is a measurement,
# the second is not knowing.
LIVE = ("live-inline", "live-throw", "live-inherited")

VERDICTS = ("fabricated", "mixed", "live-inline", "live-throw")


def classify_class(cls, table, packages):
    """What a bridge-side mention of an OCCT class can actually raise in this build.

    Class-level, not member-level, and the approximation is one-directional: a class with an inline
    check on any member reads as `live-inline` even where the member the bridge calls has its check
    in the .cxx. That biases towards "protected", which is the right direction for a census whose
    findings cost a reader's time, and it means a clean channel-one run is weaker evidence than a
    finding. The map carries the member names per kind, so sharpening this is a matter of resolving
    which member a call site names rather than of deriving anything new.
    """
    entry = table.get(cls)
    if not entry:
        package = cls.split("_", 1)[0]
        return "inert" if package in packages else "unexamined"
    if "inline-raise" in entry:
        return "live-inline"      # the bridge's own unit expands it, so it fires
    if "inline-throw" in entry or "outofline-throw" in entry:
        return "live-throw"       # a literal throw, which no macro gates
    if "inherited-live" in entry:
        return "live-inherited"   # a base class throws, and the bridge calls it through this one
    return "compiled-out"         # outofline-raise and/or outofline-delegated only


def classes_named(fragment):
    """OCCT class names a fragment of bridge source names, ignoring our own and C's spellings."""
    found = set()
    for match in OCCT_CLASS_RE.finditer(fragment):
        name = match.group(1)
        if NOT_OCCT_RE.match(name):
            continue
        found.add(name)
    return found


VOCABULARY_RE = re.compile(
    r"\b(" + "|".join(THROWING.THROWING_TYPES) + r"|(?:"
    + "|".join(THROWING.THROWING_PREFIXES) + r")\w+)\b\s*(?:\w+\s*)?\(")


def vocabulary_sites(body):
    """Offsets of every construction of check-throwing-calls' vocabulary, with the class named.

    That vocabulary is exactly "OCCT validating caller-supplied numbers": the gp_ direction and
    axis family, Geom_Direction, the GeomEval_ packages and Standard_GUID, each of which earned its
    place in #345's audit of sites that actually threw. The list is imported rather than restated,
    so the one thing that must not drift between that gate and this census does not.

    The argument scan is this script's own, and deliberately. `check-throwing-calls.py`'s regex
    takes everything up to the next `;`, which for `gp_Ax2 a(gp_Pnt(...), gp_Dir(x, y, z))` swallows
    the inner `gp_Dir`. That is harmless to a gate that only needs to flag the statement once, and
    wrong here, where the verdict is per class: the first version of this census reported
    `OCCTShapeCreateBoxOriented` as unprotected when the very same statement builds a `gp_Dir` whose
    check is live.
    """
    sites = []
    for match in VOCABULARY_RE.finditer(body):
        open_paren = body.index("(", match.end() - 1)
        depth = 0
        close = len(body)
        for i in range(open_paren, len(body)):
            if body[i] == "(":
                depth += 1
            elif body[i] == ")":
                depth -= 1
                if depth == 0:
                    close = i
                    break
        args = body[open_paren + 1:close]
        if THROWING.NUMERIC_ARG_RE.match(args):
            continue  # literal construction: nothing a caller can trip, so nothing to protect
        sites.append((match.start(), match.group(1), args.strip()))
    return sites


def census(table, packages, src=SRC, paths=None, text_by_path=None):
    """Per-try-block findings over the bridge, plus the counts the rate is quoted from."""
    findings = []
    counts = {v: 0 for v in VERDICTS}
    counts["try-blocks"] = 0
    counts["try-blocks-with-vocabulary"] = 0
    paths = sorted(glob.glob(os.path.join(src, "*.mm"))) if paths is None else paths
    for path in paths:
        text = (text_by_path or {}).get(path)
        if text is None:
            text = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, REPO) if os.path.isabs(path) else path
        for func, start, raw_body in THROWING.function_bodies(text):
            body = THROWING.strip_noise(raw_body)
            for span_start, span_end in THROWING.try_spans(body):
                counts["try-blocks"] += 1
                block = body[span_start:span_end + 1]
                sites = [s for s in vocabulary_sites(body)
                         if span_start <= s[0] <= span_end]
                if not sites:
                    continue
                counts["try-blocks-with-vocabulary"] += 1
                named = {cls for _off, cls, _args in sites}
                verdicts = {classify_class(cls, table, packages) for cls in named}
                others = {c for c in classes_named(block) if c not in named}
                other_live = sorted(c for c in others
                                    if classify_class(c, table, packages) in LIVE)
                other_unknown = sorted(c for c in others
                                       if classify_class(c, table, packages) == "unexamined")
                if "live-inline" in verdicts:
                    verdict = "live-inline"
                elif {"live-throw", "live-inherited"} & verdicts:
                    verdict = "live-throw"
                elif other_live or other_unknown:
                    verdict = "mixed"
                else:
                    verdict = "fabricated"
                counts[verdict] += 1
                line = text[:start + span_start].count("\n") + 1
                findings.append({
                    "file": rel, "line": line, "function": func, "verdict": verdict,
                    "sites": sorted("%s[%s]" % (cls, classify_class(cls, table, packages))
                                    for cls in named),
                    "other_live": other_live, "other_unknown": other_unknown,
                })
    return findings, counts


# Channel two. An accessor guarded only by `StdFail_NotDone_Raise_if` is the largest single class of
# compiled-out check in the kernel: 122 of the 828 out-of-line sites against 30 inline ones. The
# documented contract is "Value() throws if the construction failed", and with the macro empty it
# returns whatever the object holds, which for a failed OCCT algorithm is a default-constructed
# null. That is #726's unmeasured value arriving through #2801's mechanism, and unlike channel one
# it does not need a try block to be a defect: the caller's own IsDone test is the whole protection.
NOTDONE_EXC = "StdFail_NotDone"

# Calls on the same object that settle the question the dead check would have. `IsDone` and, for the
# GC_/gce_ families, `Status() != gce_Done`, which `GC_Root::IsDone` is defined as.
EXPLICIT_GUARD_RE = r"\s*(?:\.|->)\s*(?:IsDone|Status)\s*\("
# Calls that may settle it and may not. `GeomAPI_ProjectPointOnSurf::NbPoints` returns 0 when the
# projection is not done, so testing it is as good as IsDone; that is a fact about that class's
# source, not about the spelling, so these are reported for a reading rather than cleared.
COUNT_GUARD_RE = r"\s*(?:\.|->)\s*(?:Nb\w+|IsEmpty|Extrema)\s*\("

GUARDS = ("explicit", "count", "none")


def notdone_classes(table):
    """{class: members} whose StdFail_NotDone guard sits in a .cxx and is therefore compiled out."""
    out = {}
    for cls, entry in table.items():
        if "outofline-raise" not in entry:
            continue
        excs, members, _count = entry["outofline-raise"]
        if NOTDONE_EXC in excs:
            out[cls] = members
    return out


def notdone_census(table, src=SRC, paths=None, text_by_path=None):
    """Bridge locals of such a class, and whether the bridge tests the state OCCT no longer will."""
    findings = []
    counts = {g: 0 for g in GUARDS}
    classes = notdone_classes(table)
    if not classes:
        return findings, counts
    pattern = re.compile(r"\b(" + "|".join(re.escape(c) for c in sorted(classes))
                         + r")\s+(\w+)\s*\(")
    paths = sorted(glob.glob(os.path.join(src, "*.mm"))) if paths is None else paths
    for path in paths:
        text = (text_by_path or {}).get(path)
        if text is None:
            text = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, REPO) if os.path.isabs(path) else path
        for func, start, raw_body in THROWING.function_bodies(text):
            body = THROWING.strip_noise(raw_body)
            for match in pattern.finditer(body):
                cls, var = match.group(1), match.group(2)
                reached = sorted(m for m in classes[cls]
                                 if re.search(r"\b" + re.escape(var) + r"\s*(?:\.|->)\s*"
                                              + re.escape(m) + r"\s*\(", body))
                if not reached:
                    continue  # constructed but never read through a compiled-out accessor
                if re.search(r"\b" + re.escape(var) + EXPLICIT_GUARD_RE, body):
                    guard = "explicit"
                elif re.search(r"\b" + re.escape(var) + COUNT_GUARD_RE, body):
                    guard = "count"
                else:
                    guard = "none"
                counts[guard] += 1
                findings.append({
                    "file": rel, "line": text[:start + match.start()].count("\n") + 1,
                    "function": func, "class": cls, "variable": var, "members": reached,
                    "guard": guard,
                })
    return findings, counts


# Channel three (#2858). Channel two's population is `StdFail_NotDone` and nothing else, which is
# 1 of the 28 exception kinds among the map's 828 out-of-line sites and 122 of its 284 classes. The
# three defects the #2801 sweep proved all sat in the part no channel read: #2856 and #2857 are
# `Standard_OutOfRange`, #2855 is `Standard_RangeError`. This channel is the same question asked of
# the index-and-dimension family: the bridge hands a caller-controlled number to a member whose
# only bound test was one of these macros, so with the macro empty the number is used unchecked.
#
# It is a different shape from channel two's and not a generalisation of its code. Channel two asks
# "was the construction done", a question about one object's state that `IsDone()` answers. This one
# asks "is this index inside this object's bounds", which is answered by comparing the index against
# a bound the object reports, so the guard it looks for is a comparison rather than a call.
INDEX_EXCS = ("Standard_DimensionError", "Standard_DimensionMismatch", "Standard_OutOfRange",
              "Standard_OutOfRange_Always", "Standard_RangeError")

# A bound the object reports about itself. Copied from the predicates OCCT's own out-of-line
# `_Raise_if` lines test, which is where the guard has to come from: `Index < 1 || Index >
# NbPoles()` (`Geom2d_BezierCurve.cxx:609`), `theRow < LowerRow() || theRow > UpperRow()`
# (`math_Matrix`), `Index > Length()` (`NCollection_Sequence`).
BOUND_ACCESSOR_RE = re.compile(r"\b(?:Nb\w+|Upper\w*|Lower\w*|Length|Size|Extent|Degree|"
                               r"RowNumber|ColNumber|NbRows|NbColumns)\s*\(")
COMPARISON_RE = re.compile(r"<=?|>=?|==|!=")
INT_LITERAL_RE = re.compile(r"(?<![\w.])\d+(?![\w.])")
CONDITION_HEAD_RE = re.compile(r"\b(?:if|while)\s*\(")
AUTO_DECL_RE = re.compile(r"\bauto\s*[*&]?\s*(\w+)\s*=\s*([^;]*);")

# `bound` is the guard PR #2870 wrote at ten sites; `literal-only` tests the index against a
# constant and not against the object, which catches `index < 1` and misses every overrun; `none`
# is the shape #2859 and #2861 shipped with.
INDEX_GUARDS = ("bound", "literal-only", "none")


def index_classes(table):
    """{class: members} whose out-of-line guard is an index-or-dimension raise, so it is gone.

    The members set is the map's, which aggregates every out-of-line raise on the class regardless
    of which exception each one carried: the map's row is per (class, kind), not per (class, kind,
    exception). So a class that raises `StdFail_NotDone` on `Value` and `Standard_OutOfRange` on
    `Pole` contributes both names here. That over-includes rather than under-includes, which is the
    direction a census should err in when its output is a list to read, and it is why this channel
    prints a guard column rather than a verdict.
    """
    out = {}
    for cls, entry in table.items():
        if "outofline-raise" not in entry:
            continue
        excs, members, _count = entry["outofline-raise"]
        if not set(excs) & set(INDEX_EXCS):
            continue
        named = {m for m in members if m != UNATTRIBUTED}
        if named:
            out[cls] = named
    return out


# An index or a dimension arrives as an integer by value. A pointer parameter is an out-parameter
# here, which is what `LowerDistanceParameters(u, v)` takes and what makes it not this channel's
# subject: nothing about it is a number OCCT was going to range-check. Without this filter the
# channel reported four such calls, all of them noise, and every one of them a member the map lists
# because its class ALSO raises StdFail_NotDone somewhere (see index_classes).
INDEX_PARAM_TYPE_RE = re.compile(r"^(?:const\s+)?(?:unsigned\s+|signed\s+)?"
                                 r"(?:int\d*_t|int|long|short|size_t|Standard_Integer|"
                                 r"Standard_Size)$")


def parameters_of(text, brace):
    """{name: type} for the parameters of the function whose body opens at `brace`.

    Written here rather than taken from `check-throwing-calls.py`, which yields bodies and not
    signatures. It walks back from the `(` matching the signature's `)` so a defaulted argument or
    a function-pointer parameter cannot truncate it.
    """
    close = text.rfind(")", 0, brace)
    if close < 0:
        return {}
    depth = 0
    open_paren = -1
    for i in range(close, -1, -1):
        if text[i] == ")":
            depth += 1
        elif text[i] == "(":
            depth -= 1
            if depth == 0:
                open_paren = i
                break
    if open_paren < 0:
        return {}
    params = {}
    depth = 0
    current = ""
    for ch in text[open_paren + 1:close] + ",":
        if ch in "(<[":
            depth += 1
        elif ch in ")>]":
            depth -= 1
        if ch == "," and depth == 0:
            found = re.findall(r"[A-Za-z_]\w*", current)
            if len(found) > 1 and "*" not in current and "&" not in current:
                params[found[-1]] = " ".join(found[:-1])
            current = ""
        else:
            current += ch
    return params


def index_parameters(params):
    """The subset of a bridge signature that can be an index or a dimension OCCT would check."""
    return {name for name, ty in params.items() if INDEX_PARAM_TYPE_RE.match(ty.strip())}


def typed_locals(body, classes, decl_re):
    """{variable: class} for every local the bridge declares of one of `classes`.

    Four spellings, all of which the bridge writes: `Handle(C) v`, `occ::handle<C> v`, `C v(...)`
    and `auto v = <anything naming C>`, the last being how #2870's own sites are written
    (`auto bezier = occ::handle<Geom2d_BezierCurve>::DownCast(c->curve);`). A census that knew only
    the first three would have been blind to the file the defect was in.
    """
    out = {}
    for match in AUTO_DECL_RE.finditer(body):
        for cls in classes:
            if re.search(r"\b" + re.escape(cls) + r"\b", match.group(2)):
                out.setdefault(match.group(1), cls)
                break
    for match in decl_re.finditer(body):
        cls = match.group(1) or match.group(2) or match.group(3)
        var = match.group(4)
        if var in ("const", "DownCast", "return"):
            continue
        out.setdefault(var, cls)
    return out


def paren_argument_text(body, open_paren):
    """The argument text of a call whose `(` sits at `open_paren`, nested parens included.

    `SetPole(index, gp_Pnt2d(x, y))` is why this is paren-matched rather than `[^)]*`: the naive
    form stopped at the inner `)` and the outer call's own index argument was never seen, which is
    the same defect `vocabulary_sites` records one screen up for channel one.
    """
    depth = 0
    for i in range(open_paren, len(body)):
        if body[i] == "(":
            depth += 1
        elif body[i] == ")":
            depth -= 1
            if depth == 0:
                return body[open_paren + 1:i]
    return body[open_paren + 1:]


def conditions(body):
    """The paren-matched text of every `if (...)` and `while (...)` condition in a body."""
    out = []
    for match in CONDITION_HEAD_RE.finditer(body):
        open_paren = body.index("(", match.end() - 1)
        depth = 0
        for i in range(open_paren, len(body)):
            if body[i] == "(":
                depth += 1
            elif body[i] == ")":
                depth -= 1
                if depth == 0:
                    out.append(body[open_paren:i + 1])
                    break
    return out


# A bound the function hoisted into a local before testing against it. `const int nbPoles =
# bz->NbPoles(); if (index < 1 || index > nbPoles || nbPoles <= 2)` is how six of the ten guards
# PR #2870 wrote are spelled, and reading only the condition text scored two of them
# `literal-only`: a false finding, and in the direction that matters most, since it would have sent
# a reader to re-guard a site that is already correct.
BOUND_LOCAL_RE = re.compile(r"\b(?:const\s+)?(?:auto|int\d*_t|int|unsigned|long|size_t|"
                            r"Standard_Integer|Standard_Size)\s+(\w+)\s*=\s*([^;]*);")


def bound_locals(body):
    """Local names initialised from a bound the object reports, so a test against one is a bound."""
    return {m.group(1) for m in BOUND_LOCAL_RE.finditer(body)
            if BOUND_ACCESSOR_RE.search(m.group(2))}


def index_guard_for(param, conds, bounds=()):
    """How well the function constrains `param` before handing it to OCCT."""
    verdict = "none"
    bound_re = (re.compile(r"\b(?:" + "|".join(re.escape(b) for b in sorted(bounds)) + r")\b")
                if bounds else None)
    for cond in conds:
        if not re.search(r"\b" + re.escape(param) + r"\b", cond):
            continue
        if not COMPARISON_RE.search(cond):
            continue
        if BOUND_ACCESSOR_RE.search(cond) or (bound_re and bound_re.search(cond)):
            return "bound"
        if INT_LITERAL_RE.search(cond):
            verdict = "literal-only"
    return verdict


def index_census(table, src=SRC, paths=None, text_by_path=None):
    """Caller-controlled indices handed to a member whose bound test this build compiled out.

    Returns (findings, counts). Each finding carries `asymmetric`, which is the signal #2858 asked
    to encode: another function in the SAME bridge file passes a caller value to the same member of
    the same class and does bound-check it. That within-file split found three of the #2801 sweep's
    defects, and it is a fact about the file rather than a judgement about the call.
    """
    findings = []
    counts = {g: 0 for g in INDEX_GUARDS}
    classes = index_classes(table)
    if not classes:
        return findings, counts
    alt = "|".join(re.escape(c) for c in sorted(classes))
    decl_re = re.compile(r"(?:Handle\s*\(\s*(%s)\s*\)|occ::handle\s*<\s*(%s)\s*>|\b(%s))"
                         r"\s*(?:const\s+)?[*&]?\s*(\w+)\s*[;=({,]" % (alt, alt, alt))
    member_alt = re.compile(r"\b(\w+)\s*(?:\.|->)\s*("
                            + "|".join(sorted({re.escape(m) for ms in classes.values()
                                               for m in ms})) + r")\s*\(")
    paths = sorted(glob.glob(os.path.join(src, "*.mm"))) if paths is None else paths
    for path in paths:
        text = (text_by_path or {}).get(path)
        if text is None:
            text = open(path, encoding="utf-8").read()
        rel = os.path.relpath(path, REPO) if os.path.isabs(path) else path
        per_file = []
        # Members of the same name that some OTHER function in this file bound-checks, whatever
        # class it called them on. This is the sibling half of the asymmetry signal and it has to
        # look outside the population: #2859's guarded side is `Geom2d_BSplineCurve::Pole`, whose
        # own check is a literal throw, so that class is not in `index_classes` at all and the
        # comparison the issue asked for cannot be made from the population alone.
        siblings = {}
        for func, start, raw_body in THROWING.function_bodies(text):
            body = THROWING.strip_noise(raw_body)
            params = index_parameters(parameters_of(text, start))
            if not params:
                continue
            conds = conditions(body)
            bounds = bound_locals(body)
            for match in member_alt.finditer(body):
                args = paren_argument_text(body, match.end() - 1)
                fed = [p for p in params if re.search(r"\b" + re.escape(p) + r"\b", args)]
                if not fed:
                    continue
                if max((index_guard_for(p, conds, bounds) for p in fed),
                       key=INDEX_GUARDS.index) == "bound":
                    siblings.setdefault(match.group(2), set()).add(func)
            locals_by_name = typed_locals(body, classes, decl_re)
            if not locals_by_name:
                continue
            for var, cls in sorted(locals_by_name.items()):
                for member in sorted(classes[cls]):
                    call = re.compile(r"\b" + re.escape(var) + r"\s*(?:\.|->)\s*"
                                      + re.escape(member) + r"\s*\(")
                    for match in call.finditer(body):
                        args = paren_argument_text(body, match.end() - 1)
                        fed = sorted(p for p in params
                                     if re.search(r"\b" + re.escape(p) + r"\b", args))
                        if not fed:
                            continue  # not a caller-controlled index: nothing for a guard to do
                        guard = max((index_guard_for(p, conds, bounds) for p in fed),
                                    key=INDEX_GUARDS.index)
                        counts[guard] += 1
                        per_file.append({
                            "file": rel,
                            "line": text[:start + match.start()].count("\n") + 1,
                            "function": func, "class": cls, "member": member,
                            "variable": var, "arguments": sorted(fed), "guard": guard,
                        })
        # Keyed on the MEMBER NAME within the file, not on (class, member), and that is the whole
        # signal. #2859 is `Geom2d_BSplineCurve::Pole` bound-checked in `OCCTCurve2DBSplineGetPole`
        # and `Geom2d_BezierCurve::Pole` not bound-checked in `OCCTCurve2DBezierGetPole`, one screen
        # apart in one file: same accessor name, same shape of input, different class. Keyed on the
        # class as well, the pair is two unrelated rows and the asymmetry is invisible.
        for f in per_file:
            others = sorted(siblings.get(f["member"], set()) - {f["function"]})
            f["asymmetric"] = others if f["guard"] != "bound" else []
        findings.extend(per_file)
    return findings, counts


# Channel four (#2858). The `#ifndef No_Exception` code regions, which are a different defect from
# every other population on this page: the dead region swallows the CONDITION VARIABLE and not only
# the raise, so the check's own answer is discarded and the next statement runs on data the kernel
# knows is wrong. `GeomFill_BSplineCurves.cxx:282` is the worked case (PR #2849): `bool IsOK =` sits
# inside the `#ifndef`, `Arrange`'s `false` goes nowhere, and `Init` dereferences the null handle
# `Arrange` never filled. A census keyed on `_Raise_if` sites cannot tell that apart from "check
# gone, data still valid", which is why this is a table rather than a derivation over the map.
#
# The population is small enough to commit literally, in the shape `derive-gdt-enums.py --verify`
# uses: `--verify-no-exception-regions` re-derives it from an OCCT tree and diffs.
NO_EXCEPTION_REGIONS = (
    # (file stem, what the region swallows, what is known about it)
    ("Convert_EllipseToBSplineCurve", "Tol, delta", "open, #2858"),
    ("Convert_SphereToBSplineSurface", "delta", "open, #2858"),
    ("Convert_TorusToBSplineSurface", "delta", "open, #2858"),
    ("GeomFill_BSplineCurves", "bool IsOK", "guarded bridge-side, PR #2849"),
    ("GeomFill_BezierCurves", "bool IsOK", "guarded bridge-side, PR #2849"),
    ("GeomFill_Profiler", "int n = NbKnots()", "open, #2858"),
)

NO_EXCEPTION_DIRECTIVE_RE = re.compile(
    r"^\s*#\s*if(n?def\s+No_Exception|\s+!?\s*defined\s*\(?\s*No_Exception)", re.MULTILINE)
# An assignment, which is what makes a region swallow rather than merely disappear. `=` that is
# part of `==`, `!=`, `<=`, `>=`, `+=` and friends is not one.
#
# Known limits, from review of #2887: a structured binding (`auto [x, y] = ...`), a range-for
# (`for (auto x : y)`) and a lambda init-capture (`[x = 1]{}`) would each read as an assignment or
# as none, and this does not distinguish them. It over-reports rather than under-reports, and the
# six regions it selects are a committed table that `--verify-no-exception-regions` re-checks, so a
# wrong selection shows up as a table row nobody can justify rather than as a silent miss. Worth
# revisiting if OCCT's `#ifndef No_Exception` regions ever stop being the C++03-shaped code they are
# in 8.0.1.
ASSIGNMENT_RE = re.compile(r"(?<![=!<>+\-*/%&|^])=(?!=)")


def no_exception_region_texts(raw):
    """The `#ifndef No_Exception` regions of one file that SWALLOW a value, as text.

    **Swallowing is derived, not listed.** Measured over the pinned tree, 24 out-of-line files hold
    such a region and 18 of them are inert for one of three reasons: 14 `#define No_Exception`
    themselves (the `HLRBRep`/`HLRAlgo` block, `ElSLib.cxx`, `Intrv_Intervals.cxx`), which changes
    nothing because the whole kernel already has it; two are diagnostics that print a message
    (`Draw_BasicCommands.cxx`, `IFSelect_ShareOutResult.cxx`); and two hold an extra check that
    throws rather than a value the surrounding code goes on to read
    (`NCollection_AccAllocator.cxx`, and in a comment `GCPnts_*Abscissa.cxx`). All three collapse
    to one mechanical test: with the directives and the comments dropped, does anything remain that
    ASSIGNS? A list of the eighteen names would have said the same thing today and would have gone
    stale silently.
    """
    lines = raw.splitlines()
    regions = []
    for match in NO_EXCEPTION_DIRECTIVE_RE.finditer(raw):
        first = raw[:match.start()].count("\n")
        depth = 0
        body = []
        for line in lines[first:]:
            stripped = line.strip()
            if stripped.startswith("#if"):
                depth += 1
                continue
            if stripped.startswith("#endif"):
                depth -= 1
                if depth <= 0:
                    break
                continue
            if (not stripped or stripped.startswith("#") or stripped.startswith("//")
                    or stripped.startswith("*") or stripped.startswith("/*")):
                continue
            body.append(stripped)
        text = " ".join(body)
        if text and ASSIGNMENT_RE.search(text):
            regions.append(text)
    return regions


def derive_no_exception_regions(occt_src, sources=None):
    """{file stem: [region text]} for the out-of-line files whose region swallows a value.

    Out-of-line only, and that is the whole point: a region in a `.hxx` is expanded with the
    bridge's own flags and so is live for us. A `.cxx` region is dead in the kernel binary.
    OCCT's `GTests/` fixtures are skipped: they write `#ifndef No_Exception` around an
    `EXPECT_THROW` deliberately, to assert both spellings, and no shipped library holds them.
    """
    found = {}
    for stem, raw in (outofline_sources(occt_src) if sources is None else sources):
        if stem.endswith("_Test") or "No_Exception" not in raw:
            continue
        regions = no_exception_region_texts(raw)
        if regions:
            found[stem] = regions
    return found


def no_exception_problems(occt_src):
    """Whatever the committed `#ifndef No_Exception` table gets wrong about an OCCT tree."""
    return no_exception_problems_for(derive_no_exception_regions(occt_src))


def no_exception_problems_for(derived):
    committed = {stem for stem, _swallowed, _status in NO_EXCEPTION_REGIONS}
    out = []
    for stem in sorted(set(derived) - committed):
        out.append("%s holds a #ifndef No_Exception region that swallows a value and the committed "
                   "table does not list it: %s" % (stem, derived[stem][0][:120]))
    for stem in sorted(committed - set(derived)):
        out.append("%s is in the committed table and swallows nothing in this tree; if the kernel "
                   "fixed it, drop the row and say so" % stem)
    for stem, swallowed, _status in NO_EXCEPTION_REGIONS:
        if stem in derived and not any(w.strip() in region for region in derived[stem]
                                       for w in swallowed.split(",")):
            out.append("%s swallows %r in this tree, and the committed row says %r"
                       % (stem, derived[stem][0][:80], swallowed))
    return out


def assert_view_is_plausible(table, packages, counts, paths):
    """Fail rather than report clean when the script is looking at the wrong thing.

    okf/policies/static-gates.md: a wrong answer is a bug, an answer about a population that was
    never examined is a lie. Each assertion below is about something this script reads and does not
    produce.
    """
    problems = []
    if len(table) < 500:
        problems.append("the map holds %d class(es); the pinned tree yields well over a thousand"
                        % len(table))
    problems.extend(canary_problems(table))  # one copy, shared with derive's own abort
    if len(packages) < 100:
        problems.append("the map names %d OCCT package(s); without them every absent class reads "
                        "as unexamined and no finding can be reached" % len(packages))
    for cls in ("gp", "Geom", "BRepBuilderAPI", "TopoDS", "ShapeFix"):
        if cls not in packages:
            problems.append("package %s is not in the map's package list, so the walk did not "
                            "cover the tree" % cls)
    for cls in THROWING.THROWING_TYPES:
        if classify_class(cls, table, packages) == "unexamined":
            problems.append("%s, which check-throwing-calls.py treats as a throwing type, is not "
                            "even in a package the map examined" % cls)
    dead_notdone = notdone_classes(table)
    if len(dead_notdone) < 50:
        problems.append("the map records only %d class(es) whose StdFail_NotDone guard is "
                        "out-of-line; the pinned tree has over sixty" % len(dead_notdone))
    if "GeomAPI_ProjectPointOnSurf" not in dead_notdone:
        problems.append("GeomAPI_ProjectPointOnSurf is not among the classes whose NotDone guard "
                        "is out-of-line, and its LowerDistance is one of the measured cases")
    # Channel three and the depth kind, each as a canary rather than a floor, per
    # okf/policies/static-gates.md's rule after #2833: name the measured fact whose absence means
    # the channel is reporting about a population it never examined.
    dead_index = index_classes(table)
    if "Geom2d_BezierCurve" not in dead_index:
        problems.append("Geom2d_BezierCurve, whose index guards #2859 measured as out-of-line "
                        "macros, is not among the classes channel three examines")
    if "Geom_BezierCurve" in dead_index:
        problems.append("Geom_BezierCurve is in channel three's population, and #2859 measured "
                        "every one of its index guards as a literal throw; the map is describing "
                        "some other tree")
    depth_rows = sum(1 for entry in table.values() if "inline-dead-at-depth" in entry)
    if "inline-dead-at-depth" not in table.get("NCollection_Array1", {}):
        problems.append("NCollection_Array1 carries no inline-dead-at-depth row, so either the "
                        "map predates that kind or the walk saw no OCCT source naming the class "
                        "OCCT's own code names most; regenerate with --write-table")
    elif depth_rows < 50:
        # 50 is half the measured 100 of 104. The threshold was 2 when this landed, which the
        # sentence below already contradicted: a map carrying two rows is not one that "yields one
        # for most" of them, and 2 would have passed a map that was almost entirely ungenerated.
        problems.append("only %d class(es) carry an inline-dead-at-depth row; the pinned tree "
                        "yields one for 100 of the 104 inline-checked classes" % depth_rows)
    if len(paths) < 50:
        problems.append("only %d bridge .mm file(s) found under %s" % (len(paths), SRC))
    if counts["try-blocks"] < 1000:
        problems.append("only %d try block(s) parsed out of the bridge; it holds thousands"
                        % counts["try-blocks"])
    return problems


def run(verbose=False):
    if not os.path.exists(TABLE):
        sys.exit("census-compiled-out-validation: %s is missing; regenerate it with --write-table "
                 "against Libraries/occt-src" % os.path.relpath(TABLE, REPO))
    table, packages = parse_table()
    paths = sorted(glob.glob(os.path.join(SRC, "*.mm")))
    findings, counts = census(table, packages, paths=paths)
    problems = assert_view_is_plausible(table, packages, counts, paths)
    if problems:
        print("census-compiled-out-validation: refusing to report, its own view is implausible:")
        for problem in problems:
            print("  %s" % problem)
        return 2
    population = counts["try-blocks-with-vocabulary"]
    print("census-compiled-out-validation: %d try block(s) in Sources/OCCTBridge/src, %d of them "
          "protecting a construction from the caller-values vocabulary"
          % (counts["try-blocks"], population))
    for verdict in VERDICTS:
        rate = (100.0 * counts[verdict] / population) if population else 0.0
        print("  %-12s %4d  %5.1f%% of the population" % (verdict, counts[verdict], rate))
    fabricated = [f for f in findings if f["verdict"] == "fabricated"]
    if fabricated:
        print("\nevery validity check the try block could be protecting against is compiled out of "
              "this build, or absent from OCCT altogether, and nothing else in the block can "
              "throw:")
        for f in fabricated:
            print("  %s:%d  %s  %s" % (f["file"], f["line"], f["function"], ",".join(f["sites"])))
    mixed = [f for f in findings if f["verdict"] == "mixed"]
    if mixed:
        print("\nthe vocabulary's own check is compiled out, but the try block names something "
              "else that can or might throw, so the catch is not necessarily fabricated:")
        for f in mixed:
            extra = (f["other_live"] + ["%s?" % c for c in f["other_unknown"]])[:4]
            print("  %s:%d  %s  %s  (also: %s)"
                  % (f["file"], f["line"], f["function"], ",".join(f["sites"]),
                     ",".join(extra) or "-"))
    if verbose:
        print("\nevery try block in the vocabulary population:")
        for f in findings:
            print("  %-12s %s:%d  %s  %s"
                  % (f["verdict"], f["file"], f["line"], f["function"], ",".join(f["sites"])))

    nd_findings, nd_counts = notdone_census(table, paths=paths)
    total_nd = sum(nd_counts.values())
    print("\ncensus-compiled-out-validation, channel two: %d bridge local(s) of a class whose "
          "StdFail_NotDone guard sits in a .cxx, read through an accessor that guard was protecting"
          % total_nd)
    for guard in GUARDS:
        rate = (100.0 * nd_counts[guard] / total_nd) if total_nd else 0.0
        print("  guard %-9s %4d  %5.1f%%" % (guard, nd_counts[guard], rate))
    nd_classes = notdone_classes(table)
    nameless = sorted(c for c, members in nd_classes.items() if members == {UNATTRIBUTED})
    print("  the edge of this population: %d of the %d class(es) whose NotDone guard is "
          "out-of-line have no accessor name in the map (<file-scope>, see member_at), so a bridge "
          "local of one cannot be reported here at all%s"
          % (len(nameless), len(nd_classes),
             ": " + ", ".join(nameless) if nameless else ""))
    for guard, heading in (
            ("none", "nothing in the bridge function tests the state the compiled-out check "
                     "tested, so a failed construction is read as a result:"),
            ("count", "guarded by a count accessor rather than by IsDone. Whether that is "
                      "equivalent is a fact about each OCCT class's own source, per "
                      "okf/policies/follow-occt-callers.md, so these are for a reading:")):
        rows = [f for f in nd_findings if f["guard"] == guard]
        if rows:
            print("\n%s" % heading)
            for f in rows:
                print("  %s:%d  %s  %s %s.%s()"
                      % (f["file"], f["line"], f["function"], f["class"], f["variable"],
                         "(), .".join(f["members"])))
    ix_findings, ix_counts = index_census(table, paths=paths)
    total_ix = sum(ix_counts.values())
    print("\ncensus-compiled-out-validation, channel three: %d bridge call(s) handing a "
          "caller-controlled index or dimension to a member whose only bound test is an "
          "out-of-line %s macro" % (total_ix, "/".join(e.split("_", 1)[1] for e in INDEX_EXCS)))
    for guard in INDEX_GUARDS:
        rate = (100.0 * ix_counts[guard] / total_ix) if total_ix else 0.0
        print("  guard %-13s %4d  %5.1f%%" % (guard, ix_counts[guard], rate))
    print("  the edge of this population: an index reaching OCCT through anything but an integer "
          "parameter passed by value, or through a local of a class the map has no row for, is "
          "outside it. A `TColStd_Array1OfReal` the bridge declares itself is deliberately outside "
          "too: the bridge's own unit expands NCollection_Array1's check, so there it is live.")
    for guard, heading in (
            ("none", "nothing in the bridge function bounds the index, so the caller's number "
                     "reaches an accessor whose own bound test this build removed:"),
            ("literal-only", "bounded against a constant and not against the object, which stops "
                             "a negative index and no overrun:")):
        rows = [f for f in ix_findings if f["guard"] == guard]
        if rows:
            print("\n%s" % heading)
            for f in rows:
                print("  %s:%d  %s  %s::%s(%s)%s"
                      % (f["file"], f["line"], f["function"], f["class"], f["member"],
                         ",".join(f["arguments"]),
                         ("  ASYMMETRIC: bounded in " + ", ".join(f["asymmetric"])
                          + " in this same file") if f["asymmetric"] else ""))

    print("\ncensus-compiled-out-validation, channel four: the %d OCCT out-of-line file(s) whose "
          "`#ifndef No_Exception` region swallows the CONDITION as well as the raise, so the "
          "check's own answer is discarded and the next statement runs on data the kernel knows is "
          "wrong. Committed, because it cannot be derived from the raise map; "
          "--verify-no-exception-regions re-derives it from an OCCT tree."
          % len(NO_EXCEPTION_REGIONS))
    bridge_text = "".join(open(p, encoding="utf-8").read() for p in paths)
    for stem, swallowed, status in NO_EXCEPTION_REGIONS:
        named = re.search(r"\b" + re.escape(stem) + r"\b", bridge_text) is not None
        print("  %-32s swallows %-22s %s  (%s)"
              % (stem, swallowed, "the bridge names this class" if named
                 else "not named in the bridge", status))

    dead = sorted(((cls, entry["inline-dead-at-depth"]) for cls, entry in table.items()
                   if "inline-dead-at-depth" in entry),
                  key=lambda row: (-row[1][2], row[0]))
    inline_total = sum(1 for entry in table.values() if "inline-raise" in entry)
    print("\ncensus-compiled-out-validation, the depth qualifier: %d of the %d class(es) the map "
          "calls inline-checked are NAMED by at least one OCCT out-of-line unit, which is a unit "
          "that expands the same check with No_Exception on. The verdict `live-inline` above means "
          "live where the BRIDGE is the immediate caller, and nowhere else."
          % (len(dead), inline_total))
    for cls, (_excs, members, count) in dead[:10]:
        print("  %-28s %5d unit(s)  %s" % (cls, count, ",".join(sorted(members))))

    print("\nA `catch` here is not automatically wrong: it may be guarding against a future OCCT "
          "build with the checks on, or against a literal throw this map cannot see through a call "
          "chain. What it must not be is the only thing standing between a caller's bad number and "
          "a value that reads as a measurement. See okf/policies/"
          "occt-validation-is-compiled-out.md.")
    return 0


# ---------------------------------------------------------------------------
# self-test
# ---------------------------------------------------------------------------


FIXTURE_TABLE = {
    "gp_Dir": {"inline-raise": ({"Standard_ConstructionError"}, {"gp_Dir", "SetCoord"}, 5)},
    "Geom_Direction": {"outofline-raise": ({"Standard_ConstructionError"}, {"Geom_Direction"}, 5)},
    "Geom2d_Direction": {"outofline-raise": ({"Standard_ConstructionError"},
                                             {"Geom2d_Direction"}, 4)},
    "gp_Ax2": {"outofline-delegated": ({"Standard_ConstructionError"}, {"gp_Dir"}, 3)},
    "BRepBuilderAPI_MakeEdge": {"outofline-throw": ({"StdFail_NotDone"}, {"Edge"}, 2)},
}
FIXTURE_PACKAGES = {"gp", "Geom", "Geom2d", "BRepBuilderAPI", "TopoDS"}


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))
        return ok

    def one(source, table=None, packages=None):
        return census(table or FIXTURE_TABLE, FIXTURE_PACKAGES if packages is None else packages,
                      paths=["<f>"], text_by_path={"<f>": source})

    # The finding this census exists for: the try is real code, the check behind it is not.
    dead = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
            "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n  }\n"
            "  catch (...)\n  {\n  }\n}\n")
    found, counts = one(dead)
    case("outofline-only-try-reported",
         len(found) == 1 and found[0]["verdict"] == "fabricated", str(found))

    # The same shape with an inline check is real protection and must not be reported.
    live = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
            "    gp_Dir d(x, y, z);\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = one(live)
    case("inline-check-try-not-reported",
         len(found) == 1 and found[0]["verdict"] == "live-inline", str(found))

    # A literal construction cannot be tripped by a caller, so it is not in the population at all.
    literal = ("void OCCTThing()\n{\n  try\n  {\n"
               "    Handle(Geom_Direction) d = new Geom_Direction(0, 0, 1);\n  }\n"
               "  catch (...)\n  {\n  }\n}\n")
    found, counts = one(literal)
    case("literal-construction-out-of-population",
         found == [] and counts["try-blocks"] == 1
         and counts["try-blocks-with-vocabulary"] == 0, str(counts))

    # A second justification downgrades the verdict rather than clearing or condemning the site.
    mixed = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
             "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n"
             "    BRepBuilderAPI_MakeEdge mk(p1, p2);\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = one(mixed)
    case("second-throw-source-downgrades-to-mixed",
         len(found) == 1 and found[0]["verdict"] == "mixed"
         and found[0]["other_live"] == ["BRepBuilderAPI_MakeEdge"], str(found))

    # An unrecognised OCCT class is uncertainty, not a clean bill: the map cannot see through it.
    unknown = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
               "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n"
               "    Wibble_Thing w(d);\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = one(unknown)
    case("unrecognised-class-downgrades-to-mixed",
         len(found) == 1 and found[0]["verdict"] == "mixed"
         and found[0]["other_unknown"] == ["Wibble_Thing"], str(found))

    # A class the map examined and found no site in cannot throw, so it is not a justification.
    # gp_Pnt is the case: it is absent from the map and its package is one the walk covered.
    inert = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
             "    gp_Pnt p(x, y, z);\n"
             "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n  }\n"
             "  catch (...)\n  {\n  }\n}\n")
    found, _ = one(inert)
    case("examined-class-with-no-site-is-not-a-justification",
         len(found) == 1 and found[0]["verdict"] == "fabricated", str(found))

    # And the same absence in a package the walk never covered is uncertainty, not inertness. This
    # distinction replaced a hand-written whitelist of "inert" gp_ types, 8 of whose 18 entries the
    # map contradicted: gp_Vec, gp_XY, gp_XYZ, gp_Trsf, gp_Trsf2d, gp_GTrsf, gp_Lin2d, gp_Vec2d.
    offtree = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
               "    Wibble_Thing p(x, y, z);\n"
               "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n  }\n"
               "  catch (...)\n  {\n  }\n}\n")
    found, _ = one(offtree)
    case("absence-in-an-unexamined-package-is-uncertainty",
         len(found) == 1 and found[0]["verdict"] == "mixed", str(found))

    # A class whose only recorded check is one it delegates to an inline-checked class from its own
    # .cxx is still compiled out: gp_Ax2 documents ConstructionError and cannot raise it.
    delegated = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
                 "    gp_Ax2 a(origin, normalDir, refDir);\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = one(delegated, table=dict(FIXTURE_TABLE, **{
        "gp_Ax2": FIXTURE_TABLE["gp_Ax2"]}))
    case("delegated-check-is-still-compiled-out",
         len(found) == 1 and found[0]["verdict"] == "fabricated"
         and found[0]["sites"] == ["gp_Ax2[compiled-out]"], str(found))

    # A construction outside the try is check-throwing-calls' subject, not this census's.
    outside = ("void OCCTThing(double x)\n{\n"
               "  Handle(Geom_Direction) d = new Geom_Direction(x, x, x);\n  try\n  {\n"
               "    int i = 0;\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, counts = one(outside)
    case("construction-outside-try-not-in-population",
         found == [] and counts["try-blocks"] == 1, str(counts))

    # Derivation: the inline/out-of-line split is decided by the extension, and the member by the
    # body the site sits in, not by the nearest definition above it.
    hxx = ("inline constexpr gp_Dir::gp_Dir(const double x)\n{\n"
           "  Standard_ConstructionError_Raise_if(x < 0, \"gp_Dir\");\n}\n"
           "inline void gp_Dir::SetCoord(const double x)\n{\n"
           "  Standard_OutOfRange_Raise_if(x < 0, \"gp_Dir\");\n}\n")
    sites, _bases = file_sites(".hxx", hxx)
    case("member-attribution-by-body-not-by-proximity",
         [s[2] for s in sites] == ["gp_Dir", "SetCoord"], str(sites))
    case("header-sites-are-inline", {s[0] for s in sites} == {"inline-raise"}, str(sites))

    # The same file as a .cxx: the kernel compiles it with No_Exception and the check is gone.
    sites, _bases = file_sites(".cxx", hxx)
    case("cxx-sites-are-outofline", {s[0] for s in sites} == {"outofline-raise"}, str(sites))

    # An out-of-line constructor and destructor, which OCCT writes with the qualified name at column
    # 0 and no return type. MEMBER_RE's prefix used to be mandatory, and since there is no word
    # boundary inside the class name it could not match these at all: 1,274 of 5,554 real sites were
    # reaching the fallback, 720 of them in a .cxx, and the StdFail_NotDone constructor check is
    # exactly the member channel two wants named.
    ctor = ("math_FunctionRoots::math_FunctionRoots(math_FunctionWithDerivative& F,\n"
            "                                       const double                 a)\n{\n"
            "  StdFail_NotDone_Raise_if(a < 0, \" \");\n}\n"
            "math_FunctionRoots::~math_FunctionRoots()\n{\n"
            "  Standard_OutOfRange_Raise_if(myDone, \" \");\n}\n")
    sites, _bases = file_sites(".cxx", ctor)
    case("out-of-line-constructor-and-destructor-are-attributed",
         [s[2] for s in sites] == ["math_FunctionRoots", "~math_FunctionRoots"], str(sites))

    # And the fallback says so rather than borrowing a plausible name, because channel two reads the
    # members column for accessor names. The literal is asserted rather than the constant, or the
    # case would be true of whatever the constant said, and the property that makes it safe is
    # asserted too: it cannot be spelled as a C++ member, so it can never collide with a real one.
    static_helper = ("static void ScanIt(const double x)\n{\n"
                     "  StdFail_NotDone_Raise_if(x < 0, \" \");\n}\n")
    sites, _bases = file_sites(".cxx", static_helper)
    case("unattributable-site-is-recorded-as-file-scope",
         [s[2] for s in sites] == ["<file-scope>"], str(sites))
    case("the-unattributed-marker-cannot-be-a-member-name",
         re.match(r"^[A-Za-z_]\w*$", UNATTRIBUTED) is None, UNATTRIBUTED)

    # The optional prefix must not turn a qualified *call* at column 0 into a member body: the brace
    # search rejects it because the statement's `;` arrives first. Without that, everything after
    # such a call would be attributed to it.
    call = ("Standard_ConstructionError::Raise(\"x\");\n"
            "void gp_Dir::Thing(const double x)\n{\n"
            "  Standard_OutOfRange_Raise_if(x < 0, \" \");\n}\n")
    sites, _bases = file_sites(".cxx", call)
    case("qualified-call-at-column-zero-is-not-a-member-body",
         [s[2] for s in sites] == ["Thing"], str(sites))

    # A doc comment naming an exception is prose. OCCT's headers are full of them.
    prose = ("//! Raises Standard_ConstructionError if theN is null.\n"
             "/* throw Standard_DomainError(\"x\"); */\n"
             "void gp_Dir::Thing()\n{\n  return;\n}\n")
    sites, _bases = file_sites(".cxx", prose)
    case("doc-comments-are-not-sites", sites == [], str(sites))

    # The macro's own definition is not a call of it, or all 111 headers would look like raisers.
    define = ("#if !defined No_Exception && !defined No_Standard_ConstructionError\n"
              "  #define Standard_ConstructionError_Raise_if(CONDITION, MESSAGE) \\\n"
              "    if (CONDITION) throw Standard_ConstructionError(MESSAGE);\n"
              "#else\n"
              "  #define Standard_ConstructionError_Raise_if(CONDITION, MESSAGE)\n"
              "#endif\n")
    sites, _bases = file_sites(".hxx", define)
    case("macro-definition-is-not-a-site",
         [s for s in sites if s[0] == "inline-raise"] == [], str(sites))

    # The base-class scan, which is what keeps BRepPrimAPI_MakeBox off the fabricated list.
    decl = ("class BRepPrimAPI_MakeBox : public BRepBuilderAPI_MakeShape\n{\npublic:\n};\n")
    _sites, found_bases = file_sites(".hxx", decl)
    case("base-classes-are-read-from-the-header",
         found_bases == {"BRepPrimAPI_MakeBox": {"BRepBuilderAPI_MakeShape"}}, str(found_bases))
    inherit_table = {"BRepBuilderAPI_Command": {"outofline-throw": ({"StdFail_NotDone"},
                                                                    {"Check"}, 1)}}
    derive_inherited(inherit_table, {"BRepPrimAPI_MakeBox": {"BRepBuilderAPI_MakeShape"},
                                     "BRepBuilderAPI_MakeShape": {"BRepBuilderAPI_Command"}})
    case("inherited-live-is-found-through-an-intermediate-base",
         classify_class("BRepPrimAPI_MakeBox", inherit_table, {"BRepPrimAPI"}) == "live-inherited",
         str(inherit_table.get("BRepPrimAPI_MakeBox")))

    # A second justification that is live only by inheritance still counts as one.
    inherited_second = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
                        "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n"
                        "    BRepPrimAPI_MakeBox mk(axis, w, h, d);\n  }\n"
                        "  catch (...)\n  {\n  }\n}\n")
    found, _ = one(inherited_second, table=dict(FIXTURE_TABLE, **{
        "BRepPrimAPI_MakeBox": {"inherited-live": ({"StdFail_NotDone"},
                                                   {"BRepBuilderAPI_Command"}, 1)}}),
                   packages=FIXTURE_PACKAGES | {"BRepPrimAPI"})
    case("inherited-live-second-source-downgrades-to-mixed",
         len(found) == 1 and found[0]["verdict"] == "mixed"
         and found[0]["other_live"] == ["BRepPrimAPI_MakeBox"], str(found))

    # The nested-argument scan, which is the defect that made 89 sites look fabricated.
    nested = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
              "    gp_Ax2 axis(gp_Pnt(x, y, z), gp_Dir(x, y, z));\n  }\n"
              "  catch (...)\n  {\n  }\n}\n")
    found, _ = one(nested)
    case("nested-vocabulary-construction-is-found",
         len(found) == 1 and found[0]["verdict"] == "live-inline"
         and "gp_Dir[live-inline]" in found[0]["sites"], str(found))

    # Channel two. The fixture's GeomAPI_ProjectPointOnSurf carries the shape the kernel has: a
    # StdFail_NotDone_Raise_if in the .cxx, on the accessors that report the answer.
    nd_table = dict(FIXTURE_TABLE, **{
        "GeomAPI_ProjectPointOnSurf": {
            "outofline-raise": ({"StdFail_NotDone"}, {"LowerDistance", "NearestPoint"}, 2)},
        "BRepPrimAPI_MakeHalfSpace": {
            "outofline-raise": ({"StdFail_NotDone"}, {"Solid"}, 1)},
    })

    def nd(source):
        return notdone_census(nd_table, paths=["<f>"], text_by_path={"<f>": source})

    unguarded = ("void OCCTThing(double x)\n{\n  try\n  {\n"
                 "    BRepPrimAPI_MakeHalfSpace maker(face, refPt);\n"
                 "    return new OCCTShape(maker.Solid());\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = nd(unguarded)
    case("notdone-accessor-with-no-guard-reported",
         len(found) == 1 and found[0]["guard"] == "none" and found[0]["members"] == ["Solid"],
         str(found))

    guarded = ("void OCCTThing(double x)\n{\n  try\n  {\n"
               "    BRepPrimAPI_MakeHalfSpace maker(face, refPt);\n"
               "    if (!maker.IsDone())\n      return nullptr;\n"
               "    return new OCCTShape(maker.Solid());\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, counts = nd(guarded)
    case("notdone-accessor-behind-isdone-is-clean",
         len(found) == 1 and found[0]["guard"] == "explicit", str(found))

    # Status() != gce_Done is what GC_Root::IsDone is defined as, so it is an explicit guard and not
    # a finding. Two of the first three sites this channel produced were this, and were correct.
    status = ("void OCCTThing(double x)\n{\n  try\n  {\n"
              "    BRepPrimAPI_MakeHalfSpace maker(face, refPt);\n"
              "    if (maker.Status() != gce_Done)\n      return nullptr;\n"
              "    return new OCCTShape(maker.Solid());\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = nd(status)
    case("status-against-gce_Done-counts-as-an-explicit-guard",
         len(found) == 1 and found[0]["guard"] == "explicit", str(found))

    counted = ("void OCCTThing(double x)\n{\n  try\n  {\n"
               "    GeomAPI_ProjectPointOnSurf proj(p, surface);\n"
               "    if (proj.NbPoints() == 0)\n      return result;\n"
               "    result.d = proj.LowerDistance();\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = nd(counted)
    case("count-guard-is-reported-for-a-reading-not-cleared",
         len(found) == 1 and found[0]["guard"] == "count", str(found))

    # Constructed and never read through one of the guarded accessors: not in the population.
    unread = ("void OCCTThing(double x)\n{\n  try\n  {\n"
              "    GeomAPI_ProjectPointOnSurf proj(p, surface);\n"
              "    int n = proj.NbPoints();\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = nd(unread)
    case("construction-never-read-is-not-in-the-population", found == [], str(found))

    # The plausibility assertions must fire, or a run against nothing would look clean.
    blind = assert_view_is_plausible({}, set(), {"try-blocks": 0}, [])
    case("plausibility-check-fires-on-an-empty-view", len(blind) >= 5, str(blind))

    # A map that lost gp_Dir's inline row is a map of something other than an OCCT tree, and the
    # whole census inverts: every gp_Dir site would read as fabricated.
    without_gp_dir = {k: v for k, v in FIXTURE_TABLE.items() if k != "gp_Dir"}
    problems = assert_view_is_plausible(without_gp_dir, FIXTURE_PACKAGES | {"x%d" % i for i in
                                                                           range(200)},
                                        {"try-blocks": 9999}, ["x"] * 74)
    case("plausibility-check-catches-a-map-missing-gp_Dir",
         any("gp_Dir has no inline-raise row" in p for p in problems), str(problems))

    # `canary_problems` is what `derive` aborts on, in place of the file-count floor #2833's rule
    # retired, and it is the same copy `assert_view_is_plausible` extends with. Both canaries must be
    # load-bearing: each absence has to produce its own line, or the pair is one check wearing two
    # names. The second is the one the old assertion pair could lose silently.
    case("canary-passes-on-a-map-holding-both-measured-facts",
         canary_problems(FIXTURE_TABLE) == [], str(canary_problems(FIXTURE_TABLE)))
    case("canary-fires-on-an-empty-map", len(canary_problems({})) == 2,
         str(canary_problems({})))
    without_geom_direction = {k: v for k, v in FIXTURE_TABLE.items() if k != "Geom_Direction"}
    case("canary-fires-when-the-measured-dead-check-is-absent",
         [p for p in canary_problems(without_geom_direction)
          if p.startswith("Geom_Direction has no outofline-raise row")] != [],
         str(canary_problems(without_geom_direction)))
    # An OCCT tree whose gp_Dir check had moved out of line would abort too, and that is correct: it
    # is the news the map exists to carry, not a parser fault. The wrong instrument here was a floor
    # on the walked file count, which sat at 34% of the real 14,671 and so answered neither question.
    moved_out_of_line = dict(FIXTURE_TABLE, **{
        "gp_Dir": {"outofline-raise": ({"Standard_ConstructionError"}, {"gp_Dir"}, 5)}})
    case("canary-fires-when-the-measured-live-check-moved-out-of-line",
         len(canary_problems(moved_out_of_line)) == 1, str(canary_problems(moved_out_of_line)))

    # NOT_OCCT_RE, whose entries are each a name OCCT_CLASS_RE yields that is not an OCCT class. A
    # `Standard_` typedef must not read as an unexamined class, which would downgrade a fabricated
    # verdict to mixed on no evidence. One case for the mechanism, not one per entry: measured, no
    # entry fires over the bridge's own population, so a per-entry case could not fail on removal.
    # `OCCTShapeRef` is in the fixture as the bridge writes it and is excluded by `OCCT_CLASS_RE`
    # before this list ever sees it, having no underscore; that is the point of the comment there.
    typedefs = ("void OCCTThing(double x, double y, double z)\n{\n  try\n  {\n"
                "    Handle(Geom_Direction) d = new Geom_Direction(x, y, z);\n"
                "    Standard_Real len = 0.0;\n"
                "    OCCTShapeRef out = nullptr;\n  }\n  catch (...)\n  {\n  }\n}\n")
    found, _ = one(typedefs)
    case("standard-typedefs-are-not-unexamined-classes",
         len(found) == 1 and found[0]["verdict"] == "fabricated"
         and found[0]["other_unknown"] == [], str(found))

    # ---------------------------------------------------------------- channel three (#2858).
    # The fixture class is the one #2859 was measured on: Geom2d_BezierCurve's index guards are
    # all out-of-line macros, and Geom2d_BSplineCurve's are literal throws, which is why only one
    # of the pair is in this channel's population at all.
    ix_table = dict(FIXTURE_TABLE, **{
        "Geom2d_BezierCurve": {
            "outofline-raise": ({"Standard_OutOfRange", "Standard_ConstructionError"},
                                {"Pole", "SetPole", "InsertPoleAfter"}, 14)},
    })

    def ix(source):
        return index_census(ix_table, paths=["<f>"], text_by_path={"<f>": source})

    # The shipped defect this channel exists for, in the shape PR #2870's own "before" had: a
    # caller's int32_t reaches Pole() and nothing bounds it.
    unbounded = ("void OCCTCurve2DBezierGetPole(OCCTCurve2DRef curve, int32_t index, double* x)\n"
                 "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
                 "  if (bz.IsNull())\n    return;\n"
                 "  gp_Pnt2d p = bz->Pole(index);\n  *x = p.X();\n}\n")
    found, _counts = ix(unbounded)
    case("index-unbounded-caller-index-reported",
         len(found) == 1 and found[0]["guard"] == "none"
         and found[0]["member"] == "Pole", str(found))

    # The guard PR #2870 wrote. Bounding against the object clears the site.
    bounded = ("void OCCTCurve2DBezierGetPole(OCCTCurve2DRef curve, int32_t index, double* x)\n"
               "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
               "  if (bz.IsNull() || index < 1 || index > bz->NbPoles())\n    return;\n"
               "  gp_Pnt2d p = bz->Pole(index);\n  *x = p.X();\n}\n")
    found, _ = ix(bounded)
    case("index-bounded-against-the-object-is-clean",
         len(found) == 1 and found[0]["guard"] == "bound", str(found))

    # Six of those ten guards hoist the bound into a local first, and reading the condition text
    # alone scored two of them literal-only: a false finding pointing at a correct site.
    hoisted = ("bool OCCTCurve2DBezierRemovePole(OCCTCurve2DRef curve, int32_t index)\n"
               "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
               "  const int nbPoles = bz->NbPoles();\n"
               "  if (index < 1 || index > nbPoles || nbPoles <= 2)\n    return false;\n"
               "  bz->Pole(index);\n  return true;\n}\n")
    found, _ = ix(hoisted)
    case("index-bound-hoisted-into-a-local-is-still-a-bound",
         len(found) == 1 and found[0]["guard"] == "bound", str(found))

    # A constant floor stops a negative index and no overrun, which is a different verdict from
    # both of the above and is reported for a reading rather than cleared.
    literal = ("void OCCTThing(OCCTCurve2DRef curve, int32_t index)\n"
               "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
               "  if (index < 1)\n    return;\n  bz->Pole(index);\n}\n")
    found, _ = ix(literal)
    case("index-bounded-against-a-constant-only-is-reported",
         len(found) == 1 and found[0]["guard"] == "literal-only", str(found))

    # An out-parameter is not an index, whatever it points at. Without this the channel reported
    # four such calls, every one of them noise, and every one on a member the map lists only
    # because its class also raises StdFail_NotDone somewhere else. The fixture points at an
    # int32_t deliberately: a `double*` is rejected by the type filter below as well, so it would
    # not show which of the two rules is doing the work.
    outparam = ("void OCCTThing(OCCTCurve2DRef curve, int32_t* outIndex)\n"
                "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
                "  bz->Pole(outIndex);\n}\n")
    found, _ = ix(outparam)
    case("index-out-parameters-are-not-in-the-population", found == [], str(found))

    # And the case the TYPE filter alone decides, since the one above is carried by
    # `parameters_of` dropping a pointer parameter before the filter ever sees it. A double is a
    # coordinate or a tolerance; nothing about it is a number OCCT was going to range-check, and
    # without this the channel reports every `Segment(u1, u2)` in the bridge.
    scalar = ("void OCCTThing(OCCTCurve2DRef curve, double u1, double u2)\n"
              "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
              "  bz->SetPole(u1, u2);\n}\n")
    found, _ = ix(scalar)
    case("index-a-by-value-double-is-not-an-index", found == [], str(found))

    # A loop variable the function derived itself is not a caller-controlled index: the bridge
    # already knows it is in range, and OCCTCurve2DBezierGetPoles is the real instance.
    internal = ("void OCCTThing(OCCTCurve2DRef curve, int32_t unused)\n"
                "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
                "  for (int i = 1; i <= bz->NbPoles(); i++)\n    bz->Pole(i);\n}\n")
    found, _ = ix(internal)
    case("index-loop-variable-is-not-caller-controlled", found == [], str(found))

    # The nested-argument scan, the same defect channel one had: an argument list read as
    # `[^)]*` stops at the first inner `)`. **No site in the bridge needs this today**, because
    # OCCT puts the index first in every such signature and a truncated list still holds it; the
    # case therefore puts the index after the nested call, which is a parser case and not a shape
    # the tree writes. It is kept because the direction of the error is a false clean, and a
    # census that misses a defect is the one failure this page's whole argument is about.
    nested = ("bool OCCTThing(OCCTCurve2DRef curve, int32_t index, double x, double y)\n"
              "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
              "  bz->SetPole(gp_Pnt2d(x, y), index);\n  return true;\n}\n")
    found, _ = ix(nested)
    case("index-after-a-nested-call-argument-is-still-found",
         len(found) == 1 and found[0]["member"] == "SetPole", str(found))

    # The asymmetry signal, which is how #2859 was found by hand. The guarded sibling is a
    # DIFFERENT class whose own check is a literal throw, so it is not in the population: keyed on
    # (class, member) rather than on the member name, this comparison cannot be made at all.
    asymmetric = ("void OCCTCurve2DBSplineGetPole(OCCTCurve2DRef curve, int32_t index)\n"
                  "{\n  auto bs = Handle(Geom2d_BSplineCurve)::DownCast(curve->curve);\n"
                  "  if (index < 1 || index > bs->NbPoles())\n    return;\n"
                  "  bs->Pole(index);\n}\n"
                  "void OCCTCurve2DBezierGetPole(OCCTCurve2DRef curve, int32_t index)\n"
                  "{\n  auto bz = Handle(Geom2d_BezierCurve)::DownCast(curve->curve);\n"
                  "  bz->Pole(index);\n}\n")
    found, _ = ix(asymmetric)
    case("index-asymmetry-names-the-guarded-sibling-in-the-same-file",
         len(found) == 1 and found[0]["guard"] == "none"
         and found[0]["asymmetric"] == ["OCCTCurve2DBSplineGetPole"], str(found))

    # A class with no index-family out-of-line raise is not in the population whatever it is
    # handed, or the channel would be a census of every integer the bridge passes anywhere.
    unrelated = ("void OCCTThing(OCCTCurve2DRef curve, int32_t index)\n"
                 "{\n  Handle(Geom_Direction) d = Handle(Geom_Direction)::DownCast(curve->curve);\n"
                 "  d->Pole(index);\n}\n")
    found, _ = ix(unrelated)
    case("index-class-with-no-index-raise-is-out-of-the-population", found == [], str(found))

    # ---------------------------------------------------------------- channel four (#2858).
    swallow = ("#ifndef No_Exception\n  bool IsOK =\n#endif\n"
               "    Arrange(C1, C2, C3, C4, Tol);\n"
               "  Standard_ConstructionError_Raise_if(!IsOK, \" not joining\");\n")
    case("no-exception-region-holding-an-assignment-swallows",
         no_exception_region_texts(swallow) == ["bool IsOK ="],
         str(no_exception_region_texts(swallow)))

    # The 14 files that define the symbol themselves change nothing: the whole kernel already has
    # it. Listing them by name would have been the same answer today and stale tomorrow.
    defines = "#ifndef No_Exception\n  #define No_Exception\n#endif\n"
    case("no-exception-region-defining-the-symbol-swallows-nothing",
         no_exception_region_texts(defines) == [], str(no_exception_region_texts(defines)))

    diagnostic = ("#ifdef No_Exception\n  di << \"Exceptions disabled\\n\";\n"
                  "#else\n  di << \"Exceptions enabled\\n\";\n#endif\n")
    case("no-exception-diagnostic-region-swallows-nothing",
         no_exception_region_texts(diagnostic) == [],
         str(no_exception_region_texts(diagnostic)))

    guard_only = ("#ifndef No_Exception\n"
                  "  if (aBlock == nullptr)\n    throw Standard_ProgramError(\"x\");\n#endif\n")
    case("no-exception-region-that-only-throws-swallows-nothing",
         no_exception_region_texts(guard_only) == [],
         str(no_exception_region_texts(guard_only)))

    # The committed table against a tree, all three ways it can be wrong, because a table that
    # silently matched nothing would report all clear exactly as loudly as a clean tree.
    complete = {stem: [swallowed] for stem, swallowed, _status in NO_EXCEPTION_REGIONS}
    case("no-exception-table-agrees-with-a-tree-holding-exactly-it",
         no_exception_problems_for(complete) == [], str(no_exception_problems_for(complete)))
    added = dict(complete, Wibble_Thing=["double x = 1;"])
    case("no-exception-table-reports-a-region-it-does-not-list",
         any("Wibble_Thing holds" in p for p in no_exception_problems_for(added)),
         str(no_exception_problems_for(added)))
    missing = {k: v for k, v in complete.items() if k != "GeomFill_BSplineCurves"}
    case("no-exception-table-reports-a-row-the-tree-no-longer-has",
         any("GeomFill_BSplineCurves is in the committed table" in p
             for p in no_exception_problems_for(missing)), str(no_exception_problems_for(missing)))
    moved = dict(complete, GeomFill_BSplineCurves=["double somethingElse = 1;"])
    case("no-exception-table-reports-a-row-whose-region-changed",
         any("GeomFill_BSplineCurves swallows" in p for p in no_exception_problems_for(moved)),
         str(no_exception_problems_for(moved)))

    # ---------------------------------------------------------------- the depth kind (#2858).
    depth_table = {"NCollection_Array1": {"inline-raise": ({"Standard_OutOfRange"},
                                                           {UNATTRIBUTED}, 9)}}
    derive_dead_at_depth(None, depth_table, sources=[
        ("BRepMesh_Delaun", "void f() { NCollection_Array1<int> a(1, 2); a.Value(1); }"),
        ("BRepMesh_Circle", "NCollection_Array1<int> b(1, 2);"),
        ("Poly_Triangulation", "// NCollection_Array1 in a comment only\n"),
        ("gp_Dir", "void g() { return; }"),
    ])
    row = depth_table["NCollection_Array1"].get("inline-dead-at-depth")
    case("dead-at-depth-counts-every-unit-that-names-the-class",
         row is not None and row[2] == 2 and row[1] == {"BRepMesh"}, str(row))
    case("dead-at-depth-does-not-count-a-mention-in-a-comment",
         row is not None and "Poly" not in row[1], str(row))
    clean = {"gp_Dir": {"outofline-raise": ({"Standard_ConstructionError"}, {"gp_Dir"}, 1)}}
    derive_dead_at_depth(None, clean, sources=[("gp_Ax2", "gp_Dir d(1, 0, 0);")])
    case("dead-at-depth-says-nothing-about-a-class-with-no-inline-check",
         "inline-dead-at-depth" not in clean["gp_Dir"], str(clean))

    # The plausibility assertions for the two additions that read the map. A map without either
    # canary would let the census print a channel that examined nothing.
    for absent, needle in (("Geom2d_BezierCurve", "channel three examines"),
                           ("NCollection_Array1", "carries no inline-dead-at-depth row")):
        thinned = dict(ix_table, **{"NCollection_Array1": {
            "inline-raise": ({"Standard_OutOfRange"}, {UNATTRIBUTED}, 9),
            "inline-dead-at-depth": ({"Standard_OutOfRange"}, {"BRepMesh"}, 400)}})
        thinned.pop(absent, None)
        problems = assert_view_is_plausible(thinned,
                                            FIXTURE_PACKAGES | {"x%d" % i for i in range(200)},
                                            {"try-blocks": 9999}, ["x"] * 74)
        case("plausibility-check-fires-when-%s-is-absent" % absent,
             any(needle in problem for problem in problems), str(problems))

    # The live tree, which is the run anybody reads.
    if os.path.exists(TABLE):
        real, real_packages = parse_table()
        real_paths = sorted(glob.glob(os.path.join(SRC, "*.mm")))
        _found, real_counts = census(real, real_packages, paths=real_paths)
        live_problems = assert_view_is_plausible(real, real_packages, real_counts, real_paths)
        case("live-tree-view-is-plausible", not live_problems, "; ".join(live_problems))
        case("live-tree-population-is-non-empty",
             real_counts["try-blocks-with-vocabulary"] > 0, str(real_counts))
        _nd, real_nd_counts = notdone_census(real, paths=real_paths)
        case("live-tree-channel-two-population-is-non-empty",
             sum(real_nd_counts.values()) > 0, str(real_nd_counts))
        _ix, real_ix_counts = index_census(real, paths=real_paths)
        case("live-tree-channel-three-population-is-non-empty",
             sum(real_ix_counts.values()) > 0, str(real_ix_counts))
        # Channel four's table is only worth printing while the bridge can still reach one of the
        # classes in it, and `Surface.bsplineFill` is why it exists at all (PR #2849).
        bridge = "".join(open(path, encoding="utf-8").read() for path in real_paths)
        reachable = [stem for stem, _s, _t in NO_EXCEPTION_REGIONS
                     if re.search(r"\b" + re.escape(stem) + r"\b", bridge)]
        case("live-tree-channel-four-table-is-reachable-from-the-bridge",
             "GeomFill_BSplineCurves" in reachable, str(reachable))
    else:
        case("committed-map-exists", False, "%s is missing" % os.path.relpath(TABLE, REPO))

    # --- the provenance stamp's tree half (#2885) ---------------------------------------------
    #
    # A fixture tree rather than the real one, because the property under test is what the checker
    # says about a tree that does NOT carry a patch, and the real tree carries all of them. The
    # fixture is written under a temporary directory and removed, so no case depends on cleanup
    # having run in an earlier one.
    import shutil
    import tempfile

    fixture = tempfile.mkdtemp(prefix="raise-map-provenance-")
    try:
        os.makedirs(os.path.join(fixture, "adm", "cmake"))
        open(os.path.join(fixture, "adm", "cmake", "version.cmake"), "w", encoding="utf-8").write(
            "set (OCC_VERSION_MAJOR 8 )\nset (OCC_VERSION_MINOR 0 )\n"
            "set (OCC_VERSION_MAINTENANCE 1 )\n")
        case("tree-version-read-from-version-cmake", tree_occt_version(fixture) == "8.0.1",
             str(tree_occt_version(fixture)))
        case("tree-version-absent-is-none", tree_occt_version(os.path.join(fixture, "nope"))
             is None)

        os.makedirs(os.path.join(fixture, "src", "Pkg"))
        target = os.path.join(fixture, "src", "Pkg", "Pkg_Thing.cxx")
        patched = "void Pkg_Thing::Do()\n{\n  if (myS.IsNull())\n    throw Standard_NullObject();\n  use(myS);\n}\n"
        vanilla = "void Pkg_Thing::Do()\n{\n  use(myS);\n}\n"
        patch_text = (
            "--- a/src/Pkg/Pkg_Thing.cxx\n"
            "+++ b/src/Pkg/Pkg_Thing.cxx\n"
            "@@ -1,3 +1,5 @@\n"
            " void Pkg_Thing::Do()\n"
            " {\n"
            "+  if (myS.IsNull())\n"
            "+    throw Standard_NullObject();\n"
            "   use(myS);\n"
            " }\n")
        patch_path = os.path.join(fixture, "0099-fixture.patch")
        open(patch_path, "w", encoding="utf-8").write(patch_text)

        case("postimage-is-context-plus-added-lines",
             patch_postimages(patch_text) == [(
                 "src/Pkg/Pkg_Thing.cxx",
                 ["void Pkg_Thing::Do()", "{", "  if (myS.IsNull())",
                  "    throw Standard_NullObject();", "  use(myS);", "}"])],
             str(patch_postimages(patch_text)))

        open(target, "w", encoding="utf-8").write(patched)
        case("applied-patch-is-not-reported",
             patches_not_applied(fixture, [patch_path]) == [],
             str(patches_not_applied(fixture, [patch_path])))

        # This is #2885 itself, in miniature: the patch is on disk and the tree predates it, which
        # is the state `--write-table` must refuse rather than stamp.
        open(target, "w", encoding="utf-8").write(vanilla)
        reported = patches_not_applied(fixture, [patch_path])
        case("unapplied-patch-is-reported",
             len(reported) == 1 and "0099-fixture" in reported[0]
             and "does not hold" in reported[0], str(reported))

        os.remove(target)
        reported = patches_not_applied(fixture, [patch_path])
        case("patch-targeting-a-file-the-tree-lacks-is-reported",
             len(reported) == 1 and "is not in the tree" in reported[0], str(reported))
    finally:
        shutil.rmtree(fixture, ignore_errors=True)

    # The writer and the reader of the stamp are in different files on purpose, so the round trip
    # is asserted from both ends: check-inventory-prose.py owns the format and has the same case.
    sample = "\n".join(INVENTORY.format_provenance("8.0.1", {"0042-x": "0123456789ab"}))
    case("stamp-borrowed-from-check-inventory-prose-round-trips",
         INVENTORY.parse_provenance(sample)
         == {"version": "8.0.1", "patches": {"0042-x": "0123456789ab"}},
         str(INVENTORY.parse_provenance(sample)))

    # The view check: the committed map must carry a stamp naming every carried patch. A
    # --write-table that silently stopped emitting it would leave the gate in check-inventory-prose
    # reporting on nothing, and this is the case that says so from the writer's side.
    if os.path.exists(TABLE):
        live = INVENTORY.parse_provenance(open(TABLE, encoding="utf-8").read())
        case("committed-map-carries-a-stamp-for-every-carried-patch",
             live is not None
             and set(live["patches"]) == set(INVENTORY.carried_patch_digests()),
             "stamped=%d on-disk=%d" % (len(live["patches"]) if live else -1,
                                        len(INVENTORY.carried_patch_digests())))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


# ---------------------------------------------------------------------------
# the map's provenance stamp (#2885)
# ---------------------------------------------------------------------------
#
# The map describes the tree AFTER `Scripts/build-occt.sh` applies the carried patches, and nothing
# re-derived it when that tree changed: `0042` added a throw to `ShapeAnalysis::GetFaceUVBounds`
# and the map said `ShapeAnalysis` held no live throw for two pins. The trigger that was missing is
# a stamp saying which patch set produced the tree, because that is text a runner with no OCCT
# checkout can compare against `Scripts/patches/`.
#
# The stamp is only worth as much as its truthfulness, so `--write-table` MEASURES it rather than
# asserting it: every carried patch has to be verifiably present in the tree being derived from, or
# nothing is written. Without that, running `--write-table` against a tree patched a month ago
# would stamp today's patch list onto yesterday's rows and put the gate to sleep, which is a worse
# state than the one this closes.


def tree_occt_version(occt_src):
    """The OCCT version the tree states, e.g. "8.0.1", or None.

    `adm/cmake/version.cmake` is where OCCT keeps it in 8.x; there is no `Standard_Version.hxx` in
    the source tree, it is generated into the build. The numeric triple is what
    `Scripts/build-occt.sh`'s `OCCT_VERSION` can be compared against; the optional
    `OCC_VERSION_DEVELOPMENT` string is a different vocabulary from that script's `OCCT_RC` token,
    so it is appended for a reader and not compared.
    """
    path = os.path.join(occt_src, "adm", "cmake", "version.cmake")
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return None
    parts = []
    for name in ("MAJOR", "MINOR", "MAINTENANCE"):
        match = re.search(r"set\s*\(\s*OCC_VERSION_%s\s+(\d+)" % name, text)
        if not match:
            return None
        parts.append(match.group(1))
    version = ".".join(parts)
    dev = re.search(r"set\s*\(\s*OCC_VERSION_DEVELOPMENT\s+\"?([A-Za-z0-9._]+)", text)
    return version + "." + dev.group(1) if dev else version


def patch_postimages(text):
    """[(path, [lines])] for every hunk in a unified diff: the lines the patch leaves behind.

    Context and added lines, in order, with removed lines dropped. A hunk is applied exactly when
    its post-image appears in the target file, which is a property of the file alone and needs no
    `git`, no index and no clean tree. `git apply --reverse --check` is the authority
    `build-occt.sh` and docs/guides/building-occt.md use; this is the same question asked of text,
    so that `--write-table` can refuse a stale tree on a machine where the tree is not a checkout.
    """
    out, path, post = [], None, None
    for line in text.split("\n"):
        if line.startswith("+++ "):
            target = line[4:].split("\t")[0].strip()
            path = None if target == "/dev/null" else (
                target[2:] if target[:2] in ("a/", "b/") else target)
            continue
        if line.startswith("@@"):
            if post is not None and path:
                out.append((path, post))
            post = []
            continue
        if post is None:
            continue
        if line[:1] in ("+", " "):
            post.append(line[1:])
        elif line[:1] in ("-", "\\"):
            continue
        else:
            if path:
                out.append((path, post))
            post = None
    if post is not None and path:
        out.append((path, post))
    return out


def _contains_block(haystack, needle):
    if not needle:
        return True
    for i in range(len(haystack) - len(needle) + 1):
        if haystack[i:i + len(needle)] == needle:
            return True
    return False


def patches_not_applied(occt_src, paths=None):
    """["<stem>: <why>"] for every carried patch this tree does not carry.

    `paths` is for the self-test; the real run reads `Scripts/patches/*.patch`. Trailing whitespace
    is ignored on both sides, because a patch file that survived an editor is still the patch.
    """
    if paths is None:
        paths = sorted(glob.glob(os.path.join(SCRIPTS, "patches", "*.patch")))
    problems = []
    for path in paths:
        stem = os.path.basename(path)[: -len(".patch")]
        cache = {}
        # errors="replace" on both sides, and on both sides for the same reason: OCCT carries a
        # handful of Latin-1 bytes in comments, and a decode error here would be a traceback
        # blaming the tool where the two texts still agree byte for byte.
        patch_text = open(path, encoding="utf-8", errors="replace").read()
        for rel, post in patch_postimages(patch_text):
            target = os.path.join(occt_src, rel)
            if rel not in cache:
                try:
                    cache[rel] = [line.rstrip() for line
                                  in open(target, encoding="utf-8", errors="replace").read()
                                  .split("\n")]
                except OSError:
                    cache[rel] = None
            if cache[rel] is None:
                problems.append("%s: %s is not in the tree" % (stem, rel))
                break
            if not _contains_block(cache[rel], [line.rstrip() for line in post]):
                problems.append("%s: %s does not hold this patch's lines" % (stem, rel))
                break
    return problems


def provenance_or_exit(occt_src):
    """The stamp lines for this tree, or exit 2 saying which patch it does not carry.

    A refusal rather than a warning, on okf/policies/static-gates.md's rule that a detector must
    fail rather than report about a population it did not examine. The stamp's whole claim is
    "these patches were in the tree these rows came from", and a tree that lacks one cannot support
    it.
    """
    version = tree_occt_version(occt_src)
    if version is None:
        sys.exit("census-compiled-out-validation: cannot read OCC_VERSION_* from %s; the map's "
                 "provenance stamp records the version and cannot be written (#2885)"
                 % os.path.join(occt_src, "adm", "cmake", "version.cmake"))
    missing = patches_not_applied(occt_src)
    if missing:
        print("census-compiled-out-validation: %s does not carry %d of the carried patches, so a "
              "map derived from it cannot be stamped with them (#2885):" % (occt_src, len(missing)))
        for problem in missing:
            print("  %s" % problem)
        print("\nRun Scripts/build-occt.sh, which applies Scripts/patches/*.patch to that tree, "
              "and try again.")
        sys.exit(2)
    return INVENTORY.format_provenance(version, INVENTORY.carried_patch_digests())


def write_table(occt_src):
    if not os.path.isdir(occt_src):
        sys.exit("census-compiled-out-validation: no OCCT source tree at %s" % occt_src)
    # The stamp first, because it is the cheap half and it is the half that can refuse: a tree
    # missing a carried patch is not one this map may be derived from at all, and finding that out
    # after a 70-second walk teaches nobody anything extra.
    provenance = provenance_or_exit(occt_src)
    text = format_table(derive(occt_src), provenance)
    open(TABLE, "w", encoding="utf-8").write(text)
    print("census-compiled-out-validation: wrote %s (%d rows) from %s"
          % (os.path.relpath(TABLE, REPO),
             len([l for l in text.splitlines() if l and not l.startswith("#")]), occt_src))
    return 0


def verify_no_exception_regions(occt_src, require):
    """Re-derive channel four's table from an OCCT tree, in the shape --reverify-table uses."""
    if not os.path.isdir(occt_src):
        message = ("census-compiled-out-validation: SKIPPED, no OCCT source tree at %s, so the "
                   "committed #ifndef No_Exception table cannot be re-derived" % occt_src)
        if require:
            print(message.replace("SKIPPED", "FAILED"))
            return 2
        print(message)
        return 0
    problems = no_exception_problems(occt_src)
    if not problems:
        print("census-compiled-out-validation: the %d committed #ifndef No_Exception region(s) "
              "are exactly the ones %s holds" % (len(NO_EXCEPTION_REGIONS), occt_src))
        return 0
    print("census-compiled-out-validation: the committed #ifndef No_Exception table no longer "
          "describes %s:" % occt_src)
    for problem in problems:
        print("  %s" % problem)
    return 1


def reverify_table(occt_src, require):
    if not os.path.isdir(occt_src):
        message = ("census-compiled-out-validation: SKIPPED, no OCCT source tree at %s, so the "
                   "committed map cannot be re-derived" % occt_src)
        if require:
            print(message.replace("SKIPPED", "FAILED"))
            return 2
        print(message)
        return 0
    derived = format_table(derive(occt_src), provenance_or_exit(occt_src))
    committed = open(TABLE, encoding="utf-8").read()
    if derived == committed:
        print("census-compiled-out-validation: %s matches %s"
              % (os.path.relpath(TABLE, REPO), occt_src))
        return 0
    import difflib
    print("census-compiled-out-validation: %s no longer matches %s"
          % (os.path.relpath(TABLE, REPO), occt_src))
    for line in list(difflib.unified_diff(committed.splitlines(), derived.splitlines(),
                                          "committed", "derived", lineterm=""))[:60]:
        print("  %s" % line)
    print("\nRegenerate with --write-table and check the totals moved the way the change predicts.")
    return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--verbose", action="store_true",
                        help="list every try block in the population, not just the findings")
    parser.add_argument("--write-table", action="store_true",
                        help="regenerate Scripts/occt-raise-if-map.txt from an OCCT source tree")
    parser.add_argument("--reverify-table", action="store_true",
                        help="re-derive the map and diff it against the committed copy")
    parser.add_argument("--verify-no-exception-regions", action="store_true",
                        help="re-derive channel four's committed #ifndef No_Exception table from "
                             "an OCCT source tree and report every way it disagrees")
    parser.add_argument("--require-occt-src", action="store_true",
                        help="with --reverify-table or --verify-no-exception-regions, fail "
                             "instead of skipping when the tree is absent, so a run that examined "
                             "nothing is not a green one")
    parser.add_argument("--occt-src", default=DEFAULT_OCCT_SRC,
                        help="OCCT source tree to derive from (default: Libraries/occt-src)")
    args = parser.parse_args()
    if args.self_test:
        sys.exit(self_test())
    if args.write_table:
        sys.exit(write_table(args.occt_src))
    if args.reverify_table:
        sys.exit(reverify_table(args.occt_src, args.require_occt_src))
    if args.verify_no_exception_regions:
        sys.exit(verify_no_exception_regions(args.occt_src, args.require_occt_src))
    sys.exit(run(args.verbose))
