#!/usr/bin/env python3
"""Suggest a domain for each member of `extension Shape`, from what tests cover it (#660).

#395's header split was a lookup: every declaration mapped to exactly one `.mm`. This one is not.
The domain of a `Shape` method is a judgement, and the point of this script is to shrink how much
judgement is left rather than pretend there is none.

The signal is test coverage. `Tests/OCCT<Domain>Tests` is an established taxonomy in this repo, and
a member exercised by exactly one of those targets has a defensible home: put the source where the
tests already are, so `Shape+Modeling.swift` and `OCCTModelingTests` line up without a lookup table.

    python3 Scripts/derive-shape-domain-split.py             # counts per domain
    python3 Scripts/derive-shape-domain-split.py --list       # every member and its suggestion
    python3 Scripts/derive-shape-domain-split.py --unmapped   # only the ones needing a decision

Roughly four fifths map cleanly. The rest split two ways and both matter:

  AMBIGUOUS  exercised by several targets. Decide by what the method does, not by which test
             happens to touch it first; a test in OCCTStressTests calling a modelling method says
             nothing about the method's domain.
  UNTESTED   exercised by nothing. Place by behaviour, and treat the absence as worth reporting:
             an untested public method on the primary type is a finding in its own right.

The coverage signal is textual co-occurrence, not a call graph: a target "exercises" a member if
`.memberName` appears anywhere in its sources. Common names (`.count`, `.area`) therefore collide
across types, so a suggestion is a starting point and not an answer. That is the whole framing of
this script, but it is worth stating rather than leaving a reader to infer it from a wrong result.

Exits 2 if run from anywhere but the repo root, matching the other scripts (#625).
"""

import argparse
import collections
import glob
import os
import re
import sys

SOURCES = "Sources/OCCTSwift"
TESTS = "Tests"

# A word boundary, not a prefix. `startswith("extension Shape")` also matches `extension ShapeAxis`
# and `extension ShapeMeasurements`, both of which are real types here, and would silently fold
# their members into Shape's census. No such extension exists in this file today; the point is that
# it would be counted wrongly with no error, which is the same silent-contamination failure the
# depth check below was added to fix.
#
# The access-modifier prefix is required too, not optional dressing: `public extension Shape {`
# puts every member inside it (public or not) on the same standing as an explicit `public` member
# of a plain `extension Shape {`, and #662 found 5 such blocks in Document.swift (plus one more in
# PresentationMesh.swift) that this regex skipped outright before the prefix was added -- 7 real
# members and 4 nested types, invisible with no error, the same failure shape the comment above
# already names for a different cause.
EXTENSION_SHAPE = re.compile(r"^(?:public |internal |private |package |fileprivate |)?extension Shape\b")

MEMBER = re.compile(
    r"^\s+(?:public |internal |private |fileprivate |)?(?:static |)?"
    r"(?:func|var|let|subscript) ([a-zA-Z_]\w*)"
)
# Nested result types declared inside the extension. Their own members are not members of Shape.
NESTED = re.compile(r"^\s+(?:public |internal |private |fileprivate |)?(?:final )?(?:struct|enum|class) ")
# Targets that say nothing about a method's domain: they exercise everything by design.
DOMAIN_FREE = {"Stress", "Integration", "Thread", "Misc", "Foundation"}


def strip_block_comments(line, in_block):
    """Return (code outside any block comment, whether a block comment is still open).

    Mirrors what the compiler does with a same-line block comment rather than dropping the whole
    physical line. Skipping the line is what the first version did, and it silently lost any code
    sharing a line with the closing `*/`: both the member on that line and, if its braces did not
    happen to balance, every later member in the block, because the depth counter desynced.
    """
    out = []
    while line:
        if in_block:
            close = line.find("*/")
            if close == -1:
                return "".join(out), True
            line = line[close + 2:]
            in_block = False
        else:
            open_at = line.find("/*")
            if open_at == -1:
                out.append(line)
                return "".join(out), False
            out.append(line[:open_at])
            line = line[open_at + 2:]
            in_block = True
    return "".join(out), in_block


