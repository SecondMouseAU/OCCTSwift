#!/usr/bin/env python3
r"""Verify that every symbol `docs/` documents as current API still exists in `Sources/OCCTSwift`.

#802: the v2.0.0 release removes 62 deprecated symbols (#784/PR #798) and renames or replaces
several more. During that PR two stale reference pages were found only by a reviewer reading
closely: `BRepGraph-Editor-Identity.md` showed a live-looking `@available(*, deprecated) public var
generation` signature for a property the same PR deleted, and `FeatureRecognition.md` described a
call two separate PRs had already replaced. Nothing else in this repo's `Scripts/` checks
existence; `check-docs-defaults.py` checks that a documented *default* matches its declaration, but
only after already resolving the doc entry to a live declaration, so a symbol that no longer has
one is invisible to it, not a false pass.

## The trap this script exists to not fall into

A name-only grep produces false positives in both directions once a rename shares a bare word with
something still live: `ShapeContentsExtended.nbEdges` and `Curve2D.fromCircleArc` are real, current
symbols whose bare member name (`nbEdges`) or prefix (`fromCircle`) collides with a *removed* one
(`Shape.nbEdges`, `Conic2D.fromCircle`). A checker keyed on the bare word alone cannot tell
`ShapeContentsExtended.nbEdges` (fine) from `Shape.nbEdges` (gone) apart, or `Curve2D.fromCircleArc`
(fine) from a substring match against `fromCircle` (gone, and on a different type entirely).

So every check here is keyed on the exact **(owning type, member name)** pair, resolved the same
way `check-docs-defaults.py` resolves one: never on the member name alone.

## Two channels

1. **Backtick-quoted `###`-`######` headings** (`### \`AAG.detectHoles()\``, `### \`generation\``).
   This is the reference pages' own convention for "this heading declares a symbol", verified
   against all 65 pages: every prose section heading at this depth is un-backticked
   (`### Queries`, `### Creation`); every backtick-quoted one names a real symbol. A **dotted**
   heading (`Type.member`) is checked strictly, type and member both, exactly as in "the trap"
   above. A **bare** heading (no dot, like `### \`shape\``, a stored-property page style) cannot be
   checked that strictly: real pages resolve their owning type two incompatible ways depending on
   file (a genuine type name, `## AAG`, or a `// MARK:`-style group label, `## Properties`,
   `## Evaluation`, reused verbatim across many files for many types), and several pages
   (`Document-Analysis-Builders.md`, `Document-Math-Bounds.md`, ...) are grab-bag completions pages
   whose filename names none of the types they document. Measured directly: resolving a bare
   heading's type via context/filename and requiring an exact match against THAT guess produced
   946 candidates on the real tree, and reading a sample showed the guess wrong nearly every time
   (`fixWireGaps`, real and live on `Shape`, resolved via filename to `Document` and reported
   stale). So a bare heading's existence is asked **globally**: does *any* live type (or the
   free-function namespace) have this exact member name, with the guessed type and a same-heading
   a same-heading dash-separated `Type[, Type...]` disambiguator suffix
   (`### \`distance(to:deflection:)\`, Wire, Edge, Face`)
   tried first, as a nicety, not a requirement. This cannot resurrect "the trap": a dotted mention
   is never downgraded to the global check.
   - `## H2` prose headings are *not* separately existence-checked, for the reason above: a
     genuine type and an OCCT C++ class named for background (`## Adaptor3d_IsoCurve`, not a Swift
     symbol at all) share the identical un-backticked convention, and nothing short of reading
     tells those apart. They are still harvested as *context*, one of several inputs into the
     global bare-member check above, never load-bearing alone.
2. **Inline `` `Type.member` `` mentions in prose**, anywhere in the scanned text outside a fenced
   block (`docs/reference/README.md`'s own authoring **template**, inside a ` ```markdown ` fence,
   would otherwise read as a real page and its literal placeholder `### \`Type.method(label:)\``
   as a stale symbol; any fence is skipped, not just ` ```swift `). This is what caught the two
   known misses' *sibling* shape: prose describing a call without giving it its own heading.
   Requires an explicit dot, so a plain backtick-quoted English word never becomes a candidate, and
   is checked as strictly as a dotted heading (never the relaxed global check above, since a
   fabricated dotted mention has no legitimate ambiguous-heading excuse).

A member declaration is extracted regardless of its access level (`public`, `internal`, `private`).
Existence, not visibility, is the question here, and access-gating produces exactly the wrong
false positive: `Face.exactBounds` (`internal var`) and `FeatureRecognition.swift`'s `buildGraph()`
(`private func`) are both real, both correctly documented for context, and an access-level gate
would read both as "removed". It also sidesteps a trap in trying to gate on access at all:
`public private(set) var storage` is fully public to read, but a naive scan for the word `private`
finds it inside `private(set)` and would misclassify the whole line.

## What "removed" annotation suppresses, and why it does not just get skipped

A page that correctly documents a removal (`### \`generation\` *(removed in v2.0.0)*`, or prose
noting "removed at v2.0.0 (#784)") *mentions* a name this script's live index no longer contains.
That is correct, not drift, so a heading or sentence carrying an explicit removal/deprecation word
is excluded from failing the run, but still counted and reported (`--verbose`), not silently
dropped, so a reviewer can confirm the annotation is honest rather than trusting the absence of a
complaint.

## Scope

`docs/**/*.md` and `README.md`, excluding `docs/CHANGELOG.md` and `docs/SEMVER.md` (append-only
historical ledgers this project's own policy forbids a PR from editing, and which legitimately
narrate removed/renamed names in their own past tense: scanning them would be checking a diary for
using the past tense). `docs/occt-upgrades.md` is in scope: it is prose about OCCT kernel version
history, essentially no Swift symbol density, and excluding it would just be one more silent carve
-out to remember.

Usage (from the repo root):

    python3 Scripts/check-docs-existence.py                # report stale references
    python3 Scripts/check-docs-existence.py --self-test     # run the removal-matrix battery
    python3 Scripts/check-docs-existence.py --verbose       # also list acknowledged-historical and
                                                             # unresolved-context entries

Exit status is 1 when a stale reference is found, or when the unresolved-context bucket grows past
its pinned baseline (the same "growth is drift" convention `check-docs-defaults.py` uses for its
`unmatched` bucket). CI runs it, and its `--self-test`, in `ci.yml`'s `gate-scripts` job.
"""
import argparse
import glob
import os
import re
import sys

SRC_GLOB = 'Sources/OCCTSwift/*.swift'
DOC_GLOB = 'docs/**/*.md'
README = 'README.md'
EXCLUDED_DOCS = {'docs/CHANGELOG.md', 'docs/SEMVER.md'}

# Bare-context and inline-prose resolution sometimes cannot pin an owning type at all (a bare
# member heading under a purely prose H2, in a file whose name doesn't match any live type). Each
# is investigated once and either fixed (give the page a resolvable heading/context) or added here
# with a one-line reason. Growth beyond this is unreported drift the gate would otherwise miss
# silently, exactly the failure mode `check-docs-defaults.py`'s `EXPECTED_UNMATCHED` guards against.
EXPECTED_UNRESOLVED = 0

