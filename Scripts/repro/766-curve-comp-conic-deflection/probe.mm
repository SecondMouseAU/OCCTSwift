// Epic #766 (#1978), kernel parity for CompCurveTests.swift, ConicalProjectionTests.swift,
// ConvertCircleTests.swift, ConvertConicCurvesTests.swift and CPntsUniformDeflectionTests.swift.
// Same inputs as the Swift tests, mirroring the bridge:
//   OCCTConcatenateCurves3D/2D     -> GeomConvert_CompCurveToBSplineCurve / Geom2dConvert_...
//   OCCTShapeProjectWireConical    -> BRepProj_Projection(wire, shape, eye)
//   OCCTConvert*ToBSpline2D        -> Convert_{Circle,Ellipse,Hyperbola,Parabola}ToBSplineCurve
//   OCCTCPntsUniformDeflection*    -> CPnts_UniformDeflection on BRepAdaptor_Curve
#include <BRepAdaptor_Curve.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRepProj_Projection.hxx>
#include <BRep_Tool.hxx>
#include <CPnts_UniformDeflection.hxx>
#include <Convert_CircleToBSplineCurve.hxx>
#include <Convert_EllipseToBSplineCurve.hxx>
#include <Convert_HyperbolaToBSplineCurve.hxx>
#include <Convert_ParabolaToBSplineCurve.hxx>
#include <GC_MakeSegment.hxx>
#include <GCE2d_MakeSegment.hxx>
#include <Geom2dConvert_CompCurveToBSplineCurve.hxx>
#include <Geom2d_BSplineCurve.hxx>
#include <GeomConvert_CompCurveToBSplineCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TColStd_Array1OfInteger.hxx>
#include <TColStd_Array1OfReal.hxx>
#include <TColgp_Array1OfPnt2d.hxx>
#include <cstdio>
#include <vector>

static void conic(const char* name, const Convert_ConicToBSplineCurve& c)
{
  TColgp_Array1OfPnt2d    p(1, c.NbPoles());
  TColStd_Array1OfReal    w(1, c.NbPoles()), k(1, c.NbKnots());
  TColStd_Array1OfInteger m(1, c.NbKnots());
  for (int i = 1; i <= c.NbPoles(); i++)
  {
    p(i) = c.Poles().Value(i);
    w(i) = c.Weights().Value(i);
  }
  for (int i = 1; i <= c.NbKnots(); i++)
  {
    k(i) = c.Knots().Value(i);
    m(i) = c.Multiplicities().Value(i);
  }
  Handle(Geom2d_BSplineCurve) b = new Geom2d_BSplineCurve(p, w, k, m, c.Degree());
  double                      f = b->FirstParameter(), l = b->LastParameter();
  printf("%s: degree=%d poles=%d domain=[%.17g, %.17g]\n", name, c.Degree(), c.NbPoles(), f, l);
  for (int i = 0; i <= 4; i++)
  {
    gp_Pnt2d q = b->Value(f + (l - f) * i / 4.0);
    printf("  at %d/4: (%.17g, %.17g)\n", i, q.X(), q.Y());
  }
}

static void deflection(const char* name, const BRepAdaptor_Curve& a, double d, bool range, double u1,
                       double u2)
{
  CPnts_UniformDeflection ud;
  if (range)
    ud.Initialize(a, d, u1, u2, 1e-7, true);
  else
    ud.Initialize(a, d, 1e-7, true);
  int    n = 0;
  double first = 0, last = 0;
  while (ud.More())
  {
    if (n == 0)
      first = ud.Value();
    last = ud.Value();
    n++;
    ud.Next();
  }
  printf("%s: deflection %g -> %d points, params %.17g .. %.17g\n", name, d, n, first, last);
}

