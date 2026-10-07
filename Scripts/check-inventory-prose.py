#!/usr/bin/env python3
"""Gate: every counted claim this repo makes about its own inventories must match the inventory.

Two inventories keep drifting from the prose that describes them, and each drift has shipped more
than once:

  * the carried OCCT patches in ``Scripts/patches/``, counted in ``Package.swift``'s pin comment,
    in ``CLAUDE.md`` and in ``okf/references/carried-occt-patches.md``, and
  * the static gate scripts run by ``ci.yml``'s ``gate-scripts`` job, counted in that job's own
    comment, in ``CLAUDE.md`` and in ``okf/policies/static-gates.md``.

A third record of the first inventory joined them in #2885: ``Scripts/occt-raise-if-map.txt`` is a
committed derivation of the PATCHED ``Libraries/occt-src``, and it carries a stamp naming the
carried patches the tree held. Nothing re-derived that map when a patch changed a raise site, so it
described a kernel we had stopped shipping for two pins. The re-derivation needs the tree; the
stamp does not, which is what lets this gate hold it against ``Scripts/patches/`` on every PR.

#2910 widened it past the kernel. ``CLAUDE.md`` is the working summary of how this repo works, and
three more of its counted claims about the repo's own shape had no derivation at all: the
swift-format exemption manifest, the bridge file counts and the test-target list. The manifest is
the sharpest case, because it is the one inventory designed to drain: #2852's rule is that a PR
touching an exempt file brings it into compliance and deletes its line, so that number falls on its
own and the prose was stale within days of being written. (The manifest drained to nothing and was
retired, this gate's reader of it with it.) The bridge counts are the opposite shape
and failed the same way: "All 33 bridge files are enforced" described the tree before the
#1378/#1380 split multiplied it to 93, and no edit was needed to make the sentence wrong.

**#2954 then took every counted claim out of ``CLAUDE.md``.** The gates were working and the
claims were still expensive: a count in the working summary is shared by every open PR, so a
correct edit to the inventory reds every other branch at merge time, which the manifest row did
three times in one day. The counts were not deleted. Each went to the page that owns its subject,
where the gate follows it: the patch counts to ``okf/references/carried-occt-patches.md``, the
gate/census/audit counts to ``okf/policies/static-gates.md``, the enforced-bridge population to
``okf/policies/code-style.md``, and the bridge header and implementation counts nowhere at all,
because ``README.md`` and ``docs/architecture/overview.md`` already carried and gated them. The
one real deletion is the manifest's size, which is now stated in no file, because every file is
equally shared and rehoming the sentence would have rehomed the collision. ``CLAUDE.md`` still
appears below, for the test-target list: that is an inventory rather than a count, so no PR
invalidates it by draining it.

**Correct today with nothing keeping it so is the finding, not just wrong today.** The sweep that
filed these measured five claims and found three wrong and two right, and both of the right ones
are registered here anyway: which is which was not knowable from reading the file, and that is the
property the gate restores.

The recurrence is the argument for a gate rather than another proofread: ci.yml called the job's
scripts "five" while running thirteen (#1066), the pinned-patch count went stale at
v2.0.0-kernel.1 through .3, at #1032 and at #1157/#1402, and one carried-patch row key was written
with an ellipsis so it named no file on disk. Filed as #1408, which asked for exactly this.

How it works. Every claim is registered below in CLAIMS as a (file, regex, fact) triple. The regex
must capture the number, written as digits or as an English number word, and the fact names a value
this script DERIVES from the repo. A claim fails if the number disagrees with the derived value, and
it also fails if the regex matches nothing at all, since a reworded sentence that no longer matches
is a claim nobody is checking any more, which is the state this gate exists to end.

**#3056 added the first check here that reads tense rather than a number.** A repin that pins a
carried patch leaves behind prose saying that patch is "NOT built", "not pinned" or "must be
deleted when this is pinned", true the day before and false the day after. #3031 pinned eight
patches and #3054 had to correct about thirty such statements in ten files; review found one.
``check_stale_pin_prose`` derives each patch's real state from ``Package.swift``'s pinned-asset
list (``pinned_patch_numbers``) and flags a sentence that calls a PINNED patch not-yet-pinned. It
judges only a sentence it can resolve to one patch, by a patch number in the sentence, a
``Package.swift`` row, a table row keyed by a number, or a ``## NNNN-`` section; it is silent
about a past-tense sentence, about a patch named for comparison, and about every sentence that
resolves to nothing. The same words about a patch the list does not hold are correct, which is why
an unpinned patch's prose needs no edit. It is a REPORT until ``PIN_PROSE_IS_GATE`` flips (see
okf/policies/static-gates.md); ``--strict-pin-prose`` makes it exit 1 today. It cannot see the
by-plane mirror's own comments, which name no pinned state, or a count and a kernel tag that went
stale: those are counted claims above, or have no anchor to resolve against.

Run from anywhere; paths resolve from __file__.
"""

import argparse
import glob
import hashlib
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WORDS = {
    # "none" is here so the unpinned-count sentences can read naturally at zero, which is their
    # normal state between a repin and the next patch landing (#2773, v4.0.0-kernel.2).
    "none": 0, "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
    "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
    "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
    "twenty-one": 21, "twenty-two": 22, "twenty-three": 23, "twenty-four": 24, "twenty-five": 25,
    "twenty-six": 26, "twenty-seven": 27, "twenty-eight": 28, "twenty-nine": 29, "thirty": 30,
    "thirty-one": 31, "thirty-two": 32, "thirty-three": 33, "thirty-four": 34, "thirty-five": 35,
    "thirty-six": 36, "thirty-seven": 37, "thirty-eight": 38, "thirty-nine": 39, "forty": 40,
    "forty-one": 41, "forty-two": 42, "forty-three": 43, "forty-four": 44, "forty-five": 45,
}


def to_int(token):
    """A number written as digits or as an English word, or None if it is neither."""
    token = token.strip().lower()
    if token.isdigit():
        return int(token)
    return WORDS.get(token)


def read(rel):
    with open(os.path.join(REPO, rel), encoding="utf-8") as handle:
        return handle.read()


# --- the derived facts -------------------------------------------------------------------------


def patch_files():
    """Stems of every carried patch on disk, e.g. 0010-Intf_Interference-...-319."""
    paths = glob.glob(os.path.join(REPO, "Scripts", "patches", "*.patch"))
    return sorted(os.path.basename(p)[: -len(".patch")] for p in paths)


def patch_number(stem):
    """The leading NNNN of a carried patch stem, or None when it is not NNNN-named (#2148)."""
    return int(stem[:4]) if stem[:4].isdigit() else None


def numbered_patch_files():
    """`patch_files()` restricted to the NNNN-named ones, which is every counted fact's subject.

    #2148: two checks and three counted facts read `int(stem[:4])` off these stems, so one file in
    `Scripts/patches/` that is not NNNN-named took the whole gate down with a `ValueError`
    traceback instead of reporting anything. A crash tells the reader the tool is broken when what
    is broken is the tree, and it takes the other twenty-one claims down with it.

    This is not hypothetical. The WASI branch named its kernel patches `wasi-*.patch`, CI died on
    `invalid literal for int() with base 10: 'wasi'`, and the resulting bug report concluded the
    census script "does not exist in the repository at all". Those patches belong in
    `Scripts/patches-wasi/` and now live there, but nothing in this gate ever said so, which is the
    part worth fixing: `check_patch_naming` below now says it.
    """
    return [stem for stem in patch_files() if patch_number(stem) is not None]


def wasi_patch_files():
    """Stems of every WASI-only patch on disk, e.g. wasi-osd-chronometer.

    A separate sequence from `patch_files()`: `Scripts/patches-wasi/` is applied by
    `build-occt-wasm.sh` alone, is deliberately not NNNN-named, and is pinned into no release
    asset. None of that made its prose unworth checking, which is what #2166 corrected: the two
    counted claims in that directory's README were the only ones in the repo nothing read.
    """
    paths = glob.glob(os.path.join(REPO, "Scripts", "patches-wasi", "*.patch"))
    return sorted(os.path.basename(p)[: -len(".patch")] for p in paths)


def pinned_patch_numbers(text=None):
    """The patch numbers enumerated in Package.swift's pinned-asset comment."""
    text = read("Package.swift") if text is None else text
    start = text.find("survive, all present in Scripts/patches/, are:")
    if start < 0:
        return []
    numbers = []
    for line in text[start:].split("\n")[1:]:
        stripped = line.strip()
        if not stripped.startswith("//"):
            break
        body = stripped[2:].strip()
        if not body:
            if numbers:
                break
            continue
        match = re.match(r"^(\d{4})\s", body)
        if match:
            numbers.append(match.group(1))
    return numbers


def gate_job_scripts(text=None):
    """Scripts invoked by ci.yml's gate-scripts job, split into bare and --self-test runs."""
    text = read(".github/workflows/ci.yml") if text is None else text
    start = text.find("\n  gate-scripts:")
    if start < 0:
        return {}, {}
    rest = text[start + 1:]
    end = re.search(r"\n  [A-Za-z0-9_-]+:\n", rest)
    job = rest[: end.start()] if end else rest
    bare, selftest = set(), set()
    for match in re.finditer(r"run:\s*python3 Scripts/([A-Za-z0-9_.-]+\.py)([^\n]*)", job):
        name, args = match.group(1), match.group(2)
        (selftest if "--self-test" in args else bare).add(name)
    return bare, selftest


def gate_job_invocations(text=None):
    """How many `python3 Scripts/...` steps ci.yml's gate-scripts job runs, invocations not scripts.

    Distinct from gate_job_scripts(), which de-duplicates a script's bare and --self-test runs into
    one name. static-gates.md's hook paragraph counts invocations, so it needs this number.
    """
    text = read(".github/workflows/ci.yml") if text is None else text
    start = text.find("\n  gate-scripts:")
    if start < 0:
        return 0
    rest = text[start + 1:]
    end = re.search(r"\n  [A-Za-z0-9_-]+:\n", rest)
    job = rest[: end.start()] if end else rest
    return len(re.findall(r"run:\s*python3 Scripts/[A-Za-z0-9_.-]+\.py", job))


def hook_invocations(text=None):
    """How many of those invocations Scripts/git-hooks/pre-commit runs.

    #2058 found this sentence stale by six: the hook had drifted to twenty of twenty-eight while the
    policy still said twenty of twenty-one, flag for flag with one named exception. A hand-counted
    number in a sentence about an inventory is exactly what this gate exists for, so it is derived.
    """
    text = read("Scripts/git-hooks/pre-commit") if text is None else text
    return len(re.findall(r'^run "[^"]+"\s+Scripts/[A-Za-z0-9_.-]+\.py', text, re.MULTILINE))


def bridge_source_files(*suffixes):
    """Every file under Sources/OCCTBridge/ with one of `suffixes`, recursively.

    #2910. Three counted claims in CLAUDE.md's bridge paragraphs are derivable from this tree and
    none of them was derived: the enforced clang-format population, the per-domain header set and
    the Objective-C++ implementation count. Two of the three were wrong when the sweep measured
    them, both because the bridge split (#1378, #1380) multiplied the file count and the prose that
    described the old layout stayed.
    """
    found = []
    for root, _dirs, names in os.walk(os.path.join(REPO, "Sources", "OCCTBridge")):
        for name in names:
            if name.endswith(suffixes):
                found.append(os.path.relpath(os.path.join(root, name), REPO))
    return sorted(found)


