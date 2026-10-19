#!/usr/bin/env python3
"""#3487: the README's per-class table from a matrix run's results file.

usage: classtable.py <run-dir>/results-<mode>.tsv

Prints a markdown table: one row per case class, counting what happened to the cases of the class.
`returned, then faulted or spun on use` is a case where the reader returned a shape and the
probe's validity check then faulted or spun on it, which is not a fault of the reader.
"""
import sys
from collections import Counter, defaultdict

COLUMNS = ["refused", "accepted", "faulted in the reader", "spun in the reader",
           "returned, then faulted or spun on use"]


def column(cls):
    if cls.startswith("refused"):
        return "refused"
    if cls.startswith("accepted"):
        return "accepted"
    if cls.startswith("USE-"):
        return "returned, then faulted or spun on use"
    if cls.startswith("SIG") or cls.startswith("EXIT"):
        return "faulted in the reader"
    if cls.startswith("HANG"):
        return "spun in the reader"
    return cls


def main():
    tot = defaultdict(Counter)
    for line in open(sys.argv[1]):
        name, kind, label, cls, path = line.rstrip("\n").split("\t")
        tot[kind][column(cls)] += 1
    print("| class | cases | " + " | ".join(COLUMNS) + " |")
    print("|---|---|" + "---|" * len(COLUMNS))
    for kind in ["prefix", "long", "header", "root", "count", "ref", "byte"]:
        if kind in tot:
            c = tot[kind]
            print(f"| {kind} | {sum(c.values()):,} | " + " | ".join(f"{c[x]:,}" for x in COLUMNS) + " |")


if __name__ == "__main__":
    main()
