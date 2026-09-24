// #1979 kernel parity for ChFi2dBuilderTests, ChFi2dChamferAPITests, ChFi2dFilletAlgoTests,
// ChFi2dFilletAPITests and CompBezier2dToBSpline2dTests: the same OCCT calls, with the same
// inputs, that the bridge functions those tests reach make.
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepGProp.hxx>
#include <GProp_GProps.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <GCPnts_AbscissaPoint.hxx>
#include <BRep_Tool.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <ChFi2d_Builder.hxx>
#include <ChFi2d_ChamferAPI.hxx>
#include <ChFi2d_FilletAlgo.hxx>
#include <ChFi2d_FilletAPI.hxx>
#include <Convert_CompBezierCurves2dToBSplineCurve2d.hxx>
#include <gp_Pln.hxx>
#include <cstdio>

static double len(const TopoDS_Edge& e)
{
  BRepAdaptor_Curve c(e);
  return GCPnts_AbscissaPoint::Length(c);
}

static void edgeInfo(const char* tag, const TopoDS_Edge& e)
{
  gp_Pnt a = BRep_Tool::Pnt(TopExp::FirstVertex(e, true));
  gp_Pnt b = BRep_Tool::Pnt(TopExp::LastVertex(e, true));
  printf("%s (%.12g, %.12g, %.12g)->(%.12g, %.12g, %.12g) length=%.12g\n", tag, a.X(), a.Y(), a.Z(),
         b.X(), b.Y(), b.Z(), len(e));
}

static void faceInfo(const char* tag, const TopoDS_Face& f)
{
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(f, TopAbs_EDGE, em);
  GProp_GProps g;
  BRepGProp::SurfaceProperties(f, g);
  printf("%s edges=%d area=%.12g\n", tag, em.Extent(), g.Mass());
}

static TopoDS_Face rect()
{
  gp_Pnt                  p1(-5, -5, 0), p2(5, -5, 0), p3(5, 5, 0), p4(-5, 5, 0);
  BRepBuilderAPI_MakeWire w;
  w.Add(BRepBuilderAPI_MakeEdge(p1, p2));
  w.Add(BRepBuilderAPI_MakeEdge(p2, p3));
  w.Add(BRepBuilderAPI_MakeEdge(p3, p4));
  w.Add(BRepBuilderAPI_MakeEdge(p4, p1));
  return BRepBuilderAPI_MakeFace(w.Wire(), true);
}

