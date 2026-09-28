#!/usr/bin/env python3
"""CENSUS, not a gate: #766 kernel-parity records whose shape cannot carry a parity claim.

A record claims that a bridge output and a kernel output were compared and agreed. Four shapes make
that claim unsupportable, and each is cheap to find:

  * **boolean-only on both sides.** `{"built": true}` against `{"built": true}` proves the two
    agreed that something happened, and nothing about what. Batch 1 of the walk measured this as the
    primary triage signal: 7 of 9 records in the rejected PR were boolean-only, 0 of 9 in the best
    one, with no false positives.
  * **no numeric value on either side.** The looser version of the same thing. A measurement with no
    number in it did not measure.
  * **no provenance.** No `probe`, no `source`, no `evidence`: nothing says where the kernel value
    came from, so the kernel side could have been copied from the bridge side.
  * **key sets that differ.** When the two sides do not measure the same things, the extra
    measurement is the finding. Batch 1 found a review round that resolved a real mismatch by
    DELETING the kernel's extra measurement so both sides agreed, with prose defending it. A record
    whose kernel side is a strict subset of its bridge side has that shape, and is called out
    separately from the reverse.

It also resolves every `Scripts/repro/...` path a record cites, since a record citing a transcript
that is not in the tree cites nothing.

WHY THIS IS A CENSUS AND NOT A GATE
-----------------------------------
Every shape has a correct instance. A test whose whole subject is "this refuses" has `{"result":
"nil"}` on both sides and is right to. A wrapper-side guard has no kernel probe because the kernel
was never reached, which several records say in prose. And the two sides legitimately differ in key
set where one side reports a value the other cannot express. So this prints a list and always exits
0, per `okf/policies/static-gates.md`. What it buys is the order to read in.

NOT FOR `gate-scripts`
----------------------
The records live on `v5.0.0-766-execution`, not on `main`. `--require-records` turns a run over an
absent population into an error rather than a clean report (#2098's mode).

    python3 Scripts/census-766-record-shape.py
    python3 Scripts/census-766-record-shape.py --records <dir> --repro-root <dir> --summary
    python3 Scripts/census-766-record-shape.py --self-test
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DEFAULT_RECORDS = os.path.join("okf", "references", "766-execution", "kernel-parity")

REPRO_PATH = re.compile(r"Scripts/repro/[A-Za-z0-9_.+-]+")
BOOLISH = {"true", "false", "nil", "none", "yes", "no", "n/a", "empty", "ok", "null"}
PROVENANCE_KEYS = ("probe", "source", "evidence", "kernel_probe", "transcript")


def side_data(rec: dict, side: str):
    """The `data` mapping for one side, accepting both the `_output` and the `_result` spellings."""
    out = rec.get(side + "_output")
    if out is None:
        out = rec.get(side + "_result")
    if not isinstance(out, dict):
        return None
    inner = out.get("data")
    return inner if isinstance(inner, dict) else out


def values_of(data) -> list:
    """Every scalar in `data`, one level of list and dict nesting unwrapped."""
    if not isinstance(data, dict):
        return []
    out = []
    for v in data.values():
        if isinstance(v, list):
            out += v
        elif isinstance(v, dict):
            out += list(v.values())
        else:
            out.append(v)
    return out


def boolish(v) -> bool:
    if isinstance(v, bool) or v is None:
        return True
    return isinstance(v, str) and v.strip().lower() in BOOLISH


def numeric(v) -> bool:
    if isinstance(v, bool):
        return False
    if isinstance(v, (int, float)):
        return True
    return isinstance(v, str) and bool(re.search(r"-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?", v))


def provenance(rec: dict) -> bool:
    for k in PROVENANCE_KEYS:
        if rec.get(k):
            return True
    for side in ("kernel_output", "kernel_result"):
        o = rec.get(side)
        if isinstance(o, dict) and any(o.get(k) for k in PROVENANCE_KEYS):
            return True
    return False


def inspect(rec: dict, repro_root: str | None) -> list[str]:
    """The shape flags for one record, in reading order. Empty means the record looks sound."""
    flags = []
    bd, kd = side_data(rec, "bridge"), side_data(rec, "kernel")
    bv, kv = values_of(bd), values_of(kd)

    if bd is None or kd is None:
        flags.append("a-side-is-missing")
    else:
        # The two sides' `data` in different shapes, a mapping against a prose blob, means nothing
        # mechanical compared them: `equal: true` there is a human reading. 231 records branch-wide.
        # An exact-equality channel was measured instead and discarded: only 37 records claim
        # `equal: true` over two same-keyed mappings whose values differ, and all 37 differ in the
        # last float digit, so the channel would have been noise rather than a signal.
        raw_b = rec.get("bridge_output") or rec.get("bridge_result")
        raw_k = rec.get("kernel_output") or rec.get("kernel_result")
        db = raw_b.get("data") if isinstance(raw_b, dict) else None
        dk = raw_k.get("data") if isinstance(raw_k, dict) else None
        if db is not None and dk is not None and type(db) is not type(dk):
            flags.append("sides-differ-in-shape")
        if bv and kv and all(boolish(v) for v in bv) and all(boolish(v) for v in kv):
            flags.append("boolean-only-both-sides")
        elif not any(numeric(v) for v in bv + kv):
            flags.append("no-numeric-either-side")
        bk, kk = set(bd), set(kd)
        if bk != kk:
            if kk < bk:
                flags.append("kernel-side-is-a-subset")
            elif bk < kk:
                flags.append("bridge-side-is-a-subset")
            else:
                flags.append("key-sets-disjoint")

    if not provenance(rec):
        flags.append("no-provenance")

    if repro_root is not None:
        for cited in sorted(set(REPRO_PATH.findall(json.dumps(rec)))):
            if not os.path.exists(os.path.join(repro_root, cited)):
                flags.append(f"cited-path-absent:{cited}")
    return flags


def records(records_dir: str):
    for path in sorted(glob.glob(os.path.join(records_dir, "*.json"))):
        try:
            data = json.load(open(path, encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"  WARNING: {os.path.basename(path)} did not parse: {exc}", file=sys.stderr)
            continue
        if not isinstance(data, list):
            print(f"  WARNING: {os.path.basename(path)} is not a list of records", file=sys.stderr)
            continue
        for i, rec in enumerate(data):
            if isinstance(rec, dict):
                yield os.path.basename(path), i, rec


def census(args) -> int:
    records_dir = args.records if os.path.isabs(args.records) else os.path.join(ROOT, args.records)
    repro_root = None
    if args.repro_root:
        repro_root = (args.repro_root if os.path.isabs(args.repro_root)
                      else os.path.join(ROOT, args.repro_root))

    tally: dict[str, int] = {}
    findings = []
    total = 0
    for fname, i, rec in records(records_dir):
        total += 1
        flags = inspect(rec, repro_root)
        for f in flags:
            tally[f.split(":")[0]] = tally.get(f.split(":")[0], 0) + 1
        if flags:
            findings.append((fname, i, rec.get("test_name", "?"),
                             rec.get("bridge_function", "?"), flags))

    print("census-766-record-shape: kernel-parity records whose shape cannot carry the claim")
    print(f"  records read: {total}")
    print(f"  records with at least one flag: {len(findings)}")
    for k in sorted(tally):
        print(f"    {k:26s} {tally[k]}")

    if args.require_records and total == 0:
        print("  ERROR: --require-records and no record was examined. The records live on "
              "v5.0.0-766-execution; a clean report over an empty directory is a false green.",
              file=sys.stderr)
        return 2

    if findings and not args.summary:
        print()
        for fname, i, test, bridge_fn, flags in findings:
            print(f"  {fname}[{i}]  {' '.join(flags)}")
            print(f"      {bridge_fn} :: {test}")
    if findings:
        print()
        print("  Read boolean-only-both-sides first: it predicted batch 1's blind tests. Read")
        print("  kernel-side-is-a-subset next: when two sides disagree in shape, the extra")
        print("  measurement is the finding, not the thing to delete.")
    return 0


def self_test() -> int:
    """Prove each shape flag is reachable, and that a sound record raises none of them."""
    cases = []

    sound = {
        "test_name": "t", "bridge_function": "OCCTShapeVolume",
        "bridge_output": {"type": "measurement", "data": {"volume": 8.0}},
        "kernel_output": {"type": "measurement", "data": {"volume": 8.0},
                          "source": "Scripts/repro/766-x/transcript.txt volume=8.0"},
    }
    cases.append(("a sound record raises no flag", inspect(sound, None) == []))

    # 1. Boolean-only on both sides. Batch 1's primary signal.
    r = json.loads(json.dumps(sound))
    r["bridge_output"]["data"] = {"built": True}
    r["kernel_output"]["data"] = {"built": True}
    cases.append(("boolean-only on both sides is flagged",
                  "boolean-only-both-sides" in inspect(r, None)))

    # 2. A boolean spelled as a string counts. `{"result": "nil"}` is the common spelling on this
    #    branch, and a first version that tested `isinstance(v, bool)` saw none of them.
    r = json.loads(json.dumps(sound))
    r["bridge_output"]["data"] = {"result": "nil"}
    r["kernel_output"]["data"] = {"result": "nil"}
    cases.append(("a bool spelled as a string counts",
                  "boolean-only-both-sides" in inspect(r, None)))

    # 3. A record with no number anywhere is flagged even when the values are prose.
    r = json.loads(json.dumps(sound))
    r["bridge_output"]["data"] = {"kind": "plane"}
    r["kernel_output"]["data"] = {"kind": "plane"}
    cases.append(("no numeric value on either side is flagged",
                  "no-numeric-either-side" in inspect(r, None)))

    # 4. A kernel side that is a strict subset of the bridge side is called out on its own. This
    #    is the laundering-by-deletion shape.
    r = json.loads(json.dumps(sound))
    r["bridge_output"]["data"] = {"volume": 8.0, "area": 24.0}
    r["kernel_output"]["data"] = {"volume": 8.0}
    cases.append(("a kernel side that is a subset is flagged as such",
                  "kernel-side-is-a-subset" in inspect(r, None)))

    # 5. The reverse is a different flag, because a kernel measuring MORE is the finding to keep,
    #    not the thing to trim.
    r = json.loads(json.dumps(sound))
    r["kernel_output"]["data"] = {"volume": 8.0, "area": 24.0}
    cases.append(("a bridge side that is a subset is a different flag",
                  "bridge-side-is-a-subset" in inspect(r, None)))

    # 6. Disjoint key sets are their own flag.
    r = json.loads(json.dumps(sound))
    r["kernel_output"]["data"] = {"mass": 8.0}
    cases.append(("disjoint key sets are flagged", "key-sets-disjoint" in inspect(r, None)))

    # 6b. A mapping on one side and a prose blob on the other is flagged. The key-set channel above
    #     is blind to it, because neither side has keys to compare, and it is exactly the case
    #     where `equal: true` cannot have been reached mechanically.
    r = json.loads(json.dumps(sound))
    r["kernel_output"]["data"] = "GeomAPI: volume 8.0"
    cases.append(("a mapping against a prose blob is flagged",
                  "sides-differ-in-shape" in inspect(r, None)))
    r = json.loads(json.dumps(sound))
    r["bridge_output"]["data"] = "volume 8.0"
    r["kernel_output"]["data"] = "GeomAPI: volume 8.0"
    cases.append(("two prose blobs are NOT flagged for shape, since both are prose",
                  "sides-differ-in-shape" not in inspect(r, None)))

    # 7. No provenance is flagged.
    r = json.loads(json.dumps(sound))
    del r["kernel_output"]["source"]
    cases.append(("a record with no provenance is flagged", "no-provenance" in inspect(r, None)))

    # 8. A top-level `probe` counts as provenance, and so does `evidence`. Both spellings are in
    #    use on the branch; reading only one would report hundreds of sound records.
    for key in ("probe", "evidence", "kernel_probe"):
        r = json.loads(json.dumps(sound))
        del r["kernel_output"]["source"]
        r[key] = "Scripts/repro/766-x/transcript.txt"
        cases.append((f"a top-level {key} counts as provenance",
                      "no-provenance" not in inspect(r, None)))

    # 9. The `_result` spelling is read like `_output`. Six records use it.
    r = {"test_name": "t", "bridge_function": "OCCTX",
         "bridge_result": {"built": True}, "kernel_result": {"built": True},
         "probe": "Scripts/repro/766-x"}
    cases.append(("the _result spelling is read",
                  "boolean-only-both-sides" in inspect(r, None)))

    # 10. A missing side is flagged rather than crashing the run. A null `bridge_output` is in the
    #     population, and a crash here would take the whole census down.
    r = json.loads(json.dumps(sound))
    r["bridge_output"] = None
    cases.append(("a missing side is flagged, not a crash",
                  "a-side-is-missing" in inspect(r, None)))

    # 11. A cited repro path that is not in the tree is reported, and one that is, is not.
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(os.path.join(d, "Scripts", "repro", "766-x"))
        ok = inspect(sound, d)
        cases.append(("a cited repro path that exists is silent",
                      not any(f.startswith("cited-path-absent") for f in ok)))
        r = json.loads(json.dumps(sound))
        r["kernel_output"]["source"] = "Scripts/repro/766-not-here/transcript.txt v=1"
        bad = inspect(r, d)
        cases.append(("a cited repro path that is absent is reported",
                      any(f.startswith("cited-path-absent") for f in bad)))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--records", default=DEFAULT_RECORDS)
    ap.add_argument("--repro-root", default=".",
                    help="the tree to resolve cited Scripts/repro paths against; empty to skip")
    ap.add_argument("--summary", action="store_true")
    ap.add_argument("--require-records", action="store_true",
                    help="exit 2 rather than report clean when nothing was examined (#2098)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else census(args)


if __name__ == "__main__":
    sys.exit(main())