def bridge_enforced_files():
    r"""The population `Scripts/format-bridge.sh` clang-formats: every bridge header and `.mm`.

    Mirrors that script's `enforced_files()`, which is `find Sources/OCCTBridge \( -name '*.h' -o
    -name '*.mm' \)`. There is no exemption list to subtract: the bridge manifest was empty for
    months before it was retired, and the Swift one was retired with it, so every file is enforced
    by construction.
    """
    return bridge_source_files(".h", ".mm")


def bridge_domain_headers():
    """The per-domain headers in Sources/OCCTBridge/include/, excluding the OCCTBridge.h umbrella.

    #395 split one header into an umbrella plus one per domain, and CLAUDE.md has stated the split
    as "N files: OCCTBridge.h umbrella + M per-domain headers" ever since. Both halves are derived
    here so the sentence cannot describe a different number of domains from the directory.
    """
    include = os.path.join("Sources", "OCCTBridge", "include")
    return sorted(f for f in bridge_source_files(".h")
                  if os.path.dirname(f) == include
                  and os.path.basename(f) != "OCCTBridge.h")


def test_target_names(text=None):
    """Every `.testTarget(name:)` declared in Package.swift, in declaration order."""
    text = read("Package.swift") if text is None else text
    return re.findall(r"\.testTarget\(\s*name:\s*\"([^\"]+)\"", text)


def classify(text=None):
    """The gate/census/audit/release-check split, derived from the job, not a hand-kept list.

    #2196 added the fourth bucket. `gate-scripts` runs a script bare unless the script cannot
    answer there: a census cannot, because its answer is a list of sites for a human rather than a
    verdict; a release check cannot, because its input is not in the checkout. Both therefore
    appear in the job as a `--self-test` and nothing else, and before this the second kind fell
    into no bucket at all, so "N gates, M censuses and one merge-history audit" would have
    described fewer scripts than the job runs while every claim on this page still passed.
    """
    bare, selftest = gate_job_scripts(text)
    everything = bare | selftest
    censuses = {n for n in everything if n.startswith("census-")}
    audits = {n for n in everything if n == "check-changelog-transcription.py"}
    gates = {n for n in bare if n not in censuses and n not in audits}
    releases = {n for n in selftest if n not in bare and n not in censuses and n not in audits}
    return {
        "gates": gates,
        "censuses": censuses,
        "audits": audits,
        "releases": releases,
        "all": everything,
        "selftest": selftest,
    }


def script_declares_require_flag(name, text=None):
    """True when `Scripts/<name>` defines a `--require-...` flag, #2098's "examined nothing" mode.

    This is what distinguishes a release check from a gate that somebody forgot to invoke bare: a
    script whose real run needs an input CI does not have carries the flag that turns a run which
    examined nothing into an error, rather than reporting clean about a population it never read.
    """
    if text is None:
        try:
            text = read(os.path.join("Scripts", name))
        except OSError:
            return False
    return bool(re.search(r"""add_argument\(\s*['"]--require-[a-z-]+['"]""", text))


def facts():
    split = classify()
    gates_with_selftest = split["gates"] & split["selftest"]
    return {
        "patches_on_disk": len(numbered_patch_files()),
        # #2166: the WASI-only sequence, counted in Scripts/patches-wasi/README.md.
        "wasi_patches_on_disk": len(wasi_patch_files()),
        "patches_pinned": len(pinned_patch_numbers()),
        # #1403: the count of patches the pinned asset LACKS. Package.swift and
        # carried-occt-patches.md both introduce their unpinned lists with this number, and both
        # went stale at 0032, 0033 AND 0034 because no claim read it.
        "patches_unpinned": len(numbered_patch_files()) - len(pinned_patch_numbers()),
        "gate_scripts": len(split["gates"]),
        "census_scripts": len(split["censuses"]),
        "audit_scripts": len(split["audits"]),
        # #2196: the fourth kind. A script whose real run belongs to the release process and whose
        # `--self-test` alone runs in the job, counted separately because it is neither a gate nor
        # a census and folding it into either would make the sentence untrue.
        "release_check_scripts": len(split["releases"]),
        "job_scripts": len(split["all"]),
        "job_scripts_minus_one": len(split["all"]) - 1,
        "gates_with_selftest": len(gates_with_selftest),
        # #2058: the two numbers in static-gates.md's pre-commit-hook paragraph. Invocations, not
        # scripts, because that is what the sentence counts.
        "job_invocations": gate_job_invocations(),
        "hook_invocations": hook_invocations(),
        # #2910: the three bridge-tree counts CLAUDE.md states and nothing read. Two of the three
        # were already wrong when the sweep measured them, left behind by the #1378/#1380 split.
        "bridge_enforced_files": len(bridge_enforced_files()),
        "bridge_domain_headers": len(bridge_domain_headers()),
        "bridge_include_headers": len(bridge_domain_headers()) + 1,
        "bridge_impl_files": len(bridge_source_files(".mm")),
        "test_targets": len(test_target_names()),
    }


# --- the claims --------------------------------------------------------------------------------
#
# (file, regex capturing the number in group 1, fact name). One entry per sentence that states a
# count. Reword a sentence and its regex must be updated with it: that is the point.

CLAIMS = [
    ("Package.swift", r"OCCT V8_0_1 \+ the (\S+) carried patches listed below", "patches_pinned"),
    ("Package.swift", r"under \"Retired patches\"\)\.\s*The (\S+) that", "patches_pinned"),
    ("Package.swift", r"plus (?:the )?(\S+) patches listed above", "patches_pinned"),
    ("Package.swift", r"Scripts/patches/ holds ([A-Za-z-]+) patches", "patches_on_disk"),
    # #1403: three claims that existed all along and were read by nothing. Kilo's review caught the
    # first two by hand on PR #2041 after 0034 landed; the third had gone stale unnoticed.
    # #2773, revised at the v4.0.0-kernel.2 repin: both files now use the same sentence shape,
    # "lacks <count> of them", because it is grammatical at none, one and many alike. The previous
    # pair of regexes each matched only one of those, so taking the count to zero broke both with
    # "no sentence matches", which reads like the regex rotted rather than the prose moving. A
    # count that is wrong should fail as a count mismatch; only a reworded sentence should fail as
    # a missing match.
    ("Package.swift", r"[Tt]he pinned asset lacks (\S+) of them", "patches_unpinned"),
    ("okf/references/carried-occt-patches.md",
     r"`Scripts/patches/` holds ([A-Za-z-]+) patches", "patches_on_disk"),
    ("okf/references/carried-occt-patches.md",
     r"pins lacks (\S+) of them", "patches_unpinned"),
    # #2954. The pinned count moved here from CLAUDE.md, which states no count now. Both of this
    # page's statements of it are registered: the xcframework section's, which the move added, and
    # the wasm section's, which was already written and which nothing read, so it could have gone
    # stale at a repin exactly as the CLAUDE.md copy did.
    ("okf/references/carried-occt-patches.md",
     r"of which the pinned asset carries ([A-Za-z0-9-]+)", "patches_pinned"),
    ("okf/references/carried-occt-patches.md",
     r"the pinned native asset carries ([A-Za-z0-9-]+)", "patches_pinned"),
    ("Package.swift", r"`ls Scripts/patches/\*\.patch \| wc -l` answers (\d+)", "patches_on_disk"),
    # #2166: the WASI sequence. `Scripts/patches-wasi/` was outside this gate entirely until the
    # patch-number parser stopped being the reason, and its README said "both patches here apply
    # cleanly" while PR #2076 had fifteen sitting in the same directory.
    # `(\S+)` and a tolerant plural for the same reason every sibling entry uses them: a count
    # written as a digit, or a drop to one patch making the noun singular, should fail as a count
    # mismatch rather than as "no sentence matches", which reads like the regex rotted.
    ("Scripts/patches-wasi/README.md",
     r"`Scripts/patches-wasi/` holds (\S+) patch(?:es)?\b", "wasi_patches_on_disk"),
    # #2885: the count line in Scripts/occt-raise-if-map.txt's provenance stamp. The digest
    # comparison in check_raise_map_provenance() below would catch a stale count too, and this
    # entry is still here rather than left to it: the stamp states a count in prose, every counted
    # claim in this repo is registered in this table, and the issue asked for it to be registered
    # rather than checked only by new code. The two failures read differently on purpose, one as a
    # count mismatch and one naming the patch the map predates.
    ("Scripts/occt-raise-if-map.txt",
     r"# derived against: (\d+) carried patch\(es\)", "patches_on_disk"),
    # #2954. The gate/census/audit headline sentence moved out of CLAUDE.md to the page that owns
    # the subject. The claim is the same claim, read in its new home: CLAUDE.md states no count.
    ("okf/policies/static-gates.md",
     r"(\S+) gates, \S+ censuses and \S+ merge-history audit", "gate_scripts"),
    ("okf/policies/static-gates.md",
     r"\S+ gates, (\S+) censuses and \S+ merge-history audit", "census_scripts"),
    ("okf/policies/static-gates.md",
     r"\S+ gates, \S+ censuses and (\S+) merge-history audit", "audit_scripts"),
    # #2196: the fourth kind, stated in its own sentence rather than folded into the one above. It
    # is not a gate (its real run is not in this job at all) and not a census (its real run reaches
    # a verdict), so counting it as either would make a checked sentence untrue, which is the
    # failure this gate exists to prevent rather than to commit. CLAUDE.md carried a second copy of
    # this sentence until #2954; the one here is the survivor.
    ("okf/policies/static-gates.md", r"runs (\S+) release check", "release_check_scripts"),
    (".github/workflows/ci.yml", r"because all (\S+) are pure Python", "job_scripts"),
    (".github/workflows/ci.yml", r"does not hide the\s*#\s*other (\S+)\.", "job_scripts_minus_one"),
    ("okf/policies/static-gates.md", r"(\S+) of the \S+ gates, all \S+ censuses", "gates_with_selftest"),
    ("okf/policies/static-gates.md", r"\S+ of the (\S+) gates, all \S+ censuses", "gate_scripts"),
    ("okf/policies/static-gates.md", r"\S+ of the \S+ gates, all (\S+) censuses", "census_scripts"),
    ("okf/policies/static-gates.md", r"The (\S+) censuses today", "census_scripts"),
    # #2058. Both halves of the hook paragraph's sentence, which had gone stale at both ends.
    ("okf/policies/static-gates.md",
     r"pre-commit` runs ([A-Za-z-]+) of `gate-scripts`'", "hook_invocations"),
    ("okf/policies/static-gates.md",
     r"of `gate-scripts`' ([A-Za-z-]+) invocations", "job_invocations"),
    # #2910, the bridge tree. "All N bridge files are enforced" said 33 against a tree of 93, and
    # CLAUDE.md's architecture block said 16 headers and one .mm per domain against 18 and 74. Both
    # predate the #1378/#1380 split, which is how a sentence goes stale without anybody editing it.
    # #2954 moved the enforced-population sentence to the policy that owns the population, and
    # deleted CLAUDE.md's three architecture numbers outright rather than rehoming them, because
    # README.md and docs/architecture/overview.md already state and gate all three below.
    #
    # The neighbouring "21.1.8 and 22.1.8 disagree on 10 of the files" is deliberately NOT here and
    # lost its denominator instead, in both files that carry it. It is a measurement somebody took
    # on the tree of the day, not a count of an inventory, so re-deriving its denominator would
    # restate a comparison nobody ran across 93 files. A frozen measurement has to read as frozen;
    # this gate's subject is the claims that describe the tree as it is now.
    ("okf/policies/code-style.md",
     r"all (\S+)\s*\n?\s*`Sources/OCCTBridge` files are enforced", "bridge_enforced_files"),
    # #2910, the same two facts in the four places the sweep found them outside CLAUDE.md. Each had
    # drifted independently, which is the argument for registering a copy rather than deleting it:
    # the architecture sketch is useful where it is, and a reader of README.md is not going to open
    # docs/architecture/overview.md to find out whether its numbers are the live ones.
    ("README.md", r"\((\S+) per-domain headers \+ a slim OCCTBridge\.h umbrella\)",
     "bridge_domain_headers"),
    ("README.md", r"^Sources/OCCTBridge/src/\s+(\S+) Objective-C\+\+ implementation files",
     "bridge_impl_files"),
    ("docs/architecture/overview.md", r"# (\S+) per-domain C declaration files",
     "bridge_domain_headers"),
    ("docs/architecture/overview.md", r"# (\S+) implementation files, ten domains split",
     "bridge_impl_files"),
    ("Scripts/derive-bridge-header-split.py",
     r"so there are (\S+) \.mm files against \S+ headers", "bridge_impl_files"),
    ("Scripts/derive-bridge-header-split.py",
     r"so there are \S+ \.mm files against (\S+) headers", "bridge_include_headers"),
    ("Scripts/derive-bridge-header-split.py",
     r"All (\S+) bridge header files: the umbrella", "bridge_include_headers"),
    ("Scripts/derive-bridge-header-split.py",
     r"the umbrella plus the (\S+) per-domain headers", "bridge_domain_headers"),
]