# --- shared skeleton/type-tracking machinery (same approach as check-docs-defaults.py) --------


def code_skeleton(line, in_block):
    """Blank out strings and comments so brace/keyword scanning sees only code."""
    out, i, in_str = [], 0, False
    while i < len(line):
        c = line[i]
        if in_block:
            if c == '*' and i + 1 < len(line) and line[i + 1] == '/':
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == '/' and i + 1 < len(line):
            if line[i + 1] == '/':
                break
            if line[i + 1] == '*':
                in_block = True
                i += 2
                continue
        out.append(c)
        i += 1
    return ''.join(out), in_block


# The name group allows a dot: `extension Shape.History {` is the only place Swift permits one,
# and it must be captured whole, not truncated at the dot, or the nested type never gets a
# `qualified` name distinct from its enclosing one.
TYPE_RE = re.compile(
    r'^\s*(?:public\s+|internal\s+|private\s+|fileprivate\s+|open\s+)?'
    r'(?:final\s+|indirect\s+)*(?P<kind>extension|struct|class|enum|actor|protocol)\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_.]*)'
)
FUNC_RE = re.compile(
    r'\b(?:public\s+|open\s+)?'
    r'(?:static\s+|class\s+|final\s+|mutating\s+|override\s+|convenience\s+|required\s+'
    r'|nonisolated\s+)*'
    r'(?P<kind>func|init|subscript)\b\s*(?P<name>[A-Za-z_][A-Za-z0-9_]*)?(?P<optional>[?!])?'
)
VAR_RE = re.compile(
    r'\b(?:public\s+|open\s+)?'
    r'(?:static\s+|class\s+|final\s+|lazy\s+|weak\s+|unowned(?:\([^)]*\))?\s+|override\s+)*'
    # A reserved word escaped as an identifier (`` static let `default` = ... ``, needed because
    # `default` cannot otherwise be spelled as a property name) wears backticks Swift strips at
    # compile time; a doc referencing it (`Material.default`) never shows them either.
    r'(?:var|let)\s+`?(?P<name>[A-Za-z_][A-Za-z0-9_]*)`?'
)
TYPEALIAS_RE = re.compile(r'\btypealias\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)')
CASE_RE = re.compile(r'^\s*case\s+(?P<rest>.+?):?\s*$')

# --- access levels: used ONLY by --coverage, never by the staleness gate -------------------------
# Most restrictive first, so `min` over this ordering is "effective access of a member inside a
# less-visible type".
ACCESS_ORDER = ['private', 'fileprivate', 'internal', 'package', 'public', 'open']
ACCESS_RANK = {a: i for i, a in enumerate(ACCESS_ORDER)}
PUBLICISH = ('public', 'open')

_ATTRIBUTE_RE = re.compile(r'^\s*@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s*')
_NON_ACCESS_MODIFIER_RE = re.compile(
    r'^\s*(?:static|class|final|lazy|weak|unowned(?:\([^)]*\))?|override|mutating|nonmutating'
    r'|convenience|required|dynamic|indirect|nonisolated(?:\([^)]*\))?|distributed|borrowing'
    r'|consuming)\s+')
# The negative lookahead is the whole point: `public private(set) var storage` is PUBLIC to read,
# and a scan that finds the word `private` anywhere calls it private. A bare `private(set) var`
# with no leading access keyword is `internal`, which is also what falling through to the default
# produces, so both spellings come out right.
_ACCESS_KEYWORD_RE = re.compile(r'^\s*(open|public|package|internal|fileprivate|private)\b(?!\s*\()')


def min_access(a, b):
    return a if ACCESS_RANK[a] <= ACCESS_RANK[b] else b


def leading_access(skeleton):
    """The access keyword a declaration line actually carries, or None if it carries none.

    None is not the same as `internal`: what an unmarked declaration defaults to depends on where it
    sits (an enum case inherits its enum, a `public extension`'s members are public, everything else
    is internal), and that context is not visible from the line alone.
    """
    s = skeleton
    while True:
        m = _ATTRIBUTE_RE.match(s) or _NON_ACCESS_MODIFIER_RE.match(s)
        if not m:
            break
        s = s[m.end():]
    m = _ACCESS_KEYWORD_RE.match(s)
    return m.group(1) if m else None


def split_top_level(text, sep=','):
    parts, depth, buf, i = [], 0, [], 0
    while i < len(text):
        c = text[i]
        if c in '([{<':
            depth += 1
        elif c in ')]}>':
            depth -= 1
        if c == sep and depth <= 0:
            parts.append(''.join(buf))
            buf = []
        else:
            buf.append(c)
        i += 1
    parts.append(''.join(buf))
    return [p.strip() for p in parts if p.strip()]


def _record(ctx, name, live_types, live_members, live_free, pending=None, own=None, is_case=False):
    if ctx is None:
        live_free.add(name)
        return
    live_members.setdefault(ctx['qualified'], set()).add(name)
    if pending is not None:
        # First declaration wins, so an `internal` shadow of a `public` name cannot demote it.
        key = (ctx['qualified'], name)
        cand = (own, ctx['kind'], ctx.get('access'), ctx['qualified'], is_case)
        prev = pending.get(key)
        if prev is None or (prev[0] is None and own is not None):
            pending[key] = cand


def _scan_member_line(skeleton, ctx, live_types, live_members, live_free, pending=None):
    """Record every var/let/func/init/subscript/deinit/case/typealias directly in a type's body
    (or at file top level), regardless of access level.

    This is deliberately NOT access-level-aware, unlike `check-docs-defaults.py`'s declaration
    extractor: that script's job is verifying a *public* API's restated default, so gating on
    `public`/`open` is correct for it. This script's job is existence, and an access-level gate
    produces exactly the wrong kind of false positive for it: `Face.exactBounds` (`internal var`)
    and `FeatureRecognition.swift`'s `buildGraph()` (`private func`) are both real, both correctly
    documented for context, and both would read as "removed" under a public-only gate. There is
    also a correctness trap in trying to gate on access at all: `public private(set) var storage`
    is fully readable (public getter), but a naive access-modifier search finds "private" inside
    "private(set)" and would misclassify the whole declaration as non-public.
    """
    own = leading_access(skeleton)
    is_enum_case = CASE_RE.match(skeleton)
    if is_enum_case:
        if not (ctx and ctx['kind'] == 'enum'):
            return
        for part in split_top_level(is_enum_case.group('rest')):
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', part.strip())
            if m:
                _record(ctx, m.group(0), live_types, live_members, live_free, pending,
                        own=None, is_case=True)
        return

    if re.search(r'\bdeinit\b', skeleton):
        _record(ctx, 'deinit', live_types, live_members, live_free, pending, own)
        return

    m = FUNC_RE.search(skeleton)
    if m:
        name = m.group('name') or m.group('kind')
        if m.group('kind') in ('init', 'subscript'):
            name = m.group('kind')
        _record(ctx, name, live_types, live_members, live_free, pending, own)
        return
    m = TYPEALIAS_RE.search(skeleton)
    if m:
        _record(ctx, m.group('name'), live_types, live_members, live_free, pending, own)
        qualified = m.group('name') if ctx is None else ctx['qualified'] + '.' + m.group('name')
        live_types.add(qualified)
        return
    m = VAR_RE.search(skeleton)
    if m:
        _record(ctx, m.group('name'), live_types, live_members, live_free, pending, own)


