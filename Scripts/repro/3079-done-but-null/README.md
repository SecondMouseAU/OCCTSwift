# #3079: do the 35 `new OCCTShape(builder.Shape())` sites ever return a done-but-null shape?

#3061 found that `BRepOffsetAPI_MakeOffsetShape` reports done with a null shape for a collapsing
offset, and guarded the eight offset-family functions. #3079 lists 35 more bridge functions with the
same `IsDone()`-only shape and asks which of them can be made to do the same from Swift. This
directory is that measurement.

## Result

**No null-wrapped result was produced by any of the 35.** Of 949 cases (one process each, released
kernel `v4.0.0-kernel.4`, debug build): 0 returned a non-nil `Shape` whose `isNull` is true, the rest
were `nil`, a valid non-null shape, or a constructor refusal before the bridge was reached.
Three groups did not return normally, and are separate defects filed as issues rather than fixed here:

- #3098: `middlePath(start:end:)` crashes (SIGSEGV) for the same face twice, two adjacent faces, and two null shapes.
- #3099: `loft(profiles:solid:ruled:false)` with a single profile crashes (SIGSEGV).
- #3100: zero or NaN extrusion length and vector, NaN draft and revolution angles, a NaN mesh point, and a 1e300 infinite extrusion did not return in 20 s.

No guard was added, so no bridge, Swift or doc file changed. Every function is recorded below as
probed and not reproducible. That is a statement about these inputs, not a proof: a null result may
exist for an input class not tried. The inputs are in `probe/Sources/probe/main.swift`, and the guard
goes in the day one is found, with the test pattern of `Tests/OCCTModelingTests/Issue3061OffsetNullResultTests.swift`.

`OCCTShapeUnion` and `OCCTShapeIntersect` have no Swift caller at all, and `OCCTShapeSubtract` is
reached only through `drilled(...)`. For those three the Swift boolean wrappers (which run the same
`BRepAlgoAPI_Fuse`, `Cut`, `Common`) were probed with the same pairs, which is evidence about the
builder and not a call of the C function itself. The four `BRepAlgoAPI` booleans cope: nil or a valid
shape in every case, including both operands null, an emptied solid and empty compounds.

## Per function

