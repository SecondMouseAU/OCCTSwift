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

## Proving the tests fail

[`okf/policies/prove-the-test-fails.md`](../../../okf/policies/prove-the-test-fails.md) asks for a
red against an injected defect for every test touched. Sixty-three tests is too many to rebuild
once each, so the harness is one build with a runtime switch: `apply-injections.py` patches 43
semantic defects into the bridge and the Swift layer, each selected by `OCCT766_INJECT`,
`run-injection-matrix.py` runs the suite once per id, and `score-injection-matrix.py` maps the
display names Swift Testing prints back to function names and asserts coverage.

`injection-matrix.txt` is the scored result: **43 injections, 63 touched tests, 63 covered**, with
the baseline green and no crash. `injection-matrix-raw.txt` is the unscored run.

None of the injections is of the "bridge returns nil" shape, because that is the weakness being
removed and a test that notices only total failure would pass it. Each is a plausible wrong answer:
a trace that also emits its own source, a `FindShape` that descends like `SearchShape`, a
`removeShape` that reports success and removes nothing, a path ID that loses its trailing
separator, an extent off by one, a tag counter pinned at 1, an `isKept` that answers true for
everything, an `Expand` that reports success and expands nothing, a `RescaleGeometry` that scales
nothing.

Three things the sweep caught that a looser one would have reported as clean:

1. **`OCCTSWIFT_BRIDGE_PREBUILT=1` is ambient in this environment** and makes every `.mm` edit
   inert. The driver pops it from the environment of the **test run**, not just the build.
2. **The first attempt scraped nothing.** Driving `swiftpm-testing-helper` directly produced no
   parseable output, and the matrix printed 43 rows of "reds 0", which reads exactly like a suite
   full of blind tests. The baseline assertion ("0 seen passing") is what caught it; without a
   baseline row the run would have been reported as a finding about the tests.
3. **Two injections landed past an early exit, and both were real.** INJ29 sat after the
   `FindAttribute` guard in `OCCTDocumentNamingGetEvolution`, so the one fixture with no attribute
   (`noEvolutionOnEmptyLabel`) never reached it; moving the injection above the guard reds it.
   INJ42 exposed a defect in the new test itself: `XDEEditorTests.editorExpand` read `volumes[0]`
   after `#expect(volumes.count == 2)`, and `#expect` does not short-circuit, so an empty array was
   a fatal subscript that killed the process and the test after it (`editorExpandRefusals`) never
   ran. The array equivalent of the force-unwrap `CLAUDE.md` forbids. Fixed, in four places, by
   taking elements through `first`/`last` with `try #require`.

The switch count is asserted against the test count for exactly the reason the brief gives: an
injection that was never wired shows up as an uncovered test, which is what a blind test also looks
like, and the two must not be confused.
