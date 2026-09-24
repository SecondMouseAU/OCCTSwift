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
# libsetjmp defines. See #2172 and Scripts/repro/2048/run.sh case 6, where their absence is a LINK
# error naming setjmp: without them the compiler emits a plain call to `setjmp`, which nothing in
# the sysroot defines, and `wasm-ld: error: ... undefined symbol: setjmp` is what the build says.
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
            # A present-but-empty value is refused rather than returned. A blank
            # WASM_CXX_EH_FLAGS would otherwise emit a toolset carrying no exception flags at
            # all, which is measured case 5: the build stays green, nothing is diagnosed, and
            # every outermost catch stops firing. "The pin is what the toolset reads" is only a
            # guarantee if an unreadable pin stops the script.
            if not value.strip():
                raise SystemExit(f"error: {pins_file} defines {name} with no value")
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
    # -x c++ compiles Sources/OCCTBridge/src/*.mm as C++ rather than Objective-C++. #2256 measured
    # why: clang gives ANY Objective-C++ TU the Objective-C++ personality
    # (__gnustep_objcxx_personality_v0) whether or not Objective-C is present, LLVM's wasm EH
    # lowering runs only on the wasm C++ personality, so the function is skipped and an Itanium
    # invoke/landingpad reaches WebAssembly ISel, which cannot select it. Building those files
    # without the EH flags instead is #2171's silent failure: they compile clean and every
    # outermost catch (...) stops firing with no diagnostic.
    #
    # The bridge contains no Objective-C: zero @interface, @implementation, @autoreleasepool, @try,
    # NSString, NSObject, NSArray across all 74 .mm files, and the one framework #import is already
    # WASI-guarded. So this costs nothing that could otherwise have worked; Objective-C cannot
    # target this triple at all (-fobjc-runtime=macosx is a backend fatal error).
    #
    # It lives HERE and not in Package.swift's cxxSettings, which is where #2256 (PR #2281) had to
    # leave it while this PR was open. Two reasons: cxxSettings would need .unsafeFlags, which is
    # the exact thing this PR exists to remove; and under the deprecated `--build-system native` a
    # cxxSettings -x c++ also reaches .c sources in the same target, while the toolset's does not.
    cxx = list(cxx_common) + ["-x", "c++"]
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

    # The two loops below iterate the pin, so they check nothing at all if the pin went empty.
    # Assert the flag by name here, once, so that emptying or gutting WASM_CXX_EH_FLAGS fails this
    # script instead of quietly producing case 5's green build with no exception support.
    if "-fwasm-exceptions" not in cxx:
        failures.append("-fwasm-exceptions does not reach the C++ compiler")

    # Every pinned exception flag reaches the C++ compiler. Dropping one is what #2171 measured as
    # a silent failure: the build stays green and every outermost catch stops firing.
    for flag in eh:
        if flag not in cxx:
            failures.append(f"cxxCompiler is missing the pinned flag {flag}")

    # -x c++ must reach the C++ compiler and must NOT reach the C compiler. Losing it puts the
    # bridge's .mm files back through the Objective-C++ personality, which crashes this clang in
    # code generation (#2256); gaining it on the C side would compile a genuine .c source as C++,
    # which is the one thing the toolset placement buys over Package.swift's cxxSettings under the
    # deprecated `--build-system native`. Neither is visible in the pin, so neither loop above
    # covers it.
    def has_x_cxx(opts: list[str]) -> bool:
        return any(opts[i] == "-x" and opts[i + 1] == "c++" for i in range(len(opts) - 1))

    if not has_x_cxx(cxx):
        failures.append("cxxCompiler is missing -x c++, so the bridge's .mm files would go "
                        "through the Objective-C++ personality and crash clang (#2256)")

    # The sjlj pair is separate from the exception flags, and without it the link fails outright
    # on an undefined `setjmp` (measured, run.sh case 6), so it is never a silent loss.
    c_opts = doc["cCompiler"]["extraCLIOptions"]
    if has_x_cxx(c_opts):
        failures.append("cCompiler must NOT carry -x c++: it would compile a genuine .c source "
                        "as C++, which is exactly what the toolset placement avoids")
    if "-wasm-enable-sjlj" not in cxx or "-wasm-enable-sjlj" not in c_opts:
        failures.append("-wasm-enable-sjlj must reach both the C and the C++ compiler")

    # And the encoding flag has to reach the C compiler with it, or a C object built for SjLj
    # carries the legacy encoding and the whole module is refused at run time.
    for flag in eh:
        if flag not in c_opts:
            failures.append(f"cCompiler is missing the pinned flag {flag}")

    # `-mllvm` passes the NEXT argument through to LLVM, so membership is not enough: an option
    # list that carries `-wasm-use-legacy-eh=false` without the `-mllvm` in front of it is an
    # unknown driver argument, and one that ends on a bare `-mllvm` swallows whatever SwiftPM
    # appends after it.
    for tool in ("cCompiler", "cxxCompiler"):
        opts = doc[tool]["extraCLIOptions"]
        for index, opt in enumerate(opts):
            if opt == "-mllvm" and index + 1 >= len(opts):
                failures.append(f"{tool} ends on a bare -mllvm, which would swallow "
                                f"whatever follows it")
            if opt.startswith("-wasm-") and (index == 0 or opts[index - 1] != "-mllvm"):
                failures.append(f"{tool}'s {opt} is not preceded by -mllvm")

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
    # Checked here rather than left to the link, for the same reason the wasi-sdk prefix is. The
    # DEFAULT is the one that bites: `Libraries/` is gitignored apart from dummy.c and include/,
    # so a fresh checkout has the directory and not the archive, and a -L into it produces
    # `wasm-ld: error: unable to find library -lOCCT-wasm` at the end of a full build instead of
    # here, before one starts.
    if not (occt_lib_dir / "libOCCT-wasm.a").is_file():
        raise SystemExit(f"error: no libOCCT-wasm.a in {occt_lib_dir}. Pass --occt-lib-dir, or "
                         f"build the kernel with Scripts/build-occt-wasm.sh.")

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
