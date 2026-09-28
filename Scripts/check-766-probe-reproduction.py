#!/usr/bin/env python3
"""Recompile every #766 ground-truth probe and diff its output against its own transcript.

This is what "kernel parity" verification actually means. A `kernel_output` record cites a line of
`Scripts/repro/766-*/transcript.txt`; nothing until now re-ran the probe that produced it, so a
transcript could be an edited copy of the bridge's answer and every count in the tree would agree.
`check-test-validity.py`'s `run_sample_kernel_parity` is a `return True` stub (#2198), and this is
the thing that should eventually replace it.

Per probe: compile `probe.mm` against the xcframework with the line from the `ground-truth-probe`
skill, run it, and compare stdout+stderr with `transcript.txt`. Verdicts:

    MATCH             output is identical after normalisation
    DIFF-VALUES       a line's value differs: a real divergence between kernel and transcript
    TRANSCRIPT-EXTRA  the transcript holds lines the rerun did not produce (an annotation, or a
                      claim nothing produced); the rerun is otherwise a subsequence of it
    RERUN-EXTRA       the rerun printed lines the transcript does not hold
    TIMEOUT           it built and did not finish
    COMPILE-FAIL      the probe does not build against this asset
    MISSING           no probe.mm, or no transcript.txt

Normalisation is deliberately small, because every rule is a way for a real difference to pass:
OCCT's own `[read in <n> s]` timing line, and hex addresses. Nothing numeric in the measurements is
touched.

NOT A GATE, AND NOT FOR `gate-scripts`
--------------------------------------
It reads a 1.3 GB xcframework that CI does not check out and compiles 344 translation units, which
is the release-check shape `okf/policies/static-gates.md` describes: a question about something the
repo points at rather than something it contains. `--require-asset` makes a run that examined
nothing exit 2 instead of reporting clean (#2098's mode). It exits 1 when any probe fails to
reproduce, so it can be run as a gate by hand or in a job that does have the asset.

    python3 Scripts/check-766-probe-reproduction.py --require-asset
    python3 Scripts/check-766-probe-reproduction.py --dirs 766-lprop-surface-analytic
    python3 Scripts/check-766-probe-reproduction.py --asset <dir> --jobs 8
    python3 Scripts/check-766-probe-reproduction.py --self-test
"""

from __future__ import annotations

import argparse
import concurrent.futures
import difflib
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_ASSET = os.path.join("Libraries", "OCCT.xcframework")
DEFAULT_PROBES = os.path.join("Scripts", "repro")
SLICE = "macos-arm64"
LIB = "OCCT-macos"

