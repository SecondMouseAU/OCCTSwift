#!/usr/bin/env python3
"""Derive the GD&T Swift enums from OCCT's own XCAFDimTolObjects headers, and gate the
hand-transcription against them (#996).

Seven public enums in `Sources/OCCTSwift/GDTRead.swift` are hand-transcribed, member for member and
ordinal for ordinal, from seven headers in the pinned kernel:

    Document.DimensionType          <- XCAFDimTolObjects_DimensionType.hxx          (32)
    Document.GeomToleranceType      <- XCAFDimTolObjects_GeomToleranceType.hxx      (16)
    Document.DimensionFormVariance  <- XCAFDimTolObjects_DimensionFormVariance.hxx  (29)
    Document.DimensionGrade         <- XCAFDimTolObjects_DimensionGrade.hxx         (20)
    Document.DimensionQualifier     <- XCAFDimTolObjects_DimensionQualifier.hxx     (4)
    Document.AngularQualifier       <- XCAFDimTolObjects_AngularQualifier.hxx       (4)
    Document.DimensionModifier      <- XCAFDimTolObjects_DimensionModif.hxx         (24)

Nothing checked them. The bridge casts OCCT's enum straight to int32 with no sentinel and no remap,
and `dimension(at:)` returns nil when `rawValue:` fails, so the moment OCCT adds a member the reader
silently starts dropping dimensions of that type. Both enums have grown across OCCT versions.

    python3 Scripts/derive-gdt-enums.py                   # print the manifest summary
    python3 Scripts/derive-gdt-enums.py --list            # print every member and its Swift case
    python3 Scripts/derive-gdt-enums.py --verify          # exit 1 if Swift and the manifest differ
    python3 Scripts/derive-gdt-enums.py --reverify-headers  # exit 1 if manifest and headers differ
    python3 Scripts/derive-gdt-enums.py --write-manifest  # rewrite the manifest from the headers
    python3 Scripts/derive-gdt-enums.py --self-test       # prove each failure mode is caught

WHY A COMMITTED MANIFEST AND NOT A DIRECT HEADER READ. `ci.yml`'s `gate-scripts` job runs on
`ubuntu-latest` with no `Libraries/OCCT.xcframework`, so a gate that reads the headers directly
would report SKIPPED on every CI run, which is the same as not existing. `Scripts/occt-gdt-enums.txt`
holds the derivation, checked in, and `--verify` compares Swift against it with no kernel present.
`--reverify-headers` is the other half and needs the kernel: it is what catches an OCCT bump, and it
is why the manifest is a derivation rather than a second hand-written list. Same split, and the same
reason, as `Scripts/occt-packages.txt` and `census-doc-occt-attribution.py`.

WHICH ENUMS ARE GATED, AND WHICH ARE NOT. `XCAFDimTolObjects` ships more transcribable enums than
these seven: `GeomToleranceModif`, `GeomToleranceMatReqModif`, `GeomToleranceZoneModif`,
`GeomToleranceTypeValue`, `ToleranceZoneAffectedPlane`, `DatumSingleModif`, `DatumModifWithValue`,
`DatumTargetType`. None of those is bound in Swift today, because the accessors that would return
them are not wrapped (#1004 enumerates that surface, and the first three entries of the table above
are the part of it #1004's dimension PR wrapped). Gating an enum nothing returns would assert a
correspondence that does not exist yet, so this gate covers exactly the ones that are bound, and
`--reverify-headers` reports the unbound ones so the list is visible rather than implied.

The Swift enum's own name is free: `swift_case_name` strips the OCCT *type* prefix off each member,
so `DimensionModifier` may be spelled out in Swift while its members come from
`XCAFDimTolObjects_DimensionModif_*`. Only the member names and ordinals are gated.

Exits 2 if run from anywhere but the repo root, matching the other gate scripts (#625). `--self-test`
runs on synthetic fixtures and does not need the repo tree, so it is exempt.
"""

import argparse
import os
import re
import sys

SWIFT_FILE = os.path.join("Sources", "OCCTSwift", "GDTRead.swift")
MANIFEST = os.path.join("Scripts", "occt-gdt-enums.txt")
OCCT_HEADERS = os.path.join("Libraries", "OCCT.xcframework", "macos-arm64", "Headers")

