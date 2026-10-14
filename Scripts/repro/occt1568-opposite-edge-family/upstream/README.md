# Patch series v2 for upstream OCCT `IR`

`git format-patch` of branch `integration/ir-fillet-1568-v2` (OCCT worktree `/Users/elb/Projects/worktrees/occt-ir-fillet-1568`)
on upstream `IR` 88cc61507. Nothing is posted and no PR is open.

Apply in file order with `git am`. Proposed PR split:

| patch | commit | PR |
| --- | --- | --- |
| 0001 | `StartSol` drops an obstacle it found no edge for | PR1 |
| 0002 | fillets whose arcs cross are no longer taken for a touching pair | PR2 |
| 0003 | builds fillets on opposite edges whose arcs cross | PR3 |
| 0004 | builds a fillet wider than its face | PR3 |
| 0005 | `BRepTools_WireExplorer`: a pcurve too short to step along ends the exploration | PR2 |
| 0006 | `Compute`: a result that is not a valid solid is a failure (needs 0005) | PR2 |
| 0007 | `tests/blend/simple/H8` and `tests/blend/buildevol/D8` expect the refusal | PR2 |

Dependencies, measured by applying each subset to clean IR and running the 43 fillet and WireExplorer GTests one
process each: PR1 and PR2 are independent; 0006 needs 0005; 0003 needs 0002 and (for its tolerance case) 0006; 0004
needs 0003. Details in the review drafts (`drafts-v2/upstream-pr-description.md`).

Commits 0005 to 0007 carry a `Co-Authored-By` trailer; strip it if it is not wanted upstream.
