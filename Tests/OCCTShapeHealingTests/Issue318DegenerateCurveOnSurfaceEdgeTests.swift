import Testing
@testable import OCCTSwift

/// Issue #318: `Shape.analyze(tolerance:)` SIGSEGV'd (via `BRepGProp::LinearProperties` ->
/// `BRepGProp_EdgeTool::IntegrationOrder`) walking a shape that contains a degenerate edge whose
/// SOLE geometric representation is a Bezier/BSpline curve-on-surface pcurve (no 3D curve) --
/// `BRepAdaptor_Curve::GetType()` correctly reports the pcurve's type via the curve-on-surface
/// override, but `IntegrationOrder` then read the pole count through a completely different,
/// non-virtual accessor (`BAC.Curve().Curve()`) that is null whenever there is no 3D curve, and
/// dereferenced the null down-cast. Fixed by using the adaptor's own (correctly-dispatching)
/// `NbPoles()` instead (`Scripts/patches/0006-*`, upstream Open-Cascade-SAS/OCCT#1381 (repro) /
/// OCCT#1382 (fix)).
///
/// This exact shape is `Shape.sew(shapes:tolerance:)`'s real output sewing two adjacent (but not
/// edge-sharing) mesh-derived planar candidate faces from OCCTReconstruct's plane-select spike
/// (`kof_ii_engine_cover.stl`, regions 10 + 64) -- `BRepBuilderAPI_Sewing` introduces the
/// degenerate BSpline-pcurve edge while trying to reconcile the near-coincident boundaries. A
/// from-scratch synthetic curve-on-surface edge did not reproduce this (the sewing step itself is
/// what manufactures the offending edge), so the captured BREP dump is the minimal faithful repro.
@Suite("Issue #318 -- degenerate curve-on-surface edge crashes Shape.analyze")
struct Issue318DegenerateCurveOnSurfaceEdgeTests {

    @Test("Shape.analyze(tolerance:) no longer crashes on a sewn shape with a degenerate BSpline-pcurve edge")
    func analyzeSurvivesDegenerateCurveOnSurfaceEdge() {
        guard let shape = Shape.fromBREPString(Self.fixtureBREP) else {
            Issue.record("Shape.fromBREPString failed to parse the fixture")
            return
        }

        // No #expect needed for the crash itself -- a regression would abort the whole test
        // process (uncatchable SIGSEGV); reaching the assertions below is the real assertion.
        let result = shape.analyze(tolerance: 0.11477)
        guard let result else {
            Issue.record("Shape.analyze returned nil")
            return
        }
        // The fixture is a genuinely malformed shape (two faces that failed to sew into a
        // shell) -- these counts just pin the known-good post-fix values, not "healthy".
        // smallEdgeCount is 0, not the ~60 raw degenerate edges the fixture carries: the
        // bridge's own #318 guard skips degenerate edges before measuring length, since a
        // degenerate edge's zero extent is a topological given, not a "small edge" defect.
        #expect(result.smallEdgeCount == 0)
        #expect(result.freeEdgeCount == 0)
    }

