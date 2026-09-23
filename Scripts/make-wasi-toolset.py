#!/usr/bin/env python3
"""Emit the SwiftPM toolset a WASI consumer of OCCTSwift builds with.

WHY THIS EXISTS

`Package.swift` carries no `.unsafeFlags` on the WASI path, because SwiftPM refuses to build any
package that has them once it is resolved by VERSION, which is how an application consumes a
published package. Measured, with `Scripts/repro/2048/run.sh`:

    error: 'consumer': the target 'X' in product 'Y' contains unsafe build flags

A path dependency and a branch dependency are both exempt; a version requirement is not. So a
manifest that needs `-fwasm-exceptions` cannot be depended on, and every flag the wasm build needs
has to arrive from somewhere that is not the manifest.

A toolset is that somewhere. It is the CONSUMER's file, passed as `swift build --toolset <file>`,
and it can carry anything, because the consumer is the one taking the risk. It also happens to be
the right home for these particular flags on their own merits: every one of them names a path or a
property of the machine (where wasi-sdk is installed, where `libOCCT-wasm.a` was put), which is not
something a published manifest could know.

WHAT IS AND IS NOT IN HERE

Only what has no safe spelling. `-lc++abi`, `-lunwind`, `-lsetjmp`, `-lwasi-emulated-getpid` and
`-lOCCT-wasm` are `.linkedLibrary` entries in `Package.swift`, which SwiftPM considers safe, so
this file supplies the `-L` that finds them and not the names. `-D` defines and header search paths
are safe settings too and are likewise in the manifest.

USAGE

    python3 Scripts/make-wasi-toolset.py --wasi-sdk <prefix> --occt-lib-dir <dir> -o toolset.json
    swift build --toolset toolset.json --swift-sdk swift-6.4.0-RELEASE_wasm \\
        --triple wasm32-unknown-wasip1

A consumer reaches this script inside its own checkout, at
`.build/checkouts/OCCTSwift/Scripts/make-wasi-toolset.py`, and `--occt-lib-dir` is wherever that
consumer put the kernel archive.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PINS_FILE = REPO_ROOT / "Scripts" / "wasm-toolchain-versions.txt"
SHIM = REPO_ROOT / "Scripts" / "wasm-shims" / "wasi-std-threading.hpp"

# Separate from WASM_CXX_EH_FLAGS deliberately: `-fwasm-exceptions` does nothing for setjmp, and
# these two are what turn a setjmp/longjmp pair into the __wasm_setjmp / __wasm_longjmp that
# libsetjmp defines. See #2172 and Scripts/repro/2048/run.sh case 6, where their absence is a
# compile error naming setjmp.
SJLJ_FLAGS = ["-mllvm", "-wasm-enable-sjlj"]


def read_pin(name: str, pins_file: Path = PINS_FILE) -> str:
    """Return one KEY=value from the pinned toolchain file.

    Read rather than restated, so a toolset cannot drift away from the flags the kernel was
    compiled with and keep building.
    """
    if not pins_file.is_file():
        raise SystemExit(f"error: {pins_file} is missing")
    for line in pins_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        if key == name:
            return value
    raise SystemExit(f"error: {pins_file} has no {name}")


def eh_library_dir(wasi_sdk: Path) -> Path:
    """wasi-sdk's exception-enabled C++ runtime.

    The Swift SDK's own WASI.sdk carries the no-exceptions flavour of `libc++abi` (it holds
    `cxa_noexception.cpp.o` and defines no `__cxa_throw`) and no `libunwind` at all, so this
    directory has to precede the sysroot on the library search path, not merely be on it.
    """
    return wasi_sdk / "share" / "wasi-sysroot" / "lib" / "wasm32-wasip1" / "eh"


def build_toolset(wasi_sdk: Path, occt_lib_dir: Path, shim: Path | None,
                  eh_flags: list[str]) -> dict:
    """Assemble the toolset document."""
    cxx_common = list(eh_flags) + SJLJ_FLAGS
    cxx = list(cxx_common)
    if shim is not None:
        cxx += ["-include", str(shim)]
    # The C compiler gets the SAME set, not just the SjLj pair. `-wasm-use-legacy-eh=false` is an
    # -mllvm option and applies to any language, and a C object built with `-wasm-enable-sjlj`
    # without it carries the legacy encoding, which wasmkit rejects with `Illegal opcode: [6]` for
    # the whole module. Measured: Scripts/repro/2048/run.sh case 7 failed exactly that way while
    # this function handed the C compiler only SJLJ_FLAGS. `-fwasm-exceptions` on a C compile is
    # accepted with no diagnostic, so passing the pair costs nothing.
    toolset = {
        "schemaVersion": "1.0",
        "cCompiler": {"extraCLIOptions": list(cxx_common)},
        "cxxCompiler": {"extraCLIOptions": cxx},
        # Order matters: the eh directory has to come before the sysroot's own, or -lc++abi
        # resolves to the no-exceptions build and the link fails on __cxa_throw.
        "linker": {"extraCLIOptions": [
            "-L" + str(eh_library_dir(wasi_sdk)),
            "-L" + str(occt_lib_dir),
        ]},
    }
    return toolset


def self_test() -> int:
    """Check the document's shape against the things that were measured about it."""
    failures = []
    eh = read_pin("WASM_CXX_EH_FLAGS").split()

    doc = build_toolset(Path("/wasi"), Path("/libs"), Path("/shim.hpp"), eh)
    cxx = doc["cxxCompiler"]["extraCLIOptions"]

    # Every pinned exception flag reaches the C++ compiler. Dropping one is what #2171 measured as
    # a silent failure: the build stays green and every outermost catch stops firing.
    for flag in eh:
        if flag not in cxx:
            failures.append(f"cxxCompiler is missing the pinned flag {flag}")

    # The sjlj pair is separate from the exception flags and is a hard compile error without it.
    c_opts = doc["cCompiler"]["extraCLIOptions"]
    if "-wasm-enable-sjlj" not in cxx or "-wasm-enable-sjlj" not in c_opts:
        failures.append("-wasm-enable-sjlj must reach both the C and the C++ compiler")

    # And the encoding flag has to reach the C compiler with it, or a C object built for SjLj
    # carries the legacy encoding and the whole module is refused at run time.
    for flag in eh:
        if flag not in c_opts:
            failures.append(f"cCompiler is missing the pinned flag {flag}")

    # The shim is force-included when one is named, and not otherwise.
    if ["-include", "/shim.hpp"] != cxx[-2:]:
        failures.append("the shim is not force-included")
    if any("-include" == opt for opt in
           build_toolset(Path("/wasi"), Path("/libs"), None, eh)["cxxCompiler"]["extraCLIOptions"]):
        failures.append("--no-shim still emitted an -include")

    # The eh directory precedes the kernel's directory, and both are present.
    link = doc["linker"]["extraCLIOptions"]
    if not link or not link[0].endswith("wasm32-wasip1/eh"):
        failures.append("the eh library directory is not first on the search path")
    if "-L/libs" not in link:
        failures.append("the kernel's library directory is missing")

    # A tool with an empty extraCLIOptions is refused outright by SwiftPM, so no tool may be empty.
    for tool, body in doc.items():
        if tool == "schemaVersion":
            continue
        if not body.get("extraCLIOptions"):
            failures.append(f"{tool} would be written with no options, which SwiftPM refuses")

    for failure in failures:
        print(f"FAIL {failure}")
    print(f"self-test: {'PASS' if not failures else str(len(failures)) + ' failure(s)'}")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--wasi-sdk", default=os.environ.get("WASI_SDK_PREFIX"),
                        help="wasi-sdk install prefix (default: $WASI_SDK_PREFIX)")
    parser.add_argument("--occt-lib-dir",
                        help="directory holding libOCCT-wasm.a (default: this checkout's Libraries/)")
    parser.add_argument("--no-shim", action="store_true",
                        help="do not force-include the threading shim, for a bridge that includes "
                             "it itself")
    parser.add_argument("-o", "--output", help="write here instead of standard output")
    parser.add_argument("--self-test", action="store_true", help="check this script and exit")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    if not args.wasi_sdk:
        parser.error("--wasi-sdk is required (or set WASI_SDK_PREFIX). "
                     "Scripts/install-wasm-toolchain.sh installs the pinned one.")
    wasi_sdk = Path(args.wasi_sdk).resolve()
    if not eh_library_dir(wasi_sdk).is_dir():
        raise SystemExit(f"error: {eh_library_dir(wasi_sdk)} does not exist. "
                         f"Is {wasi_sdk} a wasi-sdk {read_pin('WASI_SDK_VERSION')} install?")

    occt_lib_dir = Path(args.occt_lib_dir).resolve() if args.occt_lib_dir \
        else (REPO_ROOT / "Libraries")

    shim = None if args.no_shim else SHIM
    if shim is not None and not shim.is_file():
        raise SystemExit(f"error: the threading shim is not at {shim}")

    document = build_toolset(wasi_sdk, occt_lib_dir, shim,
                             read_pin("WASM_CXX_EH_FLAGS").split())
    text = json.dumps(document, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(text)
        print(f"wrote {args.output}")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