def _conformance_targets(skeleton, after):
    """`class WireCurve: ArcLengthCurveAdaptor, @unchecked Sendable {` -> {'ArcLengthCurveAdaptor',
    'Sendable'}. A member a doc attributes to `WireCurve` can be declared nowhere near it: a
    protocol EXTENSION supplies it once for every conformer (`ArcLengthCurveAdaptor`'s
    `maximumSampleCount`, inherited by both `WireCurve` and `EdgeCurve`), so a conforming type's
    member lookup must also walk what it conforms to. Superclasses and generic constraints land in
    the same set as protocols; checking a superclass's members too is harmless; a bare constraint
    like `AnyObject` matches nothing and costs one empty lookup.
    """
    rest = skeleton[after:]
    brace_idx = rest.find('{')
    colon_idx = rest.find(':')
    if colon_idx == -1 or (brace_idx != -1 and colon_idx > brace_idx):
        return set()
    clause = rest[colon_idx + 1: brace_idx if brace_idx != -1 else len(rest)]
    out = set()
    for part in split_top_level(clause):
        part = re.sub(r'^@\w+\s+', '', part.strip())   # `@unchecked Sendable` -> `Sendable`
        m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', part)
        if m:
            out.add(m.group(0))
    return out


def extract_source_symbols(files):
    """files: {path: text} -> (live_types, live_members, live_free, conformances, access).

    `conformances`: qualified type name -> set of protocol/superclass names it declares itself
    conforming to, textually (see `_conformance_targets`).

    `access`: {(owner_qualified, member_name): effective access level}, for `--coverage` only. The
    staleness gate stays access-blind (see `_scan_member_line`); every member is still extracted and
    still looked up, and this map is consulted by nothing but the census.
    """
    live_types, live_members, live_free = set(), {}, set()
    conformances = {}
    type_decls = {}   # qualified -> {'access': explicit-or-None, 'parent': qualified-or-None}
    pending = {}      # (owner, name) -> (own, ctx_kind, ctx_access, ctx_qualified, is_case)
    for path in sorted(files):
        lines = files[path].split('\n')
        type_stack = []
        brace_depth = 0
        pending_type = None
        in_block = False
        for line in lines:
            skeleton, next_block = code_skeleton(line, in_block)
            was_in_block = in_block
            in_block = next_block
            depth_before = brace_depth
            tm = None

            if not was_in_block:
                tm = TYPE_RE.match(skeleton)
                if tm:
                    kind = tm.group('kind')
                    name = tm.group('name')
                    ctx = type_stack[-1] if type_stack else None
                    # `extension Shape.History {` puts the dot INSIDE `name` (TYPE_RE's name
                    # group allows one), so `qualified` is then already fully formed and must not
                    # be re-prefixed by an unrelated enclosing ctx.
                    qualified = name if ('.' in name or ctx is None) else ctx['qualified'] + '.' + name
                    live_types.add(qualified)
                    decl_access = leading_access(skeleton)
                    _record(ctx, name, live_types, live_members, live_free, pending, decl_access)
                    # An `extension` never declares the type's access, only the default its own
                    # members take, so it must not overwrite what the real declaration said.
                    if kind != 'extension':
                        type_decls[qualified] = {
                            'access': decl_access,
                            'parent': ctx['qualified'] if ctx else None,
                            # The enclosing FRAME, not just its name: a type with no modifier of
                            # its own inside `public extension Shape` is public, and reading only
                            # `parent` cannot tell that extension from a bare one.
                            'ctx_kind': ctx['kind'] if ctx else None,
                            'ctx_access': ctx.get('access') if ctx else None,
                        }
                    targets = _conformance_targets(skeleton, tm.end())
                    if targets:
                        conformances.setdefault(qualified, set()).update(targets)
                    pending_type = {'short': name, 'qualified': qualified, 'kind': kind,
                                    'access': decl_access}
                if pending_type and '{' in skeleton:
                    type_stack.append({**pending_type, 'depth': depth_before})
                    pending_type = None

            if not was_in_block and not tm:
                ctx = type_stack[-1] if type_stack else None
                direct_member = ctx is not None and depth_before == ctx['depth'] + 1
                top_level = ctx is None and depth_before == 0
                if direct_member or top_level:
                    _scan_member_line(skeleton, ctx, live_types, live_members, live_free, pending)

            brace_depth += skeleton.count('{') - skeleton.count('}')
            while type_stack and brace_depth <= type_stack[-1]['depth']:
                type_stack.pop()
    return live_types, live_members, live_free, conformances, resolve_access(pending, type_decls)


def resolve_access(pending, type_decls):
    """Turn each member's (own keyword, enclosing context) pair into one effective access level.

    Swift's defaulting rules, which are not readable off the declaration line:
      - an enum `case` has no access keyword of its own and takes the enum's;
      - a protocol requirement likewise takes the protocol's;
      - a member of `public extension Foo` with no keyword is public, the same member in a bare
        `extension Foo` is internal;
      - everything else defaults to internal;
      - and a member is never more visible than the type it sits in, so a `public func` inside an
        internal struct is internal.

    Reading only the keyword on the line gets the FIRST of these exactly backwards, which is how a
    `public enum`'s 575 cases came to be counted as non-public in this repo's own coverage census.
    """
    memo = {}

    def type_effective(q):
        if q in memo:
            return memo[q]
        memo[q] = 'public'   # cycle guard, and the answer for a type declared outside this glob
        d = type_decls.get(q)
        if d is None:
            return 'public'
        eff = d['access']
        if eff is None:
            # Same defaulting rule as a member: inside `public extension Foo`, an unmarked nested
            # type is public. Missing this clamped `Shape.ContigousEdgeResult`'s `public let`
            # fields down to internal and hid real API from the census.
            eff = (d.get('ctx_access') or 'internal') if d.get('ctx_kind') == 'extension' \
                else 'internal'
        if d['parent']:
            eff = min_access(eff, type_effective(d['parent']))
        memo[q] = eff
        return eff

    out = {}
    for key, (own, ctx_kind, ctx_access, ctx_qualified, is_case) in pending.items():
        if own is not None:
            declared = own
        elif is_case or ctx_kind == 'protocol':
            declared = type_effective(ctx_qualified)
        elif ctx_kind == 'extension':
            declared = ctx_access or 'internal'
        else:
            declared = 'internal'
        out[key] = min_access(declared, type_effective(ctx_qualified))
    return out