| # | Bridge function | Swift API | Inputs tried | Result (cases) |
|---|---|---|---|---|
| 1 | `OCCTShapeDraft` | `drafted(faces:direction:angle:neutralPlane:)` | angle 0, 45, 89.9, 90, 180, -89.9 deg, NaN; zero direction; zero or parallel neutral normal; null base; two faces; sphere face | 10 nil, 3 valid |
| 2 | `OCCTShapeConvertToNURBS` | `convertedToNURBS()` | box, sphere, null, emptied solid, empty compound | 1 nil, 4 valid |
| 3 | `OCCTShapeFuseAndBlend` | `fusedAndBlended(with:radius:)` | overlapping, identical, disjoint, contained, coincident-face boxes; box and sphere; radius 1e-4 and 1000; null either side; emptied; faces | 3 nil, 9 valid |
| 4 | `OCCTShapeCutAndBlend` | `cutAndBlended(with:radius:)` | same 12 inputs | 3 nil, 9 valid |
| 5 | `OCCTShapeGlue` | `Shape.glue(_:_:tolerance:)` | touching, identical, disjoint, overlapping, contained boxes; tolerance 1000 and -1; null first, second, both; emptied; empty compounds | 3 nil, 9 valid |
| 6 | `OCCTShapeUnion` | `none (C function only, no Swift caller); probed through union(_:) which shares BRepAlgoAPI_Fuse` | identical, disjoint, contained, containing, touching face/edge/vertex, null first/second/both, emptied, empty compounds, face vs box | 4 nil, 9 valid |
| 7 | `OCCTShapeSubtract` | `none directly; reached via drilled(at:direction:radius:depth:) and probed through subtracting(_:)` | same 13 pairs, plus drill depth 0, radius 1000, hole missing the box, null base | 4 nil, 13 valid |
| 8 | `OCCTShapeIntersect` | `none (C function only); probed through intersection(_:)` | same 13 pairs | 3 nil, 10 valid |
| 9 | `OCCTShapeChamferTwoDistances` | `chamferedTwoDistances(_:)` | one edge and all 12 edges; d1,d2 of 0.001, 5, 10, 11, 1e6, 0, -1, (1,50), NaN; edge 99; non-adjacent face; null; sphere | 18 nil, 4 valid |
| 10 | `OCCTShapeChamferDistAngle` | `chamferedDistAngle(_:)` | one edge and all edges; distance 0.001 to 1e6, 0, NaN; angle 0, 0.001, 89.99, 90, 180, -10; edge 99; null | 23 nil, 5 valid |
| 11 | `OCCTFace2DFillet` | `fillet2D(vertexIndices:radii:)` | 20 mm square, one and four vertices; radius 0, -1, 0.001, 9.9, 10, 10.1, 1000, 1e9, NaN; vertex 99; null; solid; sliver triangle; circle face | 14 nil, 9 valid |
| 12 | `OCCTFace2DChamfer` | `chamfer2D(edgePairs:distances:)` | same distances; non-adjacent pair; edge 99; null; solid | 9 nil, 13 valid |
| 13 | `OCCTShapeFillet` | `filleted(radius:)` | box, sphere, cylinder, cone, null, emptied, face, empty compound; radius 0, -1, 0.001, 4.9, 5, 5.1, 100, 1e9, NaN | 66 nil, 6 valid |
| 14 | `OCCTShapeChamfer` | `chamfered(distance:)` | same 72 inputs | 63 nil, 9 valid |
| 15 | `OCCTShapeCreateRevolutionFromCurve` | `Shape.revolution(meridian:axisOrigin:axisDirection:angle:)` | segment on and off the axis; angle 2pi, 0, 1e-12, -1, 1e6, NaN; zero axis; the axis line itself; 1e-9 circle | 1 nil, 14 valid |
| 16 | `OCCTShapeExtrudeSemiInfinite` | `extrudedSemiInfinite(direction:infinite:)` | face, box, null, empty compound; direction zero, 1e-12, NaN, in-plane, 1e300 | 12 nil, 5 valid, 4 hang (NaN, 1e300): #3100 |
| 17 | `OCCTShapeCreateRevolution` | `Shape.revolve(profile:axisOrigin:axisDirection:angle:)` | wire on the axis, off the axis, crossing it, perpendicular through it, collinear polygon, collapsed polygon; the six angles; zero axis | 2 nil, 14 valid, 1 constructor refusal |
| 18 | `OCCTShapeCreateExtrusionInfinite` | `extrudedInfinite(direction:infinite:)` | face, box, null, empty compound; the five directions | 8 nil, 5 valid, 4 hang (NaN, 1e300): #3100 |
| 19 | `OCCTShapeCreateExtrusionShape` | `extruded(by:)` | face, box, null, emptied solid, empty compound; vector zero, 1e-12, NaN, in-plane, 1e300 | 12 nil, 7 valid, 2 hang (zero, NaN on a face): #3100 |
| 20 | `OCCTShapeCreateRevolutionFull` | `revolved(axisOrigin:axisDirection:)` | null, zero axis, box clear of and across the axis, face on the axis, empty compound | 4 nil, 2 valid |
| 21 | `OCCTShapeCreateRevolutionPartial` | `revolved(axisOrigin:axisDirection:angle:)` | face off the axis with the six angles; null; empty compound | 1 nil, 7 valid |
| 22 | `OCCTShapeMiddlePath` | `middlePath(start:end:)` | opposite faces, adjacent, same face, cylinder end faces in four orders, unrelated faces, sphere, null base, null ends, empty compound | 6 nil, 3 valid, 3 SIGSEGV (same face, adjacent faces, null ends): #3098 |
| 23 | `OCCTShapeCreatePipeSweep` | `Shape.sweep(profile:along:)` | circle along a line; collinear profile; profile equal to the path; collapsed path; 1e-9 path; collapsed profile; 1e-9 circle; radius larger than the bend; parallel profile; closed path; self-crossing path | 3 nil, 7 valid, 1 constructor refusal |
| 24 | `OCCTShapeCreateLoft` | `Shape.loft(profiles:solid:)` | 14 profile sets (coincident, single, none, collapsed, collinear, tiny, twisted, rect to circle, perpendicular, same segment, open then closed, huge circle), solid and shell | 10 nil, 12 valid, 4 constructor refusals |
| 25 | `OCCTShapeCreateLoftAdvanced` | `Shape.loft(profiles:solid:ruled:firstVertex:lastVertex:)` | the same 14 sets, smooth and ruled, solid and shell; vertex cases | 15 nil, 31 valid, 2 SIGSEGV (single profile, ruled false): #3099 |
| 26 | `OCCTShapeNonUniformScale` | `nonUniformScaled(sx:sy:sz:)` | box, sphere, face, null; scales 0 (one and all), -1, NaN, inf, 1e-300, 1e300, 2/3/4; emptied; empty compound; cylinder with z 0 and 1e-9 | 9 nil, 31 valid |
| 27 | `OCCTShapeAddLinearRib` | `addingLinearRib(profile:direction:draftDirection:fuse:)` | degenerate directions and profiles on the box top (107 nil), then the success path reached with 4 profile placements x 4 directions x 3 draft directions x fuse (9 valid), plus tiny, huge and cut-through directions | 107 nil, 9 valid, 1 constructor refusal |
| 28 | `OCCTShapeAddRevolutionForm` | `addingRevolutionForm(profile:axisOrigin:axisDirection:height1:height2:fuse:)` | heights 0, negative, 1e6, NaN, tiny, 50; zero axis; axis through the profile; null; success path on a stepped cylinder | 42 nil, 16 valid |
| 29 | `OCCTShapeDraftPrism` | `addingDraftPrism(profile:sketchFaceIndex:draftAngle:height:fuse:)` | angles 0, 5, 45, 80, 89, 90, -5, NaN; heights 0, -5, 1000; every sketch face 0 to 5, 99, -1; profile off the face, larger than it, collinear; null; cylinder | 6 nil, 25 valid, 2 hang (NaN): #3100 |
| 30 | `OCCTShapeDraftPrismThruAll` | `addingDraftPrismThruAll(profile:sketchFaceIndex:draftAngle:fuse:)` | angles 0, 5, 45, 80, 90, -5, NaN from the top and the bottom face; profile off the face; null | 11 nil, 15 valid, 4 hang (NaN): #3100 |
| 31 | `OCCTShapeRevolFeature` | `addingRevolvedFeature(profile:sketchFaceIndex:axisOrigin:axisDirection:angle:fuse:)` | angles 360, 0, 90, -90, 1e-9, 1e6, NaN; axis through the profile; zero axis; profile outside or inside the base; every sketch face, 99, -1; null | 5 nil, 23 valid, 2 hang (NaN): #3100 |
| 32 | `OCCTShapeRevolFeatureThruAll` | `addingRevolvedFeatureThruAll(profile:sketchFaceIndex:axisOrigin:axisDirection:fuse:)` | ok, zero axis, axis through the profile, profile outside; every sketch face, 99, -1; null | 5 nil, 11 valid |
| 33 | `OCCTShapeFromMesh` | `Shape.fromMesh(points:triangles:)` | empty, no triangles, one triangle, coincident, collinear, repeated index, index 0, 9, -1, duplicate triangles, tetrahedron, flat tetrahedron, all-degenerate, 1e300, NaN | 4 nil, 11 valid, 1 hang (NaN point): #3100 |
| 34 | `OCCTShapeCreateExtrusion` | `Shape.extrude(profile:direction:length:)` | rectangle and collinear polyline; zero direction; length 0, -5, NaN, 1e-12, 1e300; in-plane direction | 4 nil, 6 valid, 4 hang (length 0, NaN): #3100 |
| 35 | `OCCTGeomFillConstrained` | `constrainedFill(edge1:edge2:edge3:edge4:maxDegree:maxSegments:)` | triangle, square, one edge three or four times, collinear, disconnected, stacked circles, degrees 0, 1, 1000, -1 | 2 nil, 10 valid |

A "constructor refusal" is a degenerate wire the Swift `Wire` constructor itself returned nil for, so the
bridge was never reached (printed as `INPUT-REFUSED`).

## Re-run

```
Scripts/repro/3079-done-but-null/run.sh                 # all cases, about 15 minutes with CASE_TIMEOUT=20
CASE_TIMEOUT=20 Scripts/repro/3079-done-but-null/run.sh OCCTShapeMiddlePath   # one function
```

`run.sh` builds `probe/`, a separate package depending on OCCTSwift by path (the root manifest is
untouched, the released kernel asset resolves, no `Libraries/` needed), and runs every case in its own
process so a crash is one line. `probe/.build/out/Products/Debug/probe --list` names the cases and
`probe <case>` runs one. Output is `transcript.txt`: one line per case (`nil`, `VALID ...`,
`NULL-WRAPPED`, `CRASH(exit n)`, `TIMEOUT`, `INPUT-REFUSED`) and a per-function count at the end.
