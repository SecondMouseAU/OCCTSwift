#!/usr/bin/env python3
"""Gate: every `Tests/OCCT<Domain>Tests/...swift` path cited in the repo resolves to a file (#3148).

Nothing checked that a cited test path exists. A file renamed, split or deleted left every prose
mention of it pointing at nothing, and #3147's plan to sort each test target into subdirectories
would do that to hundreds of citations in one commit. This is the gate that makes the rewrite
checkable: after a move, a citation the move tool missed fails here.

WHAT IT ASSERTS. Scan every tracked text file under Scripts/, docs/, okf/, Sources/ and Tests/, plus Package.swift, for
the pattern `Tests/OCCT<Name>Tests/<path>.swift`, and require the cited path to exist as a file.
A citation with a glob in it (`Tests/OCCTThreadTests/*.swift`) is not matched by the pattern, so
globs are not checked. A bare file name with no directory is not matched either, which is a real
limit: a citation written `see FooTests.swift` is invisible here and to the move tool.

EXEMPTIONS. A citation that is allowed to dangle is a row in
`Scripts/test-areas/citation-exemptions.tsv` with a written reason: a citing file whose content is
a historical record (the CHANGELOG, captured probe output), or a cited path that never was a merged
test (scratch `ZZ*` probes, self-test placeholders, the deleted per-domain monolith files). A `path`
or `regex` row that matches no dangling citation is a failure of its own, so the list cannot become
an allowlist nobody rereads. `Scripts/test-areas/` itself is not scanned: the mapping tables there
name the destination of a move that has not happened yet, so their `proposed_path` column dangles
by design.

THE AREA TABLES (#3308). The gate also runs the plan `move-test-files.py --map` makes for every
`Scripts/test-areas/*.tsv` table (except the exemptions table): the dry run's own checks, without
its clean-tree refusal. A table fails when a Swift file under its target has no row, which is how a
shared helper added later (`SIMDTestHelpers.swift`) or a test that landed straight in an area
directory left twelve tables refusing unseen; when a row's current and proposed paths both exist
or neither does; and when the table itself is malformed. After the roll-out every row is `done` or
`same`, and "clean" means the plan found no problem. A shared helper gets a `(stays)` row.

EXIT STATUS. 0 clean, 1 on a dangling citation, a stale exemption or an area-table problem.

    python3 Scripts/check-test-path-citations.py            # the gate
    python3 Scripts/check-test-path-citations.py --list     # every citation, one per line
    python3 Scripts/check-test-path-citations.py --self-test
"""
import fnmatch
import importlib.util
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SCAN_DIRS = ("Scripts", "docs", "okf", "Sources", "Tests")
# Package.swift is the one root file that cites a test file by path (the wasm shim), so it is read too.
SCAN_FILES = ("Package.swift",)
# Not scanned: the mapping data names destinations that do not exist yet.
SKIP_PREFIXES = ("Scripts/test-areas/",)
EXEMPTIONS = "Scripts/test-areas/citation-exemptions.tsv"
# The class holds "/" because a citation may name an area subdirectory (`Area/FooTests.swift`), and
# "+" because Swift file names use it (`Shape+Curve.swift`), and "-" for hyphenated names; a class
# without any of them goes blind to the citations that use them.
CITATION = re.compile(r"Tests/OCCT[A-Za-z0-9]+Tests/[A-Za-z0-9_.+/-]*?\.swift")


def tracked_files(root):
    """Files under the scanned directories: `git ls-files` in a checkout, a walk otherwise."""
    if os.path.exists(os.path.join(root, ".git")):
        out = subprocess.run(["git", "-C", root, "ls-files", "--", *SCAN_DIRS, *SCAN_FILES],
                             capture_output=True, text=True, check=True).stdout
        names = [n for n in out.split("\n") if n]
    else:
        names = []
        for d in SCAN_DIRS:
            for dirpath, _dirs, files in os.walk(os.path.join(root, d)):
                for f in files:
                    names.append(os.path.relpath(os.path.join(dirpath, f), root))
        names += [f for f in SCAN_FILES if os.path.isfile(os.path.join(root, f))]
    return sorted(n for n in names if not n.startswith(SKIP_PREFIXES))