    /// `Shape.sew(shapes: [region10Face, region64Face], tolerance: 0.11477)`'s literal output --
    /// see the suite doc comment for provenance. Captured via `Shape.writeBREP(to:)` /
    /// `BRepTools::Write` on the real sewn shape, no hand editing.
    static let fixtureBREP = """

CASCADE Topology V3, (c) Open Cascade
Locations 0
Curve2ds 1
7 0 0  1 2 2  56.654021921231077 -3.7500000000000009  57.04746399896505 -3.9358220100402836 
 0 2 0.43771750026161399 2
Curves 4
1 -2.8133929099591844e-15 76.329724692885577 162.25465393066327 1 3.6858418149402948e-17 -0 
1 3.75 76.777503967285156 162.25465393066406 0 -1 0 
1 3.75 67.894027709960938 162.25465393066406 -1 0 0 
1 -3.75 76.777503967285156 162.25465393066406 0 -1 0 
Polygon3D 0
PolygonOnTriangulations 4
2 1 4 
p 0.402154894520719 1 -3.75 3.75 
2 4 3 
p 0.134531506203001 1 0 8.88347625732422 
2 3 2 
p 0.116260976791382 1 0 7.5 
2 1 2 
p 0.20924063279228 1 0 8.88347625732422 
Surfaces 2
1 -7.544270318526254e-16 20.468242255937561 169.01947414490169 -4.4311771739137347e-18 0.12022157749560158 0.99274708375520759 5.3844377506579377e-35 0.99274708375520759 -0.12022157749560158 -1 -5.3272311001041063e-19 -4.3990382170055017e-18 
1 0 0 162.25465393066406 0 0 1 1 0 -0 -0 1 0 
Triangulations 1
4 2 1 0 0.246977551272418
-3.875 76.6655591486853 162.379653930664 -3.75 67.8940277099609 162.254653930664 3.75 67.8940277099609 162.254653930664 3.85816791883412 76.7139945008941 162.30328494109 -3.75 76.3297246928856 -3.75 67.8940277099609 3.75 67.8940277099609 3.75 76.3297246928856 1 2 3 4 1 3 

TShapes 75
Ve
10.4124963605597
-1.49768877029419 82.7488441467285 162.754653930664
0 0

0101101
*
Ed
 0.550211774678522 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.597858049358765 1 1 1
2  1 1 0 0 0.437717500261614
0

0101000
+75 0 -75 0 *
Ed
 0.647548823062256 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.698758524707646 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.750942321446231 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.803548042613134 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.856016179727299 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.907791810442834 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.958324598548921 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.00707888346697 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.05353734915881 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.09720744471573 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.13762597049364 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.17436366424807 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.20703162172334 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.23528313110666 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.25881825916311 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.27738752014378 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.29079371023975 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.29889465926329 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.30160414787462 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.30160414787462 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.29889465926329 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.29079371023975 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.27738752014378 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.25881825916311 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.23528313110666 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.20703162172334 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.17436366424807 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.13762597049364 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.09720744471573 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.05353734915881 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 1.00707888346697 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.958324598548921 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.907791810442834 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.856016179727299 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.803548042613134 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.750942321446231 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.698758524707646 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.647548823062256 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.597858049358765 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.550211774678522 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.50515850077836 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.463128407129728 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.424565431609356 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.389877740240288 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.359433141056801 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.333554497969203 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.312514227401897 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.296536132747257 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.285788983776613 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.280387433867272 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.28578898377664 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.29653613274726 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.312514227401897 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.333554497969203 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.359433141056801 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.389877740240288 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.424565431609356 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.463128407129728 1 1 1
0

0101000
+75 0 -75 0 *
Ed
 0.50515850077836 1 1 1
0

0101000
+75 0 -75 0 *
Wi

0101100
+74 0 +73 0 +72 0 +71 0 +70 0 +69 0 +68 0 +67 0 +66 0 +65 0 
+64 0 +63 0 +62 0 +61 0 +60 0 +59 0 +58 0 +57 0 +56 0 +55 0 
+54 0 +53 0 +52 0 +51 0 +50 0 +49 0 +48 0 +47 0 +46 0 +45 0 
+44 0 +43 0 +42 0 +41 0 +40 0 +39 0 +38 0 +37 0 +36 0 +35 0 
+34 0 +33 0 +32 0 +31 0 +30 0 +29 0 +28 0 +27 0 +26 0 +25 0 
+24 0 +23 0 +22 0 +21 0 +20 0 +19 0 +18 0 +17 0 +16 0 +15 0 
+14 0 *
Fa
0  1e-07 1 0

0101000
+13 0 *
Ve
2.50456442429619
-3.875 76.6655591486853 162.379653930664
0 0

0101101
*
Ve
2.42985529770691
3.85816791883412 76.7139945008941 162.30328494109
0 0

0101101
*
Ed
 2.29532379150391 1 1 0
1  1 0 -3.75 3.75
6  1 1 0
0

0101000
+11 0 -10 0 *
Ve
2.29532379150391
3.75 67.8940277099609 162.254653930664
0 0

0101101
*
Ed
 2.29532379150391 1 1 0
1  2 0 0 8.88347625732422
6  2 1 0
0

0101000
+10 0 -8 0 *
Ve
2.29532379150391
-3.75 67.8940277099609 162.254653930664
0 0

0101101
*
Ed
 2.29532379150391 1 1 0
1  3 0 0 7.5
6  3 1 0
0

0101000
+8 0 -6 0 *
Ed
 2.29532379150391 1 1 0
1  4 0 0 8.88347625732422
6  4 1 0
0

0101000
+11 0 -6 0 *
Wi

0101100
+9 0 +7 0 +5 0 -4 0 *
Fa
0  1e-07 2 0
2  1
0111000
-3 0 *
Co

1100000
+12 0 +2 0 *

+1 0 
"""
}
