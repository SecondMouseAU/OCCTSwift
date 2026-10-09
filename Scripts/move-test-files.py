#!/usr/bin/env python3
"""Move a test target's files into area subdirectories, and rewrite every path that names them (#3148).

Reads a mapping table (`Scripts/test-areas/<target>.tsv`: current path, proposed path, area, pending
PRs, reason) and, with `--apply`, does three things in one pass:

  1. `git mv` each file whose proposed path differs from its current one;
  2. rewrites the entries of `wasmExcludedTestFiles` in Package.swift for the moved files. SwiftPM
     resolves an `exclude:` path relative to the TARGET's directory, so a bare `Foo.swift` stops
     excluding the file the moment it sits in `Area/Foo.swift`, and the exclude silently does nothing
     on wasm. The entry becomes `Area/Foo.swift` (proved with `swift package dump-package` and a
     scratch build in the PR for #3148);
  3. rewrites every citation of a moved path, in the population `check-test-path-citations.py`
     reads (Scripts/, docs/, okf/, Sources/, Tests/ and Package.swift), so that gate is green after.

A ROW MAY CROSS TARGETS (#3147): a file of the Curve target moves into an area directory of the
Topology target, current path in one `Tests/OCCT<X>Tests/` and proposed path in another. The row stays in the SOURCE target's table,
because column 1 is the path the v5 branch still keeps and `--path-map` is given the table of the
target a lift is reading. Three things differ from a same-target row: the `wasmExcludedTestFiles`
entry, if the file has one, leaves the source target's list and joins the destination's (the entry
is relative to its target, so the move must carry it); a file under a mapped target counts as named
when ANY table under `Scripts/test-areas/` names it, which is how the destination target's own run
accepts the file that arrived; and a destination path another table already claims, or a file name
the destination target already has, is a problem.

DEFAULT IS A DRY RUN. It prints the plan and changes nothing. `--apply` is required to write.

IT REFUSES a dirty tree (`git status --porcelain --untracked-files=no` not empty), in dry-run too,
so the diff of an apply is exactly the move and nothing a person was in the middle of. Untracked
files do not count: the tool only rewrites tracked ones, and an untracked Swift file under a mapped
target is refused separately as a file no row names.

IDEMPOTENT. Each row is in one of five states: `move` (current exists, proposed does not), `done`
(proposed exists, current does not), `same` (the row keeps its path), `conflict` (both exist) or
`missing` (neither does). A second apply finds every row `done`, moves nothing and rewrites nothing.
`conflict` and `missing` stop the run before it touches anything. So does a file under the target
that no row names, which is what a lift PR that merged after the mapping was written looks like.

WHAT IT LEAVES ALONE, decided with evidence rather than by taste. A citing file covered by a `file`
row in `Scripts/test-areas/citation-exemptions.tsv` is not rewritten: `docs/CHANGELOG.md` and the
captured output of probes (`transcript*.txt`, `swift-side.txt`, saved `*.swift.txt` probe sources,
`matrix-*.json`). The rule is that a file recording what ran or what was released at a time is
evidence of that time, so its paths stay as they were, and `check-test-path-citations.py` exempts
the same files, from the same table, so the two cannot disagree. Everything else is rewritten,
including prose in `Scripts/repro/*/README.md`, because a reader following that citation wants the
file as it is now. The measurement behind the rule, taken on main on 2026-10-08: 345 citations in
209 files, of which 24 name a Surface test file. Two of those 24 are CHANGELOG lines (one a dead
monolith path already), none is in captured output, and none of the 174 `Scripts/repro/766-*`
transcripts cites a test path at all; one transcript repo-wide does (`Scripts/repro/2905`). The three
open Surface lifts (#3141, #3143, #3144) add no such citation either. The rule therefore costs
almost nothing today and protects the case that matters: a lift that adds a transcript printing a
test path would otherwise have it rewritten into a lie about what ran. The dry run prints how many
citations of moved paths it left alone, so a
rule that starts swallowing live citations is visible.

    python3 Scripts/move-test-files.py --map Scripts/test-areas/surface.tsv            # dry run
    python3 Scripts/move-test-files.py --map Scripts/test-areas/surface.tsv --apply
    python3 Scripts/move-test-files.py --self-test
"""
import argparse
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))


