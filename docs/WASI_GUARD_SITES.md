# WASI Build Guard Sites Documentation

This document lists all locations in OCCT source code that require `#ifdef __wasi__` guards for WASI compatibility.

## Current Status

| File | Function/Location | Missing API | Status |
|------|------------------|-------------|--------|
| `src/FoundationClasses/TKernel/OSD/OSD_Chronometer.cxx` | `GetProcessCPU()` | `times()`, `struct tms` | ✅ Patched (needs emulation flags) |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `Build()` | `umask()` | ✅ Patched |
| `src/FoundationClasses/TKernel/OSD/OSD_Directory.cxx` | `BuildTemporary()` | `mkdtemp()` | ✅ Patched |
| `src/FoundationClasses/TKernel/OSD/OSD_Environment.cxx` | (global) | `std::mutex`, `std::lock_guard` | ❌ Needs patch |
| `src/FoundationClasses/TKernel/OSD/OSD_File.cxx` | (multiple) | `mkstemp()`, `fcntl` locking | ❌ Needs patch |

## Required CMake Flags

Add to CMake configuration for WASI builds:
```cmake
-DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID"
-DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID"
-DCMAKE_EXE_LINKER_FLAGS="${CMAKE_EXE_LINKER_FLAGS} -lwasi-emulated-process-clocks -lwasi-emulated-getpid"
```

## Guard Sites Detail

### 1. OSD_Chronometer.cxx - GetProcessCPU()
**Lines ~53-70** (original source)
```cpp
void OSD_Chronometer::GetProcessCPU(double& theUserSeconds, double& theSystemSeconds)
{
#if defined(__linux__) || defined(__FreeBSD__) || defined(__ANDROID__) || defined(__QNX__) \
    || defined(__EMSCRIPTEN__)
  static const long aCLK_TCK = sysconf(_SC_CLK_TCK);
#else
  static const long aCLK_TCK = CLK_TCK;
#endif

#ifdef __wasi__
  theUserSeconds = theSystemSeconds = 0.0;
#else
  tms aCurrentTMS{};
  times(&aCurrentTMS);
  theUserSeconds   = (double)aCurrentTMS.tms_utime / aCLK_TCK;
  theSystemSeconds = (double)aCurrentTMS.tms_stime / aCLK_TCK;
#endif
}
```
**Also needs:** `times()` stub at top of file (after CLK_TCK define)
```cpp
#ifdef __wasi__
// WASI doesn't have times() or struct tms
static clock_t times(struct tms *buf) {
  return 0;
}
#endif
```

### 2. OSD_Directory.cxx - Build()
**Lines ~107-110** (original source)
```cpp
myPath.SystemName(aBuffer);
#ifdef __wasi__
  // WASI doesn't have umask
#else
  umask(0);
#endif
int aStatus = mkdir(aBuffer.ToCString(), anInternalProt);
```

### 3. OSD_Directory.cxx - BuildTemporary()
**Lines ~155-165** (original source)
```cpp
#ifdef __wasi__
  // WASI doesn't have mkdtemp, use a simple random name
  static int counter = 0;
  char aTmpName[64];
  snprintf(aTmpName, sizeof(aTmpName), "/tmp/occt_%d_%d", getpid(), counter++);
  if (mkdir(aTmpName, 0700) != 0)
#else
  char aTmpName[] = "/tmp/CSFXXXXXX";
  if (nullptr == mkdtemp(aTmpName))
#endif
  {
    return OSD_Directory(); // can't create a directory
  }
```

### 4. OSD_Environment.cxx - Global mutex usage
**Lines ~137-138** (original source)
```cpp
static std::mutex           aMutex;
std::lock_guard<std::mutex> aLock(aMutex);
```
**Guard needed:** Wrap mutex usage or use WASI-compatible synchronization.

### 5. OSD_File.cxx - Multiple locations
- **Line ~767:** `mkstemp(aTmpName)` - temporary file creation
- **Lines ~1394-1404:** `F_WRLCK`, `F_RDLCK`, `F_SETLKW`, `F_UNLCK`, `F_SETLK` - file locking
- **Line ~1509-1510:** `F_UNLCK`, `F_SETLK` - file unlocking

All need `__wasi__` guards with alternative implementations or stubs.

## Patch Files

Current patches in `Scripts/patches/`:
- `wasi-osd-chronometer.patch` - Guards for OSD_Chronometer
- `wasi-osd-directory.patch` - Guards for OSD_Directory

## Next Steps

1. Create patches for OSD_Environment.cxx (mutex)
2. Create patches for OSD_File.cxx (mkstemp, fcntl locking)
3. Add emulation flags to build script CMake configuration
4. Test full build to identify any remaining guard sites

## Build Command

```bash
./Scripts/build-occt-wasm.sh
```

Output artifacts:
- `Libraries/libOCCT-wasm.a` - Combined static library
- `Libraries/occt-headers-wasm/` - Headers for SwiftPM linking