def resolve_conformances(live_members, conformances, access=None):
    """Mutates `live_members` so every conforming type's set also contains what it inherits from
    a protocol/superclass's own members: a protocol EXTENSION supplies a member once for every
    conformer, with no separate declaration near the conforming type to find. Called once, right
    after `extract_source_symbols`, so every later lookup (`doc_member_exists`,
    `member_exists_anywhere`) needs no changes at all. Transitive and cycle-safe.
    """
    def expand(t, visited):
        if t in visited:
            return {}
        visited = visited | {t}
        # name -> the qualified owner the declaration actually came from, so an inherited member's
        # access is read off the protocol/superclass that declares it rather than defaulted.
        acc = {n: t for n in live_members.get(t, set())}
        for target in conformances.get(t, set()):
            for n, src in expand(target, visited).items():
                acc.setdefault(n, src)
        return acc

    for t in list(conformances):
        origins = expand(t, set())
        live_members[t] = set(origins)
        if access is not None:
            for n, src in origins.items():
                if (t, n) not in access and (src, n) in access:
                    access[(t, n)] = access[(src, n)]


# --- doc-side extraction ------------------------------------------------------------------------

HEADING_BACKTICK_RE = re.compile(r'^(#{2,6})\s+`([^`]+)`\s*(.*)$')
HEADING_BARE_RE = re.compile(r'^(#{2,6})\s+(.+?)\s*$')
HISTORICAL_RE = re.compile(r'\b(removed|deprecated|no longer exists|renamed)\b', re.IGNORECASE)
INLINE_DOTTED_RE = re.compile(
    r'`([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)(?:\([^`]*\))?`')
# ANY opening fence, not just ```swift. `docs/reference/README.md` shows the per-page authoring
# TEMPLATE inside a ```markdown block (literal `### `Type.method(label:)`` as a placeholder), and
# a swift-only check let a placeholder heading reach channel 1 and get reported as a stale symbol.
# A ```bash/```json/etc. block never contains a Swift symbol worth channel 2 checking either.
FENCE_OPEN_RE = re.compile(r'^\s*```')
FENCED_END_RE = re.compile(r'^\s*```\s*$')
IDENTIFIER_SHAPED_RE = re.compile(r'^[A-Za-z_][A-Za-z0-9_.]*$')
# `` `firstPoint` ``, `` `.locationNone` ``, `` `distance(to:)` `` -- a bare, undotted symbol
# mention. Coverage only; see the note in `scan_doc_file`.
BARE_BACKTICK_RE = re.compile(r'`\.?([a-z_][A-Za-z0-9_]*(?:\([^`]*\))?)`')


def strip_disambiguation(text):
    """`contains(uid:), GraphUID` -> ('contains(uid:)', 'GraphUID'). Split on the FIRST em/en
    dash or ` - ` only, since a symbol itself never contains one."""
    for sep in (', ', ' – ', ' - '):
        if sep in text:
            head, _, tail = text.partition(sep)
            return head.strip(), tail.strip()
    return text.strip(), ''


def classify_symbol(text):
    """`'Type.member(...)'` -> ('dotted', type, member); bare PascalCase -> ('bare_type', name);
    bare lowerCamel -> ('bare_member', name); anything else (a phrase, an operator) -> None."""
    text = text.split('(')[0].strip()
    if not text:
        return None
    if '.' in text:
        head, _, tail = text.rpartition('.')
        if re.fullmatch(r'[A-Z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]*[A-Za-z][A-Za-z0-9_]*)*', head) \
                and re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', tail):
            return ('dotted', head, tail)
        return None
    if re.fullmatch(r'[A-Z][A-Za-z0-9_]*', text):
        return ('bare_type', text)
    if re.fullmatch(r'[a-zA-Z_][A-Za-z0-9_]*', text):
        return ('bare_member', text)
    return None


def suffix_type_candidates(suffix):
    """`'Wire, Edge, Face'` -> ['Wire', 'Edge', 'Face']. `'per-pass control (#266)'` -> []."""
    cleaned = re.sub(r'\(#\d+\)', '', suffix).strip()
    if not cleaned:
        return []
    parts = [p.strip().strip('[]') for p in cleaned.split(',')]
    if all(re.fullmatch(r'[A-Z][A-Za-z0-9_]*', p) for p in parts):
        return parts
    return []


class Report:
    def __init__(self):
        self.checked = 0
        self.stale = []          # (path, line, kind, type_or_None, member, resolved_by)
        self.historical = []     # (path, line, text): acknowledged, not failing
        self.unresolved = []     # (path, line, member): no owning type could be pinned
        self.seen = set()        # every member name a doc reference resolved to, for --coverage


def doc_type_exists(t, live_types):
    if t in live_types:
        return True
    return any(lt == t or lt.endswith('.' + t) or t.endswith('.' + lt) for lt in live_types)


def doc_member_exists(t, member, live_types, live_members):
    for lt, members in live_members.items():
        if (lt == t or lt.endswith('.' + t) or t.endswith('.' + lt)) and member in members:
            return True
    return False


def member_exists_anywhere(member, live_members, live_free):
    """Does ANY live type, or the free-function namespace, have this exact member name?

    Used only for a BARE (undotted) reference, where the "owning type" is a *guess*: the real
    pages mix two `##`-heading conventions (a genuine type name, e.g. `## AAG`, and a `// MARK:`
    group label, e.g. `## Properties`, `## Evaluation`, repeated verbatim across many files for many
    types), and several pages (`Document-Analysis-Builders.md`, `Document-Math-Bounds.md`, ...) are
    grab-bag completions pages whose filename names none of the types they document. Measured
    directly: resolving those bare headings' "owning type" via heading-context/filename and
    requiring an exact match against THAT guess produced 946 candidates on the real tree, and
    reading a sample showed the guess wrong nearly every time (`fixWireGaps`, real and live on
    `Shape`, resolved via filename to `Document` and reported stale). A DOTTED reference never has
    this problem, since the page states the type itself, so this relaxation applies to bare references
    only; see the `dotted` branch of `_check_and_record`, which stays strict.
    """
    if member in SYNTHESIZED_MEMBERS or member in live_free:
        return True
    return any(member in members for members in live_members.values())


# The compiler synthesizes these; no `--self-test` fixture or the real corpus's own source text
# ever spells them out as a declaration (`CaseIterable`'s `allCases`, seen for `Column.allCases`
# in `docs/reference/Selection.md`).
SYNTHESIZED_MEMBERS = {'allCases'}

# A dotted `` `Type.tail` `` mention whose tail is a file extension names a FILE
# (`` `Shape.swift` ``, `` `Wire.md` ``), not a member: common in a page's own "see also"/index
# prose. Never a legitimate Swift member name in this codebase.
NON_SYMBOL_TAILS = {'swift', 'md'}


