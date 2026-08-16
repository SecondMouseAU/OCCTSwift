#!/usr/bin/env python3
r"""Census of over-coverage: every OCCT class a doc claim attributes a method to, checked against
the pinned headers and against what that method's bridge function actually reaches.

#928, for #807. Ten of #807's twelve lane passes are still unwritten and the two that shipped
(#808, #809) could not produce the `over` verdict their own tables promised: their `classify()`
returns `ok`, `deliberate, recorded` or `under` and nothing else, so `over: 0` was a literal printed
beside three derived counts. Over-coverage was established instead by one hand read-through per
lane, which is the failure mode #807 exists to end: this repo's censuses were rebuilt by hand and
"wrong differently each time" (#558, #571, #573, #583, #595, #507, #553, #562).

## The question this asks

Docs attribute each documented method to an OCCT class:

    - **OCCT:** `BRepPrimAPI_MakeHalfSpace` / `BRepBuilderAPI_MakeSolid`
      (via `OCCTShapeExtrudeSemiInfinite`).

Two things are checkable about that claim without reading anything:

  1. **Does the class exist in the pinned kernel at all?** A class that moved or vanished in a
     version bump is over-coverage by #807's own definition.
  2. **Does the bridge function implementing that method reach the class?** The claim above names
     `BRepPrimAPI_MakeHalfSpace`; `OCCTShapeExtrudeSemiInfinite` runs `BRepPrimAPI_MakePrism`. Seventeen
     of #808's twenty-six confirmed findings are exactly that shape.

Neither existing walker asks it. `check-docs-existence.py` walks docs to `Sources/OCCTSwift` and
cannot see an OCCT class at all; `check-bridge-index.py` walks `OCCTBridge.h`'s hand-maintained
index to bridge symbols and never reads `docs/`. What was missing is the docs -> OCCT class ->
bridge implementation link, and this script is that link. It borrows
`check-bridge-index.py`'s `reachable()` outright rather than writing a third reachability walker:
that function already resolves the four indirections this bridge uses (wrapper-type fields,
file-local and shared helpers, `Foo::Bar` static facades, transitively), each of which was added
because a checker blind to it reports correct entries as wrong (#510, #565, #624).

## Three channels, because the claims are written three ways

  A. `- **OCCT:** ...` bullets under a reference page's `###` heading. 4,029 of them, the bulk.
  B. `///` doc comments in `Sources/OCCTBridge/include/*.h`, attached to the declaration below.
     #808's finding 3 lives only here (a comment promising a `BRepBuilderAPI_EdgeError` its own
     function cannot return).
  C. Two-column `| swift | OCCT |` table rows, the shape `docs/API_REFERENCE.md` uses. #808's
     finding 4 lives only here, and its sibling row four hundred lines down was already correct,
     which is why a per-page read missed it.

## How a claim is resolved to a bridge function

Explicitly when it names one (`(via \`OCCTShapeQuilt\`)`, `` `OCCTMeshFaceIterCreate` -> ... ``),
which 1,574 of the 4,029 bullets do. Otherwise through the enclosing heading's Swift member name,
looked up in a member -> bridge-symbol index built from `Sources/OCCTSwift/*.swift`. That index is
keyed on the bare member name, so `distance` resolves to the union over every type declaring one.
That is deliberately permissive: the union can only make a claim look reachable, never unreachable,
so it trades recall for a false-positive rate low enough to read.

A claim resolving to no bridge function at all is **unresolved**, counted and reported separately,
never silently dropped. A detector that skips what it cannot parse reports zero for two different
reasons (#510).

## What it does not catch, stated plainly

Not "the class is reached but the wrong METHOD of it is named" (`gp_Trsf::VectorialPart` passes
because `gp_Trsf` is reached), not a class reached through an accessor chain whose type is never
spelled (`g->graph.Editor().Faces()` never writes `BRepGraph_EditorView`), not a base-class virtual
called on a subclass-typed field, and not a claim whose subject the heading resolves wrongly. Each
is a measured false-positive category, not a guess:
`Scripts/repro/928-over-coverage-detector/README.md` has the caught/missed split against #808's
twenty-six and #809's six, the forty-row adjudicated sample behind the false-positive rate, and one
worked example of every category above. This is a floor on the over-coverage in a lane, never a
proof there is none.

## Report, not gate

Exits 0 whether or not it finds anything, like `census-unmeasured-values.py`: the output is a list
of sites for a human to adjudicate. `--self-test` is what CI holds it to, since a bare run could
never fail and so could never signal. Promoting it to a gate is a separate decision on the measured
false-positive rate, and it comes with a rename to `check-` per this repo's own convention.

## The pinned headers, not the refman

Class existence is asked of `Libraries/OCCT.xcframework/macos-arm64/Headers/*.hxx`, CLAUDE.md's
designated source of truth for version-sensitive detail, never of the `occt-refman` cache through
the `context` MCP. A live MCP call is not reproducible in CI and cannot be diffed; the headers are
local, deterministic, and are what the bridge actually compiles against. `Libraries/` is absent in
CI and in a fresh clone, so the existence check reports SKIPPED there rather than passing silently,
and the attribution check (the one that catches 25 of #808's 26 and all 6 of #809's) runs everywhere
off a committed 5 KB package manifest, `Scripts/occt-packages.txt`, re-derivable with
`--reverify-packages`.

Usage (from anywhere; paths derive from this file's location):

    python3 Scripts/census-doc-occt-attribution.py                    # the census
    python3 Scripts/census-doc-occt-attribution.py --self-test        # the fixture battery
    python3 Scripts/census-doc-occt-attribution.py --verbose          # also list unresolved claims
    python3 Scripts/census-doc-occt-attribution.py --lane gp_,GC_     # restrict to a #807 lane
    python3 Scripts/census-doc-occt-attribution.py --sample 40        # a reproducible sample
    python3 Scripts/census-doc-occt-attribution.py --reverify-packages
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCRIPTS = os.path.join(ROOT, "Scripts")
DOCS = os.path.join(ROOT, "docs")
SWIFT_DIR = os.path.join(ROOT, "Sources", "OCCTSwift")
BRIDGE_INC = os.path.join(ROOT, "Sources", "OCCTBridge", "include")
OCCT_HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")
PACKAGE_MANIFEST = os.path.join(SCRIPTS, "occt-packages.txt")

# `docs/CHANGELOG.md` and `docs/SEMVER.md` are append-only ledgers narrating what past releases
# changed, so they legitimately name classes a past version attributed and this one does not.
# Same carve-out `check-docs-existence.py` makes, for the same reason.
EXCLUDED_DOCS = {"docs/CHANGELOG.md", "docs/SEMVER.md"}


# ---------------------------------------------------------------------------------------------
# Claim text: which part of it is an attribution
# ---------------------------------------------------------------------------------------------

# A claim routinely names a class in order to say it is NOT the one running. The corrections #808
# and #809 wrote are themselves the clearest examples: "corrected from a stale
# `GCE2d_MakeArcOfCircle` attribution by #809", and "`TopExp_Explorer` is the class that does NOT
# deduplicate". Reading those as attributions is the single largest false-positive source on the
# real corpus, and the two examples need opposite handling, which is why there are two marker sets
# rather than one:
#
#   CLAUSE-SCOPE. The clause is ABOUT a wrong or historical attribution, so every class in it is
#   commentary wherever it sits. `TopExp_Explorer` precedes its own "does NOT", so a positional cut
#   cannot reach it.
#
#   POSITIONAL. The clause makes a real attribution and then contrasts it, so only the tail is
#   commentary. "`BRepPrimAPI_MakeHalfSpace`, not `BRepPrimAPI_MakePrism`" must still report the
#   first, and a clause-scope rule would drop both.
#
# Claims are split into clauses on `;` and on a sentence-ending `. ` first, so one contrastive
# clause does not silence the attribution beside it.
CLAUSE_MARKERS = [
    "corrected from", "stale", "formerly", "previously", "superseded", "no longer", "used to",
    "does not", "doesn't", "do not", "is not", "are not", "was not", "were not", "never",
    "unlike", "in contrast", "as opposed to", "not the one", "not this", "deprecated",
    "misattribut", "wrongly", "incorrectly",
]
POSITIONAL_MARKERS = [
    " not ", " no ", " rather than ", " instead of ", " without ", " avoids ", " avoid ",
    " bypasses ", " bypass ", " cannot ", " can't ", " none of ", " despite ",
]
CLAUSE_SPLIT = re.compile(r";|(?<=[a-z)`])\.\s+(?=[A-Z`])")


def attribution_spans(text: str) -> list[str]:
    """The parts of a claim that actually attribute, clause by clause."""
    out = []
    for clause in CLAUSE_SPLIT.split(text):
        if not clause:
            continue
        low = clause.lower()
        if any(m in low for m in CLAUSE_MARKERS):
            continue
        cut = len(clause)
        padded = " " + clause + " "
        for marker in POSITIONAL_MARKERS:
            idx = padded.lower().find(marker)
            if idx != -1:
                cut = min(cut, max(0, idx - 1))
        out.append(clause[:cut])
    return out


# ---------------------------------------------------------------------------------------------
# Class tokens
# ---------------------------------------------------------------------------------------------

BACKTICK_SPAN = re.compile(r"`([^`\n]+)`")
# `BRepPrimAPI_MakeHalfSpace`, `gp_Pnt`, `BRep_Tool::IsClosed`, `TopExp::MapShapes(...)`.
CLASS_TOKEN = re.compile(
    r"\b(?P<pkg>[A-Za-z][A-Za-z0-9]*)(?:_(?P<rest>[A-Za-z][A-Za-z0-9_]*))?"
    r"(?:::(?P<member>[A-Za-z_][A-Za-z0-9_]*))?\b"
)
BRIDGE_SYMBOL = re.compile(r"\bOCCT[A-Za-z0-9_]+\*?")

# A `Prefix_Name` token whose prefix names no OCCT package is not a class: `Poly_Triangulation` is,
# `some_variable` is not. The prefix set is derived from the pinned headers and committed, so this
# distinction survives into CI where `Libraries/` is absent.
def load_packages() -> tuple[set[str], set[str]]:
    """(prefixes of `Prefix_Name.hxx` headers, package classes with no underscore)."""
    prefixes, bare = set(), set()
    if not os.path.exists(PACKAGE_MANIFEST):
        return prefixes, bare
    section = None
    for line in open(PACKAGE_MANIFEST, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#"):
            if line.startswith("# ["):
                section = line[3:-1]
            continue
        (prefixes if section == "prefixes" else bare).add(line)
    return prefixes, bare


# A name does not always own a header, and existence keyed on the directory listing is wrong in
# both directions. Measured on the pinned kernel: `BRepGraph_FacesOfEdge` and 40 more are declared
# inside a sibling header and were reported absent; `GeomAbs_Plane`, `STEPControl_AsIs` and
# `XCAFDoc_ColorSurf` are enumerators of a differently-named enum and were reported absent too.
# Narrowing to `class`/`struct`/`enum`/`using`/`typedef` declarations fixes the first and not the
# second. So existence asks the weaker, correct question: does this exact name occur anywhere in
# the pinned headers? A name that occurs nowhere is what #807 means by a class that moved or
# vanished, and nothing weaker than an occurrence is needed to rule that out.
OCCT_NAME_RE = re.compile(r"\b[A-Za-z][A-Za-z0-9]*_[A-Za-z][A-Za-z0-9_]*\b")


def derive_packages() -> tuple[set[str], set[str], set[str]]:
    """Re-derive from the bundled headers: (prefixes, bare package classes, every class name)."""
    prefixes, bare, names = set(), set(), set()
    if not os.path.isdir(OCCT_HEADERS):
        return prefixes, bare, names
    for fn in sorted(os.listdir(OCCT_HEADERS)):
        if not fn.endswith((".hxx", ".lxx")):
            continue
        name = fn[: -len(".hxx")]
        if fn.endswith(".hxx"):
            names.add(name)
            if "_" in name:
                prefixes.add(name.split("_", 1)[0])
            else:
                bare.add(name)
        with open(os.path.join(OCCT_HEADERS, fn), errors="ignore") as fh:
            names.update(OCCT_NAME_RE.findall(fh.read()))
    return prefixes, bare, names


def class_tokens(text: str, prefixes: set[str], bare: set[str],
                 quoted_only: bool = True) -> list[tuple[str, str | None]]:
    """Every OCCT class a claim's attribution span names, as (class, scoped-member-or-None).

    In markdown, only backtick-quoted text is read: the reference pages quote every class name,
    and the prose around them is full of ordinary English that a bare-word scan turns into
    candidates. A C header's `///` comment has no markdown, so channel B passes
    `quoted_only=False`; #808's finding 3 is written `the BRepBuilderAPI_EdgeError for the last
    MakeEdge`, unquoted, and the markdown rule cannot see it at all.
    """
    out, seen = [], set()
    spans = BACKTICK_SPAN.findall(text) if quoted_only else [text]
    for span in spans:
        for m in CLASS_TOKEN.finditer(span):
            pkg, rest, member = m.group("pkg"), m.group("rest"), m.group("member")
            if rest is not None:
                if pkg not in prefixes:
                    continue
                # `TopAbs_EDGE`, `GeomAbs_C1`, `BOPAlgo_CUT`: an enum VALUE, spelled with an
                # all-uppercase tail, is a parameter a method passes, not a class it is
                # implemented by. No header declares one, so leaving them in reports every
                # correct `TopExp::MapShapes(shape, TopAbs_EDGE)` as naming an absent class.
                tail = rest.rsplit("_", 1)[-1]
                if len(tail) >= 2 and tail.isupper():
                    continue
                cls = f"{pkg}_{rest}"
            else:
                # A bare package name (`Precision`, `TopExp`, `BRepTools`) is only ever read out
                # of backticked text. Unquoted, it collides with the English word: a bridge
                # header's `@param tolerance Precision for fixing` is not an attribution to
                # `Precision.hxx`, and the same is true of `Bisector`, `Draft` and `Law`.
                if not quoted_only or pkg not in bare:
                    continue
                cls = pkg
            key = (cls, member)
            if key not in seen:
                seen.add(key)
                out.append(key)
    return out


# ---------------------------------------------------------------------------------------------
# Swift member -> bridge symbols
# ---------------------------------------------------------------------------------------------

SWIFT_DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*"
    r"(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?"
    r"(?:static\s+|class\s+|final\s+|lazy\s+|mutating\s+|nonisolated(?:\([^)]*\))?\s+"
    r"|override\s+|convenience\s+|required\s+|discardableResult\s+)*"
    r"(?:func|var|init|subscript)\b"
)
SWIFT_NAME = re.compile(r"\b(?:func|var)\s+`?([A-Za-z_][A-Za-z0-9_]*)`?|\b(init|subscript)\b")


def swift_member_symbols() -> dict[str, set[str]]:
    """Bare Swift member name -> every `OCCT*` symbol named inside its declaration.

    Keyed on the bare name, not `(type, member)`: a reference page's heading is often bare
    (`### \\`divided(at:tolerance:)\\``) and the pages resolve their owning type two incompatible
    ways, which `check-docs-existence.py` measured directly and had to relax for the same reason.
    The union over every type declaring a name is permissive, and permissive is the safe direction
    here: it can only make an attribution look reachable, never unreachable.
    """
    index: dict[str, set[str]] = {}
    for dirpath, _dirs, filenames in os.walk(SWIFT_DIR):
        for fn in sorted(filenames):
            if not fn.endswith(".swift"):
                continue
            lines = open(os.path.join(dirpath, fn), errors="ignore").read().split("\n")
            for i, line in enumerate(lines):
                if not SWIFT_DECL.match(line):
                    continue
                m = SWIFT_NAME.search(line)
                if not m:
                    continue
                name = m.group(1) or m.group(2)
                # The opening brace is often on a later line than the declaration keyword: a
                # multi-line signature (`public static func setUVPoints(edge:face:` ...) is the
                # normal shape in this tree, and stopping at the first line drops the whole body,
                # which is how `setUVPoints` first came back with no bridge symbol at all.
                j, limit = i, min(len(lines), i + 12)
                while j < limit and "{" not in lines[j]:
                    j += 1
                body, depth = [], 0
                # No brace within the signature window means a stored property or a bodiless
                # requirement, which calls nothing. Scanning on regardless is what credited
                # `vector2DMagnitude` with four unrelated `OCCTChFi2d*` symbols from the code
                # below it, and a claim checked against the wrong function's reach set is a
                # finding invented rather than found.
                if j < limit and "{" in lines[j]:
                    k, opened = j, False
                    while k < len(lines) and k - j < 400:
                        body.append(lines[k])
                        depth += lines[k].count("{") - lines[k].count("}")
                        opened = opened or "{" in lines[k]
                        # The close is on its own line for all but a one-liner, so the balance
                        # test cannot also require a brace on the current line. Requiring it ran
                        # every accessor's capture on to the 400-line cap and credited
                        # `maxEdgeTolerance` with eight unrelated `OCCTBRepTool*` symbols, which
                        # is what hid #808's finding 16 behind a reach set it never had.
                        if opened and depth <= 0:
                            break
                        k += 1
                # Scanning continues from i + 1, deliberately: a nested declaration inside this
                # body is its own entry too, and skipping past the block dropped every one of
                # them. Measured, that skip is what left `Edge.normal` resolving to the mesh
                # iterator's `normal` instead of its own bridge call.
                index.setdefault(name, set()).update(
                    BRIDGE_SYMBOL.findall("\n".join([line] + body))
                )
    return index


# ---------------------------------------------------------------------------------------------
# Bridge reachability, borrowed from check-bridge-index.py
# ---------------------------------------------------------------------------------------------


def bridge_reach() -> dict[str, set[str]]:
    """`check-bridge-index.py`'s reachability, used as-is.

    That script expands a function's reach through its OWN file's helpers plus the shared
    `OCCTBridge_Internal.h`, and stops there. Its question is the mirror image of this one (does
    this index entry name a symbol that wraps this class), so the scoping is conservative in the
    opposite direction and an unfollowed cross-file helper invents a finding here rather than
    hiding one. `occtPlateApproxSurface` is the measured case: defined in
    `OCCTBridge_ProjLib_NLPlate.mm`, called from `OCCTBridge_Healing.mm`, and every
    `GeomPlate_MakeApprox` attribution on a plate entry is reported for that reason alone.

    Widening it anyway was built and measured, and is NOT kept. Against the 40-row adjudicated
    sample and the 32 known findings together:

        no widening          31/32 known caught, false-positive rate 41.0%, 493 findings
        helpers only         29/32 known caught, false-positive rate 39.5%, 488 findings
        every callee         29/32 known caught, false-positive rate 37.8%, 483 findings

    Both widenings lose `Shape.moved -> BRepBuilderAPI_Transform` and
    `mergedMeshNodes -> BRep_Builder`, two findings #808 confirmed by reading the code, to buy one
    or two percentage points. The mechanism is that `reachable()`'s per-function name set holds
    every identifier in the body, not only the functions it calls, so a local variable sharing a
    name with a helper drags that helper's whole reach in. Recall against a validation set built
    by hand is the criterion here, and it is the one measurement not drawn from this script's own
    output.
    """
    spec = importlib.util.spec_from_file_location(
        "_cbi", os.path.join(SCRIPTS, "check-bridge-index.py")
    )
    cbi = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cbi)
    cwd = os.getcwd()
    os.chdir(ROOT)   # check-bridge-index.py resolves Sources/OCCTBridge relative to the cwd
    try:
        return cbi.reachable()
    finally:
        os.chdir(cwd)


def expand_targets(named: list[str], reach: dict[str, set[str]]) -> set[str]:
    """`OCCTShapeFill*` covers every symbol starting with the prefix; a bare name covers itself."""
    out = set()
    for sym in named:
        if sym.endswith("*"):
            out |= {k for k in reach if k.startswith(sym[:-1])}
        elif sym in reach:
            out.add(sym)
    return out


# ---------------------------------------------------------------------------------------------
# Claims
# ---------------------------------------------------------------------------------------------

class Claim:
    __slots__ = ("path", "line", "channel", "text", "subject", "named")

    def __init__(self, path, line, channel, text, subject, named):
        self.path = path
        self.line = line
        self.channel = channel
        self.text = text
        self.subject = subject      # the Swift member name, when one could be resolved
        self.named = named          # bridge symbols the claim itself names


OCCT_BULLET = re.compile(r"^(\s*)-\s*\*\*OCCT:?\*\*:?\s*(.*)$")
HEADING = re.compile(r"^(#{2,6})\s+(.*?)\s*$")
FENCE = re.compile(r"^\s*```")
TABLE_ROW = re.compile(r"^\s*\|(?P<cells>.+)\|\s*$")


def _member_of(heading_text: str) -> str | None:
    """`\\`Shape.uniqueEdgeCount\\`` -> `uniqueEdgeCount`; `\\`divided(at:)\\`` -> `divided`."""
    m = re.match(r"^`([^`]+)`", heading_text.strip())
    if not m:
        return None
    body = m.group(1).split("(")[0].strip()
    body = body.split("—")[0].split("–")[0].strip()
    if not body:
        return None
    tail = body.rsplit(".", 1)[-1]
    return tail if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", tail) else None


def gather_continuation(lines: list[str], j: int, indent: int, text: str) -> tuple[str, int]:
    """A wrapped bullet, joined into one claim, and the line after it.

    A separate function so the self-test's removal matrix has a seam to disable: reading only the
    first physical line splits a claim in half and hides whichever class landed on the second, and
    that is a defect no case can prove without being able to turn the joining off.
    """
    while j < len(lines):
        nxt = lines[j]
        if not nxt.strip() or FENCE.match(nxt):
            break
        stripped = nxt.lstrip()
        if stripped.startswith(("-", "#", "|")):
            break
        if len(nxt) - len(stripped) <= indent:
            break
        text += " " + stripped
        j += 1
    return text, j


def attribution_names(cls: str, member: str | None) -> set[str]:
    """The spellings that satisfy an attribution to `cls` (`::member` included, if given).

    `TopExp::MapShapes` is reached by a bridge body writing exactly that, which
    `check-bridge-index.py` records as both the bare `TopExp` and the joined `TopExp_MapShapes`
    (its `SCOPED` rule). Accepting only the bare name would report every correct facade
    attribution in the corpus, so both spellings count. A separate function for the same reason as
    `gather_continuation`: the removal matrix needs to be able to take the rule away.
    """
    return {cls} | ({f"{cls}_{member}"} if member else set())


def doc_claims(paths: list[str]) -> list[Claim]:
    """Channel A (`- **OCCT:**` bullets) and channel C (two-column `| swift | OCCT |` rows)."""
    claims = []
    for path in paths:
        rel = os.path.relpath(path, ROOT)
        lines = open(path, errors="ignore").read().split("\n")
        fenced = False
        subject = None
        i = 0
        while i < len(lines):
            line = lines[i]
            if FENCE.match(line):
                fenced = not fenced
                i += 1
                continue
            if fenced:
                i += 1
                continue

            h = HEADING.match(line)
            if h:
                got = _member_of(h.group(2))
                if got:
                    subject = got
                i += 1
                continue

            b = OCCT_BULLET.match(line)
            if b:
                indent, body = len(b.group(1)), b.group(2)
                text, j = gather_continuation(lines, i + 1, indent, body)
                claims.append(
                    Claim(rel, i + 1, "bullet", text, subject, BRIDGE_SYMBOL.findall(text))
                )
                i = j
                continue

            t = TABLE_ROW.match(line)
            if t:
                cells = [c.strip() for c in t.group("cells").split("|")]
                if len(cells) == 2 and not set(cells[1]) <= set("-: "):
                    swift, occt = cells
                    names = re.findall(r"`([^`]+)`", swift)
                    member = None
                    for n in names:
                        cand = _member_of(f"`{n}`")
                        if cand:
                            member = cand
                            break
                    claims.append(
                        Claim(rel, i + 1, "table", occt, member, BRIDGE_SYMBOL.findall(occt))
                    )
                i += 1
                continue
            i += 1
    return claims


DOC_COMMENT = re.compile(r"^\s*///\s?(.*)$")
DECL_NAME = re.compile(r"\b(OCCT[A-Za-z0-9_]+)\s*\(")


def bridge_header_claims() -> list[Claim]:
    """Channel B: a `///` block in a bridge header, attributed to the declaration under it."""
    claims = []
    for fn in sorted(os.listdir(BRIDGE_INC)):
        if not fn.endswith(".h"):
            continue
        path = os.path.join(BRIDGE_INC, fn)
        rel = os.path.relpath(path, ROOT)
        lines = open(path, errors="ignore").read().split("\n")
        block, start = [], None
        for idx, line in enumerate(lines):
            m = DOC_COMMENT.match(line)
            if m:
                if start is None:
                    start = idx + 1
                block.append(m.group(1))
                continue
            if block:
                d = DECL_NAME.search(line)
                if d:
                    claims.append(
                        Claim(rel, start, "header-doc", " ".join(block), None, [d.group(1)])
                    )
                block, start = [], None
        # A trailing block with no declaration under it attributes nothing and is dropped.
    return claims


# ---------------------------------------------------------------------------------------------
# The census
# ---------------------------------------------------------------------------------------------

class Finding:
    __slots__ = ("claim", "cls", "member", "kind", "targets", "how")

    def __init__(self, claim, cls, member, kind, targets, how="explicit"):
        self.claim = claim
        self.cls = cls
        self.member = member
        self.kind = kind          # 'absent' (not in the pinned headers) or 'unreached'
        self.targets = targets
        # 'explicit' when the claim names its own bridge symbol, 'heading' when the symbol came
        # from the enclosing heading's Swift member. The two are separate confidence tiers and
        # their false-positive rates were measured separately; see the PR body for #928.
        self.how = how


def run(claims, reach, member_syms, prefixes, bare, header_names, lane=None):
    findings, unresolved = [], []
    checked = 0
    for claim in claims:
        tokens = []
        seen = set()
        quoted_only = claim.channel != "header-doc"
        for span in attribution_spans(claim.text):
            for tok in class_tokens(span, prefixes, bare, quoted_only):
                if tok not in seen:
                    seen.add(tok)
                    tokens.append(tok)
        if not tokens:
            continue

        targets = expand_targets(claim.named, reach)
        how = "explicit"
        if not targets and claim.subject:
            targets = expand_targets(sorted(member_syms.get(claim.subject, ())), reach)
            how = "heading"
        if not targets:
            unresolved.append(claim)
            continue

        reached = set()
        for t in targets:
            reached |= reach.get(t, set())

        for cls, member in tokens:
            if lane and not any(cls.startswith(p) for p in lane):
                continue
            checked += 1
            if header_names is not None and cls not in header_names:
                findings.append(Finding(claim, cls, member, "absent", sorted(targets), how))
                continue
            if attribution_names(cls, member) & reached:
                continue
            findings.append(Finding(claim, cls, member, "unreached", sorted(targets), how))
    return findings, unresolved, checked


def in_scope_docs() -> list[str]:
    out = []
    for dirpath, _dirs, filenames in os.walk(DOCS):
        for fn in sorted(filenames):
            if not fn.endswith(".md"):
                continue
            path = os.path.join(dirpath, fn)
            if os.path.relpath(path, ROOT) in EXCLUDED_DOCS:
                continue
            out.append(path)
    readme = os.path.join(ROOT, "README.md")
    if os.path.exists(readme):
        out.append(readme)
    return sorted(out)


def write_manifest(prefixes: set[str], bare: set[str]) -> None:
    with open(PACKAGE_MANIFEST, "w", encoding="utf-8") as fh:
        fh.write("# OCCT package names, derived from the pinned kernel's own headers.\n")
        fh.write("# Re-derive: python3 Scripts/census-doc-occt-attribution.py --write-packages\n")
        fh.write("# Drift check: --reverify-packages (needs Libraries/, skipped in CI).\n")
        fh.write("# [prefixes]\n")
        for p in sorted(prefixes):
            fh.write(p + "\n")
        fh.write("# [bare]\n")
        for b in sorted(bare):
            fh.write(b + "\n")


# ---------------------------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------------------------

_FIXTURE_PREFIXES = {"BRepPrimAPI", "BRepBuilderAPI", "BRep", "TopExp", "Poly", "Geom2d", "gp"}
_FIXTURE_BARE = {"TopExp", "BRepTools", "ShapeCustom"}
_FIXTURE_HEADERS = {
    "BRepPrimAPI_MakeHalfSpace", "BRepPrimAPI_MakePrism", "BRepBuilderAPI_Sewing",
    "BRep_Tool", "BRep_Builder", "TopExp", "TopExp_Explorer", "BRepTools",
    "Poly_Triangulation", "Geom2d_Circle", "gp_Pnt", "ShapeCustom",
}
_FIXTURE_REACH = {
    "OCCTShapeExtrudeSemiInfinite": {"BRepPrimAPI_MakePrism", "TopoDS_Shape"},
    "OCCTShapeUniqueEdgeCount": {"TopExp", "TopExp_MapShapes", "TopTools_IndexedMapOfShape"},
    "OCCTShapeQuilt": {"BRepTools_Quilt", "TopoDS_Shape"},
    "OCCTShapeUpdate": {"BRepTools", "BRepTools_Update"},
    "OCCTMakeEdgeError": {"BRepCheck_Analyzer", "TopoDS_Edge"},
    "OCCTShapeMaxEdgeTolerance": {"ShapeAnalysis_ShapeTolerance"},
    # Only the joined spelling, no bare package name. `check-bridge-index.py` records a `Foo::Bar`
    # call as both, so a real reach set nearly always carries both and cannot isolate the joined
    # one; this entry exists so a case can.
    "OCCTFacadeJoinedOnly": {"BRepTools_Update"},
}


def _self_test_case(name, claims, expect_classes, member_syms=None, headers=_FIXTURE_HEADERS):
    findings, unresolved, _checked = run(
        claims, _FIXTURE_REACH, member_syms or {}, _FIXTURE_PREFIXES, _FIXTURE_BARE, headers
    )
    got = sorted({f.cls for f in findings})
    want = sorted(expect_classes)
    ok = got == want
    print(f'  {"PASS" if ok else "FAIL"}  {name}')
    if not ok:
        print(f"          expected {want}")
        print(f"          got      {got}  (unresolved: {len(unresolved)})")
    return 0 if ok else 1


def self_test() -> int:
    bad = 0

    # 1. The shape #928 predicts: an explicitly-resolved claim naming a class the bridge function
    #    does not reach. Injected verbatim from #808's finding on `extrudedSemiInfinite`.
    bad += _self_test_case(
        "a class the named bridge function does not reach IS reported",
        [Claim("d.md", 1, "bullet",
               "`BRepPrimAPI_MakeHalfSpace` (via `OCCTShapeExtrudeSemiInfinite`).", None,
               ["OCCTShapeExtrudeSemiInfinite"])],
        ["BRepPrimAPI_MakeHalfSpace"],
    )

    # 2. The same claim corrected. Proves the detector is not simply reporting everything: a rule
    #    that flagged both would look identical to a working one on case 1 alone.
    bad += _self_test_case(
        "the corrected claim on the same method is NOT reported",
        [Claim("d.md", 1, "bullet",
               "`BRepPrimAPI_MakePrism` (via `OCCTShapeExtrudeSemiInfinite`).", None,
               ["OCCTShapeExtrudeSemiInfinite"])],
        [],
    )

    # 3. Resolution through the heading's Swift member, the path 2,455 of the 4,029 bullets need.
    #    Without the member index this claim resolves to nothing and lands in `unresolved`.
    bad += _self_test_case(
        "a claim with no bridge symbol resolves through its heading's Swift member",
        [Claim("d.md", 1, "bullet", "`BRep_Tool::MaxTolerance`.", "maxEdgeTolerance", [])],
        ["BRep_Tool"],
        member_syms={"maxEdgeTolerance": {"OCCTShapeMaxEdgeTolerance"}},
    )

    # 4. A scoped `Foo::Bar` facade call reaches through the `Foo_Bar` spelling too. Without this
    #    every correct `TopExp::MapShapes` attribution would be reported.
    bad += _self_test_case(
        "a `Package::Static` facade attribution resolves (no false positive)",
        [Claim("d.md", 1, "bullet", "`TopExp::MapShapes` (via `OCCTShapeUniqueEdgeCount`).",
               None, ["OCCTShapeUniqueEdgeCount"])],
        [],
    )

    # 4b. The other half of the facade rule, and the row that actually isolates it. Case 4's
    #     fixture reaches BOTH `TopExp` and `TopExp_MapShapes`, which is what a real reach set
    #     looks like (`check-bridge-index.py` records a `Foo::Bar` call as both), so removing the
    #     joined spelling leaves it passing on the bare one. This fixture reaches only the joined
    #     spelling, so the rule is the only thing standing between it and a finding.
    bad += _self_test_case(
        "a facade attribution resolves on the joined `Class_Member` spelling alone",
        [Claim("d.md", 1, "bullet", "`BRepTools::Update` (via `OCCTFacadeJoinedOnly`).", None,
               ["OCCTFacadeJoinedOnly"])],
        [],
    )

    # 5. The same method's WRONG attribution, one word different. Disjoint from case 4: the pair
    #    isolates "does the facade rule discriminate" from "does it merely pass everything".
    bad += _self_test_case(
        "`TopExp_Explorer` on a method that runs `TopExp::MapShapes` IS reported",
        [Claim("d.md", 1, "bullet",
               "`TopExp_Explorer` with `TopAbs_EDGE` (via `OCCTShapeUniqueEdgeCount`).",
               None, ["OCCTShapeUniqueEdgeCount"])],
        ["TopExp_Explorer"],
    )

    # 6. Negation. The corrections #808 and #809 wrote name the wrong class on purpose, and
    #    attributing that text is the largest false-positive source measured on the real corpus.
    bad += _self_test_case(
        "a class named after a negation marker is commentary, not an attribution",
        [Claim("d.md", 1, "bullet",
               "`TopExp::MapShapes` (via `OCCTShapeUniqueEdgeCount`); `TopExp_Explorer` is the "
               "class that does NOT deduplicate.", None, ["OCCTShapeUniqueEdgeCount"])],
        [],
    )

    # 7. Negation must not swallow the attribution itself: a POSITIONAL marker cuts a suffix, so a
    #    claim whose wrong class sits BEFORE one is still reported. Without this row, moving a
    #    marker from POSITIONAL_MARKERS to CLAUSE_MARKERS until the corpus goes quiet would pass
    #    every other row.
    bad += _self_test_case(
        "a wrong class BEFORE a positional negation marker is still reported",
        [Claim("d.md", 1, "bullet",
               "`BRepPrimAPI_MakeHalfSpace`, not `BRepPrimAPI_MakePrism` "
               "(via `OCCTShapeExtrudeSemiInfinite`).", None, ["OCCTShapeExtrudeSemiInfinite"])],
        ["BRepPrimAPI_MakeHalfSpace"],
    )

    # 7b. And the mirror, which is what actually isolates POSITIONAL_MARKERS: the same sentence
    #     with the two classes swapped. Row 7 passes with the positional cut removed entirely
    #     (the tail class is reached, so it produces no finding either way), so it proves the
    #     clause rule is not over-firing and nothing else.
    bad += _self_test_case(
        "a class after a positional marker is commentary, not an attribution",
        [Claim("d.md", 1, "bullet",
               "`BRepPrimAPI_MakePrism`, not `BRepPrimAPI_MakeHalfSpace` "
               "(via `OCCTShapeExtrudeSemiInfinite`).", None, ["OCCTShapeExtrudeSemiInfinite"])],
        [],
    )

    # 8. A class absent from the pinned headers: #807's other over-coverage shape, a class that
    #    moved or vanished in a version bump. Reported even though the bridge cannot reach it
    #    either, and reported as `absent` rather than `unreached` so the two stay distinguishable.
    findings, _u, _c = run(
        [Claim("d.md", 1, "bullet", "`BRepPrimAPI_MakeVanished` (via `OCCTShapeQuilt`).",
               None, ["OCCTShapeQuilt"])],
        _FIXTURE_REACH, {}, _FIXTURE_PREFIXES, _FIXTURE_BARE, _FIXTURE_HEADERS,
    )
    ok = [(f.cls, f.kind) for f in findings] == [("BRepPrimAPI_MakeVanished", "absent")]
    print(f'  {"PASS" if ok else "FAIL"}  a class absent from the pinned headers is reported as absent')
    bad += 0 if ok else 1

    # 9. A token that is not an OCCT class at all. `some_variable` has the `Prefix_Name` shape and
    #    would be reported by a shape-only rule; the package manifest is what refuses it.
    bad += _self_test_case(
        "a `prefix_name` token whose prefix names no OCCT package is not a class",
        [Claim("d.md", 1, "bullet", "`some_variable` (via `OCCTShapeQuilt`).", None,
               ["OCCTShapeQuilt"])],
        [],
    )

    # 9b. An enum VALUE is a parameter a method passes, not a class it is implemented by, and no
    #     header declares one. Leaving them in reports every correct
    #     `TopExp::MapShapes(shape, TopAbs_EDGE)` as naming a class absent from the pinned kernel.
    findings, _u, _c = run(
        [Claim("d.md", 1, "bullet",
               "`TopExp::MapShapes(shape, TopAbs_EDGE)` (via `OCCTShapeUniqueEdgeCount`).",
               None, ["OCCTShapeUniqueEdgeCount"])],
        _FIXTURE_REACH, {}, _FIXTURE_PREFIXES | {"TopAbs"}, _FIXTURE_BARE, _FIXTURE_HEADERS,
    )
    ok = not findings
    print(f'  {"PASS" if ok else "FAIL"}  an all-caps enum value is not treated as a class')
    bad += 0 if ok else 1

    # 10. Only backtick-quoted text is read. Ordinary prose mentioning a class name unquoted is
    #     narration; treating it as an attribution reported 40+ extra sites on the real corpus.
    bad += _self_test_case(
        "an unquoted class name in prose is not an attribution",
        [Claim("d.md", 1, "bullet",
               "`BRepTools_Quilt` via `OCCTShapeQuilt`, similar to BRepPrimAPI_MakeHalfSpace.",
               None, ["OCCTShapeQuilt"])],
        [],
    )

    # 11. A claim that resolves to no bridge function is UNRESOLVED, not clean. A detector that
    #     drops what it cannot resolve reports zero for two different reasons (#510).
    findings, unresolved, _c = run(
        [Claim("d.md", 1, "bullet", "`BRepPrimAPI_MakeHalfSpace`.", "noSuchMember", [])],
        _FIXTURE_REACH, {}, _FIXTURE_PREFIXES, _FIXTURE_BARE, _FIXTURE_HEADERS,
    )
    ok = not findings and len(unresolved) == 1
    print(f'  {"PASS" if ok else "FAIL"}  an unresolvable claim is counted unresolved, not clean')
    bad += 0 if ok else 1

    # 12. Channel B: a bridge header `///` comment, attributed to the declaration below it. This
    #     is the only channel #808's finding 3 appears in, and it is exercised through the real
    #     header parser: passing a hand-built Claim with `channel="header-doc"` proves the rule and
    #     nothing about the parser that has to produce one.
    header_text = ("/// Get the last vertex point of an edge.\n"
                   "void OCCTEdgeVertex2(OCCTShapeRef edge);\n\n"
                   "/// Get the BRepBuilderAPI_EdgeError for the last MakeEdge (0=done).\n"
                   "int32_t OCCTMakeEdgeError(OCCTShapeRef edge);\n")
    bad += _self_test_case(
        "channel B: a bridge header doc comment is attributed to the declaration below it",
        bridge_header_claims_from_text("OCCTBridge_X.h", header_text),
        ["BRepBuilderAPI_EdgeError"],
        headers=_FIXTURE_HEADERS | {"BRepBuilderAPI_EdgeError"},
    )

    # 13. Channel C: a two-column table row, resolved through its own Swift cell, again through the
    #     real parser. #808's finding 4 appears only here, and its correct sibling row sat four
    #     hundred lines down in the same file, which is why a per-page read missed it.
    table_text = ("| Swift | OCCT |\n|---|---|\n"
                  "| `shape.edgeCount` | `TopExp_Explorer` |\n")
    bad += _self_test_case(
        "channel C: a two-column table row resolves through its Swift cell",
        doc_claims_from_text("API_REFERENCE.md", table_text),
        ["TopExp_Explorer"],
        member_syms={"edgeCount": {"OCCTShapeUniqueEdgeCount"}},
    )

    # 13b. Clause splitting. Without it a contrastive tail silences the attribution beside it:
    #      this claim's first clause names a class the function does not reach, and its second
    #      says the entry was corrected, so treating the whole bullet as one clause drops both.
    bad += _self_test_case(
        "a contrastive clause does not silence the attribution beside it",
        [Claim("d.md", 1, "bullet",
               "`BRepPrimAPI_MakeHalfSpace` (via `OCCTShapeExtrudeSemiInfinite`); corrected from "
               "an earlier stale attribution.", None, ["OCCTShapeExtrudeSemiInfinite"])],
        ["BRepPrimAPI_MakeHalfSpace"],
    )

    # 14. The parser, not the rule: a wrapped bullet's second physical line carries the class.
    #     Reading one line at a time drops it, and the case would report clean.
    lines = [
        "- **OCCT:** `BRepPrimAPI_MakePrism` and",
        "  `BRepPrimAPI_MakeHalfSpace` (via `OCCTShapeExtrudeSemiInfinite`).",
    ]
    got = doc_claims_from_text("d.md", "\n".join(lines))
    ok = len(got) == 1 and "BRepPrimAPI_MakeHalfSpace" in got[0].text
    print(f'  {"PASS" if ok else "FAIL"}  a wrapped bullet is read as one claim, both lines')
    bad += 0 if ok else 1

    # 15. The parser again: a fenced code block is not prose. A ```swift example naming a class
    #     is illustration, and its `- **OCCT:**`-shaped lines are not claims.
    text = "```swift\n- **OCCT:** `BRepPrimAPI_MakeHalfSpace`\n```\n"
    ok = doc_claims_from_text("d.md", text) == []
    print(f'  {"PASS" if ok else "FAIL"}  a fenced block yields no claims')
    bad += 0 if ok else 1

    # 16. The heading tracker: a `###` heading sets the subject for the bullets under it, and a
    #     later heading replaces it. A tracker that never updated would attribute every bullet in
    #     a page to its first method.
    text = ("### `Shape.alpha()`\n\n- **OCCT:** `BRep_Tool`.\n\n"
            "### `Shape.beta()`\n\n- **OCCT:** `BRep_Tool`.\n")
    got = doc_claims_from_text("d.md", text)
    ok = [c.subject for c in got] == ["alpha", "beta"]
    print(f'  {"PASS" if ok else "FAIL"}  each bullet takes the subject of its own heading')
    bad += 0 if ok else 1

    total = 20
    print(f"\nself-test: {total - bad} passed, {bad} failed")
    return bad


def doc_claims_from_text(rel: str, text: str) -> list[Claim]:
    """`doc_claims` over an in-memory page, for the self-test's parser rows."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, os.path.basename(rel))
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return doc_claims([path])


