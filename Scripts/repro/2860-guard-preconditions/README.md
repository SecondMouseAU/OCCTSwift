# #2860 / #2857: the preconditions the bridge guards are built on

The sweep probes prove the defects: [`../2801-sweep-math/`](../2801-sweep-math/) for #2860's fifteen
modes and [`../2801-sweep-index/`](../2801-sweep-index/) for #2857's eight. This one measures the
four things a guard author needs and cannot read off a signature. `probe.mm` + `run.sh`;
`transcript.txt` is the run against the **pinned** `v4.0.0-kernel.2` asset (`OCCT.xcframework.zip`
checksum `18b181cc27778520fa2912ac2abb38038800b70e48d2fe1cf7fedcc61414d1c3`). A developer checkout's
`Libraries/OCCT.xcframework` is often a locally built kernel one repin behind, so `run.sh` takes
`OCCT_XCFRAMEWORK`; point it at the downloaded asset.

## 1. Both inline-buffer thresholds, so a test can sit either side of each

`math_DoubleTab` inlines 64 doubles (`math_DoubleTab.hxx:33`) and `math_VectorBase` inlines 32
(`math_VectorBase.hxx:63`). Neither type exposes which storage it chose, so mode `thresholds`
measures it directly: it takes the address of element `(1,1)` and asks whether that address lies
inside the object's own footprint.

| container | elements | inlined |
|---|---|---|
| `math_Matrix` 3x2 | 6 | yes |
| `math_Matrix` 2x32 | 64 | yes, exactly at the threshold |
| `math_Matrix` 2x33 | 66 | no |
| `math_Matrix` 100x1 | 100 | no |
| `math_Vector` | 31, 32 | yes |
| `math_Vector` | 33 | no |

`sizeof(math_Matrix)` is 576 and `sizeof(math_Vector)` is 296, so an overrun that stays inside the
inlined buffer scribbles inside the object and hands back a plausible number **forever**, while the
same defect one element larger runs off a heap block and faults. That is why every test for this
cluster asserts the refusal rather than the absence of a crash, and why each one carries a case on
both sides: `3x2` returning a determinant of `-1` and `4x2` Uzawa returning `IsDone() == true` were
only findable this way.

## 2. A negative-dimension `math_Matrix` constructs, so the accessors can carry the guard

`math_Matrix(1, -5, 1, -5, 7.0)` builds without complaint and reports `RowNumber() == -5`
(mode `negative-dims`, exit 0). So `OCCTMathMatrixCreate` needs no refusal channel of its own: every
accessor bounded by the reported counts refuses every index of such a matrix, which is the branch
#2860's fix shape permits ("document it and make every accessor refuse on it") and leaves
`MathMatrix.init(rows:cols:initialValue:)` non-failable.

Mode `zero-dims-accessors` is the reason the squareness predicate is not `RowNumber() ==
ColNumber()` alone. A 0x0 satisfies that, and `Determinant()` on it **returns 1**: a confident
answer for a matrix with no entries. `Transpose()` and `Invert()` also return normally. So the
predicate is `RowNumber() >= 1 && RowNumber() == ColNumber()`.

## 3. `math_Uzawa` either side of the 32, and why the build flag would not fix it

`math_Uzawa.cxx:47` sizes `Errinit(1, Cont.ColNumber())` and `:101`/`:104` write `Errinit(i)` for
`i = 1..Cont.RowNumber()`. The constructor's own `Standard_DimensionError_Raise_if` at `:94` tests
`Secont.Length()` and `Nce + Nci` against `Nlig` and **relates rows to columns nowhere**, so
restoring it would not catch this; `math_Uzawa.cxx` additionally `#define`s
`No_Standard_OutOfRange` and `No_Standard_DimensionError` itself at `:27-29`, so even a Debug kernel
has no check underneath. The precondition is therefore derived, not restored:
`nConstraints <= nVars`.

| `nConstraints` x `nVars` | `Errinit` | result |
|---|---|---|
| 32 x 32 | inlined, written in bounds | exit 0, `IsDone = 1`, `Value(1) = 0.114286`, the control |
| 33 x 32 | inlined, written one past | exit 0, `IsDone = 1`, `Value(1) = -0.0234375` |
| 40 x 33 | on the heap, written 7 past | exit 0, `IsDone = 1`, `Value(1) = 0` |
| 100 x 2 | inlined, written 68 past | **SIGSEGV** (`../2801-sweep-math/`) |

The three exit-0 rows are the argument for a value guard rather than a crash-shaped test: two of them
return a number, and which of the four outcomes a given size produces is address-space luck.

## 4. `gp_Mat::Determinant()` is the guard predicate, so it is measured

`gp_Trsf::SetValues` (`gp_Trsf.cxx:366`) refuses `abs(s) < gp::Resolution()` where `s` is
`gp_Mat(col1, col2, col3).Determinant()`. Mode `trsf-determinant` runs that exact test on the inputs
the sweep measured and on inputs it must **not** refuse:

| 3x3 | determinant | refused by the kernel's own test |
|---|---|---|
| all zero | 0 | yes |
| rank 2, row 3 repeats row 2 | 0 | yes |
| identity | 1 | no |
| uniform scale 2 | 8 | no |
| uniform scale 1e-5 | 1e-15 | no |

`gp::Resolution()` is `2.2250738585072014e-308`, so a legitimately tiny uniform scale is nowhere near
it and the guard refuses exactly what `SetValues` would have refused.

## 5. A singular `gp_GTrsf` is already refused, so `OCCTShapeGTrsfModification` gets no guard

#2860's finding 6 names `Shape.gtrsfModification` alongside `Shape.trsfModification`, but the
mechanism it quotes is `gp_Trsf::SetValues`, and the `gp_GTrsf` path never calls it:
`gp_GTrsf::SetValue` carries no determinant requirement and `gp_GTrsf.cxx` holds no `_Raise_if` at
all. Mode `gtrsf-singular` measures what actually happens: a rank-2 vectorial part (z flattened,
determinant 0) raises `Standard_NoSuchObject` out of `BRepTools_Modifier`, exit 3, which is the
bridge's existing `catch (...)` reporting `nullptr`. **So that entry point already refuses
correctly** and adding a predicate there would be a second way to say the same thing. Recorded here
rather than guarded.
