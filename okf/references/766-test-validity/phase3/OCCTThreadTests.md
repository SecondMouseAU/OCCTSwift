# Phase 3: OCCTThreadTests Injection Matrix

**Target**: `OCCTThreadTests` (12 tests) — ThreadSpec parsing, threadedHole, threadedShaft, ThreadForm v2
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🟢 High (core thread feature, multiple OCCT bridge entry points)

---

## Test Inventory by Suite

| Suite | Tests | Primary Category |
|-------|-------|------------------|
| ThreadSpecParsingTests | 4 | WR¹ |
| ThreadedFeatureTests | 4 | CR¹ |
| ThreadSpecTruncationTests | 4 | WR¹ |

**Total**: 12 tests across 3 suites

**Legend**: **WR** = Wrong Result (tests producing incorrect results without crashing); **CR** = Crash Risk (tests exercising bridge functions where defects can trigger OCCT-level crashes or assertion failures).

---

## Injection Matrix: Critical Crash-Related Tests First

### ThreadedFeatureTests (Bridge Functions: `OCCTShapeBuildThreadCutter`, `Shape.loft`, `Shape.sew`, `Shape.subtracting`, `Shape.union`, `Shape.filleted`, `Shape.screwSweptThreadCutter`)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| threadedHole cuts material from a bored block | `OCCTShapeBuildThreadCutter` + boolean cut | Cutter returns null | Return null from `OCCTShapeBuildThreadCutter` | ✅ | ✅ | Analytic cutter path |
| threadedShaft cuts helical V-grooves into the shaft | `Shape.threadedRodSolid` (direct) | Direct build fails | Return nil from `buildThreadedRodDirect` | ✅ | ✅ | Direct build path |
| threadedHole respects left-handed helix parameter | `OCCTShapeBuildThreadCutter` | Handedness ignored | Force same result for both | ✅ | ✅ | Mirror symmetry test |
| Multi-start thread (starts: 2) removes more material than single-start | `OCCTShapeBuildThreadCutter` + boolean | Multi-start treated as single | Ignore `starts` parameter | ✅ | ✅ | Volume comparison |

### ThreadSpecParsingTests (Pure Swift — no bridge calls)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| Metric M5x0.8 | N/A (Swift) | Parse returns nil | Force `parse` to return nil | ✅ | ✅ | No bridge involvement |
| Metric M6 uses coarse pitch | N/A (Swift) | Wrong default pitch | Return wrong pitch | ✅ | ✅ | Table lookup test |
| UNC 1/4-20 converts to metric | N/A (Swift) | Conversion wrong | Return wrong diameter/pitch | ✅ | ✅ | Fraction parsing |
| Theoretical and cut depths | N/A (Swift) | Math wrong | Return wrong values | ✅ | ✅ | Pure computation |

### ThreadSpecTruncationTests (Pure Swift — no bridge calls)

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| ISO-68 crest flat = P/8 | N/A (Swift) | Wrong constant | Return wrong value | ✅ | ✅ | Property getter |
| ISO-68 root flat = P/4 | N/A (Swift) | Wrong constant | Return wrong value | ✅ | ✅ | Property getter |
| cutDepth = 5H/8 | N/A (Swift) | Wrong relation | Return wrong value | ✅ | ✅ | Derived property |
| minorDiameter consistent with cut depth | N/A (Swift) | Wrong calculation | Return wrong value | ✅ | ✅ | Derived property |

---

## Progress Tracking

| Suite | Tests | Injected | Red ✓ | Green ✓ | PR Ready |
|-------|-------|----------|-------|---------|----------|
| ThreadSpecParsingTests | 4 | 4 | 4 | 4 | ✅ |
| ThreadedFeatureTests | 4 | 4 | 4 | 4 | ✅ |
| ThreadSpecTruncationTests | 4 | 4 | 4 | 4 | ✅ |

**Total**: 12 tests - **All Red→Green verified**

---

## Kernel Parity Verification

All 12 tests have kernel parity evidence in `okf/references/766-execution/kernel-parity/OCCTThreadTests.json` with `comparison.equal: true` for every test where kernel comparison applies (ThreadedFeatureTests only; ThreadSpecParsingTests and ThreadSpecTruncationTests are pure Swift computations with no OCCT kernel equivalent).