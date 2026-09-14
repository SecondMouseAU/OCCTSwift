# Phase 0 Complete: Inventory & Categorization

## Summary

**Date**: 2026-09-14  
**Script**: `Scripts/enumerate-tests.py`  
**Total @Test functions**: **5,828** across **18 test targets**

> Note: Issue #766 cites 5,484 tests. The difference (344) is likely due to parameterized tests or test count at time of issue filing. This inventory captures all currently discoverable `@Test` functions.

## Test Distribution by Target

| Target | Count | Priority (Risk) |
|--------|-------|-----------------|
| OCCTModelingTests | 654 | 🔴 Critical (most OCCT surface) |
| OCCTTopologyTests | 554 | 🟠 High |
| OCCTSurfaceTests | 552 | 🟠 High |
| OCCTGeom2dTests | 545 | 🟠 High |
| OCCTCurveTests | 530 | 🟠 High |
| OCCTAnalysisTests | 526 | 🟠 High |
| OCCTXCAFTests | 422 | 🔴 Critical (crash fixes #341, #344, #349, #353, #371, #374) |
| OCCTStressTests | 366 | 🔴 Critical (TSan, concurrency) |
| OCCTMathTests | 342 | 🟡 Medium |
| OCCTShapeHealingTests | 320 | 🔴 Critical (degenerate geometry, #430, #522, #597) |
| OCCTFoundationTests | 200 | 🟢 Low |
| OCCTBRepGraphTests | 200 | 🟡 Medium (thread safety) |
| OCCTDrawingTests | 194 | 🟡 Medium |
| OCCTIOTests | 166 | 🔴 Critical (null handles #643) |
| OCCTMeshTests | 86 | 🟢 Low |
| OCCTMiscTests | 85 | 🟢 Low |
| OCCTThreadTests | 67 | 🔴 Critical (thread safety) |
| OCCTIntegrationTests | 19 | 🟢 Low |

**Total**: 5,828 tests

## Existing Prove-the-Test-Fails Evidence

Only **3 tests** currently have prove-the-test-fails documentation:

| Target | Suite | Test | Location |
|--------|-------|------|----------|
| OCCTSurfaceTests | Issue437PlatePointG2Tests | (multiple) | `Tests/OCCTSurfaceTests/Issue437PlatePointG2Tests.swift` |
| OCCTShapeHealingTests | Issue837FixDetailedModeFlagsTests | (multiple) | `Tests/OCCTShapeHealingTests/Issue837FixDetailedModeFlagsTests.swift` |
| OCCTThreadTests | Issue784ThreadBuildCodableCompatTests | (multiple) | `Tests/OCCTThreadTests/Issue784ThreadBuildCodableCompatTests.swift` |

## Files Created

| File | Description |
|------|-------------|
| `okf/references/766-test-validity/inventory.json` | Complete test inventory (5,828 entries) |
| `okf/references/766-test-validity/taxonomy.md` | Defect category taxonomy (12 categories) |
| `Scripts/enumerate-tests.py` | Extraction script (improved for both @Test formats) |

## Next Steps

1. **Phase 1**: High-risk boundary tests — null-handle guards, borrowed handles, 14 known OCCT crash fixes
2. **Phase 2**: Gate/census script self-tests — 9 scripts with `--self-test`
3. **Phase 3**: Sequential domain sweep — starting with OCCTStressTests

## Commands

```bash
# Run inventory again
cd /Users/elb/kilocode/OCCTSwift/Epic_766 && python3 Scripts/enumerate-tests.py 2>/dev/null > okf/references/766-test-validity/inventory.json

# Count by target
cat okf/references/766-test-validity/inventory.json | jq -r '.[] | .target' | sort | uniq -c | sort -rn

# Count with prove comment
cat okf/references/766-test-validity/inventory.json | jq '[.[] | select(.has_prove_comment)] | length'
```