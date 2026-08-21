#!/usr/bin/env python3
"""Check `detect-dead-parameters.py` against the compiler, which is a different construction (#1001).

The detector decides "never read" with a word-boundary search over a comment-stripped function
body. `clang -Wunused-parameter` decides the same question from the parsed AST. They share no code
and no idea of what a body is, so agreement is corroboration and disagreement locates a bug in one
of them. This is the [measure, do not assume] policy's second-construction rule applied to a
detector rather than to a geometric result.

It runs `-fsyntax-only`, so it needs the OCCT headers (`Libraries/OCCT.xcframework`) and the
bridge's own `include/` directory, and it reports SKIPPED without them, the same way
`census-doc-occt-attribution.py` does.

    python3 Scripts/repro/1001-detector-fp-rates/verify_dead_parameters.py            # this tree
    python3 Scripts/repro/1001-detector-fp-rates/verify_dead_parameters.py 90917a70   # a commit

Given a commit, it exports that commit's `Sources/OCCTBridge/src` to a temporary directory and runs
both halves against it, which is how the non-empty population is reproduced: today's tree reports
zero from both halves, because Pass 4a fixed every site.
"""

import importlib.util
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DETECTOR = os.path.join(ROOT, "Scripts", "repro", "385-coverage-sample", "detect-dead-parameters.py")
HEADERS = os.path.join(ROOT, "Libraries", "OCCT.xcframework", "macos-arm64", "Headers")
INCLUDE = os.path.join(ROOT, "Sources", "OCCTBridge", "include")

WARNING = re.compile(r"^(.*?):(\d+):\d+: warning: unused parameter '([^']+)'")


def load_detector():
    spec = importlib.util.spec_from_file_location("_dead", DETECTOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def compiler_unused(src_dir):
    """Every (file, parameter) clang calls unused, over the same directory the detector scans."""
    found = set()
    for fn in sorted(os.listdir(src_dir)):
        if not fn.endswith(".mm"):
            continue
        cmd = [
            "clang++", "-std=c++17", "-ObjC++", "-fsyntax-only",
            "-Wno-everything", "-Wunused-parameter",
            f"-I{HEADERS}", f"-I{INCLUDE}", f"-I{src_dir}",
            "-DOCCT_AVAILABLE=1", "-DOCCT_NO_DEPRECATED",
            os.path.join(src_dir, fn),
        ]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        for line in proc.stderr.splitlines():
            m = WARNING.match(line)
            if m:
                found.add((os.path.basename(m.group(1)), m.group(3)))
    return found


def export(commit):
    tmp = tempfile.mkdtemp(prefix="occtswift-1001-")
    tar = subprocess.run(["git", "archive", commit, "Sources/OCCTBridge/src"],
                         cwd=ROOT, capture_output=True)
    if tar.returncode != 0:
        raise SystemExit(f"git archive {commit} failed: {tar.stderr.decode()}")
    subprocess.run(["tar", "-x", "-C", tmp], input=tar.stdout, check=True)
    return tmp, os.path.join(tmp, "Sources", "OCCTBridge", "src")


def main(argv):
    if not os.path.isdir(HEADERS):
        print("SKIPPED: Libraries/OCCT.xcframework is absent, so the compiler half cannot run.")
        return 0

    commit = argv[1] if len(argv) > 1 else None
    tmp = None
    if commit:
        tmp, src_dir = export(commit)
        print(f"tree: {commit}")
    else:
        src_dir = os.path.join(ROOT, "Sources", "OCCTBridge", "src")
        print("tree: the working tree")

    try:
        det = load_detector()
        detected = {(row[0], name) for row in det.scan_dir(src_dir) for name in row[3]}
        compiled = compiler_unused(src_dir)
    finally:
        if tmp:
            shutil.rmtree(tmp, ignore_errors=True)

    print(f"detector says unread : {len(detected)}")
    print(f"clang says unused    : {len(compiled)}")
    only_det = sorted(detected - compiled)
    only_cc = sorted(compiled - detected)
    print(f"agreed               : {len(detected & compiled)}")
    if only_det:
        print("\nDETECTOR ONLY (a false positive of the detector, or a use clang can see):")
        for f, p in only_det:
            print(f"  {f}  {p}")
    if only_cc:
        print("\nCLANG ONLY (a site the detector is blind to):")
        for f, p in only_cc:
            print(f"  {f}  {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
