# #3490: the text BREP readers take no more than their buffer holds, and stop at a stream that has failed

Evidence for carried patch `0073` (`Scripts/patches/README.md` has the write-up, the census of every
`>>` into a char array, and the measured tables). It reuses the #3487 harness, `Scripts/repro/3487/`
(`probe.mm`, `matrix.py`, `classtable.py`), and adds what that harness does not have:

- `run-unguarded.sh <OCCT.xcframework> <work-dir> [jobs]` runs the harness against the **bare reader**
  (`BRepTools::Read` on the path and on a stream, no bridge guard in front), thinned the way the #3487
  "before" runs are, so a patched kernel and an unpatched one compare case for case. Then
  `python3 Scripts/repro/3487/classtable.py <work-dir>/run-<name>/results-<mode>.tsv` prints each class.
- `cases.py <box.brep> <out-dir>` writes the hand-made files `BREPKernelDamagedReadTests` builds in
  Swift: a number of 44 characters (OCCT#1560), a text that ends inside an edge and inside a vertex
  (OCCT#1608), an overlong word as a section name and as a shape type, a sub-shape and a root
  reference outside the table, and a trimmed and an offset curve whose basis is a type nothing reads.

To run the unpatched side, unzip the `v4.0.0-kernel.7` `OCCT.xcframework.zip`. For the patched side,
compile the translation units the patch changes (`git diff --name-only` in a `Libraries/occt-src` with
the stack applied, `-O2 -DNDEBUG -DNo_Exception`, the headers of the unzipped framework) and
`ar r` them into a copy of its `macos-arm64/libOCCT-macos.a`; one pass is minutes, not the hour of a
kernel build.

What each part of the patch buys was measured by removing it from the whole in turn (the table is in
the patch's README entry): the shape-table index range is the largest single part, the failed-stream
checks and loop terminators the next, the basis checks catch one `byte` case in 355, and the
composed-location range check catches none of the matrix's cases and is needed all the same: a
`Locations` entry `2 9999 1 0` faults without it and is refused with it (`cases.py` writes `loc_composed_bad.brep`; the matrix's four files have no composed locations).