# Swift enum name -> (OCCT enum type, header stem). The header stem is also the OCCT member prefix.
BOUND = {
    "DimensionType": "XCAFDimTolObjects_DimensionType",
    "GeomToleranceType": "XCAFDimTolObjects_GeomToleranceType",
    "DimensionFormVariance": "XCAFDimTolObjects_DimensionFormVariance",
    "DimensionGrade": "XCAFDimTolObjects_DimensionGrade",
    "DimensionQualifier": "XCAFDimTolObjects_DimensionQualifier",
    "AngularQualifier": "XCAFDimTolObjects_AngularQualifier",
    "DimensionModifier": "XCAFDimTolObjects_DimensionModif",
}

# Every XCAFDimTolObjects enum header, so --reverify-headers can name the unbound ones rather than
# leaving "which enums exist" to the reader's memory. Derived by listing the directory, filtered to
# headers whose body is a bare `enum`, which is what makes one transcribable at all.
ALL_ENUM_HEADERS_GLOB = "XCAFDimTolObjects_"

# `  XCAFDimTolObjects_DimensionType_Location_None,` or `... = 3,` inside an enum body.
MEMBER = re.compile(r"^\s*(XCAFDimTolObjects_[A-Za-z0-9_]+?)\s*(?:=\s*(-?\d+))?\s*,?\s*$")
ENUM_OPEN = re.compile(r"^\s*enum\s+(XCAFDimTolObjects_[A-Za-z0-9_]+)\s*$")
# `    public enum DimensionType: Int32, Sendable, CaseIterable {`
SWIFT_ENUM_OPEN = re.compile(r"^\s*public enum ([A-Za-z0-9_]+)\s*:\s*Int32\b[^{]*\{\s*$")
# `        case sizeDiameter = 15`
SWIFT_CASE = re.compile(r"^\s*case ([A-Za-z0-9_]+)\s*=\s*(-?\d+)\s*$")


def parse_occt_enum(text):
    """Members of the first bare `enum XCAFDimTolObjects_*` in `text`, as [(name, ordinal)].

    OCCT writes these without explicit ordinals, so the ordinal is the position unless a member
    states one. Reading positions rather than requiring `= n` is what lets this work at all: not one
    of the bound headers spells a single ordinal out.
    """
    members = []
    depth = 0
    inside = False
    next_ordinal = 0
    for line in text.splitlines():
        if not inside:
            if ENUM_OPEN.match(line):
                inside = True
            continue
        if "{" in line:
            depth += line.count("{")
            continue
        if "}" in line:
            break
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        m = MEMBER.match(line)
        if not m:
            continue
        name, explicit = m.group(1), m.group(2)
        ordinal = int(explicit) if explicit is not None else next_ordinal
        members.append((name, ordinal))
        next_ordinal = ordinal + 1
    return members


def parse_swift_enums(text):
    """{swift enum name: [(case name, raw value)]} for every `public enum X: Int32` in `text`."""
    enums = {}
    current = None
    for line in text.splitlines():
        opened = SWIFT_ENUM_OPEN.match(line)
        if opened:
            current = opened.group(1)
            enums[current] = []
            continue
        if current is None:
            continue
        case = SWIFT_CASE.match(line)
        if case:
            enums[current].append((case.group(1), int(case.group(2))))
            continue
        # A `}` at the enum's own indentation closes it. Anything shallower than a case line and
        # containing a brace ends the enum body; nested types are not used inside the bound enums.
        if line.strip() == "}":
            current = None
    return enums


def swift_case_name(occt_member, occt_type):
    """`XCAFDimTolObjects_DimensionType_Size_Diameter` -> `sizeDiameter`.

    The suffix after the enum type's own name is lowerCamelCased on its underscores, with one extra
    rule: an all-caps token lowercases whole rather than only in its first character, so the ISO 286
    position letters (`CD`, `JS`, `ZC`) and grades (`IT01`, `IT7`) come out as `cd`, `js`, `zc`,
    `it01`, `it7` rather than `cD`, `iT01`. That rule is what the transcription already follows; the
    gate re-derives it rather than trusting a stored pairing, so a renamed Swift case is a mismatch
    rather than a silently accepted alias.
    """
    if occt_member.startswith(occt_type + "_"):
        suffix = occt_member[len(occt_type) + 1:]
    else:
        suffix = occt_member
    parts = [p for p in suffix.split("_") if p]
    if not parts:
        return suffix
    out = []
    for position, part in enumerate(parts):
        token = part.lower() if part.upper() == part else part
        if position == 0:
            token = token[0].lower() + token[1:]
        else:
            token = token[0].upper() + token[1:]
        out.append(token)
    return "".join(out)