def paragraph_historical_map(lines):
    """line number (1-based) -> True if its paragraph (contiguous non-blank lines) contains a
    historical/removal keyword anywhere in it.

    Only for channel 2 (inline prose): a sentence like "`Shape.nbEdges` ... and removed at
    v2.0.0 (#784)." routinely soft-wraps the annotation onto a LATER physical line than the
    mention itself, and checking only the matched line missed six real, correctly-annotated cases
    on the first pass against the real tree. Headings (channel 1) do NOT get this treatment: see
    `_check_and_record`'s dotted/bare_type branches, where a heading whose *prose paragraph below
    it* says "deprecated" while the heading's own restated declaration still claims current
    existence is exactly the `BSplineContinuity`/`Continuity`/`ContinuityOrder` shape found on the
    real tree: genuinely wrong content (says "is now a typealias of X"; X does not exist either),
    not a wrapped annotation. Widening channel 1 the same way would silently swallow that.
    """
    result = {}
    para_start = 0
    para_lines = []
    for idx, line in enumerate(lines):
        if line.strip() == '':
            if para_lines:
                hit = bool(HISTORICAL_RE.search('\n'.join(para_lines)))
                for n in range(para_start, idx):
                    result[n + 1] = hit
            para_lines = []
            para_start = idx + 1
        else:
            para_lines.append(line)
    if para_lines:
        hit = bool(HISTORICAL_RE.search('\n'.join(para_lines)))
        for n in range(para_start, len(lines)):
            result[n + 1] = hit
    return result


def scan_doc_file(path, text, live_types, live_members, live_free, rep):
    lines = text.split('\n')
    para_historical = paragraph_historical_map(lines)
    context_stack = {}   # level -> type-name hint or None
    fence_active = False
    for idx, line in enumerate(lines):
        lineno = idx + 1
        # Check for the CLOSING fence before the opening pattern: both are `^\s*```...$`, and a
        # closing ``` (bare) matches FENCE_OPEN_RE too, so checking `fence_active` first is what
        # lets the fence ever end instead of swallowing the rest of the file.
        if fence_active:
            if FENCED_END_RE.match(line):
                fence_active = False
            continue
        if FENCE_OPEN_RE.match(line):
            fence_active = True
            continue

        # --- coverage-only channel -------------------------------------------------------------
        # Any backtick-quoted bare identifier counts as "this member is NAMED in docs", which is
        # the only question `--coverage` asks. A table row `| \`firstPoint\` | ... |` documents a
        # field as surely as a heading does, and counting only headings made the census demand a
        # heading per field: 584 empty anchor headings were added next to tables that already
        # explained every one of them, purely to satisfy this number.
        #
        # Deliberately NOT fed into the staleness check. A bare backtick-quoted word is far too
        # weak to accuse of being a removed symbol (it is often just an English word in code
        # font); that check keeps requiring a dotted `Type.member` or a heading, as the module
        # docstring describes.
        for word in BARE_BACKTICK_RE.findall(line):
            rep.seen.add(word.split('(')[0])

        hb = HEADING_BACKTICK_RE.match(line)
        if hb:
            level = len(hb.group(1))
            raw, suffix = hb.group(2), hb.group(3)
            context_stack = {k: v for k, v in context_stack.items() if k < level}
            # The disambiguating suffix appears BOTH ways in the real pages: inside the backtick
            # span (`` `contains(uid:), GraphUID` ``) and outside it
            # (`` `distance(to:deflection:)`, Wire, Edge, Face ``). Both must be tried.
            body, inner_dash_suffix = strip_disambiguation(raw)
            outer_dash_suffix = ''
            s = suffix.strip()
            for sep in (', ', '–', '-'):
                if s.startswith(sep):
                    outer_dash_suffix = s[len(sep):].strip()
                    break
            dash_suffix = inner_dash_suffix or outer_dash_suffix
            historical = bool(HISTORICAL_RE.search(suffix)) or bool(HISTORICAL_RE.search(inner_dash_suffix))
            cls = classify_symbol(body)
            resolved_type = None
            if cls:
                if cls[0] == 'dotted':
                    resolved_type = cls[1]
                elif cls[0] == 'bare_type':
                    resolved_type = None  # checked as a type, not a member
                elif cls[0] == 'bare_member':
                    resolved_type = _resolve_context(context_stack, path)
                    if not resolved_type and dash_suffix:
                        cands = suffix_type_candidates(dash_suffix)
                        resolved_type = cands[0] if len(cands) == 1 else None
                _check_and_record(cls, resolved_type, path, lineno, historical, rep,
                                   live_types, live_members, live_free,
                                   fallback_types=suffix_type_candidates(dash_suffix))
            # This heading's own (possibly bare) identifier becomes context for deeper headings.
            hint = body if IDENTIFIER_SHAPED_RE.fullmatch(body) else None
            context_stack[level] = hint
            continue

        hbare = HEADING_BARE_RE.match(line)
        if hbare and line.lstrip().startswith('#'):
            level = len(hbare.group(1))
            text_ = hbare.group(2).strip()
            context_stack = {k: v for k, v in context_stack.items() if k < level}
            hint = text_ if IDENTIFIER_SHAPED_RE.fullmatch(text_) else None
            context_stack[level] = hint
            continue

        # Channel 2: inline `Type.member` mentions in ordinary prose (any heading state). Skipped
        # only while inside ANY fenced block. A fenced ```swift snippet is often intentionally
        # showing removed/"before" code under a prose explanation (not this channel's concern; the
        # heading that introduces it, if any, is channel 1's job), and a fenced shell/json block
        # never contains a Swift symbol reference worth checking either.
        for m in INLINE_DOTTED_RE.finditer(line):
            t, member = m.group(1), m.group(2)
            if member in NON_SYMBOL_TAILS:
                continue   # `` `Shape.swift` ``, `` `Wire.md` ``: a filename, not a symbol
            historical = para_historical.get(lineno, False)
            rep.checked += 1
            if not doc_type_exists(t, live_types):
                continue  # the type itself is gone/renamed wholesale; channel 1/headings own that
            if doc_member_exists(t, member, live_types, live_members) or member in SYNTHESIZED_MEMBERS:
                continue
            if historical:
                rep.historical.append((path, lineno, f'{t}.{member}'))
                continue
            rep.stale.append((path, lineno, 'inline', t, member, 'inline'))


def _resolve_context(context_stack, path):
    for level in sorted(context_stack, reverse=True):
        if context_stack[level]:
            return context_stack[level]
    base = os.path.basename(path)
    if base.endswith('.md'):
        base = base[:-3]
    return base.split('-')[0] or None


