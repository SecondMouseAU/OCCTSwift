// Probe: does BRepOffsetAPI_MakeFilling, built with the bridge's exact default parameters
// (occtFillingMakeBuilder's defaults: Degree=3, NbPtsOnCur=15, NbIter=2, Tol2d=Tol3d*0.1,
// Tol3d=1e-4, TolAng=0.01, TolCurv=0.1, MaxDeg=8, MaxSegments=9), ever report IsDone()==true
// with G0Error() exceeding the requested Tol3d? OCCTShapeFillBuildResult only checks IsDone().

#include <BRepOffsetAPI_MakeFilling.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom_BezierCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pnt.hxx>
#include <cstdio>
#include <cmath>
#include <vector>

static TopoDS_Edge bezierEdge(std::vector<gp_Pnt> pts) {
    TColgp_Array1OfPnt poles(1, (int)pts.size());
    for (int i = 0; i < (int)pts.size(); i++) poles.SetValue(i + 1, pts[i]);
    Handle(Geom_BezierCurve) curve = new Geom_BezierCurve(poles);
    return BRepBuilderAPI_MakeEdge(curve);
}

int main() {
    // Four warped (non-planar, high curvature) boundary edges -- a hyperbolic-paraboloid-ish
    // twisted quad, hard for a low-degree/low-segment G0 fit to reach 1e-4.
    double amp = 6.0;
    TopoDS_Edge e1 = bezierEdge({ gp_Pnt(0,0,0), gp_Pnt(3,0, amp), gp_Pnt(7,0,-amp), gp_Pnt(10,0,0) });
    TopoDS_Edge e2 = bezierEdge({ gp_Pnt(10,0,0), gp_Pnt(10,3,-amp), gp_Pnt(10,7,amp), gp_Pnt(10,10,0) });
    TopoDS_Edge e3 = bezierEdge({ gp_Pnt(10,10,0), gp_Pnt(7,10,amp), gp_Pnt(3,10,-amp), gp_Pnt(0,10,0) });
    TopoDS_Edge e4 = bezierEdge({ gp_Pnt(0,10,0), gp_Pnt(0,7,-amp), gp_Pnt(0,3,amp), gp_Pnt(0,0,0) });

    struct TolCase { double tol3d; const char* label; };
    std::vector<TolCase> cases = { {1e-4, "bridge-default-1e-4"}, {1e-6, "tighter-1e-6"}, {1e-8, "extreme-1e-8"} };

    for (auto& c : cases) {
        // Mirror occtFillingMakeBuilder's exact defaults.
        BRepOffsetAPI_MakeFilling filling(
            3,           // Degree
            15,          // NbPtsOnCur
            2,           // NbIter
            false,       // Anisotropie
            c.tol3d * 0.1, // Tol2d
            c.tol3d,       // Tol3d
            0.01,        // TolAng
            0.1,         // TolCurv
            8,           // MaxDeg
            9            // MaxSegments
        );
        for (TopoDS_Edge e : {e1, e2, e3, e4}) filling.Add(e, GeomAbs_C0, true);
        try {
            filling.Build();
            bool done = filling.IsDone();
            double g0 = done ? filling.G0Error() : -1;
            printf("%-22s tol3d=%-10g isDone=%-5s G0Error=%-12g %s\n",
                   c.label, c.tol3d, done ? "true" : "false", g0,
                   (done && g0 > c.tol3d) ? "EXCEEDS TOLERANCE, ACCEPTED ANYWAY" : "");
        } catch (...) {
            printf("%-22s tol3d=%-10g THREW\n", c.label, c.tol3d);
        }
    }
    return 0;
}
