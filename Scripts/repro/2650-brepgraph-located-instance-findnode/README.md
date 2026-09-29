# #2650: why `findNode(for:)` missed every sub-shape of a placed instance

`BRepGraph.findNode(for:)` returned `nil` for any face, edge or vertex reached through a located
child of a compound, so no picked sub-shape of a STEP assembly got a `GraphUID` downstream. The
question the fix turned on is not "does it return nil" but **what OCCT's contract for `FindNode`
actually is**, because if a located sub-shape is correctly a different shape with no node, then the
issue is a documentation fix rather than a lookup fix.

It is a lookup fix. `probe.mm` measures it three ways against the pinned `v4.0.0-kernel.2` asset
(OCCT 8.0.1 plus the carried patches), and `probe-output.txt` is that run.

## OCCT's contract, from the kernel's own headers

Two lines settle it, and they point the same way.

```
BRepGraph_ShapesView.hxx:216   FindNode "uses OCCT IsSame() semantics
                               (TShape + Location, orientation ignored)".
BRepGraph_ShapesView.hxx:258   bindSourceShapeAliases: "Bind source shape keys to nodes
                               populated from a location-stripped input shape. This keeps
                               ShapesView::FindNode() usable with the original TopoDS
                               subshapes when root placement is stored on a Product
                               occurrence or Compound child ref."
```

So a located sub-shape **is** a different key from the definition, and the kernel nonetheless
intends `FindNode` to answer for it: it binds each original sub-shape as an alias of the definition
node, on purpose, for exactly this case. `nil` is not OCCT's answer.

`bindSourceShapeAliasesRecursive` (`BRepGraph_ShapesView.cxx:544`) is what does the work. For a
compound parent it recurses with the child's populated shape stripped to the identity
(`:570-579`), and `bindSourceShapeAlias` (`:514`) looks the definition up with
`aLookup.Location(theDefinitionLocation)` and binds the source key to that node. The definition key
for a compound child is therefore **the source sub-shape with its placement dropped**.

## Why it never ran here

`Add()` calls it under one condition (`BRepGraph_ShapesView.cxx:897-922`):

```cpp
const bool isRootLocationStoredInRef = shouldStoreRootLocationInRef(theOptions, BRepGraph_NodeId());
...
if (isRootLocationStoredInRef && aResult.TopologyRoot.IsValid())
{
  bindSourceShapeAliases(theGraph, theShape, aPopulateShape);
}
```

and for a parentless `Add` that condition *is* `Options::CreateAutoProduct`
(`shouldStoreRootLocationInRef`, `:73-82`). `OCCTBRepGraphCreate` passes `CreateAutoProduct = false`
to preserve pre-beta1 node counts, so no alias was ever bound, while the *children's* placements
went onto child refs regardless of that option. The gate is on the root's own placement; the
aliasing it suppresses is about the children. That asymmetry is the whole defect, and it is
upstream's, with our non-default option as the trigger.

## Measured: the three cases the issue lists, under both option values

`CreateAutoProduct = false`, which is what the bridge passes:

| case | query | resolved |
|---|---|---|
| A `compound[box, moved]` | solids | **1 of 2** |
| A | faces | **6 of 12** |
| A | edges / vertices | **12 of 24** / **8 of 16** |
| A | `FindNode(moved)` | **INVALID** (`FindNode(box)` is `Solid[0]`) |
| B `compound[moved]` | faces | **0 of 6** |
| C root `= moved` | faces of `moved` | 6 of 6 |
| D `compound[box, moved(compound[moved])]` | faces | **6 of 12** |

`CreateAutoProduct = true`, OCCT's own default: **every** one of those is complete, 2 of 2, 12 of
12, 24 of 24, 16 of 16, 6 of 6, 12 of 12. The kernel resolves the located sub-shapes when its own
aliasing runs. That reproduces the issue exactly and locates the cause.

