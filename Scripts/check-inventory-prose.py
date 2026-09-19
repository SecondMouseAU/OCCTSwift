#!/usr/bin/env python3
"""Gate: every counted claim this repo makes about its own inventories must match the inventory.

Two inventories keep drifting from the prose that describes them, and each drift has shipped more
than once:

  * the carried OCCT patches in ``Scripts/patches/``, counted in ``Package.swift``'s pin comment,
    in ``CLAUDE.md`` and in ``okf/references/carried-occt-patches.md``, and
  * the static gate scripts run by ``ci.yml``'s ``gate-scripts`` job, counted in that job's own
    comment, in ``CLAUDE.md`` and in ``okf/policies/static-gates.md``.

The recurrence is the argument for a gate rather than another proofread: ci.yml called the job's
scripts "five" while running thirteen (#1066), the pinned-patch count went stale at
v2.0.0-kernel.1 through .3, at #1032 and at #1157/#1402, and one carried-patch row key was written
with an ellipsis so it named no file on disk. Filed as #1408, which asked for exactly this.

How it works. Every claim is registered below in CLAIMS as a (file, regex, fact) triple. The regex
must capture the number, written as digits or as an English number word, and the fact names a value
this script DERIVES from the repo. A claim fails if the number disagrees with the derived value, and
it also fails if the regex matches nothing at all, since a reworded sentence that no longer matches
is a claim nobody is checking any more, which is the state this gate exists to end.

Run from anywhere; paths resolve from __file__.
"""

import argparse
import glob
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WORDS = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
    "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14,
    "fifteen": 15, "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
    "twenty-one": 21, "twenty-two": 22, "twenty-three": 23, "twenty-four": 24, "twenty-five": 25,
    "twenty-six": 26, "twenty-seven": 27, "twenty-eight": 28, "twenty-nine": 29, "thirty": 30,
    "thirty-one": 31, "thirty-two": 32, "thirty-three": 33, "thirty-four": 34, "thirty-five": 35,
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


def classify():
    """The gate/census/audit split, derived from the job rather than from a hand-kept list."""
    bare, selftest = gate_job_scripts()
    everything = bare | selftest
    censuses = {n for n in everything if n.startswith("census-")}
    audits = {n for n in everything if n == "check-changelog-transcription.py"}
    gates = {n for n in bare if n not in censuses and n not in audits}
    return {
        "gates": gates,
        "censuses": censuses,
        "audits": audits,
        "all": everything,
        "selftest": selftest,
    }


def facts():
    split = classify()
    gates_with_selftest = split["gates"] & split["selftest"]
    return {
        "patches_on_disk": len(patch_files()),
        "patches_pinned": len(pinned_patch_numbers()),
        "gate_scripts": len(split["gates"]),
        "census_scripts": len(split["censuses"]),
        "audit_scripts": len(split["audits"]),
        "job_scripts": len(split["all"]),
        "job_scripts_minus_one": len(split["all"]) - 1,
        "gates_with_selftest": len(gates_with_selftest),
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
    ("Package.swift", r"`ls Scripts/patches/\*\.patch \| wc -l` answers (\d+)", "patches_on_disk"),
    ("CLAUDE.md", r"\((\S+) on disk, \S+ pinned", "patches_on_disk"),
    ("CLAUDE.md", r"\(\S+ on disk, (\S+) pinned", "patches_pinned"),
    ("CLAUDE.md", r"(\S+) gates, \S+ censuses and \S+ merge-history audit", "gate_scripts"),
    ("CLAUDE.md", r"\S+ gates, (\S+) censuses and \S+ merge-history audit", "census_scripts"),
    ("CLAUDE.md", r"\S+ gates, \S+ censuses and (\S+) merge-history audit", "audit_scripts"),
    (".github/workflows/ci.yml", r"because all (\S+) are pure Python", "job_scripts"),
    (".github/workflows/ci.yml", r"does not hide the\s*#\s*other (\S+)\.", "job_scripts_minus_one"),
    ("okf/policies/static-gates.md", r"(\S+) of the \S+ gates, all \S+ censuses", "gates_with_selftest"),
    ("okf/policies/static-gates.md", r"\S+ of the (\S+) gates, all \S+ censuses", "gate_scripts"),
    ("okf/policies/static-gates.md", r"\S+ of the \S+ gates, all (\S+) censuses", "census_scripts"),
    ("okf/policies/static-gates.md", r"The (\S+) censuses today", "census_scripts"),
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


def run():
    problems = check_claims() + check_patch_rows()
    if problems:
        print("check-inventory-prose: %d problem(s)\n" % len(problems))
        for problem in problems:
            print("  " + problem)
        print("\nEach is a number in prose that no longer matches what the repo holds, or a row "
              "that names nothing. Fix the prose, or the inventory, whichever is wrong.")
        return 1
    values = facts()
    print("check-inventory-prose: clean")
    print("  patches: %d on disk, %d pinned" % (values["patches_on_disk"], values["patches_pinned"]))
    print("  gate-scripts job: %d gates, %d censuses, %d merge-history audit, %d scripts total"
          % (values["gate_scripts"], values["census_scripts"], values["audit_scripts"],
             values["job_scripts"]))
    print("  %d claims checked across %d files"
          % (len(CLAIMS), len({c[0] for c in CLAIMS})))
    return 0


# --- self-test ---------------------------------------------------------------------------------


def self_test():
    cases = []

    def case(name, ok, detail=""):
        cases.append((name, ok, detail))

    # 1. The real repo is clean, which is what the gate asserts in CI.
    problems = check_claims() + check_patch_rows()
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
    args = parser.parse_args()
    sys.exit(self_test() if args.self_test else run())
