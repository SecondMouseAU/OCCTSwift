# Phase 2: check-bridge-index.py Self-Test Removal Matrix

**Script**: `Scripts/check-bridge-index.py` — OCCTBridge.h class → symbol index: stale / misfiled entries

**Baseline**: Run `python3 Scripts/check-bridge-index.py --self-test` → expect all cases pass

---

## Self-Test Cases (from `SELF_TEST`, `DIRECTION_TEST`, `INDIRECTION_TEST`)

| # | Category | Case Name | Fixture | Mechanism Exercised | Guard to Remove | Expected Result |
|---|----------|-----------|---------|---------------------|-----------------|-----------------|
| 1 | Stale | plain entry | `// BRepFill_Draft → OCCTBRepFillDraftNope` | Stale symbol detection | `real_symbols()` reading | 1 stale reported |
| 2 | Stale | continuation line | `// ShapeFix_Shape → OCCTShapeFixDetailed, OCCTShapeHeal*, OCCTImportSTLRobustNope` | Multi-line continuation parsing | Line continuation logic | 1 stale reported |
| 3 | Stale | heading naming several classes | `// RWObj_CafReader/Writer → OCCTDocumentLoadOBJNope*` | Family prefix (`*`) with injected name | Family prefix expansion | 1 stale reported |
| 4 | Stale | name inside parenthetical aside | `// GeomAPI_ProjectPointOnCurve → OCCTCurve3DNearestParameter (NOT OCCTCurve3DProjectPointNope)` | Parenthetical exclusion `(NOT ...)` | Aside parsing | 1 stale reported |
| 5 | Stale | annotated family prefix | `// BRepOffsetAPI_MakeFilling → OCCTShapeFillNope* (Shape.fill)` | Family prefix with annotation | Family prefix with aside | 1 stale reported |
| 6 | Stale | symbol surviving only in tombstone comment | `// GCPnts_AbscissaPoint → OCCTCurve2DLength` | Real symbol from comment | `real_symbols()` comment filtering | 1 stale reported |

---

| # | Category | Case Name | Fixture | Mechanism Exercised | Guard to Remove | Expected Result |
|---|----------|-----------|---------|---------------------|-----------------|-----------------|
| 7 | Misfiled | symbol drives neighbouring class | `// BOPAlgo_CellsBuilder → OCCTBOPAlgoSplit` | Direction check: symbol reaches wrong class | `reachable()` class membership | 1 misfiled reported on OCCTBOPAlgoSplit |
| 8 | Misfiled | family prefix belongs to another class | `// ShapeFix_Wire → OCCTShapeFixWire*` | Family prefix mis-attribution | Family prefix expansion + reach check | 1 misfiled reported |
| 9 | Misfiled | class is reimplemented, not wrapped | `// LProp_AnalyticCurInf → OCCTLPropAnalyticCurInf` | Reimplemented class detection | `reachable()` existence check | 1 misfiled reported |
| 10 | Misfiled | class name one letter off | `// Law_Interpol → OCCTLawInterpolate` | Typo class name | `reachable()` existence check | 1 misfiled reported |
| 11 | Misfiled | one wrong symbol among correct neighbours | `// GCPnts_AbscissaPoint → OCCTCurve3DGetLength*, OCCTBOPAlgoSplit` | Per-symbol check (not per-entry) | Per-symbol direction check | 1 misfiled reported on OCCTBOPAlgoSplit |

---

| # | Category | Case Name | Fixture | Mechanism Exercised | Guard to Remove | Expected Result |
|---|----------|-----------|---------|---------------------|-----------------|-----------------|
| 12 | Indirection | wrapper-type field | `// XCAFDoc_ShapeTool → OCCTDocumentAddShape` | Wrapper field access (`x->shape`) | Indirection follow | Clean (not reported) |
| 13 | Indirection | lowercase static helper | `// TDataStd_NamedData → OCCTDocumentNamedData*` | Static helper call | Helper recognition | Clean (not reported) |
| 14 | Indirection | chained helper | `// BRepOffsetAPI_MakeFilling → OCCTShapeFillBuildResult → OCCTShapeFill` | Chained helper calls | Helper chain follow | Clean (not reported) |
| 15 | Indirection | explicit exemption | `// BRepOffsetAPI_MakeFilling → OCCTShapeFillBuildResult (exempt)` | Explicit exemption list | Exemption check | Clean (not reported) |

---

## Removal Procedure

For each case above:

```bash
# 1. Identify the guard/mechanism in check-bridge-index.py
# 2. Create injection by commenting out or modifying the guard
# 3. Run: python3 Scripts/check-bridge-index.py --self-test
# 4. Confirm: case fails (reported as MISS/FAIL)
# 5. Restore guard
# 6. Confirm: case passes (reported as ok)
```

---

## Disjointness Evidence

Per `prove-the-test-fails.md`: State which mechanism each case isolates and how you know.

| Case | Isolates Mechanism | Disjointness Evidence |
|------|-------------------|----------------------|
| 1 (plain stale) | Basic stale detection | Only fails when `real_symbols()` doesn't see the name |
| 2 (continuation) | Line continuation parsing | Fails only when `_` continuation logic removed |
| 3 (family prefix) | Family prefix expansion | Fails only when `*` expansion logic removed |
| 4 (parenthetical) | Aside parsing | Fails only when `(NOT ...)` parsing removed |
| 7 (misfiled) | Direction check per symbol | Fails only when per-symbol check removed (entry-level passes) |
| 12 (indirection) | Wrapper field follow | Fails only when `IDENT->field` follow removed |

---

## Gate Script Self-Test Removal Matrix Template

| Case | Guard Removed | Baseline Cases | After Removal | Mechanism Isolated | Disjointness Proof |
|------|---------------|----------------|---------------|-------------------|-------------------|
| 1 | `real_symbols()` reads comments | 15 pass | 14 pass, 1 MISS | Basic stale detection | Only this case fails |
| 2 | Line continuation parsing | 15 pass | 14 pass, 1 MISS | Continuation logic | Only this case fails |
| ... | ... | ... | ... | ... | ... |

---

## Notes

- Total cases: 15 (6 stale + 5 misfiled + 4 indirection)
- Each case must be proven by removing its specific guard
- "A green removal row is ambiguous" — if removing a guard leaves count unchanged, case is decorative
- Report matrix per `prove-the-test-fails.md` format