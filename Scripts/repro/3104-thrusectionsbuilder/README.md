# #3104: ThruSectionsBuilder with fewer than two sections

Question: does `ThruSectionsBuilder` crash or return an invalid shape for the input that crashed
`Shape.loft` in #3099? Answer: no. Every case either refuses (`build()` is false, `shape` is nil) or
returns a valid shape. No process crashed, hung or returned a non-zero exit code.

Cause: `OCCTThruSectionsBuild` already refuses `sectionCount < 2` before calling
`BRepOffsetAPI_ThruSections::Build`, counting `addWire` and `addVertex` alike. That is the same
count #3103 added to `OCCTShapeCreateLoftAdvanced`, and the same rule as the DRAW `thrusections`
command (`BRepTest_SweepCommands.cxx`).

Method: `probe.swift` drives the public builder surface; `run.sh` runs one input per process with a
60 s timeout; `transcript.txt` is the output, 288 processes on the released kernel
(`v4.0.0-kernel.4`). Each order (W = addWire, V = addVertex, in sequence) ran for solid and shell,
ruled and smooth, and with six option sets: none, `setSmoothing(true)`,
`setSmoothing(false)` + `setMaxDegree` + `setContinuity`, `checkCompatibility(false)` +
`setParType` + `setCriteriumWeight`, `shape` read before `build()`, and `build()` called twice.

| Sections added | Cases | build() | shape | Crash | Hang | Invalid shape |
|---|---|---|---|---|---|---|
| none | 24 | false | nil | 0 | 0 | 0 |
| one wire (W) | 24 | false | nil | 0 | 0 | 0 |
| one vertex (V) | 24 | false | nil | 0 | 0 | 0 |
| two vertices (VV) | 24 | false | nil | 0 | 0 | 0 |
| wire + vertex (WV, VW) | 48 | true | valid | 0 | 0 | 0 |
| two wires (WW) | 24 | true | valid | 0 | 0 | 0 |
| three or more (WWW, VWW, WWV, VWV, VWWV) | 120 | true | valid | 0 | 0 | 0 |

Totals: 96 refused with nil, 192 valid shapes, 0 crashes, 0 hangs, 0 invalid shapes.
