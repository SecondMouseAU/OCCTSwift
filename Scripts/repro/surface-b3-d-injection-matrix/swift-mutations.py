#!/usr/bin/env python3
"""Apply (or, with --revert, remove) four Swift-side mutations of Sources/OCCTSwift/DrawingSymbols.swift.

The DrawingSymbolsTests this PR lifts exercise pure Swift: DrawingAnnotation builds its geometry
without a bridge call, so the bridge-level switches in switches.txt cannot redden them (the matrix
reports 0 of 4, before and after). These mutations are the counterfactual for them. Each is gated on
the same B3_SWITCH environment variable the shadow reads, so one build serves all four and
run-injection-matrix.py runs them with --switches manual-switches.txt.

usage (repo root): python3 <this dir>/swift-mutations.py            apply
                   python3 <this dir>/swift-mutations.py --revert   git checkout the file

The edit is temporary: DrawingSymbols.swift is restored before anything is committed, and the
`strings <bundle> | grep -c B3_SWITCH` check reads 0 after the restoring rebuild.
"""
import subprocess, sys

PATH = "Sources/OCCTSwift/DrawingSymbols.swift"
if "--revert" in sys.argv:
    subprocess.run(["git", "checkout", "--", PATH], check=True)
    sys.exit(0)

s = open(PATH).read()
if "B3_SWITCH" in s:
    sys.exit("already mutated")

def sub(old, new):
    global s
    if s.count(old) != 1:
        sys.exit(f"anchor not unique ({s.count(old)}): {old!r}")
    s = s.replace(old, new)

sub("extension DrawingAnnotation {\n    /// ISO 1302 surface finish annotation",
    'private let b3Switch = Foundation.ProcessInfo.processInfo.environment["B3_SWITCH"] ?? ""\n\n'
    "extension DrawingAnnotation {\n    /// ISO 1302 surface finish annotation")
# SF_NOBAR: .machiningRequired loses the bar across the long arm
sub("            let barLength = 4.0\n            result.append(",
    '            let barLength = 4.0\n            if b3Switch != "SF_NOBAR" { result.append(')
sub("                        style: .solid)))\n        case .machiningProhibited:",
    "                        style: .solid))) }\n        case .machiningProhibited:")
# FCF_NODIV2: the tolerance/datum divider is not emitted
sub("        result.append(\n            .centreline(\n                .init(\n                    from: SIMD2(divX2, bottomLeft.y),",
    '        if b3Switch != "FCF_NODIV2" { result.append(\n            .centreline(\n                .init(\n                    from: SIMD2(divX2, bottomLeft.y),')
sub("                    to: SIMD2(divX2, topRight.y),\n                    style: .solid)))",
    "                    to: SIMD2(divX2, topRight.y),\n                    style: .solid))) }")
# GLYPH_FLT: flatness spelled differently
sub('case .flatness: return "FLT"', 'case .flatness: return b3Switch == "GLYPH_FLT" ? "FL" : "FLT"')
# BL_AMP: the zigzag's second peak on the same side as the first
sub("let p3 = mid + 0.5 * step * dir - amplitude * perp",
    'let p3 = mid + 0.5 * step * dir - (b3Switch == "BL_AMP" ? -amplitude : amplitude) * perp')
if "\nimport Foundation\n" not in "\n" + s:
    s = "import Foundation\n" + s
open(PATH, "w").write(s)
