// OCCTSwift#583: is 0 a value the surface local properties actually produce, or only a sentinel?
//
// The five Shape.faceLProp* getters return a bare double (or fill a bare point) and use 0 to mean
// "IsCurvatureDefined() was false here". That is only safe if 0 is never an answer. This probe
// walks real geometry through BRepLProp_SLProps, the exact class the bridge builds, and prints
// the definedness flag next to the four curvature scalars and the point, so the collisions are
// visible rather than argued.
//
// Build:
//   L=Libraries/OCCT.xcframework/macos-arm64
//   clang++ -std=c++17 -ObjC++ -w -I"$L/Headers" -L"$L" -lOCCT-macos \
//     -framework Foundation -framework AppKit -lz -lc++ \
//     Scripts/repro/583-lprop-zero-sentinel/occt_583_zero_is_ordinary.cpp -o /tmp/occt_583_zero
//   /tmp/occt_583_zero

#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLProp_SLProps.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <GeomLProp_CLProps.hxx>
#include <Geom_BezierCurve.hxx>
#include <Geom_Circle.hxx>
#include <Geom_ConicalSurface.hxx>
#include <Geom_CylindricalSurface.hxx>
#include <Geom_Line.hxx>
#include <Geom_Plane.hxx>
#include <Geom_SphericalSurface.hxx>
#include <Precision.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Face.hxx>
#include <gp_Ax2.hxx>
#include <gp_Ax3.hxx>

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

// occtLocalPropsResolution(), the value #529 converged all 18 adaptor sites onto.
static const double kResolution = Precision::Confusion();

struct Row {
    std::string label;
    double u, v;
};

static bool isZero(double x) { return x == 0.0; }

// Counters for the summary at the end.
static int gDefinedAllZero = 0;   // defined, and every curvature scalar is exactly 0
static int gDefinedGaussZero = 0; // defined, and the Gaussian curvature alone is exactly 0
static int gUndefined = 0;
static int gOriginPoint = 0;      // Value() == (0, 0, 0) exactly

static void sweep(const char* title, const TopoDS_Face& face, const std::vector<Row>& rows) {
    printf("\n=== %s ===\n", title);
    printf("%-26s %-9s %-13s %-13s %-13s %-13s %-8s %s\n",
           "point", "defined", "K (gauss)", "H (mean)", "kMax", "kMin", "umbilic", "Value()");
    for (const Row& r : rows) {
        BRepAdaptor_Surface as(face);
        BRepLProp_SLProps props(as, r.u, r.v, 2, kResolution);
        const bool defined = props.IsCurvatureDefined();

        double K = 0, H = 0, kMax = 0, kMin = 0;
        bool umbilic = false;
        if (defined) {
            K = props.GaussianCurvature();
            H = props.MeanCurvature();
            kMax = props.MaxCurvature();
            kMin = props.MinCurvature();
            umbilic = props.IsUmbilic();
        }
        gp_Pnt p = props.Value();

        if (!defined) {
            gUndefined++;
        } else {
            if (isZero(K) && isZero(H) && isZero(kMax) && isZero(kMin)) gDefinedAllZero++;
            else if (isZero(K)) gDefinedGaussZero++;
        }
        if (p.X() == 0.0 && p.Y() == 0.0 && p.Z() == 0.0) gOriginPoint++;

        printf("%-26s %-9s %-13.6g %-13.6g %-13.6g %-13.6g %-8s (%g, %g, %g)\n",
               r.label.c_str(), defined ? "yes" : "NO",
               K, H, kMax, kMin,
               defined ? (umbilic ? "yes" : "no") : "-",
               p.X(), p.Y(), p.Z());
    }
}

