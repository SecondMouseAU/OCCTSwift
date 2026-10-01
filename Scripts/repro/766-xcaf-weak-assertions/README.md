# 766: measuring what `Tests/OCCTXCAFTests/` should pin

`probe-output.txt` is the transcript this slice's expected values came from, per
[`okf/policies/measure-dont-assume.md`](../../../okf/policies/measure-dont-assume.md). Nothing in
the rewritten tests was derived from reading a wrapper.

## How it was taken

A throwaway `@Suite` was written into `Tests/OCCTXCAFTests/`, run with
`swift test --filter ZzMeasureProbeTests`, and deleted. Every line it printed is prefixed `PROBE`.
Five runs are concatenated, in order:

1. tracing, ShapeTool, explorer, ShapeMapTool, TNaming extensions, TNaming basics, directory,
   IDFilter
2. label tags and fathers, `FindShape` against `SearchShape`, `TopExp::MapShapes` arithmetic,
   fresh-document directory tags, explorer depth, select/resolve, editor expand and rescale
3. the trace control case, explorer depth under a real assembly, assembly item counts,
   select/resolve detail, editor detail, rescale detail
4. the bisect that located the crash (`v.findLabel` is the last line before it), **before** the
   bridge guards
5. the same bisect **after** the guards, all five calls answering

`OCCTSWIFT_BRIDGE_PREBUILT` was unset for every run, so the `.mm` edits between runs 4 and 5 were
live rather than inert.

## The two things the measurement found

### A `TNaming` family that takes the process down on a document with no naming

Four `Document` methods crashed when the document root carried no `TNaming_UsedShapes` attribute,
which is the state of every document before the first `TNaming_Builder` runs:
`sameShapeCount`, `sameShapeLabels`, `namingFindLabel` and `namingValidUntil`. The process printed
`*** Abort *** an exception was raised, but no catch was found. ... SIGSEGV`, which is
`CLAUDE.md`'s documented `Standard_ErrorHandler::Abort` path with `FindHandler()` finding nothing.
Two separate mechanisms:

- **An uninitialised member, nothing to do with `No_Exception`.**
  `TNaming_SameShapeIterator`'s `TDF_Label` constructor leaves its raw `TNaming_PtrNode myNode`
  **uninitialised** when the attribute is absent (`TNaming_NamedShape.cxx:1358`: the whole body is
  inside `if (access.Root().FindAttribute(...))` and the header declares no default). `More()` is
  `myNode != nullptr` over that garbage. This is an upstream defect.

- **A compiled-out precondition, which is
  [`okf/policies/occt-validation-is-compiled-out.md`](../../../okf/policies/occt-validation-is-compiled-out.md)
  met in a new place.** `TNaming_Tool::Label` and `TNaming_Tool::ValidUntil` guard exactly this case
  with `Standard_NoSuchObject_Raise_if(!HasLabel(...))`, and both are out-of-line, so both are
  empty in the kernel we link. `Scripts/occt-raise-if-map.txt:4515` already records the row:
  `TNaming_NamedShape outofline-raise 27 Standard_NoMoreObject,Standard_NoSuchObject ... Label ...
  ValidUntil`. The map had the fact; nothing had asked what the bridge callers do without it. With
  the raise gone, both functions fall through to the private overload and dereference a null
  `TNaming_UsedShapes` handle. `census-compiled-out-validation.py` does not flag these two, because
  its question is about a bridge `catch` that swallows a value, and here the `catch` never runs.

The fix is a `TNaming_Tool::HasLabel` guard in all four bridge functions, which is the policy's
"guard the value before the call" rather than a `try`. `HasLabel` performs the same lookup without
the dereference and is false both for the missing attribute and for a shape not in the map, which
are exactly the two cases that must answer "nothing found". Regression test:
`TNamingExtensionTests.sameShapeQueriesOnADocumentWithNoNaming`.

The upstream half, `myNode`, is not patched here: the bridge no longer reaches it, and a kernel
patch is its own PR per
[`okf/policies/upstream-occt-patch-process.md`](../../../okf/policies/upstream-occt-patch-process.md).

### A fixture that had stopped meaning its name

`TNamingSelectResolveTests` built a standalone `Shape.face(from: Wire.rectangle(...))` and called it
"a shape within context" when selecting against a box. It is not a sub-shape of the box at all.
Measured: `selectShape` accepts it and writes a `.selected` evolution, and `resolveShape` then
returns nil, so every assertion in the suite was running on the refusal path. The suite now selects
a real face of the box, and keeps the foreign-face case as its own test with the refusal it
actually produces.