def check_claims(values=None):
    values = facts() if values is None else values
    problems = []
    for rel, pattern, fact in CLAIMS:
        try:
            text = read(rel)
        except OSError as exc:
            problems.append("%s: cannot read (%s)" % (rel, exc))
            continue
        match = re.search(pattern, text, re.MULTILINE)
        if not match:
            problems.append(
                "%s: no sentence matches /%s/, so the %s claim is no longer checked. Update the "
                "regex in Scripts/check-inventory-prose.py alongside the rewording."
                % (rel, pattern, fact))
            continue
        stated = to_int(match.group(1))
        if stated is None:
            problems.append("%s: %r is not a number this gate can read (claim: %s)"
                            % (rel, match.group(1), fact))
        elif stated != values[fact]:
            problems.append("%s: says %s where %s is %d\n    %s"
                            % (rel, match.group(1), fact, values[fact], match.group(0).strip()))
    return problems


def check_patch_rows():
    """Every carried-patch row names a file on disk, and every file on disk has a row."""
    text = read("okf/references/carried-occt-patches.md")
    on_disk = set(patch_files())
    keyed = set()
    problems = []
    for match in re.finditer(r"^\|\s*`(\d{4}[^`]*)`", text, re.MULTILINE):
        key = match.group(1)
        if re.fullmatch(r"\d{4}", key):
            continue  # the unpinned-patch table keys by number alone, deliberately
        keyed.add(key)
        if key not in on_disk:
            problems.append(
                "okf/references/carried-occt-patches.md: row `%s` names no file in "
                "Scripts/patches/. Row keys are filenames, so an abbreviated one cannot be "
                "resolved back to the patch it describes." % key)
    for stem in sorted(on_disk - keyed):
        problems.append("Scripts/patches/%s.patch has no row in "
                        "okf/references/carried-occt-patches.md" % stem)
    return problems


def check_wasi_patch_rows():
    """Every row in Scripts/patches-wasi/README.md names a file there, and every file has a row.

    #2166. The sibling of `check_patch_rows()`, for the sequence that gate never looked at. A
    count alone would not be enough: PR #2076 grew that directory from two patches to fifteen and
    the README's table still described two, so the table itself is what has to be held to the
    directory.

    The empty-directory report is the "validate the view" rule from okf/policies/static-gates.md
    rather than a defect the tree can currently have: a mistyped glob here would report clean
    forever, exactly the way derive-bridge-header-split.py reported `misfiled: 0` while reading 2
    declarations of 16 (#2080).
    """
    readme = os.path.join(REPO, "Scripts", "patches-wasi", "README.md")
    if not os.path.exists(readme):
        return ["Scripts/patches-wasi/README.md: missing. The directory's patches are described "
                "nowhere, and this gate has nothing to check them against (#2166)."]
    text = read("Scripts/patches-wasi/README.md")
    on_disk = set(wasi_patch_files())
    problems = []
    if not on_disk and os.path.isdir(os.path.dirname(readme)):
        problems.append(
            "Scripts/patches-wasi/ yielded no .patch files. Either the directory really is empty, "
            "in which case its README should say so, or this gate is reading the wrong path and "
            "has been reporting clean without looking (#2166).")
    keyed = set()
    for match in re.finditer(r"^\|\s*`([A-Za-z0-9_.-]+)\.patch`", text, re.MULTILINE):
        stem = match.group(1)
        keyed.add(stem)
        if stem not in on_disk:
            problems.append(
                "Scripts/patches-wasi/README.md: row `%s.patch` names no file in "
                "Scripts/patches-wasi/." % stem)
    for stem in sorted(on_disk - keyed):
        problems.append("Scripts/patches-wasi/%s.patch has no row in "
                        "Scripts/patches-wasi/README.md" % stem)
    return problems


def carried_sequence_numbers(text):
    """Expand a "0010-0012, 0014-0031, 0033-0035" range list into the set it names."""
    # Tolerate a capitalised "The" and a line wrap anywhere inside the phrase: the sentence is
    # reflowed whenever a retirement is added to it, and a gate that fails on the wrap teaches
    # whoever hits it to contort the prose rather than to fix the inventory.
    match = re.search(r"[Tt]he\s+carried\s+sequence\s+now\s+reads\s+([0-9\u2013, \n-]+?)\.",
                      text)
    if not match:
        return None
    numbers = set()
    for part in re.split(r",\s*", match.group(1).replace("\n", " ").strip()):
        part = part.strip()
        if not part:
            continue
        ends = re.split(r"[\u2013-]", part)
        if len(ends) == 2 and ends[0].strip().isdigit() and ends[1].strip().isdigit():
            numbers.update(range(int(ends[0]), int(ends[1]) + 1))
        elif part.isdigit():
            numbers.add(int(part))
        else:
            return None
    return numbers


def check_carried_sequence():
    """Scripts/patches/README.md's range list must name exactly the patches on disk.

    #1403. This is prose that encodes a SET, not a count, so no CLAIMS entry can check it. It has
    gone stale three times (at 0032's retirement, at 0033 and at 0034), each time caught by a human
    reading the paragraph rather than by this gate, which was reading the counts beside it and
    reporting clean.
    """
    text = read("Scripts/patches/README.md")
    stated = carried_sequence_numbers(text)
    if stated is None:
        return ["Scripts/patches/README.md: could not find or parse the 'carried sequence now "
                "reads ...' range list. Reword it and this check must be updated with it."]
    on_disk = {patch_number(stem) for stem in numbered_patch_files()}
    problems = []
    for missing in sorted(on_disk - stated):
        problems.append("Scripts/patches/README.md: the carried sequence omits %04d, which is on "
                        "disk" % missing)
    for extra in sorted(stated - on_disk):
        problems.append("Scripts/patches/README.md: the carried sequence names %04d, which is not "
                        "on disk (retired patches belong in the gaps, not the ranges)" % extra)
    return problems


def tsan_suppression_patches(text=None):
    """Every `Scripts/patches/NNNN` a `Scripts/tsan.supp` comment cites, as a set of ints."""
    if text is None:
        text = read("Scripts/tsan.supp")
    return {int(n) for n in re.findall(r"Scripts/patches/(\d{4})", text)}


def check_tsan_suppressions():
    """A tsan.supp suppression must cite an UNPINNED patch that exists on disk.

    #1409. A suppression exists because the fix is not in the pinned kernel yet. The moment a repin
    ships that patch the suppression is dead, and it then hides a race nobody is looking for any
    more. CLAUDE.md lists retiring it as due at the repin and says of that class outright: "None of
    their tests can signal that they have outlived their fix." This is that signal.

    Deliberately implemented here rather than as its own gate: exactly ONE suppression cites a patch
    today (0030, for #1154), and a standalone script for one case is disproportionate. This file
    already reads Scripts/patches/ and Package.swift to decide what is pinned.

    The second half catches the mirror-image drift, a suppression citing a patch that no longer
    exists. Neither 0032 nor 0035 left one behind, but both were retired within a month, so the
    shape is live rather than hypothetical.
    """
    cited = tsan_suppression_patches()
    if not cited:
        return []
    on_disk = {patch_number(stem) for stem in numbered_patch_files()}
    pinned = {int(n) for n in pinned_patch_numbers()}
    problems = []
    for n in sorted(cited - on_disk):
        problems.append("Scripts/tsan.supp: cites Scripts/patches/%04d, which is not on disk. If "
                        "that patch was retired, the suppression it justified goes with it." % n)
    for n in sorted(cited & pinned):
        problems.append("Scripts/tsan.supp: cites Scripts/patches/%04d, which IS now pinned, so "
                        "the suppression is dead and is hiding a race the kernel already fixes. "
                        "Delete that entry (#1409)." % n)
    return problems


# --- the raise map's provenance stamp (#2885) ---------------------------------------------------
#
# Scripts/occt-raise-if-map.txt is a committed derivation of Libraries/occt-src, which is the tree
# AFTER Scripts/build-occt.sh applies the carried patches. Nothing re-derived it when that tree
# changed: patch 0042 added a `throw Standard_NullObject` to ShapeAnalysis::GetFaceUVBounds, and
# the map said ShapeAnalysis held no live throw for two pins while the kernel we ship held one.
# The re-derivation itself needs the tree, which no gate-scripts runner has, so what is checked
# here is the TREE'S INPUTS: the map records which carried patches produced the tree it came from,
# and that record is text this gate can hold against Scripts/patches/ on every PR.
#
# Keyed on the patch set ON DISK, not on the pinned asset. The tree build-occt.sh patches is the
# one Scripts/patches/ describes, so an unpinned patch is in the map's subject and not in the
# asset's; check-pinned-asset-patches.py is the check keyed the other way, and the two are meant
# to be able to disagree.
#
# Implemented here rather than as its own gate, on check_tsan_suppressions()' precedent above:
# one committed derivation has this shape today, this file already reads Scripts/patches/ and
# already owns "every record this repo keeps of the patch inventory matches it", and a standalone
# script for one artefact would be disproportionate.

RAISE_MAP = os.path.join("Scripts", "occt-raise-if-map.txt")


def patch_digest(path):
    """sha256 of a patch file's bytes, to 12 hex.

    A count moves when a patch lands; this moves when one is EDITED in place, which is the half a
    count cannot see and which happens every time a patch is revised under review.
    """
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()[:12]


def carried_patch_digests():
    """{stem: digest} over Scripts/patches/*.patch, the fact the map's stamp records."""
    paths = glob.glob(os.path.join(REPO, "Scripts", "patches", "*.patch"))
    return {os.path.basename(p)[: -len(".patch")]: patch_digest(p) for p in sorted(paths)}


