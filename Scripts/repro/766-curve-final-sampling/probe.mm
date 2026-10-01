// Epic #766 kernel-parity probe for the last OCCTCurveTests files (#1978):
// ProjectionOnCurve, QuasiUniformAbscissa, QuasiUniformDeflection, SketchArcCircle,
// SurfToAnaSurf, TopTransCurveTransition, UniformAbscissa, WireEdgePolyline.
// Each block calls the OCCT class the bridge calls, with the inputs the Swift test passes.

#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <GCPnts_QuasiUniformAbscissa.hxx>
#include <GCPnts_QuasiUniformDeflection.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <GCPnts_UniformAbscissa.hxx>
#include <GC_MakePlane.hxx>
#include <GC_MakeSegment.hxx>
#include <GProp_GProps.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomConvert.hxx>
#include <GeomConvert_SurfToAnaSurf.hxx>
#include <Geom_BSplineSurface.hxx>
#include <Geom_Circle.hxx>
#include <Geom_Plane.hxx>
#include <Geom_RectangularTrimmedSurface.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopTrans_CurveTransition.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Vertex.hxx>
#include <TopoDS_Wire.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static const char* stateName(TopAbs_State s)
{
  switch (s)
  {
    case TopAbs_IN:
      return "IN";
    case TopAbs_OUT:
      return "OUT";
    case TopAbs_ON:
      return "ON";
    default:
      return "UNKNOWN";
  }
}

