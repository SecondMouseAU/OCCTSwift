#!/usr/bin/env python3
"""Apply (or check) the two tracked-source injections of the #2983 ShapeHealing re-sweep.

usage: python3 Scripts/repro/2983-shapehealing-resweep/inject.py apply|status

The sweep injects almost everything by SHADOWING bridge functions from Swift
(`SweepHealingShadow.swift.txt`, copied in as `Sources/OCCTSwift/SweepHealingShadow.swift`), which
needs no edit to any tracked file. Two switches cannot be reached that way, so they are edits:

  * `AN_CHECKINTERNAL_FALSE_REAL` runs `OCCTShapeAnalyze`'s per-shell scan with
    `checkinternaledges` false, the divergence #717 fixed. It is a C++ internal flag no Swift
    shadow can reach, so `OCCTBridge_Healing_Analysis.mm` carries a `getenv` gate.
  * the `TP_*` and `HEALTHY_*` switches distort Swift members of `ShapeAnalysisResult`, which a
    module-local declaration cannot shadow, so `ShapeAnalysisResult.swift` carries the gates.

Every anchor is asserted unique before anything is written. Restore with `git checkout --` on the
two files and `rm` of the shadow, then REBUILD UNTIL THE BUNDLE HOLDS NO MARKER
(`strings <bundle> | grep -c SWEEP_HEALING_SWITCH`), per
okf/references/injection-sweep-mechanics.md.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[3]
MM = ROOT / "Sources/OCCTBridge/src/OCCTBridge_Healing_Analysis.mm"
SW = ROOT / "Sources/OCCTSwift/ShapeAnalysisResult.swift"

MM_OLD = "        OCCTShellOrientationScan scan = occtAnalyzeShellOrientation(shell);\n"
MM_NEW = (
    MM_OLD
    + """        { // SWEEP-INJECT (temporary, never committed)
          const char* sweepSwitch = getenv("SWEEP_HEALING_SWITCH");
          if (sweepSwitch && std::string(sweepSwitch) == "AN_CHECKINTERNAL_FALSE_REAL")
          {
            ShapeAnalysis_Shell sweepAnalyzer;
            sweepAnalyzer.CheckOrientedShells(shell, true, false);
            scan.hasFreeEdges  = sweepAnalyzer.HasFreeEdges();
            scan.freeEdgeCount = 0;
            if (scan.hasFreeEdges)
            {
              TopoDS_Compound sweepFree = sweepAnalyzer.FreeEdges();
              for (TopExp_Explorer sweepExp(sweepFree, TopAbs_EDGE); sweepExp.More();
                   sweepExp.Next())
                scan.freeEdgeCount++;
            }
          }
        }
"""
)

TP_OLD = """        smallEdgeCount + smallFaceCount + gapCount + freeEdgeCount
            + (hasInvalidTopology ? 1 : 0)
            + (hasSelfIntersection == true ? 1 : 0)
    }"""
TP_NEW = """        smallEdgeCount + smallFaceCount + gapCount + freeEdgeCount
            + (hasInvalidTopology ? 1 : 0)
            + (hasSelfIntersection == true ? 1 : 0)
            + (SweepHealingGate.on("TP_DOUBLE_FREEFACE") ? freeFaceCount : 0)
            - (SweepHealingGate.on("TP_DROP_SELFINT") && hasSelfIntersection == true ? 1 : 0)
            - (SweepHealingGate.on("TP_DROP_INVALID") && hasInvalidTopology ? 1 : 0)
            - (SweepHealingGate.on("TP_DROP_FREEEDGE") ? freeEdgeCount : 0)
    }"""
HE_OLD = """        totalProblems == 0 && !hasInvalidTopology
    }"""
HE_NEW = """        if SweepHealingGate.on("HEALTHY_TRUE") { return true }
        if SweepHealingGate.on("HEALTHY_IGNORES_FREEEDGES") {
            return smallEdgeCount + smallFaceCount + gapCount == 0 && !hasInvalidTopology
        }
        return totalProblems == 0 && !hasInvalidTopology
    }"""


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "status"
    mm, sw = MM.read_text(), SW.read_text()
    if mode == "status":
        print("mm injected:", "SWEEP-INJECT" in mm, "| swift injected:", "SweepHealingGate" in sw)
        return
    assert mode == "apply", "usage: inject.py apply|status"
    assert mm.count(MM_OLD) == 1, f"mm anchor matches {mm.count(MM_OLD)} times"
    assert sw.count(TP_OLD) == 1, f"totalProblems anchor matches {sw.count(TP_OLD)} times"
    assert sw.count(HE_OLD) == 1, f"isHealthy anchor matches {sw.count(HE_OLD)} times"
    MM.write_text(mm.replace(MM_OLD, MM_NEW))
    SW.write_text(sw.replace(TP_OLD, TP_NEW).replace(HE_OLD, HE_NEW))
    print("applied")


if __name__ == "__main__":
    main()