int main()
{
  {
    Handle(Geom_TrimmedCurve) s1 = GC_MakeSegment(gp_Pnt(0, 0, 0), gp_Pnt(1, 0, 0)).Value();
    Handle(Geom_TrimmedCurve) s2 = GC_MakeSegment(gp_Pnt(1, 0, 0), gp_Pnt(2, 1, 0)).Value();
    GeomConvert_CompCurveToBSplineCurve comp(s1);
    bool                                ok = comp.Add(s2, 1e-3);
    Handle(Geom_BSplineCurve)           r  = comp.BSplineCurve();
    gp_Pnt a = r->StartPoint(), b = r->EndPoint();
    printf("concatenate3D: add=%d degree=%d poles=%d domain=[%.17g, %.17g] start=(%g, %g, %g) end=(%g, %g, %g)\n",
           ok, r->Degree(), r->NbPoles(), r->FirstParameter(), r->LastParameter(), a.X(), a.Y(),
           a.Z(), b.X(), b.Y(), b.Z());
  }
  {
    Handle(Geom2d_TrimmedCurve) s1 = GCE2d_MakeSegment(gp_Pnt2d(0, 0), gp_Pnt2d(1, 0)).Value();
    Handle(Geom2d_TrimmedCurve) s2 = GCE2d_MakeSegment(gp_Pnt2d(1, 0), gp_Pnt2d(2, 1)).Value();
    Geom2dConvert_CompCurveToBSplineCurve comp(s1);
    bool                                  ok = comp.Add(s2, 1e-3);
    Handle(Geom2d_BSplineCurve)           r  = comp.BSplineCurve();
    gp_Pnt2d a = r->StartPoint(), b = r->EndPoint();
    printf("concatenate2D: add=%d degree=%d poles=%d domain=[%.17g, %.17g] start=(%g, %g) end=(%g, %g)\n",
           ok, r->Degree(), r->NbPoles(), r->FirstParameter(), r->LastParameter(), a.X(), a.Y(),
           b.X(), b.Y());
  }
  {
    TopoDS_Edge  e = BRepBuilderAPI_MakeEdge(gp_Pnt(-3, 0, 0), gp_Pnt(3, 0, 0));
    TopoDS_Wire  w = BRepBuilderAPI_MakeWire(e);
    TopoDS_Shape box0 =
      BRepPrimAPI_MakeBox(gp_Pnt(-10, -10, -0.5), 20, 20, 1).Shape(); // Shape.box centres it
    gp_Trsf t;
    t.SetTranslation(gp_Vec(-10, -10, -5));
    TopoDS_Shape        box = BRepBuilderAPI_Transform(box0, t, true).Shape();
    BRepProj_Projection pr(w, box, gp_Pnt(0, 0, 10));
    printf("projectConical: done=%d", pr.IsDone());
    if (pr.IsDone())
    {
      TopoDS_Shape               r = pr.Shape();
      TopTools_IndexedMapOfShape em, vm;
      TopExp::MapShapes(r, TopAbs_EDGE, em);
      TopExp::MapShapes(r, TopAbs_VERTEX, vm);
      printf(" isNull=%d edges=%d vertices=%d\n", r.IsNull(), em.Extent(), vm.Extent());
      for (int i = 1; i <= vm.Extent(); i++)
      {
        gp_Pnt p = BRep_Tool::Pnt(TopoDS::Vertex(vm(i)));
        printf("  vertex (%.17g, %.17g, %.17g)\n", p.X(), p.Y(), p.Z());
      }
    }
    else
      printf("\n");
  }
  conic("circleArcToBSpline r=10 [0, pi]",
        Convert_CircleToBSplineCurve(gp_Circ2d(gp_Ax2d(gp_Pnt2d(0, 0), gp_Dir2d(1, 0)), 10), 0,
                                     M_PI));
  gp_Ax22d ax(gp_Pnt2d(0, 0), gp_Dir2d(1, 0), gp_Dir2d(0, 1));
  conic("ellipseArc 20x10 [0, pi]", Convert_EllipseToBSplineCurve(gp_Elips2d(ax, 20, 10), 0, M_PI));
  conic("hyperbolaArc 10x5 [-1, 1]", Convert_HyperbolaToBSplineCurve(gp_Hypr2d(ax, 10, 5), -1, 1));
  conic("parabolaArc focal 5 [-2, 2]", Convert_ParabolaToBSplineCurve(gp_Parab2d(ax, 5), -2, 2));

  TopoDS_Shape               cyl = BRepPrimAPI_MakeCylinder(10, 5).Shape();
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(cyl, TopAbs_EDGE, em);
  for (int i = 1; i <= em.Extent(); i++)
  {
    BRepAdaptor_Curve a(TopoDS::Edge(em(i)));
    char              name[64];
    snprintf(name, sizeof name, "cylinder edge[%d] type %d", i - 1, (int)a.GetType());
    deflection(name, a, 0.1, false, 0, 0);
  }
  BRepAdaptor_Curve a(TopoDS::Edge(em(1)));
  // The ranged test asks for [first sample, the sample at index count / 2].
  CPnts_UniformDeflection ud;
  ud.Initialize(a, 0.1, 1e-7, true);
  std::vector<double> ps;
  while (ud.More())
  {
    ps.push_back(ud.Value());
    ud.Next();
  }
  printf("edge[0] full: %zu params; params[0]=%.17g params[%zu]=%.17g\n", ps.size(), ps[0],
         ps.size() / 2, ps[ps.size() / 2]);
  deflection("edge[0] ranged", a, 0.1, true, ps[0], ps[ps.size() / 2]);
  return 0;
}
