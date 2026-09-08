---
title: IOStatus
parent: API Reference
---

# IOStatus

Why a STEP or IGES read, transfer or write ended the way it did: OCCT's own
`IFSelect_ReturnStatus`, surfaced instead of collapsed to a `Bool`.

Until #1644 every data-exchange entry point in the bridge ended in
`if (status != IFSelect_RetDone) return false;`, which is one bit of a five-valued answer, so a
missing file, a corrupt file, an empty model and an unwritable destination all reached Swift as
the same `nil` or the same `ExportError.exportFailed(String)`. `IOStatus` is that answer, and
three error cases carry it: `ImportError.readFailed(path:status:)`,
`Exporter.ExportError.writeFailed(path:status:)` and `DocumentError.exchangeFailed(url:status:)`.

## Topics

- [The cases](#the-cases) · [Where it comes from](#where-it-comes-from) ·
  [What each failure actually reports](#what-each-failure-actually-reports) ·
  [Members](#members)

---

## The cases

```swift
public enum IOStatus: Int32, Sendable, CaseIterable {
    case notReached = -1
    case void = 0
    case done = 1
    case error = 2
    case fail = 3
    case stop = 4
}
```

| Case | OCCT | Meaning |
|---|---|---|
| `notReached` | none | The call failed before OCCT produced a status: a rejected argument, a null handle, a caught C++ exception, or a format whose writer has no status to give. |
| `void` | `IFSelect_RetVoid` | Nothing to do. The step ran and found no content. |
| `done` | `IFSelect_RetDone` | Success. |
| `error` | `IFSelect_RetError` | Bad input. The file is not what it claims to be. |
| `fail` | `IFSelect_RetFail` | The step ran and failed. |
| `stop` | `IFSelect_RetStop` | Interrupted. |

The case names are OCCT's, not a translation. `error` and `fail` are near-synonyms in English and
a real distinction here, so renaming them would invent a meaning the kernel does not have.

## Where it comes from

The bridge's `OCCTReturnStatus` mirrors `IFSelect_ReturnStatus`' own ordinals, and
`OCCTBridge_Internal.h` `static_assert`s each one against the OCCT constant, so a kernel repin
that renumbers or reorders that enum fails the compile rather than silently relabelling every
status the bridge reports.

Thirty-three bridge entry points take a trailing `OCCTReturnStatus* _Nullable outStatus`; passing
`NULL` is exactly the behaviour they had before #1644, which is what the counting entry points
(`Shape.stepRootCount`, `Shape.igesShapeCount` and their siblings) still do.

## What each failure actually reports

Measured against the pinned kernel, not read off the header's ordering. Two of these contradict
the reading #1644 started from:

| What you did | Status |
|---|---|
| `Shape.loadSTEP` on a path that does not exist | `.error` |
| `Shape.loadSTEP` on a file that is not STEP | `.fail` |
| `Shape.loadSTEP` on a well-formed STEP file with an empty `DATA` section | `.done` |
| `Exporter.writeSTEP` to a directory that does not exist | `.stop` |
| `Exporter.optimizeSTEP` on a file that is not STEP | `.fail` |

A **missing** file is `.error` while a **corrupt** one is `.fail`, and a valid STEP file holding no
data reads as `.done`: its emptiness surfaces downstream as zero transferred roots, not as
`IFSelect_RetVoid`.

## Members

### `IOStatus.description`

`CustomStringConvertible` conformance: a short phrase naming the OCCT constant and what it means,
so a log line reads on its own.

```swift
public var description: String { get }
```

- **Returns:** e.g. `"IFSelect_RetError: bad input, the file is not what it claims to be"`.
- **Example:**
  ```swift
  do {
      let shape = try Shape.loadSTEP(fromPath: path)
      print(shape.volume)
  } catch ImportError.readFailed(let path, .error) {
      print("\(path): check the path, OCCT could not open it")
  } catch ImportError.readFailed(let path, .fail) {
      print("\(path): opened, but this is not a STEP file")
  } catch ImportError.readFailed(let path, let status) {
      print("\(path): \(status)")
  }
  ```

---

## Related

- [`Exporter`](Exporter.md), whose `ExportError.writeFailed(path:status:)` carries this.
- [`Document`](Document.md), whose `DocumentError.exchangeFailed(url:status:)` carries this.
- [`Shape`](Shape.md), whose STEP and IGES loaders throw `ImportError.readFailed(path:status:)`.
