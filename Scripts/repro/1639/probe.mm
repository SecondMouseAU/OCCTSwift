// Ground truth for #1639: what BRepLib::UpdateEdgeTol's two bounds actually do, and whether the
// Bool it returns ever tracks "the tolerance moved".
//
// Build: see CLAUDE.md, "Compile a Ground Truth C++ Test".

#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepLib.hxx>
#include <ShapeFix_ShapeTolerance.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Builder.hxx>
#include <BRep_Tool.hxx>
#include <Geom2d_Line.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <Geom_Plane.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <gp_Pln.hxx>

#include <cmath>
#include <cstdio>

static void report(const char* label, const TopoDS_Edge& e, double minReq, double maxCheck)
{
  double before = BRep_Tool::Tolerance(e);
  bool   ret    = BRepLib::UpdateEdgeTol(e, minReq, maxCheck);
  double after  = BRep_Tool::Tolerance(e);
  printf("   %-26s minReq %-9g maxCheck %-9g before %-11g returned %-5s after %-11g moved: %s\n",
         label, minReq, maxCheck, before, ret ? "true" : "false", after,
         (after != before) ? "YES" : "no");
}

// A straight 3D edge from (0,0,0) to (10,0,0), carrying a pcurve on the z=0 plane that is a
// straight 2D line from (0,0) to (10, skew): the pcurve's 3D image drifts from the 3D curve by up
// to `skew`, so the edge's real tolerance requirement is about `skew`.
static TopoDS_Edge skewedPCurveEdge(double skew)
{
  TopoDS_Edge          e     = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
  Handle(Geom_Plane)   plane = new Geom_Plane(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)));
  gp_Dir2d             dir(10.0, skew);
  Handle(Geom2d_Line)  line = new Geom2d_Line(gp_Pnt2d(0, 0), dir);
  BRep_Builder         b;
  b.UpdateEdge(e, new Geom2d_TrimmedCurve(line, 0.0, 10.0 / dir.X()), plane, TopLoc_Location(),
               BRep_Tool::Tolerance(e));
  b.Range(e, 0.0, 10.0);
  return e;
}

int main()
{
  printf("=== 1. box edge (exact pcurves), sweep of both bounds\n");
  TopoDS_Shape box = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
  TopExp_Explorer ex(box, TopAbs_EDGE);
  TopoDS_Edge     boxEdge = TopoDS::Edge(ex.Current());
  report("box edge", boxEdge, 1e-5, 1e-3);
  report("box edge", boxEdge, 1e-5, 1e-9);  // below the edge's own 1e-7: should refuse
  report("box edge", boxEdge, 1e-5, 1e300);

  printf("\n=== 2. edge with a pcurve that drifts from its 3D curve\n");
  for (double skew : {0.001, 0.01, 0.1})
  {
    char label[64];
    snprintf(label, sizeof(label), "skew %g", skew);
    TopoDS_Edge e = skewedPCurveEdge(skew);
    report(label, e, 1e-7, 1.0);
  }

  printf("\n=== 3. the same drifting edge, MaxToleranceToCheck below the edge's own tolerance\n");
  {
    TopoDS_Edge  e = skewedPCurveEdge(0.01);
    BRep_Builder b;
    b.UpdateEdge(e, 0.05);  // make the edge coded tolerance 0.05
    report("coded 0.05, maxCheck 0.01", e, 1e-7, 0.01);
    TopoDS_Edge e2 = skewedPCurveEdge(0.01);
    b.UpdateEdge(e2, 0.05);
    report("coded 0.05, maxCheck 1.0", e2, 1e-7, 1.0);
  }

  printf("\n=== 4. what the bridge's hardcoded maxCheck = tol * 100 refuses\n");
  {
    TopoDS_Edge  e = skewedPCurveEdge(0.01);
    BRep_Builder b;
    b.UpdateEdge(e, 0.05);
    report("tol 1e-5 -> maxCheck 1e-3", e, 1e-5, 1e-5 * 100.0);
    TopoDS_Edge e2 = skewedPCurveEdge(0.01);
    b.UpdateEdge(e2, 0.05);
    report("tol 1e-5, maxCheck 1.0", e2, 1e-5, 1.0);
  }

  printf("\n=== 5. the Swift tests' fixture: a box whose edges were forced to a loose tolerance\n");
  for (double forced : {0.05, 0.5})
  {
    TopoDS_Shape             b1 = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    ShapeFix_ShapeTolerance  st;
    st.SetTolerance(b1, forced, TopAbs_EDGE);
    TopExp_Explorer e1(b1, TopAbs_EDGE);
    char            label[64];
    snprintf(label, sizeof(label), "forced %g, maxCheck inf", forced);
    report(label, TopoDS::Edge(e1.Current()), 1e-7, HUGE_VAL);

    TopoDS_Shape            b2 = BRepPrimAPI_MakeBox(10.0, 10.0, 10.0).Shape();
    ShapeFix_ShapeTolerance st2;
    st2.SetTolerance(b2, forced, TopAbs_EDGE);
    TopExp_Explorer e2(b2, TopAbs_EDGE);
    snprintf(label, sizeof(label), "forced %g, maxCheck tol*100", forced);
    report(label, TopoDS::Edge(e2.Current()), 1e-7, 1e-7 * 100.0);
  }
  return 0;
}
