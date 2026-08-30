#!/usr/bin/env python3
"""#872 (part of Phase 6, #819): comments that mention a symbol or a fact which no longer holds.

CENSUS, not a gate: like the other three (`census-unmeasured-values.py`,
`census-doc-occt-attribution.py`, `census-arguments-tuple-shapes.py`), it exits 0 whether or not it
finds anything, and CI runs only its `--self-test`. #872's own text is explicit that "does this
comment still match the code" is a semantic comparison a script cannot make in general; what this
script checks is the mechanically-checkable SUBSET of that question, four ways:

1. **Dotted symbol mentions in `///`/`//` comments under `Sources/OCCTSwift`**
   (`` `Shape.filleted` ``, `` `Curve3D.arcLength` ``): does that `Type.member` still resolve to a
   live declaration? Reuses `check-docs-existence.py`'s own symbol index and resolution functions
   (`extract_source_symbols`, `doc_type_exists`, `doc_member_exists`, `member_exists_anywhere`)
   rather than re-deriving them, since that script's own docstring records exactly why a naive
   name-only check produces false positives in both directions (`ShapeContentsExtended.nbEdges`
   vs. a removed `Shape.nbEdges`) and this census would inherit the identical trap if it built its
   own index from scratch. The difference from `check-docs-existence.py` is the corpus: comments,
   not `docs/`.
2. **Bridge function mentions in comments under `Sources/OCCTBridge`**
   (`` `OCCTShapeBooleanCheck` ``): does that name still exist as a declared function in
   `Sources/OCCTBridge/include/*.h`? A different symbol space (C functions, not Swift members), so
   a separate, simpler index.
3. **`Scripts/*.py` docstring usage lines vs. real `argparse` flags**: a docstring showing
   `python3 Scripts/foo.py --bar` where `--bar` is not a flag `main()`'s `ArgumentParser` actually
   registers.
4. **`CLAUDE.md` patch-number citations vs. `Scripts/patches/*.patch` on disk**: a `Scripts/patches/
   00NN-*` citation in prose naming a file that is not actually present (already retired, or never
   existed under that number).

WHAT THIS DOES NOT CHECK, stated rather than silently absent, per #872's own scope. Bare (undotted)
symbol mentions (`` `filleted` ``) are not checked here for the identical reason
`check-docs-existence.py` treats them only as coverage, never as a failing check: the "owning type"
of a bare mention inside a comment is even less determinable than inside a `docs/` page, since a
comment has no heading/filename convention to lean on at all. Described *behavior* (a stated
default, a claimed fallback, a "why this line exists" rationale) is not checked: confirming those
needs reading the code the comment sits on, which is exactly the semantic work #872 says a script
cannot do and defers to whoever picks this pass up. `CLAUDE.md`'s Known OCCT Bugs *narrative*
claims ("fixed upstream in vX.Y.Z", "not yet filed") are not re-verified against live GitHub/OCCT
state here either, per `feedback-verify-external-status-claims`: that needs a network call per
claim and a human/agent judgement call per result, not a census line.

    python3 Scripts/census-comment-staleness.py
    python3 Scripts/census-comment-staleness.py --self-test

Run from the repo root. Exit code is always 0 (a census, never a gate); `--self-test` exits 1 on a
detector failure.
"""
from __future__ import annotations

import argparse
import glob
import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(ROOT)


