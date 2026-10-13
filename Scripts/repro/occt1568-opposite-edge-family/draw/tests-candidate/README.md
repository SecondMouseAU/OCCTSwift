# tests-candidate

The DRAW case scripts of this directory's parent, converted where mechanical to the upstream idiom (`explode`, `blend`, `checkshape`, `checkprops -v`, `checknbshapes`), one case per file, so that they could drop into `tests/blend/simple` or `tests/bugs/modalg_7`. Each keeps a `fam_verdict` block that prints the `FAMILY` line `run-all.py` reads; under `testgrid` the block is skipped (no `common.tcl`).

Run with the runner: `run-all.py --build <draw-build> tests-candidate/*.tcl`.

| file | label | expectation |
| --- | --- | --- |
| `pr2_q1_3_3.tcl` | `pr2.q1.3_3` | valid |
| `pr2_q1_2_5_3.tcl` | `pr2.q1.2.5_3` | valid |
| `pr2_q1_1_3_5.tcl` | `pr2.q1.1_3.5` | valid |
| `pr2_q1_0_5_3_9.tcl` | `pr2.q1.0.5_3.9` | valid |
| `pr2_q1_2_2_2_2.tcl` | `pr2.q1.2.2_2.2` | valid |
| `pr2_row2.tcl` | `pr2.row2` | valid |
| `pr2_q2_atmonce.tcl` | `pr2.q2.at-once` | valid |
| `pr2_q6_2_2.tcl` | `pr2.q6.2_2` | valid |
| `pr2_q6_2m1em8.tcl` | `pr2.q6.2-1e-8` | valid |
| `pr2_q6_singlem4.tcl` | `pr2.q6.single-4` | valid |
| `pr2_row5_d1em9.tcl` | `pr2.row5.d1e-9` | valid_or_refused |
| `pr2_row5_d2em8.tcl` | `pr2.row5.d2e-8` | valid_or_refused |
| `pr2_row5_d1em7.tcl` | `pr2.row5.d1e-7` | valid_or_refused |
| `pr2_row5_d1em5.tcl` | `pr2.row5.d1e-5` | valid_or_refused |
| `pr2_row5_d2em4.tcl` | `pr2.row5.d2e-4` | valid_or_refused |
| `pr2_i3428_r1_999999.tcl` | `pr2.i3428.r1.999999` | valid |
| `pr2_i3428_r2.tcl` | `pr2.i3428.r2` | valid_or_refused |
| `pr2_i3428_r3.tcl` | `pr2.i3428.r3` | refused |
| `pr3_q3_r4_5.tcl` | `pr3.q3.r4.5` | valid |
| `pr3_q3_r5.tcl` | `pr3.q3.r5` | valid |
| `pr3_q3_r6.tcl` | `pr3.q3.r6` | valid |
| `pr3_row3.tcl` | `pr3.row3` | valid |
| `pr3_q4_r100.tcl` | `pr3.q4.r100` | valid |
| `pr3_q5_7_5.tcl` | `pr3.q5.7_5` | valid |

## Not converted

- **pr1.rim-1.5, pr1.all12-1.5, pr3.row7**: need model-1568.brep, the model of OCCT#1568 (a data file, restore [locate_data_file ...]); the data file would have to be added to the data set.
- **pr2.q2.sequence**: the second fillet's edge is found on the result of the first by position (fam_edge_at); explode names of a filleted shape are not stable, so the case needs the helper.
- **pr2.row6.first / .second**: same: the second fillet's edge is found on the result of the first by position.
- **pr1 crash itself**: DRAW converts the SIGSEGV of StartSol to an exception (OCC_CONVERT_SIGNALS), so no DRAW test can show the crash; the GTest or the C++ probe does.
