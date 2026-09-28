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
    MATCH-DECLARED    identical once the probe's own reproduce.json allowances were applied, and
                      the report names every line each allowance covered
    DIFF-VALUES       a line's value differs: a real divergence between kernel and transcript
    TRANSCRIPT-EXTRA  the transcript holds lines the rerun did not produce (an annotation, or a
                      claim nothing produced); the rerun is otherwise a subsequence of it
    RERUN-EXTRA       the rerun printed lines the transcript does not hold
    NOT-REPRODUCIBLE  reproduce.json declares the transcript is not one capture of one run, with a
                      reason; the report prints the reason every time and never a value
    DECL-UNUSED       a reproduce.json pattern matched nothing, so it is either stale or was always
                      wrong. A defect, for the reason a blind gate is one
    DECL-INVALID      a reproduce.json is unreadable, or an allowance carries no reason
    TIMEOUT           it built and did not finish
    COMPILE-FAIL      the probe does not build against this asset
    MISSING           no probe.mm, or no transcript.txt

Normalisation is deliberately small, because every rule is a way for a real difference to pass:
OCCT's own `[read in <n> s]` timing line, hex addresses, the ANSI colour `Message_PrinterOStream`
emits, and a line with no content left after those. Nothing numeric in the measurements is touched.

reproduce.json: WHAT THE CAPTURE DID, DECLARED NEXT TO THE PROBE
----------------------------------------------------------------
Thirteen of 344 transcripts did not reproduce and **none of the thirteen was a kernel divergence**
(PR #2823). Each was a way in which "transcript.txt is one run of probe.mm from its own directory with
no arguments" was not true of the capture, so each is declared in an optional `reproduce.json`
beside the probe rather than normalised away for all 344. Every key takes a required `reason`, and
a key whose pattern matches nothing is DECL-UNUSED rather than ignored.

**Each key takes one of two shapes, and which one is decided by its consumer**: `cwd`, `argv` and
`status` are read as literals and take `{"value": ..., "reason": ...}`; every other key is matched
against lines and takes `{"pattern": <regex>, "reason": ...}`, as a list for the three that hold
several. A declaration that offers the other shape is DECL-INVALID rather than accepted, because the
validator used to take either and each consumer read exactly one: a `pattern`-only `argv` raised
KeyError, and a `pattern`-only `cwd` ran the probe in the wrong directory and said nothing, which is
the mistake two of the thirteen transcripts below were captured with (PR #2822's review).

    cwd             "repo-root", for a probe whose fixture path is relative to the repo root
                    (`Tests/OCCTStressTests/Fixtures/...`). Running it in its own directory turned
                    a missing fixture into `faces=0 edges=0`, which reads as a kernel divergence.
    argv            the arguments the capture passed, as a list of strings. Several probes are
                    argv-driven tools whose arguments were recorded only in the transcript's own
                    header prose. Strings, not JSON numbers: `1.50` would reach the probe as "1.5".
    rerun_keep      the capture's own line filter, as a regex: only matching rerun lines are
                    compared. `766-thread-safety` was captured through `grep -E '^[0-9]{3,4} '`.
    rerun_drop      lines the rerun prints that the capture's inputs made impossible, such as a
                    "BREP read failed" for a shape that was never committed.
    volatile        a transcript line matching one of these is compared BY SHAPE: the rerun must
                    still hold a line at the same position matching the same pattern, and only the
                    digits are free. Elapsed time, CPU time, working-set size and free disk space.
                    A volatile line that vanishes, or stops matching its shape, still fails.
    transcript_only lines the transcript holds that the probe does not print: an author's note that
                    the process died, or a measurement whose input shape was never committed.
    transcript_tail_from
                    the same, for a whole marked section rather than a line: everything from the
                    first line matching the pattern to the end of the transcript. Three thread
                    transcripts carry a "Part B" whose input shapes a diagnostic test exported and
                    nobody committed.
    status          "not-reproducible", for a transcript that is not one capture of one run at all
                    (`766-thread-181-189` interleaves two programs' output over several
                    invocations). Verdict NOT-REPRODUCIBLE, reason printed, exit code unaffected.

IT REPORTS WHICH KERNEL IT MEASURED, AND DOES NOT VERIFY THAT IT IS THE PINNED ONE
-----------------------------------------------------------------------------------
The banner prints the sha256 of the static archive the probes link against, because a DIFF-VALUES
cannot tell "the transcript is wrong" from "I compiled against a different kernel than the
transcript was made on", and the remedy it prints is to withdraw the records that cite it.
Verifying that the archive IS the pinned asset is #2818, which covers four scripts; until it lands,
read the fingerprint. The default `--asset` is the repo's own `Libraries/OCCT.xcframework`, which in
a working checkout is routinely NOT the pinned archive: measured 2026-09-28, the main checkout's
copy and the pinned `v4.0.0-kernel.2` asset SwiftPM resolves are different archives, and this
script accepts either without comment. In a worktree with no `Libraries/`, point `--asset` at
`.build/artifacts/*/OCCT/OCCT.xcframework` after `swift package resolve`, which is the pinned asset
and is what CI links.

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
import hashlib
import json
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

    Four rules, and each one is a way for a real difference to pass, so each is bounded:
    OCCT's own `[read in <n> s]` timing line, hex addresses, the ANSI colour codes
    `Message_PrinterOStream` emits, which the original captures were taken without, and a line
    with nothing left on it after those.

    The last rule is the newest and the only one that drops a line rather than rewriting it. A line
    with no content is never a measurement, and it cannot hide one: dropping empty lines from both
    sides can turn a difference into a match only where the difference WAS an empty line. OCCT
    writes `ESC[32;1m` on a line of its own before each STEP writer banner and the original
    captures kept neither the escape nor the newline after it, which reported
    `766-stress-format-round-trip` as divergent over 53 blank lines while all 127 of its
    measurements agreed to the last digit (PR #2823). Nothing numeric in a measurement is touched.
    """
    text = READ_IN.sub("[read in TIME]", text)
    text = HEX.sub("0xADDR", text)
    text = ANSI.sub("", text)
    lines = [line.rstrip() for line in text.strip().split("\n")]
    return "\n".join(line for line in lines if line)


def write_text(path: str, text: str) -> None:
    """`text` into `path`, with the handle closed before anything else opens it.

    The self-test writes a dozen fixture files that `clang` then reads, and `open(p, "w").write(x)`
    leaves closing them to the refcount. That holds on CPython and is not a property to depend on
    (PR #2822), so every write in this file goes through here.
    """
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)


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


DECL_FILE = "reproduce.json"
# Every allowance is a way for a real difference to pass, so every one carries a reason that the
# report prints. There are three shapes of entry, and which shape a key takes is decided by what
# CONSUMES it, not by taste:
#   PATTERN_KEYS   a list of {"pattern": <regex>, "reason": <why>} objects, matched against lines.
#   REGEX_KEYS     one {"pattern": <regex>, "reason": <why>} object, matched against lines.
#   VALUE_KEYS     one {"value": <literal>, "reason": <why>} object, read as a literal.
# The validator accepted `value` OR `pattern` for every key in the last two groups while the
# consumers read exactly one of them, which is PR #2822's CRITICAL: a `pattern`-only `argv` reached
# `decl["argv"]["value"]` and raised KeyError, and a `pattern`-only `cwd` read as None and ran the
# probe in the WRONG DIRECTORY, silently, which is the failure two of the thirteen transcripts this
# script exists to adjudicate were produced by. A validator that admits a shape no consumer reads is
# not a laxer validator, it is a validator for a different file.
PATTERN_KEYS = ("rerun_drop", "volatile", "transcript_only")
REGEX_KEYS = ("rerun_keep", "transcript_tail_from")
VALUE_KEYS = ("cwd", "argv", "status")
# Derived, not restated: a key added to one of the three groups and forgotten here would be reported
# as an unknown key in every declaration that used it.
DECL_KEYS = PATTERN_KEYS + REGEX_KEYS + VALUE_KEYS


def load_declaration(d: str):
    """(declaration, errors) for the probe directory `d`.

    An absent `reproduce.json` is `{}`, which is the normal case: 331 of 344 probes reproduce with
    no declaration at all and must keep doing so. A declaration that names an unknown key, or an
    allowance with no reason, is an error rather than a silently ignored line, because a typo in a
    suppression file is indistinguishable from a suppression that works.
    """
    path = os.path.join(d, DECL_FILE)
    if not os.path.isfile(path):
        return {}, []
    try:
        with open(path, encoding="utf-8") as fh:
            decl = json.load(fh)
    except (ValueError, OSError) as exc:
        return {}, [f"{DECL_FILE} is not readable JSON: {exc}"]
    if not isinstance(decl, dict):
        return {}, [f"{DECL_FILE} must hold a JSON object"]
    errors = [f"{DECL_FILE}: unknown key {k!r}" for k in decl if k not in DECL_KEYS]
    for k in PATTERN_KEYS:
        entries = decl.get(k, [])
        if not isinstance(entries, list):
            errors.append(f"{DECL_FILE}: {k} must be a list")
            continue
        for e in entries:
            if not isinstance(e, dict) or not e.get("pattern") or not e.get("reason"):
                errors.append(f"{DECL_FILE}: every {k} entry needs a pattern and a reason")
                continue
            try:
                re.compile(e["pattern"])
            except re.error as exc:
                errors.append(f"{DECL_FILE}: {k} pattern {e['pattern']!r} does not compile: {exc}")
    for k in REGEX_KEYS:
        if k not in decl:
            continue
        e = decl[k]
        if not isinstance(e, dict) or not e.get("pattern") or not e.get("reason"):
            errors.append(f"{DECL_FILE}: {k} needs a pattern and a reason")
            continue
        try:
            re.compile(e["pattern"])
        except re.error as exc:
            errors.append(f"{DECL_FILE}: {k} pattern {e['pattern']!r} does not compile: {exc}")
    for k in VALUE_KEYS:
        if k not in decl:
            continue
        e = decl[k]
        if not isinstance(e, dict) or "value" not in e or not e.get("reason"):
            errors.append(f"{DECL_FILE}: {k} needs a value and a reason")
            continue
        # Each of the three is read as a literal by exactly one consumer, so each literal is checked
        # here rather than where reading it wrong is silent.
        if k == "cwd" and e["value"] not in ("repo-root", "probe"):
            errors.append(f"{DECL_FILE}: cwd must be \"repo-root\" or \"probe\"")
        if k == "status" and e["value"] != "not-reproducible":
            errors.append(f"{DECL_FILE}: the only status is \"not-reproducible\"")
        if k == "argv":
            if not isinstance(e["value"], list):
                errors.append(f"{DECL_FILE}: argv value must be a list of arguments, and a bare "
                              "string would be passed one character at a time")
            elif not all(isinstance(a, str) for a in e["value"]):
                # A JSON number would reach the probe through `str()`, and `1.50` arrives as "1.5",
                # which is a different argument from the one the capture passed. The capture's
                # command line is text, so it is declared as text.
                errors.append(f"{DECL_FILE}: every argv element must be a string, because a JSON "
                              "number does not round-trip to the argument the capture passed")
    return decl, errors


def apply_declaration(want: list[str], got: list[str], decl: dict):
    """(want, got, covered, unused) with the declaration's allowances applied.

    `covered` is one line per allowance that matched something, and it is printed for every
    MATCH-DECLARED probe: an allowance nobody can see is the blindness this file exists to avoid.
    `unused` is every allowance that matched nothing, which is a defect for the same reason.
    """
    covered, unused = [], []

    # `cwd` and `argv` changed how the probe RAN, so they cannot be checked against lines here, but
    # they are the whole reason two of these probes reproduce and they must not pass silently: a
    # MATCH-DECLARED with an empty detail block reads as a MATCH with extra ceremony.
    for k in ("cwd", "argv"):
        if k in decl:
            covered.append(f"{k} {decl[k]['value']!r}: {decl[k]['reason']}")

    keep = decl.get("rerun_keep")
    if keep:
        # `pattern`, never `value`: this is compiled as a regex, and a `value` fallback compiled a
        # literal the author never meant as one (PR #2822). The validator requires `pattern`.
        rx = re.compile(keep["pattern"])
        kept = [l for l in got if rx.search(l)]
        if len(kept) == len(got):
            unused.append(f"rerun_keep {rx.pattern!r} dropped no rerun line ({keep['reason']})")
        else:
            covered.append(f"rerun_keep {rx.pattern!r} dropped {len(got) - len(kept)} rerun "
                           f"line(s): {keep['reason']}")
        got = kept

    for e in decl.get("rerun_drop", []):
        rx = re.compile(e["pattern"])
        hit = [l for l in got if rx.search(l)]
        got = [l for l in got if not rx.search(l)]
        (covered if hit else unused).append(
            f"rerun_drop {e['pattern']!r} matched {len(hit)} rerun line(s): {e['reason']}")

    for e in decl.get("transcript_only", []):
        rx = re.compile(e["pattern"])
        hit = [l for l in want if rx.search(l)]
        want = [l for l in want if not rx.search(l)]
        (covered if hit else unused).append(
            f"transcript_only {e['pattern']!r} matched {len(hit)} transcript line(s): {e['reason']}")

    # `transcript_tail_from` is `transcript_only` for the case that would otherwise need one pattern
    # per line: three thread transcripts carry a "Part B" section, marked with its own header, whose
    # input shapes were exported by a diagnostic test that was never committed. The marker must
    # still be there, so a transcript that loses it is DECL-UNUSED rather than silently truncated.
    tail = decl.get("transcript_tail_from")
    if tail:
        rx = re.compile(tail["pattern"])
        at = next((i for i, l in enumerate(want) if rx.search(l)), None)
        if at is None:
            unused.append(f"transcript_tail_from {rx.pattern!r} matched no transcript line "
                          f"({tail['reason']})")
        else:
            covered.append(f"transcript_tail_from {rx.pattern!r} dropped {len(want) - at} "
                           f"transcript line(s) from that marker on: {tail['reason']}")
            want = want[:at]

    # `volatile` is the only allowance that compares rather than removes, and it is deliberately
    # positional: the rerun must still hold a line AT THE SAME INDEX matching the same shape. A
    # volatile line that disappears changes the lengths and is reported; one that stops matching its
    # own pattern is reported; only the digits inside the shape are free.
    vol = decl.get("volatile", [])
    if vol and len(want) == len(got):
        differing = {e["pattern"]: 0 for e in vol}
        for i, (w, g) in enumerate(zip(want, got)):
            if w == g:
                continue
            # Every pattern that covers this line pair is credited, not just the first. The
            # substitution happens once either way, and a first version stopped at the first match,
            # so a second pattern covering the same line reported "matched 1 line, 0 differing" and
            # read as an allowance doing nothing (PR #2822).
            matched = False
            for e in vol:
                rx = re.compile(e["pattern"])
                if rx.search(w) and rx.search(g):
                    matched = True
                    differing[e["pattern"]] += 1
            if matched:
                got[i] = w
        for e in vol:
            rx = re.compile(e["pattern"])
            # A volatile pattern is used when it matches a line, not when that line happens to
            # differ on this run. `ElapsedTime() over a 50 ms sleep` came back at the captured value
            # once and the allowance was reported DECL-UNUSED, which would have had someone delete a
            # declaration that is right about a line that is genuinely volatile.
            found = sum(1 for l in want if rx.search(l))
            (covered if found else unused).append(
                f"volatile {e['pattern']!r} matched {found} transcript line(s), "
                f"{differing[e['pattern']]} of them differing on this run: {e['reason']}")
    elif vol:
        for e in vol:
            unused.append(f"volatile {e['pattern']!r} was not applied: the two sides hold "
                          f"{len(want)} and {len(got)} lines, so no line is at the same index "
                          f"({e['reason']})")
    return want, got, covered, unused


def compile_and_run(probe: str, asset: str, workdir: str, timeout: int, decl: dict | None = None,
                    repo_root: str = ROOT):
    """(status, output_or_error) for one probe.mm compiled against `asset`.

    The binary runs with the probe's own directory as its working directory, because several probes
    read a fixture by a path relative to it (`inputs/fillet298_in1.brep`). Running elsewhere
    silently produced `faces=0 edges=0` and read as a kernel divergence. Two probes need the
    opposite, because their fixture path is relative to the repo root, and say so in their
    `reproduce.json` `cwd`. An optional `argv.txt` beside the probe, or the declaration's `argv`,
    supplies the arguments a probe needs.
    """
    decl = decl or {}
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
    if "argv" in decl:
        argv += [str(a) for a in decl["argv"]["value"]]
    else:
        argv_file = os.path.join(probe_dir, "argv.txt")
        if os.path.isfile(argv_file):
            with open(argv_file, encoding="utf-8") as fh:
                argv += [a for a in fh.read().split() if a]
    cwd = repo_root if decl.get("cwd", {}).get("value") == "repo-root" else probe_dir
    try:
        run = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, cwd=cwd)
    except subprocess.TimeoutExpired:
        return "TIMEOUT", "the probe timed out"
    return "RAN", (run.stdout + run.stderr)


def check_one(d: str, asset: str, timeout: int, repo_root: str = ROOT) -> dict:
    name = os.path.basename(d)
    probe = os.path.join(d, "probe.mm")
    transcript = os.path.join(d, "transcript.txt")
    if not os.path.isfile(probe) or not os.path.isfile(transcript):
        return {"name": name, "status": "MISSING",
                "detail": f"probe.mm={os.path.isfile(probe)} transcript.txt={os.path.isfile(transcript)}"}
    decl, decl_errors = load_declaration(d)
    if decl_errors:
        return {"name": name, "status": "DECL-INVALID", "detail": "\n".join(decl_errors)}
    if decl.get("status", {}).get("value") == "not-reproducible":
        # Not a pass and not a failure: a transcript that was never one capture of one run cannot be
        # compared at all, and saying so out loud on every run is the whole point. The reason is
        # printed; no measurement of this probe is ever reported as verified.
        return {"name": name, "status": "NOT-REPRODUCIBLE",
                "detail": decl["status"]["reason"]}
    work = tempfile.mkdtemp(prefix="probe766-")
    try:
        status, out = compile_and_run(probe, asset, work, timeout, decl, repo_root)
        if status != "RAN":
            return {"name": name, "status": status, "detail": out}
        with open(transcript, encoding="utf-8", errors="ignore") as fh:
            want_lines = strip_header(normalise(fh.read()).split("\n"))
        got_lines = normalise(out).split("\n")
        if want_lines == got_lines and not decl:
            return {"name": name, "status": "MATCH", "detail": ""}
        want_lines, got_lines, covered, unused = apply_declaration(want_lines, got_lines, decl)
        if unused:
            return {"name": name, "status": "DECL-UNUSED", "detail": "\n".join(unused)}
        if want_lines == got_lines:
            return {"name": name, "status": "MATCH-DECLARED" if decl else "MATCH",
                    "detail": "\n".join(covered)}
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


def asset_fingerprint(asset: str) -> str:
    """The sha256 and size of the static archive the probes will actually link against.

    This records WHICH kernel a verdict was reached against; it does not verify that the kernel is
    the pinned one, which is #2818's job across four scripts. The distinction matters because a
    DIFF-VALUES cannot tell "the transcript is wrong" from "I compiled against a different kernel
    than the transcript was made on", and the printed remedy is to withdraw records. Measured on
    2026-09-28: the pinned v4.0.0-kernel.2 asset SwiftPM resolves is
    27329ac2d30f65ce2c319e47b599183ee4d4947e8ee86478ce557dfb4bb5b260, and the main checkout's own
    `Libraries/OCCT.xcframework`, which is this script's DEFAULT `--asset`, is a different archive.
    Either is silently accepted today, so a report with no fingerprint in it is not attributable.
    """
    lib = os.path.join(asset, SLICE, "lib" + LIB + ".a")
    if not os.path.isfile(lib):
        return "no archive at that path, so nothing identifies what was measured"
    h = hashlib.sha256()
    with open(lib, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return f"{os.path.basename(lib)} sha256={h.hexdigest()} bytes={os.path.getsize(lib)}"


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
    print(f"  archive: {asset_fingerprint(asset)}")
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
    for k in ("MATCH", "MATCH-DECLARED", "NOT-REPRODUCIBLE", "DIFF-VALUES", "TRANSCRIPT-EXTRA",
              "RERUN-EXTRA", "DECL-UNUSED", "DECL-INVALID", "TIMEOUT", "COMPILE-FAIL", "MISSING"):
        if tally.get(k):
            print(f"  {k:16s} {tally[k]}")

    # MATCH-DECLARED and NOT-REPRODUCIBLE are printed with their reasons on every run and are not
    # failures. Printing them is the difference between "declared volatile" and "silently stopped
    # matching": an allowance nobody reads is the same thing as no allowance at all.
    declared = [r for r in results if r["status"] in ("MATCH-DECLARED", "NOT-REPRODUCIBLE")]
    for r in declared:
        print()
        print(f"  {r['status']}  {r['name']}")
        for line in r["detail"].split("\n")[:args.detail_lines]:
            print(f"      {line}")

    bad = [r for r in results
           if r["status"] not in ("MATCH", "MATCH-DECLARED", "NOT-REPRODUCIBLE")]
    for r in bad:
        print()
        print(f"  {r['status']}  {r['name']}")
        for line in r["detail"].split("\n")[:args.detail_lines]:
            print(f"      {line}")
    if bad:
        print()
        print("  A probe that does not reproduce its own transcript means the transcript is not a")
        print("  record of this kernel. Re-run it and correct the transcript, or withdraw the")
        print("  records that cite it. A DECL-UNUSED is the other shape of the same defect: an")
        print("  allowance in reproduce.json that covers nothing is either stale or was wrong.")
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
        write_text(os.path.join(empty, "probe.mm"), "int main(){return 0;}\n")
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
        write_text(dummy_c, "int occt_probe_self_test_dummy(void) { return 0; }\n")
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
            write_text(os.path.join(p, "probe.mm"), src)
            write_text(os.path.join(p, "transcript.txt"), want)
        os.makedirs(os.path.join(d, "766-cwd", "inputs"))
        write_text(os.path.join(d, "766-cwd", "inputs", "x.txt"), "fixture\n")
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

    # 9. The blank-line rule. It is the only normalisation that drops a line, so it needs both
    #    halves: a blank line is erased, and a line with content is not.
    cases.append(("a blank line is not a difference",
                  normalise("a\n\n\nb") == normalise("a\nb")))
    cases.append(("an ANSI-only line goes with it",
                  normalise("a\n\x1b[32;1m\nb") == normalise("a\nb")))
    cases.append(("a line with content survives the blank-line rule",
                  normalise("a\n0\nb") != normalise("a\nb")))

    # 10. reproduce.json validation. A typo in a suppression file is indistinguishable from a
    #     suppression that works, so each of these is an error rather than a silent no-op.
    with tempfile.TemporaryDirectory() as d:
        def decl_errors(obj):
            p = os.path.join(d, "probe-dir")
            shutil.rmtree(p, ignore_errors=True)
            os.makedirs(p)
            write_text(os.path.join(p, DECL_FILE),
                       obj if isinstance(obj, str) else json.dumps(obj))
            return load_declaration(p)[1]

        cases.append(("an unknown reproduce.json key is an error",
                      any("unknown key" in e for e in decl_errors({"cwdd": {"value": "probe",
                                                                            "reason": "x"}}))))
        cases.append(("a volatile entry with no reason is an error",
                      bool(decl_errors({"volatile": [{"pattern": "x"}]}))))
        cases.append(("a volatile pattern that does not compile is an error",
                      any("does not compile" in e
                          for e in decl_errors({"volatile": [{"pattern": "(", "reason": "x"}]}))))
        cases.append(("an unparseable reproduce.json is an error",
                      bool(decl_errors("{not json"))))
        cases.append(("a cwd other than repo-root or probe is an error",
                      bool(decl_errors({"cwd": {"value": "/etc", "reason": "x"}}))))
        cases.append(("a valid declaration has no errors",
                      decl_errors({"cwd": {"value": "repo-root", "reason": "fixture path"}}) == []))

        # 10b. The shape of each single-entry key, which the validator used to accept either way
        #      round while its consumer read exactly one (PR #2822's CRITICAL). The three `value`
        #      keys reject a `pattern`, and each rejection is a defect the old validator waved
        #      through: a `pattern`-only `argv` raised KeyError at `decl["argv"]["value"]`, a
        #      `pattern`-only `cwd` read as None and ran the probe in the WRONG DIRECTORY with no
        #      word about it, and a `pattern`-only `status` read as None and so as reproducible,
        #      which compares a transcript that is not one capture of one run.
        cases.append(("a pattern-only cwd is an error, not a silent run in the probe directory",
                      any("cwd needs a value" in e
                          for e in decl_errors({"cwd": {"pattern": "repo-root", "reason": "x"}}))))
        cases.append(("a pattern-only argv is an error, not a KeyError at run time",
                      any("argv needs a value" in e
                          for e in decl_errors({"argv": {"pattern": "inputs", "reason": "x"}}))))
        cases.append(("a pattern-only status is an error, not a silently reproducible transcript",
                      any("status needs a value" in e
                          for e in decl_errors({"status": {"pattern": "not-reproducible",
                                                           "reason": "x"}}))))
        #      ...and the two regex keys reject a `value`, which was being compiled as a regex.
        cases.append(("a value-only rerun_keep is an error, because it is compiled as a regex",
                      any("rerun_keep needs a pattern" in e
                          for e in decl_errors({"rerun_keep": {"value": "^[0-9]+ ",
                                                               "reason": "x"}}))))
        cases.append(("a value-only transcript_tail_from is an error for the same reason",
                      any("transcript_tail_from needs a pattern" in e
                          for e in decl_errors({"transcript_tail_from": {"value": "== Part B",
                                                                         "reason": "x"}}))))
        cases.append(("a rerun_keep pattern that does not compile is an error, not a crash",
                      any("does not compile" in e
                          for e in decl_errors({"rerun_keep": {"pattern": "(", "reason": "x"}}))))
        cases.append(("a transcript_tail_from pattern that does not compile is an error too",
                      any("does not compile" in e
                          for e in decl_errors({"transcript_tail_from": {"pattern": "(",
                                                                         "reason": "x"}}))))
        #      `argv`'s value is iterated, so a string would reach the probe one character at a time.
        cases.append(("an argv value that is a bare string is an error",
                      any("must be a list" in e
                          for e in decl_errors({"argv": {"value": "inputs", "reason": "x"}}))))
        cases.append(("an argv element that is not a string is an error",
                      any("must be a string" in e
                          for e in decl_errors({"argv": {"value": [1.5], "reason": "x"}}))))
        #      A key written as a bare literal rather than an object is an error and not an
        #      AttributeError: the old `decl.get("cwd", {}).get("value")` ran on whatever was there.
        cases.append(("a cwd that is not an object is an error rather than a crash",
                      bool(decl_errors({"cwd": "repo-root"}))))
        cases.append(("a valid argv and rerun_keep declaration has no errors",
                      decl_errors({"argv": {"value": ["inputs"], "reason": "the capture's argv"},
                                   "rerun_keep": {"pattern": "^[0-9]{3,4} ",
                                                  "reason": "the capture's grep"}}) == []))

    # 11. Each allowance, applied to lines, with the case that must still fail beside it. Every
    #     entry here is a way for a real difference to pass, which is why each has a negative twin.
    vol = {"volatile": [{"pattern": r"^t=[0-9.]+ s$", "reason": "elapsed time"}]}
    w, g, cov, un = apply_declaration(["a", "t=0.06 s", "b"], ["a", "t=0.05 s", "b"], vol)
    cases.append(("a declared-volatile line's digits may differ", w == g and cov and not un))
    w, g, cov, un = apply_declaration(["a", "t=0.06 s", "b"], ["a", "t=none", "b"], vol)
    cases.append(("a volatile line that stops matching its shape is still a difference", w != g))
    w, g, cov, un = apply_declaration(["a", "t=0.06 s", "b"], ["a", "b"], vol)
    cases.append(("a volatile line that vanishes is still a difference",
                  w != g and any("not applied" in u for u in un)))
    w, g, cov, un = apply_declaration(["a", "x=1", "b"], ["a", "x=2", "b"], vol)
    cases.append(("a volatile pattern does not cover a line it does not match", w != g))
    w, g, cov, un = apply_declaration(["a", "b"], ["a", "b"], vol)
    cases.append(("a volatile pattern that matches nothing is unused", bool(un)))
    w, g, cov, un = apply_declaration(["a", "t=0.06 s"], ["a", "t=0.06 s"], vol)
    cases.append(("a volatile line that agrees on this run is still a used allowance",
                  w == g and cov and not un))
    # Two patterns over one line: both are credited. Stopping at the first match reported the second
    # as "matched 1 transcript line(s), 0 of them differing", which reads as an allowance covering a
    # line that never differs and is the shape a reader deletes (PR #2822).
    vol2 = {"volatile": [{"pattern": r"^t=[0-9.]+ s$", "reason": "elapsed time"},
                         {"pattern": r"^t=", "reason": "the same line, a looser shape"}]}
    w, g, cov, un = apply_declaration(["t=0.06 s"], ["t=0.05 s"], vol2)
    cases.append(("two volatile patterns covering one differing line are both credited",
                  w == g and not un and sum("1 of them differing" in c for c in cov) == 2))

    tonly = {"transcript_only": [{"pattern": r"^\(process terminated", "reason": "author's note"}]}
    w, g, cov, un = apply_declaration(["a", "(process terminated: SIGSEGV)"], ["a"], tonly)
    cases.append(("a declared author note is dropped from the transcript side",
                  w == g == ["a"] and cov and not un))
    w, g, cov, un = apply_declaration(["a"], ["a"], tonly)
    cases.append(("a transcript_only pattern that matches nothing is unused", bool(un)))

    tail = {"transcript_tail_from": {"pattern": r"^== Part B: ", "reason": "inputs never committed"}}
    w, g, cov, un = apply_declaration(["a", "b", "== Part B: x", "c", "d"], ["a", "b"], tail)
    cases.append(("a declared transcript tail is dropped from the marker on",
                  w == g == ["a", "b"] and cov and not un))
    w, g, cov, un = apply_declaration(["a", "b"], ["a", "b"], tail)
    cases.append(("a transcript_tail_from marker that is absent is unused", bool(un)))
    w, g, cov, un = apply_declaration(["a", "b", "== Part B: x"], ["a", "z"], tail)
    cases.append(("dropping the tail does not hide a difference before the marker", w != g))

    keep = {"rerun_keep": {"pattern": r"^[0-9]{3,4} ", "reason": "the capture's grep"}}
    w, g, cov, un = apply_declaration(["298 x"], ["298 x", "Mesh /tmp/a.obj"], keep)
    cases.append(("a declared capture filter drops the lines it filtered",
                  w == g == ["298 x"] and cov and not un))
    w, g, cov, un = apply_declaration(["298 x"], ["298 x"], keep)
    cases.append(("a rerun_keep that drops nothing is unused", bool(un)))

    drop = {"rerun_drop": [{"pattern": r"^nut: BREP read failed$", "reason": "input never kept"}]}
    w, g, cov, un = apply_declaration(["a"], ["a", "nut: BREP read failed"], drop)
    cases.append(("a declared rerun-only line is dropped", w == g == ["a"] and cov and not un))
    w, g, cov, un = apply_declaration(["a"], ["a"], drop)
    cases.append(("a rerun_drop that matches nothing is unused", bool(un)))

    # 12. The whole path through check_one, against the stand-in asset again: an allowance that
    #     covers a real difference gives MATCH-DECLARED, one that covers nothing gives DECL-UNUSED,
    #     `argv` reaches the program, `cwd` moves the working directory, and a declared
    #     not-reproducible transcript is neither a pass nor a failure.
    with tempfile.TemporaryDirectory() as d:
        asset = os.path.join(d, "OCCT.xcframework")
        os.makedirs(os.path.join(asset, SLICE, "Headers"))
        dummy_c = os.path.join(d, "dummy.c")
        dummy_o = os.path.join(d, "dummy.o")
        write_text(dummy_c, "int occt_probe_self_test_dummy(void) { return 0; }\n")
        subprocess.run(["clang", "-c", dummy_c, "-o", dummy_o], capture_output=True)
        subprocess.run(["ar", "rcs", os.path.join(asset, SLICE, "lib" + LIB + ".a"), dummy_o],
                       capture_output=True)
        fake_root = os.path.join(d, "fake-repo")
        os.makedirs(os.path.join(fake_root, "Tests"))
        write_text(os.path.join(fake_root, "Tests", "fixture.txt"), "root fixture\n")

        def mk(name, body, want, decl=None):
            p = os.path.join(d, name)
            os.makedirs(p, exist_ok=True)
            write_text(os.path.join(p, "probe.mm"),
                       "#include <stdio.h>\n#include <stdlib.h>\nint main(int argc, char** argv){"
                       + body + "return 0;}\n")
            write_text(os.path.join(p, "transcript.txt"), want)
            if decl is not None:
                write_text(os.path.join(p, DECL_FILE), json.dumps(decl))
            return p

        # `cwd`: the fixture is at Tests/fixture.txt, relative to the repo root, not the probe dir.
        root_body = ('FILE*f=fopen("Tests/fixture.txt","r");'
                     'printf("fixture=%s\\n", f?"found":"missing");')
        p = mk("766-root", root_body, "fixture=found\n",
               {"cwd": {"value": "repo-root", "reason": "the fixture path is repo-root relative"}})
        r = check_one(p, asset, 60, repo_root=fake_root)
        cases.append(("cwd repo-root finds a repo-root-relative fixture",
                      r["status"] == "MATCH-DECLARED"))
        cases.append(("and the cwd reason is reported rather than left blank",
                      "repo-root relative" in r["detail"]))
        p = mk("766-root-undeclared", root_body, "fixture=found\n")
        r = check_one(p, asset, 60, repo_root=fake_root)
        cases.append(("without the cwd declaration the same probe fails",
                      r["status"] == "DIFF-VALUES"))

        # `argv`: the value reaches the program.
        p = mk("766-argv", 'printf("mode=%s\\n", argc>1?argv[1]:"none");', "mode=prim\n",
               {"argv": {"value": ["prim"], "reason": "the capture passed the mode"}})
        r = check_one(p, asset, 60)
        cases.append(("argv reaches the probe", r["status"] == "MATCH-DECLARED"))

        # `volatile` end to end, and the DECL-UNUSED twin.
        p = mk("766-vol", 'printf("free=%d\\n", 1234);', "free=9999\n",
               {"volatile": [{"pattern": r"^free=[0-9]+$", "reason": "free disk space"}]})
        r = check_one(p, asset, 60)
        cases.append(("a declared-volatile probe is MATCH-DECLARED",
                      r["status"] == "MATCH-DECLARED"))
        p = mk("766-vol-stale", 'printf("free=1234\\n");', "free=1234\n",
               {"volatile": [{"pattern": r"^used=[0-9]+$", "reason": "a pattern nothing matches"}]})
        r = check_one(p, asset, 60)
        cases.append(("an allowance that covers nothing is DECL-UNUSED",
                      r["status"] == "DECL-UNUSED"))

        # A declared allowance must not hide a difference on an undeclared line.
        p = mk("766-vol-plus-real", 'printf("free=1\\narea=7.0\\n");', "free=9\narea=6.0\n",
               {"volatile": [{"pattern": r"^free=[0-9]+$", "reason": "free disk space"}]})
        r = check_one(p, asset, 60)
        cases.append(("a volatile allowance does not hide a real divergence beside it",
                      r["status"] == "DIFF-VALUES"))

        # `status: not-reproducible` short-circuits before any compile, and is not a pass.
        p = mk("766-nr", 'printf("anything\\n");', "something else\n",
               {"status": {"value": "not-reproducible",
                           "reason": "the transcript interleaves two programs over several runs"}})
        r = check_one(p, asset, 60)
        cases.append(("a declared not-reproducible transcript is NOT-REPRODUCIBLE",
                      r["status"] == "NOT-REPRODUCIBLE"))
        cases.append(("and its reason is what gets reported",
                      "interleaves two programs" in r["detail"]))

        # An invalid declaration fails rather than being ignored.
        p = mk("766-badjson", 'printf("a\\n");', "a\n")
        write_text(os.path.join(p, DECL_FILE), "{oops")
        r = check_one(p, asset, 60)
        cases.append(("an unreadable reproduce.json is DECL-INVALID",
                      r["status"] == "DECL-INVALID"))

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
