// OCCTSwift#595: the six curvature getters that still spell "undefined" as 0, measured.
//
// #583 fixed the Shape.faceLProp* block by reading through BRepLProp_SLProps and showing that a
// cylinder's Gaussian curvature is exactly 0 at every point with the curvature defined, so 0 was
// never a spare encoding. This probe asks the same question of the six entry points #583 deferred,
// each on a different public type and through a different OCCT class:
//
//   Curve3D.curvature(at:)          GeomLProp_CLProps      IsTangentDefined()
//   Curve3D.localCurvature(at:)     GeomLProp_CLProps      IsTangentDefined()
//   Curve2D.curvature(at:)          GeomLProp_CLProps2d    IsTangentDefined()
//   Shape.edgeCurvatureLP(at:)      BRepLProp_CLProps      IsTangentDefined()
//   Surface.gaussianCurvature       GeomLProp_SLProps      IsCurvatureDefined()
//   Surface.meanCurvature           GeomLProp_SLProps      IsCurvatureDefined()
//
// and of the two neighbours the issue's census did not list, both of which decide "undefined" with
// a hand-rolled gate of their own rather than an OCCT predicate:
//
//   Curve3D.torsion(at:)            Geom_Curve::D3         |d1 x d2|^2 < Precision::Confusion()
//   Wire.curvature(at:)             BRepAdaptor_CompCurve  |d1| < 1e-10
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/595-curvature-zero-sentinel/occt_595_curvature_zero.cpp -o /tmp/occt_595_curv
//   /tmp/occt_595_curv

#include <BRepAdaptor_CompCurve.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepLProp_CLProps.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Curve.hxx>
#include <Geom2d_BezierCurve.hxx>
#include <Geom2d_Circle.hxx>
#include <Geom2d_Line.hxx>
#include <GeomLProp_CLProps.hxx>
#include <GeomLProp_SLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax22d.hxx>
#include <gp_Ax3.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

// occtLocalPropsResolution(), the one value #494/#529 converged every local-properties site onto.
static const double kResolution = Precision::Confusion();

static int gCollisions = 0;    // rows whose value is exactly 0 with the gate open (a real answer)
static int gSentinels = 0;     // rows whose gate is shut, and so return 0 today
static int gLocalDiverged = 0; // rows where curvature(at:) and localCurvature(at:) disagree

static const char* verdict(bool gateOpen, double value) {
    if (!gateOpen) { gSentinels++; return "SENTINEL 0"; }
    if (value == 0.0) { gCollisions++; return "REAL 0  <-- collides"; }
    return "real value";
}

// ---------------------------------------------------------------- 3D curves, GeomLProp_CLProps

// A cubic Bezier whose first two poles coincide. D1(0) is null, the tangent search falls through to
// D2, and Curvature() comes back RealLast(): a different sentinel, and the one case a bare double
// does distinguish.
static Handle(Geom_BezierCurve) cuspCurve() {
    TColgp_Array1OfPnt poles(1, 4);
    poles(1) = gp_Pnt(0, 0, 0);
    poles(2) = gp_Pnt(0, 0, 0);
    poles(3) = gp_Pnt(1, 1, 0);
    poles(4) = gp_Pnt(2, 0, 0);
    return new Geom_BezierCurve(poles);
}

// Every pole at one point: no derivative of any order is significant, the tangent search runs out,
// and IsTangentDefined() is false. The row that collides with a straight line.
static Handle(Geom_BezierCurve) deadCurve() {
    TColgp_Array1OfPnt poles(1, 4);
    for (int i = 1; i <= 4; ++i) poles(i) = gp_Pnt(0, 0, 0);
    return new Geom_BezierCurve(poles);
}

static Handle(Geom2d_BezierCurve) cuspCurve2d() {
    TColgp_Array1OfPnt2d poles(1, 4);
    poles(1) = gp_Pnt2d(0, 0);
    poles(2) = gp_Pnt2d(0, 0);
    poles(3) = gp_Pnt2d(1, 1);
    poles(4) = gp_Pnt2d(2, 0);
    return new Geom2d_BezierCurve(poles);
}

static Handle(Geom2d_BezierCurve) deadCurve2d() {
    TColgp_Array1OfPnt2d poles(1, 4);
    for (int i = 1; i <= 4; ++i) poles(i) = gp_Pnt2d(0, 0);
    return new Geom2d_BezierCurve(poles);
}

