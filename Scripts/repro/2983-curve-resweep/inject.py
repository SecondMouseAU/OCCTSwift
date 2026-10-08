#!/usr/bin/env python3
"""Apply (or check) the tracked-source injections of the #2983 Curve re-sweep.

usage: python3 Scripts/repro/2983-curve-resweep/inject.py apply|status

Almost everything is injected by SHADOWING bridge functions from Swift (`SweepCurveShadow.swift.txt`,
copied in as `Sources/OCCTSwift/SweepCurveShadow.swift`), which needs no edit to a tracked file.
The Swift-side logic a shadow cannot reach is edited here behind `SweepCurveGate`:

  * `Sampling.swift`: the ceiling, `requested(_:atLeast:)` and `impliedCount(length:spacing:)`
  * `ArcLengthCurveAdaptor.swift`: `sampledPoints` and `points(spacing:)`
  * `LawFunction.swift`: the retry-on-truncation loop of both knot-splitting readers

Every anchor is asserted unique before anything is written. Restore with `git checkout --` on the
three files and `rm` of the shadow, then REBUILD UNTIL THE BUNDLE HOLDS NO MARKER
(`strings <bundle> | grep -c SWEEP_CURVE_SWITCH`), per okf/references/injection-sweep-mechanics.md.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
SRC = ROOT / "Sources/OCCTSwift"
G = "SweepCurveGate.on"

EDITS = {
    "Sampling.swift": [
        (
            "    public static let maximumSampleCount = 10_000_000\n",
            f'    public static let maximumSampleCount = {G}("SMP_CEILING_PLUS1") ? 10_000_001 : 10_000_000\n',
        ),
        (
            "        guard count >= minimum, count <= maximumSampleCount else { return nil }\n"
            "        return count\n",
            f"""        let lo = {G}("SMP_REQ_MIN_MINUS1") ? minimum - 1 : ({G}("SMP_REQ_MIN_PLUS1") ? minimum + 1 : minimum)
        let hi = {G}("SMP_REQ_CEIL_MINUS1") ? maximumSampleCount - 1 : ({G}("SMP_REQ_CEIL_PLUS1") ? maximumSampleCount + 1 : maximumSampleCount)
        if {G}("SMP_REQ_CLAMP") {{
            guard count >= lo else {{ return nil }}
            return Swift.min(count, hi)
        }}
        guard count >= lo, count <= hi else {{ return nil }}
        return count
""",
        ),
        (
            "        guard spacing > 0, length > 0 else { return nil }\n"
            "        let implied = (length / spacing).rounded() + 1\n"
            "        guard implied <= Double(maximumSampleCount) else { return nil }\n"
            "        return max(2, Int(implied))\n",
            f"""        if {G}("SMP_IMP_SPACING_GE0") {{
            guard spacing >= 0, length > 0 else {{ return nil }}
        }} else if {G}("SMP_IMP_NO_LENGTH_GUARD") {{
            guard spacing > 0 else {{ return nil }}
        }} else {{
            guard spacing > 0, length > 0 else {{ return nil }}
        }}
        var implied = (length / spacing).rounded() + 1
        if {G}("SMP_IMP_FLOOR") {{ implied = (length / spacing).rounded(.down) + 1 }}
        if {G}("SMP_IMP_CEIL") {{ implied = (length / spacing).rounded(.up) + 1 }}
        if {G}("SMP_IMP_NO_PLUS1") {{ implied = (length / spacing).rounded() }}
        if {G}("SMP_IMP_PLUS2") {{ implied = (length / spacing).rounded() + 2 }}
        if {G}("SMP_IMP_CEIL_LT") {{
            guard implied < Double(maximumSampleCount) else {{ return nil }}
        }} else if {G}("SMP_IMP_CEIL_PLUS1") {{
            guard implied <= Double(maximumSampleCount) + 1 else {{ return nil }}
        }} else if {G}("SMP_IMP_NO_CEIL") {{
            // no ceiling at all: the shipped trap, kept below Int.max so the process survives
            guard implied < 4e18 else {{ return nil }}
        }} else {{
            guard implied <= Double(maximumSampleCount) else {{ return nil }}
        }}
        if {G}("SMP_IMP_CLAMP_CEIL") {{ return Swift.min(Int(implied), maximumSampleCount) }}
        return Swift.max({G}("SMP_IMP_FLOOR_1") ? 1 : 2, Int(implied))