def _check_and_record(cls, resolved_type, path, lineno, historical, rep, live_types, live_members,
                       live_free, fallback_types=None):
    rep.checked += 1
    # Record the name regardless of outcome: --coverage asks whether docs MENTION a symbol, which a
    # stale reference still does. Coverage and staleness are separate questions and a symbol can
    # fail one while passing the other.
    _mentioned = cls[2] if cls[0] == 'dotted' else cls[1]
    if _mentioned:
        rep.seen.add(_mentioned)
    kind = cls[0]
    if kind == 'dotted':
        # Strict: the page states the owning type itself, so this is exactly the shape #802 warns
        # about (`Shape.nbEdges` vs `ShapeContentsExtended.nbEdges`) and must not be relaxed.
        _, t, member = cls
        ok = doc_type_exists(t, live_types) and doc_member_exists(t, member, live_types, live_members)
        if not ok and fallback_types:
            ok = any(doc_member_exists(ft, member, live_types, live_members) for ft in fallback_types)
        if not ok and member[:1].isupper():
            # A PascalCase tail (`Shape.OrientedBoundingBox`, `BillOfMaterials.Column`) can name a
            # genuinely nested type (checked above via `doc_member_exists`, since a nested type is
            # also recorded as a member of its enclosing one) OR a page's organisational grouping
            # of an unrelated TOP-LEVEL type under a related heading. Try the bare type too before
            # giving up: still exact-name matching, so this cannot resurrect the
            # `Shape.nbEdges`/`ShapeContentsExtended.nbEdges` trap (lowercase tails never reach
            # here) or the `Conic2D.fromCircle`/`Curve2D.fromCircleArc` one (already exact-matched
            # above, not substring).
            ok = doc_type_exists(f'{t}.{member}', live_types) or doc_type_exists(member, live_types)
        if ok:
            return
        if historical:
            rep.historical.append((path, lineno, f'{t}.{member}'))
            return
        rep.stale.append((path, lineno, 'heading', t, member, 'dotted'))
    elif kind == 'bare_type':
        t = cls[1]
        if doc_type_exists(t, live_types):
            return
        if historical:
            rep.historical.append((path, lineno, t))
            return
        rep.stale.append((path, lineno, 'heading', None, t, 'bare_type'))
    else:  # bare_member: the owning type is a GUESS (heading context or filename), so existence
           # is asked globally, not of the guess alone. See `member_exists_anywhere`'s docstring.
        member = cls[1]
        if resolved_type and doc_member_exists(resolved_type, member, live_types, live_members):
            return
        if fallback_types and any(
                doc_member_exists(ft, member, live_types, live_members) for ft in fallback_types):
            return
        if member_exists_anywhere(member, live_members, live_free):
            return
        if resolved_type is None and not fallback_types:
            rep.unresolved.append((path, lineno, member))
            return
        if historical:
            label = f'{resolved_type}.{member}' if resolved_type else member
            rep.historical.append((path, lineno, label))
            return
        rep.stale.append((path, lineno, 'heading', resolved_type, member, 'bare_member'))


def coverage(live_members, seen, access):
    """Which live PUBLIC members are named nowhere in docs/ (#802 item 5).

    The INVERSE of what this script normally asks. The gate walks docs and checks each reference
    resolves; this walks the source and checks each member is referenced. A clean gate run says
    nothing about coverage, which is why the two are separate modes rather than one number.

    Excluded, deliberately:
      - anything whose effective access is not `public`/`open` (see `resolve_access`).
      - `_`-prefixed names, conventionally private-by-convention even when `public`.
      - PascalCase members, which are nested TYPES rather than functions or properties.
      - anything under a `CodingKeys` type, a `Codable` implementation detail no consumer calls.

    The access filter is the one exclusion this mode originally lacked, and its absence cost real
    work: the census asked for ~180 `private`/`internal` implementation helpers to be documented in
    consumer reference pages, and two agents dutifully documented them, then raised
    `check-docs-defaults.py`'s `EXPECTED_UNMATCHED` baseline (3 -> 66 and 3 -> 7) because that gate
    only indexes public declarations and correctly refused to match a private one. Two gates
    disagreeing was the signal; the census was the one that was wrong.

    KNOWN LIMITATION: `seen` is a set of bare member NAMES, not (type, member) pairs, so
    documenting `Shape.count` marks `count` covered on every type that has one. The count here is
    therefore a floor on the real gap.

    Measured this way the answer is roughly a quarter of the surface. Measured with an ad hoc regex
    over `Type.member` and `member(` it comes out around 25% higher, because a member documented as
    a bare heading or in running prose is invisible to that shape. That wrong number was produced
    once, believed, and nearly acted on, which is why this lives in the script that already parses
    docs correctly instead of being re-derived per investigation.
    """
    missing = {}
    total = 0
    nonpublic = 0
    for owner, members in live_members.items():
        if 'CodingKeys' in owner:
            continue
        for member in members:
            if member.startswith('_') or member[:1].isupper():
                continue
            if access.get((owner, member), 'public') not in PUBLICISH:
                nonpublic += 1
                continue
            total += 1
            if member not in seen:
                missing.setdefault(owner, []).append(member)
    return total, {k: sorted(v) for k, v in missing.items()}, nonpublic


def print_coverage(total, missing, nonpublic):
    n = sum(len(v) for v in missing.values())
    print(f"live public members      : {total}")
    print(f"non-public, not counted  : {nonpublic}")
    print(f"named nowhere in docs/   : {n}  ({100 * n / max(total, 1):.1f}%)")
    print(f"types with a gap         : {len(missing)}")
    if not missing:
        return
    print("\nlargest gaps:")
    for owner, members in sorted(missing.items(), key=lambda kv: -len(kv[1]))[:20]:
        print(f"  {owner:<38} {len(members):>4}  {', '.join(members[:3])}"
              + (" ..." if len(members) > 3 else ""))


def in_scope_doc_paths():
    paths = [p for p in glob.glob(DOC_GLOB, recursive=True) if p not in EXCLUDED_DOCS]
    if os.path.exists(README):
        paths.append(README)
    return sorted(paths)


def print_report(rep, verbose):
    print(f'symbol references checked: {rep.checked}')
    print(f'stale (no live declaration): {len(rep.stale)}')
    print(f'acknowledged historical (mentions a removed name, correctly annotated): '
          f'{len(rep.historical)}')
    print(f'unresolved context (bare member, no owning type could be pinned): '
          f'{len(rep.unresolved)} (baseline {EXPECTED_UNRESOLVED})')

    if rep.stale:
        print('\nSTALE: documented symbol has no matching live declaration:')
        for path, lineno, kind, t, member, how in rep.stale:
            label = f'{t}.{member}' if t else member
            print(f'  {path}:{lineno}  {label}  [{kind}/{how}]')
    if verbose and rep.historical:
        print('\nACKNOWLEDGED HISTORICAL: mentions a removed name, but says so:')
        for path, lineno, label in rep.historical:
            print(f'  {path}:{lineno}  {label}')
    if verbose and rep.unresolved:
        print('\nUNRESOLVED CONTEXT: could not be checked:')
        for path, lineno, member in rep.unresolved:
            print(f'  {path}:{lineno}  {member}')


# --- self-test: a removal matrix built from the real #798 removals ------------------------------
# Each row is a real removed/renamed symbol from PR #798's own migration table, reproduced as a
# minimal fixture, plus the two named collision traps (#802's own warning) as CLEAN cases. Every
# row is run once with the checker's relevant guard disabled to prove it is load-bearing, per
# okf/policies/prove-the-test-fails.md.

