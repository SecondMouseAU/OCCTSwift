# #2835: how OCCT tells two occurrences of one part apart, measured

#2650 fixed the lookup half: `findNode(for:)` now resolves the sub-shapes of a placed instance, and
it answers **the definition node**, so the two instances of one part in a compound both come back as
`Solid[0]`. That is the kernel's own aliasing, not a defect. What #2835 adds is the other half, a
way to get the **occurrence** a located sub-shape was reached through.

`probe.mm` measures what OCCT's answer is, against the pinned kernel asset; `probe-output.txt` is
that run. Compile line is in `CLAUDE.md`'s ground-truth section, plus `-framework CoreGraphics`.

## OCCT's answer is a path, not an id

Three lines in the kernel's own headers say so, and the `BRepGraph` README says why.

```
BRepGraph/README.md:398          "Keep occurrence-context metadata resolution out of the core
                                 storage model; resolve it through explorer usage paths or
                                 layer-side resolvers."
BRepGraph_ChildExplorer.hxx:47   "visits each occurrence. If Edge[5] is reachable through Face[0]
                                 and Face[1], it is visited twice with different accumulated
                                 transforms."
BRepGraph_UsagePath.hxx:33       "Paths are used to disambiguate multiple occurrences of the same
                                 definition reachable through different references or sibling
                                 positions."
```

So the occurrence-aware lookup is a wrap of `BRepGraph_ChildExplorer::CurrentUsagePath()` plus
`Current().Location`, and `BRepGraph_UsagePath` is the identity. Nothing new is invented here; the
whole of this issue's public surface is those two calls.

## What the probe settles

**A. there is no root Product to start from.** `OCCTBRepGraphCreate` passes
`Options::CreateAutoProduct = false`, and the result is `Products=0 Occurrences=0
RootProductIds().Size()=0`. So the assembly node kinds are absent from every graph this wrapper
builds, `rootNodes` / `rootProductIndices` are empty, and the traversal root has to be the topology
root, which the caller gets from `findNode(for:)` on the shape the graph was built from. This is why
the Swift API takes the root rather than defaulting to one.

**B/C. the explorer emits one entry per occurrence.** From `Compound[0]` on a compound holding one
box twice: `TargetKind=Solid` emits 2 for `Solids().Nb()==1`, and `TargetKind=Face` emits 12 for
`Faces().Nb()==6`. `Face[0]` is emitted twice, at `loc=(0,0,0)` and `loc=(100,0,0)`.

**D. the field that carries the distinction is the step's `Ref` and `StepIndex`, not the node.**

```
first  = Compound[0](-,step=-1) / Solid[0](ChildRef[0],step=0) / Shell[0](ShellRef[0],step=0) / Face[0](FaceRef[0],step=0)
second = Compound[0](-,step=-1) / Solid[0](ChildRef[1],step=1) / Shell[0](ShellRef[0],step=0) / Face[0](FaceRef[0],step=0)
IsEqual = false   HashCode equal = true
```

Every node in the two paths is identical. Only the `Solid[0]` step differs, in both its `ChildRef`
and its `StepIndex`. A bridge that emitted nodes alone would collapse the two occurrences right back
together, so all three fields per step are part of the C struct.

`HashCode equal = true` is worth recording: `BRepGraph_UsagePath::HashCode()` is documented to use
"first step, last step, and size for O(1) computation", so two occurrences differing only in a middle
step collide. That is fine for a hash and wrong for an identity, which is why the Swift
`UsagePathStep`/`Occurrence` hash is Swift's own synthesis over every step rather than a wrap of
`HashCode()`.

**E. nesting composes.** A compound of two compounds, each holding the same box twice, gives 4 solid
occurrences with 3-step paths, distinguished at two different levels.

**F. cost.** On a 200-instance compound, one enumeration of every occurrence of one face definition
is **0.21 ms**, and the full 1200-occurrence sweep of the same kind is **0.21 ms**: the same figure,
because the traversal is the whole cost and the per-definition filter saves nothing. That is the
shape of the answer to the issue's cost question. Per-pick resolution is affordable, and a downstream
identity table that wants every occurrence should sweep the kind once rather than call per pick, since
n picks cost n traversals.

**G. the edge cases.** `root == target` emits the root once, with a single-step path whose `Ref` is
invalid and whose `StepIndex` is `-1`. A target index the graph does not have gives 0. An
out-of-range **root** emits 0 and **does not throw**, so the bridge's guard is a plain count of zero
rather than a caught exception. An unplaced single part gives exactly 1 occurrence with an identity
location, so the accessor is meaningful on a part as well as on an assembly.