int main()
{
  // ChFi2dBuilderTests (OCCTChFi2dAddFillet / OCCTChFi2dAddChamfer / OCCTChFi2dAddChamferAngle)
  {
    TopoDS_Face f = rect();
    faceInfo("rect", f);
    TopTools_IndexedMapOfShape vm, em;
    TopExp::MapShapes(f, TopAbs_VERTEX, vm);
    TopExp::MapShapes(f, TopAbs_EDGE, em);
    gp_Pnt v1 = BRep_Tool::Pnt(TopoDS::Vertex(vm(1)));
    printf("vertex index 0 = (%.12g, %.12g, %.12g)\n", v1.X(), v1.Y(), v1.Z());
    {
      ChFi2d_Builder b(f);
      b.AddFillet(TopoDS::Vertex(vm(1)), 2.0);
      printf("AddFillet status=%d (IsDone=%d)\n", (int)b.Status(), (int)ChFi2d_IsDone);
      faceInfo("  fillet result", b.Result());
    }
    {
      ChFi2d_Builder b(f);
      b.AddChamfer(TopoDS::Edge(em(1)), TopoDS::Edge(em(2)), 2.0, 2.0);
      printf("AddChamfer(e0, e1, 2, 2) status=%d\n", (int)b.Status());
      faceInfo("  chamfer result", b.Result());
    }
    {
      ChFi2d_Builder b(f);
      b.AddChamfer(TopoDS::Edge(em(1)), TopoDS::Vertex(vm(1)), 2.0, M_PI / 4);
      printf("AddChamfer(e0, v0, 2, pi/4) status=%d\n", (int)b.Status());
      faceInfo("  chamfer-angle result", b.Result());
    }
  }
  // ChFi2dChamferAPITests (OCCTChFi2dChamferEdges)
  {
    TopoDS_Edge       e1 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge       e2 = BRepBuilderAPI_MakeEdge(gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0));
    ChFi2d_ChamferAPI c(e1, e2);
    printf("ChamferAPI perform=%d\n", c.Perform());
    TopoDS_Edge m1, m2;
    TopoDS_Edge ce = c.Result(m1, m2, 3.0, 3.0);
    edgeInfo("  chamfer", ce);
    edgeInfo("  edge1", m1);
    edgeInfo("  edge2", m2);
  }
  // ChFi2dFilletAlgoTests (OCCTChFi2dFilletAlgo)
  {
    TopoDS_Edge       e1 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge       e2 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0));
    gp_Pln            pl(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    ChFi2d_FilletAlgo a(e1, e2, pl);
    printf("FilletAlgo perform=%d NbResults(corner)=%d\n", a.Perform(2.0),
           a.NbResults(gp_Pnt(0, 0, 0)));
    TopoDS_Edge r1, r2;
    TopoDS_Edge fe = a.Result(gp_Pnt(0, 0, 0), r1, r2);
    edgeInfo("  fillet", fe);
    edgeInfo("  edge1", r1);
    edgeInfo("  edge2", r2);
  }
  // ChFi2dFilletAPITests (OCCTChFi2dFilletEdges)
  {
    TopoDS_Edge      e1 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    TopoDS_Edge      e2 = BRepBuilderAPI_MakeEdge(gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0));
    gp_Pln           pl(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    ChFi2d_FilletAPI a(e1, e2, pl);
    printf("FilletAPI perform=%d NbResults=%d\n", a.Perform(2.0), a.NbResults(gp_Pnt(10, 0, 0)));
    TopoDS_Edge r1, r2;
    TopoDS_Edge fe = a.Result(gp_Pnt(10, 0, 0), r1, r2);
    edgeInfo("  fillet", fe);
    edgeInfo("  edge1", r1);
    edgeInfo("  edge2", r2);
  }
  {
    TopoDS_Edge      e1 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 10), gp_Pnt(5, 0, 10));
    TopoDS_Edge      e2 = BRepBuilderAPI_MakeEdge(gp_Pnt(0, 0, 10), gp_Pnt(0, 5, 10));
    gp_Pln           pl(gp_Pnt(0, 0, 10), gp_Dir(0, 0, 1));
    ChFi2d_FilletAPI a(e1, e2, pl);
    printf("FilletAPI z=10 perform=%d NbResults=%d\n", a.Perform(1.0),
           a.NbResults(gp_Pnt(0, 0, 10)));
    TopoDS_Edge r1, r2;
    TopoDS_Edge fe = a.Result(gp_Pnt(0, 0, 10), r1, r2);
    edgeInfo("  fillet", fe);
    edgeInfo("  edge1", r1);
    edgeInfo("  edge2", r2);
  }
  // CompBezier2dToBSpline2dTests (OCCTConvertCompBezier2dToBSpline2d)
  {
    auto run = [](const char* tag, const std::vector<std::vector<gp_Pnt2d>>& segs) {
      Convert_CompBezierCurves2dToBSplineCurve2d conv;
      for (auto& s : segs)
      {
        NCollection_Array1<gp_Pnt2d> a(1, (int)s.size());
        for (int i = 0; i < (int)s.size(); i++)
          a(i + 1) = s[i];
        conv.AddCurve(a);
      }
      conv.Perform();
      printf("%s degree=%d poles=%d knots=%d\n", tag, conv.Degree(), conv.NbPoles(), conv.NbKnots());
      if (conv.NbPoles() > 20)
        return;
      NCollection_Array1<gp_Pnt2d> p(1, conv.NbPoles());
      conv.Poles(p);
      for (int i = 1; i <= p.Length(); i++)
        printf("  pole %d (%.12g, %.12g)\n", i, p(i).X(), p(i).Y());
      NCollection_Array1<double> k(1, conv.NbKnots());
      NCollection_Array1<int>    m(1, conv.NbKnots());
      conv.KnotsAndMults(k, m);
      for (int i = 1; i <= k.Length(); i++)
        printf("  knot %.12g mult %d\n", k(i), m(i));
    };
    run("CompBezier quadratic", {{gp_Pnt2d(0, 0), gp_Pnt2d(1, 2), gp_Pnt2d(2, 0)}});
    run("CompBezier two cubics",
        {{gp_Pnt2d(0, 0), gp_Pnt2d(1, 1), gp_Pnt2d(2, 1), gp_Pnt2d(3, 0)},
         {gp_Pnt2d(3, 0), gp_Pnt2d(4, -1), gp_Pnt2d(5, -1), gp_Pnt2d(6, 0)}});
    std::vector<std::vector<gp_Pnt2d>> many;
    for (int i = 0; i < 60; i++)
    {
      double x = i * 3;
      many.push_back({gp_Pnt2d(x, 0), gp_Pnt2d(x + 1, 1), gp_Pnt2d(x + 2, -1), gp_Pnt2d(x + 3, 0)});
    }
    run("CompBezier 60 cubics (bridge rejects > 100 poles or > 50 knots)", many);
  }
  return 0;
}
