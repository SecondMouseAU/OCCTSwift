// Epic #766, Issue1433GPropFaceKnotSizingTests.swift, Issue1502DarbouxTrihedronTests.swift and
// Issue1515CoonsPatchUParameterTests.swift: kernel parity.
//  - BRepGProp_Face on the 10x10 planar face: SVIntSubs/VKnots, and LIntSubs/LKnots on edge 1,
//    with arrays sized N (subintervals + 1), as OCCTBRepGPropFaceVKnots / ...BoundaryIntegration.
//  - GeomFill_Darboux on Adaptor3d_CurveOnSurface(pcurve of the circle edge, face), as
//    OCCTGeomFillDarbouxTrihedron.
//  - GeomFill_CoonsAlgPatch on the 10-square with the bridge's sortbounds-style reversal, at the
//    2x2 corners (the pinned kernel carries patch 0034, the #1515 fix).
#include <Adaptor3d_CurveOnSurface.hxx>
#include <BRepAdaptor_Surface.hxx>
#include <BRepBuilderAPI_MakeEdge.hxx>
#include <BRepBuilderAPI_MakeFace.hxx>
#include <BRepBuilderAPI_MakePolygon.hxx>
#include <BRepBuilderAPI_MakeWire.hxx>
#include <BRepGProp_Face.hxx>
#include <BRep_Tool.hxx>
#include <GC_MakeSegment.hxx>
#include <Geom2dAdaptor_Curve.hxx>
#include <GeomAdaptor_Curve.hxx>
#include <GeomFill_CoonsAlgPatch.hxx>
#include <GeomFill_Darboux.hxx>
#include <GeomFill_SimpleBound.hxx>
#include <Geom_Circle.hxx>
#include <Geom_TrimmedCurve.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Wire.hxx>
#include <cstdio>
#include <gp_Pln.hxx>

int main()
{
  {
    BRepBuilderAPI_MakePolygon poly(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0), gp_Pnt(0, 10, 0), true);
    TopoDS_Face    f = BRepBuilderAPI_MakeFace(gp_Pln(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), poly.Wire()).Face();
    BRepGProp_Face gf(f);
    int            n = gf.SVIntSubs();
    NCollection_Array1<double> k(1, n + 1);
    gf.VKnots(k);
    printf("1433 vKnots: SVIntSubs=%d knots=", n);
    for (int i = 1; i <= n + 1; i++)
      printf("%g ", k(i));
    TopTools_IndexedMapOfShape emap;
    TopExp::MapShapes(f, TopAbs_EDGE, emap);
    gf.Load(TopoDS::Edge(emap(1)));
    int s = gf.LIntSubs();
    NCollection_Array1<double> lk(1, s + 1);
    gf.LKnots(lk);
    printf("| edge 0: LIntSubs=%d knots=", s);
    for (int i = 1; i <= s + 1; i++)
      printf("%g ", lk(i));
    printf("\n");
  }
  for (double r : {5.0, 3.0})
  {
    Handle(Geom_Circle) c = new Geom_Circle(gp_Ax2(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), r);
    TopoDS_Wire         w = BRepBuilderAPI_MakeWire(BRepBuilderAPI_MakeEdge(c).Edge()).Wire();
    TopoDS_Face         f = BRepBuilderAPI_MakeFace(w).Face();
    TopTools_IndexedMapOfShape emap;
    TopExp::MapShapes(f, TopAbs_EDGE, emap);
    TopoDS_Edge          e = TopoDS::Edge(emap(1));
    double               first, last;
    Handle(Geom2d_Curve) pc = BRep_Tool::CurveOnSurface(e, f, first, last);
    Handle(Adaptor3d_CurveOnSurface) cos =
      new Adaptor3d_CurveOnSurface(new Geom2dAdaptor_Curve(pc, first, last), new BRepAdaptor_Surface(f));
    Handle(GeomFill_Darboux) d = new GeomFill_Darboux();
    d->SetCurve(cos);
    for (double prm : {0.1, 0.0, 0.5, 1.5, 3.0, 5.0})
    {
      gp_Vec t, nn, b;
      bool   ok = d->D0(prm, t, nn, b);
      printf("1502 r=%g param=%g ok=%d T=(%.9g,%.9g,%.9g) N=(%.9g,%.9g,%.9g) B=(%.9g,%.9g,%.9g) T.N=%.2g\n", r, prm, ok, t.X(),
             t.Y(), t.Z(), nn.X(), nn.Y(), nn.Z(), b.X(), b.Y(), b.Z(), t.Dot(nn));
    }
  }
  {
    auto mk = [](gp_Pnt a, gp_Pnt b) {
      Handle(Geom_TrimmedCurve) s = GC_MakeSegment(a, b).Value();
      return Handle(GeomFill_SimpleBound)(
        new GeomFill_SimpleBound(new GeomAdaptor_Curve(s, s->FirstParameter(), s->LastParameter()), 1e-3, 1e-3));
    };
    Handle(GeomFill_Boundary) bound[4] = {mk(gp_Pnt(0, 0, 0), gp_Pnt(10, 0, 0)),
                                          mk(gp_Pnt(10, 0, 0), gp_Pnt(10, 10, 0)),
                                          mk(gp_Pnt(0, 10, 0), gp_Pnt(10, 10, 0)),
                                          mk(gp_Pnt(0, 0, 0), gp_Pnt(0, 10, 0))};
    bool   rev[4] = {false, false, false, false};
    gp_Pnt first, tail;
    bound[0]->Points(first, tail);
    for (int i = 1; i < 4; i++)
    {
      gp_Pnt qf, ql;
      bound[i]->Points(qf, ql);
      rev[i] = (ql.Distance(tail) < qf.Distance(tail));
      tail   = rev[i] ? qf : ql;
    }
    rev[2] = !rev[2];
    rev[3] = !rev[3];
    for (int i = 0; i < 4; i++)
      bound[i]->Reparametrize(0., 1., false, false, 1., 1., rev[i]);
    GeomFill_CoonsAlgPatch patch(bound[0], bound[1], bound[2], bound[3]);
    double worst = 0;
    for (int i = 0; i < 5; i++)
      for (int j = 0; j < 5; j++)
      {
        double u = i / 4.0, v = j / 4.0;
        worst    = std::max(worst, patch.Value(u, v).Distance(gp_Pnt(10 * u, 10 * v, 0)));
      }
    gp_Pnt a = patch.Value(1, 0), b = patch.Value(0, 1);
    printf("1515 coons: Value(1,0)=(%g,%g,%g) Value(0,1)=(%g,%g,%g) max|Value(u,v) - (10u,10v,0)| on 5x5 = %.3g\n", a.X(),
           a.Y(), a.Z(), b.X(), b.Y(), b.Z(), worst);
  }
  return 0;
}
