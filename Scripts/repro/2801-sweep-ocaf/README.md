# #2801 sweep: the OCAF integer/real array setters write out of bounds, silently

`probe.mm` + `run.sh`; `transcript.txt` is the run against the **pinned** `v4.0.0-kernel.2` asset
(`OCCT.xcframework.zip` checksum `18b181cc27778520fa2912ac2abb38038800b70e48d2fe1cf7fedcc61414d1c3`).
`run.sh` takes `OCCT_XCFRAMEWORK`, because a developer checkout's `Libraries/OCCT.xcframework` is
often a locally built kernel rather than the pin.

## The two compiled-out links

`TDataStd_IntegerArray.cxx:75`, out-of-line, so absent from the binary:

```cpp
void TDataStd_IntegerArray::Init(const int lower, const int upper)
{
  Standard_RangeError_Raise_if(upper < lower, "TDataStd_IntegerArray::Init");
  Backup();
  myValue = new NCollection_HArray1<int>(lower, upper, 0);
}
```

`TDataStd_IntegerArray.cxx:105`, and the checks it relies on:

```cpp
void TDataStd_IntegerArray::SetValue(const int index, const int value)
{
  if (myValue.IsNull()) { return; }
  if (myValue->Value(index) == value) { return; }   // out-of-bounds READ
  Backup();
  myValue->SetValue(index, value);                  // out-of-bounds WRITE
}
```

`NCollection_Array1::Value` and `::SetValue` do carry `Standard_OutOfRange_Raise_if`, but they are
**inline** members expanded inside `TDataStd_IntegerArray.cxx`, an OCCT translation unit compiled
`-DNo_Exception`, so both are compiled out at that depth. `aPos` is a `size_t`, so a negative index
wraps to a huge offset rather than comparing as negative.

## Reachability, and the asymmetry that proves it was an oversight

`OCCTBridge_Document_Attributes.mm` exposes four entry points per array type. The **getter** tests
`index < attr->Lower() || index > attr->Upper()` before reading. The **setter**, twelve lines above
it in the same file, tests nothing. Same file, same attribute, opposite treatment.

| Swift API | bridge | guard |
|---|---|---|
| `AssemblyNode.integerArrayValue(at:)` | `OCCTDocumentGetIntegerArrayValue` | bounds tested |
| `AssemblyNode.setIntegerArrayValue(at:value:)` | `OCCTDocumentSetIntegerArrayValue` | **none** |
| `AssemblyNode.initIntegerArray(lower:upper:)` | `OCCTDocumentInitIntegerArray` | **none**, `upper < lower` passes straight through |
| the same three for `RealArray` | `...RealArray...` | same split |

The Boolean, Byte, ExtString and Reference array setters take a whole buffer and do bound-check, so
`IntegerArray` and `RealArray` are the only two affected.

## Measured

| mode | call | result |
|---|---|---|
| 0 | `SetValue(1, ...)` on `[1..4]` | correct |
| 1 | `SetValue(5, ...)` | **write succeeds silently**, reads back, in-range contents untouched |
| 2 | `SetValue(0, ...)` | **write succeeds silently** |
| 3 | `SetValue(1000000, ...)` | **write succeeds silently, ~4 MB past a 4-element buffer** |
| 4 | `SetValue(-1000000, ...)` | SIGBUS |
| 5 | `SetValue(INT_MIN+1, ...)` | SIGSEGV |
| 10 | `Set(label, 1, 0)` then `SetValue(1, ...)` | attribute created with `Upper() < Lower()`, then SIGSEGV |
| 11 | `Set(label, 10, 1)` | **SIGSEGV inside `Set` itself** |
| 12 | `Set(label, 0, -1000000)` | SIGSEGV |
| 13 | `Set(label, INT_MAX, INT_MIN)` | survives; `Lower()`/`Upper()` report the nonsense back |
| 21 | `RealArray::SetValue(1000000, ...)` | **write succeeds silently** |
| 22 | `RealArray::SetValue(INT_MIN+1, ...)` | SIGSEGV |

Modes 1, 2, 3 and 21 are the serious half: a **silent out-of-bounds heap write** from a public Swift
API, reported as success. A crash is recoverable information; this is not.

`AssemblyNode.initIntegerArray(lower: 10, upper: 1)` (mode 11) is an immediate uncatchable SIGSEGV
from ordinary-looking `Int32` arguments on a documented call.

## Related

- #2801, the mechanism, and `okf/policies/occt-validation-is-compiled-out.md`.
- #726, the unmeasured-values programme: modes 1 to 3 are its shape applied to a write.
- #345, why the fault is uncatchable in-process.
