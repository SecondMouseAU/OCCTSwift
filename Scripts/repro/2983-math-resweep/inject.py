#!/usr/bin/env python3
"""Apply or restore the #2983 Math re-sweep injections (Swift-side splices, gated at runtime).

usage: inject.py apply | restore

`apply` copies `MathInjSwitch.swift.txt` to Sources/OCCTSwift/MathInjSwitch.swift and splices a
`MATH_INJ=<name>` gate into the wrappers the seven Math test files reach. Every anchor is resolved
to exactly one match BEFORE any file is written. `restore` is `git checkout --` plus removing the
switch file; never a reverse replacement (okf/references/injection-sweep-mechanics.md).
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
SRC = ROOT / "Sources/OCCTSwift"
HERE = pathlib.Path(__file__).resolve().parent
J = lambda n: f'injOn("{n}")'

# (file, anchor text that must occur exactly once, replacement)
EDITS = [
    # ---- Period
    ("Period.swift", "OCCTPeriodTotalSeconds(sec, usec, &s, &u)\n        return Int(s)",
     f"OCCTPeriodTotalSeconds(sec, usec, &s, &u)\n        return Int(s) + ({J('PER_TOTSEC')} ? 1 : 0)"),
    ("Period.swift", "OCCTPeriodTotalSeconds(sec, usec, &s, &u)\n        return Int(u)",
     f"OCCTPeriodTotalSeconds(sec, usec, &s, &u)\n        return {J('PER_TOTUS')} ? 0 : Int(u)"),
    ("Period.swift", "Int(c.days), Int(c.hours), Int(c.minutes), Int(c.seconds),",
     f"Int(c.days), {J('PER_COMP_SWAP')} ? Int(c.minutes) : Int(c.hours), {J('PER_COMP_SWAP')} ? Int(c.hours) : Int(c.minutes), Int(c.seconds),"),
    ("Period.swift", "Int(c.milliseconds), Int(c.microseconds)\n        )",
     f"{J('PER_COMP_NOMS')} ? 0 : Int(c.milliseconds), Int(c.microseconds)\n        )"),
    ("Period.swift", "OCCTPeriodAdd(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)\n        return Period(sec: s, usec: u)",
     f"OCCTPeriodAdd(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)\n        if {J('PER_ADD_LHS')} {{ return lhs }}\n        return Period(sec: s, usec: u)"),
    ("Period.swift", "OCCTPeriodSubtract(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)\n        return Period(sec: s, usec: u)",
     f"OCCTPeriodSubtract(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u)\n        if {J('PER_SUB_LHS')} {{ return lhs }}\n        if {J('PER_SUB_AS_ADD')} {{ OCCTPeriodAdd(lhs.sec, lhs.usec, rhs.sec, rhs.usec, &s, &u) }}\n        if {J('PER_SUB_REVERSED')} {{ OCCTPeriodSubtract(rhs.sec, rhs.usec, lhs.sec, lhs.usec, &s, &u) }}\n        return Period(sec: s, usec: u)"),
    ("Period.swift", "OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) == 0",
     f"{J('PER_EQ_TRUE')} ? true : ({J('PER_EQ_SEC')} ? lhs.sec == rhs.sec : OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) == 0)"),
    ("Period.swift", "OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) < 0",
     f"{J('PER_LT_FALSE')} ? false : ({J('PER_LT_SEC')} ? lhs.sec < rhs.sec : ({J('PER_LT_LE')} ? OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) <= 0 : OCCTPeriodCompare(lhs.sec, lhs.usec, rhs.sec, rhs.usec) < 0))"),
    ("Period.swift", "        var s: Int32 = 0\n        var u: Int32 = 0\n        guard\n            OCCTPeriodCreate(",
     f"        if {J('PER_INIT_NIL')} {{ return nil }}\n        var s: Int32 = 0\n        var u: Int32 = 0\n        guard\n            OCCTPeriodCreate("),
    ("Period.swift", "                Int32(days), Int32(hours), Int32(minutes), Int32(seconds),\n                Int32(milliseconds), Int32(microseconds), &s, &u)",
     f"                {J('PER_INIT_NODAYS')} ? 0 : Int32(days), Int32(hours), Int32(minutes), Int32(seconds),\n                Int32(milliseconds), Int32(microseconds), &s, &u)"),
    ("Period.swift", "        guard OCCTPeriodCreateFromSeconds(Int32(totalSeconds), Int32(microseconds), &s, &u) else {",
     f"        guard OCCTPeriodCreateFromSeconds(Int32(totalSeconds), {J('PER_SECS_NOUS')} ? 0 : Int32(microseconds), &s, &u) else {{"),
    # ---- Shape+Math transforms
    ("Shape+Math.swift", "    public func transformed(matrix: Matrix12Grouped) -> Shape? {\n",
     f"    public func transformed(matrix: Matrix12Grouped) -> Shape? {{\n        if {J('TRF_GROUPED_IDENT')} {{ return self }}\n        if {J('TRF_GROUPED_NIL')} {{ return nil }}\n"),
    ("Shape+Math.swift", "    public func gTransformed(matrix: TransformMatrix3D) -> Shape? {\n",
     f"    public func gTransformed(matrix: TransformMatrix3D) -> Shape? {{\n        if {J('TRF_GT_IDENT')} {{ return self }}\n        if {J('TRF_GT_NIL')} {{ return nil }}\n"),
    ("Shape+Math.swift", "    public func transformed(byMatrix matrix: TransformMatrix3D) -> Shape? {\n",
     f"    public func transformed(byMatrix matrix: TransformMatrix3D) -> Shape? {{\n        if {J('TRF_BYM_IDENT')} {{ return self }}\n        if {J('TRF_BYM_NIL')} {{ return nil }}\n"),
    ("Shape+Math.swift", "            v[4], v[5], v[6], v[7],\n            v[8], v[9], v[10], v[11],\n            &result)",
     f"            v[4], v[5], v[6], {J('TRF_BYM_TXONLY')} ? 0 : v[7],\n            v[8], v[9], v[10], {J('TRF_BYM_TXONLY')} ? 0 : v[11],\n            &result)"),
    ("Shape+Math.swift", "            v[0], v[1], v[2], v[3],\n            v[4], v[5], v[6], v[7],",
     f"            {J('TRF_BYM_NOMIRROR')} ? abs(v[0]) : v[0], v[1], v[2], v[3],\n            v[4], v[5], v[6], v[7],"),
    ("Shape+Math.swift", "        OCCTShapeTransformIsNegative(handle)",
     f"        {J('TRF_NEG_FALSE')} ? false : ({J('TRF_NEG_TRUE')} ? true : OCCTShapeTransformIsNegative(handle))"),
    # ---- TransformFactory
    ("TransformFactory.swift", "    values.count == 12 ? values : nil",
     f"    values.count == 12 ? values : ({J('TRF_VALIDATE_LONG')} && values.count == 13 ? Array(values.prefix(12)) : ({J('TRF_VALIDATE_ANY')} && values.count > 3 ? values : nil))"),
    ("TransformFactory.swift", "            values[0], values[1], values[2],\n            values[4], values[5], values[6],\n            values[8], values[9], values[10],\n            values[3], values[7], values[11],\n        ])!",
     f"            values[0], values[1], values[2],\n            values[4], values[5], values[6],\n            values[8], values[9], values[10],\n            values[3], values[7], values[11],\n        ].enumerated().map {{ {J('TRF_GROUPED_ID')} ? values[$0.offset] : $0.element }})!"),
    ("TransformFactory.swift", "            values[0], values[1], values[2], values[9],\n            values[3], values[4], values[5], values[10],\n            values[6], values[7], values[8], values[11],\n        ])!",
     f"            values[0], values[1], values[2], values[9],\n            values[3], values[4], values[5], values[10],\n            values[6], values[7], values[8], values[11],\n        ].enumerated().map {{ {J('TRF_INTERLEAVED_ID')} ? values[$0.offset] : $0.element }})!"),
    ("TransformUtils.swift", "        return Matrix3x4(values: [a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34])\n    }\n}",
     f"        if {J('TRF_TRSF_SIGN')} {{ a14 = -a14; a24 = -a24; a34 = -a34 }}\n        return Matrix3x4(values: [a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34])\n    }}\n}}"),
    ("Shape+Topology.swift", "        guard matrix.count >= 12 else { return nil }\n        guard\n            let ref = matrix.withUnsafeBufferPointer({ buf in\n                OCCTShapeLocated(",
     f"        guard matrix.count >= 12 else {{ return nil }}\n        if {J('TRF_LOCATED_IDENT')} {{ return self }}\n        guard\n            let ref = matrix.withUnsafeBufferPointer({{ buf in\n                OCCTShapeLocated("),
    # ---- MathSolver (solveSystem only; solveSystemNewton is a different anchor)
    ("MathSolver.swift", "OCCTMathFunctionSetRoot(\n            Int32(variables), Int32(equations),\n            valCallback, derivCallback, ptr,\n            startPoint, tolerance, Int32(maxIterations), &result)\n        return ok ? result : nil",
     f"OCCTMathFunctionSetRoot(\n            Int32(variables), Int32(equations),\n            valCallback, derivCallback, ptr,\n            startPoint, tolerance, Int32(maxIterations), &result)\n        if {J('SYS_START')} {{ return ok ? startPoint : nil }}\n        if {J('SYS_NIL')} {{ return nil }}\n        if {J('SYS_REVERSED')} {{ return ok ? result.reversed() : nil }}\n        if {J('SYS_LOOSE')} {{ return ok ? result.map {{ $0 * 1.001 }} : nil }}\n        return ok ? result : nil"),
    ("MathSolver.swift", "            &result, &minimum)\n        return ok ? (result, minimum) : nil\n    }\n}\n\nextension MathSolver {\n\n    /// Spherical linear",
     f"            &result, &minimum)\n        if {J('NEW_START')} {{ return ok ? (startPoint, minimum) : nil }}\n        if {J('NEW_NIL')} {{ return nil }}\n        if {J('NEW_REVERSED')} {{ return ok ? (result.reversed(), minimum) : nil }}\n        if {J('NEW_LOOSE')} {{ return ok ? (result.map {{ $0 * 1.001 }}, minimum) : nil }}\n        if {J('NEW_MIN')} {{ return ok ? (result, minimum + 0.01) : nil }}\n        return ok ? (result, minimum) : nil\n    }}\n}}\n\nextension MathSolver {{\n\n    /// Spherical linear"),
    # ---- MathPolynomialRoots
    ("MathLibrary.swift", "        if n < 0 { return nil }\n        return Array(roots.prefix(Int(n)))\n    }\n}\n\n/// Jacobi eigenvalue solver",
     f"        if n < 0 {{ return nil }}\n        if {J('POLY_NIL')} {{ return nil }}\n        if {J('POLY_EMPTY')} {{ return [] }}\n        if {J('POLY_DROP_LAST')} {{ return Array(roots.prefix(max(Int(n) - 1, 0))) }}\n        if {J('POLY_NEG')} {{ return roots.prefix(Int(n)).map {{ -$0 }} }}\n        if {J('POLY_EXTRA')} {{ return Array(roots.prefix(Int(n))) + [0.0] }}\n        return Array(roots.prefix(Int(n)))\n    }}\n}}\n\n/// Jacobi eigenvalue solver"),
    # ---- TrigRoots
    ("TrigRoots.swift", "        OCCTTrigRootsInfinite(a, b, c, d, e, inf, sup)",
     f"        {J('TRIG_INF_TRUE')} ? true : ({J('TRIG_INF_FALSE')} ? false : OCCTTrigRootsInfinite(a, b, c, d, e, inf, sup))"),
]


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    files = sorted({f for f, _, _ in EDITS})
    if mode == "restore":
        subprocess.check_call(["git", "checkout", "--"] + [f"Sources/OCCTSwift/{f}" for f in files], cwd=ROOT)
        (SRC / "MathInjSwitch.swift").unlink(missing_ok=True)
        return
    if mode != "apply":
        sys.exit(__doc__)
    texts = {f: (SRC / f).read_text() for f in files}
    for f, anchor, _ in EDITS:
        n = texts[f].count(anchor)
        if n != 1:
            sys.exit(f"anchor matched {n} times in {f}: {anchor[:70]!r}")
    for f, anchor, new in EDITS:
        texts[f] = texts[f].replace(anchor, new)
    for f, t in texts.items():
        (SRC / f).write_text(t)
    (SRC / "MathInjSwitch.swift").write_text((HERE / "MathInjSwitch.swift.txt").read_text())
    print(f"applied {len(EDITS)} edits")


main()