def _load_docs_existence_module():
    path = os.path.join(ROOT, "check-docs-existence.py")
    spec = importlib.util.spec_from_file_location("check_docs_existence", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


DOC_EXIST = _load_docs_existence_module()

COMMENT_LINE_RE = re.compile(r'^\s*(///|//)(?!/)(.*)$')
# Same shape as check-docs-existence's INLINE_DOTTED_RE, applied to a comment's own text rather
# than a docs/ page's prose.
DOTTED_MENTION_RE = re.compile(r'`([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)(?:\([^`]*\))?`')
BRIDGE_MENTION_RE = re.compile(r'`(OCCT[A-Za-z0-9_]+)`')
BRIDGE_DECL_RE = re.compile(r'\bOCCT[A-Za-z0-9_]+(?=\s*\()')

# Standard library / Foundation / Dispatch / Metal types this codebase's comments quote often
# (`` `Int.max` ``, `` `Task.detached` ``, `` `MTLDevice.makeBuffer` ``) that are never going to be
# in Sources/OCCTSwift's own symbol index and are not this census's business: measured directly,
# 15 of the first 36 raw hits were exactly this shape before this exclusion existed. Extend rather
# than special-case a symptom if a new one shows up; this is a namespace exclusion, not a per-symbol
# allowlist, on purpose, since the alternative (matching a curated per-symbol list) would need
# updating every time a comment quotes a new stdlib member.
EXTERNAL_TYPE_PREFIXES = {
    "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Float16", "Float80", "Bool", "String", "Character", "Substring",
    "Optional", "Array", "Dictionary", "Set", "Range", "ClosedRange", "PartialRangeFrom",
    "Sequence", "Collection", "Task", "URL", "Data", "Date", "TimeInterval",
    "DispatchSemaphore", "DispatchQueue", "DispatchTime", "DispatchGroup",
    "MTLDevice", "MTLBuffer", "MTLTexture", "MTLCommandQueue",
    "NSObject", "NSError", "NSString", "NSNumber", "Error", "Result", "Any", "AnyObject",
    "ObjectIdentifier", "Unmanaged", "ContiguousArray", "IndexSet",
}
# OCCT/bridge source-file references quoted in prose (`` `OCCTBridge_Topology.mm` ``,
# `` `TopTools_ShapeMapHasher.hxx` ``): a file name, not a Type.member mention, same idea as
# check-docs-existence.py's own `NON_SYMBOL_TAILS` (which only needs `.swift`/`.md`, since `docs/`
# pages don't quote C++ source files the way source comments constantly do).
FILE_EXTENSION_TAILS = {"mm", "hxx", "cxx", "h", "hpp", "cpp", "m"}

# Broader than check-docs-existence.py's own HISTORICAL_RE (`removed|deprecated|no longer
# exists|renamed`): source comments narrate history far more colloquially than a docs/ page does
# ("used to sit behind", "the older X sibling"), measured directly against four of this census's
# own first-pass hits (`OCCTShapeUpgradeDivideContinuity`, `OCCTInertiaProperties`,
# `OCCTVolumeInertiaResult`, `OCCTDatumInfo.name`), every one an accurate description of something
# already gone, not a live claim.
HISTORICAL_RE = re.compile(
    r'\b(removed|deprecated|no longer|renamed|used to|older .{0,30}?sibling|the old |previously)\b',
    re.IGNORECASE)

# A comment can also correctly mention a symbol that does NOT exist because it's describing a
# hypothetical the code deliberately guards against, not a live claim about the current API
# (`Edge.swift`'s own "If a future `Edge.orientation` accessor... is added, re-run that audit"):
# the opposite direction from HISTORICAL_RE (not-yet-real rather than no-longer-real), but the
# same shape of false positive for this census.
HYPOTHETICAL_RE = re.compile(
    r'\b(if a future|were (?:a|it) to|would (?:be|need)|hypothetical(?:ly)?)\b', re.IGNORECASE)


def comment_block_text(lines, target_idx):
    """The contiguous run of `///`/`//` comment lines (any code between counts as a break)
    surrounding `lines[target_idx]`, joined, for a HISTORICAL_RE search across the whole remark
    rather than just the one physical line the mention happens to sit on."""
    start = target_idx
    while start > 0 and COMMENT_LINE_RE.match(lines[start - 1]):
        start -= 1
    end = target_idx
    while end + 1 < len(lines) and COMMENT_LINE_RE.match(lines[end + 1]):
        end += 1
    return "\n".join(lines[start:end + 1])


def swift_comment_findings():
    """Channel 1: dotted symbol mentions inside Sources/OCCTSwift comments.

    The live index also includes Tests/**/*.swift, since a comment legitimately cross-references a
    test suite/method by name (`` `Issue298FilletThreadSafetyTests` `` and similar), and those
    declarations live only in Tests/, never in Sources/OCCTSwift.
    """
    src_files = {}
    for path in sorted(glob.glob(os.path.join(REPO_ROOT, DOC_EXIST.SRC_GLOB))):
        with open(path, encoding="utf-8") as fh:
            src_files[path] = fh.read()
    scan_files = dict(src_files)  # comments are only scanned in Sources/, not Tests/ itself
    for path in sorted(glob.glob(os.path.join(REPO_ROOT, "Tests", "**", "*.swift"), recursive=True)):
        with open(path, encoding="utf-8") as fh:
            src_files[path] = fh.read()  # indexed for resolution only, not scanned for comments

    live_types, live_members, live_free, conformances, access = DOC_EXIST.extract_source_symbols(src_files)
    DOC_EXIST.resolve_conformances(live_members, conformances, access)

    findings = []
    for path, text in scan_files.items():
        lines = text.splitlines()
        for idx, line in enumerate(lines):
            lineno = idx + 1
            m = COMMENT_LINE_RE.match(line)
            if not m:
                continue
            for dm in DOTTED_MENTION_RE.finditer(line):
                t, member = dm.group(1), dm.group(2)
                if t in EXTERNAL_TYPE_PREFIXES:
                    continue
                if member in DOC_EXIST.NON_SYMBOL_TAILS or member in FILE_EXTENSION_TAILS:
                    continue
                if DOC_EXIST.doc_member_exists(t, member, live_types, live_members):
                    continue
                block = comment_block_text(lines, idx)
                if HISTORICAL_RE.search(block):
                    continue  # accurately describes something already gone, not a live claim
                if HYPOTHETICAL_RE.search(block):
                    continue  # describes a not-yet-real future case, not a live claim either
                if not DOC_EXIST.doc_type_exists(t, live_types):
                    # The type itself is gone (renamed/removed); still worth a distinct note since
                    # the fix is "update the type name", not "update the member".
                    findings.append((path, lineno, f"`{t}.{member}`", "type not found", line.strip()))
                    continue
                findings.append((path, lineno, f"`{t}.{member}`", "member not found on that type", line.strip()))
    return findings


BRIDGE_IDENT_RE = re.compile(r'\bOCCT[A-Za-z0-9_]+\b')


def bridge_declared_functions():
    """Every `OCCTXxx` identifier that appears anywhere on a non-comment header line: function
    declarations (`BRIDGE_DECL_RE`'s original, narrower net), but also struct/enum typedef names
    (`} OCCTVolumeInertiaResult;`), which appear with no trailing `(` at all and were the source of
    a real false positive (`OCCTVolumeInertiaResult` IS declared, at OCCTBridge_Properties.h:426,
    just as a typedef target, not a function). A census only needs "this identifier is genuinely
    somewhere in the live header text", not a precise function-vs-type classification."""
    live = set()
    for path in sorted(glob.glob(os.path.join(REPO_ROOT, "Sources/OCCTBridge/include/*.h"))):
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*"):
                    continue
                for m in BRIDGE_IDENT_RE.finditer(line):
                    live.add(m.group(0))
    return live


def bridge_comment_findings():
    """Channel 2: bridge function-name mentions inside Sources/OCCTBridge comments."""
    live = bridge_declared_functions()
    findings = []
    for path in sorted(glob.glob(os.path.join(REPO_ROOT, "Sources/OCCTBridge/src/*.mm"))) + \
            sorted(glob.glob(os.path.join(REPO_ROOT, "Sources/OCCTBridge/include/*.h"))):
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        for idx, line in enumerate(lines):
            lineno = idx + 1
            stripped = line.strip()
            is_comment = stripped.startswith("//") or (stripped.startswith("*") and "/*" not in stripped and "*/" not in stripped)
            if not is_comment:
                continue
            for bm in BRIDGE_MENTION_RE.finditer(line):
                name = bm.group(1)
                if name in live:
                    continue
                if HISTORICAL_RE.search(comment_block_text(lines, idx)):
                    continue  # accurately describes something already gone, not a live claim
                findings.append((path, lineno, f"`{name}`", "bridge function not declared anywhere", stripped))
    return findings


def script_flag_findings():
    """Channel 3: a Scripts/*.py docstring usage line naming a flag argparse doesn't register."""
    findings = []
    usage_re = re.compile(r'python3\s+Scripts/([A-Za-z0-9_.\-/]+\.py)((?:\s+--[A-Za-z0-9-]+)*)')
    flag_re = re.compile(r'--[A-Za-z0-9-]+')
    for path in sorted(glob.glob(os.path.join(REPO_ROOT, "Scripts/*.py"))):
        basename = os.path.basename(path)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        declared_flags = set(re.findall(r'add_argument\([\'"](--[A-Za-z0-9-]+)[\'"]', text))
        if not declared_flags:
            continue  # a script with no argparse flags at all has nothing to check here
        # Docstring is the leading triple-quoted string; scan the whole file's text for usage
        # lines regardless, a usage example living outside the docstring is still a claim.
        for lineno, line in enumerate(text.splitlines(), start=1):
            um = usage_re.search(line)
            if not um or um.group(1) != basename:
                continue
            for flag in flag_re.findall(um.group(2)):
                if flag not in declared_flags:
                    findings.append((path, lineno, flag, "flag not registered by argparse", line.strip()))
    return findings


def claude_md_findings():
    """Channel 4: Scripts/patches/00NN-* citations in CLAUDE.md against files on disk."""
    findings = []
    claude_path = os.path.join(REPO_ROOT, "CLAUDE.md")
    real_patches = {os.path.basename(p) for p in glob.glob(os.path.join(REPO_ROOT, "Scripts/patches/*.patch"))}
    real_numbers = {os.path.basename(p)[:4] for p in real_patches}
    cite_re = re.compile(r'`Scripts/patches/(\d{4})-[A-Za-z0-9_.\-]*\.patch`')
    with open(claude_path, encoding="utf-8") as fh:
        for lineno, line in enumerate(fh, start=1):
            for m in cite_re.finditer(line):
                num = m.group(1)
                cited_file = m.group(0).strip('`').split('/')[-1]
                if num not in real_numbers:
                    findings.append((claude_path, lineno, f"`Scripts/patches/{cited_file}`",
                                      "no patch with this number is on disk (retired or renumbered)",
                                      line.strip()[:160]))
    return findings


def run_census(quiet=False):
    channels = [
        ("Sources/OCCTSwift comments, dotted symbol mentions", swift_comment_findings()),
        ("Sources/OCCTBridge comments, bridge function mentions", bridge_comment_findings()),
        ("Scripts/*.py docstring usage flags", script_flag_findings()),
        ("CLAUDE.md patch-number citations", claude_md_findings()),
    ]
    total = 0
    for title, findings in channels:
        total += len(findings)
        if quiet:
            continue
        print(f"\n=== {title}: {len(findings)} ===")
        for path, lineno, symbol, reason, context in findings:
            rel = os.path.relpath(path, REPO_ROOT)
            print(f"  {rel}:{lineno}: {symbol} — {reason}")
            print(f"      {context}")
    if not quiet:
        print(f"\nTotal candidates: {total} (a census: none of these are auto-fixed; each needs a "
              f"human/agent read to confirm before filing, per #872's own worked examples of a "
              f"heuristic's false-positive rate)")
    return channels


def self_test():
    failures = []

    # Channel 1 fixture: inject a comment mentioning a plainly nonexistent type/member and confirm
    # the SAME resolution machinery check-docs-existence.py already trusts flags it.
    tmp_dir = os.path.join(REPO_ROOT, "Sources", "OCCTSwift")
    fixture_name = "_CensusCommentStalenessSelfTestFixture.swift"
    fixture_path = os.path.join(tmp_dir, fixture_name)
    fixture_content = (
        "// self-test fixture, deleted immediately after use\n"
        "struct CensusFixtureLive {\n"
        "    /// See `CensusFixtureLive.realMember` for the real one.\n"
        "    var realMember: Int = 0\n"
        "    /// See `CensusFixtureLive.ghostMember`, which does not exist.\n"
        "    var other: Int = 0\n"
        "    /// The removed `CensusFixtureLive.retiredMember` used to hold this instead (historical,\n"
        "    /// should not be flagged).\n"
        "    var third: Int = 0\n"
        "    /// If a future `CensusFixtureLive.futureMember` accessor is added, revisit this\n"
        "    /// (hypothetical, should not be flagged).\n"
        "    var fourth: Int = 0\n"
        "}\n"
    )
    try:
        with open(fixture_path, "w", encoding="utf-8") as fh:
            fh.write(fixture_content)
        findings = swift_comment_findings()
        symbols_hit = [(path, symbol) for path, _, symbol, _, _ in findings if fixture_name in path]
        hit = any("ghostMember" in symbol for _, symbol in symbols_hit)
        if not hit:
            failures.append("injected stale `Type.ghostMember` comment mention was not caught")
        if any("realMember" in symbol for _, symbol in symbols_hit):
            failures.append("a comment mentioning a REAL member (`realMember`) was wrongly flagged")
        if any("retiredMember" in symbol for _, symbol in symbols_hit):
            failures.append("a HISTORICAL mention (`retiredMember`, 'removed'/'used to') was wrongly flagged")
        if any("futureMember" in symbol for _, symbol in symbols_hit):
            failures.append("a HYPOTHETICAL mention (`futureMember`, 'if a future') was wrongly flagged")
    finally:
        if os.path.exists(fixture_path):
            os.remove(fixture_path)

    # Channel 2 fixture: same shape, for a bridge function name.
    findings = bridge_comment_findings()
    # No injection needed to prove the detector *can* fire: run it against a synthetic in-memory
    # check instead, since writing into Sources/OCCTBridge for a self-test is riskier (clang-format
    # gate, code-structure gate) than the Swift-side fixture above.
    live = bridge_declared_functions()
    if "OCCTShapeCreateBox" not in live:
        failures.append("bridge_declared_functions() did not find a known-real function "
                         "(OCCTShapeCreateBox) -- the header scan itself is broken")
    if "OCCTThisFunctionDoesNotExist" in live:
        failures.append("bridge_declared_functions() reported a function that cannot exist")

    # Channel 3 fixture: a temp script with a docstring usage line naming an unregistered flag.
    tmp_script = os.path.join(REPO_ROOT, "Scripts", "_census_comment_staleness_selftest.py")
    try:
        with open(tmp_script, "w", encoding="utf-8") as fh:
            fh.write(
                '"""\n'
                "    python3 Scripts/_census_comment_staleness_selftest.py --real-flag\n"
                "    python3 Scripts/_census_comment_staleness_selftest.py --ghost-flag\n"
                '"""\n'
                "import argparse\n"
                "ap = argparse.ArgumentParser()\n"
                "ap.add_argument('--real-flag', action='store_true')\n"
            )
        findings = script_flag_findings()
        hit = any("_census_comment_staleness_selftest.py" in path and flag == "--ghost-flag"
                  for path, _, flag, _, _ in findings)
        if not hit:
            failures.append("injected undocumented --ghost-flag usage line was not caught")
        false_positive = any("_census_comment_staleness_selftest.py" in path and flag == "--real-flag"
                              for path, _, flag, _, _ in findings)
        if false_positive:
            failures.append("a real, registered flag (--real-flag) was wrongly flagged")
    finally:
        if os.path.exists(tmp_script):
            os.remove(tmp_script)

    # Channel 4: exercised directly against the real CLAUDE.md/Scripts/patches, no injection (an
    # injected fake patch-number citation would need editing CLAUDE.md itself, riskier than reading
    # the real file); instead prove the two mechanical facts it depends on are sound.
    findings = claude_md_findings()
    real_numbers = {os.path.basename(p)[:4] for p in glob.glob(os.path.join(REPO_ROOT, "Scripts/patches/*.patch"))}
    if not real_numbers:
        failures.append("no Scripts/patches/*.patch files found at all -- glob is broken")
    stale_ids = {f[2] for f in findings}
    for f in findings:
        num = f[2].split("/")[-1][:4]
        if num in real_numbers:
            failures.append(f"claude_md_findings() flagged {f[2]} but that number IS on disk")

    if failures:
        for f in failures:
            print(f"SELF-TEST FAILURE: {f}")
        return False
    print("SELF-TEST: OK (4 channels: injected miss caught, injected real-symbol correctly not "
          "flagged, header/patch scans sane)")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--self-test", action="store_true", help="prove each channel's detector works")
    ap.add_argument("--quiet", action="store_true", help="only print the total")
    args = ap.parse_args()

    if args.self_test:
        return 0 if self_test() else 1

    run_census(quiet=args.quiet)
    return 0  # census, never a gate


if __name__ == "__main__":
    os.chdir(REPO_ROOT)
    sys.exit(main())