READ_IN = re.compile(r"\[read in [0-9.eE+-]+ ?s\]")
HEX = re.compile(r"0x[0-9a-fA-F]{6,}")
ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]|\[3[0-9];1m|\[0m")


def normalise(text: str) -> str:
    """`text` with the volatile shapes replaced, and trailing whitespace dropped.

    Three rules, and each one is a way for a real difference to pass, so each is bounded:
    OCCT's own `[read in <n> s]` timing line, hex addresses, and the ANSI colour codes
    `Message_PrinterOStream` emits, which the original captures were taken without.
    Nothing numeric in a measurement is touched.
    """
    text = READ_IN.sub("[read in TIME]", text)
    text = HEX.sub("0xADDR", text)
    text = ANSI.sub("", text)
    return "\n".join(line.rstrip() for line in text.strip().split("\n"))


def strip_header(lines: list[str]) -> list[str]:
    """Drop the leading `#` provenance block a transcript may carry.

    Several transcripts open with the build line, the date and the Swift-side values, as `#`
    comments. Those are documentation of the capture, not output the probe prints, and counting
    them as output reported seven sound probes as divergent.

    The marker is `#` followed by a space, or a bare `#`, and NOT `#` followed by a digit. Probes
    print issue numbers at the start of a line (`#490 restriction C0: ...`, `#398 8-point cubic`),
    and a first version that took any leading `#` as a header deleted real measurements from five
    transcripts and reported the reruns as having printed lines nobody asked for.
    """
    i = 0
    while i < len(lines):
        s = lines[i].strip()
        if s and not (s == "#" or s.startswith("# ")):
            break
        i += 1
    return lines[i:]


def compile_and_run(probe: str, asset: str, workdir: str, timeout: int):
    """(status, output_or_error) for one probe.mm compiled against `asset`.

    The binary runs with the probe's own directory as its working directory, because several probes
    read a fixture by a path relative to it (`inputs/fillet298_in1.brep`). Running elsewhere
    silently produced `faces=0 edges=0` and read as a kernel divergence. An optional `argv.txt`
    beside the probe supplies the arguments a probe needs, one per line.
    """
    headers = os.path.join(asset, SLICE, "Headers")
    binary = os.path.join(workdir, "probe")
    cmd = [
        "clang++", "-std=c++17", "-ObjC++", "-w",
        "-I", headers, "-L", os.path.join(asset, SLICE), "-l" + LIB,
        "-framework", "Foundation", "-framework", "AppKit", "-lz", "-lc++",
        probe, "-o", binary,
    ]
    try:
        cp = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "COMPILE-FAIL", "clang++ timed out"
    if cp.returncode != 0:
        return "COMPILE-FAIL", cp.stderr.strip()[-1500:]
    probe_dir = os.path.dirname(os.path.abspath(probe))
    argv = [binary]
    argv_file = os.path.join(probe_dir, "argv.txt")
    if os.path.isfile(argv_file):
        argv += [a for a in open(argv_file, encoding="utf-8").read().split() if a]
    try:
        run = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=probe_dir)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "the probe timed out"
    return "RAN", (run.stdout + run.stderr)


def check_one(d: str, asset: str, timeout: int) -> dict:
    name = os.path.basename(d)
    probe = os.path.join(d, "probe.mm")
    transcript = os.path.join(d, "transcript.txt")
    if not os.path.isfile(probe) or not os.path.isfile(transcript):
        return {"name": name, "status": "MISSING",
                "detail": f"probe.mm={os.path.isfile(probe)} transcript.txt={os.path.isfile(transcript)}"}
    work = tempfile.mkdtemp(prefix="probe766-")
    try:
        status, out = compile_and_run(probe, asset, work, timeout)
        if status != "RAN":
            return {"name": name, "status": status, "detail": out}
        want_lines = strip_header(
            normalise(open(transcript, encoding="utf-8", errors="ignore").read()).split("\n"))
        got_lines = normalise(out).split("\n")
        if want_lines == got_lines:
            return {"name": name, "status": "MATCH", "detail": ""}
        diff = "\n".join(list(difflib.unified_diff(
            want_lines, got_lines, fromfile="transcript.txt", tofile="rerun", lineterm=""))[:40])
        # A rerun that is a subsequence of the transcript, or the other way round, is a different
        # finding from a line whose VALUE differs. The transcript saying more than the probe prints
        # is either an annotation or a claim nothing produced; a differing value is a divergence.
        removed = [d for d in diff.split("\n") if d.startswith("-") and not d.startswith("---")]
        addedl = [d for d in diff.split("\n") if d.startswith("+") and not d.startswith("+++")]
        if removed and not addedl:
            verdict = "TRANSCRIPT-EXTRA"
        elif addedl and not removed:
            verdict = "RERUN-EXTRA"
        else:
            verdict = "DIFF-VALUES"
        return {"name": name, "status": verdict, "detail": diff}
    finally:
        shutil.rmtree(work, ignore_errors=True)


def probe_dirs(args) -> list[str]:
    base = args.probes if os.path.isabs(args.probes) else os.path.join(ROOT, args.probes)
    if args.dirs:
        return [d if os.path.isabs(d) else os.path.join(base, d) for d in args.dirs]
    return sorted(glob.glob(os.path.join(base, "766-*")))


def run(args) -> int:
    asset = args.asset if os.path.isabs(args.asset) else os.path.join(ROOT, args.asset)
    have_asset = os.path.isdir(os.path.join(asset, SLICE, "Headers"))
    dirs = [d for d in probe_dirs(args) if os.path.isdir(d)]

    print("check-766-probe-reproduction: recompile each probe and diff it against its transcript")
    print(f"  asset: {asset}  ({'present' if have_asset else 'ABSENT'})")
    print(f"  probe directories: {len(dirs)}")

    if not have_asset or not dirs:
        why = ("the xcframework is not at that path" if not have_asset
               else "no 766-* probe directory was found")
        if args.require_asset:
            print(f"  ERROR: --require-asset and {why}. A clean report over a population that "
                  "was never compiled is a false green, not a result.", file=sys.stderr)
            return 2
        print(f"  SKIPPED: {why}. Pass --require-asset to make this an error.")
        return 0

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(check_one, d, asset, args.timeout): d for d in dirs}
        for fut in concurrent.futures.as_completed(futures):
            results.append(fut.result())
    results.sort(key=lambda r: r["name"])

    tally: dict[str, int] = {}
    for r in results:
        tally[r["status"]] = tally.get(r["status"], 0) + 1
    for k in ("MATCH", "DIFF-VALUES", "TRANSCRIPT-EXTRA", "RERUN-EXTRA", "TIMEOUT",
              "COMPILE-FAIL", "MISSING"):
        if tally.get(k):
            print(f"  {k:13s} {tally[k]}")

    bad = [r for r in results if r["status"] != "MATCH"]
    for r in bad:
        print()
        print(f"  {r['status']}  {r['name']}")
        for line in r["detail"].split("\n")[:args.detail_lines]:
            print(f"      {line}")
    if bad:
        print()
        print("  A probe that does not reproduce its own transcript means the transcript is not a")
        print("  record of this kernel. Re-run it and correct the transcript, or withdraw the")
        print("  records that cite it.")
        return 1
    return 0