def _load_gate():
    spec = importlib.util.spec_from_file_location(
        "check_test_path_citations", os.path.join(HERE, "check-test-path-citations.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


GATE = _load_gate()
# An area names what the tests cover. It never names a project, batch, release or issue.
FORBIDDEN_WORDS = {"batch", "issue", "release", "wave", "sprint", "lift", "pr", "phase"}
FORBIDDEN_SHAPE = re.compile(r"\d{3,}|[Vv]\d")
WORD = re.compile(r"[A-Z]+(?![a-z])|[A-Z][a-z]*|[a-z]+|\d+")


def bad_area_name(name):
    """True when a directory name names a project, batch, release or issue. Judged word by word, so
    `Waveform` and `Tissue` pass and `Batch12`, `Issue766` and `BezierV121` do not (a substring test
    refused the first two, which the review of the PR that added this tool, #3149, found). A `V` followed by a digit is a version suffix whatever its length."""
    return (any(w.lower() in FORBIDDEN_WORDS for w in WORD.findall(name))
            or bool(FORBIDDEN_SHAPE.search(name)))
AREA_SHAPE = re.compile(r"^[A-Z][A-Za-z0-9]*$")
TARGET_PATH = re.compile(r"^Tests/(OCCT[A-Za-z0-9]+Tests)/(.+\.swift)$")


class Refusal(Exception):
    pass


def git(root, *args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, check=True).stdout


def load_map(path):
    rows = []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 5:
                raise Refusal("%s:%d: want 5 tab-separated columns, got %d" % (path, n, len(parts)))
            rows.append(dict(cur=parts[0], new=parts[1], area=parts[2], prs=parts[3], reason=parts[4]))
    return rows


def validate_map(rows):
    """Problems in the table itself, independent of the tree."""
    problems, seen_new, seen_cur, base = [], {}, set(), {}
    for r in rows:
        cm, nm = TARGET_PATH.match(r["cur"]), TARGET_PATH.match(r["new"])
        if not cm or not nm:
            problems.append("not a Tests/OCCT<X>Tests/...swift path: %s -> %s" % (r["cur"], r["new"]))
            continue
        if r["cur"] in seen_cur:
            problems.append("current path listed twice: %s" % r["cur"])
        seen_cur.add(r["cur"])
        if r["new"] in seen_new:
            problems.append("two rows land on %s" % r["new"])
        seen_new[r["new"]] = r["cur"]
        key = (nm.group(1), os.path.basename(r["new"]))
        if key in base and base[key] != r["new"]:
            problems.append("two files named %s in target %s" % (key[1], key[0]))
        base[key] = r["new"]
        if r["new"] != r["cur"]:
            segs = nm.group(2).split("/")[:-1]
            if len(segs) != 1:
                problems.append("want exactly one area directory: %s" % r["new"])
            for s in segs:
                if not AREA_SHAPE.match(s) or bad_area_name(s):
                    problems.append("area '%s' names a project, batch, release or issue, or is not "
                                    "CamelCase: %s" % (s, r["new"]))
    return problems


def row_state(root, r):
    cur_ok = os.path.isfile(os.path.join(root, r["cur"]))
    new_ok = os.path.isfile(os.path.join(root, r["new"]))
    if r["cur"] == r["new"]:
        return "same" if cur_ok else "missing"
    if cur_ok and new_ok:
        return "conflict"
    if cur_ok:
        return "move"
    return "done" if new_ok else "missing"


def other_rows(root, map_path):
    """Rows of every OTHER table under Scripts/test-areas/, so a file that arrived from another
    target (a cross-target row lives in the source target's table) is known to the destination's run."""
    out = []
    d = os.path.join(root, "Scripts", "test-areas")
    if not os.path.isdir(d):
        return out
    for f in sorted(os.listdir(d)):
        full = os.path.join(d, f)
        if f.endswith(".tsv") and f != "citation-exemptions.tsv" and os.path.abspath(full) != os.path.abspath(map_path):
            out.extend(load_map(full))
    return out


def cross_target_problems(rows, others):
    """A cross-target row must not land on a path, or a file name, the destination already has."""
    problems = []
    claimed = {r["new"]: r["cur"] for r in others}
    names = {}
    for r in others:
        nm = TARGET_PATH.match(r["new"])
        if nm:
            names.setdefault((nm.group(1), os.path.basename(r["new"])), set()).add(r["new"])
    for r in rows:
        cm, nm = TARGET_PATH.match(r["cur"]), TARGET_PATH.match(r["new"])
        if not (cm and nm) or cm.group(1) == nm.group(1):
            continue
        if r["new"] in claimed and claimed[r["new"]] != r["cur"]:
            problems.append("%s is also claimed by another table's row for %s" % (r["new"], claimed[r["new"]]))
        clash = names.get((nm.group(1), os.path.basename(r["new"])), set()) - {r["new"]}
        if clash:
            problems.append("target %s already has a file named %s: %s"
                            % (nm.group(1), os.path.basename(r["new"]), ", ".join(sorted(clash))))
    return problems


def unmapped_files(root, rows, others=()):
    """Swift files under a mapped target that no row names, at either path."""
    named = {r["cur"] for r in rows} | {r["new"] for r in rows} | {r["cur"] for r in others} | {r["new"] for r in others}
    targets = {TARGET_PATH.match(r["cur"]).group(1) for r in rows if TARGET_PATH.match(r["cur"])}
    out = []
    for t in sorted(targets):
        base = os.path.join(root, "Tests", t)
        for dirpath, _d, files in os.walk(base):
            for f in files:
                rel = os.path.relpath(os.path.join(dirpath, f), root)
                if f.endswith(".swift") and rel not in named:
                    out.append(rel)
    return out


def plan(root, rows, others=()):
    problems = validate_map(rows) + cross_target_problems(rows, others)
    states = [(r, row_state(root, r)) for r in rows]
    for r, s in states:
        if s == "conflict":
            problems.append("both %s and %s exist" % (r["cur"], r["new"]))
        if s == "missing":
            problems.append("neither %s nor %s exists" % (r["cur"], r["new"]))
    for u in unmapped_files(root, rows, others):
        problems.append("%s is under a mapped target and no row names it (a lift landed after the "
                        "map was written? add a row)" % u)
    return states, problems


def rename_map(states):
    """{old: new} for every row that moves or has moved, which is what citations are rewritten by."""
    return {r["cur"]: r["new"] for r, s in states if s in ("move", "done") and r["cur"] != r["new"]}


def rewrite_text(text, rmap):
    """(new_text, count): every citation of a renamed path replaced."""
    count = [0]

    def sub(m):
        new = rmap.get(m.group(0))
        if new is None:
            return m.group(0)
        count[0] += 1
        return new

    return GATE.CITATION.sub(sub, text), count[0]


def rewrite_citations(root, rmap, rows_ex, write):
    """{file: n} rewritten (or that would be), and the count left alone in exempt files."""
    changed, left_alone = {}, 0
    for rel in GATE.tracked_files(root):
        text = GATE.read_text(root, rel)
        if text is None:
            continue
        new_text, n = rewrite_text(text, rmap)
        if not n:
            continue
        if GATE.file_exempt(rel, rows_ex):
            left_alone += n
            continue
        changed[rel] = n
        if write:
            with open(os.path.join(root, rel), "w", encoding="utf-8") as fh:
                fh.write(new_text)
    return changed, left_alone


EXCLUDE_BLOCK = re.compile(r'(?P<head>"(?P<target>OCCT[A-Za-z0-9]+Tests)"\s*:\s*\[)(?P<body>[^\]]*)(?P<tail>\])',
                           re.S)
LITERAL = re.compile(r'"([^"\n]+\.swift)"')


# Column 0 only, on purpose: each target's list closes with an indented `    ],` inside the
# dictionary, and a pattern allowing leading whitespace would end the region at the first of those.
CLOSE_AT_COLUMN_ZERO = re.compile(r"^\]", re.M)


def exclude_region(text):
    """(start, end) of the `wasmExcludedTestFiles` dictionary: from its `let` to its closing `]` at
    the start of a line. None when the file declares no such dictionary; a Refusal when it does and
    never closes it, rather than reading to the end of the file."""
    start = text.find("let wasmExcludedTestFiles")
    if start < 0:
        return None
    close = CLOSE_AT_COLUMN_ZERO.search(text, start)
    if close is None:
        raise Refusal("Package.swift: wasmExcludedTestFiles has no closing ']' at the start of a line")
    return start, close.start()


def add_entry(body, rel):
    """`body` (the text between a list's brackets) with `rel` appended, in the list's own layout."""
    if "\n" in body:
        m = re.search(r'^([ \t]*)"', body, re.M)
        indent = m.group(1) if m else "        "
        tail = re.search(r"\n([ \t]*)$", body)
        close = tail.group(1) if tail else "    "
        stripped = body.rstrip()
        comma = "" if stripped.endswith(",") or not stripped.strip() else ","
        return stripped + comma + '\n%s"%s",\n%s' % (indent, rel, close)
    stripped = body.rstrip()
    return (stripped + ", " if stripped.strip() else "") + '"%s"' % rel


def drop_entry(body, rel):
    """`body` without the entry `rel`: its whole line when it sits on one, else it and one comma."""
    q = re.escape('"%s"' % rel)
    line = re.compile(r"\n[ \t]*%s,?[ \t]*(?=\n)" % q)
    if line.search(body):
        return line.sub("", body, count=1)
    for pat in (r"%s[ \t]*,[ \t]*" % q, r"[ \t]*,[ \t]*%s" % q, q):
        if re.search(pat, body):
            return re.sub(pat, "", body, count=1)
    return body


def rewrite_excludes(root, rows, write):
    """Rewrite the bare names in wasmExcludedTestFiles for moved files. Returns the changes made
    as [(target, old, new)]. Only the dictionary's own region of Package.swift is touched. A file
    that crosses targets leaves its old list and joins the new target's (the entry is relative to
    its target), reported as (source target, old, "DestTarget: new")."""
    path = os.path.join(root, "Package.swift")
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    span = exclude_region(text)
    if span is None:
        return []
    start, end = span
    region = text[start:end]
    # source target -> {path relative to the target: (destination target, proposed relative path)}
    relmap = {}
    for r in rows:
        cm, nm = TARGET_PATH.match(r["cur"]), TARGET_PATH.match(r["new"])
        if cm and nm and r["cur"] != r["new"]:
            relmap.setdefault(cm.group(1), {})[cm.group(2)] = (nm.group(1), nm.group(2))
    changes, arrivals = [], {}

    def block(m):
        mapping = relmap.get(m.group("target"))
        if not mapping:
            return m.group(0)
        body = m.group("body")

        def lit(lm):
            hit = mapping.get(lm.group(1))
            if hit is None or hit[0] != m.group("target"):
                return lm.group(0)
            changes.append((m.group("target"), lm.group(1), hit[1]))
            return '"%s"' % hit[1]

        body = LITERAL.sub(lit, body)
        for old, (dest, rel) in sorted(mapping.items()):
            if dest != m.group("target") and '"%s"' % old in body:
                body = drop_entry(body, old)
                arrivals.setdefault(dest, []).append(rel)
                changes.append((m.group("target"), old, "%s: %s" % (dest, rel)))
        return m.group("head") + body + m.group("tail")

    new_region = EXCLUDE_BLOCK.sub(block, region)

    def arrive(m):
        add = arrivals.get(m.group("target"))
        if not add:
            return m.group(0)
        body = m.group("body")
        for rel in add:
            if '"%s"' % rel not in body:
                body = add_entry(body, rel)
        arrivals.pop(m.group("target"))
        return m.group("head") + body + m.group("tail")

    new_region = EXCLUDE_BLOCK.sub(arrive, new_region)
    if arrivals:
        raise Refusal("Package.swift: wasmExcludedTestFiles has no list for %s, which a moved excluded "
                      "file is going to; add the key and run again" % ", ".join(sorted(arrivals)))
    if write and changes:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text[:start] + new_region + text[end:])
    return changes


def verify_excludes(root):
    """Every wasmExcludedTestFiles entry must resolve to a file under its target, or SwiftPM
    drops it without effect. Returns the entries that do not."""
    with open(os.path.join(root, "Package.swift"), encoding="utf-8") as fh:
        text = fh.read()
    span = exclude_region(text)
    if span is None:
        return []
    region = text[span[0]:span[1]]
    # Drop // comments so a quoted file name in prose is not read as an entry.
    region = "\n".join(l.split("//")[0] for l in region.split("\n"))
    bad = []
    for m in EXCLUDE_BLOCK.finditer(region):
        for lm in LITERAL.finditer(m.group("body")):
            if not os.path.isfile(os.path.join(root, "Tests", m.group("target"), lm.group(1))):
                bad.append("%s: %s" % (m.group("target"), lm.group(1)))
    return bad


def run(root, map_path, apply):
    if git(root, "status", "--porcelain", "--untracked-files=no").strip():
        raise Refusal("tracked files have uncommitted changes; commit or stash first (this tool's diff must be "
                      "the move and nothing else)")
    rows = load_map(map_path)
    states, problems = plan(root, rows, other_rows(root, map_path))
    if problems:
        raise Refusal("the plan has %d problem(s), nothing was changed:\n  %s"
                      % (len(problems), "\n  ".join(problems)))
    counts = {}
    for _r, s in states:
        counts[s] = counts.get(s, 0) + 1
    print("rows: " + ", ".join("%d %s" % (v, k) for k, v in sorted(counts.items())))
    if apply:
        for r, s in states:
            if s == "move":
                os.makedirs(os.path.dirname(os.path.join(root, r["new"])), exist_ok=True)
                git(root, "mv", r["cur"], r["new"])
    ex_rows = GATE.load_exemptions(root)
    rmap = rename_map(states)
    changed, left = rewrite_citations(root, rmap, ex_rows, apply)
    excl = rewrite_excludes(root, rows, apply)
    verb = "rewrote" if apply else "would rewrite"
    print("%s %d citation(s) in %d file(s); left %d citation(s) alone in historical-record files"
          % (verb, sum(changed.values()), len(changed), left))
    print("%s %d wasmExcludedTestFiles entr%s" % (verb, len(excl), "y" if len(excl) == 1 else "ies"))
    for t, o, n in excl:
        print("  %s: %s -> %s" % (t, o, n))
    bad = verify_excludes(root)
    for b in bad:
        print("UNRESOLVED exclude (SwiftPM would ignore it): " + b)
    if apply:
        dangling, stale = GATE.check(root)
        for rel, n, cited in dangling:
            print("DANGLING after apply: %s:%d %s" % (rel, n, cited))
        for k, pat, _ in stale:
            print("STALE EXEMPTION after apply: %s %s" % (k, pat))
        if dangling or stale or bad:
            return 1
    return 1 if bad else 0


# --- self-test ---------------------------------------------------------------------------------

def _repo(files):
    d = tempfile.mkdtemp(prefix="mtf-")
    subprocess.run(["git", "init", "-q", d], check=True)
    for rel, text in files.items():
        p = os.path.join(d, rel.replace("@@", "Tests/OCCT"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(text.replace("@@", "Tests/OCCT"))
    subprocess.run(["git", "-C", d, "add", "-A"], check=True)
    subprocess.run(["git", "-C", d, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "x"],
                   check=True)
    return d


def _fixture():
    pkg = ('let wasmExcludedTestFiles: [String: [String]] = [\n'
           '    "OCCTOtherTests": ["Keep.swift"],\n'
           '    // a comment mentioning "Alpha.swift" must not be read as an entry\n'
           '    "OCCTDemoTests": [\n        "Alpha.swift",\n        "Delta.swift",\n        "Gamma.swift",\n    ],\n'
           ']\n\nlet x = 1 // Tests/OCCT" + "DemoTests/Beta.swift\n')
    pkg = pkg.replace('Tests/OCCT" + "DemoTests/Beta.swift', "@@DemoTests/Beta.swift")
    tsv = ("# current\tproposed\tarea\tprs\treason\n"
           "@@DemoTests/Alpha.swift\t@@DemoTests/Shapes/Alpha.swift\tShapes\t-\tr\n"
           "@@DemoTests/Beta.swift\t@@DemoTests/Shapes/Beta.swift\tShapes\t-\tr\n"
           "@@DemoTests/Gamma.swift\t@@DemoTests/Curves/Gamma.swift\tCurves\t#1\tr\n"
           "@@DemoTests/Shared.swift\t@@DemoTests/Shared.swift\t(stays)\t-\tr\n"
           "@@DemoTests/Delta.swift\t@@OtherTests/Placed/Delta.swift\tPlaced\t-\tcrosses targets\n")
    other_tsv = ("# c\tp\ta\tprs\tr\n"
                 "@@OtherTests/Keep.swift\t@@OtherTests/Keep.swift\t(stays)\t-\tr\n")
    ex =("file\tdocs/CHANGELOG.md\thistory\n"
          "file\tScripts/repro/*transcript*.txt\tcaptured\n")
    return {
        "Package.swift": pkg,
        "@@DemoTests/Alpha.swift": "a", "@@DemoTests/Beta.swift": "b",
        "@@DemoTests/Gamma.swift": "g", "@@DemoTests/Shared.swift": "s", "@@DemoTests/Delta.swift": "d",
        "@@OtherTests/Keep.swift": "k",
        "Scripts/test-areas/other.tsv": other_tsv,
        "docs/guide.md": "see @@DemoTests/Alpha.swift and @@DemoTests/Alpha.swift:12, also "
                         "@@DemoTests/Shared.swift\n",
        "Scripts/a.py": "P = '@@DemoTests/Gamma.swift'\nQ = '@@DemoTests/Delta.swift'\n",
        "Sources/x.swift": "// @@DemoTests/Beta.swift\n",
        "docs/CHANGELOG.md": "- added @@DemoTests/Alpha.swift\n",
        "Scripts/repro/9-x/transcript.txt": "ran @@DemoTests/Gamma.swift\n",
        "Scripts/repro/9-x/README.md": "the test is @@DemoTests/Gamma.swift\n",
        "Scripts/test-areas/demo.tsv": tsv,
        "Scripts/test-areas/citation-exemptions.tsv": ex,
    }


def self_test():
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    def read(d, rel):
        with open(os.path.join(d, rel.replace("@@", "Tests/OCCT")), encoding="utf-8") as fh:
            return fh.read()

    def attempt(d, apply, table="demo.tsv"):
        try:
            return run(d, os.path.join(d, "Scripts/test-areas", table), apply), None
        except Refusal as e:
            return None, str(e)

    # dry run changes nothing
    d = _repo(_fixture())
    rc, err = attempt(d, False)
    check("a dry run exits 0", rc == 0 and err is None, str(err))
    check("a dry run changes nothing", git(d, "status", "--porcelain").strip() == "")
    # apply
    rc, err = attempt(d, True)
    check("apply exits 0", rc == 0 and err is None, str(err))
    check("apply moves the files", os.path.isfile(os.path.join(d, "Tests/OCCTDemoTests/Shapes/Alpha.swift"))
          and os.path.isfile(os.path.join(d, "Tests/OCCTDemoTests/Curves/Gamma.swift"))
          and not os.path.exists(os.path.join(d, "Tests/OCCTDemoTests/Alpha.swift")))
    check("a row that keeps its path is not moved", os.path.isfile(os.path.join(d, "Tests/OCCTDemoTests/Shared.swift")))
    g = read(d, "docs/guide.md")
    check("a citation is rewritten, with its :line suffix kept",
          "@@DemoTests/Shapes/Alpha.swift and @@DemoTests/Shapes/Alpha.swift:12".replace("@@", "Tests/OCCT") in g, g)
    check("a citation of a file that stays is untouched", "Tests/OCCTDemoTests/Shared.swift" in g)
    check("a Python string citation is rewritten", "Curves/Gamma.swift" in read(d, "Scripts/a.py"))
    check("a Sources comment is rewritten", "Shapes/Beta.swift" in read(d, "Sources/x.swift"))
    check("Package.swift prose citation is rewritten", "Shapes/Beta.swift" in read(d, "Package.swift"))
    check("the CHANGELOG is left alone", "OCCTDemoTests/Alpha.swift" in read(d, "docs/CHANGELOG.md")
          and "Shapes" not in read(d, "docs/CHANGELOG.md"))
    check("a captured transcript is left alone", "OCCTDemoTests/Gamma.swift" in read(d, "Scripts/repro/9-x/transcript.txt")
          and "Curves" not in read(d, "Scripts/repro/9-x/transcript.txt"))
    check("prose beside a transcript is rewritten", "Curves/Gamma.swift" in read(d, "Scripts/repro/9-x/README.md"))
    pkg = read(d, "Package.swift")
    check("a wasm exclude gains its area prefix", '"Shapes/Alpha.swift"' in pkg and '"Curves/Gamma.swift"' in pkg, pkg)
    check("a cross-target row moves the file into the other target",
          os.path.isfile(os.path.join(d, "Tests/OCCTOtherTests/Placed/Delta.swift"))
          and not os.path.exists(os.path.join(d, "Tests/OCCTDemoTests/Delta.swift")))
    check("a cross-target row's exclude joins the destination list and keeps its neighbour",
          '"OCCTOtherTests": ["Keep.swift", "Placed/Delta.swift"]' in pkg, pkg)
    check("a cross-target row's exclude leaves the source list, whole line and all",
          '"Shapes/Alpha.swift",\n        "Curves/Gamma.swift",\n    ],' in pkg, pkg)
    check("a cross-target row's citation is rewritten",
          "Tests/OCCTOtherTests/Placed/Delta.swift" in read(d, "Scripts/a.py"))
    check("a quoted name inside a comment is untouched", 'mentioning "Alpha.swift" must' in pkg)
    check("the mapping table itself is not rewritten",
          "@@DemoTests/Alpha.swift\t@@DemoTests/Shapes/Alpha.swift".replace("@@", "Tests/OCCT") in read(d, "Scripts/test-areas/demo.tsv"))
    check("the gate is green after the apply", GATE.check(d) == ([], []), str(GATE.check(d)))
    check("every exclude resolves after the apply", verify_excludes(d) == [], str(verify_excludes(d)))
    # idempotent
    subprocess.run(["git", "-C", d, "add", "-A"], check=True)
    subprocess.run(["git", "-C", d, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "moved"], check=True)
    rc, err = attempt(d, True)
    check("a second apply exits 0", rc == 0 and err is None, str(err))
    check("a second apply changes nothing", git(d, "status", "--porcelain").strip() == "", git(d, "status", "--porcelain"))
    rc, err = attempt(d, True, "other.tsv")
    check("the destination target's own run accepts the file that arrived", rc == 0 and err is None, str(err))
    check("...and changes nothing", git(d, "status", "--porcelain").strip() == "", git(d, "status", "--porcelain"))
    dn = _repo({k: v for k, v in _fixture().items() if k != "Scripts/test-areas/demo.tsv"})
    os.makedirs(os.path.join(dn, "Tests/OCCTOtherTests/Placed"), exist_ok=True)
    git(dn, "mv", "Tests/OCCTDemoTests/Delta.swift", "Tests/OCCTOtherTests/Placed/Delta.swift")
    subprocess.run(["git", "-C", dn, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "arrived"], check=True)
    rc, err = attempt(dn, False, "other.tsv")
    check("a file no table names is still refused in the destination target", err is not None and "Placed/Delta.swift" in err, str(err))
    # dirty
    with open(os.path.join(d, "docs/guide.md"), "a", encoding="utf-8") as fh:
        fh.write("x")
    rc, err = attempt(d, False)
    check("a dirty tree is refused, even for a dry run", err is not None and "uncommitted" in err, str(err))
    subprocess.run(["git", "-C", d, "checkout", "--", "docs/guide.md"], check=True)
    with open(os.path.join(d, "stray-notes.txt"), "w", encoding="utf-8") as fh:
        fh.write("untracked")
    rc, err = attempt(d, False)
    check("an untracked file does not make the tree dirty", rc == 0 and err is None, str(err))
    d7 = _repo(_fixture())
    with open(os.path.join(d7, "Tests/OCCTDemoTests/Untracked.swift"), "w", encoding="utf-8") as fh:
        fh.write("u")
    rc, err = attempt(d7, False)
    check("an untracked Swift file under a mapped target is still refused", err is not None and "Untracked.swift" in err, str(err))
    dc = _repo(dict(_fixture(), **{"Scripts/test-areas/other.tsv":
              "# c\tp\ta\tprs\tr\n@@OtherTests/Keep.swift\t@@OtherTests/Keep.swift\t(stays)\t-\tr\n"
              "@@DemoTests/Zed.swift\t@@OtherTests/Placed/Delta.swift\tPlaced\t-\tr\n", "@@DemoTests/Zed.swift": "z"}))
    rc, err = attempt(dc, False)
    check("a run whose destination another table claims is refused before anything moves",
          err is not None and "claimed by another table" in err, str(err))
    # a stale exclude is caught
    d2 = _repo(_fixture())
    p = os.path.join(d2, "Package.swift")
    with open(p, encoding="utf-8") as fh:
        t = fh.read().replace('"Gamma.swift"', '"Missing.swift"')
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(t)
    eof = _repo({"Package.swift": 'let wasmExcludedTestFiles: [String: [String]] = [\n    "OCCTDemoTests": ["Alpha.swift"],\n]',
                 "@@DemoTests/Alpha.swift": "a"})
    rows = [dict(cur="Tests/OCCTDemoTests/Alpha.swift", new="Tests/OCCTDemoTests/Shapes/Alpha.swift", area="", prs="-", reason="r")]
    rewrite_excludes(eof, rows, True)
    check("a dictionary closing at the very end of the file is rewritten without losing a byte",
          read(eof, "Package.swift") == 'let wasmExcludedTestFiles: [String: [String]] = [\n    "OCCTDemoTests": ["Shapes/Alpha.swift"],\n]',
          read(eof, "Package.swift"))
    open_ended = _repo({"Package.swift": 'let wasmExcludedTestFiles = [\n "OCCTDemoTests": ["Alpha.swift"],\n', "@@DemoTests/Alpha.swift": "a"})
    try:
        rewrite_excludes(open_ended, rows, True)
        check("a dictionary that never closes is refused, not read to the end of the file", False)
    except Refusal:
        check("a dictionary that never closes is refused, not read to the end of the file", True)
    check("an exclude naming no file is reported", verify_excludes(d2) == ["OCCTDemoTests: Missing.swift"],
          str(verify_excludes(d2)))
    # conflict, missing, unmapped
    d3 = _repo(_fixture())
    os.makedirs(os.path.join(d3, "Tests/OCCTDemoTests/Shapes"))
    with open(os.path.join(d3, "Tests/OCCTDemoTests/Shapes/Alpha.swift"), "w") as fh:
        fh.write("dup")
    subprocess.run(["git", "-C", d3, "add", "-A"], check=True)
    subprocess.run(["git", "-C", d3, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "dup"], check=True)
    rc, err = attempt(d3, True)
    check("a row whose destination already exists is a conflict", err is not None and "both" in err, str(err))
    check("a refused run moved nothing", os.path.isfile(os.path.join(d3, "Tests/OCCTDemoTests/Beta.swift")))
    d4 = _repo(dict(_fixture(), **{"@@DemoTests/Late.swift": "late"}))
    rc, err = attempt(d4, True)
    check("a file no row names stops the run", err is not None and "Late.swift" in err, str(err))
    d5 = _repo(_fixture())
    subprocess.run(["git", "-C", d5, "rm", "-q", "Tests/OCCTDemoTests/Beta.swift"], check=True)
    subprocess.run(["git", "-C", d5, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "rm"], check=True)
    rc, err = attempt(d5, True)
    check("a row naming no file stops the run", err is not None and "neither" in err, str(err))
    # partial state: one row already moved
    d6 = _repo(_fixture())
    os.makedirs(os.path.join(d6, "Tests/OCCTDemoTests/Shapes"))
    git(d6, "mv", "Tests/OCCTDemoTests/Alpha.swift", "Tests/OCCTDemoTests/Shapes/Alpha.swift")
    subprocess.run(["git", "-C", d6, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "half"], check=True)
    rc, err = attempt(d6, True)
    check("a half-moved tree is completed", rc == 0 and err is None
          and os.path.isfile(os.path.join(d6, "Tests/OCCTDemoTests/Curves/Gamma.swift")), str(err))
    check("a half-moved tree has its citations rewritten too", "Shapes/Alpha.swift" in read(d6, "docs/guide.md"))
    # map validation
    def probs(*rows):
        return validate_map([dict(cur=c, new=n, area="", prs="-", reason="r") for c, n in rows])
    T = "Tests/OCCTDemoTests/"
    check("an area naming a batch is refused", any("batch" in p or "names" in p for p in probs((T + "A.swift", T + "Batch12/A.swift"))))
    check("an area naming an issue is refused", probs((T + "A.swift", T + "Issue766/A.swift")) != [])
    check("an area carrying a release suffix is refused", probs((T + "A.swift", T + "BezierV121/A.swift")) != [])
    check("a lower-case area is refused", probs((T + "A.swift", T + "shapes/A.swift")) != [])
    check("a nested area is refused", probs((T + "A.swift", T + "Shapes/Deep/A.swift")) != [])
    check("two rows onto one path are refused", probs((T + "A.swift", T + "S/C.swift"), (T + "B.swift", T + "S/C.swift")) != [])
    check("same basename in two areas is refused", probs((T + "A.swift", T + "S/C.swift"), (T + "B.swift", T + "R/C.swift")) != [])
    check("a word inside a longer word is not a project name", probs((T + "A.swift", T + "Waveform/A.swift")) == []
          and probs((T + "A.swift", T + "Tissue/A.swift")) == [])
    check("a name with a batch or issue word is still refused",
          probs((T + "A.swift", T + "SurfaceBatch/A.swift")) != [] and probs((T + "A.swift", T + "Phase2/A.swift")) != [])
    check("a one-digit version suffix is refused too", probs((T + "A.swift", T + "BezierV2/A.swift")) != [])
    check("a dictionary whose lists close with an indented bracket still ends at its own close",
          exclude_region('let wasmExcludedTestFiles = [\n    "OCCTDemoTests": [\n        "A.swift",\n    ],\n]\nlet x = 1\n')
          == (0, len('let wasmExcludedTestFiles = [\n    "OCCTDemoTests": [\n        "A.swift",\n    ],\n')))
    check("a good row is accepted", probs((T + "A.swift", T + "Geom2d/A.swift")) == [])
    check("a cross-target move is accepted", probs((T + "A.swift", "Tests/OCCTOtherTests/S/A.swift")) == [])
    mine = [dict(cur=T + "A.swift", new="Tests/OCCTOtherTests/S/A.swift", area="", prs="-", reason="r")]
    taken = [dict(cur="Tests/OCCT" + "X1Tests/A.swift", new="Tests/OCCTOtherTests/S/A.swift", area="", prs="-", reason="r")]
    clash = [dict(cur="Tests/OCCT" + "X1Tests/A.swift", new="Tests/OCCTOtherTests/R/A.swift", area="", prs="-", reason="r")]
    check("a destination another table already claims is refused", cross_target_problems(mine, taken) != [])
    check("a file name the destination target already has is refused", cross_target_problems(mine, clash) != [])
    check("a cross-target row onto a free path is clean", cross_target_problems(mine, []) == [])
    bad = [r for r in results if not r[1]]
    for name, ok, detail in results:
        print("  %s  %s%s" % ("ok  " if ok else "FAIL", name, "" if ok else "  [" + detail[:200] + "]"))
    print("move-test-files --self-test: %d case(s), %d failed" % (len(results), len(bad)))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--map", help="mapping table, e.g. Scripts/test-areas/surface.tsv")
    ap.add_argument("--apply", action="store_true", help="write; the default is a dry run")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return self_test()
    if not a.map:
        ap.error("--map is required")
    try:
        return run(ROOT, os.path.abspath(a.map), a.apply)
    except Refusal as e:
        print("REFUSED: " + str(e))
        return 2


if __name__ == "__main__":
    sys.exit(main())