int main()
{
  // --- ProjectionOnCurve: circle r=5 at origin, normal Z; point (10,0,0)
  {
    Handle(Geom_Circle) circ = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    GeomAPI_ProjectPointOnCurve proj;
    proj.Init(gp_Pnt(10, 0, 0), circ);
    printf("[ProjectionOnCurve] NbPoints=%d\n", (int)proj.NbPoints());
    for (int i = 1; i <= proj.NbPoints(); i++)
    {
      gp_Pnt p = proj.Point(i);
      printf("  i=%d point=(%.12g,%.12g,%.12g) param=%.12g dist=%.12g\n",
             i, p.X(), p.Y(), p.Z(), proj.Parameter(i), proj.Distance(i));
    }
    printf("  LowerDistance=%.12g LowerDistanceParameter=%.12g\n",
           proj.LowerDistance(), proj.LowerDistanceParameter());
  }

  // --- QuasiUniformAbscissa: segment (0,0,0)-(10,0,0) with 5 and 2; circle r=5 with 10
  {
    GC_MakeSegment seg(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0));
    GeomAdaptor_Curve segA(seg.Value());
    for (int n : {5, 2})
    {
      GCPnts_QuasiUniformAbscissa s(segA, n);
      printf("[QuasiUniformAbscissa] segment n=%d IsDone=%d NbPoints=%d params:", n,
             (int)s.IsDone(), (int)s.NbPoints());
      for (int i = 1; i <= s.NbPoints(); i++)
        printf(" %.12g", s.Parameter(i));
      printf("\n");
    }
    Handle(Geom_Circle) c5 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 5);
    GeomAdaptor_Curve cA(c5);
    GCPnts_QuasiUniformAbscissa s(cA, 10);
    printf("[QuasiUniformAbscissa] circle r=5 n=10 IsDone=%d NbPoints=%d params:",
           (int)s.IsDone(), (int)s.NbPoints());
    for (int i = 1; i <= s.NbPoints(); i++)
      printf(" %.12g", s.Parameter(i));
    printf("\n");
  }

  // --- QuasiUniformDeflection: circle r=10, deflections 0.1, 1.0, 0.01
  {
    Handle(Geom_Circle) c10 = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), 10);
    GeomAdaptor_Curve a(c10);
    for (double d : {0.1, 1.0, 0.01})
    {
      GCPnts_QuasiUniformDeflection s(a, d);
      double maxRadErr = 0, maxSagitta = 0;
      for (int i = 1; i <= s.NbPoints(); i++)
      {
        gp_Pnt p = s.Value(i);
        maxRadErr = std::max(maxRadErr, std::fabs(std::hypot(p.X(), p.Y()) - 10));
        if (i > 1)
        {
          gp_Pnt q     = s.Value(i - 1);
          double chord = p.Distance(q);
          maxSagitta   = std::max(maxSagitta, 10 - std::sqrt(100 - chord * chord / 4));
        }
      }
      gp_Pnt f = s.Value(1), l = s.Value(s.NbPoints());
      printf("[QuasiUniformDeflection] r=10 defl=%g IsDone=%d NbPoints=%d maxRadialErr=%.3g "
             "maxSagitta=%.12g first=(%.12g,%.12g) last=(%.12g,%.12g)\n",
             d, (int)s.IsDone(), (int)s.NbPoints(), maxRadErr, maxSagitta, f.X(), f.Y(), l.X(),
             l.Y());
    }
  }

  // --- SketchArcCircle buildProfile: the 52 lifted points Sketch.buildProfile passes to
  // Wire.polygon3D (line (0,0)->(10,0), then the arc centre (5,0) r=5 from 0 to pi at
  // 16 segments/radian = 50 segments, its first point deduplicated against (10,0)), closed.
  {
    std::vector<gp_Pnt> pts;
    pts.push_back(gp_Pnt(0, 0, 0));
    pts.push_back(gp_Pnt(10, 0, 0));
    const int segs = (int)(16.0 * M_PI);
    for (int i = 1; i <= segs; i++)
    {
      double t = M_PI * (double)i / (double)segs;
      pts.push_back(gp_Pnt(5 + 5 * std::cos(t), 5 * std::sin(t), 0));
    }
    BRepBuilderAPI_MakePolygon poly;
    for (auto& p : pts)
      poly.Add(p);
    poly.Close();
    TopoDS_Wire w = poly.Wire();
    int nEdges    = 0;
    for (TopExp_Explorer ex(w, TopAbs_EDGE); ex.More(); ex.Next())
      nEdges++;
    GProp_GProps g;
    BRepGProp::LinearProperties(w, g);
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(w, v1, v2);
    printf("[SketchArcCircle] segments=%d inputPoints=%zu IsDone=%d edges=%d length=%.12g "
           "closed=%d\n",
           segs, pts.size(), (int)poly.IsDone(), nEdges, g.Mass(),
           (int)(!v1.IsNull() && v1.IsSame(v2)));
  }

  // --- SurfToAnaSurf: plane at origin normal Z, trimmed [-10,10]^2, to BSpline, recognise
  {
    GC_MakePlane mp(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1));
    Handle(Geom_Plane) plane = mp.Value();
    Handle(Geom_RectangularTrimmedSurface) tr =
      new Geom_RectangularTrimmedSurface(plane, -10.0, 10.0, -10.0, 10.0);
    Handle(Geom_BSplineSurface) bsp = GeomConvert::SurfaceToBSplineSurface(tr);
    GeomConvert_SurfToAnaSurf conv(bsp);
    Handle(Geom_Surface) res = conv.ConvertToAnalytical(1e-4);
    printf("[SurfToAnaSurf] resultNull=%d type=%s gap=%.6g\n", (int)res.IsNull(),
           res.IsNull() ? "-" : res->DynamicType()->Name(), conv.Gap());
    if (!res.IsNull())
    {
      Handle(Geom_Plane) rp = Handle(Geom_Plane)::DownCast(res);
      if (!rp.IsNull())
      {
        gp_Dir n = rp->Position().Direction();
        gp_Pnt o = rp->Location();
        printf("  plane normal=(%.12g,%.12g,%.12g) origin=(%.12g,%.12g,%.12g)\n", n.X(), n.Y(),
               n.Z(), o.X(), o.Y(), o.Z());
      }
    }
    printf("[SurfToAnaSurf] IsCanonical(plane)=%d IsCanonical(bspline)=%d\n",
           (int)GeomConvert_SurfToAnaSurf::IsCanonical(plane),
           (int)GeomConvert_SurfToAnaSurf::IsCanonical(bsp));
  }

  // --- TopTrans_CurveTransition, the two calls the tests make (tolerance 1e-6, FORWARD, FORWARD)
  {
    TopTrans_CurveTransition ct;
    ct.Reset(gp_Dir(1, 0, 0));
    ct.Compare(1e-6, gp_Dir(0, 1, 0), gp_Dir(0, 0, 1), 0.0, TopAbs_FORWARD, TopAbs_FORWARD);
    printf("[TopTrans] basic before=%s(%d) after=%s(%d)\n", stateName(ct.StateBefore()),
           (int)ct.StateBefore(), stateName(ct.StateAfter()), (int)ct.StateAfter());

    TopTrans_CurveTransition ct2;
    ct2.Reset(gp_Dir(1, 0, 0), gp_Dir(0, 0, 1), 0.1);
    ct2.Compare(1e-6, gp_Dir(0, 1, 0), gp_Dir(0, 0, 1), 0.05, TopAbs_FORWARD, TopAbs_FORWARD);
    printf("[TopTrans] curvature before=%s(%d) after=%s(%d)\n", stateName(ct2.StateBefore()),
           (int)ct2.StateBefore(), stateName(ct2.StateAfter()), (int)ct2.StateAfter());

    // A tangent that crosses the boundary against its normal (x-directed boundary normal)
    TopTrans_CurveTransition ct3;
    ct3.Reset(gp_Dir(1, 0, 0));
    ct3.Compare(1e-6, gp_Dir(0, 1, 0), gp_Dir(1, 0, 0), 0.0, TopAbs_FORWARD, TopAbs_FORWARD);
    printf("[TopTrans] crossing (normal +x) before=%s(%d) after=%s(%d)\n",
           stateName(ct3.StateBefore()), (int)ct3.StateBefore(), stateName(ct3.StateAfter()),
           (int)ct3.StateAfter());
  }

  // --- UniformAbscissa: first edge (IndexedMap order) of the centred 10x10x10 box
  {
    BRepPrimAPI_MakeBox mb(gp_Pnt(-5, -5, -5), 10, 10, 10);
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(mb.Shape(), TopAbs_EDGE, map);
    TopoDS_Edge e = TopoDS::Edge(map(1));
    BRepAdaptor_Curve ac(e);
    gp_Pnt s = ac.Value(ac.FirstParameter()), t = ac.Value(ac.LastParameter());
    printf("[UniformAbscissa] edge1 range=[%.12g,%.12g] start=(%g,%g,%g) end=(%g,%g,%g)\n",
           ac.FirstParameter(), ac.LastParameter(), s.X(), s.Y(), s.Z(), t.X(), t.Y(), t.Z());
    {
      GCPnts_UniformAbscissa ua(ac, 5);
      printf("  byCount 5: IsDone=%d NbPoints=%d params:", (int)ua.IsDone(), (int)ua.NbPoints());
      for (int i = 1; i <= ua.NbPoints(); i++)
        printf(" %.12g", ua.Parameter(i));
      printf("\n");
    }
    {
      GCPnts_UniformAbscissa ua(ac, 3.0);
      printf("  byDistance 3: IsDone=%d NbPoints=%d params:", (int)ua.IsDone(),
             (int)ua.NbPoints());
      for (int i = 1; i <= ua.NbPoints(); i++)
        printf(" %.12g", ua.Parameter(i));
      printf("\n");
    }
    {
      GCPnts_UniformAbscissa ua(ac, 3, 0.0, 1.0);
      printf("  byCountRange 3 [0,1]: IsDone=%d NbPoints=%d params:", (int)ua.IsDone(),
             (int)ua.NbPoints());
      for (int i = 1; i <= ua.NbPoints(); i++)
        printf(" %.12g", ua.Parameter(i));
      printf("\n");
    }
  }

  // --- WireEdgePolyline: rectangle 10x5 centred, edge 0 in IndexedMap order,
  // GCPnts_TangentialDeflection(curve, 0.1 angular, 0.1 linear)
  {
    gp_Pnt p1(-5, -2.5, 0), p2(5, -2.5, 0), p3(5, 2.5, 0), p4(-5, 2.5, 0);
    BRepBuilderAPI_MakeWire mw;
    mw.Add(BRepBuilderAPI_MakeEdge(p1, p2));
    mw.Add(BRepBuilderAPI_MakeEdge(p2, p3));
    mw.Add(BRepBuilderAPI_MakeEdge(p3, p4));
    mw.Add(BRepBuilderAPI_MakeEdge(p4, p1));
    TopTools_IndexedMapOfShape map;
    TopExp::MapShapes(mw.Wire(), TopAbs_EDGE, map);
    BRepAdaptor_Curve           c(TopoDS::Edge(map(1)));
    GCPnts_TangentialDeflection d(c, 0.1, 0.1);
    printf("[WireEdgePolyline] edge0 NbPoints=%d:", (int)d.NbPoints());
    for (int i = 1; i <= d.NbPoints(); i++)
    {
      gp_Pnt p = d.Value(i);
      printf(" (%.12g,%.12g,%.12g)", p.X(), p.Y(), p.Z());
    }
    printf("\n");
  }
  return 0;
}
