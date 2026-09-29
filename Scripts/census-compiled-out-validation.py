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

Two halves, and only the second runs without an OCCT source tree:

  --write-table / --reverify-table   derive `Scripts/occt-raise-if-map.txt` from
                                     `Libraries/occt-src`, one row per OCCT class per kind of
                                     raise site. Needs the tree; `--reverify-table` reports SKIPPED
                                     without it unless `--require-occt-src` is given.
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
         "outofline-delegated", "inherited-live")

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
    return table, packages


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


def format_table(derived):
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
        "# Regenerate after an OCCT version bump or a carried patch that touches a raise site, and",
        "# check the totals below moved the way the change predicts.",
    ]
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
    else:
        case("committed-map-exists", False, "%s is missing" % os.path.relpath(TABLE, REPO))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


def write_table(occt_src):
    if not os.path.isdir(occt_src):
        sys.exit("census-compiled-out-validation: no OCCT source tree at %s" % occt_src)
    text = format_table(derive(occt_src))
    open(TABLE, "w", encoding="utf-8").write(text)
    print("census-compiled-out-validation: wrote %s (%d rows) from %s"
          % (os.path.relpath(TABLE, REPO),
             len([l for l in text.splitlines() if l and not l.startswith("#")]), occt_src))
    return 0


def reverify_table(occt_src, require):
    if not os.path.isdir(occt_src):
        message = ("census-compiled-out-validation: SKIPPED, no OCCT source tree at %s, so the "
                   "committed map cannot be re-derived" % occt_src)
        if require:
            print(message.replace("SKIPPED", "FAILED"))
            return 2
        print(message)
        return 0
    derived = format_table(derive(occt_src))
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
    parser.add_argument("--require-occt-src", action="store_true",
                        help="with --reverify-table, fail instead of skipping when the tree is "
                             "absent, so a run that examined nothing is not a green one")
    parser.add_argument("--occt-src", default=DEFAULT_OCCT_SRC,
                        help="OCCT source tree to derive from (default: Libraries/occt-src)")
    args = parser.parse_args()
    if args.self_test:
        sys.exit(self_test())
    if args.write_table:
        sys.exit(write_table(args.occt_src))
    if args.reverify_table:
        sys.exit(reverify_table(args.occt_src, args.require_occt_src))
    sys.exit(run(args.verbose))
