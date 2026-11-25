---
title: Kernel flavour
parent: API Reference
---

# Kernel flavour

`Kernel` says which OCCT kernel this build links against and which defects it holds a fix for. OCCTSwift ships its kernel in two flavours, so a program, or a test, sometimes needs to ask.

| Flavour | What it is | What it promises |
|---|---|---|
| `carry` | OCCT plus the patches in `Scripts/patches` (the default) | The quality guarantee: the shared state the thread-safety patches fix is serialised, damaged input is refused, crash guards hold, and the answer-changing fixes apply |
| `vanilla` | OCCT exactly as Open Cascade tagged it (the LTS kernel) | A provenance guarantee: any defect is upstream's. No ThreadSanitizer-clean claim, not safe for untrusted BREP, STEP or OCAF input, no crash-guard promise |
| `unlabelled` | A kernel built before the kernel-fix ledger | Nothing: it does not say what it holds |

The ledger the answers come from is [`Scripts/kernel-fixes.tsv`](../../Scripts/kernel-fixes.tsv); the rules for guards and tests that name one of its rows are in [`okf/policies/kernel-fix-ledger.md`](../../okf/policies/kernel-fix-ledger.md).

## Topics

- [Kernel.flavour](#kernelflavour) · [Kernel.occtVersion](#kernelocctversion) · [Kernel.hasFix(_:)](#kernelhasfix_)

---

### `Kernel.flavour`

Which kernel this build links against.

```swift
public static var flavour: Kernel.Flavour { get }
```

- **Returns:** `.carry`, `.vanilla`, or `.unlabelled`.
- **OCCT:** none. Read from the `OCCTKernelFixes.h` header the kernel build generated into the xcframework.
- **Example:**
  ```swift
  switch Kernel.flavour {
  case .carry: print("hardened kernel")
  case .vanilla: print("upstream kernel")
  case .unlabelled: print("kernel predates the ledger")
  }
  ```

### `Kernel.occtVersion`

The OCCT version the kernel was built from.

```swift
public static var occtVersion: String { get }
```

- **Returns:** such as `"8.0.2"`, or `"unknown"` for an unlabelled kernel.
- **Example:**
  ```swift
  print(Kernel.occtVersion)
  ```

### `Kernel.hasFix(_:)`

Whether the kernel holds the fix for one row of the ledger.

```swift
public static func hasFix(_ id: String) -> Bool?
```

- **Parameters:** `id`, a ledger id such as `"F0080"`.
- **Returns:** `true` when the kernel holds the fix, `false` when it is known to lack it, and `nil` when it cannot say: an id its ledger has no row for, or any id asked of an unlabelled kernel. `nil` is not `false`.
- **Example:**
  ```swift
  if Kernel.hasFix("F0080") == false {
      // this kernel can crash on a face with no surface; keep the bridge's own check
  }
  ```
