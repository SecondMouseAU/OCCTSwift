#!/usr/bin/env python3
"""#3490: the hand-made damaged files behind BREPKernelDamagedReadTests, written next to a box.

usage: cases.py <box.brep> <out-dir>

<box.brep> is the box `probe gen` writes (Scripts/repro/3487). Each output is read with
`probe read path <file>` and `probe read str <file>`; the table in Scripts/patches/README.md under
0073 says what each does before and after the patch.
"""
import os
import sys

box = open(sys.argv[1]).read()
out = sys.argv[2]
os.makedirs(out, exist_ok=True)


def put(name, text):
    assert text != box, name  # an edit that did not apply tests nothing
    open(os.path.join(out, name + ".brep"), "w").write(text)


def edit(old, new):
    assert old in box, old
    return box.replace(old, new, 1)


# OCCT#1560: a vertex coordinate of 44 characters, as a decimal and as an exponent.
put("long_number", edit("\n0 0 30\n", "\n0 0 30.0000000000000000000000000000000000000001\n"))
put("long_exp", edit("\n0 0 30\n", "\n0 0 3.0000000000000000000000000000000000000001e1\n"))
# OCCT#1608: the text ends inside an edge, and inside a vertex.
head = ("DBRep_DrawableShape\n\nCASCADE Topology V1, (c) Matra-Datavision\nLocations 0\nCurve2ds 0\n"
        "Curves 0\nPolygon3D 0\nPolygonOnTriangulations 0\nSurfaces 0\nTriangulations 0\n\nTShapes 1\n")
open(os.path.join(out, "edge_flags.brep"), "w").write(head + "Ed\n 1e-07 1 1 1\n")
open(os.path.join(out, "vertex_cut.brep"), "w").write(head + "Ve\n1e-07\n0 0 0\n")
# An overlong word where a section name or a shape type goes.
put("longword_section", edit("Curve2ds 24", "C" * 400 + " 24"))
put("longword_type", edit("\nVe\n", "\n" + "V" * 400 + "\n"))
# References outside the tables.
put("ref_9999", edit("+20 0 +13 0 *", "+9999 0 +13 0 *"))
tail = box.rstrip()
assert tail.endswith("+1 0")
put("root_9999", tail[:-4] + "+9999 0")
# A trimmed and an offset curve whose basis is a type nothing reads (99).
put("offset_nobasis", edit("1 0 0 0 0 0 1 ", "9 1 0 0 1 99 "))
put("trimmed_nobasis", edit("1 0 0 0 0 0 1 ", "8 0 1 99 "))
put("offset2d_nobasis", edit("1 0 0 1 0 \n", "9 1 99 \n"))
# A composed location (type 2) built from an entry that is not in the table, and one that is.
located = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), "locatedbox.brep")
if os.path.exists(located):
    text = open(located).read().replace("Locations 1\n", "Locations 2\n", 1)
    at = text.index("Curve2ds")
    open(os.path.join(out, "loc_composed_bad.brep"), "w").write(text[:at] + "2 9999 1 0\n" + text[at:])
    open(os.path.join(out, "loc_composed_ok.brep"), "w").write(text[:at] + "2 1 2 0\n" + text[at:])
