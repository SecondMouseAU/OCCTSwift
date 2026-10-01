#!/usr/bin/env python3
"""Copy BRepFill_Evolved.cxx and plant three prints around CutEdgeProf's throw site.

The point of the copy is to answer one question: does the exception land before or after
`NCollection_Sequence<double> Seq;` is constructed? The unwind destroys `Seq`, so if the throw
precedes its constructor, the cleanup is running on an object that does not exist yet.

Usage: instrument.py <source BRepFill_Evolved.cxx> <output .cxx>

Every anchor is asserted, so a future OCCT version that moves these lines fails here rather than
silently planting nothing and reporting a clean run.
"""

import sys

ANCHORS = [
    (
        "  Cuts.Clear();\n\n  double                         f, l;",
        '  Cuts.Clear();\n  OCCT_2894_MARK("CutEdgeProf entry");\n\n'
        "  double                         f, l;",
    ),
    (
        "  CT = new Geom_TrimmedCurve(C, f, l);",
        '  OCCT_2894_MARK("before Geom_TrimmedCurve");\n'
        "  CT = new Geom_TrimmedCurve(C, f, l);\n"
        '  OCCT_2894_MARK("after Geom_TrimmedCurve");',
    ),
    (
        "  NCollection_Sequence<double> Seq;",
        '  OCCT_2894_MARK("before Seq ctor");\n'
        "  NCollection_Sequence<double> Seq;\n"
        '  OCCT_2894_MARK("after Seq ctor");',
    ),
]

PRELUDE = (
    "#include <NCollection_Sequence.hxx>",
    "#include <NCollection_Sequence.hxx>\n"
    "#include <cstdio>\n"
    "#define OCCT_2894_MARK(x)                                                                  \\\n"
    '  do                                                                                       \\\n'
    "  {                                                                                        \\\n"
    '    std::printf("PROBE2894 MARK %s\\n", x);                                                \\\n'
    "    std::fflush(stdout);                                                                   \\\n"
    "  } while (0)",
)


def main(argv):
    if len(argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        text = handle.read()
    for old, new in [PRELUDE] + ANCHORS:
        if text.count(old) < 1:
            print(f"ERROR: anchor not found in {argv[1]}:\n{old}", file=sys.stderr)
            return 1
        text = text.replace(old, new, 1)
    with open(argv[2], "w", encoding="utf-8") as handle:
        handle.write(text)
    print(f"instrumented {argv[1]} -> {argv[2]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
