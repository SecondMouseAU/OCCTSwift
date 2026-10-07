#!/usr/bin/env python3
"""CENSUS, not a gate: prose that describes the kernel before the one now pinned (#3056).

A repin changes three facts the prose states by name: WHICH kernel is pinned (`v4.0.0-kernel.K`),
HOW MANY patches the pinned asset and `Scripts/patches/` hold, and WHICH betas are cut. #3031 pinned
`v4.0.0-kernel.4`; #3054 then corrected about thirty sentences in ten files, fifteen of them of this
kind ("the pin below is now v4.0.0-kernel.3", "the asset holds thirty-one and Scripts/patches/ holds
thirty-four", "v4.0.0-beta.4 | not cut"), and review found one more. `check-inventory-prose.py`
reads the other half, a patch called not-yet-pinned, by resolving each sentence to a patch number.
These sentences name no patch, so nothing resolved them.

Three shapes, each derived from the tree rather than hand-kept:

  K1  A `vX.Y.Z-kernel.N` older than the one `Package.swift` pins, written as the CURRENT one.
  K2  A patch count stated for the pinned asset or for `Scripts/patches/` that differs from the
      count derived from the pin enumeration or the directory.
  K3  A `vX.Y.Z-beta.N` described as "not cut", or to be cut, while that tag exists.

WHY K1 IS ANCHORED TO WORDS ADJACENT TO THE TAG
-----------------------------------------------
The tree is full of older tags that are correct, because a measurement or a history names the
kernel it was taken on: "measured on the pinned kernel.2 asset", "pinned from kernel.3", "the
kernel.1 asset held thirty-one patches". Measured on `main` at b4db0bf50 (2026-10-07), 2,051 prose
files, 126 sentences name a `kernel.K` older than the pin, and only 2 of them are stale (a patch
README entry and a test comment, both still saying `kernel.3` was the pin after `kernel.4`).

  * Flag every older tag, or require an explicit historical marker on each: 126 findings, 124 of
    them false, and a marker design is 124 annotations across the tree before it is quiet.
  * A sentence-level rule (an older tag AND "pinned", "now", "current" or "pins" anywhere in the
    sentence): 66 findings, 64 false. "now" belongs to another clause ("pinned from kernel.3, so
    the return is now a measurement") and a parenthesised history sits beside the CURRENT tag.
  * The rule below, an anchor ADJACENT to the tag: 5 findings, 2 stale and 3 history, so the
    residue is 3 sentences (a patch README "Pin consequence" written when `kernel.1` WAS the pin,
    twice, and a v2.0.0 plan sentence). Those three are stale-but-historical and are left
    unmarked on purpose: the residue is what #3056 asks a human to judge.

Strong anchors say the tag IS the current pin and flag even in a sentence that also says
"measured": `Package.swift pins <tag>`, `is now <tag>`, `native is on <tag>`, `currently <tag>`,
`will publish <tag>`, `<tag>, the asset Package.swift pins`. Weak anchors, `the pinned <tag>` and
`now <tag>`, flag only when the sentence carries no past-tense or measurement word, because
"Measured on the pinned kernel.2 asset" is a frozen measurement whose "pinned" was true the day it
was written. `--measure` reproduces the three counts after a repin.

A sentence that is deliberate history takes `kernel-prose-exempt: <reason>` beside it, the same
escape `check-inventory-prose.py` gives the patch-state check (`pin-state-exempt:`).

Rejected on measurement: a K2 rule for "the N carried patches". It hits 6 sentences on the tree and
none is stale ("Thirteen of the twenty-nine carried patches", "all 29 carried patches where beta.2
carried 17"), so it would cost a false positive per sentence to gain the two "Survey the 30
carried patches" rows #3054 had to rewrite.

WHAT IT CANNOT SEE
------------------
A sentence that says the kernel is stale without naming a tag, a count or a beta ("now yields a
different checksum from the pinned asset", "the asset holds `TrimInfinite(...)`" about a tag
the sentence never names) and a bare number that is a measurement about the tree ("over 79 modified
files"). The short form `kernel.3` with no `vX.Y.Z-` prefix is not read either.

WHY THIS IS A CENSUS AND NOT A GATE
-----------------------------------
Its false-positive rate on the live tree is not zero (3 of 5 sentences above), and the residue is
the instructive part: a sentence that is stale-but-historical, such as a patch README entry written
when `kernel.1` WAS the pin, is a reading a human has to adjudicate, because rewriting it erases a
record and leaving it misleads. Per `okf/policies/static-gates.md` it exits 0 always and CI runs
only its `--self-test`. #3056 stays open until the user decides whether the residue is small enough
for a gate.

    python3 Scripts/census-stale-kernel-prose.py                 # report on this checkout
    python3 Scripts/census-stale-kernel-prose.py --root PATH     # report on another tree
    python3 Scripts/census-stale-kernel-prose.py --measure       # per-design counts, K1 only
    python3 Scripts/census-stale-kernel-prose.py --self-test
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.dirname(HERE)

EXEMPT_MARKER = "kernel-prose-exempt:"

# The census's own text quotes every shape it detects, so it is not a population member.
SELF_SKIP = {"Scripts/census-stale-kernel-prose.py"}

TAG_RE = re.compile(r"v(\d+)\.(\d+)\.(\d+)-kernel\.(\d+)")
PIN_URL_RE = re.compile(r"releases/download/(v\d+\.\d+\.\d+-kernel\.\d+)/OCCT\.xcframework\.zip")


def load_prose_helpers(root):
    """`check-inventory-prose.py` as a module, pointed at `root`.

    That script already owns the population (`prose_files`), the sentence splitter that keeps a
    markdown table row's cells apart (`prose_units`) and the derived patch counts, and a second
    copy of any of them would drift from it. Its filename has a hyphen, so it loads by path.
    """
    spec = importlib.util.spec_from_file_location(
        "check_inventory_prose", os.path.join(HERE, "check-inventory-prose.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.REPO = root
    return module


def tag_key(tag):
    """(version, kernel number) of a `vX.Y.Z-kernel.N` tag, or None."""
    match = TAG_RE.search(tag)
    return tuple(int(g) for g in match.groups()) if match else None


def pinned_tags(root):
    """(native pin, wasm pin or None) as tag strings, from `Package.swift` and the wasm pin file."""
    with open(os.path.join(root, "Package.swift"), encoding="utf-8") as handle:
        match = PIN_URL_RE.search(handle.read())
    native = match.group(1) if match else None
    wasm = None
    path = os.path.join(root, "Scripts", "wasm-kernel-pin.txt")
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as handle:
            found = re.search(r"^OCCT_WASM_RELEASE_TAG=(\S+)", handle.read(), re.MULTILINE)
        wasm = found.group(1) if found else None
    return native, wasm


def git_tags(root):
    """Every tag in the repo, or an empty set when git cannot say (a K3 skip, reported)."""
    try:
        out = subprocess.run(["git", "-C", root, "tag", "-l"], capture_output=True, text=True,
                             timeout=30, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    return {line.strip() for line in out.splitlines() if line.strip()}


# --- K1: an older kernel tag written as the current one ---------------------------------------

# Anchors are matched against the text immediately BEFORE the tag (ending where the tag starts,
# with an optional backtick already stripped) or immediately AFTER it. Every entry says why it is
# an anchor; a pattern that cannot say is how the sentence-level design came to flag "is now a
# measurement".
STRONG_BEFORE = [
    (r"(?:Package\.swift`?|the manifest)\s+pins\s+(?:the\s+)?$", "Package.swift pins <tag>"),
    (r"\b(?:is|are) now\s+(?:the\s+)?$", "the pin is now <tag>"),
    (r"\b(?:is|are) on\s+$", "native is on <tag>"),
    (r"\bcurrently\s+(?:the\s+)?$", "currently <tag>"),
    (r"\b(?:will\s+)?publish(?:es)?(?:\s+is)?\s+(?:the\s+)?$", "will publish <tag>, a tag that exists"),
]
# There is deliberately no "<tag> asset holds N" anchor: an asset is immutable, so what an OLD
# tag's asset holds is a fact that stays true, and only "the PINNED <tag> asset" is the claim.
STRONG_AFTER = [
    (r"^[`,\s]*the (?:asset|kernel|release)\s+`?(?:Package\.swift|the manifest)`?\s+pins\b",
     "<tag>, the asset Package.swift pins"),
]
WEAK_BEFORE = [
    (r"\bpinned\s+(?:the\s+)?$", "the pinned <tag>"),
    (r"\bnow\s+(?:the\s+)?$", "now <tag>"),
]
# A word that makes a sentence a record rather than a claim. It silences a WEAK anchor only: a
# strong anchor states the tag is the pin, and "re-measured against kernel.3, the asset
# Package.swift pins" is exactly the stale shape (Tests/OCCTCurveTests/Issue477, #3056).
HISTORY_RE = re.compile(
    r"\b(?:measured|re-measured|measurement|verified|re-verified|was|were|had|held|used to|belonged|"
    r"spent|stayed|remained|closed|retired|repinned|expire[sd]?|as of|since|from|onward|before|"
    r"first|shipped|published|ago|history|then|wrote|written|found|caught|rebuilt|replaced|"
    r"superseded|at the time|against)\b|\b20\d\d-\d\d-\d\d\b",
    re.IGNORECASE)


def older_tag_matches(sentence, current_keys, pin_key):
    """Matches of a `vX.Y.Z-kernel.N` strictly older than the pin, minus the wasm pin.

    The wasm kernel is pinned separately and may deliberately lag (#2785), so its tag is current
    and is passed in `current_keys`. The native pin is excluded by the strict `<`.
    """
    found = []
    for match in TAG_RE.finditer(sentence):
        key = tuple(int(g) for g in match.groups())
        if key < pin_key and key not in current_keys:
            found.append(match)
    return found


def k1_anchor(sentence, match):
    """('strong'|'weak', why) when text adjacent to this tag claims it is current, else None."""
    start, end = match.start(), match.end()
    if start and sentence[start - 1] == "`":
        start -= 1
    # Every "before" pattern ends in `$`, so only the words directly in front of the tag count and
    # no clause or sentence boundary needs cutting.
    before = sentence[max(0, start - 60):start]
    after = sentence[end + 1:end + 60] if end < len(sentence) and sentence[end] == "`" \
        else sentence[end:end + 60]
    for pattern, why in STRONG_BEFORE:
        if re.search(pattern, before, re.IGNORECASE):
            return "strong", why
    for pattern, why in STRONG_AFTER:
        if re.search(pattern, after, re.IGNORECASE):
            return "strong", why
    for pattern, why in WEAK_BEFORE:
        if re.search(pattern, before, re.IGNORECASE):
            return "weak", why
    return None


def k1_findings(rel, text, pin, wasm, units):
    """Findings for one file. `units` yields (line, sentence, anchor), as `prose_units` does."""
    pin_key = tag_key(pin)
    current = {tag_key(wasm)} if wasm else set()
    problems = []
    for line, sentence, _anchor in units(text):
        if EXEMPT_MARKER in sentence or not TAG_RE.search(sentence):
            continue
        for match in older_tag_matches(sentence, current, pin_key):
            anchor = k1_anchor(sentence, match)
            if anchor is None:
                continue
            strength, why = anchor
            if strength == "weak" and HISTORY_RE.search(sentence):
                continue
            problems.append((rel, line, "K1", "names %s as current (%s), and Package.swift pins %s"
                             % (match.group(0), why, pin), sentence))
            break
    return problems


# --- K2: a patch count that differs from the derived one --------------------------------------

NUMBER = r"\**((?:\d+)|(?:[a-z]+(?:-[a-z]+)?))\**"
# The number is a patch count only when "patch(es)" or the end of the clause follows it: "has 24 edge
# occurrences" is a count of something else (Issue613IndexContractTests).
COUNT_END = r"(?=\s+(?:carried\s+)?patch|\s*[,.;)]|\s+(?:and|so|against|but|while|where)\b|$)"
ASSET_COUNT_RE = re.compile(
    r"\b(?:pinned (?:asset|kernel)|the asset|asset)\b[^.|;]{0,40}?"
    r"\b(?:holds|carries|has|contains)\s+" + NUMBER + COUNT_END, re.IGNORECASE)
TREE_COUNT_RE = re.compile(
    r"`?Scripts/patches/`?\s+(?:holds|carries|has|contains)\s+" + NUMBER + COUNT_END,
    re.IGNORECASE)


def tag_before(sentence, end):
    """The kernel tag that directly qualifies the word at offset `end` ("the v4.0.0-kernel.1 asset
    holds"), or None. An asset is immutable, so a count stated for an OLD tag's asset is a fact."""
    found = re.search(r"(v\d+\.\d+\.\d+-kernel\.\d+)`?(?:\s+(?:pre-release|binary))*\s+$",
                      sentence[max(0, end - 60):end])
    return found.group(1) if found else None


def k2_findings(rel, text, pinned_count, tree_count, units, to_int, pin=None):
    """Counts stated for the pinned asset or for Scripts/patches/ that the tree contradicts."""
    problems = []
    for line, sentence, _anchor in units(text):
        if EXEMPT_MARKER in sentence:
            continue
        for regex, derived, what in ((ASSET_COUNT_RE, pinned_count, "the pinned asset"),
                                     (TREE_COUNT_RE, tree_count, "Scripts/patches/")):
            for match in regex.finditer(sentence):
                if sentence[:match.start()].count('"') % 2:
                    continue  # the sentence is quoting the claim as an example of a stale one
                word = re.search(r"asset", match.group(0), re.IGNORECASE)
                qualifier = tag_before(sentence, match.start() + word.start()) if word else None
                if qualifier and pin and tag_key(qualifier) != tag_key(pin):
                    continue  # an older asset's contents are history, and K1 reads the tag
                stated = to_int(match.group(1))
                if stated is None or stated == derived:
                    continue
                problems.append((rel, line, "K2", "states %d for %s, which derives to %d"
                                 % (stated, what, derived), sentence))
    return problems


# --- K3: a beta described as not cut while its tag exists -------------------------------------

NOT_CUT_ROW_RE = re.compile(r"\|\s*`?(v\d+\.\d+\.\d+-beta\.\d+)`?\s*\|\s*(?:\*\*)?not (?:yet )?cut\b",
                            re.IGNORECASE)
# An instruction to cut a beta that is already cut ("Cut `v4.0.0-beta.4` once the repin is verified").
CUT_NEXT_RE = re.compile(r"\bCut\s+`?(v\d+\.\d+\.\d+-beta\.\d+)`?")
NOT_CUT_PROSE_RE = re.compile(
    r"`?(v\d+\.\d+\.\d+-beta\.\d+|beta\.\d+)`?[^.\n|]{0,30}?\bnot (?:yet )?cut\b", re.IGNORECASE)


def k3_findings(rel, text, cut_tags):
    """A beta tag that exists and is described as not cut. Reads raw lines: a table row's cells
    are split apart by the sentence reader, and the tag and "not cut" sit in different cells."""
    problems = []
    for number, raw in enumerate(text.split("\n"), 1):
        if EXEMPT_MARKER in raw:
            continue
        names = [m.group(1) for m in NOT_CUT_ROW_RE.finditer(raw)]
        names += [m.group(1) for m in NOT_CUT_PROSE_RE.finditer(raw)]
        names += [m.group(1) for m in CUT_NEXT_RE.finditer(raw)]
        for name in names:
            if raw[:raw.find(name)].count('"') % 2:
                continue  # quoted as an example of the shape, not stating it
            exists = name in cut_tags if name.startswith("v") else any(
                tag.endswith("-" + name) for tag in cut_tags)
            if exists:
                problems.append((rel, number, "K3",
                                 "says %s is not cut (or is still to be cut), and that tag exists"
                                 % name, raw.strip()))
    return problems


# --- the run -----------------------------------------------------------------------------------


def read_population(root, helpers):
    """(rel, text) for every prose file the census reads."""
    for rel in helpers.prose_files():
        if rel in SELF_SKIP:
            continue
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as handle:
                yield rel, handle.read()
        except (UnicodeDecodeError, OSError):
            continue


def census(root, show_measure=False):
    helpers = load_prose_helpers(root)
    native, wasm = pinned_tags(root)
    if native is None:
        print("census-stale-kernel-prose: no OCCT.xcframework.zip pin found in Package.swift; "
              "nothing to compare against")
        return 0
    pinned_count = len(helpers.pinned_patch_numbers())
    tree_count = len(helpers.numbered_patch_files())
    cut = git_tags(root)
    findings = []
    population = 0
    for rel, text in read_population(root, helpers):
        population += 1
        findings += k1_findings(rel, text, native, wasm, helpers.prose_units)
        findings += k2_findings(rel, text, pinned_count, tree_count, helpers.prose_units,
                                helpers.to_int, native)
        findings += k3_findings(rel, text, cut)

    print("census-stale-kernel-prose: prose that describes the kernel before the one now pinned")
    print("  pin: %s (wasm pin: %s)   pinned patches: %d   Scripts/patches/: %d   tags read: %d"
          % (native, wasm, pinned_count, tree_count, len(cut)))
    if not cut:
        print("  NOTE: git listed no tags, so K3 (a beta called not cut) was SKIPPED, not clean.")
    print("  files read: %d" % population)
    for kind in ("K1", "K2", "K3"):
        print("  %s: %d" % (kind, sum(1 for f in findings if f[2] == kind)))
    print()
    for rel, line, kind, why, sentence in sorted(findings, key=lambda f: (f[0], f[1], f[2])):
        print("  %s:%d: %s %s" % (rel, line, kind, why))
        print("      %s" % re.sub(r"\s+", " ", sentence)[:200])
    if findings:
        print()
        print("  Each is a candidate. A sentence that is deliberate history takes "
              "`%s <reason>`; anything else is the prose a repin owes a rewrite." % EXEMPT_MARKER)
    if show_measure:
        measure(root, helpers, native, wasm)
    return 0


def measure(root, helpers, native, wasm):
    """K1's population under each anchor design, so the choice can be re-checked after a repin."""
    pin_key = tag_key(native)
    current = {tag_key(wasm)} if wasm else set()
    every = by_sentence = by_adjacent = 0
    for rel, text in read_population(root, helpers):
        for _line, sentence, _anchor in helpers.prose_units(text):
            if not older_tag_matches(sentence, current, pin_key) or EXEMPT_MARKER in sentence:
                continue
            every += 1
            if re.search(r"\b(?:pinned|now|current|currently|pins)\b", sentence, re.IGNORECASE):
                by_sentence += 1
        by_adjacent += len(k1_findings(rel, text, native, wasm, helpers.prose_units))
    print()
    print("  K1 designs over the same population (sentences naming an older tag):")
    print("    every older tag:                         %d" % every)
    print("    + a currentness word anywhere:           %d" % by_sentence)
    print("    + an anchor adjacent to the tag (used):  %d" % by_adjacent)


# --- self-test ---------------------------------------------------------------------------------


def self_test():
    helpers = load_prose_helpers(DEFAULT_ROOT)
    units = helpers.prose_units
    to_int = helpers.to_int
    pin, wasm = "v4.0.0-kernel.4", "v4.0.0-kernel.2"
    cases = []

    def k1(text, wasm_tag=wasm):
        return k1_findings("f.md", text, pin, wasm_tag, units)

    def case(name, ok):
        cases.append((name, bool(ok)))

    # K1 positives: each is the shape of a sentence #3054 had to rewrite, from the pre-fix tree.
    case("K1: 'the pin below is now <older tag>' is flagged",
         len(k1("// The pin below is now v4.0.0-kernel.3, built from a tree whose only "
                "modifications are the carried patches.")) == 1)
    case("K1: 'Package.swift pins the <older tag> pre-release asset' is flagged",
         len(k1("`Package.swift` pins\nthe `v4.0.0-kernel.3` pre-release asset, which is that "
                "same V8_0_1 plus the carried patches.")) == 1)
    case("K1: 'native is on <older tag>' is flagged",
         len(k1("native is on `v4.0.0-kernel.3` and wasm on `v4.0.0-kernel.2`, and the "
                "acknowledgement is keyed to the native count.")) == 1)
    case("K1: a tag the prose says it WILL publish, which already exists, is flagged",
         len(k1("**The pre-release tag this family will publish is `v4.0.0-kernel.3`, not "
                "`kernel.2`.**")) == 1)
    case("K1: 're-measured against <older tag>, the asset Package.swift pins' is flagged",
         len(k1("Re-measured 2026-10-01 against `v4.0.0-kernel.3`, the asset `Package.swift` "
                "pins: the repro is in Scripts/repro/766.")) == 1
         and len(k1("Re-measured against Package.swift pins v4.0.0-kernel.3 on 2026-10-01.")) == 1)

    case("K1: 'the pinned <older tag> asset' with no record word is flagged (weak anchor)",
         len(k1("Run the probe against nothing but the pinned `v4.0.0-kernel.3` asset resolves "
                "it.")) == 0
         and len(k1("The pinned `v4.0.0-kernel.3` asset resolves the repro.")) == 1)

    # K1 negatives: the legitimate history the tree is full of.
    case("K1: 'Measured on the pinned <older tag> asset' is a record and is silent",
         k1("Measured on the pinned v4.0.0-kernel.2 asset (Scripts/repro/2801): Pole(7) "
            "returns garbage.") == [])
    case("K1: 'pinned from <older tag>' is silent",
         k1("Carried patch `0043` drops that condition and is pinned from `v4.0.0-kernel.3`.") == [])
    case("K1: 'the <older tag> asset held N patches' is silent",
         k1("The `v4.0.0-kernel.1` asset held **thirty-one** patches.") == [])
    case("K1: the CURRENT pin beside older tags in a parenthesis is silent",
         k1("The pin below is now v4.0.0-kernel.4, built from a clean tree (v4.0.0-kernel.3 "
            "computed the same over 79).") == [])
    case("K1: the pin itself, named as current, is silent",
         k1("Package.swift pins `v4.0.0-kernel.4`.") == [])
    case("K1: the wasm pin, which may lag on purpose, is silent",
         k1("Package.swift pins v4.0.0-kernel.4 and wasm is currently `v4.0.0-kernel.2`.") == [])
    case("K1: the same wasm tag IS flagged when no wasm pin excuses it",
         len(k1("native is on v4.0.0-kernel.2 now.", wasm_tag=None)) == 1)
    case("K1: a NEWER tag than the pin is a plan, not a stale claim, and is silent",
         k1("Package.swift pins v4.0.0-kernel.5 next week.") == [])
    case("K1: the exemption marker silences a sentence",
         k1("kernel-prose-exempt: frozen record. native is on v4.0.0-kernel.3.") == [])
    case("K1: a weak anchor in a sentence with a history word is silent",
         k1("Compared against the pinned v4.0.0-kernel.2 asset as of 2026-09-28.") == [])
    case("K1: 'tree pins <older tag>' in a history table is silent",
         k1("v2.0.0-kernel.2 -> tree pins v2.0.0-kernel.1 v2.0.0-kernel.3 -> tree pins "
            "v2.0.0-kernel.2") == [])

    # K2.
    def k2(text, pinned=39, tree=39):
        return k2_findings("f.md", text, pinned, tree, units, to_int, pin)

    case("K2: 'the asset holds thirty-one' beside a derived 39 is flagged",
         len(k2("The asset holds thirty-one and Scripts/patches/ holds thirty-four.")) == 2)
    case("K2: a count that matches the derivation is silent",
         k2("The pinned asset holds thirty-nine patches and `Scripts/patches/` holds 39.") == [])
    case("K2: past tense ('held') is a record and is silent",
         k2("At the time the asset held thirty-one patches and Scripts/patches/ carried "
            "thirty-four.") == [])
    case("K2: an OLDER tag's asset holding a count is a fact and is silent",
         k2("The v4.0.0-kernel.1 asset holds **thirty-one** patches against a tree of "
            "twenty-nine.") == [])
    case("K2: the CURRENT tag's asset is still compared against the derivation",
         len(k2("The v4.0.0-kernel.4 asset holds thirty-one patches.")) == 1)
    case("K2: a count of something else after 'has' is silent",
         k2("Measured on the pinned kernel, a plain box has 24 edge occurrences over 12 "
            "distinct edges.") == [])
    case("K2: a quoted example of a stale claim is silent",
         k2('"The pinned asset holds thirty-one patches" and "the asset held thirty-one".') == [])
    case("K2: a differing count is reported against the right derivation",
         [f[3] for f in k2("`Scripts/patches/` holds forty.")] ==
         ["states 40 for Scripts/patches/, which derives to 39"])

    # K3.
    tags = {"v4.0.0-beta.3", "v4.0.0-beta.4"}
    case("K3: a table row calling an existing beta 'not cut' is flagged",
         len(k3_findings("f.md", "| `v4.0.0-beta.4` | not cut | | OCCT 8.0.2 |", tags)) == 1)
    case("K3: a beta whose tag does not exist is genuinely not cut and is silent",
         k3_findings("f.md", "| `v4.0.0-beta.5` | not cut | | next |", tags) == [])
    case("K3: 'beta.4 is not cut' in prose is flagged by its short name",
         len(k3_findings("f.md", "Until then beta.4 is not cut.", tags)) == 1)
    case("K3: 'Cut <tag>' as a to-do for a tag that exists is flagged",
         len(k3_findings("f.md", "- **Cut `v4.0.0-beta.4`** once the repin is verified.", tags)) == 1
         and k3_findings("f.md", "- **Cut `v4.0.0-beta.5`** once it lands.", tags) == [])
    case("K3: a quoted example of the shape is silent",
         k3_findings("f.md", 'counts ("thirty-one", "beta.4 not cut") with', tags) == [])
    case("K3: no tags readable means nothing is judged",
         k3_findings("f.md", "| `v4.0.0-beta.4` | not cut | | x |", set()) == [])

    # Parsing the pin out of a manifest's real shape.
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        with open(os.path.join(tmp, "Package.swift"), "w", encoding="utf-8") as handle:
            handle.write('url: "https://github.com/x/y/releases/download/v9.8.7-kernel.6/'
                         'OCCT.xcframework.zip",\n')
        case("pin: the tag is read out of the binaryTarget url",
             pinned_tags(tmp) == ("v9.8.7-kernel.6", None))

    failures = 0
    for label, ok in cases:
        print("  %s  %s" % ("PASS" if ok else "FAIL", label))
        failures += 0 if ok else 1
    print("\n%d/%d self-test cases pass" % (len(cases) - failures, len(cases)))
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", default=DEFAULT_ROOT, help="the tree to read (default: this one)")
    parser.add_argument("--measure", action="store_true", help="print K1's per-design counts")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    return census(os.path.abspath(args.root), show_measure=args.measure)


if __name__ == "__main__":
    sys.exit(main())
