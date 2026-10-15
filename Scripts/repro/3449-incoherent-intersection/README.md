# #3449: BRepFill_TrimSurfaceTool::IntersectWith reads past a sequence

`./run.sh 0 0 0 0 0 0 0 2 3 0` builds `probe.cpp` unpatched and with patch `0068` override-linked
(`-O2 -DNo_Exception`, the Release kernel's flags) and runs both on a radius-20 circle spine with
the profile `(0,0,0) -> (0,2,3)`, `axeProf` false.

| case | unpatched | patched |
|---|---|---|
| `0 0 0 0 0 0 0 2 3 0` circle wire, profile from the axis | SIGSEGV in `IntersectWith+164` | caught `StdFail_NotDone: incoherent intersection` |
| `0 0 1 0 0 0 0 2 3 0` disk face, profile from the axis | SIGSEGV | caught `StdFail_NotDone` |
| `5 0 0 0 0 0 0 2 3 0` off-axis profile | done=1 | done=1 |
| `0 0 0 0 0 0 0 2 3 1` `axeProf` true | done=1 | done=1 |
| `1 0 0 0 0 0 0 2 3 0` start 1 from the axis | done=1 | done=1 |

## Root cause

`IntersectWith` ends its two `EvalParameters` calls with
`StdFail_NotDone_Raise_if(Points.Length() != Points2.Length(), ...)` and then loops
`i = 1..Points.Length()` over `Points2.Value(i)`. `StdFail_NotDone_Raise_if` is empty under
`No_Exception`, which `CMAKE_BUILD_TYPE=Release` defines, so the kernel never refuses and the loop
reads past the shorter sequence. Compiled without `No_Exception` the same translation unit throws
the documented `StdFail_NotDone`, which is how the earlier probe's "no located fault" read: the
fault is not a null handle, it is a check the build removed. The patch spells the check as a
literal `throw`.
