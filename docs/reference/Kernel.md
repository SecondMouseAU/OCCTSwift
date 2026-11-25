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

## The LTS preview (v4.0.0-lts.1)

`v4.0.0-lts.1` is the first preview of the `vanilla` flavour. It pins the `kernel-8.0.2` pre-release: `V8_0_2` exactly as Open Cascade tagged it, with no carried patch on macOS and iOS, and with only the 11 WASI port patches on wasm. Its `Kernel.flavour` is `.vanilla`, its `Kernel.occtVersion` is `"8.0.2"`, and it holds 9 of the 60 ledger fixes (`Kernel.hasFix("F0019")` is `true`, `Kernel.hasFix("F0080")` is `false`). The hardened kernel, with its 51 carried patches, stays the default and is what `v4.0.0` ships. A range such as `from: "4.0.0"` never resolves a pre-release, so a consumer of the preview pins it exactly, with `.package(url: "https://github.com/SecondMouseAU/OCCTSwift", exact: "4.0.0-lts.1")`.

Beyond what the `vanilla` row above already says, the preview does not promise:

- **No ThreadSanitizer-clean claim.** The 14 thread-safety patches are absent.
- **Not safe for untrusted BREP, STEP or OCAF input, and no crash-guard promise.** The damaged-input and crash-guard patches are absent.
- **The retired guards are not reinstated.** The bridge guards retired at earlier repins because the hardened kernel holds the fix are still gone: the surface-less clause at the two Boolean-check sites (#3533), the analyzer guards (#3503), the datum lookup guard (#1030) and the bridge arc-length subdivision (#603). A call that those guards refused can fault or run long on this kernel.
- **No full test run.** The test suite has not been run against this kernel, so a test that assumes a carried patch can fail, or end its process, on it.

It is a preview. The mechanism that will carry the LTS flavour after `v4.0.0` is not decided, and this tag may be superseded by it.

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
