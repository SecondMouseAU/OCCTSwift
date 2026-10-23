# #3495: a position reference that leaves the stream, loops, or names the wrong kind of record

Evidence for carried patches `0076` (`BinTools_ShapeReader`) and `0077` (`BRepCheck_Edge::InContext`);
`Scripts/patches/README.md` has the write-up and the measured tables. Everything here reuses the
harness of `Scripts/repro/3487` and `Scripts/repro/3494`; the one new file is
`brepcheck-pcurve-only-edge.cxx`.

## What the 11 `x_located` cases are

The issue guessed two defects, an unchecked position and a cycle. Probing the cases, with
`BinTools_ShapeReader.cxx` compiled `-O0` with a `fprintf` in `ReadShape`, `ReadLocation` and the
reference branches and linked ahead of the library, they are five:

| cases | what happens | rule in `0076` |
|---|---|---|
| `@3660`, `@3680`, `@3701` (with -1, `Int32.min`, `Int32.max`, 10^8) | the byte after a shape reference is the orientation, cast to `TopAbs_Orientation` unchecked; a shape of orientation 255 faults in `TopoDS_Iterator::updateCurrentShape` through `TopAbs::Compose` | orientation and continuity bytes checked against their enumeration |
| `@3679=10^8` | a sub-shape list runs on to a reference to the compound that holds it; the record is read again from inside itself, 1,630 times, until the stack ends | a reference to a record being read is refused |
| `@2699`, `@3135`, `@3571`, `@3613` | a type byte of another kind lands in a location slot, is read as the identity and consumes nothing; the file stays in step with a structure the writer never wrote, and `BRepCheck_Analyzer` faults on the shape | a slot accepts its own type, the empty type of its kind, or a reference |
| (not in the matrix) | a delta past the start of the stream: `position - delta - 1` wraps to near 2^64 | delta zero or `>= position` refused |
| (not in the matrix) | a chain of references to references recurses once per link | a reference whose target is a reference is refused |

The last two are in `BinToolsPositionReferenceTests` as hand-written streams.

## What the "returned, then faulted" cases are

`python3 Scripts/repro/3487/sites.py <probe> <results.tsv> str --class USE-SIG11` over the text
count class groups all of them at one frame, `BRepCheck_Edge::InContext`. Two preconditions, one
per cause: a face whose surface index names no surface (`Su->DynamicType()`, #2789), and an edge
whose 3D curve index names no curve, on a planar face (`occ::down_cast<GeomAdaptor_Curve>(myHCurve)`
null, #2746). `brepcheck-pcurve-only-edge.cxx` is the second with no file at all.

## Reproducing the tables

```bash
K=<unzipped v4.0.0-kernel.7>/OCCT.xcframework
Scripts/repro/3487/build.sh $K /tmp/probe-k7
Scripts/repro/3494/build-fixtures.sh $K /tmp/fixtures
mkdir /tmp/corpus /tmp/fx && /tmp/probe-k7 gen /tmp/corpus && /tmp/fixtures /tmp/fx
# the baseline (0070-0074) and the patched build, each a copy of the framework with the changed
# units compiled from a tree carrying the patches and swapped in with `ar r`; the headers of the
# patches are copied over the copy's Headers (0076 adds a member to BinTools_ShapeReader, so
# BinMNaming_NamedShapeDriver.cxx and BinMXCAFDoc_LocationDriver.cxx are recompiled with it)
Scripts/repro/3494/stage.sh <occt-src> $K /tmp/stage-0074 Scripts/patches/007[0-4]*.patch
Scripts/repro/3487/build.sh /tmp/stage-0074/xcf /tmp/probe-0074
python3 Scripts/repro/3494/counts.py /tmp/probe-0074 /tmp/corpus /tmp/fx /tmp/run bin
python3 Scripts/repro/3494/counts.py /tmp/probe-0074 /tmp/corpus /tmp/fx /tmp/run-str str
python3 Scripts/repro/3487/matrix.py /tmp/probe-0074 /tmp/corpus /tmp/run-struct str --only struct
```

Do not put the fixtures in a directory whose name differs from another only in case: the build of
the patched framework `rm -rf`s its output directory, and this volume is case-insensitive.
