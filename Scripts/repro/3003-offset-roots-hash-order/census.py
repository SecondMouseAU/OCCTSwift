#!/usr/bin/env python3
"""#3003: read the output of many probe runs on stdin and say how far the runs agree.

    census.py lines     the output of `probe lines` run in N fresh processes
    census.py battery   the output of `battery` run in N fresh processes
    census.py compare A B   two files of `battery` output, one per build
    census.py --self-test

`lines` input is `<label> <volume as %a> <dump hash> <volume as %.17g>` per line, one block of
labels per run. For each label it reports how many distinct volumes and how many distinct bit-exact
dumps the runs produced, and the relative spread of the volumes. A label whose volume never moves
but whose dump does is a result that comes back in a different sub-shape order.

`battery` input is the 72 lines of battery.mm per run. It reports how many cases produced more than
one distinct result across the runs, split into the cases where only the dump (the sub-shape order)
differs and the cases where the outcome itself differs: valid, volume, face count, or a NULL shape.

`compare` reads the `battery` output of two builds and reports every case whose set of outcomes
differs between them, the dump left out. It answers a different question from `battery`: not
whether a build agrees with itself, but whether two builds return the same thing.
"""
import collections
import sys


def census_lines(text):
    vals = collections.defaultdict(collections.Counter)
    dumps = collections.defaultdict(collections.Counter)
    order = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) != 4:
            continue
        label, hexval, dump, _decimal = parts
        if label not in order:
            order.append(label)
        vals[label][hexval] += 1
        dumps[label][dump] += 1
    rows = []
    for label in order:
        values = sorted(float.fromhex(v) for v in vals[label])
        top = max(abs(values[0]), abs(values[-1]))
        spread = (values[-1] - values[0]) / top if top else 0.0
        rows.append((label, sum(vals[label].values()), len(vals[label]), len(dumps[label]), spread))
    return rows


def print_lines(rows):
    print("%-20s %5s %9s %9s %16s" % ("line", "runs", "volumes", "dumps", "relative spread"))
    for label, runs, nv, nd, spread in rows:
        print("%-20s %5d %9d %9d %16.2e" % (label, runs, nv, nd, spread))


def census_battery(text, per_run=72):
    lines = [l for l in text.splitlines() if l.strip()]
    if len(lines) % per_run != 0:
        raise SystemExit("battery: %d lines is not a whole number of %d-line runs" % (len(lines), per_run))
    runs = [lines[i:i + per_run] for i in range(0, len(lines), per_run)]
    results = collections.defaultdict(collections.Counter)
    for run in runs:
        for line in run:
            results[line.split(":")[0]][line] += 1

    def outcome(line):
        return line.rsplit(" dump=", 1)[0]

    moved = [k for k, c in results.items() if len(c) > 1]
    outcome_differs = [k for k in moved if len({outcome(x) for x in results[k]}) > 1]
    return {
        "runs": len(runs),
        "cases": len(results),
        "moved": moved,
        "outcome_differs": outcome_differs,
        "outcomes": {k: sorted({outcome(x).split(": ", 1)[1] for x in results[k]}) for k in outcome_differs},
    }


def battery_outcomes(text, per_run=72):
    """label -> the set of outcomes (the line without its dump) the runs produced."""
    lines = [l for l in text.splitlines() if l.strip()]
    if len(lines) % per_run != 0:
        raise SystemExit("battery: %d lines is not a whole number of %d-line runs" % (len(lines), per_run))
    out = collections.defaultdict(set)
    for line in lines:
        label = line.split(":")[0]
        out[label].add(line.rsplit(" dump=", 1)[0].split(": ", 1)[1])
    return out


def compare_batteries(text_a, text_b, per_run=72):
    a, b = battery_outcomes(text_a, per_run), battery_outcomes(text_b, per_run)
    # `missing` before `differing`: reading b[k] on a defaultdict inserts k, which hid the very
    # case this list exists to report.
    missing = sorted(set(a) ^ set(b))
    differing = {k: (sorted(a[k]), sorted(b.get(k, ()))) for k in a if a[k] != b.get(k)}
    return len(a), differing, missing


def print_compare(n, differing, missing):
    print("cases compared: %d" % n)
    print("cases whose set of outcomes differs between the two builds: %d" % len(differing))
    for k, (x, y) in sorted(differing.items()):
        print("  %s\n      first : %s\n      second: %s" % (k, "  |  ".join(x), "  |  ".join(y)))
    if missing:
        print("cases present in only one of the two: %s" % ", ".join(missing))