def format_provenance(version, digests):
    """The stamp `--write-table` writes into Scripts/occt-raise-if-map.txt, as `#` lines.

    Written here rather than in the census that emits it, because the parser below is what has to
    keep reading it: a format whose writer and reader sit in different files is a format that
    drifts, and this one is load-bearing on exactly the day nobody is thinking about it.
    """
    lines = [
        "#",
        "# PROVENANCE (#2885). This map describes Libraries/occt-src AFTER Scripts/build-occt.sh",
        "# applies the carried patches, so a patch that touches a raise site changes this file.",
        "# Nothing re-derived it for two pins, and this stamp is what makes the next one fail",
        "# loudly: Scripts/check-inventory-prose.py compares it against Scripts/patches/ on every",
        "# PR, with no OCCT tree needed. Regenerate with --write-table, which rewrites the stamp",
        "# and the rows together; the rows themselves are re-checked with --reverify-table, which",
        "# needs the tree and runs in kernel-integration.yml, the one job that has one.",
        "#",
        "# The stamp says which carried patches the tree held. It does NOT say the tree held",
        "# nothing else: a retired patch whose edits were never reverted is #2190's question, and",
        "# the stray check in docs/guides/building-occt.md's \"Shipping a rebuild\" answers it.",
        "#",
        "# occt-version: %s" % version,
        "# derived against: %d carried patch(es) in Scripts/patches/, every one of them verified"
        % len(digests),
        "# derived against: applied in the tree the rows below were derived from.",
    ]
    for stem in sorted(digests):
        lines.append("# patch: %s %s" % (stem, digests[stem]))
    return lines


def parse_provenance(text):
    """{'version': str or None, 'patches': {stem: digest}} from a stamped map, None if unstamped.

    None and an empty patch set are different answers and the caller reports them differently: an
    unstamped map is one written before this check existed, and a stamped map naming no patch is
    a parser that has stopped matching. Both are failures; only the second is this gate going
    blind, which okf/policies/static-gates.md asks every detector to be able to say out loud.
    """
    patches = dict(re.findall(r"^# patch: (\S+) ([0-9a-f]{6,64})$", text, re.MULTILINE))
    version = re.search(r"^# occt-version: (\S+)$", text, re.MULTILINE)
    if not patches and not version:
        return None
    return {"version": version.group(1) if version else None, "patches": patches}


def build_script_occt_version(text=None):
    """The OCCT version Scripts/build-occt.sh checks out, e.g. "8.0.1", or None."""
    text = read(os.path.join("Scripts", "build-occt.sh")) if text is None else text
    match = re.search(r'^OCCT_VERSION="([^"]+)"', text, re.MULTILINE)
    return match.group(1) if match else None


def version_triple(version):
    """The leading `N.N.N` of an OCCT version string, or the string unchanged if it has none.

    `tree_occt_version` appends `OCC_VERSION_DEVELOPMENT` when the tree states one, and says in its
    own docstring that the suffix is "appended for a reader and not compared". Nothing enforced
    that: the comparison below was string equality, so a stamp written from a development tree
    ("8.0.2.dev") would not match `Scripts/build-occt.sh`'s bare `OCCT_VERSION` ("8.0.2") and the
    check would report a version bump that had not happened. Found in review of #2893, before the
    8.0.2 bump that would have triggered it.
    """
    match = re.match(r"^(\d+\.\d+\.\d+)", version or "")
    return match.group(1) if match else version


def check_raise_map_provenance():
    """The raise map's stamp names exactly the carried patches on disk, at the version we build.

    #2885. Three failure directions, each reported by name rather than as one digest mismatch,
    because the message has to say which patch the map predates: that is the whole content of the
    finding. An added patch is the 0042 case verbatim; a removed one is a retirement the map still
    describes; a changed one is a patch revised in place, which no count can see.

    The version half covers the other trigger the map's header has always named, an OCCT version
    bump, and it compares the numeric triple only: `Scripts/build-occt.sh` composes its tag from
    OCCT_VERSION plus an OCCT_RC token, while the tree states a development suffix in a different
    vocabulary, so the triple is the part that is comparable between the two.
    """
    try:
        text = read(RAISE_MAP)
    except OSError as exc:
        return ["%s: cannot read (%s). It is a committed derivation of Libraries/occt-src and "
                "Scripts/census-compiled-out-validation.py reads it on every run (#2885)."
                % (RAISE_MAP, exc)]
    stamp = parse_provenance(text)
    regenerate = ("Regenerate with `python3 Scripts/census-compiled-out-validation.py "
                  "--write-table`, which needs Libraries/occt-src with the carried patches "
                  "applied (Scripts/build-occt.sh produces one).")
    if stamp is None:
        return ["%s: carries no provenance stamp, so nothing knows which patch set it was derived "
                "against. %s (#2885)" % (RAISE_MAP, regenerate)]
    on_disk = carried_patch_digests()
    if not stamp["patches"] and on_disk:
        return ["%s: has a stamp but it names no patch, which is this check going blind rather "
                "than a clean tree: the `# patch: <stem> <digest>` lines have been reworded or "
                "dropped. Fix parse_provenance() in Scripts/check-inventory-prose.py alongside "
                "the rewording (#2885)." % RAISE_MAP]
    problems = []
    for stem in sorted(set(on_disk) - set(stamp["patches"])):
        problems.append(
            "Scripts/patches/%s.patch is on disk and not in %s's stamp, so the map was derived "
            "before that patch reached the tree. That is patch 0042's case exactly: it added a "
            "throw the map went two pins without. %s (#2885)" % (stem, RAISE_MAP, regenerate))
    for stem in sorted(set(stamp["patches"]) - set(on_disk)):
        problems.append(
            "%s's stamp names %s, which is not in Scripts/patches/ any more. A retired patch's "
            "raise sites stay in the map until it is re-derived from a tree without them, and "
            "build-occt.sh never reverts, so check the tree too. %s (#2885)"
            % (RAISE_MAP, stem, regenerate))
    for stem in sorted(set(on_disk) & set(stamp["patches"])):
        if on_disk[stem] != stamp["patches"][stem]:
            problems.append(
                "Scripts/patches/%s.patch has changed since %s was derived (%s on disk, %s in the "
                "stamp). A patch revised in place moves no count, which is why the stamp records "
                "a digest. %s (#2885)"
                % (stem, RAISE_MAP, on_disk[stem], stamp["patches"][stem], regenerate))
    built = build_script_occt_version()
    if built is None:
        problems.append(
            "Scripts/build-occt.sh: no `OCCT_VERSION=\"...\"` line, so the version half of the "
            "map's provenance is unchecked. Reword the check with the script (#2885).")
    elif stamp["version"] is None:
        problems.append(
            "%s: the stamp records no `# occt-version:` line, so a version bump would not show "
            "here. %s (#2885)" % (RAISE_MAP, regenerate))
    elif version_triple(stamp["version"]) != version_triple(built):
        problems.append(
            "%s: derived against OCCT %s, but Scripts/build-occt.sh builds %s. An OCCT version "
            "bump moves raise sites wholesale. %s (#2885)"
            % (RAISE_MAP, stamp["version"], built, regenerate))
    return problems


def check_patch_naming():
    """Every .patch in Scripts/patches/ is NNNN-named (#2148).

    Ignoring an odd file would be the wrong repair for the crash it used to cause: the counted
    facts would then quietly exclude it and `patches: N on disk` would disagree with `ls`, which is
    exactly the class of silent divergence this gate exists to catch. So the non-numbered file is
    reported, with the directory it probably belongs in.

    `Scripts/patches-wasi/` is deliberately NOT held to the NNNN rule here. It is a separate
    sequence with its own naming, applied by `build-occt-wasm.sh` rather than `build-occt.sh`, and
    it is not pinned into any release asset, so none of the counted facts above are about it. It is
    no longer outside the gate, though: `check_wasi_patch_rows()` reads its README against the
    directory, and one CLAIMS entry counts it (#2166).
    """
    problems = []
    for stem in patch_files():
        if patch_number(stem) is not None:
            continue
        problems.append(
            "Scripts/patches/%s.patch: carried patches are NNNN-named (CLAUDE.md, 'numbers are "
            "never reused'), and every counted claim in this gate reads that number. A patch for "
            "another target belongs in its own directory, as the WASI patches do in "
            "Scripts/patches-wasi/ (#2148)." % stem)
    return problems


def check_release_checks():
    """A self-test-only script that is not a census must say why its real run is not in the job.

    #2196. The bucket is derived from the job's shape, so anything the job runs only as a
    `--self-test` lands in it, including a gate whose bare invocation somebody forgot to add. Then
    the counted sentence would say "one release check" about a gate that is not running, and every
    claim would pass. The discriminator is the one #2098 already asked every such script for: a
    `--require-...` flag, meaning the script refuses to report clean when its input is absent.
    A script that carries no such flag is not a release check, and this says so rather than
    quietly counting it as one.
    """
    problems = []
    for name in sorted(classify()["releases"]):
        if script_declares_require_flag(name):
            continue
        problems.append(
            "Scripts/%s: ci.yml's gate-scripts job runs it only as --self-test, which is how a "
            "release check is recognised, but it defines no `--require-...` flag saying its real "
            "run needs an input this job does not have. Either add the bare invocation (it is a "
            "gate), or give it that flag and a comment saying where its real run lives (#2196)."
            % name)
    return problems


def check_test_target_list(claude=None, package=None):
    """CLAUDE.md's Test Layout list names exactly the test targets Package.swift declares.

    #2910. The list is not a count, so the CLAIMS table cannot hold it, and it is the same species
    of claim: a written inventory of the repository with nothing deriving it. It is stated as bare
    domain names ("`Analysis`, `Curve`, ...") because the surrounding prose has already said each
    one is `Tests/OCCT<Domain>Tests/`, so the comparison strips that affix off Package.swift's
    target names rather than asking the prose to spell them out.

    A target added without a line here reads to the next author as a target that does not exist,
    which is the failure that matters: "If nothing fits, use `OCCTMiscTests`" sends work to the
    wrong module when the right one is missing from the list.
    """
    claude = read("CLAUDE.md") if claude is None else claude
    declared = [re.fullmatch(r"OCCT(.+)Tests", name) for name in test_target_names(package)]
    expected = {m.group(1) for m in declared if m}
    match = re.search(
        r"Each is `Tests/OCCT<Domain>Tests/`, declared in `Package\.swift`:\s*\n+(.+?)\.\s*\n",
        claude, re.DOTALL)
    if not match:
        return ["CLAUDE.md: the Test Layout target list no longer matches the sentence this gate "
                "reads it by, so nothing is checking it. Update the regex in "
                "Scripts/check-inventory-prose.py alongside the rewording (#2910)."]
    listed = set(re.findall(r"`([A-Za-z0-9]+)`", match.group(1)))
    problems = []
    for name in sorted(expected - listed):
        problems.append("CLAUDE.md: Test Layout omits `%s`, declared in Package.swift as "
                        "OCCT%sTests" % (name, name))
    for name in sorted(listed - expected):
        problems.append("CLAUDE.md: Test Layout names `%s`, which Package.swift declares no "
                        "OCCT%sTests target for" % (name, name))
    return problems


