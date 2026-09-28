#!/usr/bin/env python3
"""CENSUS, not a gate: `bridge_function` names in #766's kernel-parity records that resolve to nothing.

Every record in `okf/references/766-execution/kernel-parity/*.json` names the bridge function whose
output it claims to compare against the kernel. A name that resolves to no symbol in
`Sources/OCCTBridge/` means the record is about a function this repo does not have, and the
comparison it reports was made against nothing.

#2198 measured **69 of 219** resolving on the older bulk-generated records. Batch 1 of the walk, which
was hand-measured, was 52 of 52. The backlog is therefore non-zero and mixed, which is why this
reports rather than gates: promoting it would redden every PR against the branch for records an
earlier pass generated. Per `okf/policies/static-gates.md`, measure the rate, fix the backlog, then
gate.

WHAT A CLEAN NON-RESOLUTION LOOKS LIKE
--------------------------------------
Three shapes are correct and are counted separately rather than reported:

  * `"none (pure Swift: ConstructionPlane.absolute)"` - the test's subject is a Swift-side
    computation with no bridge call. 290 records branch-wide say this, and they are right to.
  * `"OCCTEdgeGetParameterBounds + OCCTEdgeGetPointAtParam (circle recovered in Swift)"` - a
    compound. Every `OCCT`-shaped token in the field is resolved, not just the first.
  * `"OCCTFaceGetPrimaryAxis (radius computed in Swift, ...)"` - a name plus a parenthetical.

A record whose field holds no `OCCT`-shaped token at all and does NOT say `none`/`pure Swift` is
reported as `no-name`, because a record that names no subject is not evidence about one.

NOT FOR `gate-scripts`
----------------------
Its input lives on `v5.0.0-766-execution`, not on `main`, so a bare run in CI would read an empty
directory and print a clean report. `--require-records` turns that into an error (#2098's mode).

    python3 Scripts/census-766-bridge-functions.py
    python3 Scripts/census-766-bridge-functions.py --records <dir> --require-records
    python3 Scripts/census-766-bridge-functions.py --self-test
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
DEFAULT_BRIDGE = os.path.join("Sources", "OCCTBridge")

TOKEN = re.compile(r"\b(?:OCCT|occt)[A-Za-z0-9_]+")
NOT_A_BRIDGE_CALL = re.compile(r"\bnone\b|\bSwift\b|\bno bridge\b|\bn/?a\b", re.I)
SWIFT_SUBJECT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*"
                           r"(?:\([^)]*\))?(?:\s*[/(].*)?$")
DECL = re.compile(r"^\s*(?:[A-Za-z_][\w\s*&:<>,]*?\b)((?:OCCT|occt)[A-Za-z0-9_]+)\s*\(", re.M)


def bridge_symbols(bridge_root: str) -> tuple[set[str], set[str]]:
    """(declared, present): names declared in a header, and names appearing anywhere in the bridge.

    Two tiers, because they answer different questions. `declared` is "this is a bridge entry
    point"; `present` is "this string exists in the bridge at all", which a helper, a macro or a
    comment also satisfies. A name in neither is the finding.
    """
    declared: set[str] = set()
    present: set[str] = set()
    for base, _dirs, files in os.walk(bridge_root):
        for fn in files:
            if not fn.endswith((".h", ".mm")):
                continue
            text = open(os.path.join(base, fn), encoding="utf-8", errors="ignore").read()
            present.update(TOKEN.findall(text))
            if fn.endswith(".h"):
                declared.update(DECL.findall(text))
    return declared, present


def records(records_dir: str):
    """Yield (json_basename, index, record) over every parity JSON in `records_dir`."""
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


def classify(field: str, declared: set[str], present: set[str]) -> tuple[str, list[str]]:
    """The verdict for one `bridge_function` field, and the names that did not resolve."""
    field = (field or "").strip()
    toks = TOKEN.findall(field)
    if not toks:
        if NOT_A_BRIDGE_CALL.search(field):
            return "not-a-bridge-call", []
        if SWIFT_SUBJECT.match(field):
            return "swift-subject", []
        return "no-name", []
    absent = [t for t in toks if t not in present]
    if absent:
        return "absent", absent
    undeclared = [t for t in toks if t not in declared]
    if undeclared:
        return "present-not-declared", undeclared
    return "declared", []


def census(args) -> int:
    records_dir = args.records if os.path.isabs(args.records) else os.path.join(ROOT, args.records)
    bridge_root = args.bridge if os.path.isabs(args.bridge) else os.path.join(ROOT, args.bridge)
    declared, present = bridge_symbols(bridge_root)

    order = ("declared", "present-not-declared", "absent", "swift-subject", "no-name",
             "not-a-bridge-call")
    buckets: dict[str, list] = {k: [] for k in order}
    for fname, i, rec in records(records_dir):
        verdict, bad = classify(rec.get("bridge_function"), declared, present)
        buckets[verdict].append((fname, i, rec.get("test_name", "?"),
                                 rec.get("bridge_function"), bad))

    total = sum(len(v) for v in buckets.values())
    print("census-766-bridge-functions: kernel-parity records whose bridge_function resolves")
    print(f"  bridge names declared in headers: {len(declared)}")
    print(f"  bridge names present anywhere:    {len(present)}")
    print(f"  records read: {total}")
    for k in order:
        print(f"    {k:22s} {len(buckets[k])}")

    if args.require_records and (total == 0 or not declared):
        print("  ERROR: --require-records and nothing was examined. The parity records live on "
              "v5.0.0-766-execution; a clean report over an empty directory is a false green.",
              file=sys.stderr)
        return 2

    findings = buckets["absent"] + buckets["no-name"]
    if findings and not args.summary:
        print()
        for fname, i, test, field, bad in findings:
            what = ", ".join(bad) if bad else "(no OCCT-shaped name in the field)"
            print(f"  {fname}[{i}]  {what}")
            print(f"      test: {test}")
            print(f"      field: {field!r}")
    if buckets["swift-subject"] and not args.summary:
        print()
        print("  identifier-shaped but naming no bridge function. Each is either a Swift-side")
        print("  subject that should say so, or a bridge name somebody paraphrased:")
        for fname, i, test, field, _bad in buckets["swift-subject"]:
            print(f"  {fname}[{i}]  {field!r}  ({test})")
    if buckets["present-not-declared"] and not args.summary:
        print()
        print("  present in the bridge but not declared in a header (a helper, a macro, or a")
        print("  record naming an internal rather than the entry point it measured):")
        for fname, i, test, _field, bad in buckets["present-not-declared"]:
            print(f"  {fname}[{i}]  {', '.join(bad)}  ({test})")
    if findings:
        print()
        print("  A record naming a function this repo does not have reports a comparison made")
        print("  against nothing. Adjudicate each: fix the name, or withdraw the record.")
    return 0


def self_test() -> int:
    """Prove the census resolves each field shape, and does not report a correct non-resolution."""
    declared = {"OCCTShapeVolume", "OCCTEdgeGetParameterBounds", "OCCTEdgeGetPointAtParam"}
    present = declared | {"OCCTInternalHelper"}
    cases = []

    def v(field):
        return classify(field, declared, present)[0]

    # 1. A declared name resolves.
    cases.append(("a declared bridge name resolves", v("OCCTShapeVolume") == "declared"))

    # 2. A name in no bridge file at all is the finding. This is #2198's shape.
    cases.append(("an absent name is reported", v("OCCTShapeDoesNotExist") == "absent"))

    # 3. A compound field resolves every token, not just the first. Without this the second half
    #    of `A + B` would never be checked.
    cases.append(("a compound field resolves both names",
                  v("OCCTEdgeGetParameterBounds + OCCTEdgeGetPointAtParam "
                    "(circle recovered in Swift)") == "declared"))
    cases.append(("a compound field reports the absent half",
                  v("OCCTEdgeGetParameterBounds + OCCTNope") == "absent"))

    # 4. A pure-Swift record is correct and must not be reported.
    cases.append(("a pure-Swift field is not a finding",
                  v("none (pure Swift: ConstructionPlane.absolute)") == "not-a-bridge-call"))
    cases.append(("a bare 'none' field is not a finding",
                  v("none: Swift guard in Wire.interpolate") == "not-a-bridge-call"))

    # 5. A field naming nothing at all is reported, because a record with no subject is not
    #    evidence about one.
    cases.append(("a field naming nothing is reported", v("the volume getter") == "no-name"))
    cases.append(("an empty field is reported", v("") == "no-name"))

    # 5b. A `(Swift)` marker and a lowercase bridge internal are both recognised. The first
    #     version of this census read neither: 215 records landed in `no-name`, most of them
    #     correct Swift-side subjects, and one was `occtNearestProjectionOnCurve2d`, a real bridge
    #     helper whose name simply does not start with a capital.
    cases.append(("a (Swift) marker is not a finding",
                  v("ConstructionContext (Swift)") == "not-a-bridge-call"))
    cases.append(("a lowercase occt helper is resolved like any other name",
                  classify("occtHelper", {"occtHelper"}, {"occtHelper"})[0] == "declared"))

    # 5c. A bare Swift symbol path is its own bucket: it names a subject, just not a bridge one.
    cases.append(("a bare Swift symbol path is its own bucket",
                  v("SheetMetal.Builder.build") == "swift-subject"))

    # 6. A name present in the bridge but declared in no header is its own bucket, not a finding
    #    and not silence.
    cases.append(("a present-but-undeclared name is its own bucket",
                  v("OCCTInternalHelper") == "present-not-declared"))

    # 7. A name plus a parenthetical resolves.
    cases.append(("a name with a parenthetical resolves",
                  v("OCCTShapeVolume (radius computed in Swift)") == "declared"))

    # 8. The header declaration parser finds a real declaration shape, and does not mistake a call
    #    in an implementation for one. This is the view assertion: a parser that finds nothing
    #    would report every record as absent, which looks exactly like a broken branch.
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        os.makedirs(os.path.join(d, "include"))
        open(os.path.join(d, "include", "OCCTBridge_X.h"), "w").write(
            "double OCCTShapeGetVolume(OCCTShapeRef shape);\n"
            "OCCTShapeRef OCCTShapeBox(double w, double h, double d);\n")
        open(os.path.join(d, "OCCTBridge_X.mm"), "w").write(
            "double OCCTShapeGetVolume(OCCTShapeRef s) { return OCCTHelperMass(s); }\n")
        dec, pres = bridge_symbols(d)
        cases.append(("header declarations are parsed",
                      dec == {"OCCTShapeGetVolume", "OCCTShapeBox"}))
        cases.append(("an implementation-only name is present but not declared",
                      "OCCTHelperMass" in pres and "OCCTHelperMass" not in dec))

    failures = 0
    for label, ok in cases:
        print(f"  {'PASS' if ok else 'FAIL'}  {label}")
        failures += 0 if ok else 1
    print(f"\n{len(cases) - failures}/{len(cases)} self-test cases pass")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--records", default=DEFAULT_RECORDS,
                    help="directory of kernel-parity JSON files")
    ap.add_argument("--bridge", default=DEFAULT_BRIDGE, help="the bridge source root to resolve in")
    ap.add_argument("--summary", action="store_true", help="counts only, no per-record list")
    ap.add_argument("--require-records", action="store_true",
                    help="exit 2 rather than report clean when nothing was examined (#2098)")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    return self_test() if args.self_test else census(args)


if __name__ == "__main__":
    sys.exit(main())
