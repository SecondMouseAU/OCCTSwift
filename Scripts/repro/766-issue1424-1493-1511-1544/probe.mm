// #766 kernel parity for Issue1424BndLibFaceNullGuardTests, Issue1493MedialAxisDistanceOnArcTests,
// Issue1511EllipseCurvatureExtremaTests and Issue1544DistanceSSDeflectionDefaultTests: the same
// OCCT calls, on the same inputs, that the bridge functions those tests reach make.
#include <BRepAdaptor_Surface.hxx>
#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepExtrema_DistanceSS.hxx>
#include <BRepMAT2d_BisectingLocus.hxx>
#include <BRepMAT2d_Explorer.hxx>
#include <BRepPrimAPI_MakeSphere.hxx>
#include <Bisector_Bisec.hxx>
#include <BndLib_AddSurface.hxx>
#include <Bnd_Box.hxx>
#include <Geom2dAPI_ProjectPointOnCurve.hxx>
#include <Geom2d_Ellipse.hxx>
#include <Geom2d_TrimmedCurve.hxx>
#include <GeomLProp_CurAndInf2d.hxx>
#include <Geom_Circle.hxx>
#include <LProp_CurAndInf.hxx>
#include <MAT_Arc.hxx>
#include <MAT_Graph.hxx>
#include <MAT_Node.hxx>
#include <Precision.hxx>
#include <TopExp_Explorer.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <limits>
#include <vector>

// Same as OCCTMedialAxis::distanceToBoundary in OCCTBridge_Geom2d_Bisector.mm.
static double distanceToBoundary(const std::vector<Handle(Geom2d_Curve)>& curves, const gp_Pnt2d& pt)
{
  double minDist = std::numeric_limits<double>::max();
  for (const auto& c : curves)
  {
    try
    {
      Geom2dAPI_ProjectPointOnCurve proj(pt, c);
      if (proj.NbPoints() > 0 && proj.LowerDistance() < minDist)
        minDist = proj.LowerDistance();
    }
    catch (...)
    {
    }
  }
  return minDist < std::numeric_limits<double>::max() ? minDist : 0.0;
}