int main() {
    printf("BRepLProp_SLProps at Resolution = %g (occtLocalPropsResolution)\n", kResolution);
    printf("A dash in the umbilic column is the same \"no answer\" the bool getter spells false.\n");

    // A plane through the origin. Every point is flat, so all four curvature scalars are exactly
    // 0, with IsCurvatureDefined() true. This is the collision the five getters cannot express.
    {
        Handle(Geom_Plane) plane = new Geom_Plane(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
        TopoDS_Face face = BRepBuilderAPI_MakeFace(plane, -10, 10, -10, 10, Precision::Confusion());
        sweep("PLANE through the origin (flat everywhere, curvature defined everywhere)", face,
              {{"origin (u=0, v=0)", 0, 0},
               {"u=3, v=4", 3, 4},
               {"u=-7.5, v=2.25", -7.5, 2.25}});
    }

    // A cylinder. The Gaussian curvature is exactly 0 at every point of a developable surface,
    // while the mean curvature is not, so faceLPropGaussianCurvature returns the sentinel on a
    // perfectly ordinary point of the commonest solid in the test suite.
    {
        Handle(Geom_CylindricalSurface) cyl =
            new Geom_CylindricalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 3.0);
        TopoDS_Face face = BRepBuilderAPI_MakeFace(cyl, 0, 2 * M_PI, 0, 12, Precision::Confusion());
        sweep("CYLINDER radius 3 (Gaussian curvature is 0 everywhere, and defined)", face,
              {{"u=0, v=0", 0, 0},
               {"u=1.1, v=6", 1.1, 6},
               {"u=4.0, v=11.5", 4.0, 11.5}});
    }

    // The cone from the #529 parity suite, apex radius 0. Sweeping v towards the apex crosses the
    // resolution and IsCurvatureDefined() goes false: the sentinel path.
    {
        Handle(Geom_ConicalSurface) cone =
            new Geom_ConicalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), M_PI / 6, 0.0);
        TopoDS_Face face = BRepBuilderAPI_MakeFace(cone, 0, 2 * M_PI, -1.0, 10.0, Precision::Confusion());
        sweep("CONE apex radius 0 (curvature falls out of definition at the apex)", face,
              {{"v=1.0 (ordinary)", 0, 1.0},
               {"v=1e-3", 0, 1e-3},
               {"v=1e-6", 0, 1e-6},
               {"v=1e-8 (past the gate)", 0, 1e-8},
               {"v=0 (the apex)", 0, 0.0}});
    }

    // A sphere at its pole, the other classic degeneracy.
    {
        Handle(Geom_SphericalSurface) sph =
            new Geom_SphericalSurface(gp_Ax3(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5.0);
        TopoDS_Face face = BRepBuilderAPI_MakeFace(sph, Precision::Confusion());
        sweep("SPHERE radius 5 (v = +/- pi/2 are the poles)", face,
              {{"v=0 (equator)", 0, 0.0},
               {"v=1.5 (near pole)", 0, 1.5},
               {"v=pi/2 (the pole)", 0, M_PI / 2},
               {"v=-pi/2 (the pole)", 0, -M_PI / 2}});
    }

    // The curve half of the same class, which #583 leaves alone. Shape.edgeCurvatureLP(at:),
    // Curve3D.curvature(at:), Curve3D.localCurvature(at:) and Curve2D.curvature(at:) all return a
    // bare double gated on IsTangentDefined(), and a straight edge's curvature is exactly 0 with the
    // tangent perfectly well defined, so 0 collides there too. Measured here so the follow-up has
    // numbers rather than an analogy.
    {
        printf("\n=== CURVES: the same collision, on the entry points #583 does not change ===\n");
        printf("%-34s %-11s %-14s %s\n", "curve", "tangent", "Curvature()", "reading");

        struct CurveRow {
            const char* label;
            Handle(Geom_Curve) curve;
            double u;
            const char* reading;
        };

        Handle(Geom_Line) line = new Geom_Line(gp_Pnt(0, 0, 0), gp_Dir(1, 0, 0));
        Handle(Geom_Circle) circle = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 4.0);

        // A cubic Bezier whose first two poles coincide: D1(0) is null, the tangent search falls
        // through to D2, and the curvature comes back as the RealLast() infinity sentinel: a
        // *different* sentinel, and the one case the double return does distinguish.
        TColgp_Array1OfPnt cuspPoles(1, 4);
        cuspPoles(1) = gp_Pnt(0, 0, 0);
        cuspPoles(2) = gp_Pnt(0, 0, 0);
        cuspPoles(3) = gp_Pnt(1, 1, 0);
        cuspPoles(4) = gp_Pnt(2, 0, 0);
        Handle(Geom_BezierCurve) cusp = new Geom_BezierCurve(cuspPoles);

        // Every pole at one point: no derivative of any order is significant, so the tangent search
        // runs out and IsTangentDefined() is false. This is the row that collides with the line.
        TColgp_Array1OfPnt deadPoles(1, 4);
        for (int i = 1; i <= 4; ++i) deadPoles(i) = gp_Pnt(0, 0, 0);
        Handle(Geom_BezierCurve) dead = new Geom_BezierCurve(deadPoles);

        std::vector<CurveRow> rows = {
            {"line (straight)", line, 5.0, "genuinely 0"},
            {"circle radius 4", circle, 1.0, "genuinely 1/4"},
            {"Bezier, first two poles equal", cusp, 0.0, "cusp: RealLast() sentinel"},
            {"Bezier, all poles equal", dead, 0.5, "no answer at all"},
        };
        for (const CurveRow& r : rows) {
            GeomLProp_CLProps props(r.curve, r.u, 2, kResolution);
            const bool tangent = props.IsTangentDefined();
            const double k = tangent ? props.Curvature() : 0.0;
            printf("%-34s %-11s %-14.6g %s\n", r.label, tangent ? "yes" : "NO", k, r.reading);
        }
        printf("The first and last rows both reach a caller as the double 0.\n");
    }

    printf("\n=== summary ===\n");
    printf("points where curvature is DEFINED and all four scalars are exactly 0 : %d\n", gDefinedAllZero);
    printf("points where curvature is DEFINED and the Gaussian alone is exactly 0: %d\n", gDefinedGaussZero);
    printf("points where curvature is UNDEFINED (the sentinel path)              : %d\n", gUndefined);
    printf("points whose Value() is exactly (0, 0, 0)                            : %d\n", gOriginPoint);
    printf("\nEvery one of the first two groups is reported by Shape.faceLProp*Curvature with the\n");
    printf("same 0 the third group is, and the fourth group with the same (0,0,0) a null handle is.\n");
    return 0;
}