""",
        ),
    ],
    "ArcLengthCurveAdaptor.swift": [
        (
            "        guard let count = Sampling.impliedCount(length: length, spacing: spacing) else { return [] }\n"
            "        return points(count: count)\n",
            f"""        guard let count = Sampling.impliedCount(length: length, spacing: spacing) else {{ return [] }}
        if {G}("ADP_SPACING_COUNT_MINUS1") {{ return points(count: count - 1) }}
        if {G}("ADP_SPACING_COUNT_PLUS1") {{ return points(count: count + 1) }}
        return points(count: count)
""",
        ),
        (
            "        guard let count = Sampling.requested(count) else { return [] }\n"
            "        var buffer = [Double](repeating: 0, count: count * 3)\n"
            "        let written = Int(sample(Int32(count), &buffer))\n"
            "        return unpackSIMD3(buffer, count: written)\n",
            f"""        guard let count = Sampling.requested(count) else {{ return [] }}
        var buffer = [Double](repeating: 0, count: count * 3)
        let asked = {G}("ADP_ASK_MINUS1") ? Int32(count - 1) : Int32(count)
        let written = Int(sample(asked, &buffer))
        if {G}("ADP_UNPACK_MINUS1") {{ return unpackSIMD3(buffer, count: written - 1) }}
        if {G}("ADP_UNPACK_ALL") {{ return unpackSIMD3(buffer, count: count) }}
        return unpackSIMD3(buffer, count: written)
""",
        ),
    ],
}

LAW_IDX_OLD = """        var (count, indices) = read(capacity: 100)
        guard count >= 0 else { return [] }
        if count > 100 {
            (count, indices) = read(capacity: count)
            guard count >= 0 else { return [] }
        }
        return indices.prefix(Int(count)).map(Int.init)
"""
LAW_IDX_NEW = f"""        var (count, indices) = read(capacity: 100)
        guard count >= 0 else {{ return [] }}
        if count > 100 && !{G}("LAWSW_IDX_NO_RETRY") {{
            (count, indices) = read(capacity: {G}("LAWSW_IDX_RETRY_MINUS1") ? count - 1 : count)
            guard count >= 0 else {{ return [] }}
        }}
        if {G}("LAWSW_IDX_PREFIX_MINUS1") {{ return indices.prefix(Int(count) - 1).map(Int.init) }}
        if {G}("LAWSW_IDX_ALL_BUFFER") {{ return indices.map(Int.init) }}
        return indices.prefix(Int(count)).map(Int.init)
"""
LAW_PAR_OLD = """        var (count, params) = read(capacity: 100)
        guard count >= 0 else { return [] }
        if count > 100 {
            (count, params) = read(capacity: count)
            guard count >= 0 else { return [] }
        }
        return Array(params.prefix(Int(count)))
"""
LAW_PAR_NEW = f"""        var (count, params) = read(capacity: 100)
        guard count >= 0 else {{ return [] }}
        if count > 100 && !{G}("LAWSW_PAR_NO_RETRY") {{
            (count, params) = read(capacity: {G}("LAWSW_PAR_RETRY_MINUS1") ? count - 1 : count)
            guard count >= 0 else {{ return [] }}
        }}
        if {G}("LAWSW_PAR_PREFIX_MINUS1") {{ return Array(params.prefix(Int(count) - 1)) }}
        if {G}("LAWSW_PAR_ALL_BUFFER") {{ return params }}
        return Array(params.prefix(Int(count)))
"""
EDITS["LawFunction.swift"] = [(LAW_IDX_OLD, LAW_IDX_NEW), (LAW_PAR_OLD, LAW_PAR_NEW)]


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    texts = {n: (SRC / n).read_text() for n in EDITS}
    if mode == "status":
        for n, t in texts.items():
            print(n, "injected:", "SweepCurveGate" in t)
        return
    assert mode == "apply", "usage: inject.py apply|status"
    for n, edits in EDITS.items():
        for old, _ in edits:
            assert texts[n].count(old) == 1, f"{n}: anchor matches {texts[n].count(old)} times:\n{old}"
    for n, edits in EDITS.items():
        t = texts[n]
        for old, new in edits:
            t = t.replace(old, new)
        (SRC / n).write_text(t)
    print("applied")


if __name__ == "__main__":
    main()
