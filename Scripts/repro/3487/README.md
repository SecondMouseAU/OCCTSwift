# #3487: BRepTools::Read faults on a BREP text that is cut short

`Shape.loadBREP` on a truncated file killed the process with SIGSEGV. This directory holds the
probe, the matrix driver and the numbers behind the fix, so the evidence outlives the session.

## Entry points

Every public route that reads BREP text, and the bridge function behind it:

| Swift | Bridge | OCCT |
|---|---|---|
| `Shape.loadBREP(from:)`, `Shape.loadBREP(fromPath:)` | `OCCTImportBREP` | `BRepTools::Read(shape, path, builder)` |
| `Shape.fromBREPString(_:)` | `OCCTShapeFromBREPString` | `BRepTools::Read(shape, istringstream, builder)` |
| `BRepGraph` attribute snapshot restore (`BRepGraph+Attributes.swift`) | through `fromBREPString` | as above |

Both bridge functions now go through one helper, `occtReadBREPStream`
(`Sources/OCCTBridge/src/OCCTBridge_IO_NativeFormats.mm`). Not BREP text, so not touched:
`OCCTBinToolsReadShape` / `OCCTBinToolsReadShapeFromFile` (the binary `BinTools_ShapeReader`; measured
below, it throws on every prefix), and the shapes inside an OCAF document (reached through
`Document.loadOCAF`, whose pre-open guards are #3318, #3330 and #3477).

## Running it

```bash
K=<unzipped v4.0.0-kernel.7>/OCCT.xcframework
Scripts/repro/3487/run-all.sh $K /tmp/w3487 8     # builds the probe, writes the corpus, runs the matrix
python3 Scripts/repro/3487/sites.py /tmp/w3487/probe /tmp/w3487/run-bridge/results-bridge.tsv bridge --sample 600
```

`probe.mm` writes the corpus (`probe gen <dir>`: a box, a cylinder, a sphere, a B-spline face, a
B-spline loft, three meshed shapes so the `Triangulations` and `PolygonOnTriangulations` sections
exist, a compound of three solids, a fuse, a rotated box so `Locations` is not empty, and the older
BREP versions V1 and V2 of five of them: 18 `.brep` files, 0.9 to 18.8 KB, plus three `.bin`) and
reads one file (`probe read <mode> <file>`; a signal prints a backtrace). `matrix.py` writes the
cases and runs them through `probe batch`, which forks one child per case, so a fault ends only that
child and a spin ends at 0.1 s of its own CPU (`SIGVTALRM`, shown as `HANG`).

Modes: `path` is `BRepTools::Read(path)` (what `OCCTImportBREP` did), `str` is
`BRepTools::Read(istringstream)` (what `OCCTShapeFromBREPString` did), `strxe` is `str` with the
stream throwing on `failbit | badbit | eofbit`, and `bridge` is `strxe` plus the word-length limit,
which is what ships (the probe carries a copy of the bridge's class; keep the two in step).

Case classes: `prefix` every strict prefix of a small file (every 9th byte of one over 3 KB, and the
last 80 bytes of every file); `byte` a byte replaced by `00`, `FF`, `9`, `-` or `*`, at every second
offset of a small file and every 13th of a large one; `count` every section count raised (+1, +100,
10^6, 2^31-1, 2^31, 10^12), lowered (-1, half, 0, negative); `ref` a sub-shape reference replaced
by index 0, 9999 or 99999999999, or by a location of 9999 or -3; `root` the root reference missing,
`+9999 0`, `+0 0`, `-1 0`, a location of 9999, no location, `*`, junk; `long` a 400 byte word in
place of a section name or a shape type; `header` an empty file, newlines, all byte values, a `V4`
header, no header.

## Measured, before the fix

`BRepTools::Read` on the bare file or stream, `v4.0.0-kernel.7`, macOS arm64. Prefixes thinned to
every 12th plus the last 80 bytes of each file (3,741 cases; the full set takes hours when the
machine is loaded, since every spin costs its CPU allowance):

| entry | cases | SIGSEGV | spin | returned null | returned a shape |
|---|---|---|---|---|---|
| `path` prefixes | 3,741 | 2,006 | 414 | 1,267 | 54 (the three prefixes that drop only `+1 0 `'s tail, per file) |

Both families of truncation fail at once: `IS >> buffer` into an uninitialised `char[255]` leaves a
stale value, which `TopTools_ShapeSet::Read` then uses to index the shape table, and the vertex and
edge geometry loops `do { IS >> val; ... } while (val > 0)` never end on a stale positive `val`.


## Root cause

The fault, from `probe read str` on `box.brep` cut to 2,400 bytes (the same top frame for cuts at
1,000 bytes and 2,560 bytes, and at 2,561, which leaves only the sign of the root reference):

```
_ZNK17TopTools_ShapeSet4ReadER12TopoDS_ShapeRNSt3__113basic_istreamIcNS2_11char_traitsIcEEEEi +336
_ZN17TopTools_ShapeSet4ReadERNSt3__113basic_istream...ERK21Message_ProgressRange             +2868
_ZN9BRepTools4ReadER12TopoDS_ShapeRNSt3__113basic_istream...ERK12BRep_BuilderRK21Message_ProgressRange +68
```

That is `TopTools_ShapeSet::Read(TopoDS_Shape&, IS, nbshapes)` (`TopTools_ShapeSet.cxx:846`; the index is line 861):

```cpp
char buffer[255];
IS >> buffer;                                   // fails at the end of the file, buffer is left as it was
...
S = myShapes(nbshapes - atoi(buffer + 1) + 1);  // line 861
```

`objdump` of the pinned build at the faulting address (`0x10017f6d0`, +336):

```
bl   atoi
sub  w8, w22, w0              // nbshapes - atoi(...)
ldr  x9, [x20, #0x20]         // myShapes' data array
ldr  x22, [x9, w8, sxtw #3]   // myShapes(i): no range check, the pinned kernel is built with No_Exception
ldr  x23, [x22, #0x8]         // the next instruction dereferences it: SIGSEGV at address 8
```

The sub-shape reference list is read the same way in `TopTools_ShapeSet::Read(IS)` (line 766), as is
the root reference in `BRepTools::Read` (`BRepTools.cxx:642`). The `do { Read(SS, IS, nbshapes); ... } while
(!SS.IsNull())` list loop and the vertex and edge `do { IS >> val; ... } while (val > 0)` loops
(`BRepTools_ShapeSet.cxx:935` for a vertex, `:1135` for an edge) are the spins. `OCC_CATCH_SIGNALS` is inert in this build, so
neither is catchable. A word of 255 bytes or more overflows the same `buffer` (`operator>>(char*)`
with no width: the disassembly shows `width < 1 ? INT64_MAX - 1 : width` passed to
`__input_c_string`), which is SIGABRT or SIGBUS.

## The fix, and what it covers

`occtReadBREPStream` reads through a stream that throws on `failbit | badbit | eofbit`, behind a
buffer that refuses a word longer than 254 bytes.

- `failbit` covers an extraction that fails. `eofbit` covers one that **succeeds on a token the end of
  the file ended**: a written BREP ends in a space (`+1 0 `), so a token ended by the end of the file
  is the mark of a cut, and it is refused at the extraction, before the reader uses the value. The
  grammar is fixed, so every strict prefix stops inside some extraction.
- The word limit is 254 because `char buffer[255]` holds a word and its terminator. It is checked in
  64 KiB refills of the stream, so it is O(1) in memory and also refuses an overlong word that the
  reader would never have read (trailing junk after the root).

After (`bridge`, 109,801 cases, 2026-10-18):

| class | cases | refused | accepted | faulted in the reader | spun in the reader | returned, then faulted or spun on use |
|---|---|---|---|---|---|---|
| prefix | 28,977 | 28,977 | 0 | 0 | 0 | 0 |
| long | 54 | 54 | 0 | 0 | 0 | 0 |
| header | 90 | 90 | 0 | 0 | 0 | 0 |
| root | 162 | 72 | 54 | 36 | 0 | 0 |
| count | 1,314 | 1,080 | 126 | 108 | 0 | 0 |
| ref | 2,725 | 0 | 1,394 | 1,239 | 0 | 92 |
| byte | 76,479 | 19,823 | 49,115 | 7,138 | 0 | 403 |

A fault or spin in `byte`, `count`, `ref` and `root` is the open class below; the counts differ by a few from run to run, because a fault that reads freed or uninitialised memory lands on SIGSEGV or SIGBUS depending on what the heap holds.

### What it does not cover

A BREP that is **complete but wrong**: the shape-table index of a sub-shape or root reference that
the file made up, an offset curve whose basis did not read, and a readable shape that is structurally
inconsistent. The shipped guard still faults on those:

| site | share of 600 sampled crashes |
|---|---|
| `TopTools_ShapeSet::Read(TopoDS_Shape&, IS, nbshapes)`, the index above | 562 (94%) |
| `BRepCheck_Edge::InContext`, in the validity check **after** the reader returned a shape | 32 |
| `Geom_OffsetCurve` / `Geom2d_OffsetCurve` constructor with a null basis (`GeomTools_CurveSet::ReadCurve`, `GeomTools_Curve2dSet::ReadCurve2d`) | 5 |
| no backtrace | 1 |

No text check short of re-implementing the reader's grammar (every curve, surface, polygon and
triangulation record, to find where a shape record's reference list starts) can see these, which is
why this is a partial fix. Also not covered, and by design:

- A file with its trailing whitespace stripped is refused, as a cut one is (`+1 0` without the space
  is a prefix of itself). `Scripts/repro/occt1568-fillet-opposite-edge/gtest/window.brep` is one such
  file. Relaxing it admits the prefix that drops only that space, and a cut inside a multi-digit
  root location (`+1 12` read as `+1 1`), which parses as the wrong location silently.
- Anything that is not the TShapes root, such as a BREP concatenated with other text.

Tracked in #3490, with the carried-patch outline: bound the index in
`TopTools_ShapeSet::Read(TopoDS_Shape&, IS, nbshapes)`, check `myMap(l1)` in
`TopTools_LocationSet::Read`, extract through `std::setw(sizeof buffer)`, null-check the basis of an
offset curve, and stop the `while (val > 0)` loops on `IS.fail()`. It is a kernel patch and needs a
rebuild and a decision; it is not authored here.

## The binary sibling

`BinTools_ShapeReader::Read` (behind `OCCTBinToolsReadShape`), `probe read bin`, three files, every
strict prefix and a byte corruption at every second offset (8,908 cases): all 2,623 prefixes throw,
and no corruption faults inside the reader. Two corrupted files return a shape that spins (2) and
seven that fault later, in `BRepCheck` on the returned shape; those are the use-site class above,
not a reader fault.