SELF_TEST_CASES = [
    (
        'dotted heading naming a removed property is STALE (the BRepGraph.generation shape)',
        {'Sources/OCCTSwift/A.swift': 'public final class BRepGraph {\n'
                                      '    public var instanceID: UInt64 { 0 }\n}\n'},
        {'docs/reference/ZZ.md': '### `BRepGraph.generation`\n\n```swift\n'
                                 'public var generation: Int { get }\n```\n'},
        'stale', 1,
    ),
    (
        'the SAME heading, annotated as removed, is acknowledged not stale',
        {'Sources/OCCTSwift/A.swift': 'public final class BRepGraph {\n'
                                      '    public var instanceID: UInt64 { 0 }\n}\n'},
        {'docs/reference/ZZ.md': '### `generation` *(removed in v2.0.0)*\n\n'
                                 'Use `instanceID` instead.\n'},
        'historical', 1,
    ),
    (
        'collision trap: ShapeContentsExtended.nbEdges is live and must NOT be flagged',
        {'Sources/OCCTSwift/A.swift': 'extension Shape {\n    public var edgeCount: Int { 0 }\n}\n'
                                      'public struct ShapeContentsExtended {\n'
                                      '    public let nbEdges: Int\n}\n'},
        {'docs/reference/ZZ.md': '### `ShapeContentsExtended`\n\n```swift\n'
                                 'public struct ShapeContentsExtended {\n'
                                 '    public let nbEdges: Int\n}\n```\n'},
        'clean', 0,
    ),
    (
        'collision trap: prose mentioning removed Shape.nbEdges IS flagged despite the live sibling',
        {'Sources/OCCTSwift/A.swift': 'extension Shape {\n    public var edgeCount: Int { 0 }\n}\n'
                                      'public struct ShapeContentsExtended {\n'
                                      '    public let nbEdges: Int\n}\n'},
        {'docs/reference/ZZ.md': 'See also `Shape.nbEdges` for the older spelling.\n'},
        'stale', 1,
    ),
    (
        'collision trap: Curve2D.fromCircleArc is live, must not match removed Conic2D.fromCircle',
        {'Sources/OCCTSwift/A.swift': 'extension Curve2D {\n'
                                      '    public static func fromCircleArc(center: Int) -> Curve2D'
                                      ' { fatalError() }\n}\n'
                                      'public struct Conic2D {\n'
                                      '    public static func circle(center: Int) -> Conic2D?'
                                      ' { nil }\n}\n'},
        {'docs/reference/ZZ.md': '### `Curve2D.fromCircleArc(center:)`\n\n```swift\n'
                                 'public static func fromCircleArc(center: Int) -> Curve2D\n```\n'},
        'clean', 0,
    ),
    (
        'renamed enum case: ThreadBuild.boolean removed, .auto/.direct remain, case is stale',
        {'Sources/OCCTSwift/A.swift': 'public enum ThreadBuild {\n    case auto\n    case direct\n}\n'},
        {'docs/reference/ZZ.md': '### `ThreadBuild.boolean`\n\nRemoved case.\n'},
        'stale', 1,
    ),
    (
        'removed typealias referenced bare is STALE',
        {'Sources/OCCTSwift/A.swift': 'public final class BRepGraph {}\n'},
        {'docs/reference/ZZ.md': '### `TopologyGraph`\n\nAlias for `BRepGraph`.\n'},
        'stale', 1,
    ),
    (
        'bare member resolved via filename fallback (BRepGraph-Editor-Identity.md -> BRepGraph)',
        {'Sources/OCCTSwift/A.swift': 'public final class BRepGraph {\n'
                                      '    public var instanceID: UInt64 { 0 }\n}\n'},
        {'docs/reference/BRepGraph-Editor-Identity.md': '### `instanceID`\n\n```swift\n'
                                                        'public var instanceID: UInt64 { get }\n```\n'},
        'clean', 0,
    ),
    (
        'bare member resolved via a dash-separated TypeA, TypeB suffix when context/filename both fail',
        {'Sources/OCCTSwift/A.swift': 'extension Wire {\n'
                                      '    public func distance(to other: Int) -> Double { 0 }\n}\n'
                                      'extension Edge {\n'
                                      '    public func distance(to other: Int) -> Double { 0 }\n}\n'},
        {'docs/reference/ZZ-Features.md':
            '### `distance(to:)`, Wire, Edge\n\n```swift\n'
            'public func distance(to other: Int) -> Double\n```\n'},
        'clean', 0,
    ),
    (
        'a switch-statement case label is NOT an enum member declaration (false-positive guard)',
        {'Sources/OCCTSwift/A.swift':
            'public enum ThreadBuild: Codable {\n'
            '    case auto\n    case direct\n'
            '    public init(from decoder: Decoder) throws {\n'
            '        let raw = try decoder.singleValueContainer().decode(String.self)\n'
            '        switch raw {\n'
            '        case "auto", "direct", "boolean": self = .auto\n'
            '        default: self = .auto\n'
            '        }\n'
            '    }\n}\n'},
        {'docs/reference/ZZ.md': '### `ThreadBuild.boolean`\n\nRemoved case.\n'},
        'stale', 1,   # would wrongly read CLEAN if the switch-case were miscounted as an enum case
    ),
    (
        'a member from a PROTOCOL EXTENSION resolves for a conforming type (the '
        'WireCurve/ArcLengthCurveAdaptor shape)',
        {'Sources/OCCTSwift/A.swift':
            'public protocol ArcLengthCurveAdaptor: AnyObject {\n'
            '    func points(count: Int) -> [Int]\n}\n'
            'extension ArcLengthCurveAdaptor {\n'
            '    public static var maximumSampleCount: Int { 10_000_000 }\n}\n'
            'public final class WireCurve: ArcLengthCurveAdaptor, @unchecked Sendable {\n'
            '    public init() {}\n}\n'},
        {'docs/reference/ZZ.md': '### `WireCurve.maximumSampleCount`\n\n```swift\n'
                                 'public static var maximumSampleCount: Int { get }\n```\n'},
        # Without conformance resolution, `WireCurve`'s own member set never gains
        # `maximumSampleCount` (it is declared only on `ArcLengthCurveAdaptor`), and this reads as
        # a false-positive STALE finding for real, currently-compiling code.
        'clean', 0,
    ),
]


def self_test():
    failures = 0
    for name, src_files, doc_files, expect_kind, expect_count in SELF_TEST_CASES:
        live_types, live_members, live_free, conformances, _acc = extract_source_symbols(src_files)
        resolve_conformances(live_members, conformances, _acc)
        rep = Report()
        for path in sorted(doc_files):
            scan_doc_file(path, doc_files[path], live_types, live_members, live_free, rep)
        got = {'stale': len(rep.stale), 'historical': len(rep.historical),
               'clean': 0 if (rep.stale or rep.historical) else 1}
        want_key = expect_kind
        ok = (want_key == 'clean' and got['stale'] == 0 and got['historical'] == 0) or \
             (want_key in ('stale', 'historical') and got[want_key] == expect_count)
        if ok:
            print(f'  PASS  {name}')
        else:
            failures += 1
            print(f'  FAIL  {name}')
            print(f'          expected {want_key}={expect_count}')
            print(f'          got      stale={got["stale"]} historical={got["historical"]}')
    failures += _coverage_self_test()
    print(f'\nself-test: {len(SELF_TEST_CASES) + _COVERAGE_CASES - failures} passed, {failures} failed')
    return failures