def self_test() -> int:
    """Prove the comparison and the normalisation, without needing the xcframework.

    The compile path cannot be exercised without the asset, so the cases here cover the two things
    that can silently pass: a normalisation rule that erases a real difference, and a comparison
    that reports MATCH on output it never read.
    """
    cases = []

    # 1. Identical text matches.
    cases.append(("identical output matches", normalise("a\nb") == normalise("a\nb")))

    # 2. A trailing-newline difference is not a difference.
    cases.append(("a trailing newline is normalised away", normalise("a\nb\n") == normalise("a\nb")))

    # 3. The timing line is normalised, in both spellings OCCT emits.
    cases.append(("the read-in timing line is normalised",
                  normalise("[read in 0.0001 s] x") == normalise("[read in 0.5 s] x")))
    cases.append(("the unspaced timing spelling is normalised too",
                  normalise("[read in 0.0001s] x") == normalise("[read in 0.5 s] x")))

    # 4. A hex address is normalised.
    cases.append(("a hex address is normalised",
                  normalise("at 0x16f3a2b40") == normalise("at 0x7ffee1234c")))

    # 4b. ANSI colour is normalised. `Message_PrinterOStream` emits it and the original captures
    #     were taken without it, which reported one sound probe as a 69-line divergence.
    cases.append(("ANSI colour is normalised",
                  normalise("\x1b[32;1m***\x1b[0m") == normalise("***")))
    cases.append(("the bracket-only colour spelling is normalised",
                  normalise("[32;1m***[0m") == normalise("***")))

    # 4c. A leading `#` provenance block is not output. Seven transcripts open with the build line
    #     and the date, and counting those as output reported every one of them as divergent.
    cases.append(("a leading # header is dropped",
                  strip_header(["# built on 2026-09-24", "#", "area=6.0"]) == ["area=6.0"]))
    cases.append(("a # line in the middle is NOT dropped, because it is output",
                  strip_header(["area=6.0", "# note"]) == ["area=6.0", "# note"]))
    cases.append(("a leading issue number is NOT a header",
                  strip_header(["#490 restriction C0: volume=785.39"]) ==
                  ["#490 restriction C0: volume=785.39"]))

    # 5. A measured VALUE difference is NOT normalised away. This is the case that matters: every
    #    normalisation rule is a way for a real difference to pass, so each one is bounded.
    cases.append(("a differing measurement is still a difference",
                  normalise("area=272.868") != normalise("area=272.869")))
    cases.append(("a differing exponent is still a difference",
                  normalise("d=1.12e-07") != normalise("d=1.12e-06")))

    # 6. A missing probe or transcript is MISSING rather than MATCH. A directory with neither would
    #    otherwise compare empty to empty and pass.
    with tempfile.TemporaryDirectory() as d:
        empty = os.path.join(d, "766-empty")
        os.makedirs(empty)
        r = check_one(empty, os.path.join(d, "no-asset"), 5)
        cases.append(("a directory with no probe is MISSING", r["status"] == "MISSING"))
        open(os.path.join(empty, "probe.mm"), "w").write("int main(){return 0;}\n")
        r = check_one(empty, os.path.join(d, "no-asset"), 5)
        cases.append(("a probe with no transcript is MISSING", r["status"] == "MISSING"))

    # 7 and 8. The real compile line, against a stand-in asset: an empty `libOCCT-macos.a` and an
    #   empty `Headers`. A probe that needs no OCCT symbol links against it, so the whole
    #   compile-run-diff path is exercised here with no 1.3 GB xcframework. A probe that reproduces
    #   its transcript is MATCH, one that prints something else is DIFF, and one that does not build
    #   is COMPILE-FAIL. Without the last of those the detector would report clean for a probe that
    #   nothing ever built.
    with tempfile.TemporaryDirectory() as d:
        asset = os.path.join(d, "OCCT.xcframework")
        os.makedirs(os.path.join(asset, SLICE, "Headers"))
        # `ar` refuses to write an archive with no members, so the stand-in holds one dummy object.
        dummy_c = os.path.join(d, "dummy.c")
        dummy_o = os.path.join(d, "dummy.o")
        open(dummy_c, "w").write("int occt_probe_self_test_dummy(void) { return 0; }\n")
        subprocess.run(["clang", "-c", dummy_c, "-o", dummy_o], capture_output=True)
        subprocess.run(["ar", "rcs", os.path.join(asset, SLICE, "lib" + LIB + ".a"), dummy_o],
                       capture_output=True)
        for name, body, want in (
            ("766-ok", 'printf("area=6.0\\n");', "area=6.0\n"),
            ("766-bad", 'printf("area=7.0\\n");', "area=6.0\n"),
            ("766-broken", "this is not c++", "nothing\n"),
            ("766-extra", 'printf("area=6.0\\n");', "area=6.0\nand a line nothing printed\n"),
            ("766-cwd", 'FILE*f=fopen("inputs/x.txt","r");printf("%s\\n",f?"found":"missing");',
             "found\n"),
        ):
            p = os.path.join(d, name)
            os.makedirs(p)
            src = ("#include <stdio.h>\nint main(){" + body + "return 0;}\n"
                   if name != "766-broken" else body + "\n")
            open(os.path.join(p, "probe.mm"), "w").write(src)
            open(os.path.join(p, "transcript.txt"), "w").write(want)
        os.makedirs(os.path.join(d, "766-cwd", "inputs"))
        open(os.path.join(d, "766-cwd", "inputs", "x.txt"), "w").write("fixture\n")
        ok = check_one(os.path.join(d, "766-ok"), asset, 60)
        bad = check_one(os.path.join(d, "766-bad"), asset, 60)
        broken = check_one(os.path.join(d, "766-broken"), asset, 60)
        extra = check_one(os.path.join(d, "766-extra"), asset, 60)
        cwd = check_one(os.path.join(d, "766-cwd"), asset, 60)
        cases.append(("a probe reproducing its transcript is MATCH", ok["status"] == "MATCH"))
        cases.append(("a probe printing a different value is DIFF-VALUES",
                      bad["status"] == "DIFF-VALUES"))
        cases.append(("an uncompilable probe is COMPILE-FAIL",
                      broken["status"] == "COMPILE-FAIL"))
        cases.append(("a transcript claiming more than the rerun printed is TRANSCRIPT-EXTRA",
                      extra["status"] == "TRANSCRIPT-EXTRA"))
        # The probe runs in its OWN directory, so a fixture read by a relative path resolves.
        # Running it in a scratch directory turned a missing fixture into `faces=0 edges=0`, which
        # reads as a kernel divergence rather than as a harness bug.
        cases.append(("a probe reads its fixture by a relative path", cwd["status"] == "MATCH"))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--asset", default=DEFAULT_ASSET, help="the OCCT.xcframework to compile against")
    ap.add_argument("--probes", default=DEFAULT_PROBES, help="the directory holding 766-* probes")
    ap.add_argument("--dirs", nargs="*", default=None, help="only these probe directories")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) // 2))
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--detail-lines", type=int, default=20)
    ap.add_argument("--require-asset", action="store_true",
                    help="exit 2 rather than report clean when nothing was compiled (#2098)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else run(args)


if __name__ == "__main__":
    sys.exit(main())