struct Curve3Row {
    const char* label;
    Handle(Geom_Curve) curve;
    double u;
};

static void sweepCurve3D() {
    printf("\n=== Curve3D.curvature(at:) / localCurvature(at:) -- GeomLProp_CLProps ===\n");
    printf("%-34s %-9s %-15s %-15s %s\n",
           "curve", "tangent", "Curvature()", "local (same)", "what a caller sees");

    std::vector<Curve3Row> rows = {
        {"line (straight)", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 5.0},
        {"circle radius 4", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0), 1.0},
        {"Bezier, first two poles equal", cuspCurve(), 0.0},
        {"Bezier, all four poles equal", deadCurve(), 0.5},
    };
    for (const Curve3Row& r : rows) {
        // Exactly what the bridge builds, for both spellings: since #494 OCCTCurve3DGetCurvature and
        // OCCTCurve3DLocalCurvature construct the same props at the same resolution and gate on the
        // same predicate, so the two columns are a check that the duplication is now total.
        GeomLProp_CLProps canonical(r.curve, r.u, 2, kResolution);
        GeomLProp_CLProps local(r.curve, r.u, 2, kResolution);
        const bool tangent = canonical.IsTangentDefined();
        const double k = tangent ? canonical.Curvature() : 0.0;
        const double kLocal = local.IsTangentDefined() ? local.Curvature() : 0.0;
        if (k != kLocal || tangent != local.IsTangentDefined()) gLocalDiverged++;
        printf("%-34s %-9s %-15.6g %-15.6g %s\n",
               r.label, tangent ? "yes" : "NO", k, kLocal, verdict(tangent, k));
    }
    printf("rows where the two spellings disagree: %d -- the duplication is total, so one can go.\n",
           gLocalDiverged);
}

// ---------------------------------------------------------------- 2D curves, GeomLProp_CLProps2d

struct Curve2Row {
    const char* label;
    Handle(Geom2d_Curve) curve;
    double u;
};

static void sweepCurve2D() {
    printf("\n=== Curve2D.curvature(at:) -- GeomLProp_CLProps2d ===\n");
    printf("%-34s %-9s %-15s %s\n", "curve", "tangent", "Curvature()", "what a caller sees");

    std::vector<Curve2Row> rows = {
        {"line (straight)", new Geom2d_Line(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 5.0},
        {"circle radius 4", new Geom2d_Circle(gp_Ax22d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 4.0), 1.0},
        {"Bezier, first two poles equal", cuspCurve2d(), 0.0},
        {"Bezier, all four poles equal", deadCurve2d(), 0.5},
    };
    for (const Curve2Row& r : rows) {
        GeomLProp_CLProps2d props(r.curve, r.u, 2, kResolution);
        const bool tangent = props.IsTangentDefined();
        const double k = tangent ? props.Curvature() : 0.0;
        printf("%-34s %-9s %-15.6g %s\n", r.label, tangent ? "yes" : "NO", k, verdict(tangent, k));
    }
}

// ---------------------------------------------------------------- edges, BRepLProp_CLProps

static void readEdge(const char* label, const TopoDS_Edge& edge, double param) {
    try {
        BRepAdaptor_Curve ac(edge);
        BRepLProp_CLProps props(ac, param, 2, kResolution);
        const bool tangent = props.IsTangentDefined();
        const double k = tangent ? props.Curvature() : 0.0;
        printf("%-34s %-9s %-15.6g %s\n", label, tangent ? "yes" : "NO", k, verdict(tangent, k));
    } catch (const Standard_Failure& f) {
        // The bridge's catch(...) turns this into the same 0 as everything else.
        gSentinels++;
        printf("%-34s %-9s %-15s %s (%s)\n", label, "throw", "-", "SENTINEL 0", f.GetMessageString());
    }
}

static void sweepEdges() {
    printf("\n=== Shape.edgeCurvatureLP(at:) -- BRepAdaptor_Curve + BRepLProp_CLProps ===\n");
    printf("%-34s %-9s %-15s %s\n", "edge", "tangent", "Curvature()", "what a caller sees");

    BRepBuilderAPI_MakeEdge lineEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    if (lineEdge.IsDone()) readEdge("straight edge", lineEdge.Edge(), 5.0);

    BRepBuilderAPI_MakeEdge circleEdge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0));
    if (circleEdge.IsDone()) readEdge("circular edge radius 4", circleEdge.Edge(), 1.0);

    BRepBuilderAPI_MakeEdge cuspEdge(cuspCurve());
    if (cuspEdge.IsDone()) readEdge("edge on the cusp Bezier", cuspEdge.Edge(), 0.0);
    else printf("%-34s %s\n", "edge on the cusp Bezier", "MakeEdge refused it");

    BRepBuilderAPI_MakeEdge deadEdge(deadCurve());
    if (deadEdge.IsDone()) readEdge("edge on the dead Bezier", deadEdge.Edge(), 0.5);
    else printf("%-34s %s\n", "edge on the dead Bezier", "MakeEdge refused it");

    // The reachable-in-practice degeneracy: a sphere solid carries a degenerate edge at each pole,
    // and every Shape.edge* entry point walks edges without asking whether they are degenerate.
    TopoDS_Shape sphere = BRepPrimAPI_MakeSphere(5.0).Shape();
    int degenerates = 0;
    for (TopExp_Explorer ex(sphere, TopAbs_EDGE); ex.More(); ex.Next()) {
        const TopoDS_Edge& e = TopoDS::Edge(ex.Current());
        if (!BRep_Tool::Degenerated(e)) continue;
        if (degenerates++ > 0) break;
        double f = 0, l = 0;
        Handle(Geom_Curve) c3d = BRep_Tool::Curve(e, f, l);
        printf("(sphere radius 5: its degenerate pole edge has %s 3D curve)\n",
               c3d.IsNull() ? "NO" : "a");
        readEdge("sphere degenerate pole edge", e, 0.5);
    }
    if (degenerates == 0) printf("(no degenerate edge found on the sphere)\n");
}