def print_battery(r):
    print("runs: %d, cases per run: %d" % (r["runs"], r["cases"]))
    print("cases with more than one distinct result over the runs: %d" % len(r["moved"]))
    print("  of which only the dump differs (the sub-shapes came back in another order): %d"
          % (len(r["moved"]) - len(r["outcome_differs"])))
    print("  of which the outcome itself differs: %d" % len(r["outcome_differs"]))
    for k in r["outcome_differs"]:
        print("    %s: %s" % (k, "  |  ".join(r["outcomes"][k])))


def self_test():
    failures = []

    def case(name, ok):
        if not ok:
            failures.append(name)

    stable = "a 0x1p+0 aa 1\na 0x1p+0 aa 1\nb 0x1p+1 bb 2\nb 0x1p+1 bb 2\n"
    rows = census_lines(stable)
    case("stable lines report one volume and one dump", all(r[2] == 1 and r[3] == 1 for r in rows))
    moved = "a 0x1p+0 aa 1\na 0x1.0000000000001p+0 ab 1\n"
    rows = census_lines(moved)
    case("a moved volume is reported as two volumes", rows[0][2] == 2)
    case("a moved volume has a nonzero spread", rows[0][4] > 0)
    reorder = "a 0x1p+0 aa 1\na 0x1p+0 ab 1\n"
    rows = census_lines(reorder)
    case("a reordered result is one volume and two dumps", rows[0][2] == 1 and rows[0][3] == 2)
    case("a line that is not four fields is ignored", census_lines("noise\n") == [])

    two_runs_same = "c1: valid=1 volume=1.0 faces=6 dump=aa\n" * 2
    r = census_battery(two_runs_same, per_run=1)
    case("identical battery runs move nothing", r["moved"] == [] and r["runs"] == 2)
    two_runs_dump = "c1: valid=1 volume=1.0 faces=6 dump=aa\nc1: valid=1 volume=1.0 faces=6 dump=bb\n"
    r = census_battery(two_runs_dump, per_run=1)
    case("a dump-only difference is moved but not an outcome difference",
         r["moved"] == ["c1"] and r["outcome_differs"] == [])
    two_runs_outcome = "c1: valid=1 volume=1.0 faces=6 dump=aa\nc1: done, NULL shape\n"
    r = census_battery(two_runs_outcome, per_run=1)
    case("a NULL result against a solid is an outcome difference", r["outcome_differs"] == ["c1"])
    try:
        census_battery("a: x\nb: y\nc: z\n", per_run=2)
        case("a ragged battery input is refused", False)
    except SystemExit:
        case("a ragged battery input is refused", True)

    same_a = "c1: valid=1 volume=1.0 faces=6 dump=aa\nc2: not done\n"
    same_b = "c1: valid=1 volume=1.0 faces=6 dump=bb\nc2: not done\n"
    n, differing, missing = compare_batteries(same_a, same_b, per_run=2)
    case("two builds that differ only in the dump return the same thing",
         n == 2 and differing == {} and missing == [])
    other = "c1: valid=1 volume=2.0 faces=6 dump=aa\nc2: not done\n"
    n, differing, missing = compare_batteries(same_a, other, per_run=2)
    case("a different volume is a different outcome", list(differing) == ["c1"])
    null = "c1: done, NULL shape\nc2: not done\n"
    n, differing, missing = compare_batteries(same_a, null, per_run=2)
    case("a NULL result against a solid is a different outcome", list(differing) == ["c1"])
    extra = "c1: valid=1 volume=1.0 faces=6 dump=aa\n"
    n, differing, missing = compare_batteries(same_a, extra, per_run=1)
    case("a case present in only one build is reported", missing == ["c2"])

    for f in failures:
        print("self-test FAILED:", f)
    print("self-test: %d failure(s)" % len(failures))
    return 1 if failures else 0


def main(argv):
    if "--self-test" in argv:
        return self_test()
    mode = argv[1] if len(argv) > 1 else ""
    if mode == "compare":
        if len(argv) != 4:
            print(__doc__)
            return 2
        print_compare(*compare_batteries(open(argv[2]).read(), open(argv[3]).read()))
        return 0
    text = sys.stdin.read()
    if mode == "lines":
        print_lines(census_lines(text))
        return 0
    if mode == "battery":
        print_battery(census_battery(text))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