int main()
{
  // ---- #1424: OCCTBndLibFace on the first face of Shape.sphere(radius: 5), tolerance 0
  {
    TopoDS_Shape sph = BRepPrimAPI_MakeSphere(5).Shape();
    TopExp_Explorer ex(sph, TopAbs_FACE);
    Bnd_Box box;
    BRepAdaptor_Surface as(TopoDS::Face(ex.Current()));
    BndLib_AddSurface::Add(as, 0.0, box);
    double x0, y0, z0, x1, y1, z1;
    box.Get(x0, y0, z0, x1, y1, z1);
    printf("#1424 BndLib_AddSurface sphere r5 face: min=(%.17g, %.17g, %.17g) max=(%.17g, %.17g, %.17g)\n",
           x0, y0, z0, x1, y1, z1);
    // A null face: the bridge never reaches this (occtShapeIsPresent refuses first and writes 0s).
    try
    {
      Bnd_Box             nb;
      BRepAdaptor_Surface na(TopoDS_Face{});
      BndLib_AddSurface::Add(na, 0.0, nb);
      printf("#1424 null face: IsVoid=%d\n", nb.IsVoid());
      nb.Get(x0, y0, z0, x1, y1, z1);
      printf("#1424 null face Get did not throw\n");
    }
    catch (const Standard_Failure& e)
    {
      printf("#1424 null face: Get threw %s (the bridge catch writes 0s)\n", e.what());
    }
  }

  // ---- #1493: medial axis of the reflex L-shape, as OCCTMedialAxisCompute builds it
  {
    double pts[6][2] = {{0, 0}, {10, 0}, {10, 4}, {4, 4}, {4, 8}, {0, 8}};
    BRepBuilderAPI_MakeWire mw;
    for (int i = 0; i < 6; i++)
    {
      gp_Pnt a(pts[i][0], pts[i][1], 0), b(pts[(i + 1) % 6][0], pts[(i + 1) % 6][1], 0);
      mw.Add(BRepBuilderAPI_MakeEdge(a, b).Edge());
    }
    TopoDS_Face              face = BRepBuilderAPI_MakeFace(mw.Wire(), true).Face();
    BRepMAT2d_Explorer       explorer;
    BRepMAT2d_BisectingLocus locus;
    explorer.Perform(face);
    locus.Compute(explorer, 1, MAT_Left, GeomAbs_Arc, Standard_False);
    Handle(MAT_Graph) graph = locus.Graph();
    std::vector<Handle(Geom2d_Curve)> curves;
    for (int c = 1; c <= explorer.NumberOfContours(); c++)
      for (explorer.Init(c); explorer.More(); explorer.Next())
        curves.push_back(explorer.Value());
    printf("#1493 L-shape medial axis: IsDone=%d arcs=%d nodes=%d boundaryCurves=%d\n", locus.IsDone(),
           graph->NumberOfArcs(), graph->NumberOfNodes(), (int)curves.size());
    for (int i = 1; i <= graph->NumberOfArcs(); i++)
    {
      Handle(MAT_Arc) arc     = graph->Arc(i);
      gp_Pnt2d        firstPt = locus.GeomElt(arc->FirstNode());
      gp_Pnt2d        lastPt  = locus.GeomElt(arc->SecondNode());
      double          d0 = distanceToBoundary(curves, firstPt), d1 = distanceToBoundary(curves, lastPt);
      Standard_Boolean            reverse = Standard_False;
      Bisector_Bisec              bisec   = locus.GeomBis(arc, reverse);
      Handle(Geom2d_TrimmedCurve) tc      = bisec.Value();
      double u0 = tc->FirstParameter(), u1 = tc->LastParameter();
      if (Precision::IsNegativeInfinite(u0))
        u0 = -1000.0;
      if (Precision::IsPositiveInfinite(u1))
        u1 = 1000.0;
      gp_Pnt2d mid;
      tc->D0(0.5 * (u0 + u1), mid);
      double dmid = distanceToBoundary(curves, mid);
      printf("  arc %d: node %d -> %d, d(t=0)=%.17g d(t=1)=%.17g d(t=0.5, real curve)=%.17g "
             "linear=%.17g deviation=%.17g\n",
             i, arc->FirstNode()->Index(), arc->SecondNode()->Index(), d0, d1, dmid, 0.5 * (d0 + d1),
             std::fabs(0.5 * (d0 + d1) - dmid));
    }
  }

  // ---- #1511: curvature extrema of Geom2d_Ellipse(major 10, minor 5) over [0, 2pi]
  {
    Handle(Geom2d_Ellipse) el = new Geom2d_Ellipse(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10, 5);
    GeomLProp_CurAndInf2d  cai;
    cai.PerformCurExt(el);
    printf("#1511 GeomLProp_CurAndInf2d::PerformCurExt ellipse(10,5): IsDone=%d NbPoints=%d\n",
           cai.IsDone(), cai.NbPoints());
    for (int i = 1; i <= cai.NbPoints(); i++)
      printf("  %.17g %s\n", cai.Parameter(i),
             cai.Type(i) == LProp_MinCur ? "LProp_MinCur" : cai.Type(i) == LProp_MaxCur ? "LProp_MaxCur" : "LProp_Inflection");
  }

  // ---- #1544: BRepExtrema_DistanceSS on the two rotated radius-10 circles, deflection 1e-7 and 100
  {
    Handle(Geom_Circle) c1 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    Handle(Geom_Circle) c2 = new Geom_Circle(gp_Ax2(gp_Pnt(30, 0, 0), gp_Dir(0, 0, 1)), 10);
    c1->Rotate(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 0.65);
    c2->Rotate(gp_Ax1(gp_Pnt(30, 0, 0), gp_Dir(0, 0, 1)), 0.2);
    TopoDS_Edge e1 = BRepBuilderAPI_MakeEdge(c1).Edge();
    TopoDS_Edge e2 = BRepBuilderAPI_MakeEdge(c2).Edge();
    double      defl[2] = {1e-7, 100.0};
    for (double d : defl)
    {
      Bnd_Box b1, b2;
      BRepBndLib::Add(e1, b1);
      BRepBndLib::Add(e2, b2);
      BRepExtrema_DistanceSS dss(e1, e2, b1, b2, 1e10, d);
      gp_Pnt                 p1 = dss.Seq1Value().First().Point(), p2 = dss.Seq2Value().First().Point();
      printf("#1544 DistanceSS deflection=%g: IsDone=%d DistValue=%.17g solutions=%d first pair distance=%.17g\n",
             d, dss.IsDone(), dss.DistValue(), dss.Seq1Value().Size(), p1.Distance(p2));
    }
  }
  return 0;
}