// ---------------------------------------------------------------- surfaces, GeomLProp_SLProps

struct SurfRow {
    const char* label;
    Handle(Geom_Surface) surface;
    double u, v;
};

static void sweepSurfaces() {
    printf("\n=== Surface.gaussianCurvature / meanCurvature -- GeomLProp_SLProps ===\n");
    printf("%-34s %-9s %-15s %-15s %s\n",
           "surface point", "defined", "K (gauss)", "H (mean)", "what a caller sees (K / H)");

    Handle(Geom_Plane) plane = new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
    Handle(Geom_CylindricalSurface) cyl =
        new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
    Handle(Geom_ConicalSurface) cone =
        new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0.0);
    Handle(Geom_SphericalSurface) sph =
        new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);

    std::vector<SurfRow> rows = {
        {"plane, u=3 v=4", plane, 3, 4},
        {"cylinder r=3, u=1.1 v=6", cyl, 1.1, 6},
        {"cone, v=1.0 (ordinary)", cone, 0, 1.0},
        {"cone, v=1e-8 (past the gate)", cone, 0, 1e-8},
        {"cone apex, v=0", cone, 0, 0.0},
        {"sphere r=5, v=0 (equator)", sph, 0, 0.0},
        {"sphere r=5, v=pi/2 (pole)", sph, 0, M_PI / 2},
    };
    for (const SurfRow& r : rows) {
        GeomLProp_SLProps props(r.surface, r.u, r.v, 2, kResolution);
        const bool defined = props.IsCurvatureDefined();
        const double K = defined ? props.GaussianCurvature() : 0.0;
        const double H = defined ? props.MeanCurvature() : 0.0;
        const char* vK = verdict(defined, K);
        const char* vH = verdict(defined, H);
        printf("%-34s %-9s %-15.6g %-15.6g %s / %s\n",
               r.label, defined ? "yes" : "NO", K, H, vK, vH);
    }
}

// ------------------------------------------------- the two neighbours the census did not list