def read_manifest(text):
    """{swift enum name: [(swift case, ordinal, occt member)]} from the manifest's own format."""
    manifest = {}
    current = None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1]
            manifest[current] = []
            continue
        if current is None:
            continue
        parts = line.split()
        if len(parts) != 3:
            continue
        manifest[current].append((parts[0], int(parts[1]), parts[2]))
    return manifest


def derive_from_headers(header_dir):
    """{swift enum name: [(swift case, ordinal, occt member)]} for the four bound enums."""
    derived = {}
    for swift_name, occt_type in sorted(BOUND.items()):
        path = os.path.join(header_dir, occt_type + ".hxx")
        with open(path, errors="ignore") as fh:
            members = parse_occt_enum(fh.read())
        derived[swift_name] = [
            (swift_case_name(name, occt_type), ordinal, name) for name, ordinal in members
        ]
    return derived


def compare(expected, actual):
    """Rows where `expected` and `actual` disagree, as (enum, kind, detail) triples.

    `expected` is {enum: [(case, ordinal, occt)]}, `actual` is {enum: [(case, ordinal)]}. Order
    matters: a reordered enum is a defect even when the set of cases is unchanged, since the raw
    values are what cross the bridge.
    """
    problems = []
    for name in sorted(set(expected) | set(actual)):
        if name not in actual:
            problems.append((name, "MISSING-ENUM", "declared by OCCT, absent from Swift"))
            continue
        if name not in expected:
            continue  # A Swift enum this gate does not claim to cover; not a defect.
        want = [(case, ordinal) for case, ordinal, _ in expected[name]]
        have = actual[name]
        if len(want) != len(have):
            problems.append(
                (name, "COUNT", f"OCCT declares {len(want)} members, Swift has {len(have)} cases"))
        for index in range(min(len(want), len(have))):
            if want[index] != have[index]:
                problems.append(
                    (name, "MEMBER",
                     f"position {index}: OCCT {want[index][0]} = {want[index][1]}, "
                     f"Swift {have[index][0]} = {have[index][1]}"))
    return problems


def write_manifest(derived, path):
    with open(path, "w") as fh:
        fh.write("# GD&T enum members, derived from the pinned kernel's own XCAFDimTolObjects\n")
        fh.write("# headers. Columns: swift case, ordinal, OCCT member (#996).\n")
        fh.write("# Re-derive: python3 Scripts/derive-gdt-enums.py --write-manifest\n")
        fh.write("# Swift check: --verify (no kernel needed, this is what CI gates).\n")
        fh.write("# Drift check: --reverify-headers (needs Libraries/, skipped in CI).\n")
        for name in sorted(derived):
            fh.write(f"[{name}]\n")
            for case, ordinal, occt in derived[name]:
                fh.write(f"{case} {ordinal} {occt}\n")


# --- self-test ---------------------------------------------------------------------------------

_HEADER = """
#ifndef _XCAFDimTolObjects_Thing_HeaderFile
#define _XCAFDimTolObjects_Thing_HeaderFile

//! Defines a thing
enum XCAFDimTolObjects_Thing
{
  XCAFDimTolObjects_Thing_None,
  XCAFDimTolObjects_Thing_Size_Diameter,
  XCAFDimTolObjects_Thing_ZC
};

#endif
"""

_HEADER_EXPLICIT = """
enum XCAFDimTolObjects_Thing
{
  XCAFDimTolObjects_Thing_None = 4,
  XCAFDimTolObjects_Thing_Next
};
"""

_SWIFT_OK = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
        case zc = 2
    }
}
"""

_SWIFT_MISSING = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
    }
}
"""

_SWIFT_REORDERED = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case zc = 1
        case sizeDiameter = 2
    }
}
"""

_SWIFT_RENAMED = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case diameter = 1
        case zc = 2
    }
}
"""

_SWIFT_WRONG_ORDINAL = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
        case zc = 3
    }
}
"""

_SWIFT_EXTRA_ENUM = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
        case zc = 2
    }

    public enum Unrelated: Int32, Sendable {
        case only = 0
    }
}
"""

_SWIFT_ABSENT = """
extension Document {
    public struct Thing: Sendable {
        public let value: Int
    }
}
"""

_SWIFT_TRAILING_INT_ENUM = """
extension Document {
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
        case zc = 2
    }

    public enum Unrelated: Int, Sendable {
        case seven = 7
    }
}
"""

_SWIFT_COMMENT_TRAP = """
extension Document {
    /// A thing.
    ///
    /// ```swift
    /// case sizeDiameter = 99
    /// ```
    public enum Thing: Int32, Sendable, CaseIterable {
        case none = 0
        case sizeDiameter = 1
        case zc = 2
    }
}
"""