def bridge_header_claims_from_text(rel: str, text: str) -> list[Claim]:
    """`bridge_header_claims` over an in-memory header, for the self-test's channel-B row."""
    import tempfile
    global BRIDGE_INC
    saved = BRIDGE_INC
    with tempfile.TemporaryDirectory() as d:
        with open(os.path.join(d, os.path.basename(rel)), "w", encoding="utf-8") as fh:
            fh.write(text)
        BRIDGE_INC = d
        try:
            return bridge_header_claims()
        finally:
            BRIDGE_INC = saved


# ---------------------------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--self-test", action="store_true",
                    help="run the fixture battery instead of scanning the tree")
    ap.add_argument("--verbose", action="store_true", help="also list unresolved claims")
    ap.add_argument("--lane", default=None,
                    help="restrict findings to classes starting with any of these comma-separated "
                         "prefixes, which is how a #807 lane is expressed "
                         "(#808: TopoDS,TopExp,TopTools,BRep_,BRepBuilderAPI,BRepPrimAPI,"
                         "BRepAlgoAPI,BRepCheck; #809: gp_,BRepExtrema_,BRepClass,GC_,GCE2d_)")
    ap.add_argument("--sample", type=int, default=0, metavar="N",
                    help="print a reproducible random sample of N findings with their claim text, "
                         "for hand adjudication (this is how the false-positive rate was measured)")
    ap.add_argument("--seed", type=int, default=928, help="the sample's seed")
    ap.add_argument("--reverify-packages", action="store_true",
                    help="re-derive Scripts/occt-packages.txt from the bundled headers and diff")
    ap.add_argument("--write-packages", action="store_true",
                    help="rewrite Scripts/occt-packages.txt from the bundled headers")
    args = ap.parse_args()

    if args.self_test:
        return 1 if self_test() else 0

    if args.write_packages:
        prefixes, bare, _names = derive_packages()
        if not prefixes:
            print(f"{OCCT_HEADERS} not present; cannot derive.")
            return 1
        write_manifest(prefixes, bare)
        print(f"wrote {os.path.relpath(PACKAGE_MANIFEST, ROOT)}: "
              f"{len(prefixes)} prefixes, {len(bare)} bare package classes")
        return 0

    prefixes, bare = load_packages()
    derived_prefixes, derived_bare, header_names = derive_packages()
    have_headers = bool(header_names)

    if args.reverify_packages:
        if not have_headers:
            print(f"Package re-derivation SKIPPED: {OCCT_HEADERS} not present "
                  "(the normal case in CI and a fresh clone).")
            return 0
        drift = (derived_prefixes ^ prefixes) | (derived_bare ^ bare)
        if drift:
            print("PACKAGE DRIFT: Scripts/occt-packages.txt no longer matches the pinned headers:")
            for name in sorted(drift):
                where = "headers only" if name in (derived_prefixes | derived_bare) else "manifest only"
                print(f"  {name} ({where})")
            print("  Re-run with --write-packages, and re-read any claim naming a removed package.")
            return 1
        print(f"Package manifest clean: {len(prefixes)} prefixes, {len(bare)} bare classes.")
        return 0

    reach = bridge_reach()
    member_syms = swift_member_symbols()
    claims = doc_claims(in_scope_docs()) + bridge_header_claims()
    lane = [p for p in args.lane.split(",") if p] if args.lane else None
    findings, unresolved, checked = run(
        claims, reach, member_syms, prefixes, bare,
        header_names if have_headers else None, lane=lane
    )

    by_channel: dict[str, int] = {}
    for c in claims:
        by_channel[c.channel] = by_channel.get(c.channel, 0) + 1

    print("census: OCCT class attributions in docs, against the pinned headers and the bridge")
    print(f"  claims parsed            : {len(claims)}  "
          + ", ".join(f"{k} {v}" for k, v in sorted(by_channel.items())))
    print(f"  class attributions checked: {checked}")
    print(f"  unresolved (no bridge fn) : {len(unresolved)}")
    if have_headers:
        print(f"  pinned headers            : {len(header_names)} classes, existence checked")
    else:
        print(f"  pinned headers            : {OCCT_HEADERS} absent, existence check SKIPPED")
    print(f"  findings                  : {len(findings)}")

    absent = [f for f in findings if f.kind == "absent"]
    unreached = [f for f in findings if f.kind == "unreached"]
    def _via(f):
        head = ",".join(f.targets[:3])
        return head + (f" (+{len(f.targets) - 3})" if len(f.targets) > 3 else "")

    if args.sample:
        import random
        rng = random.Random(args.seed)
        pool = list(findings)
        pool.sort(key=lambda f: (f.claim.path, f.claim.line, f.cls))   # a stable order to seed on
        for f in rng.sample(pool, min(args.sample, len(pool))):
            print(f"\n--- {f.claim.path}:{f.claim.line}  [{f.kind}/{f.how}/{f.claim.channel}]")
            print(f"    class   : {f.cls}{'::' + f.member if f.member else ''}")
            print(f"    subject : {f.claim.subject or '-'}")
            print(f"    via     : {_via(f)}")
            print(f"    claim   : {f.claim.text[:300]}")
        return 0

    if absent:
        print("\nABSENT from the pinned headers (the class the doc names does not exist):")
        for f in absent:
            print(f"  {f.claim.path}:{f.claim.line}  {f.cls}"
                  f"{'::' + f.member if f.member else ''}  [{f.claim.channel}/{f.how}]")
    if unreached:
        print("\nUNREACHED (the class exists, but the bridge function implementing this method "
              "does not reach it):")
        for f in unreached:
            subject = f.claim.subject or "-"
            print(f"  {f.claim.path}:{f.claim.line}  {f.cls}"
                  f"{'::' + f.member if f.member else ''}"
                  f"  [{f.how}]  subject={subject}  via={_via(f)}")
    for tier in ("explicit", "heading"):
        n = sum(1 for f in findings if f.how == tier)
        print(f"\n  findings resolved {tier}: {n}")
    if args.verbose and unresolved:
        print("\nUNRESOLVED (a claim naming a class, with no bridge function to check it against):")
        for c in unresolved:
            print(f"  {c.path}:{c.line}  subject={c.subject or '-'}  {c.text[:90]}")

    print("\nThis is a REPORT, not a gate: it exits 0 either way, and every finding needs a human "
          "read before it is a defect.")
    print("A clean run is a floor, not a proof: see the module docstring for the shapes it "
          "cannot see.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