// Curve3D.torsion(at:) computes (d1 x d2) . d3 / |d1 x d2|^2 itself and returns 0 when the
// numerator's magnitude falls under the gate. A planar curve's torsion is genuinely 0, so the same
// collision lands one method below curvature(at:).
static void sweepTorsion() {
    printf("\n=== Curve3D.torsion(at:) -- hand-rolled gate, |d1 x d2|^2 < Precision::Confusion() ===\n");
    printf("%-34s %-11s %-15s %s\n", "curve", "osc.plane", "torsion", "what a caller sees");

    struct Row { const char* label; Handle(Geom_Curve) curve; double u; };
    // A helix, the standard non-planar curve: constant torsion pitch/(r^2 + pitch^2).
    TColgp_Array1OfPnt helixPoles(1, 5);
    for (int i = 1; i <= 5; ++i) {
        const double t = (i - 1) * 0.6;
        helixPoles(i) = gp_Pnt(std::cos(t), std::sin(t), 0.4 * t);
    }
    std::vector<Row> rows = {
        {"line (straight)", new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0)), 5.0},
        {"circle radius 4 (planar)", new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0), 1.0},
        {"Bezier helix approximation", new Geom_BezierCurve(helixPoles), 0.5},
        {"Bezier, all four poles equal", deadCurve(), 0.5},
    };
    for (const Row& r : rows) {
        gp_Pnt p; gp_Vec d1, d2, d3;
        r.curve->D3(r.u, p, d1, d2, d3);
        gp_Vec cross = d1.Crossed(d2);
        const double crossMag2 = cross.SquareMagnitude();
        const bool gateOpen = crossMag2 >= Precision::Confusion();
        const double torsion = gateOpen ? cross.Dot(d3) / crossMag2 : 0.0;
        printf("%-34s %-11s %-15.6g %s\n",
               r.label, gateOpen ? "yes" : "NO", torsion, verdict(gateOpen, torsion));
    }
}

// Wire.curvature(at:) already returns Double?, but only -1.0 becomes nil: the degenerate-tangent
// branch returns 0.0, which reaches the caller as a straight wire's genuine curvature.
static void sweepWire() {
    printf("\n=== Wire.curvature(at:) -- BRepAdaptor_CompCurve, |d1| < 1e-10 ===\n");
    printf("%-34s %-11s %-15s %s\n", "wire", "|d1|", "curvature", "what a caller sees");

    struct Row { const char* label; TopoDS_Wire wire; double t; };
    std::vector<Row> rows;

    BRepBuilderAPI_MakeWire straight(BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)).Edge());
    if (straight.IsDone()) rows.push_back({"straight wire", straight.Wire(), 0.5});

    BRepBuilderAPI_MakeEdge circleEdge(new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0));
    BRepBuilderAPI_MakeWire circular(circleEdge.Edge());
    if (circular.IsDone()) rows.push_back({"circular wire radius 4", circular.Wire(), 0.25});

    BRepBuilderAPI_MakeEdge cuspEdge(cuspCurve());
    if (cuspEdge.IsDone()) {
        BRepBuilderAPI_MakeWire cuspWire(cuspEdge.Edge());
        if (cuspWire.IsDone()) rows.push_back({"wire on the cusp Bezier", cuspWire.Wire(), 0.0});
    }

    for (const Row& r : rows) {
        try {
            BRepAdaptor_CompCurve curve(r.wire);
            const double first = curve.FirstParameter(), last = curve.LastParameter();
            gp_Pnt p; gp_Vec d1, d2;
            curve.D2(first + r.t * (last - first), p, d1, d2);
            const double mag = d1.Magnitude();
            const bool gateOpen = mag >= 1e-10;
            const double k = gateOpen ? d1.Crossed(d2).Magnitude() / (mag * mag * mag) : 0.0;
            printf("%-34s %-11.4g %-15.6g %s\n", r.label, mag, k, verdict(gateOpen, k));
        } catch (const Standard_Failure& f) {
            printf("%-34s %-11s %-15s threw: %s\n", r.label, "-", "-", f.GetMessageString());
        }
    }
}

int main() {
    printf("OCCTSwift#595: 0 as the \"no curvature here\" sentinel, on the six entry points #583 deferred.\n");
    printf("Resolution = %g (occtLocalPropsResolution)\n", kResolution);

    sweepCurve3D();
    sweepCurve2D();
    sweepEdges();
    sweepSurfaces();
    sweepTorsion();
    sweepWire();

    printf("\n=== summary ===\n");
    printf("rows returning 0 as a REAL answer, gate open   : %d\n", gCollisions);
    printf("rows returning 0 as the UNDEFINED sentinel     : %d\n", gSentinels);
    printf("Every row in the first group is indistinguishable from every row in the second.\n");
    return 0;
}
