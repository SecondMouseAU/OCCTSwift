// Ports of the GTests in open upstream PRs #1537 and #1592 to a plain program, to see whether the defect each PR fixes
// reproduces on a given kernel. usage: pr_ports 1537 | 1592. One summary line per scenario.
#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Fuse.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepCheck_Analyzer.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepPrimAPI_MakePrism.hxx>
#include <GProp_GProps.hxx>
#include <NCollection_IndexedMap.hxx>
#include <ShapeUpgrade_UnifySameDomain.hxx>
#include <Standard_Failure.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_ShapeMapHasher.hxx>
#include <TopoDS.hxx>
#include <gp_Ax2.hxx>
#include <cmath>
#include <cstdio>
#include <cstring>
using EMap = NCollection_IndexedMap<TopoDS_Shape, TopTools_ShapeMapHasher>;
static double vol(const TopoDS_Shape& s) { GProp_GProps p; BRepGProp::VolumeProperties(s, p); return p.Mass(); }
static int nsol(const TopoDS_Shape& s) { int n = 0; for (TopExp_Explorer e(s, TopAbs_SOLID); e.More(); e.Next()) ++n; return n; }
static void t1537(bool both)
{
  for (bool rev : {false, true})
  {
    gp_Dir d(0, 0, rev ? -1 : 1);
    gp_Ax2 ax(gp_Pnt(-60, rev ? 25 : -25, rev ? 12 : 0), d, gp_Dir(1, 0, 0));
    TopoDS_Shape fused = BRepPrimAPI_MakeBox(ax, 120, 50, 12).Shape();
    double cz = rev ? 32.0 : 0.0;
    for (int i = 0; i < (both ? 2 : 1); ++i)
    {
      gp_Ax2 a(gp_Pnt(i == 0 ? -60.0 : 60.0, 0, cz), d);
      fused = BRepAlgoAPI_Fuse(fused, BRepPrimAPI_MakeCylinder(a, 25, 32).Shape()).Shape();
    }
    ShapeUpgrade_UnifySameDomain u(fused, true, true, true); u.Build();
    TopoDS_Shape base = u.Shape();
    EMap edges; TopExp::MapShapes(base, TopAbs_EDGE, edges);
    for (int k = 1; k <= edges.Extent(); ++k)
    {
      TopoDS_Edge e = TopoDS::Edge(edges(k));
      GProp_GProps L; BRepGProp::LinearProperties(e, L); gp_Pnt c = L.CentreOfMass();
      if (std::abs(L.Mass() - 120) > 1e-7 || std::abs(c.Z() - 12) > 1e-7 || std::abs(std::abs(c.Y()) - 25) > 1e-7) continue;
      for (double r : {1.0, 2.0, 11.999})
      {
        try
        {
          BRepFilletAPI_MakeFillet f(base); f.Add(r, e); f.Build();
          if (!f.IsDone()) { printf("1537 %s reversed=%d edgeY=%+.0f r=%g: done=0\n", both ? "bothEnds" : "oneEnd", rev, c.Y(), r); continue; }
          TopoDS_Shape s = f.Shape();
          printf("1537 %s reversed=%d edgeY=%+.0f r=%g: done=1 valid=%d solids=%d vol=%.3f (base %.3f)\n", both ? "bothEnds" : "oneEnd", rev, c.Y(), r, BRepCheck_Analyzer(s).IsValid(), nsol(s), vol(s), vol(base));
        }
        catch (Standard_Failure const& x) { printf("1537 reversed=%d r=%g: EXC %s\n", rev, r, x.GetMessageString()); }
      }
    }
  }
}
static void t1592()
{
  const double R = 5.0;
  TopoDS_Shape cyl = BRepPrimAPI_MakeCylinder(gp_Ax2(gp::Origin(), gp::DY()), 40.0, 80.0).Shape();
  BRepBuilderAPI_MakePolygon o;
  o.Add(gp_Pnt(-10, 0, 0)); o.Add(gp_Pnt(-10, 80, 0)); o.Add(gp_Pnt(-10, 80, 40)); o.Add(gp_Pnt(-10, 120, 100));
  o.Add(gp_Pnt(-10, -40, 100)); o.Add(gp_Pnt(-10, 0, 40)); o.Close();
  TopoDS_Shape plate = BRepPrimAPI_MakePrism(BRepBuilderAPI_MakeFace(o.Wire()).Face(), gp_Vec(20, 0, 0)).Shape();
  TopoDS_Shape fu = BRepAlgoAPI_Fuse(cyl, plate).Shape();
  ShapeUpgrade_UnifySameDomain u(fu); u.Build(); TopoDS_Shape solid = u.Shape();
  printf("1592 base valid=%d vol=%.3f\n", BRepCheck_Analyzer(solid).IsValid(), vol(solid));
  EMap edges; TopExp::MapShapes(solid, TopAbs_EDGE, edges);
  std::vector<TopoDS_Edge> conc;
  for (int i = 1; i <= edges.Extent(); ++i)
  {
    TopoDS_Edge e = TopoDS::Edge(edges(i)); BRepAdaptor_Curve c(e);
    gp_Pnt a = c.Value(c.FirstParameter()), b = c.Value(c.LastParameter());
    if (c.GetType() == GeomAbs_Line && std::abs(std::abs(a.X()) - 10) < 1e-6 && std::abs(b.X() - a.X()) < 1e-6
        && std::abs(b.Z() - a.Z()) < 1e-6 && std::abs(a.Z() - std::sqrt(1500.0)) < 1e-6) conc.push_back(e);
  }
  printf("1592 concave edges found: %zu\n", conc.size());
  double expect = vol(solid);
  for (auto& e : conc)
  {
    BRepFilletAPI_MakeFillet f(solid); f.Add(R, e); f.Build();
    printf("1592 alone: done=%d valid=%d vol=%.3f\n", f.IsDone(), f.IsDone() ? BRepCheck_Analyzer(f.Shape()).IsValid() : -1, f.IsDone() ? vol(f.Shape()) : 0.0);
    if (f.IsDone()) expect += vol(f.Shape()) - vol(solid);
  }
  BRepFilletAPI_MakeFillet f(solid); for (auto& e : conc) f.Add(R, e); f.Build();
  if (f.IsDone()) printf("1592 both: done=1 valid=%d solids=%d vol=%.3f expected=%.3f\n", BRepCheck_Analyzer(f.Shape()).IsValid(), nsol(f.Shape()), vol(f.Shape()), expect);
  else printf("1592 both: done=0\n");
}
int main(int argc, char** argv)
{
  if (!strcmp(argv[1], "1537")) { t1537(false); t1537(true); } else t1592();
}