# --- prose that states a patch's pinned state (#3056) -----------------------------------------

# A sentence that says a patch is NOT in the pinned kernel yet, or that something must happen
# when it is. Each one is true until a repin pins the patch and false the day after, which is the
# whole failure: #3031 pinned eight patches and about thirty such statements outlived it (#3054).
NOT_PINNED_PHRASES = [
    r"\bNOT built\b",
    r"\bnot (?:yet )?pinned\b",
    r"\bunpinned\b",
    r"\buntil (?:it|this|that|they) (?:is|are) pinned\b",
    r"\bwhen (?:it|this|that|they) (?:is|are) pinned\b",
    r"\bstill\b[^.|]{0,80}\b(?:in|on) the pinned (?:kernel|asset)\b",
    r"\bthe repin (?:must|that pins|which pins)\b",
    r"\bin the same change that repins\b",
]
NOT_PINNED_RE = re.compile("|".join(NOT_PINNED_PHRASES), re.IGNORECASE)

# A past-tense word just before the phrase makes it history ("was unpinned until
# v4.0.0-kernel.4"), and a version tag after "until" does too. Both are legitimate and stay
# unflagged. A sentence this misreads as history is silenced, never flagged: the rule is that the
# check does not guess.
HISTORICAL_BEFORE_RE = re.compile(
    r"\b(?:was|were|had been|had|used to|stayed|remained|spent|until)\b[^.]{0,50}$", re.IGNORECASE)
HISTORICAL_AFTER_RE = re.compile(r"^[^.]{0,20}\buntil `?v?\d+\.\d+\.\d+-kernel", re.IGNORECASE)
# "unlike `0044`", "same shape as 0042 and 0044": every patch named after a comparison word is
# there for comparison, so none of them is the subject.
COMPARISON_RE = re.compile(
    r"\b(?:unlike|than|versus|vs\.?|(?:same|shape|story|case|exception)(?: \w+)? as|like)\b",
    re.IGNORECASE)
PREFILTER_RE = re.compile(r"not\W{0,20}built|pinned|repin", re.IGNORECASE)
PRONOUN_PHRASE_RE = re.compile(r"\b(?:it|this|that|they)\b", re.IGNORECASE)
EXEMPT_MARKER = "pin-state-exempt:"

PROSE_SUFFIXES = (".md", ".swift", ".mm", ".h", ".py", ".sh", ".yml")
PROSE_SKIP_DIRS = {".git", ".build", "Libraries", "node_modules"}
PROSE_SKIP_PREFIXES = ("Scripts/repro/", "Tests/Fixtures/")
PROSE_SKIP_FILES = {"docs/CHANGELOG.md", "CHANGELOG.md", "Scripts/check-inventory-prose.py"}

# Only a leading comment marker is stripped, but every line of every file is read, so prose inside
# a `/* */` block is checked like any other (its `/*` and `*/` stay as inert punctuation).
_COMMENT_PREFIX_RE = re.compile(r"^\s*(?:///?|#|\*)\s?")
_ROW_HEADER_RE = re.compile(r"^(0\d{3})\s{2,}\S")
_BULLET_RE = re.compile(r"^(?:[-*]|\d+\.)\s+")
_PATCH_REF_RE = re.compile(r"(?<![\w#/.])(0\d{3})(?!\d)")


def prose_units(text):
    """Yield (line, sentence, anchor) for every sentence in `text`.

    `anchor` is the patch number a structured heading gives the sentence, else None: a
    Package.swift enumeration row (`//   0048  BRepGProp...` and the indented lines under it), or
    the first cell of a markdown table row when that cell is keyed by a patch number. A table row
    is split into its cells, so one cell's phrase is never read against a number in another.
    """
    blocks = []  # [first_line, anchor, [stripped lines], is_table]
    current = None
    section = None  # the patch a `## NNNN-...` heading opens, until the next heading
    for number, raw in enumerate(text.split("\n"), 1):
        line = raw.strip()
        if line.startswith("//"):
            line = line[2:]
            line = line[1:] if line.startswith("/") else line
            line = line.strip()
        else:
            line = _COMMENT_PREFIX_RE.sub("", raw).strip()
        if not line:
            current = None
            continue
        is_table = line.startswith("|")
        row = _ROW_HEADER_RE.match(line)
        raw_line = raw.strip()
        if raw_line.startswith("#"):
            heading = re.match(r"^(#+)\s*(0\d{3})-", raw_line)
            if heading:
                section = heading.group(2)
            elif raw_line.startswith("##") and not raw_line.startswith("###"):
                section = None  # a new top-level section; a deeper heading stays inside the patch's
        if row or is_table or _BULLET_RE.match(line) or line.startswith("#") or current is None:
            anchor = section
            if row:
                anchor = row.group(1)
            elif is_table:
                cell = re.match(r"^\|\s*`?(0\d{3})\b", line)
                anchor = cell.group(1) if cell else None
            current = [number, anchor, [], is_table]
            blocks.append(current)
        current[2].append(line)
    for first, anchor, lines, is_table in blocks:
        body = " ".join(lines)
        starts = []  # offset in `body` where each of the block's lines begins
        offset = 0
        for text_line in lines:
            starts.append(offset)
            offset += len(text_line) + 1

        def line_of(piece, cursor):
            """The file line holding `piece`, found at or after offset `cursor` in `body`."""
            at = body.find(piece, cursor)
            at = cursor if at < 0 else at
            index = max(i for i, begin in enumerate(starts) if begin <= at)
            return first + index, at + len(piece)

        cursor = 0
        if is_table:
            for cell in body.strip("|").split("|"):
                line, cursor = line_of(cell.strip(), cursor)
                yield line, cell.strip(), anchor
            continue
        for sentence in re.split(r"(?<=[.!?])\s+(?=[A-Z`*(\"'])", body):
            line, cursor = line_of(sentence, cursor)
            yield line, sentence, anchor


def resolve_patch(sentence, start, pronoun, anchor, known):
    """The one patch the phrase at `start` is about, or None when that is not certain.

    A pronoun phrase ("until it is pinned") is about the nearest patch number BEFORE it in the
    sentence. Any other phrase is about the sentence's only patch number, or, when the sentence
    names none, about the structured anchor. Two numbers and no pronoun resolves to None: a
    sentence comparing `0042` to `0044` is not a claim about either.
    """
    comparison = COMPARISON_RE.search(sentence)
    cut = comparison.start() if comparison else len(sentence)

    def refs(part):
        return [m.group(1) for m in _PATCH_REF_RE.finditer(part)
                if m.group(1) in known and m.start() < cut]

    named = refs(sentence)
    if pronoun:
        before = refs(sentence[:start])
        if before:
            return before[-1]
        return anchor if not named else None
    if len(set(named)) == 1:
        return named[0]
    return anchor if not named else None


def stale_pin_claims(path, text, pinned, known):
    """Sentences in `text` that call a pinned patch not-yet-pinned. `pinned` and `known` are sets."""
    if not PREFILTER_RE.search(text):
        return []  # cheap: a phrase can wrap across lines and comment markers, so test loosely
    problems = []
    for line, sentence, anchor in prose_units(text):
        if EXEMPT_MARKER in sentence:
            continue
        reported = set()  # one finding per patch per sentence, but every patch the sentence names
        for match in NOT_PINNED_RE.finditer(sentence):
            before = sentence[:match.start()]
            after = sentence[match.end():]
            if HISTORICAL_BEFORE_RE.search(before) or HISTORICAL_AFTER_RE.search(after):
                continue
            pronoun = bool(PRONOUN_PHRASE_RE.search(match.group(0)))
            patch = resolve_patch(sentence, match.start(), pronoun, anchor, known)
            if patch is None or patch not in pinned or patch in reported:
                continue
            reported.add(patch)
            problems.append(
                "%s:%d: says %s is not pinned (\"%s\"), but Package.swift's pinned-asset list "
                "includes it. A repin that pins a patch has to rewrite the prose that described "
                "the kernel before it; if the sentence is history, say so in its tense (#3056)."
                % (path, line, patch, match.group(0)))
    return problems


# Promotion rule, per okf/policies/static-gates.md: the check is a report until the tree it reads
# is clean, because a gate that is red on its first merge blocks every open PR. The false-positive
# count is already zero; what held it back was true findings in files this change did not own.
# Flip this when `--strict-pin-prose` exits 0 on main.
PIN_PROSE_IS_GATE = False


def prose_files():
    """Repo-relative paths of every text file whose prose can state a patch's pinned state."""
    found = []
    for root, dirs, files in os.walk(REPO):
        dirs[:] = [d for d in dirs if d not in PROSE_SKIP_DIRS]
        for name in files:
            if not name.endswith(PROSE_SUFFIXES):
                continue
            rel = os.path.relpath(os.path.join(root, name), REPO)
            if rel in PROSE_SKIP_FILES or rel.startswith(PROSE_SKIP_PREFIXES):
                continue
            found.append(rel)
    return sorted(found)


def check_stale_pin_prose():
    """No prose calls a patch not-yet-pinned when Package.swift's pinned-asset list holds it.

    #3056. The patch's real state is derived, from the enumeration `pinned_patch_numbers` reads.
    The check only judges a sentence it can resolve to one patch (see `prose_units`) and only in
    the direction the repin makes false; the same sentence about a patch the list does not hold is
    correct and passes. A repin that pins a patch must therefore also rewrite what said it was
    not pinned. Nothing else reads tense: `census-comment-staleness.py` reads names that no longer
    resolve, and these named patches that resolve perfectly.
    """
    pinned = set(pinned_patch_numbers())
    known = {"%04d" % patch_number(stem) for stem in numbered_patch_files()}
    problems = []
    for rel in prose_files():
        try:
            text = read(rel)
        except (UnicodeDecodeError, OSError):
            continue
        problems += stale_pin_claims(rel, text, pinned, known)
    return problems


def run(strict_pin_prose=False):
    stale = check_stale_pin_prose()  # read before the early return: it is a separate report
    problems = (check_claims() + check_patch_rows() + check_carried_sequence()
                + check_tsan_suppressions() + check_patch_naming() + check_wasi_patch_rows()
                + check_release_checks() + check_raise_map_provenance()
                + check_test_target_list())
    if problems:
        print("check-inventory-prose: %d problem(s)\n" % len(problems))
        for problem in problems:
            print("  " + problem)
        print("\nEach is a number in prose that no longer matches what the repo holds, or a row "
              "that names nothing. Fix the prose, or the inventory, whichever is wrong.")
        if stale:
            print("\nAlso, %d stale pinned-state sentence(s) (#3056, a report):" % len(stale))
            for problem in stale:
                print("  " + problem)
        return 1
    values = facts()
    if stale and (strict_pin_prose or PIN_PROSE_IS_GATE):
        print("check-inventory-prose: %d stale pinned-state sentence(s)\n" % len(stale))
        for problem in stale:
            print("  " + problem)
        return 1
    print("check-inventory-prose: clean")
    print("  patches: %d on disk, %d pinned" % (values["patches_on_disk"], values["patches_pinned"]))
    print("  patches-wasi: %d on disk, each with a README row" % values["wasi_patches_on_disk"])
    stamp = parse_provenance(read(RAISE_MAP))
    print("  raise map: derived against OCCT %s and %d carried patch(es), each matching on disk"
          % (stamp["version"], len(stamp["patches"])))
    print("  gate-scripts job: %d gates, %d censuses, %d merge-history audit, %d release check, "
          "%d scripts total"
          % (values["gate_scripts"], values["census_scripts"], values["audit_scripts"],
             values["release_check_scripts"], values["job_scripts"]))
    print("  bridge: %d enforced files, %d headers (umbrella + %d per-domain), "
          "%d Objective-C++ implementations"
          % (values["bridge_enforced_files"], values["bridge_include_headers"],
             values["bridge_domain_headers"], values["bridge_impl_files"]))
    print("  test targets: %d, each named in CLAUDE.md's Test Layout" % values["test_targets"])
    print("  %d claims checked across %d files"
          % (len(CLAIMS), len({c[0] for c in CLAIMS})))
    if stale:
        print("\nREPORT, not a gate yet (#3056): %d sentence(s) call a pinned patch not-yet-pinned"
              % len(stale))
        for problem in stale:
            print("  " + problem)
        print("  Pass --strict-pin-prose to exit 1 on these; PIN_PROSE_IS_GATE promotes it.")
    return 0