Case E answers the second question the issue raises. With the aliasing on, the two solid
occurrences of one definition both resolve to `Solid[0]`, with `Solids().Nb() == 1`: **a single-node
answer is what the kernel gives, and it names the definition, not the occurrence.** Per-occurrence
identity is not a NodeId question upstream either; `BRepGraph/README.md:398` keeps occurrence
context out of the storage model and resolves it through explorer usage paths.

## Why the fix is not "pass OCCT's default"

Flipping `CreateAutoProduct` to `true` would be the one-word fix and it changes more than the
lookup. The last block of `probe-output.txt`:

```
CreateAutoProduct=false root=Solid[0]  Shape(root).Location().IsIdentity()=false
CreateAutoProduct=true  root=Solid[0]  Shape(root).Location().IsIdentity()=true
```

With `true` the root's own placement is stripped into the auto Product's occurrence, so the
definition is the *unplaced* solid and `BRepGraph.shape(nodeKind:nodeIndex:)` on a graph built from
a placed shape comes back at the origin. It also adds a Product and an Occurrence node to every
graph, which `BRepGraphProductTests` and `BRepGraphOccurrenceTests` currently assert are absent. A
lookup defect does not justify moving the whole surface.

## Why the fix is the definition-key retry, and what bounds it

The bridge applies the same key transformation the kernel's own alias binder applies: on a miss
with a non-identity placement, look the shape up again with the placement dropped. The probe's
fourth block is the second construction, comparing that retry against a `CreateAutoProduct = true`
graph **element for element**, not by count:

```
A solids     retry   2/  2, OCCT aliasing   2/  2, agree   2/  2
A faces      retry  12/ 12, OCCT aliasing  12/ 12, agree  12/ 12
A edges      retry  24/ 24, OCCT aliasing  24/ 24, agree  24/ 24
A vertices   retry  16/ 16, OCCT aliasing  16/ 16, agree  16/ 16
B faces      retry   6/  6, OCCT aliasing   6/  6, agree   6/  6
B edges      retry  12/ 12, OCCT aliasing  12/ 12, agree  12/ 12
D faces      retry  12/ 12, OCCT aliasing  12/ 12, agree  12/ 12
D solids     retry   2/  2, OCCT aliasing   2/  2, agree   2/  2
D edges      retry  24/ 24, OCCT aliasing  24/ 24, agree  24/ 24
```

Same node, same kind, same index, on every element of every compound case including the nested one.

Two places they differ, both printed rather than hidden:

- **Case C, a located root.** With `CreateAutoProduct = false` the definition legitimately carries
  the root's placement, so the *unplaced* box has no node and the retry does not invent one, while
  OCCT with `true` aliases both keys. The retry preserves today's behaviour here, which is the
  behaviour the `shape(nodeKind:)` result above depends on.
- **Case F, a placed shape the graph never ingested.** OCCT binds an alias only for a source
  sub-shape it actually walked, so it answers `0 of 6`; an unbounded retry answers `6 of 6`. That
  would make `hasNode(for:)` true for a shape that was not part of the construction input, which is
  the opposite of what the kernel documents it to mean.

Case F is why the retry is bounded rather than unconditional. `OCCTBRepGraphCreate` records the
input's located sub-shapes once, at construction, and the retry fires only for a shape in that
record, so it is the kernel's aliasing reproduced over the kernel's own domain. The record is
written once and read-only afterwards, so it adds no shared mutable state to a `@unchecked Sendable`
class, and only non-identity placements are stored, so an unplaced single part stores nothing.

## Running it

```bash
clang++ -std=c++17 -ObjC++ -w \
  -I"Libraries/OCCT.xcframework/macos-arm64/Headers" \
  -L"Libraries/OCCT.xcframework/macos-arm64" \
  -lOCCT-macos -framework Foundation -framework AppKit -lz -lc++ \
  Scripts/repro/2650-brepgraph-located-instance-findnode/probe.mm -o /tmp/occt_probe
/tmp/occt_probe
```

In a worktree with no `Libraries/`, point `-I` and `-L` at the resolved artifact instead:
`.build/artifacts/<checkout>/OCCT/OCCT.xcframework/macos-arm64/`.