def read_text(root, rel):
    """The file's text, or None for anything that is not UTF-8 (binary assets)."""
    try:
        with open(os.path.join(root, rel), encoding="utf-8") as fh:
            return fh.read()
    except (UnicodeDecodeError, OSError):
        return None


def load_exemptions(root):
    rows = []
    path = os.path.join(root, EXEMPTIONS)
    if not os.path.isfile(path):
        return rows
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 3 or parts[0] not in ("file", "path", "regex") or not parts[2].strip():
                raise SystemExit("%s:%d: want 'kind<TAB>pattern<TAB>reason' with kind file|path|regex "
                                 "and a non-empty reason" % (EXEMPTIONS, n))
            rows.append((parts[0], parts[1], parts[2]))
    return rows


def file_exempt(rel, rows):
    return any(k == "file" and fnmatch.fnmatchcase(rel, pat) for k, pat, _ in rows)


def path_exempt_row(cited, rows):
    """The index of the first path or regex row covering `cited`, or None."""
    for i, (k, pat, _) in enumerate(rows):
        if k == "path" and fnmatch.fnmatchcase(cited, pat):
            return i
        if k == "regex" and re.fullmatch(pat, cited):
            return i
    return None


def citations(root, rows=None):
    """[(citing_file, line_no, cited_path)] over the scanned population.

    With `rows`, a citing file covered by a `file` row is left out, which is how the move tool and
    this gate agree on what a historical record is."""
    out = []
    for rel in tracked_files(root):
        if rows is not None and file_exempt(rel, rows):
            continue
        text = read_text(root, rel)
        if text is None:
            continue
        for n, line in enumerate(text.split("\n"), 1):
            for m in CITATION.finditer(line):
                out.append((rel, n, m.group(0)))
    return out


def check(root, cites=None):
    """(dangling, stale): dangling is [(file, line, cited)], stale is [exemption row].

    `cites` is an unfiltered `citations(root)` the caller already holds, so a report that also
    counts them scans the tree once; the `file` rows are applied here."""
    rows = load_exemptions(root)
    used = set()
    dangling = []
    if cites is None:
        cites = citations(root, rows)
    else:
        cites = [c for c in cites if not file_exempt(c[0], rows)]
    for rel, n, cited in cites:
        if os.path.isfile(os.path.join(root, cited)):
            continue
        idx = path_exempt_row(cited, rows)
        if idx is not None:
            used.add(idx)
            continue
        dangling.append((rel, n, cited))
    stale = [rows[i] for i in range(len(rows)) if rows[i][0] != "file" and i not in used]
    return dangling, stale


def map_problems(root, mover_path=None):
    """[(table, problem)] for every area table under Scripts/test-areas/: the plan
    `move-test-files.py --map` builds, so a file no row names (a new shared helper, a test that
    landed in its area directory) fails here instead of refusing a later apply (#3308)."""
    d = os.path.join(root, "Scripts", "test-areas")
    if not os.path.isdir(d):
        return []
    mover_path = mover_path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "move-test-files.py")
    # A gate that cannot load the plan it runs has not passed: report it as a problem (exit 1)
    # rather than crash with a traceback or, worse, skip the check.
    try:
        spec = importlib.util.spec_from_file_location("move_test_files", mover_path)
        mover = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mover)
    except BaseException as e:  # SyntaxError, a missing file, SystemExit from the module itself
        if isinstance(e, KeyboardInterrupt):
            raise
        return [("move-test-files.py", "cannot load %s, so no area table was checked: %s: %s"
                 % (mover_path, type(e).__name__, e))]
    out = []
    for name in sorted(os.listdir(d)):
        if not name.endswith(".tsv") or name == os.path.basename(EXEMPTIONS):
            continue
        path = os.path.join(d, name)
        try:
            rows = mover.load_map(path)
            _states, problems = mover.plan(root, rows, mover.other_rows(root, path))
        except mover.Refusal as e:
            problems = [str(e)]
        out.extend((name, p) for p in problems)
    return out