# --- self-test ---------------------------------------------------------------------------------


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))

    # 1. The real repo is clean, which is what the gate asserts in CI.
    problems = (check_claims() + check_patch_rows() + check_carried_sequence()
                + check_tsan_suppressions() + check_patch_naming() + check_wasi_patch_rows()
                + check_release_checks() + check_raise_map_provenance()
                + check_test_target_list())
    case("live-tree-clean", not problems, "; ".join(problems[:2]))

    # 2. A stated count that disagrees with the derived one is caught.
    values = facts()
    bumped = dict(values)
    bumped["patches_on_disk"] += 1
    case("count-mismatch-detected", any("patches_on_disk" in p for p in check_claims(bumped)))

    # 3. A claim whose sentence was reworded away is caught rather than silently skipped.
    saved = list(CLAIMS)
    try:
        CLAIMS.append(("CLAUDE.md", r"this sentence is not in CLAUDE\.md at all \((\d+)\)",
                       "patches_on_disk"))
        case("vanished-claim-detected",
             any("no sentence matches" in p for p in check_claims()))
    finally:
        CLAIMS[:] = saved

    # 4. Number words and digits both read, and a non-number is reported rather than crashing.
    case("number-words-read", to_int("seventeen") == 17 and to_int("22") == 22
         and to_int("TWENTY-TWO") == 22 and to_int("umpteen") is None)

    # 5. The ci.yml parser stops at the next job rather than counting the whole file.
    sample = (
        "jobs:\n"
        "  gate-scripts:\n"
        "    steps:\n"
        "      - run: python3 Scripts/check-a.py --self-test\n"
        "      - run: python3 Scripts/check-a.py\n"
        "      - run: python3 Scripts/census-b.py --self-test\n"
        "  build-and-test:\n"
        "    steps:\n"
        "      - run: python3 Scripts/check-elsewhere.py\n")
    bare, selftest = gate_job_scripts(sample)
    case("job-parser-bounded",
         bare == {"check-a.py"} and selftest == {"check-a.py", "census-b.py"},
         "bare=%s selftest=%s" % (sorted(bare), sorted(selftest)))

    # 5b. #2058: the invocation counters. gate_job_invocations counts steps rather than scripts, and
    #     the hook parser reads only its own `run "label" Scripts/x.py` lines.
    case("job-invocation-counter-bounded", gate_job_invocations(sample) == 3,
         str(gate_job_invocations(sample)))
    hook_sample = (
        '# run "check-commented-out.py"        Scripts/check-commented-out.py\n'
        'run "check-a.py --self-test"          Scripts/check-a.py --self-test\n'
        'run "check-a.py"                      Scripts/check-a.py\n'
        'if git grep -nE \'marker\' -- . ; then\n'
        '    failed+=("conflict-markers")\n'
        'fi\n')
    case("hook-invocation-counter-bounded", hook_invocations(hook_sample) == 2,
         str(hook_invocations(hook_sample)))

    # 5c. #2196: the fourth bucket. A script the job runs ONLY as --self-test and that is not a
    #     census is a release check. Before this it landed in no bucket at all, so the sentence
    #     "N gates, M censuses and one merge-history audit" would have described one script fewer
    #     than the job runs with every claim passing, which is the exact shape #1408 exists to end.
    fourth = (
        "jobs:\n"
        "  gate-scripts:\n"
        "    steps:\n"
        "      - run: python3 Scripts/check-a.py --self-test\n"
        "      - run: python3 Scripts/check-a.py\n"
        "      - run: python3 Scripts/census-b.py --self-test\n"
        "      - run: python3 Scripts/check-changelog-transcription.py --self-test\n"
        "      - run: python3 Scripts/check-changelog-transcription.py\n"
        "      - run: python3 Scripts/check-c.py --self-test\n")
    split = classify(fourth)
    case("release-check-bucketed-apart-from-gate-census-and-audit",
         split["releases"] == {"check-c.py"} and split["gates"] == {"check-a.py"}
         and split["censuses"] == {"census-b.py"}
         and split["audits"] == {"check-changelog-transcription.py"},
         str({k: sorted(v) for k, v in split.items() if k != "selftest"}))
    # Against the REAL job, not the fixture: a script the live job runs that falls into none of the
    # four buckets is precisely what went unnoticed, and a fixture cannot see it.
    live = classify()
    case("four-buckets-partition-the-live-job",
         len(live["gates"]) + len(live["censuses"]) + len(live["audits"]) + len(live["releases"])
         == len(live["all"]),
         "%d+%d+%d+%d vs %d" % (len(live["gates"]), len(live["censuses"]), len(live["audits"]),
                                len(live["releases"]), len(live["all"])))

    # 5d. The bucket is derived from the job's shape, so a gate whose bare invocation nobody added
    #     lands in it too and would be counted, and described in prose, as a release check. The
    #     `--require-...` flag #2098 already asks such a script for is what tells the two apart.
    case("require-flag-reader-reads-the-flag",
         script_declares_require_flag("x", "parser.add_argument('--require-asset', action='store_true')")
         and not script_declares_require_flag("x", 'parser.add_argument("--self-test")'))
    saved_flag = globals()["script_declares_require_flag"]
    try:
        globals()["script_declares_require_flag"] = lambda name, text=None: False
        case("release-check-without-a-require-flag-detected",
             any("defines no `--require-...` flag" in problem
                 for problem in check_release_checks()))
    finally:
        globals()["script_declares_require_flag"] = saved_flag

    values_release = dict(values)
    values_release["release_check_scripts"] += 1
    case("release-check-count-mismatch-detected",
         any("release_check_scripts" in problem for problem in check_claims(values_release)))

    # 6. The pinned-list parser reads the enumerated numbers, not every four-digit run in the file.
    pkg = ("// survive, all present in Scripts/patches/, are:\n"
           "//\n"
           "//   0010  something                     #319\n"
           "//   0011  something else                #341\n"
           "//\n"
           "// 0099 is prose after the list and must not count\n")
    case("pinned-list-parser-bounded", pinned_patch_numbers(pkg) == ["0010", "0011"],
         str(pinned_patch_numbers(pkg)))

    # 7. An abbreviated row key is caught. Proven against the shape that actually shipped: the
    #    0010 row was written with an ellipsis and named no file for six weeks (#1066).
    real = read("okf/references/carried-occt-patches.md")
    stems = patch_files()
    fake = "\n| `%s…-319` | x | y | z |\n" % stems[0][:20]
    saved_read = globals()["read"]
    try:
        globals()["read"] = lambda rel: (real + fake) if "carried-occt-patches" in rel else saved_read(rel)
        case("abbreviated-row-key-detected",
             any("names no file" in p for p in check_patch_rows()))
    finally:
        globals()["read"] = saved_read

    # 8. #1403: the carried-sequence range expander. This is prose encoding a SET rather than a
    #    count, so no CLAIMS entry can cover it, and it had gone stale three times (0032's
    #    retirement, 0033, 0034) before this check existed.
    case("carried-sequence-expands-ranges",
         carried_sequence_numbers("the carried sequence now reads 0010\u20130012, 0014, 0033.")
         == {10, 11, 12, 14, 33})
    case("carried-sequence-accepts-ascii-hyphen",
         carried_sequence_numbers("the carried sequence now reads 0010-0012.") == {10, 11, 12})
    case("carried-sequence-rejects-garbage",
         carried_sequence_numbers("the carried sequence now reads 0010 to 0012.") is None)
    case("carried-sequence-missing-sentence-detected",
         carried_sequence_numbers("no such sentence here") is None)
    # Both of these failed before the phrase regex tolerated them, on a real retirement edit:
    # the sentence gets reflowed every time a patch is retired into it.
    case("carried-sequence-accepts-sentence-initial-capital",
         carried_sequence_numbers("The carried sequence now reads 0010\u20130012.") == {10, 11, 12})
    case("carried-sequence-accepts-a-wrap-inside-the-phrase",
         carried_sequence_numbers("so the carried\nsequence now reads 0010\u20130012.")
         == {10, 11, 12})

    # 9. #1409: a tsan.supp suppression must cite an unpinned patch that is still on disk. Exactly
    #    one cites a patch today (0030), so these exercise the parser and both failure directions
    #    against literal text rather than against the tree, which would only test today's state.
    case("tsan-supp-extracts-a-cited-patch",
         tsan_suppression_patches("# making myState atomic (Scripts/patches/0030-*). Remove once")
         == {30})
    case("tsan-supp-extracts-several",
         tsan_suppression_patches("Scripts/patches/0030-a and Scripts/patches/0031-b") == {30, 31})
    case("tsan-supp-ignores-prose-without-a-patch-path",
         tsan_suppression_patches("# see patch 0030 and issue #1154") == set())
    case("tsan-supp-no-citation-is-not-a-problem",
         tsan_suppression_patches("race:SomeClass::Method\n# no patch cited here") == set())
    # This one exists because the first version of check_tsan_suppressions() could NOT fire:
    # pinned_patch_numbers() returns STRINGS, so comparing it against a set of ints never matched
    # and the check reported clean on a deliberately-broken tree. Caught by injection, not by
    # review. The case pins the type so it cannot regress.
    case("tsan-supp-pinned-numbers-compare-as-ints",
         {int(n) for n in pinned_patch_numbers()} & {21} == {21})

    # 10. #2148: a .patch in Scripts/patches/ that is not NNNN-named. Monkeypatched rather than
    #     written into the real directory, because the behaviour under test is what the glob
    #     returns, and a real file would make three cases depend on cleanup having run.
    real_patch_files = globals()["patch_files"]
    try:
        globals()["patch_files"] = lambda: sorted(real_patch_files() + ["wasi-osd-environment"])
        case("odd-patch-name-reported",
             any("wasi-osd-environment" in problem and "patches-wasi" in problem
                 for problem in check_patch_naming()))
        # The crash this replaces. Both readers take the number off every stem, and before #2148
        # they raised ValueError("invalid literal for int() with base 10: 'wasi'"), which took the
        # other twenty-one claims down with them and was reported as the gate being broken.
        crashed = None
        try:
            check_carried_sequence()
            check_tsan_suppressions()
        except ValueError as exc:
            crashed = str(exc)
        case("odd-patch-name-does-not-crash-the-number-readers", crashed is None, crashed or "")
        case("odd-patch-name-excluded-from-the-counted-facts",
             len(numbered_patch_files()) == len(real_patch_files()))
    finally:
        globals()["patch_files"] = real_patch_files

    # 11. #2166: the WASI sequence. Monkeypatched for the same reason case 10 is, so no case
    #     depends on a real file having been cleaned up afterwards.
    real_wasi = globals()["wasi_patch_files"]
    saved_read_11 = globals()["read"]
    try:
        # The fabricated stem must be one no real patch can carry. It was `wasi-osd-signal`
        # until #2173 shipped a patch of exactly that name, whereupon the README row it added
        # satisfied the check and this case reported PASS for the wrong reason, then FAIL. The
        # sibling case below already used a `-not-on-disk` name for the same reason.
        globals()["wasi_patch_files"] = lambda: sorted(real_wasi() + ["wasi-selftest-no-row"])
        case("wasi-patch-without-a-row-detected",
             any("wasi-selftest-no-row.patch has no row" in problem
                 for problem in check_wasi_patch_rows()))
    finally:
        globals()["wasi_patch_files"] = real_wasi

    real_readme = read("Scripts/patches-wasi/README.md")
    try:
        globals()["read"] = lambda rel: (
            real_readme + "\n| `wasi-not-on-disk.patch` | a row for nothing |\n"
            if "patches-wasi/README" in rel else saved_read_11(rel))
        case("wasi-row-naming-no-file-detected",
             any("names no file" in problem for problem in check_wasi_patch_rows()))
    finally:
        globals()["read"] = saved_read_11

    values_wasi = dict(facts())
    values_wasi["wasi_patches_on_disk"] += 1
    case("wasi-count-mismatch-detected",
         any("wasi_patches_on_disk" in problem for problem in check_claims(values_wasi)))

    # The view check, not the verdict: a mistyped glob would report clean forever. These assert
    # the two sequences are read from different directories and neither comes back empty.
    case("wasi-and-carried-sequences-are-distinct-populations",
         bool(wasi_patch_files()) and bool(patch_files())
         and not (set(wasi_patch_files()) & set(patch_files())),
         "wasi=%d carried=%d" % (len(wasi_patch_files()), len(patch_files())))

    # 12. #2885: the raise map's provenance stamp. Every case here monkeypatches `read`, because
    #     the subject is a 5,000-line committed derivation and a case that rewrote it on disk
    #     would leave the tree broken if it failed part-way.
    real_map = read(RAISE_MAP)
    saved_read_12 = globals()["read"]

    def with_map(text):
        return lambda rel: text if rel == RAISE_MAP else saved_read_12(rel)

    try:
        # The round trip first: what format_provenance writes, parse_provenance reads back. This
        # is the pair that a reworded stamp silently breaks, and the two live in this file
        # together precisely so that a change to one fails here rather than in six months.
        written = "\n".join(format_provenance("8.0.1", {"0010-a": "abc123abc123",
                                                        "0042-b": "def456def456"}))
        back = parse_provenance(written)
        case("provenance-round-trips",
             back == {"version": "8.0.1",
                      "patches": {"0010-a": "abc123abc123", "0042-b": "def456def456"}},
             str(back))

        # The 0042 case verbatim: a patch on disk that the stamp does not name. Built by deleting
        # a line from the real stamp rather than by adding a file, so the case exercises the real
        # map's format and leaves Scripts/patches/ alone.
        one_stem = sorted(carried_patch_digests())[-1]
        globals()["read"] = with_map(
            "\n".join(line for line in real_map.split("\n")
                      if not line.startswith("# patch: " + one_stem)))
        case("map-missing-a-carried-patch-detected",
             any(one_stem in p and "is on disk and not in" in p
                 for p in check_raise_map_provenance()),
             "; ".join(check_raise_map_provenance()[:1]))

        # A patch revised in place. No count moves, which is the whole reason the stamp records a
        # digest rather than only the count line the CLAIMS table reads.
        globals()["read"] = with_map(
            re.sub(r"^(# patch: %s )[0-9a-f]+$" % re.escape(one_stem), r"\g<1>000000000000",
                   real_map, count=1, flags=re.MULTILINE))
        case("map-patch-changed-in-place-detected",
             any("has changed since" in p and one_stem in p
                 for p in check_raise_map_provenance()))

        # A retired patch the map still describes.
        globals()["read"] = with_map(
            real_map.replace("# occt-version:",
                             "# patch: 0099-retired-but-still-in-the-stamp aaaaaaaaaaaa\n"
                             "# occt-version:", 1))
        case("map-naming-a-retired-patch-detected",
             any("0099-retired-but-still-in-the-stamp" in p
                 for p in check_raise_map_provenance()))

        # An OCCT version bump. The map's own header has named this trigger since it was written
        # and nothing read it, which is half of #2885.
        globals()["read"] = with_map(
            re.sub(r"^# occt-version: .*$", "# occt-version: 7.9.0", real_map, count=1,
                   flags=re.MULTILINE))
        case("map-derived-against-another-occt-version-detected",
             any("Scripts/build-occt.sh builds" in p for p in check_raise_map_provenance()))

        # A map written before the stamp existed, which is every copy of it until #2885.
        globals()["read"] = with_map(
            "\n".join(line for line in real_map.split("\n")
                      if not line.startswith(("# patch: ", "# occt-version: "))))
        case("map-with-no-stamp-at-all-detected",
             any("carries no provenance stamp" in p for p in check_raise_map_provenance()))

        # The detector going blind, which is a different report from the tree being dirty: the
        # stamp is there and the patch lines have stopped parsing.
        globals()["read"] = with_map(
            re.sub(r"^# patch: ", "# patch = ", real_map, flags=re.MULTILINE))
        case("map-stamp-that-parses-to-no-patch-is-a-blindness-report",
             any("going blind" in p for p in check_raise_map_provenance()))

        # ...and the same stamp is CLEAN when the tree really carries no patch, which is the
        # difference between "the parser stopped matching" and "there is nothing to name". Found
        # in review of #2893: the blind report ran before the on-disk set was read, so a full
        # retirement would have been reported as this check failing.
        saved_digests = globals()["carried_patch_digests"]
        globals()["carried_patch_digests"] = lambda: {}
        try:
            case("stamp-naming-no-patch-is-clean-when-no-patch-is-on-disk",
                 not any("going blind" in p for p in check_raise_map_provenance()),
                 "; ".join(check_raise_map_provenance()[:1]))
        finally:
            globals()["carried_patch_digests"] = saved_digests

        # A development tree states OCC_VERSION_DEVELOPMENT and tree_occt_version appends it, so
        # the stamp can read "8.0.1.dev" against build-occt.sh's bare "8.0.1". Comparing the
        # triple is what the docstring always claimed; string equality is what it did (#2893).
        globals()["read"] = with_map(
            re.sub(r"^# occt-version: .*$", "# occt-version: 8.0.1.dev", real_map, count=1,
                   flags=re.MULTILINE))
        case("a-development-suffix-on-the-stamp-is-not-a-version-bump",
             not any("Scripts/build-occt.sh builds" in p
                     for p in check_raise_map_provenance()),
             "; ".join(check_raise_map_provenance()[:1]))
    finally:
        globals()["read"] = saved_read_12

    case("version-triple-strips-a-development-suffix-and-leaves-a-bare-triple",
         version_triple("8.0.1.dev") == "8.0.1" and version_triple("8.0.1") == "8.0.1"
         and version_triple("8.0.2.beta") == "8.0.2" and version_triple(None) is None
         and version_triple("not-a-version") == "not-a-version")

    case("build-script-version-read",
         build_script_occt_version('OCCT_VERSION="8.0.1"\nOCCT_RC=""\n') == "8.0.1"
         and build_script_occt_version("# OCCT_VERSION is set below\n") is None)

    # The view check, not the verdict. A digest function reading the wrong directory, or a stamp
    # parser matching a comment somewhere else, would report clean forever.
    live_stamp = parse_provenance(read(RAISE_MAP))
    case("raise-map-stamp-is-read-from-the-real-map",
         live_stamp is not None and len(live_stamp["patches"]) == len(carried_patch_digests())
         and len(live_stamp["patches"]) > 10,
         "stamped=%d on-disk=%d" % (len(live_stamp["patches"]) if live_stamp else -1,
                                    len(carried_patch_digests())))

    case("patch-number-reads-nnnn-and-rejects-the-rest",
         patch_number("0010-Intf-319") == 10 and patch_number("wasi-osd-environment") is None
         and patch_number("001-too-short") is None)

    # 13. #2910: the bridge-tree readers and the test-target list.

    for fact in ("bridge_enforced_files", "bridge_domain_headers", "bridge_include_headers",
                 "bridge_impl_files"):
        bumped_bridge = dict(values)
        bumped_bridge[fact] += 1
        case("%s-mismatch-detected" % fact.replace("_", "-"),
             any(fact in problem for problem in check_claims(bumped_bridge)))

    # 14. #2954. The counts that moved out of CLAUDE.md still fail when they go stale in the page
    #     they moved to, and the report names that page. A move that left a claim reading a
    #     sentence nobody writes any more would pass this file's own live-tree case and protect
    #     nothing, which is the failure mode "no sentence matches" exists for; these pin the pairing
    #     of fact to destination, which no other case does.
    for fact, destination in (("patches_pinned", "okf/references/carried-occt-patches.md"),
                              ("gate_scripts", "okf/policies/static-gates.md"),
                              ("census_scripts", "okf/policies/static-gates.md"),
                              ("audit_scripts", "okf/policies/static-gates.md"),
                              ("release_check_scripts", "okf/policies/static-gates.md"),
                              ("bridge_enforced_files", "okf/policies/code-style.md")):
        moved = dict(values)
        moved[fact] += 1
        reports = [p for p in check_claims(moved) if fact in p]
        case("%s-mismatch-reported-against-%s" % (fact.replace("_", "-"),
                                                  os.path.basename(destination)),
             any(p.startswith(destination) for p in reports),
             "; ".join(reports[:1]))

    #     And CLAUDE.md states no count at all any more, which is the whole of #2954. Written as a
    #     case rather than left to a reviewer, because the next counted sentence added to that file
    #     will be added by somebody who did not read the issue.
    case("claude-md-registers-no-counted-claim",
         not any(rel == "CLAUDE.md" for rel, _pattern, _fact in CLAIMS),
         ", ".join(fact for rel, _p, fact in CLAIMS if rel == "CLAUDE.md"))

    #     The bridge walk reaches both directories, which is what the stale prose got wrong: the
    #     implementations live in src/ and the declarations in include/, and a walk that found one
    #     and not the other would still produce two plausible numbers.
    case("bridge-walk-reaches-src-and-include",
         values["bridge_impl_files"] > 1 and values["bridge_domain_headers"] > 1
         and values["bridge_enforced_files"]
         >= values["bridge_impl_files"] + values["bridge_include_headers"],
         "impl=%d headers=%d enforced=%d" % (values["bridge_impl_files"],
                                             values["bridge_include_headers"],
                                             values["bridge_enforced_files"]))

    #     The test-target list, which is an inventory rather than a count and so cannot live in
    #     CLAIMS. Both directions: a target Package.swift declares and the list omits, and a name
    #     the list carries that no target answers to.
    listed_claude = ("Each is `Tests/OCCT<Domain>Tests/`, declared in `Package.swift`:\n\n"
                     "`Analysis`, `Curve`, `Ghost`.\n")
    two_targets = ('.testTarget(\n    name: "OCCTAnalysisTests"),\n'
                   '.testTarget(\n    name: "OCCTCurveTests"),\n'
                   '.testTarget(\n    name: "OCCTMeshTests"),\n')
    drift = check_test_target_list(listed_claude, two_targets)
    case("test-target-omitted-from-the-list-detected",
         any("omits `Mesh`" in problem for problem in drift), "; ".join(drift))
    case("test-target-named-with-no-target-detected",
         any("names `Ghost`" in problem for problem in drift), "; ".join(drift))
    case("test-target-list-reworded-away-detected",
         any("no longer matches the sentence" in problem
             for problem in check_test_target_list("nothing here", two_targets)))
    case("test-target-list-clean-on-the-live-tree", not check_test_target_list(),
         "; ".join(check_test_target_list()[:2]))

    # 15. #3056: prose that states a patch's pinned state. Fixtures are fed to
    #     `stale_pin_claims` directly, with an explicit pinned set, so no case reads or edits a real
    #     file. `known` carries a synthetic 0056, an unpinned patch no real file mentions yet.
    pins = {"0044", "0045", "0048"}
    known_pins = pins | {"0043", "0056"}

    def stale(text, pinned=pins):
        return stale_pin_claims("fixture.md", text, pinned, known_pins)

    case("stale-not-pinned-about-a-pinned-patch-flagged",
         len(stale("Carried, not pinned: `0044` leaves nothing exposed.\n")) == 1,
         "; ".join(stale("Carried, not pinned: `0044` leaves nothing exposed.\n")))
    case("same-sentence-about-an-unpinned-patch-is-not-flagged",
         not stale("Carried, not pinned: `0056` leaves nothing exposed.\n"))
    # The synthetic 0056 in the two anchored shapes the real tree uses, so the check needs no
    # edit when #3111 lands its real rows: a Package.swift enumeration row and a README section.
    case("unpinned-patch-row-and-section-are-not-flagged",
         not stale("//   0056  BRepLib::Plane creates its plane under the lock          #3039\n"
                   "//         Carried 2026-10-07 and NOT built. DO NOT RETIRE THE GUARD WHEN\n"
                   "//         THIS IS PINNED.\n")
         and not stale("## 0056-BRepLib-Plane-lock-3039.patch\n\n"
                       "**Carried, not pinned.** The bridge guard stays when this is pinned.\n"))
    case("same-row-about-a-pinned-patch-is-flagged-by-its-anchor",
         len(stale("//   0044  Extrema_ExtSS::Points bound against the point sequence   #2840\n"
                   "//         Carried 2026-09-30 and NOT built, deliberately.\n")) == 1)
    case("historical-sentences-are-not-flagged",
         not stale("`0044` was not pinned until v4.0.0-kernel.4.\n")
         and not stale("| `0044-Extrema` | Was unpinned until v4.0.0-kernel.4 |\n")
         and not stale("`0045` was NOT built for two days, then pinned.\n"))
    case("a-sentence-naming-no-patch-is-ignored",
         not stale("A bucket that is not pinned would absorb that silently.\n"
                   "Visionos slices are NOT built by default.\n"))
    case("two-patches-and-no-anchor-resolve-to-nothing",
         not stale("`0044` and `0045` are not pinned.\n"))
    case("a-patch-named-for-comparison-is-not-the-subject",
         not stale("## 0056-x.patch\n\n**Carried, not pinned**, and unlike `0044` this one "
                   "leaves something exposed.\n"))
    case("a-pronoun-phrase-reads-the-nearest-preceding-patch",
         len(stale("Both are fixed by carried patch `0048`; the guards stay when it is pinned, "
                   "the `0056` exception.\n")) == 1
         and not stale("Both are fixed by carried patch `0056`; the guards stay when it is "
                       "pinned, the `0044` exception.\n"))
    case("a-deeper-heading-keeps-the-patch-section-and-a-new-section-drops-it",
         len(stale("## 0044-x.patch\n\n### CI coverage\n\nCarried, not pinned.\n")) == 1
         and not stale("## 0044-x.patch\n\n## Something else\n\nCarried, not pinned.\n"))
    case("a-table-row-is-read-cell-by-cell",
         len(stale("| #2840 | the defect, see `0045` | patch `0044`, **not pinned**; not yet filed |\n"))
         == 1
         and not stale("| #9 | the defect | patch `0044` is carried; `0056` **not pinned** |\n"))
    case("an-exempt-sentence-is-skipped",
         not stale("`0044` is not pinned. pin-state-exempt: quoted from the old release notes\n"))

    # The pre-#3054 text, verbatim from `git show 3054^:<file>`, against the post-#3031 pin
    # state (0044 to 0051 pinned). Each of these was a current-tense claim for ten days after
    # it stopped being true.
    replay = [
        ("Package.swift, 0044 row",
         "//   0044  Extrema_ExtSS::Points / Extrema_ExtCS::Points bound against the point       #2840\n"
         "//         sequence rather than against NbExt(), which counts mySqDist and so counts\n"
         "//         the parallel branch's distance-with-no-point. Carried 2026-09-30 and NOT\n"
         "//         built, deliberately: the 8.0.2 repin (due 2026-10-02, and already owed a\n"),
        ("Package.swift, 0048 row",
         "//   0048  The by-plane BRepGProp_Vinert overloads measure about the plane      #2873\n"
         "//         out instead of re-basing. Carried 2026-10-02 for the OCCT 8.0.2 rebuild.\n"
         "//         THIS ONE IS THE OPPOSITE CASE AND THE REPIN MUST ACT ON IT.\n"),
        ("CLAUDE.md, by-plane mirror",
         "  offset. The kernel hunk is now carried as `0048`, which negates the stored offset at all five\n"
         "  by-plane sites; **that mirror is a compensation and not a guard, so the repin that pins `0048`\n"
         "  deletes it in the same change**, or the sign flips back.\n"),
        ("known-occt-bugs.md, #2873 row",
         "| #2873 | the conversion | **carried patch `0048`, and the bridge fix #2873 until it is "
         "pinned.** `OCCTBRepGPropVinertPlane` builds the mirrored plane | `Scripts/repro/2873/` |\n"),
        ("carried-occt-patches.md, 0044 row",
         "| `0044-Extrema-ExtSS-ExtCS-Points-bound-against-point-sequence-2840` | Nothing reachable "
         "from Swift. `Extrema_ExtSS::Points` and `Extrema_ExtCS::Points` still fault on a parallel "
         "pair in the pinned kernel, and every bridge entry point reads a point |\n"),
        ("Scripts/patches/README.md, 0048 heading",
         "### The bridge side is a COMPENSATION, not a guard, and the repin must delete it\n"),
    ]
    for label, text in replay:
        # The README heading names no patch, so it needs the section the real file puts it under.
        wrapped = "## 0048-BRepGProp-by-plane-offset-sign-2873.patch\n\n" + text if "README" in label else text
        found = stale_pin_claims(label, wrapped, {"0044", "0045", "0046", "0047", "0048", "0050",
                                                  "0051"},
                                 {"0043", "0044", "0045", "0046", "0047", "0048", "0050", "0051"})
        case("pre-3054-replay-flagged: " + label, len(found) >= 1, "; ".join(found[:1])[:80])

    # The view checks, not the verdict: a prose reader that stopped finding rows or files would
    # report clean forever, which is the failure `no sentence matches` exists for.
    reachable = set(prose_files())
    case("prose-files-reach-the-places-the-stale-text-lived",
         {"Package.swift", "CLAUDE.md", "Scripts/patches/README.md",
          "okf/references/known-occt-bugs.md", "docs/reference/Shape-HLR-Geom.md"} <= reachable
         and not any(name.endswith(".patch") or name.startswith("Libraries/")
                     for name in reachable),
         "%d files" % len(reachable))
    anchors = [a for _l, _s, a in prose_units(read("Package.swift")) if a]
    case("package-swift-rows-resolve-to-anchors", len(set(anchors)) > 30,
         "%d distinct anchors" % len(set(anchors)))

    # Review of #3112. The line a finding names is the line of its own sentence, not the block's
    # first; every patch a sentence makes a claim about is reported, not just the first phrase's;
    # and the report is printed even when another inventory check fails the run.
    wrapped = "\n".join(["//   0048  BRepX does a thing", "//         and carries filler text.",
                          "//         More filler here.", "//         Not pinned yet, wait."])
    wrapped_hits = stale(wrapped)
    case("finding-names-its-own-sentence-line", len(wrapped_hits) == 1
         and wrapped_hits[0].startswith("fixture.md:4:"), "; ".join(wrapped_hits)[:60])
    two_clauses = stale("`0044` waits, when it is pinned we flip; `0048` waits, when it is pinned "
                        "we flip.")
    case("two-patches-in-one-sentence-both-reported",
         sorted(re.findall(r"says (\d{4})", " ".join(two_clauses))) == ["0044", "0048"],
         "; ".join(two_clauses)[:80])
    case("same-patch-twice-in-one-sentence-reported-once",
         len(stale("`0044` is not pinned and stays out until it is pinned.")) == 1)
    import contextlib
    import io
    real_scan, real_claims = globals()["check_stale_pin_prose"], globals()["check_claims"]
    try:
        globals()["check_stale_pin_prose"] = lambda: ["fixture stale finding"]
        globals()["check_claims"] = lambda values=None: ["fixture other problem"]
        sink = io.StringIO()
        with contextlib.redirect_stdout(sink):
            other_code = run(False)
    finally:
        globals()["check_stale_pin_prose"], globals()["check_claims"] = real_scan, real_claims
    case("stale-report-printed-when-another-check-fails",
         other_code == 1 and "fixture stale finding" in sink.getvalue(), sink.getvalue()[-60:])

    # The report stays a report until PIN_PROSE_IS_GATE flips: findings alone do not fail a bare
    # run, and --strict-pin-prose does fail it. The scan is stubbed so the case is deterministic
    # and the tree is read once, and run() is captured since it prints the whole summary.
    real_scan = globals()["check_stale_pin_prose"]
    try:
        codes = {}
        for label, findings in (("findings", ["fixture finding"]), ("clean", [])):
            globals()["check_stale_pin_prose"] = lambda found=findings: found
            with contextlib.redirect_stdout(io.StringIO()):
                codes[label] = (run(False), run(True))
    finally:
        globals()["check_stale_pin_prose"] = real_scan
    case("report-mode-passes-bare-and-fails-strict",
         codes["findings"] == ((1 if PIN_PROSE_IS_GATE else 0), 1) and codes["clean"] == (0, 0),
         str(codes))

    failed = [c for c in cases if not c[1]]
    for name, ok, detail in cases:
        print("[%s] %s%s" % ("PASS" if ok else "FAIL", name, (" -- " + detail) if detail else ""))
    print("\n%d/%d self-test cases pass" % (len(cases) - len(failed), len(cases)))
    return 1 if failed else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--self-test", action="store_true",
                        help="run the detector's own fixtures instead of the repo")
    parser.add_argument("--strict-pin-prose", action="store_true",
                        help="exit 1 when prose calls a pinned patch not-yet-pinned (#3056)")
    args = parser.parse_args()
    sys.exit(self_test() if args.self_test else run(args.strict_pin_prose))
