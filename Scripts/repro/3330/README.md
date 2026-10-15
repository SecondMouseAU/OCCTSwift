# #3330: malformed OCAF files against the kernel's own readers

`probe.mm` opens files through `TDocStd_Application::Open` with the bridge's #3318 guard absent.
`gen.py` writes the corpus (1586 files: every prefix of the first 400 bytes plus a stride, a real
header followed by 0xFF or 0x00, byte flips, a document under the wrong extension) and `run.sh`
walks it, restarting after each fault.

```bash
clang++ -std=c++17 -ObjC++ -w -I Libraries/OCCT.xcframework/macos-arm64/Headers \
  -L Libraries/OCCT.xcframework/macos-arm64 -lOCCT-macos -framework Foundation -framework AppKit \
  -lz -lc++ Scripts/repro/3330/probe.mm -o $WORK/probe
WORK=$WORK python3 Scripts/repro/3330/gen.py
WORK=$WORK bash Scripts/repro/3330/run.sh $WORK/probe
```

Measured 2026-10-15 on the macOS slice of `v4.0.0-kernel.6`, then with the three patched
translation units of carried patch `0069` swapped in:

| Kernel | Files | SIGSEGV | Hang (5 s watchdog) |
|---|---|---|---|
| `v4.0.0-kernel.6` | 1586 | 137 | 2 |
| with `0069` | 1586 | 0 | 1 |

The remaining hang is a byte flip in the object count that makes `Storage_InternalData` allocate an
array of billions of handles. It is not a null dereference and `0069` does not touch it.