_COVERAGE_CASES = 16


def _coverage_self_test():
    """Prove --coverage distinguishes documented from undocumented, and honours its exclusions.

    Worth its own cases rather than trusting the shared fixtures: coverage reads `rep.seen`, which
    the staleness path populates as a side effect, so a change that stopped recording it would leave
    every staleness case passing while coverage silently reported the whole surface as undocumented.

    The access rows are the expensive ones. Getting the enum-case rule backwards mislabelled 575
    public cases as non-public here, and reporting the wrong number stopped three agents mid-task,
    so each of Swift's defaulting rules gets a row asserting BOTH directions: the shape that must be
    counted, and the neighbouring shape that must not.
    """
    src = {'S.swift': (
        'public struct Widget {\n'
        '    public func documented() {}\n'
        '    public func undocumented() {}\n'
        '    public func _hidden() {}\n'
        '    public var Nested: Int { 0 }\n'
        '    internal func internalHelper() {}\n'
        '    private func privateHelper() {}\n'
        '    fileprivate func fileprivateHelper() {}\n'
        '    func implicitlyInternal() {}\n'
        '    public private(set) var settableOnlyInside: Int = 0\n'
        '}\n'
        'public struct WidgetCodingKeys {\n'
        '    public var excluded: Int { 0 }\n'
        '}\n'
        # An enum case carries no access keyword of its own; it takes the enum's.
        'public enum Mode {\n    case fast\n    case slow\n}\n'
        'internal enum HiddenMode {\n    case quiet\n}\n'
        # A member with no keyword takes the EXTENSION's, not a blanket internal.
        'public extension Widget {\n    func fromPublicExtension() {}\n}\n'
        'extension Widget {\n    func fromBareExtension() {}\n}\n'
        # A public member is never more visible than the type holding it.
        'internal struct Hidden {\n    public func publicInsideInternal() {}\n}\n'
        # A protocol requirement takes the protocol's access.
        'public protocol Shaped {\n    func requirement()\n}\n'
        # An unmarked nested type inside a `public extension` is PUBLIC, so its `public let`
        # fields stay public. Treating the struct as internal clamps them down and hides them.
        'public extension Widget {\n'
        '    struct Nested: Sendable {\n        public let carried: Int\n    }\n}\n'
        'extension Widget {\n'
        '    struct BareNested: Sendable {\n        public let notCarried: Int\n    }\n}\n')}
    docs = {'d.md': '# Widget\n\n### `Widget.documented()`\n\nText.\n'}
    live_types, live_members, live_free, conf, access = extract_source_symbols(src)
    resolve_conformances(live_members, conf, access)
    rep = Report()
    for path in sorted(docs):
        scan_doc_file(path, docs[path], live_types, live_members, live_free, rep)
    total, missing, nonpublic = coverage(live_members, rep.seen, access)
    # Every fixture member except `documented()` is absent from the doc, so "appears in `missing`"
    # and "was counted at all" coincide here, and reading the answer off `coverage`'s own return
    # value is what makes these rows load-bearing. An earlier draft re-derived the filter inline
    # from `access`; deleting the filter from `coverage` then failed nothing, because the assertion
    # was checking a copy of the logic rather than the logic.
    counted = {m for v in missing.values() for m in v}
    flat = counted

    checks = [
        ('coverage: a documented member is not reported missing', 'documented' not in flat),
        ('coverage: an undocumented member IS reported missing', 'undocumented' in flat),
        ('coverage: an underscore-prefixed member is excluded', '_hidden' not in flat),
        ('coverage: a CodingKeys member is excluded', 'excluded' not in flat),
        ('access: an explicit `internal` member is not counted',
         'internalHelper' not in counted),
        ('access: a `private` member is not counted', 'privateHelper' not in counted),
        ('access: a `fileprivate` member is not counted', 'fileprivateHelper' not in counted),
        ('access: an unmarked member of a public struct is not counted (implicit internal)',
         'implicitlyInternal' not in counted),
        ('access: `public private(set)` IS counted (public getter, not a private member)',
         'settableOnlyInside' in counted),
        ('access: a `public enum`\'s cases ARE counted (a case inherits the enum)',
         {'fast', 'slow'} <= counted),
        ('access: an `internal enum`\'s cases are not counted', 'quiet' not in counted),
        ('access: `public extension` makes an unmarked member public; a bare one does not',
         'fromPublicExtension' in counted and 'fromBareExtension' not in counted),
        ('access: a `public func` inside an internal struct is not counted',
         'publicInsideInternal' not in counted),
        ('access: an unmarked requirement of a public protocol IS counted',
         'requirement' in counted),
        ('access: a nested type in a `public extension` keeps its public fields public',
         'carried' in counted),
        ('access: the same nested type in a BARE extension does not',
         'notCarried' not in counted),
    ]
    bad = 0
    for label, ok in checks:
        print(f'  {"PASS" if ok else "FAIL"}  {label}')
        if not ok:
            bad += 1
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--self-test', action='store_true',
                    help='run the removal-matrix battery instead of scanning the tree')
    ap.add_argument('--coverage', action='store_true',
                    help='inverse mode: which live public members are named nowhere in docs/. '
                         'Reports only, never fails.')
    ap.add_argument('--verbose', action='store_true',
                    help='also list acknowledged-historical and unresolved-context entries')
    ap.add_argument('--quiet', action='store_true', help='exit status only')
    args = ap.parse_args()

    if args.self_test:
        return 1 if self_test() else 0

    src_files = {}
    for path in sorted(glob.glob(SRC_GLOB)):
        with open(path, encoding='utf-8') as fh:
            src_files[path] = fh.read()
    live_types, live_members, live_free, conformances, access = extract_source_symbols(src_files)
    resolve_conformances(live_members, conformances, access)

    rep = Report()
    for path in in_scope_doc_paths():
        with open(path, encoding='utf-8') as fh:
            text = fh.read()
        scan_doc_file(path, text, live_types, live_members, live_free, rep)

    if args.coverage:
        total, missing, nonpublic = coverage(live_members, rep.seen, access)
        print_coverage(total, missing, nonpublic)
        # Never fails. Coverage is a backlog to work through, not a property of a correct tree, and
        # a gate that fails on it would fail every build until the backlog is empty.
        return 0

    unresolved_grew = len(rep.unresolved) > EXPECTED_UNRESOLVED
    if not args.quiet:
        print_report(rep, args.verbose)
        if unresolved_grew:
            print(f'\n  Unresolved-context count grew past its baseline ({EXPECTED_UNRESOLVED}): '
                  f'a bare heading whose owning type this script cannot pin is unreported drift, '
                  f'not a pass. Give the page a resolvable heading/filename, or add a reasoned '
                  f'baseline bump.')

    fail = bool(rep.stale) or unresolved_grew
    return 1 if fail else 0


if __name__ == '__main__':
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
    sys.exit(main())
