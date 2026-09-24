// Epic #766 (#1978), kernel parity for BiTgteCurveOnEdgeTests.swift, BRepAdaptorPCurveTests.swift
// and BSplineApproxInterpTests.swift. Same inputs as the Swift tests, mirroring the bridge:
//   OCCTBiTgteCurveOnEdge*      -> BiTgte_CurveOnEdge(edgeOnFace, edge), FirstParameter/D0
//   OCCTEdgePCurveParams/Value  -> BRepAdaptor_Curve2d(edge, face)
//   OCCTBSplineApproxInterp*    -> GeomAPI_PointsToBSpline(pts, 3, 8, C2, tol3D), max error by
//                                  GeomAPI_ProjectPointOnCurve (the bridge's own measure)
#include <BRepAdaptor_Curve2d.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRep_Tool.hxx>
#include <BiTgte_CurveOnEdge.hxx>
#include <GeomAPI_PointsToBSpline.hxx>
#include <GeomAPI_ProjectPointOnCurve.hxx>
#include <Geom_BSplineCurve.hxx>
#include <TColgp_Array1OfPnt.hxx>
#include <TopExp.hxx>
#include <TopExp_Explorer.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <cmath>
#include <cstdio>
#include <vector>

static void fit(const char* name, const std::vector<gp_Pnt>& p, double tol)
{
  TColgp_Array1OfPnt a(1, (int)p.size());
  for (size_t i = 0; i < p.size(); i++)
    a((int)i + 1) = p[i];
  GeomAPI_PointsToBSpline   f(a, 3, 8, GeomAbs_C2, tol);
  Handle(Geom_BSplineCurve) c  = f.Curve();
  double                    mx = 0;
  for (size_t i = 0; i < p.size(); i++)
  {
    GeomAPI_ProjectPointOnCurve pr(p[i], c);
    if (pr.NbPoints() > 0)
      mx = std::max(mx, pr.LowerDistance());
  }
  gp_Pnt s = c->Value(c->FirstParameter()), e = c->Value(c->LastParameter());
  printf("%s: tol3D=%g done=%d degree=%d poles=%d domain=[%.17g, %.17g] maxError=%.17g\n", name,
         tol, !c.IsNull(), c->Degree(), c->NbPoles(), c->FirstParameter(), c->LastParameter(), mx);
  printf("  start=(%.17g, %.17g, %.17g) end=(%.17g, %.17g, %.17g)\n", s.X(), s.Y(), s.Z(), e.X(),
         e.Y(), e.Z());
}

int main()
{
  TopoDS_Shape               box = BRepPrimAPI_MakeBox(gp_Pnt(-5, -5, -5), 10, 10, 10).Shape(); // Shape.box centres the box
  TopTools_IndexedMapOfShape em;
  TopExp::MapShapes(box, TopAbs_EDGE, em);
  for (int i = 1; i <= 2; i++)
  {
    TopoDS_Vertex v1, v2;
    TopExp::Vertices(TopoDS::Edge(em(i)), v1, v2);
    gp_Pnt a = BRep_Tool::Pnt(v1), b = BRep_Tool::Pnt(v2);
    printf("box 10 edge[%d]: (%g, %g, %g) -> (%g, %g, %g)\n", i - 1, a.X(), a.Y(), a.Z(), b.X(),
           b.Y(), b.Z());
  }
  {
    BiTgte_CurveOnEdge c(TopoDS::Edge(em(1)), TopoDS::Edge(em(2)));
    double             f = c.FirstParameter(), l = c.LastParameter(), m = (f + l) / 2;
    gp_Pnt             p;
    c.D0(m, p);
    gp_Pnt p0, p1;
    c.D0(f, p0);
    c.D0(l, p1);
    printf("CurveOnEdge(edge[0], edge[1]): domain=[%.17g, %.17g] D0(mid)=(%.17g, %.17g, %.17g)\n",
           f, l, p.X(), p.Y(), p.Z());
    printf("  D0(first)=(%.17g, %.17g, %.17g) D0(last)=(%.17g, %.17g, %.17g)\n", p0.X(), p0.Y(),
           p0.Z(), p1.X(), p1.Y(), p1.Z());
  }
  {
    BiTgte_CurveOnEdge c(TopoDS::Edge(em(1)), TopoDS::Edge(em(1)));
    double             f = c.FirstParameter(), l = c.LastParameter();
    gp_Pnt             p;
    c.D0((f + l) / 2, p);
    printf("CurveOnEdge(edge[0], edge[0]): domain=[%.17g, %.17g] D0(mid)=(%.17g, %.17g, %.17g)\n",
           f, l, p.X(), p.Y(), p.Z());
  }

  TopoDS_Shape box2 = BRepPrimAPI_MakeBox(gp_Pnt(-5, -10, -15), 10, 20, 30).Shape(); // centred, as Shape.box
  TopExp_Explorer fx(box2, TopAbs_FACE);
  TopoDS_Face     f0 = TopoDS::Face(fx.Current());
  TopTools_IndexedMapOfShape em2;
  TopExp::MapShapes(box2, TopAbs_EDGE, em2);
  printf("box 10x20x30 face[0], edges in map order:\n");
  for (int i = 1; i <= em2.Extent(); i++)
  {
    TopoDS_Edge e = TopoDS::Edge(em2(i));
    double      a, b;
    if (BRep_Tool::CurveOnSurface(e, f0, a, b).IsNull())
    {
      printf("  edge[%d]: no pcurve on face[0]\n", i - 1);
      continue;
    }
    BRepAdaptor_Curve2d ad(e, f0);
    double              m  = (ad.FirstParameter() + ad.LastParameter()) / 2;
    gp_Pnt2d            uv = ad.Value(m);
    printf("  edge[%d]: pcurve range=[%.17g, %.17g] value(mid)=(%.17g, %.17g)\n", i - 1,
           ad.FirstParameter(), ad.LastParameter(), uv.X(), uv.Y());
  }

  std::vector<gp_Pnt> helix;
  for (int i = 0; i < 20; i++)
  {
    double t = i / 19.0 * 2.0 * M_PI;
    helix.push_back(gp_Pnt(std::cos(t), std::sin(t), 0.1 * t));
  }
  fit("basicApproximation (helix, 20 pts)", helix, 1e-3);
  std::vector<gp_Pnt> sine;
  for (int i = 0; i < 30; i++)
  {
    double t = i / 29.0;
    sine.push_back(gp_Pnt(t, std::sin(M_PI * t), 0));
  }
  fit("withInterpolationConstraints (sine, 30 pts)", sine, 1e-3);
  std::vector<gp_Pnt> para;
  for (int i = 0; i < 20; i++)
  {
    double t = i / 19.0;
    para.push_back(gp_Pnt(t, t * t, 0));
  }
  fit("performOptimal (parabola, 20 pts)", para, 1e-3);
  std::vector<gp_Pnt> line;
  for (int i = 0; i < 10; i++)
    line.push_back(gp_Pnt(i + 1, 0, 0));
  fit("setters (line, 10 pts, tol3D min(1e-4, 1e-7))", line, 1e-7);
  return 0;
}
