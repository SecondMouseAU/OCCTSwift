# Fillets whose contours share a vertex (#3233): candidate patch 0061

Investigation and candidate only. No PR, nothing reported upstream. Follows patches 0059 and 0060 (`../fillet-pivot-edges/`).
Read `review/index.md` first (the images and the Shapr3D recipes are in the review directory the run writes, by default
`/Users/elb/Projects/worktrees/fillet-3233-review/`, and a copy is committed in `review/`).

What each file is:

- `cdump.cxx`: one process per case. `fillet` runs `BRepFilletAPI_MakeFillet`, `ref` builds the reference with no fillet code (removal
  prisms, cube-minus-ball pieces and a revolved corner profile cut from the base solid), `cmp` does both and the two Boolean differences.
- `cases3233.py`: the 31 configurations, each with its kernel edge list, its reference items and the expected-geometry text.
- `measure.py`: every case against kernel.5, main (0059), this branch (0060) and the candidate (0061) into `results/measure.json`.
- `render3233.py`, `index3233.py`, `steps3233.py`: the review images, `index.md` and `table.tsv`, and the Shapr3D steps.
- `results/`: `measure.json`; the 715-case battery and two 600-case fuzz runs of 0060 against 0061 (none regressed, none newly invalid)
  and the independent grid-volume check of the newly valid ones.

Build the probes by override-linking the changed unit into a copy of the kernel.5 macOS slice (`../fillet-pivot-edges/swap-members.sh`,
unit `BRepFilletAPI/BRepFilletAPI_MakeFillet`) and linking `cdump.cxx` against it; Libraries/OCCT.xcframework must be a copy, never the shared one.
