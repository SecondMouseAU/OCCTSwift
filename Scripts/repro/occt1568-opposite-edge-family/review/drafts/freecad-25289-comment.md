(Draft, not posted. For FreeCAD#25289, which is linked from OCCT#1568.)

Thanks for the model, it made the cause findable.

What happens: the fillet of the pocket rim at exactly r = 1.5 runs the blend into a vertex where a B-spline
round of the same radius begins, `ChFi3d_Builder::StartSol` returns without an edge and leaves an empty curve
adaptor, and the walk dereferences it. That is the SIGSEGV. It is not specific to FreeCAD.

Proposed for OCCT (draft PR, not yet opened): the crash becomes a clean "no result" (`IsDone() == false`, which
FreeCAD already reports as a failed fillet), and a second, broader change makes fillets on opposite edges
whose radii add up to more than the face width build the intersection of the two rounded profiles instead of
failing, and a single fillet wider than its face pass through the far edge. Both are in the draft with images.

What it does on your model, measured (rim of 8 edges, `blend` as in your script): 1.0, 1.49 and 1.6 build and are
valid; 1.5 (the report) and 1.4999999 are declined instead of crashing. Limit: the exact 1.5 is still
declined, it does not complete "meeting the opposite edge" on this model, and the all 12 edges of your script
stay declined at 1.5 and 1.6 (the four outer edges share corners, which is a different piece of the blend code).
Until OCCT has it, a radius of 1.49 or 1.6 gives a valid result on the rim.

If you can attach a second model where the fillet should meet the opposite edge, it would be useful to try it
against the draft.
