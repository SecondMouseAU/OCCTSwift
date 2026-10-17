# #3477: a declared string length makes OCCT allocate by a number the file made up

`interpose.c` logs every `malloc`/`calloc`/`realloc` of 8 MiB or more with a backtrace. Run it
against `Scripts/repro/3330/probe.mm` (which opens a file through `TDocStd_Application::Open` with
the bridge guards absent) on the macOS slice of `v4.0.0-kernel.7`:

```bash
clang -dynamiclib -o $WORK/interpose.dylib Scripts/repro/3477/interpose.c
K=<unzipped kernel.7>/OCCT.xcframework/macos-arm64
clang++ -std=c++17 -ObjC++ -w -I $K/Headers -L $K -lOCCT-macos -framework Foundation \
  -framework AppKit -lz -lc++ Scripts/repro/3330/probe.mm -o $WORK/probe
DYLD_INSERT_LIBRARIES=$WORK/interpose.dylib $WORK/probe file.xbf
```

Measured 2026-10-17 over the eight `OCAFMalformedKernelReadTests.emptyAndText` inputs in `.xbf`,
`.cbf` and `.dat`: only `"BINFILE"` followed by the byte values 0...255 allocates, once per
extension, `calloc(993671481)`:

```
Standard::Allocate
FSD_BinaryFile::ReadString(TCollection_AsciiString&)        // the FILE* overload
FSD_BinaryFile::ReadInfo
Storage_HeaderData::Read
PCDM_ReadWriter::FileFormat(TCollection_ExtendedString const&)
CDF_Application::CanRetrieve
TDocStd_Application::Open
```

`993671481 - 1` is `0x3B3A3938`, the little-endian int at file offset 63: 7 bytes of magic, thirteen
header ints, the object count, then the first string's length. `(length + 1) * unit` is allocated
before `fread`. The all-0xFF and `BINFILE\n` + 0xFF inputs named in the issue read a length of -1,
which skips the allocation; they are not the trigger. On wasm32 the same request fails with
`Standard_MMgrRaw::Allocate(): malloc failed` (twice, for `.xbf` and `.cbf`) and every later
allocation fails with it.