def shape_members(paths=None):
    """Direct members of every top-level `extension Shape` block under Sources/OCCTSwift.

    Scans the whole directory rather than one file. It used to hardcode Shape.swift, which was
    right until #660 moved every extension out of it into Shape+<Domain>.swift: after that the
    script reported 0 members and said nothing, which is the same silent-wrong-answer this file
    keeps being fixed for. #662 still has 2,489 lines of `extension Shape` to move out of
    Document.swift, so the census needs to keep working across files.

    The depth check is load-bearing. Without it the regex also matches local `var`s inside function
    bodies and the fields of nested result types, which is how the first version of this script
    reported 557 members when 253 of its raw matches were at depth 2 or 3. Only depth 1, and only
    outside a nested type, is a member of Shape.

    Comment-only lines are excluded from brace counting: doc comments carry multi-line Swift
    examples whose braces do not balance line by line, which throws the depth off.
    """
    if paths is None:
        paths = sorted(glob.glob(os.path.join(SOURCES, "*.swift")))
    names = set()
    for path in paths:
        names |= _members_in_file(path)
    return sorted(names)


def _members_in_file(path):
    names, depth, inside, nested_until = set(), 0, False, None
    in_block_comment = False
    for line in open(path, errors="ignore"):
        if EXTENSION_SHAPE.match(line):
            inside, depth, nested_until = True, 0, None
        if not inside:
            continue
        # Reduce the line to the code a compiler would see. Doc comments here carry multi-line
        # Swift examples whose braces do not balance line by line, and a `/* */` span does the
        # same, so both are removed before anything counts braces or matches a declaration.
        code, in_block_comment = strip_block_comments(line, in_block_comment)
        stripped = code.lstrip()
        if stripped and not stripped.startswith("//"):
            if nested_until is None and NESTED.match(code):
                nested_until = depth  # everything deeper belongs to the nested type
            elif depth == 1:
                m = MEMBER.match(code)
                if m:
                    names.add(m.group(1))
            depth += code.count("{") - code.count("}")
            if nested_until is not None and depth <= nested_until:
                nested_until = None
            if depth <= 0 and stripped.startswith("}"):
                inside = False
    return names


def test_corpus():
    corpus = {}
    for d in sorted(glob.glob(os.path.join(TESTS, "OCCT*Tests"))):
        name = os.path.basename(d)[len("OCCT"):-len("Tests")]
        blob = []
        for f in glob.glob(os.path.join(d, "**", "*.swift"), recursive=True):
            blob.append(open(f, errors="ignore").read())
        corpus[name] = "\n".join(blob)
    return corpus


def classify(members, corpus):
    out = {}
    for name in members:
        pat = re.compile(r"\." + re.escape(name) + r"\b")
        hit = {t for t, blob in corpus.items() if pat.search(blob)}
        informative = hit - DOMAIN_FREE
        if len(informative) == 1:
            out[name] = (informative.pop(), "mapped")
        elif informative:
            out[name] = ("/".join(sorted(informative)), "AMBIGUOUS")
        else:
            out[name] = ("", "UNTESTED")
    return out


SELF_TEST_FIXTURE = """\
extension ShapeAxis {
    public func notOnShapeAtAll() {}
}

extension Shape {
    /// A doc comment whose example braces do not balance on one line:
    ///     if x {
    ///         doThing()
    ///     }
    public func realMember() -> Int {
        var aLocalVariable = 0
        for i in 0..<3 { aLocalVariable += i }
        return aLocalVariable
    }

    /*
       A block comment carrying an UNMATCHED brace, which is what actually corrupts a depth
       counter that does not skip block comments: {
    */
    public var realProperty: Int { 0 }

    /* a one-liner sharing its line with code */ public func rightAfterClose() -> Int { 0 }

    /* a span whose close shares a line with a
       multi-line body */ public func spanThenBody() -> Int {
        let n = 1
        return n
    }

    public func afterTheSpan() {}

    public struct NestedResult {
        public var notAShapeMember: Double
        public func alsoNotAShapeMember() {}
    }
}

public extension Shape {
    /// The access modifier is on the `extension` keyword, not this member (#662): a member with
    /// no modifier of its own is still public because the enclosing extension is.
    func memberOfPublicExtension() -> Int { 0 }
}
"""

