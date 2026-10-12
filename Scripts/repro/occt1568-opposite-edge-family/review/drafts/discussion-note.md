(One paragraph for the later Discussion post. Not posted; needs the go on the text.)

While chasing #1568 we found that IR currently reports `IsDone()` for fillets on opposite edges whose arcs cross
and returns a solid BRepCheck rejects (a 4 x 10 x 6 box with 3 and 3 gives a volume of 315 for 240), and that the
crash in #1568 is one missing `Nullify`. We have a series of five small commits with GTests that fixes those,
builds the intersection of the rounded profiles for opposite fillets and the pivot arc for a fillet wider than
its face, with images of the break and the fix, and a validated oracle for every built case (715 box cases, no
regression). Behind it there is a plan for the larger set of open fillet and chamfer issues (corners, curved
faces, concave edges, chamfers past their face, history), in the order we would do them. We would like to do
that work upstream and would like to know first which parts the maintainers want, in which order, and how
large a PR they will take.