def report(root):
    cites = citations(root)
    dangling, stale = check(root, cites)
    maps = map_problems(root)
    for name, p in maps:
        print("AREA TABLE %s: %s" % (name, p))
    for rel, n, cited in dangling:
        print("DANGLING %s:%d cites %s, which does not exist" % (rel, n, cited))
    for k, pat, _ in stale:
        print("STALE EXEMPTION %s %s matches no dangling citation; delete the row from %s"
              % (k, pat, EXEMPTIONS))
    total = len(cites)
    print("check-test-path-citations: %d citation(s) scanned, %d dangling, %d stale exemption(s), "
          "%d area-table problem(s)" % (total, len(dangling), len(stale), len(maps)))
    return 1 if dangling or stale or maps else 0


# --- self-test ---------------------------------------------------------------------------------

def _tree(files):
    """A scratch tree. "@@" in a path or a text stands for "Tests/OCCT", spelled this way so this
    file's own fixtures are not citations the gate would then have to resolve."""
    d = tempfile.mkdtemp(prefix="tpc-")
    for rel, text in files.items():
        rel, text = rel.replace("@@", "Tests/OCCT"), text.replace("@@", "Tests/OCCT")
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(text)
    return d


def self_test():
    cases = []

    def case(name, files, want_dangling, want_stale=0):
        d = _tree(files)
        dangling, stale = check(d)
        passed = len(dangling) == want_dangling and len(stale) == want_stale
        cases.append((name, passed, "dangling=%d stale=%d" % (len(dangling), len(stale))))

    live = "@@SurfaceTests/Fill/FooTests.swift"
    case("a citation of an existing file is clean",
         {live: "x", "docs/a.md": "see %s here" % live}, 0)
    case("a citation of a missing file dangles",
         {"docs/a.md": "see @@SurfaceTests/GoneTests.swift"}, 1)
    case("a file moved into a subdirectory but cited flat dangles",
         {live: "x", "docs/a.md": "see @@SurfaceTests/FooTests.swift"}, 1)
    case("a citation in each scanned directory is read",
         {"Scripts/a.py": "@@AATests/A.swift", "docs/a.md": "@@BBTests/B.swift",
          "okf/a.md": "@@CCTests/C.swift", "Sources/a.swift": "// @@DDTests/D.swift",
          "@@EETests/x.swift": "// @@EETests/E.swift"}, 5)
    case("Package.swift is read",
         {"Package.swift": "// @@AATests/Shim.swift"}, 1)
    case("a file outside the scanned directories is not read",
         {"README.md": "@@AATests/A.swift"}, 0)
    case("a file name containing a plus sign is a citation, as Shape+Curve.swift style names are",
         {"docs/a.md": "@@SurfaceTests/Shape+Curve.swift"}, 1)
    case("a plus-sign file name that exists resolves",
         {"@@SurfaceTests/Shape+Curve.swift": "x", "docs/a.md": "@@SurfaceTests/Shape+Curve.swift"}, 0)
    case("a glob citation is not a citation",
         {"docs/a.md": "@@ThreadTests/*.swift"}, 0)
    case("the mapping directory is not scanned",
         {"Scripts/test-areas/x.tsv": "@@AATests/New/A.swift"}, 0)
    case("a citation followed by a line number resolves",
         {live: "x", "docs/a.md": "%s:123" % live}, 0)
    case("a citation of a missing file followed by a line number dangles",
         {"docs/a.md": "@@SurfaceTests/GoneTests.swift:123"}, 1)
    case("a file exemption covers a historical record",
         {EXEMPTIONS: "file\tdocs/CHANGELOG.md\thistory\n",
          "docs/CHANGELOG.md": "@@AATests/Old.swift"}, 0)
    case("a file exemption does not cover another file",
         {EXEMPTIONS: "file\tdocs/CHANGELOG.md\thistory\n",
          "docs/b.md": "@@AATests/Old.swift"}, 1)
    case("a path exemption covers a scratch probe",
         {EXEMPTIONS: "path\t@@*Tests/ZZ*.swift\tscratch\n",
          "docs/a.md": "@@AATests/ZZProbe.swift"}, 0)
    case("a path exemption that matches nothing is stale",
         {EXEMPTIONS: "path\t@@*Tests/ZZ*.swift\tscratch\n",
          "docs/a.md": "nothing cited"}, 0, 1)
    case("a path exemption for a file that now exists is stale",
         {EXEMPTIONS: "path\t@@AATests/Old.swift\tgone\n",
          "@@AATests/Old.swift": "x", "docs/a.md": "@@AATests/Old.swift"}, 0, 1)
    case("a regex exemption covers the monolith file",
         {EXEMPTIONS: "regex\tTests/(OCCT[A-Za-z0-9]+Tests)/\\1\\.swift\tmonolith\n",
          "docs/a.md": "@@AA@@AATests.swift and @@AATests/Other.swift"}, 1)
    case("a binary file is skipped, not a crash",
         {"docs/a.md": "ok"}, 0)
    # The binary case needs raw bytes, so build it by hand.
    d = _tree({"docs/a.md": "ok"})
    with open(os.path.join(d, "docs", "bin.dat"), "wb") as fh:
        fh.write(b"\xff\xfe\x00" + b"Tests/" + b"OCCTAATests/A.swift")
    dangling, stale = check(d)
    cases[-1] = (cases[-1][0], not dangling and not stale, "dangling=%d" % len(dangling))
    # Area tables (#3308). A target with one test and one shared helper; a table naming only the
    # test leaves the helper as a file no row names, which is what broke twelve tables.
    test_row = "@@XTests/FooTests.swift\t@@XTests/Area/FooTests.swift\tArea\t-\twhy\n"
    helper_row = "@@XTests/SIMDTestHelpers.swift\t@@XTests/SIMDTestHelpers.swift\t(stays)\t-\tshared\n"
    header = "# current_path\tproposed_path\tarea\tpending_prs\treason\n"

    def map_case(name, table, want, extra=None):
        files = {"@@XTests/Area/FooTests.swift": "x", "@@XTests/SIMDTestHelpers.swift": "x"}
        files.update(extra or {})
        if table is not None:
            files["Scripts/test-areas/x.tsv"] = table
        got = map_problems(_tree(files))
        cases.append((name, len(got) == want, "area-table problems=%d" % len(got)))

    map_case("a table naming the test and the helper is clean", header + test_row + helper_row, 0)
    map_case("a shared helper with no row fails", header + test_row, 1)
    map_case("a test that landed in its area with no row fails",
             header + test_row + helper_row, 1, {"@@XTests/Area/BarTests.swift": "x"})
    map_case("a malformed table is a problem, not a crash", header + "only\ttwo\n", 1)
    map_case("a tree with no tables is clean", None, 0)

    def load_case(name, mover_text, want):
        d = _tree({"@@XTests/Area/FooTests.swift": "x", "@@XTests/SIMDTestHelpers.swift": "x",
                   "Scripts/test-areas/x.tsv": header + test_row + helper_row})
        path = os.path.join(d, "mover.py")
        if mover_text is not None:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(mover_text)
        got = map_problems(d, mover_path=path)
        cases.append((name, len(got) == want and all("cannot load" in p for _n, p in got),
                      "problems=%s" % [p[:40] for _n, p in got]))

    load_case("a missing move-test-files.py is a gate failure, not a crash", None, 1)
    load_case("a move-test-files.py with a syntax error is a gate failure", "def (:\n", 1)
    load_case("a move-test-files.py that raises on import is a gate failure", "raise RuntimeError('x')\n", 1)

    # One scan serves the report: a precomputed citation list must give check() the same answer.
    d = _tree({EXEMPTIONS: "file\tdocs/h.md\thistory\n", "docs/h.md": "@@AATests/Old.swift",
               "docs/a.md": "@@AATests/Gone.swift"})
    plain, pre = check(d), check(d, citations(d))
    cases.append(("check() with a precomputed scan agrees with its own scan and applies file rows",
                  plain == pre and len(pre[0]) == 1, "dangling=%d" % len(pre[0])))
    bad = [c for c in cases if not c[1]]
    for name, passed, detail in cases:
        print("  %s  %s (%s)" % ("ok  " if passed else "FAIL", name, detail))
    print("check-test-path-citations --self-test: %d case(s), %d failed" % (len(cases), len(bad)))
    return 1 if bad else 0


def main():
    args = sys.argv[1:]
    if args == ["--self-test"]:
        return self_test()
    if args == ["--list"]:
        for rel, n, cited in citations(ROOT):
            print("%s:%d\t%s" % (rel, n, cited))
        return 0
    if args:
        print(__doc__)
        return 2
    return report(ROOT)


if __name__ == "__main__":
    sys.exit(main())
