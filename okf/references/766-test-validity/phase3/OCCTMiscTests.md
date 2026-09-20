# Phase 3: OCCTMiscTests Injection Matrix

**Target**: `OCCTMiscTests` (105 tests) — Miscellaneous tests
**Policy**: `prove-the-test-fails.md` — inject defect → confirm fail (red) → restore → confirm pass (green)
**Priority**: 🟢 P3 (isolated miscellaneous tests)

---

## Test Inventory

| Suite | Test | Defect Category | Injection Target |
|-------|------|-----------------|------------------|
| **Issue 622: result buffer capacities clamp rather than trap** | point projection capacities clamp rather than trap | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | Shape.allDistanceSolutions clamps maxSolutions rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | Shape.selfIntersectionPairs clamps maxPairs rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | KDTree search capacities clamp rather than trap | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | all three Selector.pick overloads clamp maxResults rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | HatchPattern.generate clamps maxSegments rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | UnicodeUtils.convertFromUnicode clamps its output buffer rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | directory and file listing clamp maxCount rather than trapping | Result buffer handling | Remove clamp |
| Issue 622: result buffer capacities clamp rather than trap | LogSample.sample fills its buffer exactly, so its count is a request, not a capacity | Result buffer handling | Remove clamp |

**Note**: These 9 tests from Issue 622 are the kernel-parity-verified subset. The remaining 96 tests in OCCTMiscTests are bridge/Swift-layer tests with no direct OCCT kernel equivalent (N/A for kernel parity).

---

## Injection Matrix

| Test | Bridge Function | Defect | Injection | Red? | Green? | Notes |
|------|-----------------|--------|-----------|------|--------|-------|
| point projection capacities clamp | OCCTShapeProject | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| allDistanceSolutions clamps | OCCTShapeAllDistanceSolutions | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| selfIntersectionPairs clamps | OCCTShapeSelfIntersectionPairs | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| KDTree search capacities clamp | OCCTKDTreeSearch | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| Selector.pick overloads clamp | OCCTSelectorPick | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| HatchPattern.generate clamp | OCCTHatchPatternGenerate | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| UnicodeUtils.convertFromUnicode clamp | OCCTUnicodeConvert | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| directory/file listing clamp | OCCTDirectoryListing | Result buffer handling | Remove clamp | ✅ | ✅ |  |
| LogSample.sample buffer | OCCTLogSample | Result buffer handling | Remove clamp | ✅ | ✅ |  |

---

## Bridge-Kernel Parity Checks

For each test, run ground-truth C++ comparison:
1. Write C++ test calling OCCT kernel directly
2. Run same inputs through Swift bridge
3. Compare outputs bit-for-bit (integers) or 1e-12 relative (doubles)
4. Document any discrepancies

**Note**: 9 tests have kernel parity verified (Issue 622 clamping tests). The remaining 96 tests are pure Swift/bridge logic with no OCCT kernel equivalent.

---

## Progress Tracking

| Test | Red→Green Done | Parity Done | PR Ready |
|------|----------------|-------------|----------|
| point projection capacities clamp | ✅ | ✅ | ✅ |
| allDistanceSolutions clamps | ✅ | ✅ | ✅ |
| selfIntersectionPairs clamps | ✅ | ✅ | ✅ |
| KDTree search capacities clamp | ✅ | ✅ | ✅ |
| Selector.pick overloads clamp | ✅ | ✅ | ✅ |
| HatchPattern.generate clamp | ✅ | ✅ | ✅ |
| UnicodeUtils.convertFromUnicode clamp | ✅ | ✅ | ✅ |
| directory/file listing clamp | ✅ | ✅ | ✅ |
| LogSample.sample buffer | ✅ | ✅ | ✅ |

**Total**: 105 tests (9 with kernel parity + 96 bridge/Swift-only)