def _thing_expected(header=_HEADER):
    members = parse_occt_enum(header)
    return {"Thing": [(swift_case_name(n, "XCAFDimTolObjects_Thing"), o, n) for n, o in members]}


SELF_TEST = [
    (
        "a faithful transcription reports nothing",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_OK)),
        lambda problems: not problems,
    ),
    (
        "a member OCCT added and Swift lacks is a COUNT defect",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_MISSING)),
        lambda problems: any(kind == "COUNT" for _, kind, _ in problems),
    ),
    (
        "a reordered enum is a MEMBER defect even at the same count",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_REORDERED)),
        lambda problems: any(kind == "MEMBER" for _, kind, _ in problems),
    ),
    (
        "a renamed case is a MEMBER defect, not a silently accepted alias",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_RENAMED)),
        lambda problems: any(
            kind == "MEMBER" and "diameter" in detail for _, kind, detail in problems),
    ),
    (
        "a case with the wrong raw value is a MEMBER defect",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_WRONG_ORDINAL)),
        lambda problems: any(
            kind == "MEMBER" and "zc = 3" in detail for _, kind, detail in problems),
    ),
    (
        "an unrelated Int32 enum in the same file is not a defect",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_EXTRA_ENUM)),
        lambda problems: not problems,
    ),
    (
        # SWIFT_ENUM_OPEN deliberately matches only `: Int32`, so a later `: Int` enum does not
        # open a new current. Without the `}` close detection its `case seven = 7` would be
        # appended to Thing and report a COUNT defect on a correct file. This is the only case
        # that exercises that guard: nothing in the real GDTRead.swift does today, which is why
        # the guard came back green under removal until this case existed.
        "a trailing non-Int32 raw enum does not leak cases into the previous one",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_TRAILING_INT_ENUM)),
        lambda problems: not problems,
    ),
    (
        "an enum deleted from Swift entirely is a MISSING-ENUM defect",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_ABSENT)),
        lambda problems: any(kind == "MISSING-ENUM" for _, kind, _ in problems),
    ),
    (
        # SWIFT_CASE is anchored at ^ with only leading whitespace before `case`, so a `/// case ...`
        # line in a doc-comment snippet cannot match. Without that anchoring the snippet above would
        # register a fourth case at raw value 99 and turn a correct file into a COUNT defect. The
        # real GDTRead.swift carries exactly this shape in its doc comments.
        "a `case` inside a doc-comment snippet is not a case",
        lambda: compare(_thing_expected(), parse_swift_enums(_SWIFT_COMMENT_TRAP)),
        lambda problems: not problems,
    ),
    (
        # Not one of the bound headers spells an ordinal out, so position-counting is the only
        # path the gate ever takes against the tree. This is the case that proves the other branch,
        # explicit `= n`, works and continues from the stated value rather than from the position.
        "an explicit ordinal is honoured, and the next member continues from it",
        lambda: parse_occt_enum(_HEADER_EXPLICIT),
        lambda members: members == [
            ("XCAFDimTolObjects_Thing_None", 4), ("XCAFDimTolObjects_Thing_Next", 5)],
    ),
    (
        # Four shapes, one per branch of the rule, all taken from the real headers. The multi-word
        # suffix distinguishes camel case from a plain lowercase (`sizeDiameter`, not
        # `size_diameter`); the all-caps tokens are the ones a first-character-only rule gets wrong
        # (`zc` and `it01`, not `zC` and `iT01`); the mixed pair proves the tail is still capitalised.
        "the OCCT-member to Swift-case rule handles each token shape the bound headers use",
        lambda: (
            swift_case_name("XCAFDimTolObjects_Thing_Size_Diameter", "XCAFDimTolObjects_Thing"),
            swift_case_name("XCAFDimTolObjects_Thing_ZC", "XCAFDimTolObjects_Thing"),
            swift_case_name("XCAFDimTolObjects_Thing_IT01", "XCAFDimTolObjects_Thing"),
            swift_case_name("XCAFDimTolObjects_Thing_Location_None", "XCAFDimTolObjects_Thing"),
        ),
        lambda names: names == ("sizeDiameter", "zc", "it01", "locationNone"),
    ),
    (
        # The manifest is what CI compares against, so its round trip has to be exact: a parser that
        # dropped the ordinal column would make every --verify run vacuously green.
        "the manifest format round-trips a derivation exactly",
        lambda: read_manifest(
            "# comment\n[Thing]\nnone 0 XCAFDimTolObjects_Thing_None\n"
            "sizeDiameter 1 XCAFDimTolObjects_Thing_Size_Diameter\n"
            "zc 2 XCAFDimTolObjects_Thing_ZC\n"),
        lambda parsed: parsed == _thing_expected(),
    ),
]