# Only the two direct members belong to Shape. The other three names are the exact contamination
# the first version of this script shipped: a local `var` inside a function body, and the fields of
# a nested result type. It reported 557 members when the real figure was 446.
# rightAfterClose / spanThenBody / afterTheSpan cover the review finding on #680: closing a block
# comment with `continue` dropped the whole physical line, so code sharing a line with `*/` was
# lost, and an unbalanced brace on that line desynced depth for every later member too.
# memberOfPublicExtension covers #662's finding: `EXTENSION_SHAPE` matched only a line starting
# with the literal word "extension", so `public extension Shape {` (5 blocks in Document.swift,
# one more in PresentationMesh.swift) was never recognised as a Shape extension at all -- not one
# member inside any of them was counted, silently. 237 reported for Document.swift, 244 real.
SELF_TEST_EXPECTED = {
    "realMember",
    "realProperty",
    "rightAfterClose",
    "spanThenBody",
    "afterTheSpan",
    "memberOfPublicExtension",
}
# Each rejection is a bug this script has actually had or was one edit away from having:
#   aLocalVariable / notAShapeMember / alsoNotAShapeMember  no depth check (shipped, 557 vs 446)
#   notOnShapeAtAll                                          `startswith` matched extension ShapeAxis
# The unbalanced block comment above guards the third: `//`-only comment detection let a `/* */`
# span throw off brace depth, the same way doc comments did before that was fixed.
SELF_TEST_REJECTED = {
    "aLocalVariable",
    "notAShapeMember",
    "alsoNotAShapeMember",
    "notOnShapeAtAll",
}


def self_test():
    import tempfile

    with tempfile.NamedTemporaryFile("w", suffix=".swift", delete=False) as handle:
        handle.write(SELF_TEST_FIXTURE)
        fixture = handle.name
    try:
        found = set(shape_members([fixture]))
    finally:
        os.unlink(fixture)

    missing = SELF_TEST_EXPECTED - found
    leaked = SELF_TEST_REJECTED & found
    for n in sorted(missing):
        print(f"  MISSED  real member {n}", file=sys.stderr)
    for n in sorted(leaked):
        print(f"  LEAKED  non-member {n}", file=sys.stderr)
    total = len(SELF_TEST_EXPECTED) + len(SELF_TEST_REJECTED)
    ok = total - len(missing) - len(leaked)
    print(f"self-test: {ok}/{total} cases correct")
    return 0 if not missing and not leaked else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="every member with its suggestion")
    ap.add_argument("--unmapped", action="store_true", help="only members needing a decision")
    ap.add_argument("--self-test", action="store_true", help="prove the depth check works")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not os.path.isdir(SOURCES) or not os.path.isdir(TESTS):
        print(f"error: run from the repo root (expected {SOURCES}/ and {TESTS}/)", file=sys.stderr)
        return 2

    members = shape_members()
    if not members:
        print(
            "error: found no members of `extension Shape` anywhere in "
            f"{SOURCES}/. That is almost certainly this script being wrong rather than the tree "
            "being empty, so it is an error rather than a report of zero.",
            file=sys.stderr,
        )
        return 1
    result = classify(members, test_corpus())

    if args.list or args.unmapped:
        for name in members:
            domain, state = result[name]
            if args.unmapped and state == "mapped":
                continue
            print(f"{state:10s}\t{domain or '-':28s}\t{name}")
        return 0

    counts = collections.Counter()
    for domain, state in result.values():
        counts[domain if state == "mapped" else state] += 1
    print(f"members of extension Shape: {len(members)}")
    for key, n in counts.most_common():
        print(f"  {n:4d}  {key}")
    mapped = sum(n for k, n in counts.items() if k not in ("AMBIGUOUS", "UNTESTED"))
    print(f"\n  {mapped} of {len(members)} have a single-target suggestion; the rest need a decision.")
    print("  Run --unmapped for those. Report how many end up in Shape+Misc.swift: a large Misc")
    print("  means the test-target vocabulary does not fit, which #663 needs to know before it")
    print("  applies the same rule to Document.swift.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
