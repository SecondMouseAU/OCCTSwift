# #1404: `TObj_Application`'s own singleton fields are unsynchronized

Measured against the pinned kernel (OCCT `V8_0_1` plus the carried patches), TSan build in
`Libraries/occt-install-tsan`.

## What races

`TObj_Application::GetInstance()` is a process-wide singleton. Its lazy-init is a C++11
function-local static and is **not** the problem. Two of its own members are:

| Field | Reached by | Race site |
|---|---|---|
| `myIsVerbose` | `SetVerbose()` / `IsVerbose()` | `TObj_Application.hxx:77` |
| `myIsError` | `CreateNewDocument()` | `TObj_Application.cxx:172` |

`CreateNewDocument` writes `myIsError = false`, calls `NewDocument()`, then returns `!myIsError`.
Two concurrent calls interleave that write-call-read on one shared field, so one thread can clear
another's in-flight error signal and a failed creation gets reported as a success.

## This is not one of the already-fixed races

#341, #344, #349, #353, #371 and #374 fixed `XCAFApp_Application`, `CDF_Application`,
`CDM_Application`, `Resource_Manager` and `Storage_Schema`. Their patches (`0012`, `0014`, `0015`,
`0016`) all ship in the pinned kernel and do cover the machinery `NewDocument()` descends into.
`TObj_Application`'s own two fields sit one layer above that and no kernel fix touches them.

#1162's audit table originally cited #344 for this class. That was stale: #344 was a different
class, already fixed, and since eliminated from the bridge entirely by #371.

## Reproducing

```bash
Scripts/tsan-stress.sh build          # once, if Libraries/occt-install-tsan is absent

I=Libraries/occt-install-tsan
inc="$I/include/opencascade"; [ -d "$inc" ] || inc="$I/include"
libs=$(ls $I/lib/libTK*.a | xargs -n1 basename | sed 's/^lib//;s/\.a$//;s/^/-l/')
$(xcrun --find clang++) -std=c++17 -fsanitize=thread -g -O1 -w \
  -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
  -I"$inc" -L"$I/lib" occt_1404_stress.cpp -o /tmp/occt_1404 \
  $libs -lz -lc++ -framework Foundation

MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0:suppressions=Scripts/tsan.supp" \
  /tmp/occt_1404 verbose 8 200
MMGT_OPT=0 TSAN_OPTIONS="halt_on_error=0:suppressions=Scripts/tsan.supp" \
  /tmp/occt_1404 createdoc 8 100
```

Both modes report a data race on a clean tree. Measured output:

```
WARNING: ThreadSanitizer: data race
  Write of size 1 by thread T7:
    #0 TObj_Application::SetVerbose(bool) TObj_Application.hxx:77
  Previous write of size 1 by thread T2:
    #0 TObj_Application::SetVerbose(bool) TObj_Application.hxx:77

SUMMARY: ThreadSanitizer: data race TObj_Application.cxx:172
  in TObj_Application::CreateNewDocument(...)
```

Note `create_failures=0` in the `createdoc` run. The corruption is real but did not surface as a
wrong answer in 800 operations, which is why this needed TSan rather than an assertion to find.

## Why this harness is NOT a gate scenario

It calls the kernel singleton directly, with no bridge in the picture, so it is **expected** to race
and will keep racing after the fix. Adding it to `Scripts/tsan-stress.sh`'s `SCENARIOS` would wire a
permanently-red entry into the gate. That file's own policy excludes exactly this shape, the same
way it excludes #341's `shared_adaptor_cache` and `obj_roundtrip_shared` modes.

The harness is evidence that the defect is real. What verifies the **fix** is
`Scripts/tsan-stress.sh swift` over
`Tests/OCCTThreadTests/Issue1404TObjApplicationThreadSafetyTests.swift`, which reaches the singleton
the way a consumer does, through `tobjApplicationMutex()`.

## The fix

Bridge-side, `tobjApplicationMutex()` in `OCCTBridge_Document_DocumentLifecycle.mm`, held by
`OCCTTObjApplicationSetVerbose`, `OCCTTObjApplicationIsVerbose` and
`OCCTTObjApplicationCreateDocument`. The lock is held across the whole `CreateNewDocument` call
rather than around the field writes, because the window that has to be exclusive is the
write-call-read sequence, not the assignment.

Not a carried kernel patch. The class has no lock of its own, the API is niche, and upstream has no
PR touching `TObj_Application` (checked against `Open-Cascade-SAS/OCCT` before the fix, per
CLAUDE.md's "check upstream's own recent activity first" step). If this is ever upstreamed, the
kernel-side fix is a mutex member on `TObj_Application` or moving both fields to per-call state;
`myIsError` in particular is a return channel that should have been a return value.