def self_test():
    failed = 0
    for name, run, check in SELF_TEST:
        ok = check(run())
        failed += not ok
        print(f"  {'ok  ' if ok else 'FAIL'}  {name}")
    total = len(SELF_TEST)
    print(f"{total - failed}/{total} cases correct")
    return 1 if failed else 0


def unbound_enum_headers(header_dir):
    """XCAFDimTolObjects headers that declare a bare enum and are not among the four bound ones."""
    bound_types = set(BOUND.values())
    unbound = []
    for filename in sorted(os.listdir(header_dir)):
        if not filename.startswith(ALL_ENUM_HEADERS_GLOB) or not filename.endswith(".hxx"):
            continue
        stem = filename[:-4]
        if stem in bound_types:
            continue
        with open(os.path.join(header_dir, filename), errors="ignore") as fh:
            members = parse_occt_enum(fh.read())
        if members:
            unbound.append((stem, len(members)))
    return unbound


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true", help="print every member and its Swift case")
    ap.add_argument("--verify", action="store_true",
                    help="exit 1 unless Swift matches the committed manifest")
    ap.add_argument("--reverify-headers", action="store_true",
                    help="exit 1 unless the manifest matches the pinned headers (needs Libraries/)")
    ap.add_argument("--write-manifest", action="store_true",
                    help="rewrite the manifest from the pinned headers")
    ap.add_argument("--self-test", action="store_true", help="prove each failure mode is caught")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not os.path.isfile(SWIFT_FILE) or not os.path.isfile(MANIFEST):
        print(f"error: run from the repo root (expected {SWIFT_FILE} and {MANIFEST})",
              file=sys.stderr)
        return 2

    if args.write_manifest:
        if not os.path.isdir(OCCT_HEADERS):
            print(f"{OCCT_HEADERS} not present; cannot derive.", file=sys.stderr)
            return 2
        write_manifest(derive_from_headers(OCCT_HEADERS), MANIFEST)
        print(f"manifest written to {MANIFEST}")
        return 0

    with open(MANIFEST) as fh:
        manifest = read_manifest(fh.read())
    with open(SWIFT_FILE) as fh:
        swift = parse_swift_enums(fh.read())

    if args.reverify_headers:
        if not os.path.isdir(OCCT_HEADERS):
            print(f"Header re-derivation SKIPPED: {OCCT_HEADERS} not present "
                  "(expected in CI and in a fresh clone).")
            return 0
        derived = derive_from_headers(OCCT_HEADERS)
        drift = compare(derived, {k: [(c, o) for c, o, _ in v] for k, v in manifest.items()})
        for name, kind, detail in drift:
            print(f"  {kind:12s} {name}: {detail}", file=sys.stderr)
        for stem, count in unbound_enum_headers(OCCT_HEADERS):
            print(f"  unbound      {stem} ({count} members), no Swift enum, see #1004")
        if drift:
            print("\nThe manifest no longer matches the pinned headers. Re-run with "
                  "--write-manifest, then bring GDTRead.swift's enums into line with it.",
                  file=sys.stderr)
            return 1
        print("manifest matches the pinned headers")
        return 0

    problems = compare(manifest, swift)

    if args.list:
        for name in sorted(manifest):
            for case, ordinal, occt in manifest[name]:
                print(f"{name}\t{case}\t{ordinal}\t{occt}")
    else:
        for name in sorted(manifest):
            have = len(swift.get(name, []))
            print(f"  {len(manifest[name]):5d}  Document.{name}  ({BOUND[name]}), swift: {have}")

    print(f"\nenums: {len(manifest)}   "
          f"members: {sum(len(v) for v in manifest.values())}   problems: {len(problems)}")

    for name, kind, detail in problems:
        print(f"  {kind:12s} {name}: {detail}", file=sys.stderr)

    if args.verify and problems:
        print(
            "\nThe transcription has drifted from the manifest:\n"
            "  COUNT means the Swift enum has a different number of cases than OCCT declares.\n"
            "  MEMBER means a case name or raw value does not match the OCCT member at that\n"
            "  position; raw values cross the bridge unremapped, so order is load-bearing.\n"
            "  MISSING-ENUM means the Swift enum is gone entirely.\n"
            "If the pinned kernel moved, run --reverify-headers and then --write-manifest.",
            file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
