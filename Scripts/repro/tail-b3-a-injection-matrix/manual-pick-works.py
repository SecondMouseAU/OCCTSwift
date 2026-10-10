#!/usr/bin/env python3
"""Add one hand-written switch, MANUAL_PICK_WORKS, to the generated Sources/OCCTSwift/InjectionShadow.swift.

SelectorTests' three hit expectations sit in `withKnownIssue`, because `Selector.pick` returns no hit at
all on the pinned kernel (the finding this PR reports). A generic distortion cannot redden such a test:
the thing that must redden it is a pick that WORKS, after which "Known issue was not recorded" fires. This
switch is that: OCCTSelectorPick reports one hit and OCCTSelectorPickRect reports one hit, with the
ids the three tests expect (pixel x 384 -> 1, 416 -> 2, any other point -> 42; the rectangle -> 7).

usage (repo root, after generate-shadow.py): python3 <this dir>/manual-pick-works.py
then run-injection-matrix.py LABEL --switches <this dir>/manual-switches.txt --out matrix-manual-LABEL.json
"""
PATH = "Sources/OCCTSwift/InjectionShadow.swift"
s = open(PATH).read()
if "MANUAL_PICK_WORKS" in s:
    raise SystemExit("already patched")

def after(anchor, add):
    global s
    assert s.count(anchor) == 1, anchor
    s = s.replace(anchor, anchor + add)

after("    var rr = OCCTBridge.OCCTSelectorPick(sel, cam, viewW, viewH, pixelX, pixelY, out, maxResults)\n",
      '    if GD.on("MANUAL_PICK_WORKS"), let o = out, maxResults > 0 {\n'
      "        o[0] = OCCTPickResult(shapeId: pixelX == 384 ? 1 : (pixelX == 416 ? 2 : 42), depth: 1, pointX: 0, pointY: 0, pointZ: 0, subShapeType: 8, subShapeIndex: -1)\n"
      "        return 1\n    }\n")
after("    var rr = OCCTBridge.OCCTSelectorPickRect(sel, cam, viewW, viewH, xMin, yMin, xMax, yMax, out, maxResults)\n",
      '    if GD.on("MANUAL_PICK_WORKS"), let o = out, maxResults > 0 {\n'
      "        o[0] = OCCTPickResult(shapeId: 7, depth: 1, pointX: 0, pointY: 0, pointZ: 0, subShapeType: 8, subShapeIndex: -1)\n"
      "        return 1\n    }\n")
open(PATH, "w").write(s)
